# Phase 2 and Phase 3: Meta-Improvement and Summary

Steps 16-25 of the skill-refiner workflow: the human-gated meta-improvement of skill-creator, skill-refiner, and the lint scripts against pinned snapshots, then the final report, run-history append, and branch announcement.

---

## Phase 2: Meta-Improvement

16. **Announce**: "Entering phase 2 - meta-improvement. This always requires human review."
    Enter phase 2 only for a collection run or when `--meta` was passed; a single-skill run
    that did not opt in stops after phase 1 and reports.
    Present proposed meta changes and pause before applying them. Read-only snapshots and
    preparation may happen before this checkpoint; step 22 still reviews the resulting changes.
17. **Snapshot evaluation criteria** (Rule 4: snapshot before meta):
    - Copy the complete **skill-creator** skill, its `SKILL.md` and every file under its
      `references/`, to a temp location. This includes the AI Self-Check section and
      `conventions.md`, and pins the evaluator itself.
    - Copy `references/evaluation-criteria.md` to a temp location
    These snapshots are the evaluation baseline and the evaluator for phase 2.
18. **Improve skill-creator**: run the improvement cycle (steps 11a-11k) against the pinned
    snapshot as the evaluator; invoke review mode from the snapshot path, never the live
    `skills/skill-creator/SKILL.md` being edited. Reviews of **skill-creator** and
    **skill-refiner** must not load the live copy being edited. If the harness cannot load a
    skill from a snapshot path, label their scores "self-reported" and record the failure in
    `control_failures`.
19. **Improve skill-refiner**: same process, against the snapshot
    - Compare every public `skills/*/SKILL.md` directory with the canonical `### <skill-name>`
      headings in `references/test-cases.md`. Exclude the format-template heading.
      Include deprecated notices: their canonical legacy cases remain required despite score exclusion.
    - Promote stable generated or local cases into the canonical catalog for every gap, then
      verify there are no missing, duplicate, or orphan headings. This edit is phase-2-only.
20. **Improve lint scripts** (lint-skills.sh, validate-spec.sh):
    - Capture baseline: run both scripts, save full output
    - Propose improvements
    - Apply changes
    - Run regression: compare output to baseline
    - If false positives or false negatives introduced: revert
    - If clean: keep
21. **Commit phase 2**: one commit per target
    Format: `refactor(skill-refiner): meta - improve <target> (+N)`
22. **Pause for human review**: display phase 2 changes, wait for approval.
    This checkpoint is non-configurable - it fires even in `--mode auto`.
    A direct user approval such as "continue" or "proceed" counts as approval to resume.

## Phase 3: Summary

23. **Final report**: write a human-readable report first, then machine-readable run history.
    Include branch, pool, config, every changed skill, score before/after, delta, files changed,
    verification commands, peer-review flags, reverted changes, regressions found by the
    per-iteration sweep, private-skill handling, and skipped checks. If scoring was reconstructed
    after the fact, label it retroactive and state which components were not captured during the
    live loop. Do not output only JSON.
    ```
    === skill-refiner run complete ===================================
    Branch:     skill-refiner/YYYY-MM-DD-HHMMSS
    Primary:    <harness> <version> (<provider>/<resolved model>, effective effort: <level>)
    Secondary:  <same identity fields> | none (baseline only)
    Evidence:   <redacted runtime/config references; unknown fields and reasons>
    Review:     <verified cross-model | same-model | unknown-model>, cap: <5 | 3>
                <baseline: no diff, penalty 0>
    Pool:       N active skills (notices and phase-2 targets excluded)
    Inventory:  A active + D deprecated notices = P published; notice checks: pass/fail
    Config:     iterations=M, threshold=T, mode=MODE, plateau=P

    Iterations: N (of max M)
    Terminated: plateau / threshold / cap / saturated / user

    Score changes:
      skill1:  62 > 88 (+26)  [G:pass A:84 B:86 pen:0]
      skill2:  71 > 85 (+14)  [G:pass A:82 B:79 pen:0]
      ...
      skill-creator: 80 > 84 (+4)  [G:pass A:82 B:81 pen:0] [meta]
      skill-refiner: 78 > 83 (+5)  [G:pass A:80 B:79 pen:0] [meta]

    Aggregate:  active pool only: avg X.X | min X.X | max X.X
    Reverted:   X changes across Y iterations
    Contested:  Z flags escalated to human
    Regressions: none / skillA (broken reference), skillB (asymmetric boundary)
    =================================================================
    ```
24. **Write run history**: append this run's metadata to `$SKILL_REFINER_HISTORY` (the same
    file read in Phase 0 step 2) using the schema in `references/run-history-schema.md`.
    Every component score is numeric; omit a component rather than writing null. Record in
    `control_failures` every fallback to same-model or unknown-model review, every unavailable
    reviewer, and every reviewer that returned tool output instead of a verdict. When updating
    an existing history file, append the new object without reserializing the whole file; do not
    normalize or rewrite old entries just because a JSON writer changes escaping, commas, or
    whitespace. Immediately after the append, run `$SKILL_REFINER_GATE_DIR/check-refiner-state.sh`
    (if absent, mark state-integrity "unavailable" per the Phase 0 note; the commit may proceed
    with that label in the summary). If it exits non-zero, do not commit, report the validation
    error, and fix the entry first. Commit with the phase 3 summary only once the check exits 0
    or is recorded unavailable.
    Retention: the history keeps full detail for the most recent runs; older runs are compacted
    into `.refiner-runs-archive.json` by `$SKILL_REFINER_GATE_DIR/refiner-history-compact.sh`, run
    manually or periodically, never per run.
25. **Announce branch**: remind user to review and merge when ready
