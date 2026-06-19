---
name: code-slimming
description: >
  · Audit read-only code slimming: dead code, unused files, duplicate blocks, wrapper removal, commented-out code. Triggers: 'slim codebase', 'dead code', 'unused functions', 'dedupe'. Not for bugs or broad reviews.
license: MIT
compatibility: "None - works on any codebase"
metadata:
  source: iuliandita/skills
  date_added: "2026-05-02"
  effort: medium
  argument_hint: "[scope-or-diff]"
---

# Code Slimming: Read-Only Refactor Opportunity Audit

Find behavior-preserving opportunities to make a codebase smaller, clearer, and less repetitive.
This skill reports opportunities only. It does not edit code and does not write tests.

It works on four slimming axes:

1. **Dead code** - unused functions, methods, variables, parameters, imports, types, exports,
   constants, branches, files, and dependencies that nothing reaches.
2. **Redundant code** - duplicate or near-duplicate blocks, whether across the repo or repeated
   inside a single file, including exact copy-paste clones.
3. **Wrapper and indirection removal** - thin layers that forward without adding a real role.
4. **Comment volume** - commented-out code, comments that restate the code, and banner walls that
   add bytes without signal. Comments should be minimal and earn their place.

The goal is not fewer lines at any cost. The goal is lower maintenance burden with behavior,
performance, readability, and validation made explicit.

## When to use

- Finding behavior-preserving opportunities to simplify a repository, package, module, or PR
  without implementing them
- Hunting dead code: unused functions, variables, imports, types, exports, unreachable branches,
  orphan files, and unused dependencies (Step 4 enumerates the full set)
- Auditing duplicated logic, schemas, handlers, or adapters, and redundant blocks repeated across
  the repo or inside a single file, including exact clones
- Trimming comment volume: commented-out code, comments that restate the code, and banner walls
- Finding safe centralization candidates before a cleanup/refactor PR, or reviewing a bot or human
  cleanup PR that claims to reduce code size
- Ranking maintainability refactors by value, risk, and validation needs, when the goal is smaller
  behavior-preserving structure rather than general cleanliness or AI-slop detection

## When NOT to use

- Bug-focused reviews, regressions, races, edge cases, or crashes - use **code-review**
- General cleanup, naming, AI tells, dependency creep, overengineering, comment noise as a
  quality smell, or duplicate-code-as-slop without an explicit slimming goal - use **anti-slop**.
  (Comment lane: code-slimming deletes commented-out code, restating comments, and banner walls;
  anti-slop judges comment noise as a smell; anti-ai-prose rewrites AI-voiced comment text.)
- Rewriting comments or docstrings for tone and AI voice (not deleting them) - use **anti-ai-prose**
- Security vulnerabilities, secret scanning, auth flaws, or exploitability - use **security-audit**
- Writing, debugging, or adding validation tests for a slimming recommendation - use **testing**
- Broad quick merge checks - use **full-review**
- Comprehensive repo audits across all applicable dimensions - use **deep-audit**
- Direct implementation work - use the relevant language, framework, or domain skill

## Routing boundaries

| User intent | Use |
|---|---|
| "Slim this codebase", "find safe deletions", "review LOC deletion" | **code-slimming** |
| "Find dead/unused code", "unused functions/files", "remove duplicates" | **code-slimming** |
| "Delete commented-out code", "cut these comment walls down" | **code-slimming** |
| "Remove this wrapper/indirection layer", "inline this passthrough" | **code-slimming** |
| "Clean this up", "does this look AI-written?", "overengineered/verbose" | **anti-slop** |
| "These comments are noisy/AI-slop, clean them up" | **anti-slop** |
| "This prose/comments read AI-written, rewrite the voice" | **anti-ai-prose** |
| "Review this", "find bugs", "sanity check", "will this break?" | **code-review** |
| "Write/add/debug tests for this refactor" | **testing** |
| "Run all checks", "full review", "audit this repo" | **full-review** or **deep-audit** |
| "Implement the slimming/refactor" | Relevant language/framework/domain skill |

Do not activate this skill for generic review, cleanup, or audit wording unless the user explicitly
asks for slimming, deduplication, deletion, wrapper removal, or behavior-preserving size reduction.

