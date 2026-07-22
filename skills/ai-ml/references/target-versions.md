# AI/ML Target Versions

July 2026 snapshot. Verified 2026-07-22 against provider docs, PyPI, npm, GitHub releases,
and GitHub Security Advisories.
Verify current releases before pinning.

## Model families

Model IDs move faster than SDK versions and are not covered by routine minor-version bumps.
Verify against provider docs before pinning. Current as of July 2026:

| Provider | Tier | Model ID | Notes |
|----------|------|----------|-------|
| Anthropic | Frontier | `claude-fable-5` | Most capable public model: SWE, vision, research, autonomy. Blocks high-risk domains, falls back to Opus 4.8 (GA 2026-06-09) |
| Anthropic | Flagship | `claude-opus-4-8` | Most capable: complex reasoning, long-horizon agentic coding (GA 2026-05-28) |
| Anthropic | Balanced | `claude-sonnet-5` | Current speed/intelligence balance. 4.6+ dropped dated snapshots: the bare ID IS the pinned snapshot |
| Anthropic | Fast | `claude-haiku-4-5` | Low cost/latency. Dated snapshot: `claude-haiku-4-5-20251001` |
| OpenAI | Flagship | `gpt-5.6-sol` | Complex reasoning and coding; `gpt-5.6` is its alias |
| OpenAI | Balanced | `gpt-5.6-terra` | Balance intelligence and cost |
| OpenAI | Cost tier | `gpt-5.6-luna` | Cost-sensitive, high-volume workloads |

`gpt-4o` is retired from ChatGPT (2026-02-13) but still API-available; new code should select the
appropriate GPT-5.6 tier. Do not append a dated suffix to Claude 4.6+ IDs - the bare ID is the snapshot, and a
guessed suffix like `claude-sonnet-4-6-20250514` is invalid (that date belonged to the original
Sonnet 4) and returns a 404.

## SDKs, runtimes, and tooling

| Component | Version | Notes |
|-----------|---------|-------|
| Anthropic Python SDK | 0.117.1 | Claude models, streaming, tool use, structured output |
| Anthropic TS SDK | 0.112.5 | Same capabilities, TypeScript-first |
| Claude Agent SDK (TS) | 0.3.217 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 2.46.0 | GPT-5.6 models, Responses API |
| OpenAI Agents SDK | 0.18.3 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 7.0.34 | Major: Node.js 22+ and ESM required; agents, workflows, telemetry, multimodal APIs |
| LangChain | 1.3.14 | Orchestration framework |
| LangGraph | 1.2.9 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.23 | RAG framework, 300+ integrations |
| Transformers | 5.14.1 | Model inference, fine-tuning, PyTorch 2.4+ required |
| vLLM | 0.25.1 | Upgrade from 0.23.x for June/July 2026 DoS, ReDoS, and multi-tenant memory-disclosure fixes |
| Ollama | 0.32.1 | CVE-2026-65315 has no fixed-version range yet; keep current and do not trust unreviewed GGUF files |
| pgvector | 0.8.5 | PostgreSQL extension, HNSW + IVFFlat |
| Qdrant | 1.18.3 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 9.1.0 | Managed vector DB |
| ChromaDB | 1.5.9 | Lightweight vector DB, local-first |
| promptfoo | 0.121.19 | LLM eval framework, red teaming |
