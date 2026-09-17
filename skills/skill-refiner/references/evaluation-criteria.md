# Evaluation Criteria

Immutable scoring rubric for skill-refiner. Defines how skills are scored, what
thresholds mean, and how the adaptive loop makes decisions.

**This file must not be modified during phase 1.** The same applies to the test catalogs
(`test-cases.md` and `test-cases-local.md`); new cases land only in phase 2 or a separate
reviewed change.

---

## Scoring Model

Structural compliance is a **pass/fail gate**, not a weighted score component. A
skill that fails lint-skills.sh or validate-spec.sh is excluded from scoring until
the structural issue is fixed. When the gate passes, the composite score (0-100)
follows one penalty-only formula at baseline and every iteration:

```
composite = clamp0_100( (40*AI + 55*Behavioral) / 95 - cap * penalty )
```

| Symbol | Meaning |
|---|---|
| AI | AI Self-Check score, 0-100; minimum of k >= 3 fresh-context gradings |
| Behavioral | Behavioral test score, 0-100; minimum of k >= 3 fresh-context gradings |
| penalty | Sum of verified flag weights, minor = 0.2 and major = 1.0, clamped to a maximum of 1.0 |
| cap | 5 for a verified distinct-model reviewer, 3 for same-model or unknown-model fresh-context review |
| clamp0_100 | Clamp the result into the range 0-100 |

### One Formula for Baseline and Iterations

The same formula applies at baseline and every iteration. Baseline review has no diff to
review, so `penalty = 0` and the formula reduces to `(40*AI + 55*Behavioral) / 95`. Peer
review is penalty-only: a clean review adds nothing and cannot raise the score. Do not
renormalize the AI or Behavioral weights between baseline and iterations.

**Worked example.** AI = 80 and Behavioral = 80 in every case:

```
base = (40*80 + 55*80) / 95 = 7600 / 95 = 80.00

Baseline (no diff, penalty 0):                         composite = 80.00
After a NO_FLAGS review (penalty 0):                   composite = 80.00
After one verified minor flag, distinct model (cap 5): composite = 80.00 - 5*0.2 = 79.00
After one verified minor flag, same/unknown (cap 3):   composite = 80.00 - 3*0.2 = 79.40
After five verified minor flags (cap 5, penalty 1.0):  composite = 80.00 - 5*1.0 = 75.00
```

An unchanged score plus a clean review is exactly 80.00, so moving from baseline to an
iteration cannot manufacture a delta. Only a fixed defect can raise the score.

### Component Weights

| Component | Role | Source |
|---|---|---|
| Structural compliance | **gate** | lint-skills.sh + validate-spec.sh (pass/fail) |
| AI Self-Check | 40/95 of the base | skill-creator review mode |
| Behavioral test | 55/95 of the base | Synthetic task execution |
| Cross-model review | penalty-only, cap 5 or 3 | Verified flag weights |

### Fresh-Context Review (Same or Unknown Model)

Verified cross-model review requires distinct resolved model identities, regardless of harness.
Different providers, harnesses, or effort settings alone do not establish model diversity.
Record actual provider, resolved model, effective effort, harness/version, and redacted
runtime/config evidence per evaluation using `references/harness-detection.md`.

Same-model and unknown-model fresh-context reviews use `cap = 3` instead of `cap = 5`.
Unknown identity cannot use cap 5. The cap only bounds how much verified flags can deduct; it
never adds a bonus. Use the same flag deductions and veto rules in either case.

---

## Component Scoring

### Structural Compliance (gate)

Binary pass/fail per lint and validate check. The skill either passes both or it
does not participate in scoring this iteration:

- lint-skills.sh: must exit 0 for the skill directory
- validate-spec.sh: must exit 0 for the skill directory
- Any failure: exclude the skill from the composite score, report as `gated` in
  the iteration log, and surface the failure to the operator

Structural is a floor constraint, not a signal dimension. Skills that validate
get scored on behavior; skills that don't validate get fixed first.

### AI Self-Check (40/95)

skill-creator's AI Self-Check checklist, scored individually:

