---
name: code-review
description: "Use when reviewing code for bugs, logic errors, edge cases, error handling gaps, race conditions, resource leaks, or convention violations. Also trigger on 'review', 'code review', 'find bugs', 'check this', 'spot check', 'what did I miss', 'sanity check'. Not for style/slop audits (use anti-slop)."
source: custom
date_added: "2026-03-25"
effort: high
---

# Code Review: Deep Correctness Audit

Find bugs that actually break things. Not style, not slop -- correctness, reliability, and logic errors that will bite in production.

This skill complements **anti-slop** (code quality/style) and **security-audit** (vulnerabilities/OWASP). Those catch "is the code clean?" and "is the code safe?" -- this one catches "does the code actually work?"

Covers: **TypeScript/JavaScript**, **Python**, **Bash/Shell**, **Rust**, and **Infrastructure as Code** (Terraform, Ansible, Helm, Kubernetes, Docker/Compose, Proxmox/LXC). Universal patterns apply everywhere; language-specific sections add targeted checks.

## The Three Questions

Every finding answers one of:

1. **Will it crash?** -- null derefs, unhandled errors, resource exhaustion, missing imports
2. **Will it do the wrong thing?** -- logic errors, off-by-ones, wrong comparisons, missing cases
3. **Will it break later?** -- race conditions, implicit ordering, fragile assumptions, API contract drift

## When Invoked

### Step 1: Scope the review

Default scope based on context:
- If invoked right after writing code in this session -> **self-check** (review what you just wrote)
- If there are uncommitted changes (`git diff --name-only`) -> **recent changes**
- If the user specifies files/dirs/commits -> **targeted review**
- Otherwise -> ask the user

Available scopes:
- **Full codebase review** -- scan everything, report by category
- **Recent changes** -- check git diff or specific commits
- **Specific files/dirs** -- targeted review
- **Self-check** -- review code you just wrote in this session

**Large diffs (> 500 lines):** Chunk by file. Review each file with its surrounding context, then do a cross-file pass looking for integration issues (mismatched types across boundaries, inconsistent error handling, broken call chains). Large diffs are also a code smell worth noting in Observations.

### Step 2: Gather project context

Before reviewing any code, build context:
1. Read `CLAUDE.md` / `AGENTS.md` if present -- project conventions, patterns, known gotchas
2. Check the project's language/framework versions (package.json, pyproject.toml, go.mod, etc.)
3. Understand the architecture -- monolith, microservices, CLI tool, library?
4. Note any custom error handling patterns, logging conventions, or testing requirements

This context prevents false positives. A pattern that's wrong in a React app might be correct in a Node CLI tool.

### Step 3: Run mechanical checks first (if available and practical)

