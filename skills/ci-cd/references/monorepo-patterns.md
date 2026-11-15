# Monorepo Patterns

Path-based triggering, shared library detection, selective builds, and Python monorepo specifics.

## Monorepo Patterns

When a repo contains multiple services sharing a common library:

### Path-based triggering
Keep required workflows reporting on every applicable PR; condition expensive jobs inside
them instead. See `references/best-practices.md` for the required-status pending trap.

- **GitHub Actions**: `on.push.paths` / `on.pull_request.paths` to scope workflows per service
- **GitLab CI/CD**: `rules: changes: paths:` with `compare_to: refs/heads/main`
- **Forgejo**: same as GitHub Actions (`on.push.paths`)

### Shared library detection
If `libs/common/` changes, rebuild all services that depend on it:
- List dependent services in a matrix or trigger all service workflows
- `paths` filters accept globs: `paths: ['services/api/**', 'libs/common/**']`

### Selective builds
Build only what changed. Two approaches:
1. **Per-service workflows** with `paths:` filters (simplest, recommended)
2. **Single workflow with matrix** + change detection job that outputs which services need building

**Rule**: always rebuild when the shared lib changes. A "nothing changed" optimization that misses a shared dependency is worse than rebuilding everything.

### Python monorepo specifics (GitLab / GitHub / Forgejo)

For Python monorepos with multiple services sharing a common library (`libs/common/`):
- **Cache the resolver output, not the install step.** Key on `hashFiles('**/requirements*.txt')` or `**/poetry.lock`/`**/uv.lock`. With `uv` or `pip`, cache `~/.cache/uv` or `~/.cache/pip` plus each service's `.venv/` keyed on the service path + lockfile hash.
- **Install the shared lib editable** (`pip install -e libs/common`) so services import the in-repo version, not a stale wheel.
- **Scope jobs per service with path filters.** GitLab: `rules: - changes: paths: ['services/api/**', 'libs/common/**'] compare_to: refs/heads/main`. GitHub/Forgejo: `on.push.paths` / `on.pull_request.paths`. Always include `libs/common/**` in every service's filter so a shared-lib change triggers all services.
- **YAML anchors (GitLab) / reusable workflows (GitHub) for the per-service job template.** Three near-identical blocks for `api`, `worker`, `scheduler` is a maintenance trap.

See `references/gitlab-ci.md` for a full monorepo `.gitlab-ci.yml` (YAML anchors, `compare_to`, per-service change rules, shared-lib detection).
