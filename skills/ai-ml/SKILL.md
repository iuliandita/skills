---
name: ai-ml
description: >
  · Build, review, or architect AI/ML applications - LLM integrations, RAG pipelines, agent
  systems, embeddings, evals, local inference, structured output, and tool use. Triggers: 'llm',
  'rag', 'embedding', 'vector store', 'langchain', 'openai sdk', 'anthropic sdk', 'agent loop',
  'fine-tune', 'ollama', 'vllm', 'evals', 'guardrails', 'chunking', 'reranking'. Not for MCP
  servers (use mcp), prompt writing (use prompt-generator), or general DB (use databases).
license: MIT
compatibility: "Varies by task. Common: Python 3.10+, Node.js 18+. Optional: GPU for local inference"
metadata:
  source: iuliandita/skills
  date_added: "2026-04-02"
  effort: high
  argument_hint: "[task description or architecture question]"
---

# AI/ML: Building Production AI Applications

Build, review, and architect applications that use AI models - from single-API calls to
multi-agent systems with RAG pipelines. The goal is production-grade AI apps that are reliable,
cost-effective, and don't hallucinate their way into an incident.

**Target versions** (April 2026):

| Component | Version | Notes |
|-----------|---------|-------|
| Anthropic Python SDK | 0.87.0 | Claude models, streaming, tool use, structured output |
| Anthropic TS SDK | 0.81.0 | Same capabilities, TypeScript-first |
| Claude Agent SDK (TS) | 0.2.90 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 2.30.0 | GPT/o-series models, Responses API |
| OpenAI Agents SDK | 0.13.3 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 6.0.142 | Unified provider interface, ToolLoopAgent, streaming |
| LangChain | 1.2.14 | Orchestration framework, langchain-core 1.2.24 |
| LangGraph | 1.1.0 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.19 | RAG framework, 300+ integrations |
| Transformers | 5.4.0 | Model inference, fine-tuning, PyTorch 2.4+ required |
| vLLM | 0.18.1 | High-throughput serving, continuous batching |
| Ollama | 0.19.0 | Local inference, MLX backend on Apple Silicon |
| pgvector | 0.8.2 | PostgreSQL extension, HNSW + IVFFlat |
| Qdrant | 1.17.1 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 8.1.0 | Managed vector DB |
| ChromaDB | 1.5.5 | Lightweight vector DB, local-first |
| promptfoo | 0.121.3 | LLM eval framework, red teaming |

## When to use

- Integrating LLM APIs (Anthropic, OpenAI, etc.) into applications
- Building RAG pipelines (chunking, embedding, retrieval, generation)
- Designing agent systems (tool use, loops, state, multi-agent)
- Choosing between fine-tuning, RAG, and prompt engineering
- Setting up vector stores for semantic search
- Implementing structured output and tool use / function calling
- Building evaluation and testing harnesses for AI features
- Optimizing token costs, latency, and model routing
- Setting up local inference with Ollama or vLLM
- Adding safety guardrails (content filtering, PII handling, output validation)

## When NOT to use

- Building MCP servers or tools (use **mcp** - it handles the protocol layer)
- Writing or refining individual prompts (use **prompt-generator**)
- General database configuration, schema design, or migrations (use **databases**)
- Security auditing AI application code (use **security-audit**)
- Reviewing code quality unrelated to AI/ML patterns (use **code-review**)

---

## AI Self-Check

AI tools consistently produce the same mistakes when generating AI application code.
**Before returning any generated AI/ML code, verify against this list:**

- [ ] API keys loaded from environment variables, never hardcoded
- [ ] Streaming responses handled with proper error boundaries and cleanup
- [ ] Token limits respected - input truncation or chunking for long contexts
- [ ] Structured output uses the provider's native schema enforcement (Anthropic tool_use,
  OpenAI response_format), not post-hoc parsing with regex
- [ ] Tool use / function calling validates tool results before passing back to the model
- [ ] Retry logic uses exponential backoff with jitter, not fixed delays
- [ ] Rate limit errors (429) handled distinctly from server errors (5xx)
- [ ] Vector store queries include a relevance threshold - don't blindly pass low-similarity
  results to the model
