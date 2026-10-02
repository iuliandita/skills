# AI/ML Target Versions

October 2026 snapshot. Refreshed 2026-10-02 against provider docs, PyPI, npm, GitHub releases,
and GitHub Security Advisories.
Verify current releases before pinning.

## Contents

- Model families
- Claude 5-series migration
- GPT-6.1 Sol migration
- Astra migration
- SDKs, runtimes, and tooling
- Security update (checked 2026-10-02)

## Model families

Model IDs, prices, context windows, effort levels, and lifecycle status rechecked 2026-10-02
against the Anthropic, OpenAI, and DeepSeek model, pricing, and deprecation pages. The SDK and
security dates below are separate.
Model IDs move faster than SDK versions and are not covered by routine minor-version
bumps. Verify against provider docs before pinning. Prices are USD per million input/output tokens.

| Provider | Tier | Model ID | Notes |
|----------|------|----------|-------|
| Anthropic | Frontier | `claude-fable-5-1` | $10/$50, 1M ctx, default effort `high`. Use when Opus 5.5 at higher effort still falls short |
| Anthropic | Flagship | `claude-opus-5-5` | $4/$20, 1M ctx, effort `low`..`max`, default `medium`. Adaptive thinking always on: `thinking: {type: "disabled"}` returns 400 |
| Anthropic | Balanced | `claude-sonnet-5-5` | Released 2026-09-28; $2/$10, 1M ctx, 128K output. Effort `low`, `medium`, `high` (API default), `xhigh`, `max`; adaptive thinking on by default |
| Anthropic | Fast (retiring) | `claude-haiku-4-5` | $1/$5, 200K ctx, no effort control. Alias of `claude-haiku-4-5-20251001`. Retirement not sooner than 2026-10-15 |
| Anthropic | Limited | `claude-mythos-5-1` | $10/$50, invitation-only access (Project Glasswing) |
| OpenAI | Apex | `gpt-6-astra` | $10/$50, effort `low`..`max` (`none` returns 400). Tools require Responses |
| OpenAI | Flagship | `gpt-6.1-sol` | Released 2026-09-29; $2/$10, 1,050,000 ctx, 128K output. Above 272K input, full request costs 2x input/cache and 1.5x output. Effort `low`..`max`, default `medium`; no `none`/`minimal`. Tools require Responses |
| OpenAI | Cost tier | `gpt-6-luna` | $0.10/$0.50, effort `none`..`max`, default `medium`; `minimal` is not a listed level |
| OpenAI | Previous gen | `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna` | Still listed, no deprecation notice. `gpt-5.6` routes to Sol. There is no GPT-6 Terra |
| DeepSeek | Fast | `deepseek-flash` | V4.1 Flash; legacy `deepseek-v4-flash` routes to it. Thinking on by default, `reasoning_effort` `low`/`high`/`max`, default `high` |

Sonnet 5 remains an explicit safeguard fallback, not the default for new examples. Previous
GPT-6 Sol (`gpt-6-sol`) remains a separate model; its old effort controls do not transfer to 6.1.

Availability: Anthropic lists Fable 5, Opus 5, Opus 4.8/4.7/4.6/4.5, and Sonnet 5/4.6 as legacy
but still available, so `claude-opus-5` and `claude-sonnet-4-6` still resolve; target the current
tier in new code. `claude-sonnet-4-5-20250929` was deprecated 2026-09-30 and retires 2026-11-30
(replacement `claude-sonnet-5-5`). `gpt-4o` is retired from ChatGPT (2026-02-13) but still
API-available; the `gpt-4o-2024-05-13` snapshot shuts down 2026-10-23. Every
Claude ID is a pinned snapshot; do not append a dated suffix to Claude 4.6+ IDs. A guessed suffix
like `claude-sonnet-4-6-20250514` is invalid (that date belonged to the original Sonnet 4) and
returns a 404.

## Claude 5-series migration

