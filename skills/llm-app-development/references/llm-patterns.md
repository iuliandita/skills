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
    model="claude-sonnet-5-5",
    max_tokens=4096,  # covers adaptive thinking plus the reply
    system="You are a helpful assistant.",
    messages=[{"role": "user", "content": "Hello"}],
)
# Thinking blocks can precede the text, so select by type, not position.
print("".join(b.text for b in response.content if b.type == "text"))
```

Claude 5-series models think by default. See the
[Claude 5-series migration notes](target-versions.md#claude-5-series-migration) before porting
older examples: sampling parameters, prefill, and manual thinking budgets return 400.

### Anthropic (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic(); // reads ANTHROPIC_API_KEY

const response = await client.messages.create({
  model: "claude-sonnet-5-5",
  max_tokens: 4096,
  messages: [{ role: "user", content: "Hello" }],
});
const textBlock = response.content.find(
  (block): block is Anthropic.TextBlock => block.type === "text",
);
console.log(textBlock?.text ?? "");
```

### OpenAI Responses (Python)

```python
from openai import OpenAI

client = OpenAI()  # reads OPENAI_API_KEY

response = client.responses.create(
    model="gpt-6.1-sol",
    input="Explain why a queue needs a retry limit in one sentence.",
    reasoning={"effort": "low"},
    max_output_tokens=4096,
)
if response.status != "completed":
    raise RuntimeError(f"Response did not complete: {response.status}")
if not response.output_text.strip():
    raise RuntimeError("Response returned no text; inspect output for refusals")
print(response.output_text)
```

