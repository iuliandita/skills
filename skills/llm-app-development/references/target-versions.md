# AI/ML Target Versions

September 2026 snapshot. Refreshed 2026-09-10 against provider docs, PyPI, npm, GitHub releases,
and GitHub Security Advisories.
Verify current releases before pinning.

## Model families

Model IDs move faster than SDK versions and are not covered by routine minor-version bumps.
Verify against provider docs before pinning. Current as of September 2026:

| Provider | Tier | Model ID | Notes |
|----------|------|----------|-------|
| Anthropic | Frontier | `claude-fable-5-1` | Most capable public model for demanding reasoning and long-horizon work (released 2026-09-01) |
| Anthropic | Flagship | `claude-opus-5` | Complex reasoning and agentic coding; [released July 24, 2026](https://platform.claude.com/docs/en/models/opus-5/overview) |
| Anthropic | Balanced | `claude-sonnet-5` | Current speed/intelligence balance. 4.6+ dropped dated snapshots: the bare ID IS the pinned snapshot |
| Anthropic | Fast | `claude-haiku-4-5` | Low cost/latency. Dated snapshot: `claude-haiku-4-5-20251001` |
| OpenAI | Flagship | `gpt-5.6-sol` | Complex reasoning and coding; `gpt-5.6` is its alias |
| OpenAI | Balanced | `gpt-5.6-terra` | Balance intelligence and cost |
| OpenAI | Cost tier | `gpt-5.6-luna` | Cost-sensitive, high-volume workloads |
| OpenAI | Apex | `gpt-6-astra` | Most capable model for computer use, software engineering, and professional work; rollout began 2026-09-03 |

GPT-6 Astra access is rolling out by account and plan. Keep GPT-5.6 Sol as the fallback until the
target account exposes `gpt-6-astra`. `gpt-4o` is retired from ChatGPT (2026-02-13) but still
API-available. Do not append a dated suffix to Claude 4.6+ IDs - the bare ID is the snapshot, and a
guessed suffix like `claude-sonnet-4-6-20250514` is invalid (that date belonged to the original
Sonnet 4) and returns a 404.

## Astra migration

Checked 2026-09-08 against the [official migration guide](https://developers.openai.com/api/docs/guides/latest-model).
This compatibility check does not refresh the other provider or SDK pins above or below.

- Use Responses for tool calls; Astra's Chat Completions support does not include tools.
- Remove `temperature`, `top_p`, `top_logprobs`, and logprob requests. In Responses, remove
  `message.output_text.logprobs` from `include`; in Chat Completions, remove `logprobs`.
- When migrating from `none` or `minimal` reasoning, start at `low`; otherwise preserve the
  effective effort for the baseline comparison. Tune effort using task results, not model names.
- Map request and result shapes when moving to Responses: `input`, `max_output_tokens`, and
  `output_text` replace the simple chat example's message, budget, and result access patterns.
- For migrations from GPT-5.5 or earlier, review caching changes, including replacement of
  `prompt_cache_retention` by `prompt_cache_options.ttl` with `"30m"`.
- Verify account access and processing-tier compatibility before rollout. EU data residency
  requires Standard processing for Astra; retain a compatible fallback for unavailable accounts.

Start with the [Responses example](llm-patterns.md#openai-responses-python). Validate tool
schemas and preserve response output items, including reasoning items, when returning tool
results. Follow the [function-calling guide](https://developers.openai.com/api/docs/guides/function-calling)
for the complete loop. Async tools, mid-turn steering, and effort updates are optional designs;
adopt them only when the application can manage pending results and continuation state.

## SDKs, runtimes, and tooling

| Component | Version | Notes |
|-----------|---------|-------|
| Anthropic Python SDK | 1.4.0 | Major release; review migration notes before upgrading |
| Anthropic TS SDK | 0.124.0 | Claude models, streaming, tool use, structured output |
| Claude Agent SDK (TS) | 0.3.266 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 3.10.0 | Major release; GPT-6/GPT-5.6 models and Responses API |
| OpenAI Agents SDK | 0.22.2 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 7.0.93 | Node.js 22+ and ESM required; agents, workflows, telemetry, multimodal APIs |
| LangChain | 1.4.0 | Minor release; review integration compatibility |
| LangGraph | 1.2.11 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.24 | RAG framework, 300+ integrations |
| Transformers | 5.17.0 | Model inference, fine-tuning, PyTorch 2.4+ required |
| vLLM | 0.28.0 | Review release and security notes before upgrading multi-tenant deployments |
| Ollama | 0.33.3 | Do not trust unreviewed GGUF files; see the advisory qualification below |
| pgvector | 0.8.6 | PostgreSQL extension, HNSW + IVFFlat |
| Qdrant | 1.19.0 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 10.0.0 | Major release; review migration notes before upgrading |
| ChromaDB | 1.5.9 | Lightweight vector DB, local-first |
| promptfoo | 0.122.2 | LLM eval framework, red teaming |

## Security update (checked 2026-09-10)

- vLLM versions before 0.28.0 are affected by [LlavaOnevision2 model-code execution despite `trust_remote_code=False`](https://github.com/vllm-project/vllm/security/advisories/GHSA-3c86-2m5g-59q7) and [embedding/pooling input denial of service](https://github.com/vllm-project/vllm/security/advisories/GHSA-25q3-v2hm-8vpf). Both are fixed in 0.28.0; retain reviewed model sources and revisions after patching.
- [CVE-2026-65315](https://github.com/advisories/GHSA-9hhj-2jwx-r87p) describes Ollama GGUF allocation denial of service. The retrieved advisory has unknown affected/patched release ranges; do not infer that 0.33.3 fixes it. Restrict model upload/create/pull access and accept only reviewed model files while checking publisher remediation.