- [ ] Embedding model matches between indexing and querying (mixing models = garbage results)
- [ ] Prompt templates use parameterized injection, not string concatenation
- [ ] Model responses validated before use (check for refusals, empty content, malformed JSON)
- [ ] Cost estimation done before batch operations (token count * price * volume)
- [ ] No synchronous LLM calls in request handlers - always async with timeouts
- [ ] PII stripped or masked before sending to external model APIs
- [ ] Temperature set intentionally (0 for deterministic tasks, higher for creative)

---

## Workflow

### Step 1: Determine the architecture pattern

| Need | Pattern | Start with |
|------|---------|------------|
| Single model call | Direct API integration | Provider SDK |
| Knowledge-grounded answers | RAG pipeline | Vector store + retrieval |
| Multi-step reasoning | Agent with tools | LangGraph, OpenAI Agents SDK, or custom loop |
| Multiple specialized models | Model routing / chain | Custom router or Vercel AI SDK |
| Offline / air-gapped | Local inference | Ollama or vLLM |
| Existing data enrichment | Batch processing | Provider batch APIs |

### Step 2: Choose the right abstraction level

Pick the lightest tool that solves the problem:

1. **Raw SDK** - direct Anthropic/OpenAI SDK calls. Best for simple integrations, maximum
   control, minimum dependencies. Start here unless you have a specific reason not to.
2. **Vercel AI SDK** - unified provider interface with streaming primitives. Good for
   TypeScript apps that need provider-agnostic code or React/Next.js streaming UI.
3. **LangChain / LlamaIndex** - orchestration frameworks. Use when you need complex chains,
   built-in document loaders, or 300+ pre-built integrations. Don't use for simple API calls -
   the abstraction overhead isn't worth it.
4. **LangGraph / OpenAI Agents SDK** - stateful agent frameworks. Use when you need cycles,
   persistence, human-in-the-loop, or multi-agent coordination.

**The anti-pattern**: importing LangChain to make a single API call. That's like importing
Django to serve a static HTML file.

### Step 3: Implement

Follow the domain-specific sections below. Read the appropriate reference file for detailed
patterns and code examples.

### Step 4: Evaluate and validate

Every AI feature needs evaluation. Not "run it once and eyeball the output" - structured evals
with datasets, metrics, and regression detection.

Minimum viable eval: create a `promptfooconfig.yaml` with 20+ test cases, use `contains`,
`llm-rubric`, and `cost` assertions, run `npx promptfoo eval` in CI on every PR that touches
prompts. Track pass rate over time - any regression blocks the merge.

Read `references/evaluation.md` for promptfoo setup, assertion types, CI integration (GitHub
Actions example), RAG-specific evals, agent evals, and red teaming patterns.

---

## LLM Integration Patterns

### Streaming

Always stream for user-facing responses. Buffer for background processing.

```python
# Anthropic streaming (Python)
import anthropic

client = anthropic.Anthropic()

with client.messages.stream(
    model="claude-sonnet-4-6-20250514",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}],
) as stream:
    for text in stream.text_stream:
        yield text
```

### Structured output

Use native provider mechanisms, not regex parsing of free-text responses.

- **Anthropic**: `tool_use` with JSON schema, or `response_format` with `json_schema`
- **OpenAI**: `response_format: { type: "json_schema", json_schema: {...} }`
- **Vercel AI SDK**: `generateObject()` with Zod schema

### Tool use / function calling

Define tools with tight schemas. Validate tool results before feeding them back.

```python
tools = [{
    "name": "search_docs",
    "description": "Search internal documentation",
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "maxLength": 200},
            "limit": {"type": "integer", "minimum": 1, "maximum": 50}
        },
        "required": ["query"]
    }
}]
```

Read `references/llm-patterns.md` for multi-turn tool use, parallel tool calls, error
recovery, and provider-specific gotchas.

---

## RAG Architecture

The quality of a RAG system depends more on retrieval quality than model quality.
A mediocre model with great retrieval beats a frontier model with bad retrieval.

### Chunking strategy

| Strategy | When to use | Chunk size |
|----------|------------|------------|
| Fixed-size with overlap | Default starting point | 512-1024 tokens, 10-20% overlap |
| Semantic (sentence/paragraph) | Well-structured documents | Varies by content |
| Recursive character | Mixed content types | 1000 chars, 200 overlap |
| Document-aware (markdown headers, code blocks) | Structured docs, code | Section-based |
| Parent-child | Need both precision and context | Small retrieval, large context |

### Embedding model selection