Use `AsyncOpenAI` and await requests in async handlers. The output budget includes reasoning;
handle incomplete responses rather than treating empty text as success. See the
[GPT-6.1 Sol migration checklist](target-versions.md#gpt-61-sol-migration) before adapting
older examples. Use Responses for tools; GPT-6.1 Sol's Chat Completions support has no tools.
Escalate to Astra only when Sol falls short on measured task quality; check its
[migration checklist](target-versions.md#astra-migration) and account access first.

### Vercel AI SDK (TypeScript)

```typescript
import { generateText } from "ai";
import { anthropic } from "@ai-sdk/anthropic";

const { text } = await generateText({
  model: anthropic("claude-sonnet-5-5"),
  prompt: "Hello",
  maxOutputTokens: 4096,
});
```

---

## 2. Streaming Patterns

### Why stream

- User-facing: perceived latency drops from seconds to milliseconds (first token)
- Background: stream when early error detection, progress reporting, incremental persistence, or timeout avoidance is required; otherwise buffer the final result
- Long outputs: streaming prevents timeout issues on HTTP connections

### Anthropic streaming (Python)

```python
with client.messages.stream(
    model="claude-sonnet-5-5",
    max_tokens=4096,
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
  model: "claude-sonnet-5-5",
  max_tokens: 4096,
  messages: [{ role: "user", content: prompt }],
});

for await (const event of stream) {
  if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
    process.stdout.write(event.delta.text);
  }
}

const finalMessage = await stream.finalMessage();
```

These examples stream final text. In Sonnet 5.5 tool loops, longer progress notes arrive in
`thinking` blocks and are empty by default. With adaptive thinking, use `display: "updates"`
and the `thinking-display-updates-2026-08-18` beta header to render progress; `between_tools`
returns those summaries without a `display` field. See the
[migration guide](https://platform.claude.com/docs/en/models/sonnet-5-5/migration-guide#text-between-tool-calls).

### OpenAI streaming (Python)

```python
stream = client.responses.create(
    model="gpt-6.1-sol",
    input=prompt,
    reasoning={"effort": "low"},
    max_output_tokens=4096,
    stream=True,
)

final_response = None
for event in stream:
    if event.type == "response.output_text.delta":
        print(event.delta, end="", flush=True)
    elif event.type in {"response.completed", "response.incomplete", "response.failed"}:
        final_response = event.response
    elif event.type == "error":
        raise RuntimeError(event.message)
if final_response is None or final_response.status != "completed":
    raise RuntimeError("Stream did not complete; inspect terminal response")
if not final_response.output_text.strip():
    raise RuntimeError("Stream returned no text; inspect output for refusals")
```

### Server-Sent Events (SSE) for web apps

```typescript
// Next.js / Express handler
export async function POST(req: Request) {
  const { prompt } = await req.json();

  const stream = client.messages.stream({
    model: "claude-sonnet-5-5",
    max_tokens: 4096,
    messages: [{ role: "user", content: prompt }],
  });

  return new Response(stream.toReadableStream(), {
    headers: { "Content-Type": "text/event-stream" },
  });
}
```

---

## 3. Structured Output

### Anthropic - structured output

Use JSON outputs (`output_config.format`) for a validated response body, and strict tools
when the model needs to call tools. Both use a
[JSON Schema subset](https://platform.claude.com/docs/en/build-with-claude/structured-outputs#json-schema-limitations):
objects require `additionalProperties: false`; raw schemas cannot use numerical bounds or
`maxItems`. Keep those constraints in application validation rather than removing them.

```python
from copy import deepcopy
import json
from jsonschema import FormatChecker, validate

WIRE_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "description": "Age from 0 to 150"},
        "email": {"type": "string", "format": "email"},
        "topics": {
            "type": "array",
            "items": {"type": "string"},
            "description": "At most 10 topics",
        },
    },
    "required": ["name", "email"],
    "additionalProperties": False,
}
APPLICATION_SCHEMA = deepcopy(WIRE_SCHEMA)
APPLICATION_SCHEMA["properties"]["age"].update(minimum=0, maximum=150)
APPLICATION_SCHEMA["properties"]["topics"]["maxItems"] = 10

response = client.messages.create(
    model="claude-sonnet-5-5",
    max_tokens=4096,
    messages=[{"role": "user", "content": f"Extract info from: {text}"}],
    output_config={"format": {"type": "json_schema", "schema": WIRE_SCHEMA}},
)
if response.stop_reason != "end_turn":
    raise RuntimeError(f"incomplete structured output: {response.stop_reason}")
text_output = "".join(b.text for b in response.content if b.type == "text")
if not text_output.strip():
    raise RuntimeError("structured output returned no text")
data = json.loads(text_output)
validate(data, APPLICATION_SCHEMA, format_checker=FormatChecker())
```

This example needs `jsonschema`. Validation failures must reach the application's error or
retry policy. For reasoning-heavy JSON tasks, use adaptive thinking at `high` effort with an
instruction to think first, or evaluate `xhigh`; `between_tools` does no up-front thinking
without tools. Never accept a `max_tokens` response even if its text is valid JSON. See
[Sonnet 5.5 prompting guidance](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5#reasoning-tasks-with-json-output).

Strict tool use reuses the schemas and validator above. Sonnet 5.5 rejects forced `any`/`tool`
choices; use `auto` and say when the tool applies. `strict` constrains tool input, but doesn't
guarantee a call. Handle a text-only reply explicitly. For extraction alone, prefer JSON outputs.

```python
response = client.messages.create(
    model="claude-sonnet-5-5",
    max_tokens=4096,
    tools=[{
        "name": "extract_info",
        "description": "Extract structured information from the text",
        "strict": True,
        "input_schema": WIRE_SCHEMA,
    }],
    tool_choice={"type": "auto"},
    messages=[{
        "role": "user",
        "content": f"Extract info from the following text using extract_info: {text}",
    }],
)
if response.stop_reason != "tool_use":
    raise RuntimeError(f"expected extraction tool call: {response.stop_reason}")
tool_blocks = [b for b in response.content if b.type == "tool_use"]
if len(tool_blocks) != 1 or tool_blocks[0].name != "extract_info":
    raise RuntimeError("expected exactly one extract_info call")
data = tool_blocks[0].input
validate(data, APPLICATION_SCHEMA, format_checker=FormatChecker())
```

### OpenAI - Responses with json_schema

```python
response = client.responses.create(
    model="gpt-6.1-sol",
    input=f"Extract info from: {text}",
    reasoning={"effort": "low"},
    max_output_tokens=4096,
    text={
        "format": {
            "type": "json_schema",
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
if response.status != "completed":
    raise RuntimeError(f"incomplete structured output: {response.status}")
if not response.output_text.strip():
    raise RuntimeError("no structured output; inspect output for refusals")
import json
data = json.loads(response.output_text)
```

### Vercel AI SDK - structured output

Use the current [Output API](https://ai-sdk.dev/docs/reference/ai-sdk-core/output).

```typescript
import { generateText, Output } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { z } from "zod";

const { output } = await generateText({
  model: anthropic("claude-sonnet-5-5"),
  output: Output.object({
    schema: z.object({
      name: z.string(),
      age: z.number().int().min(0).max(150).optional(),
      email: z.string().email(),
      topics: z.array(z.string()).max(10),
    }),
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

This is a bounded control-flow template. Implement the cost helpers, disable hidden SDK
retries, and set request/tool deadlines before use. Reserve paid tool charges too when the
ceiling covers the whole run; uncertain provider usage retains its full reservation.

```python
messages = [{"role": "user", "content": user_query}]

MAX_ITERS, BUDGET_USD = 20, 5.00
spent = 0.0
for _ in range(MAX_ITERS):
    # Implement these accounting helpers from the selected model's rates.
    reserved = max_cost_of_next_call(messages, tools=tools, max_tokens=16000)
    if spent + reserved > BUDGET_USD:
        raise RuntimeError("agent budget would be exceeded")
    response = client.messages.create(
        model="claude-sonnet-5-5",
        max_tokens=16000,  # thinking and tool calls share this cap
        tools=tools,
        messages=messages,
    )

    spent += cost_of(response.usage)
    # Preserve the complete assistant turn, including signed thinking blocks.
    messages.append({"role": "assistant", "content": response.content})

    if response.stop_reason == "end_turn":
        break

    if response.stop_reason == "tool_use":
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                try:
                    # Validate tool name/arguments and enforce per-tool timeout/output limits.
                    result = execute_tool(block.name, block.input)
                    is_error = False
                except Exception:
                    result, is_error = "Tool failed; inspect server logs", True
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": str(result),
                    "is_error": is_error,
                })
        if not tool_results:
            raise RuntimeError("tool_use stop without tool calls")
        messages.append({"role": "user", "content": tool_results})
    else:
        raise RuntimeError(f"incomplete or unsupported stop: {response.stop_reason}")
else:
    raise RuntimeError("agent iteration limit exceeded")
```

### Tool design guidelines

- **Specific over general.** `search_docs(query)` beats `do_anything(action, params)`.
- **Tight schemas.** Use provider-supported constraints such as `enum`; enforce unsupported
  length or numerical limits in application validation, especially with strict tools.
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

This text-only example drops prior thinking. Tool loops retain signed thinking blocks and
must keep their earlier history, system prompt, and tools unchanged when replaying them on
Sonnet 5.5. Use append-only updates or documented compaction/binding controls rather than
applying this summary replacement to tool histories. See
[preserved thinking](https://platform.claude.com/docs/en/build-with-claude/preserved-thinking).

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
            model="claude-sonnet-5-5",
            system=self.system,
            max_tokens=4096,
            messages=self.messages,
        )
        if response.stop_reason != "end_turn":
            self.messages.pop()  # drop the unanswered user turn
            raise RuntimeError(f"incomplete turn: {response.stop_reason}")

        # Without tools, prior thinking blocks may be dropped from history.
        assistant_text = "".join(b.text for b in response.content if b.type == "text")
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

Sonnet 5.5 requires at least 512 cacheable tokens. Per million tokens, cache reads cost $0.20,
5-minute writes $2.50, and 1-hour writes $4; the default TTL is 5 minutes and cache hits refresh it.

```python
response = client.messages.create(
    model="claude-sonnet-5-5",
    max_tokens=4096,
    system=[
        {
            "type": "text",
            "text": large_system_prompt,  # cached across requests
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=messages,
)
# Cache reads bill at a fraction of base input price within the TTL (ratio varies by model)
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

- **Prompt caching**: mark static content with `cache_control` for discounted cache reads on
  repeated prefixes. TTL is 5 minutes, refreshed on each cache hit.
- **Thinking**: current models use adaptive thinking (on by default on Sonnet 5.5 and Haiku 5.5,
  always on for Opus 5.5 and Fable 5.1). Control depth with `output_config={"effort": ...}`;
  manual `budget_tokens` returns 400 on these models. Only the retiring Haiku 4.5 still uses it.
  On Haiku 5.5, `thinking: {"type": "disabled"}` works at `high` effort or below.
  On Sonnet 5.5, replace `disabled` with `between_tools` at `high` effort or below; use adaptive
  thinking for `xhigh`/`max` or per-message effort changes.
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
