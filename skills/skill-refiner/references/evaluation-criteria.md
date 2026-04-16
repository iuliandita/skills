# Evaluation Criteria

Immutable scoring rubric for skill-refiner. Defines how skills are scored, what
thresholds mean, and how the adaptive loop makes decisions.

**This file must not be modified during phase 1.**

---

## Scoring Model

Structural compliance is a **pass/fail gate**, not a weighted score component. A
skill that fails lint-skills.sh or validate-spec.sh is excluded from scoring until
the structural issue is fixed. When the gate passes, the composite score (0-100)
is the weighted sum of three behavior-oriented components.

### Component Weights

| Component | Weight | Source |
|---|---|---|
| Structural compliance | **gate** | lint-skills.sh + validate-spec.sh (pass/fail) |
| AI Self-Check | 40% | skill-creator review mode |
| Behavioral test | 55% | Synthetic task execution |
| Cross-model review | 5% | Secondary model flag count |

### Renormalized Weights (No Secondary Model)

When cross-model review is unavailable, redistribute the 5% proportionally:

| Component | Weight |
|---|---|
| Structural compliance | gate |
| AI Self-Check | 42% |
| Behavioral test | 58% |

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

### AI Self-Check (40%)

skill-creator's AI Self-Check checklist, scored individually:

- Each item: pass (1) or fail (0)
- Score: (passing items / applicable items) * 100
- Items not applicable to a given skill are excluded from the denominator
  (e.g., "AI self-check section" for skills that don't generate code)

### Behavioral Test (55%)

Run 2-3 synthetic test prompts per skill from `references/test-cases.md`.

**For skills without pre-written test cases**: auto-generate 2-3 prompts from the skill's
"When to use" section and quality signals from its AI Self-Check. Pre-written tests in
`test-cases.md` take precedence. Also check for a test-cases-local.md file alongside
test-cases.md for user-contributed or previously auto-generated tests. Log a warning when
using generated tests (lower quality than hand-written ones).

Score each output on four dimensions (0-25 each):

| Dimension | What it measures |
|---|---|
| Relevance | Does the output address the test scenario? |
| Completeness | Does it cover the key aspects the skill should handle? |
| Accuracy | Are the instructions, patterns, and commands correct? |
| Actionability | Could an engineer follow this output to complete the task? |

Score: average across all test prompts, normalized to 0-100.

### Cross-Model Review (5%)

Secondary model reviews the improvement diff and flags issues:

- No flags: 100
- Minor flag (verified): -20 per flag
- Minor flag (disputed by primary): discarded, no deduction
- Major flag: triggers hard veto (score becomes irrelevant)

---

## Thresholds

### Focus Threshold

| Condition | Action |
|---|---|
| Skill score > threshold | Skip in focus iterations |
| All skills > threshold | Bump threshold by 5 |
| Default threshold | 85 |
| Maximum threshold | 95 |

### Plateau Detection

| Parameter | Value |
|---|---|
| Delta threshold | 2 points |
| Trigger | No skill improves by more than delta in one iteration |
| Action | Terminate phase 1 early |

---

## Flag Definitions

### Minor Flag

Secondary model observation suggesting suboptimal quality without indicating harm.

Examples:
- "This rephrasing is slightly less clear than the original"
- "The new example is redundant with an existing one"
- "Step ordering could be improved"

**Processing:** Primary model reviews independently. Agree = deduct. Disagree = discard and log.

### Major Flag

Secondary model observation indicating harmful changes, regression, or critical content removal.

Examples:
- "This removes a security warning that was important"
- "The new workflow skips a validation step"
- "This change breaks cross-references to other skills"
- "Critical accuracy issue in a command or config example"

**Processing:** Primary model reviews with reasoning. Agree = hard revert. Disagree = escalate to circuit breaker (human review). Contested major flags always go to human.

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
- A code deletion that maintains the same score: accept (preferred)
- Restructuring that improves clarity without changing content: accept
- Adding defensive checks for impossible scenarios: reject