---

## AI Self-Check

Before returning a code-slimming audit, verify:

- [ ] **Read-only boundary held**: no source files were edited and no tests were written
- [ ] **Behavior preserved**: every recommendation names the behavior that must stay identical
- [ ] **Value explained**: every recommendation states why the slimmer shape is better
- [ ] **Tradeoffs assessed**: performance, coupling, readability, bundle size, allocation count,
  and test brittleness were considered where relevant
- [ ] **Validation named**: each `Do now` or `Do with tests` item lists concrete validation
  commands or test coverage needs
- [ ] **No abstraction theater**: no vague "make this generic" or "create a base class" advice
  without the proposed shape
- [ ] **Duplication judged in context**: likely divergence, framework conventions, and explicitness
  were considered before recommending centralization
- [ ] **Defensive duplication preserved**: repeated guards across trust, process, persistence, or
  public-API boundaries were not flagged for removal solely because an upstream layer validates the
  same condition
- [ ] **Dead code proven, not guessed**: every "unused" claim cites a no-reference search and rules
  out reflection, dynamic dispatch, DI, serialization, plugin/CLI/route registration, public API,
  conditional compilation, and test discovery before recommending deletion
- [ ] **Comment trimming is deletion, not rewriting**: only commented-out code, comments that
  restate the code, and dead banner walls are flagged; tone and AI-voice rewrites are routed to
  anti-ai-prose, and load-bearing comments (why, invariants, links, license, lint pragmas) are kept
- [ ] **Correctness and security routed**: bugs go to code-review; vulnerabilities go to security-audit
- [ ] **Routing lane held**: generic cleanup, slop, correctness, security, test-writing,
  broad-review, and implementation work were routed instead of reported as code-slimming findings
- [ ] **Current source checked**: dated versions, CLI flags, API names, and support windows are verified against primary docs before repeating them
- [ ] **Hidden state identified**: local config, credentials, caches, contexts, branches, cluster targets, or previous runs are made explicit before acting
- [ ] **Verification is real**: final checks exercise the actual runtime, parser, service, or integration point instead of only linting prose or happy paths
- [ ] **Routing overlap checked**: recommendations do not duplicate anti-slop, code-review, testing, full-review, or deep-audit responsibilities
- [ ] **Spec claims verified**: any statement about skill behavior, output contracts, or repo conventions is checked against current skill files and scripts

---

## Performance

- Start with changed files, shared modules, and repeated directory shapes before scanning the whole repo.
- Group repeated examples into one finding with representative paths.
- Prefer cheap structural searches before expensive test suites.

---

## Best Practices

- Treat smaller code as a hypothesis, not a win.
- Treat "unused" as a claim that must be proven by search, not assumed from local reading. A symbol
  with zero static references can still be live through reflection, dynamic dispatch, DI,
  serialization, plugin/CLI/route registration, public API, conditional compilation, or test
  discovery. Prove no-reference before recommending deletion.
- Keep dead-looking code that is a stable public/exported API, a documented extension point, or
  guarded behind a feature flag, build target, or platform; deleting these changes a contract.
- Treat commented-out code as dead code: recommend deleting it, since version control already
  preserves history. Keep comments that carry intent, invariants, links, license, or lint pragmas.
- Prefer deleting wrappers over adding a new abstraction layer only after proving the wrapper has no
  boundary, policy, observability, compatibility, or lifecycle role.
- Prefer a small well-named helper over a framework-shaped base class.
- Keep domain-specific duplication when the variants are likely to diverge.
- Keep defensive duplication when checks intentionally repeat across trust boundaries, process
  boundaries, public APIs, persistence layers, or privileged operations. Do not remove a repeated
  guard just because an upstream layer appears to validate the same condition.
- Avoid centralizing across independently versioned modules, separately owned teams, protocol or API
  versions, tenant-specific behavior, or plugin/provider boundaries unless the shared contract is
  explicit and stable.
- Recommend tests before centralization when behavior differences are subtle or undercovered.

## Workflow

### Step 1: Determine scope

Pick the narrowest useful scope:

- **PR or diff** - default when uncommitted changes or a branch diff exists
- **Specific path** - use when the user names files or directories
- **Whole repo** - use when the user asks for a repo-wide slimming audit

