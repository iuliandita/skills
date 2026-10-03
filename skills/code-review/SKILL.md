---
name: code-review
description: >
  Review code and diffs for correctness: bugs, regressions, edge cases, races, and resource leaks.
license: MIT
compatibility: "Works on any codebase. Optional: git (diff scope, blame) and the project's own linters (tsc, eslint, ruff, mypy, shellcheck, terraform, ansible-lint)"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: high
  argument_hint: "<file-or-pattern>"
---

# Code Review: Deep Correctness Audit

Find bugs that actually break things. Not style, not slop - correctness, reliability, and logic errors that will bite in production.

This skill complements **code-simplification** (code quality/style) and **security-audit** (vulnerabilities/OWASP). Those catch "is the code clean?" and "is the code safe?" - this one catches "does the code actually work?"

Covers: **TypeScript/JavaScript**, **Python**, **Go**, **Java**, **Bash/Shell**, and **Infrastructure as Code** (Terraform, Ansible, Helm, Kubernetes, Docker/Compose, Proxmox/LXC). Universal patterns apply everywhere; language-specific sections add targeted checks.

## When to use

- Reviewing recent changes for bugs, regressions, edge cases, or fragile assumptions
- Sanity-checking code before merge or release
- Looking for logic errors that static tooling may miss
- Doing a focused correctness review where style and security are secondary

### The Three Questions

Every finding answers one of:

1. **Will it crash?** - null derefs, unhandled errors, resource exhaustion, missing imports
2. **Will it do the wrong thing?** - logic errors, off-by-ones, wrong comparisons, missing cases
3. **Will it break later?** - race conditions, implicit ordering, fragile assumptions, API contract drift

## When NOT to use

- Style, verbosity, or machine-generated code quality issues - use **code-simplification**
- Exploitable vulnerabilities, auth flaws, or secret scanning - use **security-audit**
- Pipeline config review, pipeline architecture, runner behavior, caching, or deployment-job bugs - use **ci-cd**
- End-of-session doc hygiene or instruction-file cleanup - use **update-docs**

## AI Self-Check

Before reporting any finding at >= 80% confidence, verify:

- [ ] **Read full context**: read the entire function/file, not just the flagged line, plus the callers when the bug depends on how it is called. A pattern that looks wrong in isolation might be correct in context
- [ ] **Check for tests**: is there a test covering this case? Is the test correct?
- [ ] **Check git blame**: is this new code or battle-tested? Exclude pre-existing issues only in a diff-scoped review
- [ ] **Check for explaining comments**: comments establish intent; check that the implementation actually satisfies that intent
- [ ] **Cite the evidence**: exact file, line, and code in the agreed review scope that proves the issue. No citation = no finding
- [ ] **Adversarial self-check**: argue against each finding. If the counter-argument is convincing, drop it
- [ ] **Construct a failing case**: every finding describes a plausible failing input, race, leak, or regression; for P0 findings, give the specific input or sequence that triggers the bug
- [ ] **Verify API/stdlib claims**: never assert API or stdlib behavior from memory. 18% of "high-confidence" AI review suggestions contain factual errors about framework behavior, so look up whether a function is stable-sorted, returns a view, or handles null before making it a finding
- [ ] **Boundary values on numeric inputs flagged**: trace zero, negative, and overflow values through the actual input contract and callers; require a reachable failure before assigning confidence
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

---

## Workflow

### Step 1: Scope the review

Default scope based on context:
- If invoked right after writing code in this session -> **self-check** (review what you just wrote)
- If there are uncommitted changes (`git diff --name-only`) -> **recent changes**
- If the user specifies files/dirs/commits -> **targeted review**
- If the user asks for the whole codebase -> **full codebase review**, prioritized as in "Prioritizing in Large Codebases" and reported by category
- Otherwise -> ask the user

**Large diffs (> 500 lines):** Chunk by file. Review each file with its surrounding context, then do a cross-file pass looking for integration issues (mismatched types across boundaries, inconsistent error handling, broken call chains). Large diffs are also a code smell worth noting in Observations.

### Step 2: Gather project context

