# Safe Reduction Patterns

## Proof standard

For a deletion, record the search, definitions, imports/re-exports, string references, registrations, and the indirection paths ruled out. A static zero-reference result is not proof for public APIs, reflection, DI, serializers, route tables, plugins, CLIs, conditional compilation, or test discovery.

Also inspect build manifests, CI workflows, glob loaders, generated-code inputs, documentation links, package exports, feature flags, platform builds, and other dead-code candidates that reach each other. A superseded implementation needs a named replacement, migrated callers, and proof it is not a fallback or rollback path. Treat a cluster reachable only from other proven-dead code as one deletion candidate.

## Candidates

- **Dead and superseded code:** unused symbols, unreachable branches, removed-flag paths, old versions, stale scripts, fixtures, configs, and assets. A replacement claim names the replacement, verifies caller migration, and rules out fallback or rollback use.
- **Exact clones and one-literal copies:** collapse only identical signature, error, ordering, and data contracts. Keep provider or framework variants expected to diverge.
- **Thin wrappers:** inline only when they do not enforce validation, authorization, isolation, retries, idempotency, transactions, caching, observability, feature flags, compatibility, or fault boundaries.
- **Inert defensive scaffolding:** catches that rethrow unchanged or protect code that cannot throw. Never classify swallowing, conversion, retry, fallback, or `finally` cleanup as an automatic deletion.
- **Comment walls:** remove commented-out code and comments that merely narrate a neighboring line. Keep intent, invariants, licenses, pragmas, links, workarounds, and non-obvious constraints.
- **Duplicate shapes and parsing:** centralize only the common validated subset. Do not merge request, domain, persistence, queue/event, and response types just because fields overlap.

Shorter generic code can worsen hot-path allocations, dispatch, cache locality, bundle size, or debugging. Require measurement or defer it.