For git repos, gather cheap preflight context before deciding:

- repo root and branch: `git rev-parse --show-toplevel`, `git branch --show-current`
- uncommitted files: `git diff --name-only`, `git diff --cached --name-only`
- branch base when available: `git merge-base HEAD @{upstream}`; otherwise detect the default
  branch and use `git merge-base HEAD origin/<default-branch>`
- default branch when needed: `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null`
  or inspect `git remote show origin`
- changed files and size: `git diff --name-only <base>...HEAD`, `git diff --stat <base>...HEAD`

Scope precedence:

1. User-provided diff or path
2. Uncommitted changes
3. Current branch against upstream
4. Current branch against the default branch
5. Whole repo, or ask one concise question when interactive

If the scope is unclear and no diff exists, ask one concise question. In headless contexts, default
to whole repo and state the assumption.

### Step 2: Gather context

Read project instructions and manifests before judging code shape:

- instruction files: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/rules`, `.windsurfrules`
- manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`,
  `build.gradle`, `CMakeLists.txt`, `Makefile`
- test and check scripts
- existing shared modules, helper directories, framework conventions, and recent related commits

Note the language and framework patterns in the report header. A good centralization in Python may
be a bad abstraction in Rust, Java, or C.

### Step 3: Identify validation without over-running it

Running existing read-only validation commands is allowed unless the user forbids command execution
or the commands have side effects. Separate validation into three passes:

1. **Early baseline validation** - cheap checks that describe current repo or diff health:
   - lint or format checks when fast and obvious
   - type or compile checks when fast and local
   - documented project validation commands
2. **Candidate coverage evidence** - after finding a slimming candidate, inspect existing tests,
   callers, snapshots, fixtures, or examples that exercise the behavior to preserve.
3. **Implementation validation** - commands or tests someone must run if they implement the
   recommendation.

Do not run expensive full suites before candidate discovery unless the user asked for PR validation
or the project makes the command cheap and standard. If a check is missing, slow, flaky, noisy,
unavailable, external-service-dependent, or exits zero while printing warnings, report that as a
validation gap. Do not call an opportunity safe when validation is absent.

Passing current checks does not by itself make a proposed slimming safe. `Do now` requires
behavior-specific coverage evidence, or a trivial mechanical change whose invariant is directly
verifiable. Generic lint, type, and build commands alone are not enough for behavioral
deduplication or centralization.

For future work, identify the validation an implementation must pass. Do not write tests in this
skill.

### Step 4: Search for candidates

Run the searches for all four axes. Use structural and textual searches to find:

**Dead code (unused / unreachable):**

- functions, methods, classes, variables, parameters, constants, types, and exports with no
  references anywhere in scope
- imports that are never used and dependencies in the manifest that nothing imports
- files and modules that nothing imports, requires, includes, or registers (orphans)
- unreachable code: statements after `return`/`throw`/`break`, `if (false)` branches, dead
  `case` arms, conditions that cannot be true, and feature-flag branches for removed flags
- commented-out code blocks left behind from past edits

**Redundant / duplicate code:**

- near-duplicate files, classes, structs, functions, methods, hooks, handlers, or components
- exact copy-paste clones repeated across files or repeated inside a single file
- repeated type, interface, schema, DTO, record, enum, or data container shapes
- repeated request parsing, query construction, pagination, validation, mapping, serialization, or error handling
- parallel provider, client, repository, service, or adapter implementations with the same skeleton
- dependencies or helpers duplicating standard library or framework features
- generated-looking copy-paste that survived human maintenance, after checking whether a generator,
  schema, template, or vendored source owns it

**Wrappers and bloat:**

- wrappers with little behavior beyond forwarding to another object or function
- oversized `utils`, `helpers`, `common`, `shared`, or `misc` modules
- comment walls: banner art, comments that restate the next line, and stale doc blocks

Discovery recipe:

1. Build a candidate map from changed files, same-role siblings, repeated basenames, large generic
   modules, and repeated exported symbols, routes, schemas, DTOs, handlers, parsers, validators,
   mappers, and serializers.