Use the same model for indexing and querying. Mixing models produces meaningless similarity
scores.

| Model | Dimensions | Best for |
|-------|-----------|----------|
| `text-embedding-3-large` (OpenAI) | 3072 (or lower via `dimensions`) | General-purpose, scalable |
| `voyage-3-large` (Voyage AI) | 1024 | Code and technical content |
| `embed-v4.0` (Cohere) | 1024 | Multilingual, compression |
| Open-source (e5-mistral, gte-Qwen2) | Varies | Air-gapped / self-hosted |

### Retrieval patterns

1. **Vector search alone** - fast, good for semantic similarity, bad for exact keyword matches
2. **Hybrid search** (vector + BM25/keyword) - best default. Qdrant, Weaviate, and Pinecone
   support this natively. pgvector + `tsvector` for PostgreSQL.
3. **Reranking** - retrieve more candidates (top-50), rerank with a cross-encoder or Cohere
   Rerank, return top-5. Adds latency but significantly improves relevance.
4. **Query expansion** - rephrase the user query using an LLM before retrieval. Helps when
   user queries are vague or use different terminology than the source docs.

### Vector store selection

| Store | Type | Best for |
|-------|------|----------|
| pgvector | PostgreSQL extension | Already using Postgres, <10M vectors |
| Qdrant | Self-hosted or cloud | Production self-hosted, hybrid search |
| Pinecone | Managed only | Zero-ops, serverless scaling |
| ChromaDB | Embedded / local | Prototyping, small datasets |

### Minimal RAG example (Python + pgvector)

```python
from anthropic import Anthropic
import psycopg

client = Anthropic()

def search(query: str, limit: int = 5) -> list[dict]:
    embedding = get_embedding(query)  # same model used at index time
    with psycopg.connect(DB_URL) as conn:
        rows = conn.execute(
            "SELECT content, 1 - (embedding <=> %s::vector) AS score "
            "FROM documents WHERE 1 - (embedding <=> %s::vector) > 0.7 "
            "ORDER BY embedding <=> %s::vector LIMIT %s",
            [embedding, embedding, embedding, limit],
        ).fetchall()
    return [{"content": r[0], "score": r[1]} for r in rows]

def ask(question: str) -> str:
    context = search(question)
    if not context:
        return "No relevant documents found."
    response = client.messages.create(
        model="claude-sonnet-4-6-20250514",
        max_tokens=1024,
        messages=[{"role": "user", "content": (
            f"Answer based on these documents:\n\n"
            + "\n---\n".join(d["content"] for d in context)
            + f"\n\nQuestion: {question}"
        )}],
    )
    return response.content[0].text
```

Key patterns: relevance threshold (0.7), same embedding model for index/query, context passed as user message prefix.

Read `references/rag-patterns.md` for indexing pipelines, metadata filtering, multi-index
strategies, and production RAG architecture.

---

## Agent Systems

### The agent loop

Every agent system is fundamentally: observe -> think -> act -> repeat. The differences are in
how you manage state, handle failures, and know when to stop.

```
while not done:
    observation = get_context(state)
    action = model.decide(observation, tools)
    if action.type == "final_answer":
        done = True
    else:
        result = execute_tool(action)
        state.add(result)
```

### Framework selection

| Framework | Best for | Key feature |
|-----------|----------|-------------|
| Custom loop | Simple agents, maximum control | No dependencies |
| LangGraph | Complex state machines, cycles, persistence | Graph-based, checkpointing |
| OpenAI Agents SDK | OpenAI-native, multi-agent handoffs | Sessions, tracing |
| Claude Agent SDK | Claude-native, code/file operations | Claude Code capabilities |
| Vercel AI SDK | TypeScript agents with UI streaming | ToolLoopAgent, React hooks |

### Common pitfalls

1. **Infinite loops** - always set a max iteration count. Agents will happily loop forever.
2. **Tool explosion** - more than 10-15 tools degrades model performance. Group related
   operations into fewer, more capable tools.
3. **Missing error handling** - tool failures are normal. The agent needs to recover, not crash.
4. **No cost ceiling** - a runaway agent can burn through API budget. Set per-request token
   and cost limits.
5. **Stale context** - long-running agents accumulate context. Summarize or prune periodically.

### Minimal safe agent loop (Anthropic + Python)

Combines the three non-negotiables: iteration cap, cost gate, and tool-error policy.

