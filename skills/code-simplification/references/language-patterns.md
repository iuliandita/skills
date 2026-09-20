# Language Patterns

Use the target runtime and project conventions as the authority. A newer idiom is not a finding until its version and behavior are verified.

## TypeScript and JavaScript

Inspect redundant annotations, `any` or forced casts, utility-type gymnastics, duplicate types, Promise-constructor wrappers, stateless classes, unnecessary barrels, duplicate HTTP/date libraries, and silent defaults for required configuration. Check ESM versus CommonJS, React and TypeScript versions, async ordering, and whether a public interface or barrel is a stable boundary. Preserve callback adaptation, concurrency, and dynamic-path behavior.

## Python

Inspect static-only classes, singleton wrappers, `Any`, scattered ignores/casts, broad `except`, catch-log-continue, JavaScript or Java APIs, and generic `utils.py` modules. Preserve deferred logging interpolation, Python version gates for modern typing and pattern matching, cleanup timing in `try/finally`, and real package APIs. Prefer behavior assertions over `MagicMock` call-count tests.

## Shell

Inspect unquoted expansion, invented flags, blanket `2>/dev/null || true`, unsafe command substitution, parsing `ls`, needless subprocesses, opaque heredocs, and bootstrap logic hidden in normal scripts. Preserve the declared shell, expected grep/diff statuses, `set -e` suppression contexts, intentional globbing, cleanup traps, regex semantics, and byte-versus-character behavior.

## Rust

Inspect clones that mask borrowing, unnecessary trait bounds, one-variant error types, stale macros, unsafe blocks without invariants, and dependencies that duplicate standard library facilities. Preserve ownership, lifetimes, safe error behavior, the project error strategy, unsafe `SAFETY` contracts, and toolchain gates before suggesting `LazyLock` or newer APIs.

## Containers and infrastructure

Inspect unsupported image/runtime versions, build-stage waste, root execution, `latest`, hardcoded environment values, over-modular Terraform, redundant `depends_on`, ungrounded provider/module fields, Ansible command use where modules exist, Helm values/template drift, and Kubernetes API/field drift. Do not simplify secrets, least-privilege controls, idempotency, side-effect dependencies, probes, rollback controls, or schema validation. Validate against the pinned provider, chart, cluster, and client version.
