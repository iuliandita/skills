# LLM Integration Patterns

Detailed patterns for integrating LLM APIs into applications. Covers streaming, structured
output, tool use, multi-turn conversations, and provider-specific details.

---

## Table of Contents

1. Provider SDK Setup
2. Streaming Patterns
3. Structured Output
4. Tool Use / Function Calling
5. Multi-Turn Conversations
6. Error Handling and Retries
7. Provider-Specific Notes

---

## 1. Provider SDK Setup

### Anthropic (Python)

```python
import anthropic

# Client auto-reads ANTHROPIC_API_KEY from env
client = anthropic.Anthropic()

# Async variant
async_client = anthropic.AsyncAnthropic()

response = client.messages.create(
    model="claude-sonnet-4-6-20250514",
    max_tokens=1024,
    system="You are a helpful assistant.",
    messages=[{"role": "user", "content": "Hello"}],
)
print(response.content[0].text)
```

### Anthropic (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic(); // reads ANTHROPIC_API_KEY

const response = await client.messages.create({
  model: "claude-sonnet-4-6-20250514",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Hello" }],
});
console.log(response.content[0].type === "text" ? response.content[0].text : "");
```

### OpenAI (Python)

```python
from openai import OpenAI

client = OpenAI()  # reads OPENAI_API_KEY

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    max_tokens=1024,
)
print(response.choices[0].message.content)
```

### Vercel AI SDK (TypeScript)

```typescript
import { generateText } from "ai";
import { anthropic } from "@ai-sdk/anthropic";

const { text } = await generateText({
  model: anthropic("claude-sonnet-4-6-20250514"),
  prompt: "Hello",
  maxTokens: 1024,
});
```

---

## 2. Streaming Patterns

### Why stream

- User-facing: perceived latency drops from seconds to milliseconds (first token)
- Background: still stream to detect errors early and implement progress tracking
- Long outputs: streaming prevents timeout issues on HTTP connections

### Anthropic streaming (Python)

```python
with client.messages.stream(
    model="claude-sonnet-4-6-20250514",
    max_tokens=2048,
    messages=[{"role": "user", "content": prompt}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

# Get the final message object after streaming
final_message = stream.get_final_message()
print(f"\nTokens: {final_message.usage.input_tokens} in, {final_message.usage.output_tokens} out")
```

### Anthropic streaming (TypeScript)

```typescript
const stream = client.messages.stream({
  model: "claude-sonnet-4-6-20250514",
  max_tokens: 2048,
  messages: [{ role: "user", content: prompt }],
});

for await (const event of stream) {
  if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
    process.stdout.write(event.delta.text);
  }
}

const finalMessage = await stream.finalMessage();
```

### OpenAI streaming (Python)

```python
stream = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}],
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

### Server-Sent Events (SSE) for web apps

```typescript
// Next.js / Express handler
export async function POST(req: Request) {
  const { prompt } = await req.json();

  const stream = client.messages.stream({
    model: "claude-sonnet-4-6-20250514",
    max_tokens: 2048,
    messages: [{ role: "user", content: prompt }],
  });

  return new Response(stream.toReadableStream(), {
    headers: { "Content-Type": "text/event-stream" },
  });
}
```

---

## 3. Structured Output

### Anthropic - tool_use for structured output

Force the model to return structured data by defining a "tool" that captures the schema:

```python
response = client.messages.create(
    model="claude-sonnet-4-6-20250514",
    max_tokens=1024,
    tools=[{
        "name": "extract_info",
        "description": "Extract structured information from the text",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer", "minimum": 0, "maximum": 150},
                "email": {"type": "string", "format": "email"},
                "topics": {
                    "type": "array",
                    "items": {"type": "string"},
                    "maxItems": 10,
                }
            },
            "required": ["name", "email"]
        }
    }],
    tool_choice={"type": "tool", "name": "extract_info"},
    messages=[{"role": "user", "content": f"Extract info from: {text}"}],
)

# Result is in the tool_use content block
tool_block = next(b for b in response.content if b.type == "tool_use")
data = tool_block.input  # already parsed dict
```

### OpenAI - response_format with json_schema

```python
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": f"Extract info from: {text}"}],
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "extract_info",
            "strict": True,
            "schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "age": {"type": ["integer", "null"]},
                    "email": {"type": "string"},
                },
                "required": ["name", "age", "email"],
                "additionalProperties": False,
            },
        },
    },
)
import json
data = json.loads(response.choices[0].message.content)
```

### Vercel AI SDK - generateObject

```typescript
import { generateObject } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { z } from "zod";

const { object } = await generateObject({
  model: anthropic("claude-sonnet-4-6-20250514"),
  schema: z.object({
    name: z.string(),
    age: z.number().int().min(0).max(150).optional(),
    email: z.string().email(),
    topics: z.array(z.string()).max(10),
  }),
  prompt: `Extract info from: ${text}`,
});
```

---

## 4. Tool Use / Function Calling

### The pattern

