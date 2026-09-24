# AI/ML Target Versions

September 2026 snapshot. Refreshed 2026-09-10 against provider docs, PyPI, npm, GitHub releases,
and GitHub Security Advisories.
Verify current releases before pinning.

## Model families

Model facts checked 2026-09-24 against provider docs; the SDK and security dates below are
separate. Model IDs move faster than SDK versions and are not covered by routine minor-version
bumps. Verify against provider docs before pinning. Prices are USD per million input/output tokens.

| Provider | Tier | Model ID | Notes |
|----------|------|----------|-------|
| Anthropic | Frontier | `claude-fable-5-1` | $10/$50, 1M ctx, default effort `high`. Use when Opus 5.5 at higher effort still falls short |
| Anthropic | Flagship | `claude-opus-5-5` | $4/$20, 1M ctx, effort `low`..`max`, default `medium`. Adaptive thinking always on: `thinking: {type: "disabled"}` returns 400 |
| Anthropic | Balanced | `claude-sonnet-5` | $2/$10, 1M ctx, default effort `high`. Adaptive thinking on by default. At `low` effort, the practical cheap tier |
| Anthropic | Fast (retiring) | `claude-haiku-4-5` | $1/$5, 200K ctx, no effort control. Alias of `claude-haiku-4-5-20251001`. Retirement not sooner than 2026-10-15 |
| Anthropic | Limited | `claude-mythos-5-1` | $10/$50, invitation-only access |
| OpenAI | Apex | `gpt-6-astra` | $10/$50, effort `low`..`max` (`none` returns 400). Tools require Responses |
| OpenAI | Flagship | `gpt-6-sol` | $2/$10 up to 272K input tokens (2x input, 1.5x output above). Effort `none`..`max`, default `medium` |
| OpenAI | Cost tier | `gpt-6-luna` | $0.10/$0.50, effort `none`..`max`, default `medium`; `minimal` is not a listed level |
| OpenAI | Previous gen | `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna` | Still listed, no deprecation notice. `gpt-5.6` routes to Sol. There is no GPT-6 Terra |
| DeepSeek | Fast | `deepseek-flash` | V4.1 Flash; legacy `deepseek-v4-flash` routes to it. Thinking on by default, `reasoning_effort` `low`/`high`/`max`, default `high` |

Availability: Anthropic lists Fable 5, Opus 5, Opus 4.8/4.7/4.6/4.5, and Sonnet 4.6/4.5 as legacy
but still available, so `claude-opus-5` and `claude-sonnet-4-6` still resolve; target the current
tier in new code. `gpt-4o` is retired from ChatGPT (2026-02-13) but still API-available. Every
Claude ID is a pinned snapshot; do not append a dated suffix to Claude 4.6+ IDs. A guessed suffix
like `claude-sonnet-4-6-20250514` is invalid (that date belonged to the original Sonnet 4) and
returns a 404.

## Claude 5-series migration

Checked 2026-09-24 against the [Sonnet 5 migration guide](https://platform.claude.com/docs/en/models/sonnet-5/migration-guide)
and [thinking docs](https://platform.claude.com/docs/en/build-with-claude/thinking).

- Select response blocks by `type`; `thinking` blocks can precede the first `text` block, so
  `content[0].text` breaks. In tool loops, pass thinking blocks back complete and unmodified.
- `max_tokens` caps thinking plus text. Raise budgets sized for no-thinking output, or pass
  `thinking: {type: "disabled"}` on Sonnet 5 for short classifiers. Handle `stop_reason`
  `max_tokens` and `refusal`.
- Non-default `temperature`, `top_p`, or `top_k`, manual `budget_tokens` thinking, and assistant
  prefill return 400. Use effort, prompting, and structured outputs instead.
- Forced `tool_choice` (`any`/`tool`) works on Sonnet 5 but returns 400 on Opus 5.5, Fable 5.1,
  and Mythos 5.1; use `auto` with strict tools or `output_config.format` there.
- The newer tokenizer yields about 30% more tokens than Sonnet 4.6 and Haiku 4.5; re-run token
  counts and cost baselines. Moving from Haiku 4.5 to Sonnet 5 also doubles per-token price.

DeepSeek thinking mode ignores `temperature`; with `tools`, pass `reasoning_content` back on
every later request ([thinking mode](https://api-docs.deepseek.com/guides/thinking_mode)).

## Astra migration

Checked 2026-09-08 against the [official migration guide](https://developers.openai.com/api/docs/guides/latest-model).
This compatibility check does not refresh the other provider or SDK pins above or below.

- Use Responses for tool calls; Astra's Chat Completions support does not include tools.
  GPT-6 Sol and Luna support Chat Completions function calling only at `reasoning_effort: "none"`
  (checked 2026-09-24).
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
| Anthropic Python SDK | 1.8.0 | Major release; review migration notes before upgrading |
| Anthropic TS SDK | 0.128.0 | Claude models, streaming, tool use, structured output |
| Claude Agent SDK (TS) | 0.3.282 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 3.19.2 | Major release; GPT-6/GPT-5.6 models and Responses API |
| OpenAI Agents SDK | 0.22.3 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 7.0.114 | Node.js 22+ and ESM required; agents, workflows, telemetry, multimodal APIs |
| LangChain | 1.4.2 | Review integration compatibility |
| LangGraph | 1.2.12 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.25 | RAG framework, 300+ integrations |
| Transformers | 5.17.0 | Model inference, fine-tuning, PyTorch 2.4+ required |
| vLLM | 0.30.0 | 0.28.0 is the minimum patched floor (GHSA-3c86-2m5g-59q7, GHSA-25q3-v2hm-8vpf); review release notes before upgrading multi-tenant deployments |
| Ollama | 0.33.3 | Do not trust unreviewed GGUF files; see the advisory qualification below |
| pgvector (extension) | 0.8.6 | PostgreSQL extension, not the `pgvector` Python client; HNSW + IVFFlat |
| Qdrant | 1.19.1 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 10.0.0 | Major release; review migration notes before upgrading |
| ChromaDB | 1.5.9 | Lightweight vector DB, local-first |
| promptfoo | 0.123.1 | LLM eval framework, red teaming |

## Security update (checked 2026-09-10)

- vLLM versions before 0.28.0 are affected by [LlavaOnevision2 model-code execution despite `trust_remote_code=False`](https://github.com/vllm-project/vllm/security/advisories/GHSA-3c86-2m5g-59q7) and [embedding/pooling input denial of service](https://github.com/vllm-project/vllm/security/advisories/GHSA-25q3-v2hm-8vpf). Both are fixed in 0.28.0; retain reviewed model sources and revisions after patching.
- [CVE-2026-65315](https://github.com/advisories/GHSA-9hhj-2jwx-r87p) describes Ollama GGUF allocation denial of service. The retrieved advisory has unknown affected/patched release ranges; do not infer that 0.33.3 fixes it. Restrict model upload/create/pull access and accept only reviewed model files while checking publisher remediation.
