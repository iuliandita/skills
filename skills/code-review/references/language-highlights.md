# Language and Domain Highlights

Key highlights per language and domain. Each section names the reference file that holds the full bug pattern catalog.

## Contents

- Language: TypeScript / JavaScript
- Language: Python
- Language: Bash / Shell
- Language: Java
- Language: Infrastructure as Code
- CI/CD Pipelines
- AI-Age Patterns
- Databases
- Language: Go
- Other Languages

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