Checked 2026-09-30 against the [Sonnet 5.5 migration guide](https://platform.claude.com/docs/en/models/sonnet-5-5/migration-guide)
and [thinking docs](https://platform.claude.com/docs/en/build-with-claude/thinking).

- Select response blocks by `type`; `thinking` blocks can precede the first `text` block, so
  `content[0].text` breaks. In tool loops, pass thinking blocks back complete and unmodified.
- `max_tokens` caps thinking plus text even when thinking is omitted from the response. Size
  budgets for both and handle `max_tokens` and `refusal`; valid-looking partial JSON is failure.
  Sonnet 5.5 replaces `thinking: {type: "disabled"}` with `{type: "between_tools"}` at `low`,
  `medium`, or `high` effort only. That type takes no other fields; use adaptive thinking for
  `xhigh`/`max`, per-message effort changes, or reasoning tasks without tools.
- Non-default `temperature`, `top_p`, or `top_k`, manual `budget_tokens` thinking, and assistant
  prefill return 400. Use effort, prompting, and structured outputs instead.
- Forced `tool_choice` (`any`/`tool`) returns 400 on Sonnet 5.5 as on Opus 5.5, Fable 5.1, and
  Mythos 5.1. Use `auto` plus strict tools and handle no-call replies, or `output_config.format`
  for extraction. Raw schemas need the provider's supported subset plus application validation.
- Keep histories append-only when replaying Sonnet 5.5 thinking blocks. They bind to prior
  history, model, and account; edits to earlier system/tools/messages can return 400 under
  preserved-thinking enforcement. Do not assume reasoning survives a model switch.
- Longer progress notes between tool calls become `thinking` blocks, empty by default. With
  adaptive thinking, use `display: "updates"` and `thinking-display-updates-2026-08-18` (beta)
  for visible notes; `between_tools` returns summaries without a `display` field.
- Sonnet 5.5 uses Sonnet 5's tokenizer and per-token prices. Its minimum cacheable prefix is
  512 tokens, down from 1,024; cache read/5m write/1h write rates are $0.20/$2.50/$4 per MTok.
  Re-run effort and task-cost baselines; levels are recalibrated, not equivalent to Sonnet 5.
- Computer use on the Claude API and Google Cloud requires `computer_toolset_20260801`, not
  `computer_20251124`. Advisor pairings also change; check the migration guide before adopting.

DeepSeek thinking mode ignores `temperature`; with `tools`, pass `reasoning_content` back on
every later request ([thinking mode](https://api-docs.deepseek.com/guides/thinking_mode)).

## GPT-6.1 Sol migration

Checked 2026-09-30 against the [model page](https://developers.openai.com/api/docs/models/gpt-6.1-sol)
and [migration guide](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6.1-sol).

- Use Responses for tools. Chat Completions support has no tools; migrate request, output,
  and tool-result shapes rather than only replacing the model ID.
- Start `none`/`minimal` migrations at `low`; otherwise re-evaluate the effective effort.
  Supported levels are `low`, `medium` (default), `high`, `xhigh`, and `max`.
- Remove sampling parameters and logprobs; in Responses also remove
  `message.output_text.logprobs` from `include`. Use effort and native schemas instead.
- At standard rates per MTok, cache reads cost $0.10 and cache writes $2.50. Above 272K input
  tokens the full request uses 2x input/cache and 1.5x output pricing; budget the threshold.
  Follow the guide for `prompt_cache_options.ttl` when migrating older caching controls.
- Handle incomplete responses, refusals, and empty text. Preserve output items, including
  reasoning, when returning tool results; start with the [Responses example](llm-patterns.md#openai-responses-python).

## Astra migration

Checked 2026-09-08 against the [official migration guide](https://developers.openai.com/api/docs/guides/latest-model).
This compatibility check does not refresh the other provider or SDK pins above or below.

- Use Responses for tool calls; Astra's Chat Completions support does not include tools.
  Previous-generation GPT-6 Sol and Luna support Chat Completions function calling only at `reasoning_effort: "none"`
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
| Anthropic Python SDK | 1.11.0 | Major release; review migration notes before upgrading |
| Anthropic TS SDK | 0.131.0 | Claude models, streaming, tool use, structured output |
| Claude Agent SDK (TS) | 0.3.288 | Programmatic agent building with Claude Code capabilities |
| OpenAI Python SDK | 3.24.0 | Major release; GPT-6/GPT-5.6 models and Responses API |
| OpenAI Agents SDK | 0.23.1 | Multi-agent orchestration, tracing, sessions |
| Vercel AI SDK | 7.0.127 | Node.js 22+ and ESM required; agents, workflows, telemetry, multimodal APIs |
| LangChain | 1.4.3 | Review integration compatibility |
| LangGraph | 1.2.12 | Stateful agent graphs, cycles, persistence |
| LlamaIndex | 0.14.25 | RAG framework, 300+ integrations |
| Transformers | 5.18.0 | Model inference, fine-tuning, PyTorch 2.5+ required |
| vLLM | 0.30.0 | 0.28.0 is the minimum floor for the high-severity fixes (GHSA-3c86-2m5g-59q7, GHSA-25q3-v2hm-8vpf); 0.30.0 also fixes later medium/low advisories; review release notes before upgrading multi-tenant deployments |
| Ollama | 0.35.1 | Do not trust unreviewed GGUF files; see the advisory qualification below |
| pgvector (extension) | 0.8.7 | PostgreSQL extension, not the `pgvector` Python client; HNSW + IVFFlat |
| Qdrant | 1.19.1 | Self-hosted vector DB, hybrid search |
| Pinecone (Python) | 10.0.0 | Major release; review migration notes before upgrading |
| ChromaDB | 1.5.9 | Lightweight vector DB, local-first |
| promptfoo | 0.123.1 | LLM eval framework, red teaming |

## Security update (checked 2026-10-02)

- vLLM versions before 0.28.0 are affected by [LlavaOnevision2 model-code execution despite `trust_remote_code=False`](https://github.com/vllm-project/vllm/security/advisories/GHSA-3c86-2m5g-59q7) and [embedding/pooling input denial of service](https://github.com/vllm-project/vllm/security/advisories/GHSA-25q3-v2hm-8vpf). Both are fixed in 0.28.0; retain reviewed model sources and revisions after patching.
- [CVE-2026-65315](https://github.com/advisories/GHSA-9hhj-2jwx-r87p) describes Ollama GGUF allocation denial of service. The retrieved advisory has unknown affected/patched release ranges; do not infer that 0.35.1 fixes it. Restrict model upload/create/pull access and accept only reviewed model files while checking publisher remediation.