```python
MAX_ITERS, BUDGET_USD = 20, 5.00
TOOL_RETRY_MAX = 2  # transient failures only; retry then abort
spent = 0.0

for i in range(MAX_ITERS):
    if spent >= BUDGET_USD:
        raise BudgetExceeded(f"${spent:.2f} >= ${BUDGET_USD}")
    resp = client.messages.create(model=MODEL, max_tokens=1024, tools=tools, messages=msgs)
    spent += cost_of(resp.usage)  # input/output tokens * per-1M price
    if resp.stop_reason == "end_turn":
        return resp
    for block in resp.content:
        if block.type != "tool_use":
            continue
        for attempt in range(TOOL_RETRY_MAX + 1):
            try:
                result = dispatch(block.name, block.input); is_error = False; break
            except TransientToolError:
                if attempt == TOOL_RETRY_MAX: result, is_error = "tool failed after retries", True
            except PermanentToolError as e:
                result, is_error = f"tool aborted: {e}", True; break
        msgs.append({"role": "assistant", "content": resp.content})
        msgs.append({"role": "user", "content": [{"type": "tool_result",
            "tool_use_id": block.id, "content": str(result), "is_error": is_error}]})
raise IterationLimitExceeded(MAX_ITERS)
```

Retry transient errors (timeouts, 5xx, rate limits) with backoff; abort on permanent ones
(auth, bad input) and let the model decide next steps from the `is_error` tool_result.

Read `references/agent-patterns.md` for multi-agent architectures, human-in-the-loop patterns,
memory management, and production agent deployment.

---

## Fine-Tuning vs RAG vs Prompt Engineering

Pick the cheapest approach that meets your quality bar:

| Approach | Cost | Lead time | Best for |
|----------|------|-----------|----------|
| **Prompt engineering** | Lowest | Hours | Formatting, tone, simple tasks |
| **Few-shot examples** | Low | Hours | Pattern matching, classification |
| **RAG** | Medium | Days | Knowledge-grounded, dynamic data |
| **Fine-tuning** | High | Days-weeks | Style/behavior, latency-critical, domain specialization |

**Fine-tune when**: prompt engineering can't capture the behavior, you need consistent
style/format across thousands of outputs, or you need lower latency than RAG provides.

