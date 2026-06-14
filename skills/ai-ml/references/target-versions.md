# AI/ML Target Versions

June 2026 snapshot. Verified 2026-06-14 against PyPI, npm, and upstream GitHub release APIs.
Verify current releases before pinning.

## Model families

Model IDs move faster than SDK versions and are not covered by routine minor-version bumps.
Verify against provider docs before pinning. Current as of June 2026:

| Provider | Tier | Model ID | Notes |
|----------|------|----------|-------|
| Anthropic | Frontier | `claude-fable-5` | Most capable public model: SWE, vision, research, autonomy. Blocks high-risk domains, falls back to Opus 4.8 (GA 2026-06-09) |
| Anthropic | Flagship | `claude-opus-4-8` | Most capable: complex reasoning, long-horizon agentic coding (GA 2026-05-28) |
| Anthropic | Balanced | `claude-sonnet-4-6` | Default coding model. 4.6+ dropped dated snapshots: the bare ID IS the pinned snapshot |
| Anthropic | Fast | `claude-haiku-4-5` | Low cost/latency. Dated snapshot: `claude-haiku-4-5-20251001` |
| OpenAI | Flagship | `gpt-5.5` | Current frontier chat model; recommended replacement for `gpt-4o` |
| OpenAI | Cost tier | `gpt-5.4-mini`, `gpt-5.4-nano` | Smaller/cheaper tiers |

`gpt-4o` is retired from ChatGPT (2026-02-13) but still API-available; new code should default to
`gpt-5.5`. Do not append a dated suffix to Claude 4.6+ IDs - the bare ID is the snapshot, and a
guessed suffix like `claude-sonnet-4-6-20250514` is invalid (that date belonged to the original
Sonnet 4) and returns a 404.

## SDKs, runtimes, and tooling

| Component | Version | Notes |
|-----------|---------|-------|
| Anthropic Python SDK | 0.109.1 | Claude models, streaming, tool use, structured output |
| Anthropic TS SDK | 0.104.1 | Same capabilities, TypeScript-first |
| Claude Agent SDK (TS) | 0.3.177 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 2.41.1 | GPT/o-series models, Responses API |
| OpenAI Agents SDK | 0.17.5 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 6.0.205 | Unified provider interface, ToolLoopAgent, streaming |
| LangChain | 1.3.9 | Orchestration framework |
| LangGraph | 1.2.5 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.22 | RAG framework, 300+ integrations |
| Transformers | 5.12.0 | Model inference, fine-tuning, PyTorch 2.4+ required |
| vLLM | 0.23.0 | High-throughput serving, continuous batching |
| Ollama | 0.30.7 | Local inference, MLX backend on Apple Silicon |
| pgvector | 0.8.2 | PostgreSQL extension, HNSW + IVFFlat |
| Qdrant | 1.18.2 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 9.1.0 | Managed vector DB |
| ChromaDB | 1.5.9 | Lightweight vector DB, local-first |
| promptfoo | 0.121.15 | LLM eval framework, red teaming |
