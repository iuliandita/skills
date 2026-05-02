---
name: code-slimming
description: >
  · Audit behavior-preserving code slimming: safe deletions, deduplication, thin-wrapper removal, shared contracts. Triggers: 'slim codebase', 'deduplicate safely', 'centralize repeated logic'. Not for bugs/slop (use code-review/anti-slop).
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

The goal is not fewer lines at any cost. The goal is lower maintenance burden with behavior,
performance, readability, and validation made explicit.

## When to use

- Finding opportunities to simplify a repository, package, module, or PR
- Finding behavior-preserving refactor opportunities without implementing them
- Auditing duplicated logic, classes, structs, helpers, types, schemas, handlers, or adapters
- Looking for safe centralization candidates before a cleanup/refactor PR
- Reviewing a bot or human cleanup PR that claims to reduce code size
- Ranking maintainability refactors by value, risk, and validation needs

## When NOT to use

- Bug-focused reviews, regressions, races, edge cases, or crashes - use **code-review**
- General cleanup, naming, comments, AI tells, dependency creep, or overengineering without a deduplication/sizing goal - use **anti-slop**
- Security vulnerabilities, secret scanning, auth flaws, or exploitability - use **security-audit**
- Writing, debugging, or adding validation tests for a slimming recommendation - use **testing**
- Broad quick merge checks - use **full-review**
- Comprehensive repo audits across all applicable dimensions - use **deep-audit**
- Direct implementation work - use the relevant language, framework, or domain skill

---

## AI Self-Check

Before returning a code-slimming audit, verify:

- [ ] **Read-only boundary held**: no source files were edited and no tests were written
- [ ] **Behavior preserved**: every recommendation names the behavior that must stay identical
- [ ] **Value explained**: every recommendation states why the slimmer shape is better
- [ ] **Tradeoffs assessed**: performance, coupling, readability, bundle size, allocation count, and test brittleness were considered where relevant
- [ ] **Validation named**: each `Do now` or `Do with tests` item lists concrete validation commands or test coverage needs
- [ ] **No abstraction theater**: no vague "make this generic" or "create a base class" advice without the proposed shape
- [ ] **Duplication judged in context**: likely divergence, framework conventions, and explicitness were considered before recommending centralization
- [ ] **Correctness and security routed**: bugs go to code-review; vulnerabilities go to security-audit

---

## Performance

- Start with changed files, shared modules, and repeated directory shapes before scanning the whole repo.
- Group repeated examples into one finding with representative paths.
- Prefer cheap structural searches before expensive test suites.

---

## Best Practices

- Treat smaller code as a hypothesis, not a win.
- Prefer deleting wrappers over adding a new abstraction layer.
- Prefer a small well-named helper over a framework-shaped base class.
- Keep domain-specific duplication when the variants are likely to diverge.
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
- branch base when available: `git merge-base HEAD @{upstream}` or `git merge-base HEAD origin/main`
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
- manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `CMakeLists.txt`, `Makefile`
- test and check scripts
- existing shared modules, helper directories, framework conventions, and recent related commits

Note the language and framework patterns in the report header. A good centralization in Python may
be a bad abstraction in Rust, Java, or C.

### Step 3: Run or identify validation

For an existing PR or diff, run available local checks when practical:

- lint or format checks
- type checks or compile checks
- build commands
- unit and targeted tests
- project-specific validation scripts

If a command is missing, noisy, slow, unavailable, or exits zero while printing warnings, report that
as a validation gap. Do not call an opportunity safe when validation is absent.

Separate three kinds of validation:

- **Baseline validation** - current repo or diff health before any proposed slimming
- **Coverage evidence** - existing tests that exercise the behavior to preserve
- **Implementation validation** - commands or tests required if someone performs the slimming change

Passing current checks does not by itself make a proposed slimming safe. `Do now` requires exact
coverage evidence, or a trivial mechanical change whose invariant is directly verifiable.

For future work, identify the validation an implementation must pass. Do not write tests in this
skill.

### Step 4: Search for candidates

Use structural and textual searches to find:

- near-duplicate files, classes, structs, functions, methods, hooks, handlers, or components
- repeated type, interface, schema, DTO, record, enum, or data container shapes
- repeated request parsing, query construction, pagination, validation, mapping, serialization, or error handling
- wrappers with little behavior beyond forwarding to another object or function
- oversized `utils`, `helpers`, `common`, `shared`, or `misc` modules
- parallel provider, client, repository, service, or adapter implementations with the same skeleton
- dependencies or helpers duplicating standard library or framework features
- generated-looking copy-paste that survived human maintenance

Useful search tactics:

- list changed files, then read full files plus sibling files in the same role
- search repeated function, class, type, schema, route, and option names across the repo
- compare same-role directories such as `providers/*`, `clients/*`, `services/*`, and `repositories/*`
- find large generic modules named `utils`, `helpers`, `common`, `shared`, or `misc`
- inspect nearby tests to see whether the behavior contract is already captured

Skip or de-prioritize generated files, vendored dependencies, lockfiles, snapshots, fixtures,
minified bundles, protobuf/OpenAPI generated clients, and build artifacts unless the user scopes them.

Read surrounding code before judging. Similar shape is not enough. The question is whether one
shared behavior path would be clearer, safer, and easier to validate.

### Step 5: Classify opportunities

Use these labels:

- **Do now** - small, obvious, low risk, and already covered by meaningful validation
- **Do with tests** - likely worthwhile, but needs focused tests before implementation
- **Defer** - valid but too broad, risky, or low-value for current churn
- **Leave alone** - duplication is clearer, faster, intentional, or likely to diverge

Most findings are not merge blockers. Say so clearly.

For `Do now`, cite the exact validation evidence: test files or cases, commands run, or why the
change is purely local and mechanical. If you cannot cite that evidence, classify as `Do with tests`
or `Defer`.

### Step 6: Evaluate tradeoffs

For every recommendation, answer:

- What behavior must remain identical?
- What gets smaller: LOC, concept count, duplicated call sites, public API surface, dependency count, file count, or test surface?
- What might get worse: runtime performance, bundle size, allocation count, readability, coupling, test brittleness, or onboarding clarity?
- Why is the proposed centralization better than the current duplication?
- What validation would prove the change is safe?

If a slimmer implementation affects hot paths, rendering loops, query batching, serialization,
startup, memory layout, build output, or binary size, require performance-sensitive validation
before classifying it as `Do now`.

### Step 7: Report

Use this format:

```markdown
## Code Slimming Audit: [scope]

Context:
- Languages/frameworks: [detected]
- Validation run: [commands and results]
- Validation gaps: [missing, noisy, skipped, or unavailable checks]

### High-Value Opportunities

**Do with tests** `services/*/list-items.*` - Centralize repeated pagination and filter parsing.
Affected files: `services/users/list-items.*`, `services/projects/list-items.*`
Evidence: `services/users/list-items.ts:24-58`, `services/projects/list-items.ts:19-55`
Current duplication: both modules parse the same page, limit, sort, and filter parameters.
Refactor shape: extract a shared parser with endpoint-specific allowlists.
Behavior invariant: page and limit defaults, max-limit handling, sort allowlists, and error messages stay identical.
Why better: one behavior path for defaults and validation, with fewer divergent call sites.
Tradeoffs: one shared helper couples list endpoints to a common pagination contract.
Risk: medium
Validation needed: add boundary tests for page and limit values, then run lint/type/build/test commands.

### Low-Value Or Risky Opportunities

**Leave alone** `integrations/*` - Duplication is likely to diverge per provider.
Why not: each provider already has different retry, auth, pagination, and error semantics.

### Summary

- High-value opportunities: 1
- Low-value or risky opportunities: 1
- Merge blockers: none from this audit lens
- Residual risk / skipped areas: [large dirs, generated files, expensive checks, external services]
```

If no useful slimming opportunities are found, say so explicitly:

```markdown
### High-Value Opportunities
None found within scope.

### Low-Value Or Risky Opportunities
[optional leave-alone observations]

### Summary
- High-value opportunities: 0
- Low-value or risky opportunities: N
- Merge blockers: none from this audit lens
- Residual risk: [what was not inspected]
```

Keep the report concise. Show the refactor shape, not a lecture.

## Common Patterns

### Repeated boundary parsing

Request parsing, CLI argument normalization, env var parsing, and config loading often duplicate
defaulting and validation rules. Centralize only when the same boundary contract really applies.

### Near-twin adapters

Provider/client/repository adapters often start identical and then diverge. Recommend
centralization only when the shared part is stable and the provider-specific differences stay
explicit.

### Duplicate data shapes

Repeated DTOs, schemas, records, structs, or interfaces can be centralized when they represent the
same contract. Keep separate shapes when they describe different lifecycle stages or trust
boundaries.

### Wrapper layers

Thin wrappers that only forward calls usually add concept count without value. Prefer deleting or
inlining them unless they isolate an external dependency, provide a stable public contract, or make
testing materially easier.

### Oversized helper modules

Large `utils`, `helpers`, `common`, `shared`, or `misc` modules are often junk drawers. Recommend
splitting by domain concern or moving helpers closer to their only caller.

### Performance-sensitive slimming

Shorter code can be slower. Centralized generic code can add allocation, dynamic dispatch, reflection,
bundle weight, cache misses, or indirect calls. In hot paths, require measurement or classify as
`Defer`.

## Related Skills

- **anti-slop** - code quality audit for AI-like patterns, over-abstraction, noisy comments, hallucinated APIs, and test theater.
- **code-review** - correctness audit for bugs, regressions, races, edge cases, and broken contracts.
- **testing** - writes and debugs tests required before implementing a slimming recommendation.
- **security-audit** - reviews security-sensitive code where "defensive" duplication may be necessary.
- **full-review** - quick four-pass merge-safety audit; does not include code-slimming by default.
- **deep-audit** - comprehensive repo audit; includes code-slimming as a Wave 2 maintainability pass.

## Rules

1. **Do not edit code.** This skill reports opportunities only.
2. **Do not write tests.** Name missing tests and route test implementation to testing.
3. **Do not chase LOC alone.** Smaller code that is slower, more coupled, or harder to understand is not automatically better.
4. **Require a concrete refactor shape.** Every recommendation must describe what would be extracted, deleted, moved, or centralized.
5. **Explain why.** Every recommendation must state the maintenance benefit and the behavior that must remain unchanged.
6. **Validate before calling it safe.** A `Do now` recommendation needs existing meaningful validation or commands run during the audit.
7. **Respect language idioms.** Generic helpers, inheritance, macros, templates, reflection, and dynamic dispatch have different costs across Python, JavaScript/TypeScript, Java, Rust, C/C++, shell, and infrastructure code.
8. **Keep bugs and vulnerabilities in their lanes.** Route correctness findings to code-review and security findings to security-audit.