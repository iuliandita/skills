# Phase 0: Setup

Setup steps 1-6 that skill-refiner runs before Phase 1: configurable roots, gate and history availability, run branch, run history and rubric hash, skill inventory, evaluator identity, secondary harness probe, and the self-review fallback.

---

**Configurable roots.** Two environment variables make this workflow portable.
`SKILL_REFINER_HISTORY` (default `<repo-root>/.refiner-runs.json`) is the run-history file, and
`SKILL_REFINER_GATE_DIR` (default `<repo-root>/scripts`) is the directory holding
`lint-skills.sh` and `validate-spec.sh`. An installed-standalone copy of this skill may point
both at another location; set them before Phase 0 and use them wherever this workflow names a
path.

**Gate unavailable.** When `SKILL_REFINER_GATE_DIR` lacks `lint-skills.sh` or `validate-spec.sh`,
do not invoke the nonexistent path and do not claim structural compliance: report the structural
gate as "unavailable" for that run and continue with AI Self-Check and behavior scoring. If the
user asked for the structural gate specifically, stop and report it unavailable instead of
substituting a score. When `SKILL_REFINER_HISTORY` is absent, start a fresh baseline and skip
delta comparisons against prior runs rather than failing the run. The same rule applies to the
other `$SKILL_REFINER_GATE_DIR` helpers (`refiner-rubric-hash.sh`, `refiner-history-compact.sh`,
`check-refiner-state.sh`): when one is absent, do not invoke it, record its result "unavailable"
in the score ledger, skip the rubric-drift or state-integrity claim it would have supported, and
continue.

1. **Create feature branch**: `skill-refiner/YYYY-MM-DD-HHMMSS` from current HEAD.
   Preserve dirty worktrees; branching isolates the run, it does not imply cleanup. If already
   on a run branch for this sweep, record it instead of nesting another branch. Do not mix
   unrelated dirty files into refiner commits; isolate them with a path-limited stash only
   when authorized.
2. **Load run history**: read `$SKILL_REFINER_HISTORY` (default `.refiner-runs.json` at the
   repository root), beside `.refiner-ledger.md` (if it exists). The default sits at the
   repository root, not the `skills/` directory: a second history file in `skills/` splits the
   log and hides prior baselines.
   Use previous run data for: baseline score comparison (detect regressions from external
   changes), model/harness change detection (flag if the primary or secondary model changed
   since last run - new model = new baseline, not a comparable delta), and skip analysis
   (don't re-attempt improvements that were already tried and reverted in a recent run).
   Compute the current rubric hash with `$SKILL_REFINER_GATE_DIR/refiner-rubric-hash.sh` (pass the
   collection root as its argument when it is installed elsewhere; if absent, mark it
   "unavailable" per the note above and skip rubric-drift claims) and record it. If it
   differs from the most recent run's recorded `rubric_hash`, prior scores are not comparable:
   start a fresh baseline and do not compute deltas against the old run.
   Retention: the history keeps full detail for the most recent runs; older runs are compacted
   into `.refiner-runs-archive.json` by `$SKILL_REFINER_GATE_DIR/refiner-history-compact.sh` (skip
   if absent), run manually or periodically, never per run.
3. **Build skill inventory**: enumerate published (non-gitignored) skills and parse YAML
   frontmatter. `metadata.deprecated` is deprecated when boolean `true` or a string equal
   to `true` after trimming and case-folding, including quoted values. Missing or false
   means active; report malformed frontmatter rather than assuming active. Do not use
   string truthiness or body-text matches. Record active, notice, and published counts.
   Exclude deprecated notices and phase-2 targets (skill-creator, skill-refiner) from the
   improvement pool. Notices receive no ordinary checklist/composite score and are excluded
   from aggregates, thresholds, saturation decisions, and direct-neighbor/trigger pools.
   Keep every published notice in canonical coverage and separate pass/fail integrity and
   explicit legacy-invocation tests, following the target repository's migration policy.
   **Early exit for a named notice or a collection with no active skills**: run applicable
   lint/spec structural checks (or report gate unavailability), notice-integrity checks,
   canonical coverage checks, and explicit legacy-invocation tests. Report results and
   limitations as not scored, then stop. Bypass steps 4-15 and phase 2, including when
   `--meta` is set; do not create a baseline, aggregate, saturation result, or scored history.
   Do not redirect edits to a replacement or turn a notice into an active skill.
   If active phase-2 targets exist but the phase-1 pool is empty, skip phase-1 scoring and
   proceed to phase 2 only for a collection-wide run or explicit `--meta`, preserving its
   snapshot and human-review gates. Otherwise report the empty pool without scores.
4. **Record evaluator identity**: capture actual provider, resolved model, effective effort,
   harness and version for primary and reviewer evaluations, with redacted runtime/config
   evidence per `references/harness-detection.md`. Record unavailable fields as unknown;
   requested flags and skill effort metadata do not prove effective runtime settings.
5. **Probe for secondary harness**: run three-step validation (PATH check, config check,
   smoke test) per `references/harness-detection.md`. Announce result.
   Before sending a review payload, classify the source as public, private, or sensitive and
   verify that the user authorized sharing it with that harness/provider.
6. **If no authorized secondary is available**: **always fall back to self-review.** Spawn a fresh agent on
   the current harness with the review prompt template from `references/harness-detection.md`.
   Label as "same-model fresh-context review" only when identity is verified; otherwise use
   "unknown-model fresh-context review". Review is penalty-only and identical in form at every
   iteration that has a diff to review: verified flags deduct `cap * weight` from the composite,
   with cap 5 for a verified distinct model and cap 3 for same-model or unknown-model review. A
   clean review adds no bonus. Different harnesses alone do not establish model diversity.
   **One exception**: at baseline (iteration 1) there is no diff yet, so cross-model review is
   skipped and the baseline penalty is 0; ordinary scoring starts at iteration 2.
   Skipping review entirely is not an option - a fresh-context self-review is the minimum bar.
   If the harness doesn't support subagents, run the review prompt as a separate CLI
   invocation (`claude -p`, `codex exec`, `gemini -p`, etc.).