- Each item: pass (1) or fail (0)
- Score per grading: (passing items / applicable items) * 100
- Items not applicable to a given skill are excluded from the denominator
  (e.g., "AI self-check section" for skills that don't generate code)
- Run at least 3 independent fresh-context gradings and use the minimum (lower bound)
  as the component score, not the mean

### Behavioral Test (55/95)

Run 2-3 synthetic test prompts per skill from `references/test-cases.md`.

**For skills without pre-written test cases**: auto-generate 2-3 prompts from the skill's
"When to use" section and quality signals from its AI Self-Check. Canonical tests in
`test-cases.md` always take precedence. A `test-cases-local.md` file alongside
`test-cases.md` is read only for skills that have no canonical section, and its cases never
score the run that created them. Log a warning when using generated tests (lower quality
than hand-written ones).

Score each output on four dimensions (0-25 each):

| Dimension | What it measures |
|---|---|
| Relevance | Does the output address the test scenario? |
| Completeness | Does it cover the key aspects the skill should handle? |
| Accuracy | Are the instructions, patterns, and commands correct? |
| Actionability | Could an engineer follow this output to complete the task? |

Score: for each grading, average across all test prompts and normalize to 0-100. Run at least
3 independent fresh-context gradings and use the minimum (lower bound) as the component score,
not the mean.

Every deduction must cite an unmet listed quality signal or a concrete accuracy, completeness,
relevance, or actionability defect. Do not reserve points solely because execution is simulated,
the evaluator is cautious, or a live runtime is unavailable. Record an unavailable runtime as a
verification limit unless the skill itself falsely claims that runtime behavior was verified.

### Cross-Model Review (penalty-only)

A reviewer with verified distinct model identity reviews the improvement diff and flags issues
(the same flag rules apply to same-model or unknown-model fresh-context review at cap 3):

- No verified flags: penalty 0 (no bonus)
- Minor flag (upheld by the independent adjudicator): weight 0.2, summed and clamped to a maximum penalty of 1.0
- Minor flag (adjudicator disagrees): no penalty; log the disagreement and leave the item unresolved for the human report
- Major flag (upheld by the independent adjudicator): weight 1.0 and hard veto (revert; the penalty applies only if retained)

---

## Thresholds

### Focus Threshold

| Condition | Action |
|---|---|
| Skill score >= threshold | Skip in focus iterations; a skill exactly at the threshold is top-of-focus and skipped |
| All skills >= threshold | Bump threshold by 5, capped at 95 |
| Default threshold | 85 |
| Maximum threshold | 95 (hard cap, not overridable) |
| All skills at composite 100 (or >= 99) | Terminate phase 1 as "saturated"; do not bump |

### Plateau Detection

| Parameter | Value |
|---|---|
| Delta threshold | 2 points |
| Trigger | No skill improves by more than delta in one iteration |
| Action | Terminate phase 1 early |

### Noise Floor

A single grading is not a measurement. Each component score is the minimum of k >= 3
independent fresh-context gradings. Keep a change only when its lower-bound composite strictly
improves by at least the plateau delta (2 points) over the previous lower-bound composite.
Point-estimate moves smaller than the floor are judge variance and never keep a change, in
either direction.

---

## Flag Definitions

### Minor Flag

Secondary model observation suggesting suboptimal quality without indicating harm.

Examples:
- "This rephrasing is slightly less clear than the original"
- "The new example is redundant with an existing one"
- "Step ordering could be improved"

**Processing:** An independent fresh context, never the primary that authored the change, decides. Agree = deduct 0.2 penalty weight and log. Disagree = log the disagreement and leave the item unresolved for the human report; never silently discard it.

### Major Flag

Secondary model observation indicating harmful changes, regression, or critical content removal.

Examples:
- "This removes a security warning that was important"
- "The new workflow skips a validation step"
- "This change breaks cross-references to other skills"
- "Critical accuracy issue in a command or config example"

**Processing:** An independent fresh context, never the primary that authored the change, decides with the reviewer's reasoning. Agree = hard revert. Disagree = escalate to the human. A major flag cannot be cleared by the primary; contested major flags always go to the human.

---

## Regression Test Criteria (Lint Scripts - Phase 2 Only)

When improving lint-skills.sh or validate-spec.sh in phase 2:

1. **Capture baseline**: run script against all skills, save full output
2. **Apply improvement**
3. **Run regression comparison**:
   - No previously-passing skill now fails (no false positives introduced)
   - No previously-failing check now silently passes (no false negatives introduced)
   - New checks must be justified in commit message
4. **If regression detected**: revert the change

---

## Simplicity Criterion

All else being equal, simpler is better:

- A marginal score improvement (+1-2) that adds significant complexity: reject
- A change is kept only when the lower-bound composite strictly improves by at least the
  plateau delta (2 points), or when it preserves the score while reducing complexity or lines
  with no behavior change
- Restructuring that improves clarity without changing content: accept
- Adding defensive checks for impossible scenarios: reject
