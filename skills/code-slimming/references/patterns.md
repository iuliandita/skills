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
