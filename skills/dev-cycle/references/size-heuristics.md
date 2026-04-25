# Dev Cycle: Size Classification Heuristics

How to decide whether a unit of work is small (dive in), medium (judgment call), or large (brainstorm/spec).

## When this reference loads

Load in start mode (Step A2 in SKILL.md). Not needed in finish mode.

---

## Philosophy

The classification is a cost/benefit call:

- **Small**: the cost of writing a spec exceeds the task itself. Just do it.
- **Large**: the cost of NOT writing a spec - rework, scope creep, disagreement mid-flight - exceeds the spec cost. Spec first.
- **Medium**: either route works. Default to large if the user isn't time-pressured, small if they are.

Bias toward large when in doubt. The 5 minutes spent writing a spec is cheap insurance; 2 weeks of rework is not.

---

## The table

| Signal | Small | Large |
|--------|-------|-------|
| **Expected LOC** | <20 | >100 |
| **Files touched** | 1-2 | 5+ |
| **Modules touched** | 1 | 2+ |
| **New dependencies** | no | yes |
| **Public API change** | no | yes |
| **Database schema change** | no | yes |
| **Behavior change** | localized | cross-cutting |
| **Architectural decision** | no | yes |
| **User language** | "quick", "tiny", "just", "simple", "bump" | "properly", "design", "figure out", "how should we" |
| **Issue description** | one sentence | multi-paragraph |
| **Test changes needed** | minimal or none | substantial |
| **Rollback complexity** | trivial revert | multi-step |
| **Review cycles expected** | 1 | 2+ |

Match 3+ small signals without large signals -> **small**.
Match 3+ large signals -> **large**.
Mixed signals -> **medium/ambiguous** -> ask the user.

---

## Examples

### Clearly small

- "Fix the typo in the README" - 1 file, <5 LOC, no API change
- "Bump the ruff version to 0.7.0" - tooling only, lockfile update
- "Rename `getUserData` to `getUser`" - mechanical rename, search/replace
- "Add `ignore` entry for `.env.local` to gitignore" - single-line config
- "The error message says 'user' instead of 'username', fix it" - one string

### Clearly large

- "Add OAuth login" - new dependency, new endpoints, auth flow changes, DB migration
- "Migrate from Express to Fastify" - framework swap, all middleware refactored
- "Add multi-tenant support" - schema change, query rewrite, access control
- "Implement audit logging" - new infrastructure, cross-cutting concern
- "Rewrite the build system from webpack to vite" - tooling overhaul, CI changes

### Ambiguous (ask)

- "Clean up the user service" - could be slop cleanup (small) or architectural refactor (large)
- "Improve performance of the dashboard" - one query fix vs full rearchitecture
- "Modernize the auth code" - bump dep vs rewrite
- "Update the API" - one new field vs versioned breaking change
- "Fix the flaky tests" - one test (small) or deep infra issue (large)

---

## Ambiguity resolution questions

Ask at most two. Default to large if still unclear.

1. **Scope size**: "How many files or modules do you expect this to touch?"
2. **Public surface**: "Does this change behavior users or API consumers will notice?"
3. **Reversibility**: "If we ship this and need to back it out, is that a trivial revert or a coordinated rollback?"

One large answer is enough to tip ambiguous -> large.

---

## Edge cases

### Small task inside a large context

Example: "Add a field to the user table" sounds small (one migration), but if the field propagates through API response schemas, serializers, tests, and frontend types, it's actually large.

Probe: "Does this field need to surface anywhere else (API, UI, admin)?"

### Large task with small implementation

Example: "Add retry logic to the HTTP client" might be 30 lines of code but has cross-cutting behavior implications (idempotency, backoff, circuit breaking, observability).

Treat as large when the *decisions* are complex, even if the *code* is short.

### "Just a config change"

Config changes can be one line or an architecture pivot. Probe: "Which config, and what behavior does it control?" A feature flag toggle is small. Changing the database connection pooling mode is large.

### Refactors with no behavior change

"Extract this into a module" - if it's mechanical, small. If it involves interface redesign, large.

Probe: "Does the external interface stay identical?"

### "Just update the dependency"

Minor/patch bump with no API change - small. Major version bump or deprecated-API migration - large.

Probe: "Is this a major version bump, and does it deprecate APIs we use?"

---

## What to do with the classification

- **Small**: skip Step A4 (spec/brainstorm). Go straight to handoff. Suggest which skill fits the domain.
- **Medium**: offer the user both paths. "We could spec this (maybe 10 min) or dive in. Which?"
- **Large**: run Step A4. Don't skip it just because the user is eager - the spec pays for itself.

State the classification and the signals explicitly so the user can correct:

> "Classifying this as **large**. Signals: new public endpoint, new dependency (oauth library), requires migration, user said 'think this through properly'."

If the user overrides ("no, it's smaller than that"), accept with one probe: "What am I overweighting?" The answer either reveals a missing signal or confirms the user has context you don't.
