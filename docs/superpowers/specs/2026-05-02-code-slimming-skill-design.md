# Code Slimming Skill Design

## Goal

Create a public `code-slimming` skill for read-only maintainability audits that identify
behavior-preserving opportunities to reduce code size, centralize repeated logic, and remove
unneeded abstraction. The skill should find useful cleanup work without turning every duplicate
block into a forced abstraction.

## Background

The motivating example was an external bot PR that centralized repeated Svelte route/query
boilerplate and reduced the codebase by a small net amount. The PR was mergeable after local
validation, but the marketing-driven bot framing was not the useful part. The useful part was a
focused review lens: where can a repository be smaller and easier to maintain without changing
behavior?

Existing skills partially overlap:

- `anti-slop` catches AI-generated code quality problems, over-abstraction, duplicate code, noisy
  comments, and test theater.
- `code-review` catches correctness bugs and regressions.
- `testing` handles writing and debugging tests.
- `deep-audit` is the comprehensive repo audit orchestrator.

`code-slimming` should cover maintainability opportunities that are not necessarily AI-related and
not necessarily correctness bugs. Human-written code drifts into duplicated loaders, parallel helper
types, repeated adapter shapes, stale wrappers, and oversized helper modules too.

## Skill Boundary

`code-slimming` is a read-only audit skill. It does not edit code and does not write tests. It
reports concrete refactor opportunities, expected value, risks, and validation requirements.

The skill should trigger on requests such as:

- simplify this repo
- slim this codebase
- reduce code size
- centralize duplicated logic
- deduplicate helpers/types/classes
- find refactor opportunities
- code slimming audit

The skill should not trigger for:

- bug-focused reviews, which belong to `code-review`
- AI-style cleanup, hallucinated APIs, noisy comments, or overengineered code smells, which belong
  to `anti-slop`
- security audits, which belong to `security-audit`
- writing tests, which belongs to `testing`
- implementation work, which belongs to the relevant coding or domain skill

## Workflow

The skill should follow this read-only workflow:

1. Determine scope: current diff, target directory, specific files, or whole repo.
2. Gather context: project instructions, language/framework manifests, test scripts, existing shared
   modules, route/component patterns, helper directories, and recent related commits when useful.
3. Run or identify available validation commands when practical: lint, typecheck, build, unit tests,
   targeted tests, and any project-specific check scripts.
4. Search mechanically for candidates:
   - near-duplicate files, classes, functions, hooks, loaders, or components
   - repeated type/interface shapes
   - repeated route/load/query/pagination boilerplate
   - wrappers with little behavior beyond forwarding
   - oversized `utils`, `helpers`, `common`, or `shared` modules
   - parallel provider/client/adapter implementations with the same skeleton
   - dependency or helper usage that duplicates platform/framework functionality
5. Read surrounding code before judging. A similar shape can be intentional when integrations are
   likely to diverge or when duplication is clearer than abstraction.
6. Classify each opportunity:
   - `Do now`: small, obvious, low risk, and already covered by meaningful validation.
   - `Do with tests`: likely worthwhile, but needs focused tests before implementation.
   - `Defer`: valid but risky, broad, or not worth current churn.
   - `Leave alone`: duplication is intentional, clearer, faster, or tied to divergent behavior.
7. Report ranked findings with enough detail that a later implementation agent can act without
   rediscovering the whole repo.

## Value Criteria

The skill should treat "less code" as a hypothesis, not a win by itself. For every proposed change,
it must explain why the result is better.

Each finding should answer:

- What behavior must remain identical?
- What becomes smaller: LOC, concept count, duplicate call sites, public API surface, dependency
  count, file count, or test surface?
- What might get worse: runtime performance, bundle size, allocation count, readability, coupling,
  test brittleness, or onboarding clarity?
- Why is the proposed centralization preferable to the current duplication?
- What validation would prove the change is safe?

A slimmer implementation that is slower, more coupled, or harder to reason about is only worth it
when the maintenance gain is concrete and the cost is proven negligible or irrelevant for that path.
If a refactor touches hot paths, rendering loops, query batching, serialization, startup, or build
output, the skill should require performance-sensitive validation before classifying it as `Do now`.

## Validation Rules

For an existing PR or diff, the skill should run available local checks when practical and report the
results. Common examples include lint, typecheck, build, unit tests, and targeted test commands. If a
command is missing, noisy, unavailable, or known to exit zero despite warnings, the report should say
that directly.

For proposed future work, the skill should identify the validation that an implementation must pass.
If test coverage is missing, classify the opportunity as `Do with tests` and name the specific tests
to add or inspect. The skill should not write those tests itself.

For route/component/query centralization, validation should cover the differences being unified, not
only the shared happy path. Example: pinned-vs-picker route href generation needs direct tests or
credible existing coverage before the refactor should be treated as low risk.

## Output Format

The report should be concise and PR-oriented:

```markdown
## Code Slimming Audit: [scope]

Validation:
- `command`: result
- gap: missing or noisy validation detail

### High-Value Opportunities

**Do with tests** `src/routes/*/+page.ts` - Centralize repeated route loader query construction.
Affected files: `src/routes/a/+page.ts`, `src/routes/b/+page.ts`
Current duplication: both loaders build the same paging and filter query object.
Refactor shape: extract a shared query builder with route-specific inputs.
Why better: one behavior path for paging defaults and fewer divergent call sites.
Risk: medium
Validation needed: add/inspect pinned-vs-picker href tests, run `bun run check`, `bun run test`.

### Low-Value Or Risky Opportunities

**Leave alone** `src/providers/*` - Duplication is likely to diverge per provider.
Why not: each provider already has different retry, auth, and pagination semantics.
```

Rules for output:

- Show the concrete refactor shape, not vague "make this abstract" advice.
- Group related duplicates into one finding with representative examples.
- Separate opportunities from merge blockers. Most slimming findings are not blockers.
- State when no high-value opportunities were found.
- Keep correctness bugs routed to `code-review` and security issues routed to `security-audit`.

## Integration

Add `code-slimming` as a new public skill in the collection.

Do not add it to `full-review` by default. `full-review` should remain the merge-safety quartet:
`code-review`, `anti-slop`, `security-audit`, and `update-docs`. Adding opportunity-oriented
slimming findings there would make ordinary merge checks noisier.

Add it to `deep-audit`. `deep-audit` is intentionally comprehensive, so `code-slimming` belongs in
the code-quality wave as a separate maintainability pass alongside `code-review`, `anti-slop`, and
`anti-ai-prose`. Deep audit output should keep slimming recommendations separate from bug,
security, and prose findings.

## Success Criteria

- A new `skills/code-slimming/SKILL.md` exists and follows collection conventions.
- The skill is read-only and clearly says it does not edit code or write tests.
- Routing references are accurate for `anti-slop`, `code-review`, `testing`, `security-audit`,
  `full-review`, and `deep-audit`.
- `deep-audit` includes the new skill in the appropriate wave.
- `full-review` does not include it by default.
- Collection validation passes: `./scripts/lint-skills.sh` and `./scripts/validate-spec.sh`.
- The implementation plan includes local sync/redeploy steps for the canonical skill directory if
  required by the repo workflow.
