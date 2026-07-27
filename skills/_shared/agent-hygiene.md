# Agent Hygiene

Cross-cutting discipline for any AI agent output, independent of what the skill's
domain checks cover. These five items are not skill-specific self-checks - they
are baseline agent hygiene, checked once here instead of duplicated per skill.

- [ ] **Current source checked**: dated versions, CLI flags, API names, and support windows are verified against primary docs before repeating them
- [ ] **Hidden state identified**: local config, credentials, caches, contexts, branches, cluster targets, or previous runs are made explicit before acting
- [ ] **Verification is real**: final checks exercise the actual runtime, parser, service, or integration point instead of only linting prose or happy paths
- [ ] **Routing overlap checked**: overlapping skills, trigger terms, and "When NOT to use" boundaries are checked before returning guidance
- [ ] **Spec claims verified**: claims about tool behavior, output contracts, or repo conventions are checked against current docs, scripts, or skill files

<!-- maintainer-notes:not-shipped
Everything above this marker is the portable hygiene checklist. It is the single
source of truth and is copied verbatim into each skill's own
references/agent-hygiene.md by scripts/gen-contract-refs.sh (drift-guarded by
scripts/check-contract-sync.sh). This marker and everything below it are stripped
before copying, so installed skills never see repo-internal build notes. Edit the
checklist above, then re-run the generator.
-->