**Don't fine-tune when**: your data changes frequently (use RAG), you have fewer than 100
high-quality examples, or prompt engineering already works (you're just cargo-culting).

Read `references/fine-tuning.md` for data preparation, PEFT/LoRA patterns, evaluation during
training, and when to use full fine-tuning vs parameter-efficient methods.

---

## Local Inference

### Ollama (easiest path)

```bash
# Install (piping to sh - verify the URL and review the script first)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b
ollama run llama3.1:8b

# API compatible with OpenAI SDK
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.1:8b", "messages": [{"role": "user", "content": "hello"}]}'
```

### vLLM (production serving)

```bash
# Serve a model with continuous batching
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --dtype auto \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.9
```

| Tool | Best for | GPU required |
|------|----------|-------------|
| Ollama | Dev, prototyping, Mac (MLX) | No (CPU/MLX), optional GPU |
| vLLM | Production serving, high throughput | Yes |
| llama.cpp / llama-cpp-python | Minimal deps, quantized models | No (CPU), optional GPU |
| TGI (HF Text Generation Inference) | HF model hub integration | Yes |

Read `references/local-inference.md` for quantization choices, model selection, GPU memory
estimation, and production serving configuration.

---

## Cost Optimization

### Token budgeting

Know your costs before you scale:

```
cost_per_request = (input_tokens * input_price + output_tokens * output_price) / 1_000_000
monthly_cost = cost_per_request * requests_per_day * 30
```

### Strategies (ordered by impact)

1. **Model routing** - use cheaper models for easy tasks, frontier models for hard ones.
   Route by task complexity, not by default.
2. **Caching** - cache identical or semantically similar requests. Anthropic prompt caching
   reduces repeated prefix costs by 90%.
3. **Prompt optimization** - shorter prompts cost less. Cut examples, compress instructions.
4. **Batch APIs** - Anthropic and OpenAI offer 50% discounts for async batch processing.
5. **Output length limits** - set `max_tokens` to what you actually need, not 4096 "just in case."
6. **Context pruning** - for multi-turn conversations, summarize history instead of sending
   the full transcript.

---

## Safety and Guardrails

Input validation (prompt injection), output validation (schema + content policy), PII handling
(strip before external API calls), rate limiting (per-user + per-IP), content filtering, and
audit logging (redact PII). These are non-negotiable for production AI apps.

Read `references/safety.md` for prompt injection defense patterns, output validation schemas,
PII detection setup, and content policy implementation.

---

## Production Checklist

- [ ] API keys in environment variables or secret manager (never in code)
- [ ] Retry logic with exponential backoff and jitter on all LLM calls
- [ ] Timeouts set on all LLM calls (model inference can hang)
- [ ] Rate limiting on AI-powered endpoints
- [ ] Cost monitoring and alerting (daily spend, per-request cost tracking)
- [ ] Structured logging of prompts, responses, latency, token usage
- [ ] Evaluation suite running in CI (regression detection)
- [ ] Model fallback chain configured (primary -> secondary -> error response)
- [ ] Input validation and prompt injection defense
- [ ] Output validation before returning to users
- [ ] PII scrubbed from external API calls
- [ ] Max token limits set per request type
- [ ] Health checks on model endpoints (especially self-hosted)
- [ ] A/B testing infrastructure for prompt and model changes

---

## Reference Files

- `references/llm-patterns.md` - multi-turn tool use, parallel tool calls, error recovery, provider gotchas
- `references/rag-patterns.md` - indexing pipelines, metadata filtering, multi-index, production architecture
- `references/agent-patterns.md` - multi-agent, human-in-the-loop, memory management, production deployment
- `references/evaluation.md` - promptfoo setup, assertion types, CI integration, RAG/agent evals, red teaming
- `references/fine-tuning.md` - data prep, PEFT/LoRA, training evaluation, full vs parameter-efficient methods
- `references/local-inference.md` - quantization, model selection, GPU memory, production serving config
- `references/safety.md` - prompt injection defense, output validation, PII handling, content filtering, audit logging

## Related Skills

- **mcp** - handles MCP server development (the protocol/tooling layer). This skill handles
  the application layer - how to build apps that call models, retrieve context, and orchestrate
  agents. If building an MCP server, use mcp. If building an app that uses AI, use this skill.
- **prompt-generator** - for crafting and refining individual prompts. This skill covers prompt
  template management and patterns within applications; prompt-generator handles one-off prompt
  creation and iteration.
- **databases** - for general database operations. This skill covers vector store integration
  for RAG; databases handles engine configuration, schema design, and traditional DB operations.
- **security-audit** - for security review of AI application code. This skill provides
  guardrail patterns; security-audit provides the audit methodology.
- **code-review** - for reviewing AI application code quality beyond AI-specific patterns.

---

## Rules

1. **Start with the simplest approach.** Direct SDK calls before frameworks. Prompt engineering
   before fine-tuning. Single agent before multi-agent. Complexity is a cost.
2. **Never hardcode API keys.** Environment variables or secret managers. No exceptions.
3. **Always stream user-facing responses.** Buffered LLM responses feel broken. Stream.
4. **Set token limits explicitly.** `max_tokens` on every call. Unbounded generation wastes
   money and risks timeouts.
5. **Match embedding models.** Same model for indexing and querying. Mixing models produces
   meaningless similarity scores that silently degrade retrieval quality.
6. **Validate model output.** Check for refusals, empty content, malformed structured output.
   Models fail in creative ways - handle all of them.
7. **Budget before you batch.** Calculate cost before running batch operations. A 100k-row
   embedding job at the wrong model can cost thousands.

```python
# Cost-tracking guard before each LLM call
BUDGET_USD = 0.50  # per-request ceiling
input_price, output_price = 3.00, 15.00  # per 1M tokens (claude-sonnet)
total_tokens = count_tokens(messages)
estimated = (total_tokens * input_price + max_tokens * output_price) / 1_000_000
if estimated > BUDGET_USD:
    raise BudgetExceeded(f"Estimated ${estimated:.4f} exceeds ceiling ${BUDGET_USD}")
```
8. **Evaluate with data, not vibes.** Structured evals with datasets and metrics. "It looks
   good" is not a quality gate.
9. **Cap agent iterations.** Set a max loop count. Runaway agents burn budget and produce
   garbage. 10-20 iterations is a reasonable default.
10. **Run the AI self-check.** Every generated AI/ML code gets verified against the checklist
    above before returning.