Before manual review, run standard tooling to clear obvious issues -- but only when it makes sense:
- **TypeScript**: `tsc --noEmit` / `eslint` (skip if no `tsconfig.json` / `.eslintrc*`, or if the project has 500+ TS files -- too slow)
- **Python**: `ruff check` / `mypy` (skip if no `pyproject.toml` / `ruff.toml` / `mypy.ini`)
- **Shell**: `shellcheck` (fast, always worth running if installed)
- **Terraform**: `terraform validate` (skip if `terraform init` hasn't been run -- validate requires initialized providers)
- **Ansible**: `ansible-lint` (skip if no `.ansible-lint` config and the project isn't primarily Ansible)

**When to skip a tool:**
- No config file for it in the project (no `tsconfig.json`, no `pyproject.toml`, etc.)
- Reviewing a small diff (< 5 files) -- linting the whole project for a 3-file change is wasted effort
- The user just wants a quick review, not a full audit

**When a tool isn't installed:** Don't silently skip it. Tell the user which tools are missing so they can install them. Example: "shellcheck isn't installed -- consider `pacman -S shellcheck` for shell script linting." This is a one-time heads-up, not a blocker -- continue the review without it.

Linters catch syntax, imports, and known anti-patterns mechanically. This skill focuses on what automated tools miss: logic errors, edge cases, incorrect assumptions, and subtle bugs that require understanding intent. Don't burn time and tokens on linter output -- move to the actual review.

### Step 4: Review with four focus areas

Review the code through four lenses. These aren't sequential passes -- they're dimensions to evaluate as you read. The order reflects priority: understanding intent comes first because everything else depends on it.

**Focus 1: Understand Intent**
Read the code to understand what it's supposed to do. If reviewing a diff, read the surrounding context too. Check commit messages, PR descriptions, or comments for stated intent. You can't find bugs if you don't know what "correct" looks like.

**Focus 2: Trace Logic Paths**
Follow every code path. For each branch, loop, or condition:
- What happens on the happy path?
- What happens on each error path?
- What happens at boundaries (empty, zero, max, null)?
- Are all cases handled? (switch/match exhaustiveness, if/else completeness)

**Focus 3: Check Contracts & Boundaries**
Examine every interface between components:
- Function signatures: are callers passing the right types/shapes?
- API boundaries: is input validated before use?
- State transitions: are preconditions checked?
- Error propagation: do errors carry enough context?
- Resource lifecycle: is everything acquired/released symmetrically?
- **Downstream impact**: when reviewing changes to exported functions, interfaces, or API endpoints, grep for all callers/consumers. For config/env var changes, check all files that reference the changed key. A boolean toggle in one file can break feature-flag logic across twelve modules.

**Focus 4: Convention Compliance**
Check against project-specific correctness rules -- not style (that's anti-slop), but rules that affect whether the code works:
- CLAUDE.md rules about error handling, transactions, API patterns
- Consistency with surrounding code's error handling and state management
- Framework idioms that affect correctness (not just style)
- Required test coverage for critical paths

### Step 5: Score each finding

Rate every potential issue on a confidence scale of 0-100:

| Score | Meaning | Action |
|-------|---------|--------|
| 0 | False positive. Doesn't hold up under scrutiny or is pre-existing. | Discard |
| 25 | Might be real. Could also be intentional or context-dependent. | Discard |
| 50 | Real issue, but minor. Nitpick territory. Won't cause production incidents. | Discard |
| 75 | Very likely real. Will impact functionality or violates explicit project rules. | Borderline |
| 80+ | Confirmed real. Verified by reading surrounding code. High impact. | **Report** |
| 100 | Dead certain. The code is definitively wrong. Evidence is unambiguous. | **Report** |

**Only report findings scored >= 80.** Quality over quantity. A report with 3 real bugs beats one with 20 maybes.

**Self-review mode exception:** When reviewing code you just wrote in this session, lower the threshold to >= 70%. The cost of fixing is near-zero right now, and you can skip the git blame step (everything is new). Focus harder on logic paths and contracts -- that's where fresh code has the most bugs.

**Finding cap:** If you have more than 8-10 reportable findings, something is wrong -- either the code is catastrophically bad (say so in the summary) or your threshold is too low. Prioritize ruthlessly. Wall-of-text reviews get ignored.

For each significant code change, ask: **What are the three most likely failure modes?** This question catches architecture-level bugs that line-by-line review misses -- especially in AI-generated code where individual lines look fine but the overall design has gaps.

Before assigning a score, verify:
- Read the full function/file, not just the flagged line
- Check if there's a test covering this case (and whether the test is correct)
- Check git blame -- is this new code or battle-tested?
- Look for comments explaining why something looks odd (if a comment explains the pattern, it's not a bug)
- **Cite the evidence.** Every >= 80% finding must reference the exact file, line, and code that proves the issue. If you can't cite it, go find it. If you can't find evidence, downgrade the score.
- **Adversarial self-check.** Before finalizing each finding, argue *against* it. Try to explain why the code is actually correct. If the counter-argument is convincing, drop the finding.
- **Construct a failing case.** For critical findings, describe the specific input or sequence that triggers the bug. If you can't construct one, it's not critical.
- **Never claim API/stdlib behavior without verifying.** 18% of "high-confidence" AI code review suggestions contain factual errors about framework behavior. If unsure whether a function is stable-sorted, returns a view, or handles null -- look it up first.

### Step 6: Report

Present findings grouped by severity, with concrete fixes. See Output Format below.

---

## Universal Patterns (All Languages)

### 1. Logic Errors (Will it do the wrong thing?)

The most dangerous category -- code that runs without errors but produces wrong results.

**Detect:**
- Off-by-one errors in loops, slices, ranges, pagination
- Wrong comparison operators (`>` vs `>=`, `==` vs `===`, `and` vs `or`)
- Inverted conditions (checking for success when you mean failure)
- Missing `break` / `return` in switch/match statements (fallthrough bugs)
- Short-circuit evaluation surprises (`&&` / `||` with side effects)
- Integer overflow/underflow in arithmetic
- Floating-point comparison with `==` instead of epsilon
- String comparison when semantic comparison is needed (locale, case, normalization)
- Regex that doesn't match what the author thinks it matches
- Boolean logic errors (De Morgan violations, double negations)

**Fix:** Trace the logic manually with concrete values. Write the truth table if the condition is complex. If you can't explain what a condition does in one sentence, it's probably wrong.

### 2. Null / Undefined Hazards (Will it crash?)

Code paths where values can be absent but aren't handled.

**Detect:**
- Optional chaining needed but not used (accessing `.foo` on a possibly-null value)
- Array access without bounds checking (`arr[i]` where `i` could be out of range)
- Map/object lookup without existence check (`map[key]` where key might not exist)
- Destructuring with assumed properties (`const { a, b } = obj` where obj might lack `b`)
- Function return values that can be null/undefined/None but callers don't check
- Database/API results assumed to be non-empty
- Environment variables assumed to exist

**Fix:** Handle the null/absent case explicitly. Decide: throw (fail fast), return a default, or propagate the absence? Silent defaults are often worse than crashes -- at least crashes are honest.

### 3. Error Handling Gaps (Will it crash? / Will it do the wrong thing?)

Not about over-handling (that's anti-slop territory) -- about *missing* error handling where it matters.

**Detect:**
- Async operations without error handling (unhandled promise rejections, bare `await` without catch)
- File/network/DB operations that assume success
- Parse operations that can throw (JSON.parse, parseInt, date parsing) without guards
- Error handlers that swallow context (catching and re-throwing as a generic error)
- Cleanup code that doesn't run on error (missing `finally`, `defer`, context managers)
- Error messages that don't include the failing input or operation context
- Catch blocks that handle the wrong exception type
- Missing error propagation in callback chains

**Fix:** Handle errors at the right level. External operations (I/O, network, parsing) need error handling. Internal pure functions generally don't. When catching, either recover meaningfully or add context and re-throw.

### 4. Race Conditions & State (Will it break later?)

Concurrency bugs that work in testing but fail under load or timing.

**Detect:**
- TOCTOU (Time-of-Check-to-Time-of-Use): checking a condition then acting on it non-atomically
- Shared mutable state accessed from multiple async operations without synchronization
- Event handlers that assume ordering (e.g., `onLoad` before `onData`)
- State mutations during iteration (modifying a collection while looping over it)
- Stale closures capturing mutable variables
- Database reads followed by writes without transactions
- File operations without locking when multiple processes might access
- Promise.all where one rejection should cancel siblings but doesn't
- React state updates depending on previous state without using the updater function

**Fix:** Make operations atomic, use proper synchronization, or restructure to avoid shared mutable state. If you need ordering guarantees, enforce them explicitly.

### 5. Resource Management (Will it crash? / Will it break later?)

Resources acquired but not reliably released.

**Detect:**
- File handles, DB connections, network sockets opened but not closed on all paths (including error paths)
- Event listeners / subscriptions added but never removed
- Timers (setInterval, setTimeout) not cleared
- Temporary files created but not cleaned up
- Database connections not returned to pool
- Locks acquired but not released on error paths
- Child processes spawned but not waited on / killed

**Fix:** Use language-appropriate resource management: `try/finally`, context managers (`with` in Python), `defer` in Go, `using` in C#, RAII in Rust/C++. Acquire and release should be syntactically adjacent.

### 6. Edge Cases & Boundaries (Will it do the wrong thing?)

Inputs that are technically valid but exercise boundary conditions.

**Detect:**
- Empty collections (empty array, empty string, empty object) not handled
- Zero / negative numbers where only positive are expected
- Very large inputs (huge strings, massive arrays, deep nesting)
- Unicode in string operations (multi-byte characters, combining characters, zero-width)
- Timezone issues in date/time operations
- Locale-dependent behavior (number formatting, sorting, case conversion)
- Path traversal (relative paths, symlinks, special characters in filenames)
- Concurrent modification during iteration
- Pagination off-by-one on the last page

**Fix:** Test boundaries explicitly. Empty, zero, one, many, MAX. If a function takes a string, what happens with ""? With a 10MB string? With emoji?

### 7. API Contract Issues (Will it break later?)

Code that will break when upstream or downstream changes.

**Detect:**
- Function signatures that don't match their callers (wrong arg count, wrong types)
- Return types that don't match what callers expect
- API responses consumed without validation (trusting the shape of external data)
- Breaking changes to public interfaces without version bumps
- Implicit dependencies on execution order
- Magic strings/numbers that should be constants or enums
- Config values used inconsistently across modules
- Database schema assumptions that aren't enforced

**Fix:** Validate at boundaries. Use types to enforce contracts where possible. Make implicit assumptions explicit.

### 8. Performance Traps (Will it break later?)

Not micro-optimization -- actual performance problems that cause incidents.

**Detect:**
- N+1 query patterns (querying in a loop instead of batching)
- Unbounded growth (caches without eviction, logs without rotation, arrays that only grow)
- Blocking the event loop / main thread with sync I/O or CPU-heavy work
- Missing pagination on queries that return unbounded results
- Quadratic or worse algorithms on user-controlled input sizes
- Unnecessary re-renders / re-computations in UI frameworks
- Loading entire files/datasets into memory when streaming would work
- Missing database indexes for common query patterns
- Repeated expensive computations that could be cached

**Fix:** Fix the algorithm, not the symptoms. Batch queries, add pagination, stream large data, index properly.

### 9. Convention Violations (Correctness-Relevant Only)

Project-specific rules where violations cause bugs, data loss, or broken behavior -- not style issues (those belong in anti-slop).

**Detect:**
- CLAUDE.md rules about transactions, error handling, or API patterns not followed
- Missing required error handling per project conventions (e.g., "all DB writes must use transactions")
- Framework usage that causes runtime errors (e.g., wrong lifecycle hook, missing middleware registration)
- Missing required test coverage for critical paths (auth, payments, data mutations)
- Environment-specific patterns violated (e.g., "never use sync I/O in the request path")

**Don't detect** (defer to anti-slop): naming style, comment conventions, import ordering, code organization, generic "inconsistency with surrounding code."

**Fix:** Follow the established patterns. When a convention exists for correctness reasons, violating it is a bug, not a style issue.

### 10. Test Correctness

Tests can have bugs too. A broken test is worse than no test -- it provides false confidence.

**Detect:**
- Tests that always pass regardless of implementation (testing mocks instead of behavior)
- Wrong assertions (asserting the wrong value, wrong comparison direction)
- Missing assertions (test runs code but doesn't check the result)
- Flaky test patterns (timing-dependent, order-dependent, relying on external state)
- Mocking the wrong layer (mocking so much that the test doesn't test anything real)
- Test setup that doesn't match production behavior (different config, missing middleware)
- Copy-pasted tests with only the description changed (same assertion, different label)
- `expect(result).toBeTruthy()` when a specific value check is needed

**Fix:** Tests should break when the behavior they describe changes. If you can delete the implementation and the test still passes, the test is broken.

---

## Prioritizing in Large Codebases

For full codebase reviews on repos with 100+ files, you can't read everything. Prioritize:

1. **Recently changed files** (`git log --since='2 weeks ago' --name-only`) -- fresh code has more bugs
2. **Critical paths** -- auth, payments, data mutations, API handlers, middleware
3. **Entry points** -- main files, route definitions, CLI commands, event handlers
4. **Files without tests** -- `git ls-files '*.ts' | while read f; do test -f "${f%.ts}.test.ts" || echo "$f"; done`
5. **Complex files** -- long functions, high cyclomatic complexity, many branches
6. **Shared utilities** -- bugs here multiply across the codebase

Skip: vendored code, generated files, test fixtures/snapshots, documentation, static assets.

For targeted reviews (diff/specific files), read the full files being changed plus their immediate callers/callees. Context matters -- a function that looks fine in isolation might be called incorrectly.

---

## Language: TypeScript / JavaScript

Read `${CLAUDE_SKILL_DIR}/references/typescript.md` for the full TS/JS bug pattern catalog. Key highlights:

- **Promise pitfalls**: missing `await`, unhandled rejections, `Promise.all` partial failure, `async void`
- **Type narrowing gaps**: type assertions (`as`) bypassing runtime checks, discriminated union exhaustiveness
- **Closure traps**: stale closures in loops/effects, captured mutable variables in async callbacks
- **React-specific**: missing dependency arrays, state updates during render, memory leaks in effects
- **Node-specific**: unhandled stream errors, missing `error` event handlers on EventEmitters

## Language: Python

Read `${CLAUDE_SKILL_DIR}/references/python.md` for the full Python bug pattern catalog. Key highlights:

- **Mutable default arguments**: `def foo(items=[])` -- the list is shared across calls
- **Exception handling**: bare `except:` catching KeyboardInterrupt/SystemExit, context loss in exception chains
- **Iterator exhaustion**: generators consumed twice silently, `map()`/`filter()` returning iterators not lists
- **Import side effects**: circular imports, module-level code that runs on import
- **Async pitfalls**: mixing sync and async, blocking the event loop, missing `await`
- **Dataclass/pydantic bugs**: mutable default fields without `default_factory`, validator side effects, `model_validate()` coercion on untrusted input
- **Attribute typos**: `self.nmae = name` silently creates a new attribute on regular classes -- use `__slots__` or dataclasses

## Language: Bash / Shell

Read `${CLAUDE_SKILL_DIR}/references/shell.md` for the full Shell bug pattern catalog. Key highlights:

- **Word splitting**: unquoted variables breaking on spaces, glob expansion in unexpected places
- **Exit code masking**: pipes hiding failures (`cmd1 | cmd2` only checks cmd2), `$(...)` in assignments
- **Signal handling**: missing trap for cleanup, backgrounded processes not cleaned up
- **Portability**: bashisms in `#!/bin/sh` scripts, GNU vs BSD tool differences

## Language: Java

Read `${CLAUDE_SKILL_DIR}/references/java.md` for the full Java bug pattern catalog. Key highlights:

- **Quarkus**: CDI scope thread safety (`@ApplicationScoped` + mutable state), `@RequestScoped` lost in reactive pipelines, `Uni`/`Multi` never subscribed, native image reflection, dev services config drift (`drop-and-create` in prod)
- **Spring Boot**: `@Transactional` proxy traps (self-invocation, non-public, final, checked exceptions), `SecurityFilterChain` ordering, WebFlux blocking calls, Reactor context/MDC loss
- **General Java**: `Optional.of()` on nullable, stream reuse, lazy eval escaping try-catch, `ConcurrentHashMap` check-then-act, equals/hashCode contract, checked exceptions swallowed in lambdas
- **Modern Java 17+**: virtual thread pinning on `synchronized`, `ThreadLocal` memory explosion with Loom, sealed class `IncompatibleClassChangeError`, `StructuredTaskScope` leak
- **AI-generated Java**: framework confusion (`@Autowired` in CDI), overcomplicated generics, concurrency blindness (2x rate), security shortcuts (1.5-2x rate)

## Language: Infrastructure as Code

Read `${CLAUDE_SKILL_DIR}/references/iac.md` for the full IaC bug pattern catalog. Key highlights:

- **Terraform**: resource dependencies wrong or missing, lifecycle issues with `create_before_destroy`, state drift from manual changes, data source race conditions
- **Ansible**: handlers not notified, variable precedence surprises, `when` conditions with undefined vars, idempotency violations
- **Helm**: template rendering errors only visible at deploy time, value type mismatches, missing required values
- **Kubernetes**: liveness probe killing healthy pods, resource limits causing OOMKills, missing PDB for HA
- **ArgoCD**: auto-sync with prune on production, sync wave ordering, health check misconfiguration, app-of-apps cluster targeting
- **Docker**: ENTRYPOINT shell vs exec form, multi-stage COPY from wrong stage, ARG scoping across FROM, missing .dockerignore
- **Compose**: `depends_on` without `condition: service_healthy` (race condition on startup ordering), `restart: always` without healthcheck (infinite crash loop), version field still present (deprecated since Compose v2)
- **Proxmox/LXC**: API token permissions too broad, LXC `nesting=1` without `keyctl=1` (Docker fails inside), Terraform `telmate/proxmox` provider unpinned (breaking changes), cloud-init network config mismatch between Proxmox and guest, `full_clone` when linked clone would work

## CI/CD Pipelines

Read `${CLAUDE_SKILL_DIR}/references/cicd-pipelines.md` for the full CI/CD bug pattern catalog. Key highlights:

- **GitLab CI/CD**: `rules:` vs `only:/except:` mixing (silently rejected), missing `when: never` causing fallthrough, `workflow:rules` absent causing duplicate pipelines, dotenv variables used in `rules:` (don't exist yet), protected variable silently empty on non-protected branches
- **GitHub Actions**: expression injection via `${{ }}` with user-controlled input, `GITHUB_TOKEN` permission scope too broad, reusable workflow input type mismatches, concurrency group bugs canceling wrong runs
- **Forgejo Actions**: GitHub Actions compatibility gaps (missing features, different runner behavior, secrets handling differences)
- **ArgoCD advanced**: ApplicationSet generator collisions, multi-source Application gotchas, annotation-based sync options silently changing behavior, progressive delivery rollback ordering
- **Terraform advanced**: state locking race conditions, workspace isolation failures, provider alias confusion, `moved` blocks breaking plans, `import` block limitations

## AI-Age Patterns

Read `${CLAUDE_SKILL_DIR}/references/ai-age-patterns.md` for the full AI-age bug pattern catalog. Key highlights:

- **AI-generated code smells**: hallucinated APIs/dependencies (1 in 5 samples), deprecated patterns from stale training data, over-defensive error handling, unnecessary abstractions, insecure defaults
- **Agentic AI patterns**: prompt injection (#1 OWASP LLM 2025), missing rate limiting on LLM API calls, context window overflow, streaming edge cases, tool/function calling validation gaps
- **LLM SDK bugs**: Anthropic SDK streaming + tools interaction, extended thinking block preservation, OpenAI structured output gotchas, missing `max_tokens` defaults
- **MCP vulnerabilities**: command injection (43% of servers), tool poisoning (5% of open-source servers), path traversal, SSRF, cross-tenant data exposure

## Databases

Read `${CLAUDE_SKILL_DIR}/references/databases.md` for the full database bug pattern catalog. Key highlights:

- **General SQL**: transaction misuse (partial writes, missing rollback), NULL handling (`NOT IN` with NULLs returns 0 rows), migration bugs (NOT NULL without DEFAULT on existing tables)
- **PostgreSQL**: `timestamp` vs `timestamptz` confusion, connection pool exhaustion, `jsonb` operator mixups (`->` vs `->>`), idle-in-transaction blocking autovacuum
- **MongoDB**: missing `$set` in updates (replaces entire document), field name typos silently match nothing, write concern `w:0` data loss, schema-less type inconsistency
- **MySQL/MariaDB**: silent data truncation in non-strict mode, `utf8` is not real UTF-8 (use `utf8mb4`), `GROUP BY` returning arbitrary values
- **MSSQL**: `@@IDENTITY` vs `SCOPE_IDENTITY()`, VARCHAR can't store Unicode (use NVARCHAR), `TOP` without `ORDER BY`
- **ORM pitfalls**: N+1 queries, stale entity caches, enum stored as ordinal (reorder breaks data), auto-DDL in production

## Other Languages

For Go, Rust, and other languages without dedicated reference files: apply the universal patterns (sections 1-10) only. Note in the report that language-specific checks were skipped.

---

## What NOT to Flag

- **Style/quality issues** -- that's anti-slop's job.
- **Security vulnerabilities** -- that's security-audit's job.
- **Pre-existing bugs** -- issues on lines not touched by the current changes (when reviewing a diff).
- **Linter/compiler catches** -- missing imports, type errors, formatting. The toolchain handles these.
- **Intentional trade-offs** -- code comments explaining "we do X because Y" signal the author already considered it.
- **Test-only code** -- relaxed error handling in test fixtures/helpers is often fine.
- **Defensive code at boundaries** -- input validation on external data is correct, not a bug.
- **Known framework quirks** -- patterns that look wrong but are idiomatic for the framework.
- **TODOs with issue references** -- `// TODO(#1234)` shows awareness, not negligence.
- **Generated / vendored code** -- lock files, compiled output, auto-generated types, vendored deps, ORM migrations.
- **Previously reviewed code** -- if invoked multiple times in a session, focus on changes since the last review.

---

## Severity Classification

Each reported finding (confidence >= 80) gets a severity:

- **Critical** -- will crash, corrupt data, or produce wrong results in normal usage. Includes: null derefs on common paths, data loss, race conditions that affect correctness, broken error propagation that hides failures, security-adjacent logic errors (auth bypass through logic bug).
- **Important** -- will cause problems under specific conditions or degrade reliability over time. Includes: edge case crashes, resource leaks, performance traps that will eventually hit, missing error handling on external operations, convention violations that cause bugs in this codebase.

Rule of thumb: if you'd wake someone up at 2am over it, it's Critical. If it can wait for the next sprint, it's Important.

---

## Output Format

### When issues are found:

````markdown
## Code Review: [scope]

### Findings

#### Critical ([count] issues)

🔴 **[confidence]%** `path/to/file:line` -- [description]

[Why this is wrong and what will happen if it isn't fixed]
**Triggers when:** [specific input, sequence, or condition that causes the bug]

```[language]
// before
[code snippet]

// after
[fixed code snippet]
```

#### Important ([count] issues)

🟡 **[confidence]%** `path/to/file:line` -- [description]

[Explanation]

```[language]
// before
[code snippet]

// after
[fixed code snippet]
```

### Observations

[Patterns noticed below the 80% threshold but worth mentioning as a group. This is where higher-level insights go -- "error handling is inconsistent across the API handlers", "no input validation on any of the CLI commands", "the test suite mocks the database everywhere so nothing tests actual queries." These aggregate observations are often more valuable than individual findings.]

### Summary
- X findings across Y files (Z critical, W important)
- [1-2 sentences on overall code health as it relates to correctness]
````

### When no issues are found:

````markdown
## Code Review: [scope]

No issues found above the confidence threshold.

**Checked:** [list what was reviewed -- e.g., "14 files, focused on API handlers and auth middleware"]
**Linters:** [what ran, what was missing -- e.g., "eslint clean, shellcheck not installed (`pacman -S shellcheck`)"]

[Optional: 1-2 sentences noting anything positive -- well-structured error handling, good test coverage, etc.]
````

Keep it tight. Show the bug, show the fix, move on. Long explanations only when the bug is subtle and the reader needs to understand *why* it's wrong.

---

## Related Skills

- **anti-slop** -- handles style, quality, and machine-generated code patterns. If the finding
  is "ugly but correct," route to anti-slop. If it would cause incorrect behavior, keep it here.
- **security-audit** -- handles vulnerability detection (injection, auth bypass, credential
  exposure). Code-review catches logic bugs; security-audit catches exploitable flaws.
- **full-review** -- orchestrates code-review, anti-slop, security-audit, and update-docs in
  parallel. Code-review is one of the four passes.
- **databases** -- `references/databases.md` in this skill covers application-level DB bug
  patterns. The databases skill covers engine configuration and operations.

---

## Rules

- **Read before flagging.** Never flag code you haven't read in full context. Read the function, the file, and the callers if needed. A pattern that looks wrong in isolation might be correct in context.
- **Don't duplicate other skills.** Style issues belong to anti-slop. Security vulnerabilities belong to security-audit. If you're unsure whether a finding is a bug or a style issue, ask: "would this cause incorrect behavior?" If no, skip it.
- **One finding per bug, not per occurrence.** If the same pattern appears in 5 files, report it once with a note about scope. Don't pad the report.
- **Show the fix.** Every finding must include a concrete code fix, not just a description of the problem. If you can't show a fix, the finding isn't specific enough.
- **Verify before scoring.** Before assigning 80+, check: is there a test covering this? Does git blame show this is new or old? Is there a comment explaining why?
- **Report missing tools.** When a linter or checker isn't installed, tell the user the package name and install command so they can set it up.
- **Don't repeat dismissed findings.** If the user acknowledged or dismissed a finding in this session, don't re-report it on subsequent invocations. They heard you the first time.