Before reviewing any code, build context:
1. Read project instruction files (`AGENTS.md` or equivalent) if present - project conventions, patterns, known gotchas
2. Check the project's language/framework versions (package.json, pyproject.toml, go.mod, etc.)
3. Understand the architecture - monolith, microservices, CLI tool, library?
4. Note any custom error handling patterns, logging conventions, or testing requirements

This context prevents false positives. A pattern that's wrong in a React app might be correct in a Node CLI tool.

### Step 3: Run mechanical checks first (if available and practical)

Before manual review, run standard tooling to clear obvious issues - but only when it makes sense:
- **TypeScript**: `tsc --noEmit` / `eslint` (skip if no `tsconfig.json` / `.eslintrc*`, or if the project has 500+ TS files - too slow)
- **Python**: `ruff check` / `mypy` (skip if no `pyproject.toml` / `ruff.toml` / `mypy.ini`)
- **Shell**: `shellcheck` (fast, always worth running if installed)
- **Terraform**: `terraform validate` (skip if `terraform init` hasn't been run - validate requires initialized providers)
- **Ansible**: `ansible-lint` (skip if no `.ansible-lint` config and the project isn't primarily Ansible)

**When to skip a tool:**
- No config file for it in the project (no `tsconfig.json`, no `pyproject.toml`, etc.)
- Reviewing a small diff (< 5 files) - linting the whole project for a 3-file change is wasted effort
- The user just wants a quick review, not a full audit

**When a tool isn't installed** (check with `command -v <tool>`): don't skip it silently. Tell the user once which tools are missing, with the package name and install command (for example "shellcheck isn't installed - consider `pacman -S shellcheck`"), then continue the review without it.

Linters catch syntax, imports, and known anti-patterns mechanically. This skill focuses on what automated tools miss: logic errors, edge cases, incorrect assumptions, and subtle bugs that require understanding intent. Don't burn time and tokens on linter output - move to the actual review.

### Step 4: Review with four focus areas

Review the code through four lenses. These aren't sequential passes - they're dimensions to evaluate as you read. The order reflects priority: understanding intent comes first because everything else depends on it.

**Focus 1: Understand Intent**
Read the code to understand what it's supposed to do. If reviewing a diff, read the surrounding context too. Check commit messages, PR descriptions, or comments for stated intent. You can't find bugs if you don't know what "correct" looks like.

**Focus 2: Trace Logic Paths**
Follow every code path. For each branch, loop, or condition:
- What happens on the happy path?
- What happens on each error path?
- What happens at boundaries (empty, zero, max, null, negative)?
- Are all cases handled? (switch/match exhaustiveness, if/else completeness)

**Boundary value analysis** deserves special attention. Trace page=1, page=0, page=-1,
zero page size, the final page, and arithmetic overflow against the function's contract and
actual callers. Report a missing guard when invalid input can reach an operation that fails
or returns an incorrect result. `LIMIT` exceeding the remaining SQL rows is normally valid;
a slice end beyond an array may panic. Do not invent downstream division or assume every
numeric boundary is a bug. Apply the same evidence and confidence threshold as other findings.

**Focus 3: Check Contracts & Boundaries**
Examine every interface between components:
- Function signatures: are callers passing the right types/shapes?
- API boundaries: is input validated before use?
- State transitions: are preconditions checked?
- Error propagation: do errors carry enough context?
- Resource lifecycle: is everything acquired/released symmetrically?
- **Downstream impact**: when reviewing changes to exported functions, interfaces, or API endpoints, grep for all callers/consumers. For config/env var changes, check all files that reference the changed key. A boolean toggle in one file can break feature-flag logic across twelve modules.

**Focus 4: Convention Compliance**
Check against project-specific correctness rules - not style (that's code-simplification), but rules that affect whether the code works:
- Project instruction-file rules about error handling, transactions, API patterns
- Consistency with surrounding code's error handling and state management
- Framework idioms that affect correctness (not just style)
- Required test coverage for critical paths

### Step 5: Score each finding

Rate every potential issue on a confidence scale of 0-100:

| Score | Meaning | Action |
|-------|---------|--------|
| 0 | False positive. Does not hold up under scrutiny. | Discard |
| 25 | Might be real. Could also be intentional or context-dependent. | Discard |
| 50 | Evidence is mixed; the failure has not been established. | Discard |
| 75 | Very likely real, but a material assumption remains. | Borderline |
| 80+ | Supported by concrete evidence and surrounding context; severity is separate. | **Report** |
| 100 | Dead certain. The code is definitively wrong. Evidence is unambiguous. | **Report** |

**Only report findings scored >= 80.** Quality over quantity. A report with 3 real bugs beats one with 20 maybes.

**Self-review mode exception:** When reviewing code you just wrote in this session, lower the threshold to >= 70%. The cost of fixing is near-zero right now, and you can skip the git blame step (everything is new). Focus harder on logic paths and contracts - that's where fresh code has the most bugs.

**Finding cap:** If you have more than 8-10 reportable findings, something is wrong - either the code is catastrophically bad (say so in the summary) or your threshold is too low. Prioritize ruthlessly. Wall-of-text reviews get ignored.

For each significant code change, ask: **What are the three most likely failure modes?** This question catches architecture-level bugs that line-by-line review misses - especially in AI-generated code where individual lines look fine but the overall design has gaps.

Before assigning a score, run the AI Self-Check list above. If you cannot cite the evidence or construct the failing input, return to Step 4 for that finding or lower the score rather than reporting it.

### Step 6: Report

Present findings grouped by severity, with concrete fixes. See Output Format below.

---

## Universal Patterns (All Languages)

Read `references/universal-patterns.md` for the full cross-language bug catalog.

Always check these ten buckets before calling a review complete:
- logic errors
- null or absent-value hazards
- error-handling gaps
- race conditions and shared-state issues
- resource leaks and lifecycle mismatches
- boundary or edge-case breakage
- API and data-contract mismatches
- real performance traps
- correctness-relevant convention violations
- tests that pass without proving the behavior

The standard is simple: if it can return the wrong result, crash on a realistic path, or silently
rot over time, it belongs in the review.

---

## Prioritizing in Large Codebases

For full codebase reviews on repos with 100+ files, you can't read everything. Prioritize:

1. **Recently changed files** (`git log --since='2 weeks ago' --name-only`) - fresh code has more bugs
2. **Critical paths** - auth, payments, data mutations, API handlers, middleware
3. **Entry points** - main files, route definitions, CLI commands, event handlers
4. **Files without tests** - `git ls-files '*.ts' | while read f; do test -f "${f%.ts}.test.ts" || echo "$f"; done`
5. **Complex files** - long functions, high cyclomatic complexity, many branches
6. **Shared utilities** - bugs here multiply across the codebase

Skip: vendored code, generated files, test fixtures/snapshots, documentation, static assets.

For targeted reviews (diff/specific files), start with changed public interfaces, shared utilities, migrations, and concurrency boundaries, then read the full files being changed plus their immediate callers/callees. Context matters - a function that looks fine in isolation might be called incorrectly. Use tests and static analysis to validate suspected issues instead of reading the entire repo linearly.

---

## Language: TypeScript / JavaScript

Read `references/typescript.md` for the full TS/JS bug pattern catalog. Key highlights:

- **Promise pitfalls**: missing `await`, unhandled rejections, `Promise.all` partial failure, `async void`
- **Type narrowing gaps**: type assertions (`as`) bypassing runtime checks, discriminated union exhaustiveness
- **Closure traps**: stale closures in loops/effects, captured mutable variables in async callbacks
- **React-specific**: missing dependency arrays, state updates during render, memory leaks in effects
- **Node-specific**: unhandled stream errors, missing `error` event handlers on EventEmitters

## Language: Python

Read `references/python.md` for the full Python bug pattern catalog. Key highlights:

- **Mutable default arguments**: `def foo(items=[])` - the list is shared across calls
- **Exception handling**: bare `except:` catching KeyboardInterrupt/SystemExit, context loss in exception chains
- **Iterator exhaustion**: generators consumed twice silently, `map()`/`filter()` returning iterators not lists
- **Import side effects**: circular imports, module-level code that runs on import
- **Async pitfalls**: mixing sync and async, blocking the event loop, missing `await`
- **Dataclass/pydantic bugs**: mutable default fields without `default_factory`, validator side effects, `model_validate()` coercion on untrusted input
- **Attribute typos**: `self.nmae = name` silently creates a new attribute on regular classes - use `__slots__` or `@dataclass(slots=True)`

## Language: Bash / Shell

Read `references/shell.md` for the full Shell bug pattern catalog. Key highlights:

- **Word splitting**: unquoted variables breaking on spaces, glob expansion in unexpected places
- **Exit code masking**: pipes hiding failures (`cmd1 | cmd2` only checks cmd2), `$(...)` masked by `local`/`export` declarations
- **Signal handling**: missing trap for cleanup, backgrounded processes not cleaned up
- **Portability**: bashisms in `#!/bin/sh` scripts, GNU vs BSD tool differences

## Language: Java

Read `references/java.md` for the full Java bug pattern catalog. Key highlights:

- **Quarkus**: CDI scope thread safety (`@ApplicationScoped` + mutable state), `@RequestScoped` lost in reactive pipelines, `Uni`/`Multi` never subscribed, native image reflection, dev services config drift (`drop-and-create` in prod)
- **Spring Boot**: `@Transactional` proxy traps (self-invocation, non-public, final, checked exceptions), `SecurityFilterChain` ordering, WebFlux blocking calls, Reactor context/MDC loss
- **General Java**: `Optional.of()` on nullable, stream reuse, lazy eval escaping try-catch, `ConcurrentHashMap` check-then-act, equals/hashCode contract, checked exceptions swallowed in lambdas
- **Modern Java 17+**: virtual thread pinning on `synchronized`, `ThreadLocal` memory explosion with Loom, sealed class `IncompatibleClassChangeError`, `StructuredTaskScope` leak
- **AI-generated Java**: framework confusion (`@Autowired` in CDI), overcomplicated generics, concurrency blindness (2x rate), security shortcuts (1.5-2x rate)

## Language: Infrastructure as Code

Read `references/iac.md` for the full IaC bug pattern catalog. Key highlights:

- **Terraform**: resource dependencies wrong or missing, lifecycle issues with `create_before_destroy`, state drift from manual changes, data source race conditions
- **Ansible**: handlers not notified, variable precedence surprises, `when` conditions with undefined vars, idempotency violations
- **Helm**: template rendering errors only visible at deploy time, value type mismatches, missing required values
- **Kubernetes**: liveness probe killing healthy pods, resource limits causing OOMKills, missing PDB for HA
- **ArgoCD**: auto-sync with prune on production, sync wave ordering, health check misconfiguration, app-of-apps cluster targeting
- **Docker**: ENTRYPOINT shell vs exec form, multi-stage COPY from wrong stage, ARG scoping across FROM, missing .dockerignore
- **Compose**: `depends_on` without `condition: service_healthy` (race condition on startup ordering), `restart: always` without healthcheck (infinite crash loop), version field still present (deprecated since Compose v2)
- **Proxmox/LXC**: API token permissions too broad, LXC `nesting=1` without `keyctl=1` (Docker fails inside), Terraform `telmate/proxmox` provider unpinned (breaking changes), cloud-init network config mismatch between Proxmox and guest, `full_clone` when linked clone would work

## CI/CD Pipelines

Route pipeline-only findings to **ci-cd**. This reference is candidate context for tracing
an application change across its delivery boundary, not a second pipeline audit.

Read `references/cicd-pipelines.md` for the full CI/CD bug pattern catalog. Key highlights:

- **GitLab CI/CD**: `rules:` vs `only:/except:` mixing (silently rejected), unconditional final rules creating unwanted jobs, `workflow:rules` absent causing duplicate pipelines, dotenv variables used in `rules:` (don't exist yet), protected variable silently empty on non-protected branches
- **GitHub Actions**: expression injection via `${{ }}` with user-controlled input, `GITHUB_TOKEN` permission scope too broad, reusable workflow input type mismatches, concurrency group bugs canceling wrong runs
- **Forgejo Actions**: GitHub Actions compatibility gaps (missing features, different runner behavior, secrets handling differences)
- **ArgoCD advanced**: ApplicationSet generator collisions, multi-source Application gotchas, annotation-based sync options silently changing behavior, progressive delivery rollback ordering
- **Terraform advanced**: state locking race conditions, workspace isolation failures, provider alias confusion, `moved` blocks breaking plans, `import` block limitations

## AI-Age Patterns

Use this reference to find concrete behavior defects. Naming, style, and abstraction preferences
belong to **code-simplification**; vulnerability findings belong to **security-audit**. Pattern matches
and historical statistics are prompts for investigation, never evidence about the reviewed code.

Read `references/ai-age-patterns.md` for the full AI-age bug pattern catalog. Key highlights:

- **AI-generated code smells**: hallucinated APIs/dependencies (1 in 5 samples), deprecated patterns from stale training data, over-defensive error handling, unnecessary abstractions, insecure defaults
- **Agentic AI patterns**: prompt injection (#1 OWASP LLM 2025), missing rate limiting on LLM API calls, context window overflow, streaming edge cases, tool/function calling validation gaps
- **LLM SDK bugs**: provider SDK streaming + tool-calling interaction, reasoning block preservation where applicable, structured output gotchas, missing token limits or defaults
- **MCP vulnerabilities**: command injection (43% of servers), tool poisoning (5% of open-source servers), path traversal, SSRF, cross-tenant data exposure

## Databases

Read `references/databases.md` for the full database bug pattern catalog. Key highlights:

- **General SQL**: transaction misuse (partial writes, missing rollback), NULL handling (`NOT IN` with NULLs returns 0 rows), migration bugs (NOT NULL without DEFAULT on existing tables)
- **PostgreSQL**: `timestamp` vs `timestamptz` confusion, connection pool exhaustion, `jsonb` operator mixups (`->` vs `->>`), idle-in-transaction blocking autovacuum
- **MongoDB**: plain replacement passed to updateOne/updateMany (invalid update document), field name typos silently match nothing, write concern `w:0` data loss, schema-less type inconsistency
- **MySQL/MariaDB**: silent data truncation in non-strict mode, `utf8` is not real UTF-8 (use `utf8mb4`), `GROUP BY` returning arbitrary values
- **MSSQL**: `@@IDENTITY` vs `SCOPE_IDENTITY()`, VARCHAR can't store Unicode (use NVARCHAR), `TOP` without `ORDER BY`
- **ORM pitfalls**: N+1 queries, stale entity caches, enum stored as ordinal (reorder breaks data), auto-DDL in production

## Language: Go

Read `references/go.md` for the full Go bug pattern catalog. Key highlights:

- **Goroutine leaks**: goroutines blocked on channels with no receiver, missing context/done signal, no WaitGroup
- **Nil interface traps**: interface holding a typed nil pointer is not nil - `error` returned as `(*MyError)(nil)` fails nil checks
- **Defer ordering**: LIFO execution, closure capture by reference, defer in loops exhausting file descriptors
- **Channel deadlocks**: unbuffered channel send/receive in same goroutine, double close panic, timer allocation and version-dependent retention in loops
- **Error wrapping**: `%s` vs `%w` in `fmt.Errorf`, sentinel comparison with `==` instead of `errors.Is()`, custom errors missing `Unwrap()`
- **Context leaks**: `context.WithCancel`/`WithTimeout` without `defer cancel()`, ignoring request-scoped contexts
- **Data races**: concurrent map writes (fatal panic), shared slice append, read-modify-write without sync, missing `-race` in CI
- **Loop variable capture**: pre-Go 1.22 closure capture bug. Check `go.mod` first: `go 1.22` or higher means per-iteration semantics (safe); below 1.22 means the loop variable is shared across all goroutines/closures (classic capture bug). This check is version-gated - read `go.mod` before flagging. If no `go.mod` is available, state the version condition as an unresolved check; do not report a version-dependent bug as confirmed.

## Other Languages

For Rust and other languages without dedicated reference files: apply the universal patterns (sections 1-10) only. Note in the report that language-specific checks were limited to universal patterns.

---

## What NOT to Flag

- **Style/quality issues** - that's code-simplification's job.
- **Security vulnerabilities** - that's security-audit's job.
- **Pre-existing bugs** - issues on lines not touched by the current changes (when reviewing a diff).
- **Linter/compiler catches** - missing imports, type errors, formatting. The toolchain handles these.
- **Intentional trade-offs** - code comments explaining "we do X because Y" establish intent; still flag a demonstrated failure of that intent.
- **Test-only code** - relaxed error handling in test fixtures/helpers is often fine.
- **Defensive code at boundaries** - input validation on external data is correct, not a bug.
- **Known framework quirks** - patterns that look wrong but are idiomatic for the framework.
- **TODOs with issue references** - `// TODO(#1234)` shows awareness, not negligence.
- **Generated / vendored code** - lock files, compiled output, auto-generated types, vendored deps, ORM migrations.
- **Previously reviewed code** - if invoked multiple times in a session, focus on changes since the last review.
- **Rewrite requests** - do not request rewrites unless the current structure blocks correctness or maintainability.
- **Missing tests in general** - call out missing tests only when a specific behavior or risk needs coverage.

---

## Severity Classification

Each reported finding (confidence >= 80) uses the shared severity scale:

- **P0** - must fix: will crash, corrupt data, or produce wrong results in normal usage. Includes null derefs on common paths, data loss, race conditions that affect correctness, broken error propagation that hides failures, and security-adjacent logic errors such as auth bypass through a logic bug.
- **P1** - should fix: will cause problems under specific realistic conditions or degrade reliability over time. Includes edge case crashes, resource leaks, performance traps that will eventually hit, missing error handling on external operations, and convention violations that cause bugs in this codebase.
- **P2** - nice to fix: lower-urgency correctness risk, missing focused regression coverage for a confirmed bug, or maintainability issue with a plausible future failure mode.
- **P3** - backlog: real but non-urgent follow-up that should not block the reviewed change.
- **info** - informational: verified observation with no immediate action.

Rule of thumb: if you'd wake someone up at 2am over it, it's P0. If it can wait for the next sprint, it's P1. If it belongs in a backlog but still has a plausible failure mode, it's P2/P3.

---

## Output Format

Use the report templates in `references/report-format.md`: one for findings grouped by severity with before/after fixes, one for a clean review that still lists what was checked and which linters ran or were missing. Read it before writing the final report.

---

## Reference Files

- `references/universal-patterns.md` - cross-language bug patterns and failure modes
- `references/typescript.md` - TypeScript and JavaScript bug patterns
- `references/python.md` - Python bug patterns
- `references/shell.md` - shell bug patterns
- `references/java.md` - Java bug patterns
- `references/go.md` - Go bug patterns
- `references/iac.md` - infrastructure-as-code bug patterns
- `references/cicd-pipelines.md` - CI/CD bug patterns
- `references/ai-age-patterns.md` - AI-age correctness patterns and hallucination-driven bugs
- `references/databases.md` - application-level database bug patterns
- `references/report-format.md` - report templates for findings and clean reviews (read at Step 6)

---

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** CODE-REVIEW
- **Deliverable bucket:** `audits`
- **Mode:** always-on. Every invocation applies the reporting size and evidence rules in `references/output-contract.md`.
- **Deliverable path:** `docs/local/audits/code-review/<YYYY-MM-DD>-<slug>.md`
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract).

## Related Skills

- **code-simplification** - handles style, quality, and machine-generated code patterns. If the finding
  is "ugly but correct," route to code-simplification. If it would cause incorrect behavior, keep it here.
- **security-audit** - handles vulnerability detection (injection, auth bypass, credential
  exposure). Code-review catches logic bugs; security-audit catches exploitable flaws.
- **repo-audit** - orchestrates code-review, code-simplification, security-audit, and update-docs in
  parallel. Code-review is one of the four passes.
- **databases** - `references/databases.md` in this skill covers application-level DB bug
  patterns. The databases skill covers engine configuration and operations.
- **git** - for PR/MR creation and git operations. Code-review evaluates the code in PRs;
  git handles creating and managing them.

---

## Rules

- **Read before flagging.** Never flag code you haven't read in full context (see the AI Self-Check).
- **Bug or style?** If you're unsure whether a finding is a bug or a style issue, ask: "would this cause incorrect behavior?" If no, skip it; style and vulnerabilities route as in "What NOT to Flag".
- **One finding per bug, not per occurrence.** If the same pattern appears in 5 files, report it once with the affected locations. Don't pad the report.
- **Show the fix.** Every finding must include a concrete code fix, not just a description of the problem. If you can't show a fix, the finding isn't specific enough.
- **Don't repeat dismissed findings.** If the user acknowledged or dismissed a finding in this session, don't re-report it on subsequent invocations. They heard you the first time.