2. Use cheap searches before manual reading: compare same-role trees such as `providers/*`,
   `clients/*`, `services/*`, `repositories/*`, `handlers/*`, `routes/*`, and `adapters/*`; search
   repeated declarations and one-line wrappers that only forward to another call; find large generic
   modules named `utils`, `helpers`, `common`, `shared`, or `misc`.
3. For dead-code candidates, search for every reference to the symbol (definition site, call sites,
   re-exports, string-keyed lookups, config/route tables, DI registrations) before classifying it
   unused. Lean on the repo's own dead-code and clone tooling when present - it scopes the search
   and reduces both misses and false positives:

   | Concern | Common language-agnostic or per-language tools |
   |---|---|
   | Unused symbols/exports | `knip` (TS/JS; supersedes the archived `ts-prune`); `vulture`, `ruff` F401/F841 (Python); `staticcheck`, `deadcode` (Go); `cargo` `dead_code` warnings (Rust); compiler `-Wunused` (C/C++) |
   | Unused dependencies | `knip`, `depcheck` (JS); `deptry` (Python); `cargo-machete` (Rust) |
   | Copy-paste clones | `jscpd` (multi-language), `PMD CPD` (multi-language) |

   Treat tool output as a candidate list, not a verdict: confirm each hit by reading, and discount
   known false positives (reflection, dynamic dispatch, DI, serialization, plugin/CLI/route
   registration, public API, conditional compilation, test discovery). When no tooling is available,
   say so as a coverage gap.
4. For each candidate, read the full candidate files, at least one nearby caller, and nearby tests
   to see whether the behavior contract is already captured, before classifying.

Skip or de-prioritize generated files, vendored dependencies, lockfiles, snapshots, fixtures,
minified bundles, protobuf/OpenAPI generated clients, and build artifacts unless the user scopes them.
When duplication appears in generated output, recommend changing the generator, schema, or template,
or exclude it from slimming findings. Do not recommend hand-editing generated output.

Read surrounding code before judging. Similar shape is not enough. The question is whether one
shared behavior path would be clearer, safer, and easier to validate.

### Step 5: Classify opportunities

Use these labels:

- **Do now** - small, obvious, low risk, and already covered by meaningful validation
- **Do with tests** - likely worthwhile, but needs focused tests before implementation
- **Defer** - valid but too broad, risky, or low-value for current churn
- **Leave alone** - duplication is clearer, faster, intentional, or likely to diverge

These labels are audit recommendations only. Even `Do now` does not authorize this skill to edit
code; it means the proposed change appears safe for a separate implementation pass.

Every classified item must cite:

- representative file paths and line ranges
- the repeated behavior or wrapper behavior observed
- the behavior invariant that must remain identical
- existing validation evidence or the missing validation gap
- why similar-looking cases are included, excluded, or left alone

Most findings are not merge blockers. Say so clearly.

For `Do now`, cite behavior-specific validation evidence: exact test files or cases that exercise
the preserved behavior, or explain why the change is purely local, mechanical, and directly
inspectable. If you cannot cite behavior-specific evidence, classify as `Do with tests` or `Defer`.

For dead-code and commented-out-code deletions, the evidence is the no-reference proof: the search
that found zero live references and the indirection paths ruled out (reflection, dynamic dispatch,
DI, serialization, plugin/CLI/route registration, public API, conditional compilation, test
discovery). A symbol unreferenced and unreachable through any of those paths is a valid `Do now`. If
it is exported or reachable through an unproven path, classify as `Do with tests` or `Defer` and say
which path you could not rule out.

### Step 6: Evaluate tradeoffs

For every recommendation, answer:

- What behavior must remain identical?
- What gets smaller: LOC, concept count, duplicated call sites, public API surface, dependency
  count, file count, or test surface?
- What might get worse: runtime performance, bundle size, allocation count, readability, coupling,
  test brittleness, or onboarding clarity?
- Why is the proposed centralization better than the current duplication?
- What validation would prove the change is safe?
- Are duplicated checks intentionally defensive at separate boundaries, and what fails closed if one
  layer is bypassed?

If a slimmer implementation affects hot paths, rendering loops, query batching, serialization,
startup, memory layout, build output, or binary size, require performance-sensitive validation
before classifying it as `Do now`.

