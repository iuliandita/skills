# Maintainability Patterns

Use these as prompts, not style rules. Explain a concrete maintenance or correctness cost and preserve project conventions.

## Universal checks

- **Noise:** comments that restate code, redundant types, boilerplate, needless intermediate variables, decorative sections, and barrel files that hide ownership.
- **Overengineering:** one-implementation base classes, factories that always return one type, pass-through services, utility junk drawers, and abstractions that neither isolate a boundary nor support real variation.
- **Grounding:** imports, methods, flags, config keys, provider fields, and schema claims that are plausible but absent from installed types, generated schema, lockfiles, help text, or primary docs.
- **Error handling:** broad catches, default fallbacks for required configuration, and wrappers that hide uncertainty. Keep external-boundary validation, typed conversion, recovery, retry, cleanup, and diagnostic context.
- **Tests:** implementation-mirroring mocks, call-count-only assertions, and snapshots without behavioral assertions. Keep adapter, logging, and contract tests when call shape is the contract.

Classify each finding on both axes: **Noise** is bulk without value, **Lies** is ungrounded or stale behavior, and **Soul** is needless concept count or poor fit. Mark it **Fix** only when evidence supports a concrete replacement, **Consider** for a justified tradeoff, and **Fine** when the apparently redundant shape carries a real contract. After inspecting scripts and configuration, run only project-configured non-mutating checks such as `shellcheck`, `ruff`/mypy, eslint/TypeScript, Terraform, Ansible, Helm, or Kubernetes validation. Do not use `--fix`, `--write`, `apply`, unknown scripts, or unconfigured tools.

## Language prompts

| Area | Inspect | Preserve |
|---|---|---|
| TypeScript/JavaScript | `any`, redundant annotations, Promise wrappers, duplicate types, stale module patterns, unsupported hooks/config | ESM/runtime version, async ordering, public barrels |
| Python | static-only classes, `Any`/casts, broad `except`, JS/Java idioms, `utils.py` junk drawers | supported Python version, deferred logging, context-manager timing |
| Shell | unquoted expansions, invented flags, broad `|| true`, unnecessary subprocesses | declared shell semantics, expected nonzero statuses, cleanup traps |
| Rust | clones masking ownership, excessive bounds, stale macros, unsupported crate APIs | borrow/lifetime safety, unsafe invariants, current toolchain |
| Containers and IaC | one-resource modules, ungrounded fields, ignored failures, dead values, imperative drift | auth, least privilege, idempotency, side-effect dependencies, provider and cluster versions |

## Structural duplication

Compare sibling providers, clients, registries, adapters, parsers, handlers, and schemas. Report one representative example only when a shared behavior contract is stable. Separate variants should remain separate when they diverge by provider, version, ownership, trust boundary, latency, or failure semantics.