1. Define tools with JSON Schema input specifications
2. Send message with tools available
3. Model returns a `tool_use` block (Anthropic) or `tool_calls` (OpenAI)
4. Execute the tool, return the result
5. Model incorporates the result and continues

### Anthropic tool use loop

```python
messages = [{"role": "user", "content": user_query}]

while True:
    response = client.messages.create(
        model="claude-sonnet-4-6-20250514",
        max_tokens=4096,
        tools=tools,
        messages=messages,
    )

    # Collect all content blocks
    messages.append({"role": "assistant", "content": response.content})

    if response.stop_reason == "end_turn":
        break

    if response.stop_reason == "tool_use":
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                result = execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": str(result),
                })
        messages.append({"role": "user", "content": tool_results})
```

### Tool design guidelines

- **Specific over general.** `search_docs(query)` beats `do_anything(action, params)`.
- **Tight schemas.** Add `maxLength`, `minimum`, `maximum`, `enum` constraints.
- **Clear descriptions.** The model uses the description to decide when to call the tool.
  Be precise about what it does and doesn't do.
- **10-15 tools max.** Beyond that, models struggle with tool selection. Group related
  operations if you have too many.
- **Idempotent where possible.** Models sometimes call the same tool twice. Make sure
  repeated calls don't cause problems.

---

## 5. Multi-Turn Conversations

### Context management

For multi-turn conversations, manage the message history carefully:

```python
class Conversation:
    def __init__(self, system: str, max_turns: int = 50):
        self.system = system
        self.messages: list[dict] = []
        self.max_turns = max_turns

    def add_user_message(self, content: str) -> str:
        self.messages.append({"role": "user", "content": content})
        self._maybe_summarize()

        response = client.messages.create(
            model="claude-sonnet-4-6-20250514",
            system=self.system,
            max_tokens=2048,
            messages=self.messages,
        )

        assistant_text = response.content[0].text
        self.messages.append({"role": "assistant", "content": assistant_text})
        return assistant_text

    def _maybe_summarize(self):
        """Summarize old messages to keep context manageable."""
        if len(self.messages) > self.max_turns:
            old = self.messages[: self.max_turns // 2]
            summary = summarize_messages(old)  # LLM call to compress
            self.messages = [
                {"role": "user", "content": f"Previous conversation summary: {summary}"}
            ] + self.messages[self.max_turns // 2 :]
```

### Prompt caching (Anthropic)

For repeated system prompts or large static contexts, use prompt caching to reduce costs:

```python
response = client.messages.create(
    model="claude-sonnet-4-6-20250514",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": large_system_prompt,  # cached across requests
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=messages,
)
# Cached tokens cost 90% less on subsequent requests within the TTL
```

---

## 6. Error Handling and Retries

### Retry with exponential backoff

```python
import time
import random
import anthropic

def call_with_retry(fn, max_retries=3):
    for attempt in range(max_retries + 1):
        try:
            return fn()
        except anthropic.RateLimitError:
            if attempt == max_retries:
                raise
            delay = (2 ** attempt) + random.uniform(0, 1)  # jitter
            time.sleep(delay)
        except anthropic.APIStatusError as e:
            if e.status_code >= 500 and attempt < max_retries:
                time.sleep(2 ** attempt)
                continue
            raise  # 4xx errors (except 429) are not retryable
```

### Key error categories

| Error | HTTP code | Action |
|-------|-----------|--------|
| Rate limited | 429 | Retry with backoff, respect `Retry-After` header |
| Overloaded | 529 (Anthropic) | Retry with longer backoff |
| Server error | 500-503 | Retry with backoff |
| Invalid request | 400 | Fix the request, don't retry |
| Auth error | 401/403 | Check API key, don't retry |
| Context too long | 400 | Truncate input, reduce context |

---

## 7. Provider-Specific Notes

### Anthropic

- **Prompt caching**: mark static content with `cache_control` for 90% cost reduction on
  repeated prefixes. TTL is 5 minutes, refreshed on each cache hit.
- **Extended thinking**: for complex reasoning, enable extended thinking with
  `thinking={"type": "enabled", "budget_tokens": N}`. Available on Claude Sonnet 4+ and Opus.
- **Batch API**: submit up to 100k requests for 50% cost reduction, results within 24 hours.
  Good for evals and data processing.
- **Citations**: Claude can return source citations when given documents in the prompt.

### OpenAI

- **Responses API**: newer API alongside Chat Completions. Supports built-in tools
  (web search, file search, code interpreter) and streaming.
- **Structured outputs**: `strict: true` in json_schema guarantees valid JSON matching the
  schema. Without `strict`, the model may deviate.
- **Predicted outputs**: for editing tasks, provide the expected output to reduce latency
  and cost on models that support it.

### Vercel AI SDK

- **Provider-agnostic**: same code works with Anthropic, OpenAI, Google, Mistral, and
  30+ other providers by swapping the model import.
- **React hooks**: `useChat`, `useCompletion`, `useObject` for streaming UI updates.
- **ToolLoopAgent**: built-in agent loop that handles tool call/result cycles automatically.
- **Middleware**: intercept and transform model calls for logging, caching, guardrails.
