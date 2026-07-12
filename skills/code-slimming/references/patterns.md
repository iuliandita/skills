# Code Slimming: Pattern Recognition Guide

Pattern-by-pattern recognition aids for classifying a slimming candidate by its shape.
Consult this when a candidate's category is unclear. The operational workflow,
no-reference discipline, and rules live in `SKILL.md`; this file is the recall layer.

## Dead code and unused symbols

Functions, methods, variables, constants, types, and exports that nothing references are pure
maintenance cost. So are unused imports, orphan files nothing imports, unreachable branches, and
removed-flag code paths. The deletion is safe only once no-reference is proven. The recurring false
positives are entry points reached through indirection (see the no-reference paths in SKILL.md Best
Practices and Step 5); treat any of those as "not dead" until proven otherwise.

## Superseded and replaced code

An old implementation lingers after a rewrite: callers moved to the replacement, but the original
unit stayed. Recognize it by parallel old/new versions of the same concept (`parser.ts` next to
`parser_v2.ts`), legacy branches after a migration marked complete, and modules whose only
remaining references are from other dead code. A "replaced" claim needs three proofs: the
replacement is named, every caller migrated, and the old path is not a kept fallback, rollback
target, or feature-flag branch. Dead code reachable only from other dead code counts as dead -
report the whole cluster together so the deletion is coherent.

## Leftover files

Files the project no longer needs: one-off scripts written for a finished task, scratch/debug
files, backup copies (`.bak`, `.orig`, `copy`, date suffixes), fixtures and assets nothing loads,
configs for removed tools or services, disabled or permanently skipped test files, and docs
describing removed features. Check build configs, CI workflows, scripts in manifests, and doc
links before calling a file orphaned - loaders are often string-keyed or glob-based.

## Exact and intra-file clones

Copy-paste blocks repeated across files, or repeated within one file, collapse cleanly when they are
truly identical and share one contract. Same-file repetition (a loop body pasted three times, two
near-identical switch arms) is often the easiest and safest win because the call sites are all
visible at once. Confirm the blocks are exact or differ only in clearly parameterizable values
before proposing a single shared form.

## Commented-out code and comment walls

Commented-out code is dead code in disguise: version control already preserves it, so recommend
deletion. Comment walls - ASCII banners, section dividers, and comments that restate the next line
of code - add bytes without signal. Keep comments that carry intent (the why), invariants,
non-obvious constraints, links to issues or specs, license headers, and lint/type pragmas. This is a
deletion lane only; rewriting AI-voiced prose belongs to anti-ai-prose.

## Per-element function copies

A common AI-generated shape: one function per element where the elements differ only in a literal -
`handleRed`/`handleBlue`/`handleGreen`, a getter per field, a near-identical handler per route or
entity, switch arms that map one-to-one onto data. Collapse to a loop, map, or lookup table keyed by
the varying literal. Require identical contracts: same signature shape, same error behavior, same
ordering guarantees. Leave alone when variants are expected to diverge (per-provider semantics) or
when the explicit form is a framework convention (route tables, codegen targets).

## Inert try/catch and defensive scaffolding

Another AI-generated shape: mechanical try/catch around code that needs none. Inert forms are safe
to flag - a catch that only rethrows unchanged, catch-log-rethrow that adds no context the logger
lacks, try around code that cannot throw, and blanket per-function wrapping applied uniformly.
Distinguish these from behavior-carrying catches: swallow-and-continue, error conversion or
wrapping into typed errors, retries, fallbacks, and cleanup in `finally`. Removing a swallowing
catch changes propagation - that is `Do with tests` at best, and a swallowed error that hides a bug
is a code-review finding, not a slimming one. The same discipline applies to needless defensive
null checks on values a type system or upstream contract already guarantees - flag only with the
guarantee cited.

## Repeated boundary parsing

Request parsing, CLI argument normalization, env var parsing, and config loading often duplicate
defaulting and validation rules. Centralize only when the same boundary contract really applies.

## Near-twin adapters

Provider/client/repository adapters often start identical and then diverge. Recommend
centralization only when the shared part is stable and the provider-specific differences stay
explicit.

## Duplicate data shapes

Repeated DTOs, schemas, records, structs, or interfaces can be centralized when they represent the
same contract. Keep separate shapes when they describe different lifecycle stages or trust
boundaries. Do not merge inbound untrusted request shapes, internal/domain shapes, persistence
entities, queue/event payloads, and outbound response shapes merely because fields overlap. Shared
field lists are not shared contracts; centralize only the truly common validated subset, or keep
explicit mappers.

## Wrapper layers

Thin wrappers that only forward calls usually add concept count without value. Prefer deleting or
inlining them unless they isolate an external dependency, provide a stable public contract, or make
testing materially easier. Leave them alone when they enforce validation, auth/authorization,
tenant isolation, retries, idempotency, transactions, caching, rate limits, logging, tracing,
metrics, feature flags, compatibility shims, dependency inversion, or fault isolation.

## Oversized helper modules

Large `utils`, `helpers`, `common`, `shared`, or `misc` modules are often junk drawers. Recommend
splitting by domain concern or moving helpers closer to their only caller.

## Performance-sensitive slimming

Shorter code can be slower. Centralized generic code can add allocation, dynamic dispatch, reflection,
bundle weight, cache misses, or indirect calls. In hot paths, require measurement or classify as
`Defer`.