### Step 7: Report

It is acceptable and often correct to return zero high-value opportunities. Do not manufacture a
slimming recommendation to fill the report. Prefer a well-justified `Leave alone` finding over a
low-confidence abstraction.

The markdown template below is the body of the written deliverable. It is a read-only set of
proposals: it groups findings by action label and intentionally opts out of the checkbox Fix
protocol in the Output Contract (there is nothing for an implementer to flip here). Wrap it with the
boxed inline header and boxed conclusion table when emitting to the transcript; the conclusion table
remaps the shared columns exactly as defined in the Output Contract section below (`Type` =
`rec`/`found`, `Priority` carries `Risk`, `Action` = `proposed`/`recommend`).

Use this format:

```markdown
## Code Slimming Audit: [scope]

Context:
- Languages/frameworks: [detected]
- Baseline validation run: [commands and results; implementation validation not run because this audit is read-only]
- Validation gaps: [missing, noisy, skipped, or unavailable checks]

### High-Value Opportunities

**Do with tests** `services/*/list-items.*` - Centralize repeated pagination and filter parsing.
Affected files: `services/users/list-items.*`, `services/projects/list-items.*`
Evidence: `services/users/list-items.ts:24-58`, `services/projects/list-items.ts:19-55`
Current duplication: both modules parse the same page, limit, sort, and filter parameters.
Refactor shape: extract a shared parser with endpoint-specific allowlists.
Behavior invariant: page and limit defaults, max-limit handling, sort allowlists, and error messages stay identical.
Call-site impact: 2 endpoint handlers, no public import path changes.
Why better: one behavior path for defaults and validation, with fewer divergent call sites.
Tradeoffs: one shared helper couples list endpoints to a common pagination contract.
Risk: medium
Validation needed: add boundary tests for page and limit values, then run lint/type/build/test commands.

**Do now** `src/legacy/format.ts` - Delete unused module.
Evidence: `src/legacy/format.ts:1-120` defines `formatLegacy`; no imports of `legacy/format` or
references to `formatLegacy` in `src/`, `test/`, config, or route tables (`rg -n "legacy/format|formatLegacy"`).
No-reference proof: not exported from the package index, not referenced by string key, not a DI/CLI/route registration.
Behavior invariant: none; nothing reaches this code.
Why better: removes a whole dead module and its transitive imports.
Tradeoffs: none if the no-reference proof holds.
Risk: low
Validation needed: type and build pass after deletion; grep confirms zero references.

### Removed-Code Safety Review

Include this section only when reviewing a diff or PR that removed code.

**Needs evidence** `[area]`
Removed behavior: [code path, wrapper, branch, fallback, type, validation, or dependency removed]
Replacement path: [what now handles it]
Behavior invariant: [what must still happen]
Evidence checked: [diff lines, call sites, tests, type checks]
Risk: [low/medium/high]
Validation needed: [specific command/test/case]

### Low-Value Or Risky Opportunities

**Leave alone** `integrations/*` - Duplication is likely to diverge per provider.
Why not: each provider already has different retry, auth, pagination, and error semantics.

### Summary

- High-value opportunities: 1
- Low-value or risky opportunities: 1
- Merge blockers: none from this audit lens
- Residual risk / skipped areas: [large dirs, generated files, expensive checks, external services]
- Net recommendation: [slim / defer / leave mostly unchanged], based on risk-adjusted maintenance value, not LOC delta
```

If no useful slimming opportunities are found, say so explicitly:

```markdown
### High-Value Opportunities
None found within scope.

### Search Coverage
- Scope inspected: [diff/path/repo areas]
- Patterns checked: [dead code/unused symbols, orphan files, clones, wrappers, duplicate schemas, repeated parsers, adapters, utils, comment walls]
- Files/directories skipped: [generated/vendor/tests/etc.]
- Validation checked: [commands/tests found or unavailable]

### Why no action is recommended
- Existing duplication appears intentional because: [...]
- Thin wrappers are retained because: [...]
- Shared abstraction would likely worsen: [...]

### Low-Value Or Risky Opportunities
[optional leave-alone observations]

### Summary
- High-value opportunities: 0
- Low-value or risky opportunities: N
- Merge blockers: none from this audit lens
- Residual risk: [what was not inspected]
- Net recommendation: leave mostly unchanged
```

Keep the report concise. Show the refactor shape, not a lecture.

## Common Patterns

Pattern-by-pattern recognition aids - dead code and unused symbols, exact and intra-file clones,
commented-out code and comment walls, repeated boundary parsing, near-twin adapters, duplicate data
shapes, wrapper layers, oversized helper modules, and performance-sensitive slimming - live in
`references/patterns.md`. Consult it when a candidate's category or safe-collapse shape is unclear.

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** CODE-SLIMMING
- **Deliverable bucket:** `audits`
- **Mode:** always-on for audit and review invocations. Every invocation that analyses existing code emits the full contract - boxed inline header, body summary inline plus per-finding detail in the deliverable file, boxed conclusion, conclusion table. For a quick factual question (e.g., "what is wrapper removal?") respond freely without the contract.
- **Deliverable path:** `docs/local/audits/code-slimming/<YYYY-MM-DD>-<slug>.md`
- **Severity scale:** this skill overrides the shared P0-P3 scale, which the contract permits via its scale-migration note. Findings are classified by action - `Do now | Do with tests | Defer | Leave alone` - plus a `Risk: low | medium | high` field per finding (see the Workflow). This skill proposes deletions, not severity-ranked defects. Old -> new: P0-P3 priority is not used; `Risk` replaces the `Priority` column (see Conclusion-table columns below).
- **Conclusion-table columns** (the shared table in `references/output-contract.md` is code-review-flavored; map it for this skill): `Type` is `rec` for opportunities or `found` when reviewing removed code; the `Priority` column carries this skill's `Risk` value (`low | medium | high`), not a P-level; `Action` is `proposed` for opportunities and `recommend` for removed-code safety findings. The file-deliverable groups findings by action label (`Do now`, `Do with tests`, `Defer`, `Leave alone`), not by `## P0`-style headings.

## Related Skills

- **anti-slop** - code quality audit for AI-like patterns, over-abstraction, noisy comments,
  hallucinated APIs, and test theater.
- **anti-ai-prose** - prose-slimming for AI voice in docs, comments, and docstrings. Use when the
  goal is removing AI-written prose patterns rather than reducing code size.
- **code-review** - correctness audit for bugs, regressions, races, edge cases, and broken contracts.
- **testing** - writes and debugs tests required before implementing a slimming recommendation.
- **security-audit** - reviews security-sensitive code where "defensive" duplication may be necessary.
- **full-review** - quick four-pass merge-safety audit; does not include code-slimming by default.
- **deep-audit** - comprehensive repo audit; includes code-slimming as a Wave 2 maintainability pass.

## Rules

1. **Do not edit code.** This skill reports opportunities only.
2. **Do not write tests.** Name missing tests and route test implementation to testing.
3. **Do not chase LOC alone.** Smaller code that is slower, more coupled, or harder to understand
   is not automatically better.
4. **Require a concrete refactor shape.** Every recommendation must describe what would be
   extracted, deleted, moved, or centralized.
5. **Explain why.** Every recommendation must state the maintenance benefit and the behavior that
   must remain unchanged.
6. **Validate before calling it safe.** A `Do now` recommendation needs behavior-specific
   validation evidence, or a purely local mechanical invariant that was directly inspected.
7. **Respect language idioms.** Generic helpers, inheritance, macros, templates, reflection, and
   dynamic dispatch have different costs across Python, JavaScript/TypeScript, Java, Rust, C/C++,
   shell, and infrastructure code.
8. **Keep bugs and vulnerabilities in their lanes.** Route correctness findings to code-review and
   security findings to security-audit.
9. **Prove dead before deleting.** Never recommend deleting a symbol, file, or dependency as unused
   without a no-reference search and an explicit list of indirection paths ruled out (reflection,
   dynamic dispatch, DI, serialization, plugin/CLI/route registration, public API, conditional
   compilation, test discovery).
10. **Trim comments by deletion, not rewriting.** Flag only commented-out code, comments that
    restate the code, and dead banner walls. Keep intent, invariants, links, license, and pragmas.
    Route AI-voice prose rewrites to anti-ai-prose.
