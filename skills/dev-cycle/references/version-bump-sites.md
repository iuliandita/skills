# Dev Cycle: Version-Bump Sites

Where versions live across common ecosystems, and how to find them. Referenced from Step B3 in SKILL.md.

## When this reference loads

Load in finish mode during the doc/version sync step. Not needed in start mode.

---

## Philosophy

Versions drift because nobody owns the full list. This skill owns the list.

Two rules:

1. **Grep, don't remember.** The locations below are common, but every repo has quirks. Always grep for the current version string.
2. **Propose, don't auto-edit.** Show the user the diff. They confirm the scope.

---

## Detection script

Run this at repo root to find all version strings:

```bash
# Get the current version from the primary manifest
CURRENT_VERSION=""
[[ -f package.json ]] && CURRENT_VERSION=$(jq -r '.version' package.json 2>/dev/null)
[[ -z "$CURRENT_VERSION" && -f pyproject.toml ]] && CURRENT_VERSION=$(grep -E '^version\s*=' pyproject.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
[[ -z "$CURRENT_VERSION" && -f Cargo.toml ]] && CURRENT_VERSION=$(grep -E '^version\s*=' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
[[ -z "$CURRENT_VERSION" ]] && CURRENT_VERSION=$(git tag -l 'v*' --sort=-v:refname | head -1 | sed 's/^v//')

echo "Current version: $CURRENT_VERSION"

# Find all occurrences across the repo
rg --fixed-strings "$CURRENT_VERSION" --hidden --no-ignore \
  --glob '!.git' --glob '!node_modules' --glob '!*.lock' --glob '!*.sum'
```

Review each match. Not all are version strings - some may be coincidental (e.g., a test fixture with `"version": "1.2.3"` that's documenting a different system).

---

## Site catalog

### Language / package manifests

| Ecosystem | File | Field | Notes |
|-----------|------|-------|-------|
| Node.js | `package.json` | `"version"` | Root. Sub-packages in monorepos (`packages/*/package.json`). |
| Python (modern) | `pyproject.toml` | `[project] version` or `[tool.poetry] version` | Single source of truth for new projects. |
| Python (legacy) | `setup.py`, `setup.cfg` | `version=` | Still seen in older projects. |
| Python (dynamic) | `__init__.py` | `__version__` | When pyproject uses `dynamic = ["version"]`. |
| Rust | `Cargo.toml` | `[package] version` | Workspace members may inherit via `workspace.package`. |
| Go | `go.mod` | no direct version; tags drive it | Module version = latest git tag. |
| Java (Maven) | `pom.xml` | `<version>` | Parent POM may define it; check inheritance. |
| Java (Gradle) | `build.gradle` / `build.gradle.kts` | `version =` | May be in `gradle.properties`. |
| Ruby | `Gemfile.lock`, `*.gemspec` | `spec.version` | Primary in gemspec. |
| PHP | `composer.json` | `"version"` | Often omitted; packagist uses tags. |
| .NET | `*.csproj`, `Directory.Build.props` | `<Version>` | Can be centralized in Directory.Build.props. |
| Elixir | `mix.exs` | `version: "x.y.z"` | Inside project/0 function. |
| Dart/Flutter | `pubspec.yaml` | `version:` | `x.y.z+build` format is common. |
| Swift | `Package.swift` | No direct version; tags drive it | Like Go. |

### Container / orchestration

| File | Patterns to check |
|------|-------------------|
| `Dockerfile` | `LABEL version=`, `LABEL org.opencontainers.image.version=`, base image tags (`FROM image:TAG`), `ARG VERSION=` |
| `Dockerfile.*` | Same, multiple Dockerfiles common in monorepos |
| `docker-compose.yml`, `docker-compose.*.yml`, `compose.yaml` | `image: ORG/APP:TAG` |
| `docker-bake.hcl` | `tags = ["..."]` |
| `.dockerignore` | n/a - no versions |

### Kubernetes

| File | Patterns to check |
|------|-------------------|
| `k8s/**/*.yaml`, `manifests/**/*.yaml` | `image: ORG/APP:TAG` in Deployment/StatefulSet/DaemonSet/CronJob specs |
| `kustomization.yaml` | `images:` block with `newTag:` |
| `base/` and `overlays/` (Kustomize) | Same patterns per overlay |
| Helm charts | see below |

### Helm

| File | Field | Notes |
|------|-------|-------|
| `Chart.yaml` | `version:` | The chart's own version. Bump on chart changes. |
| `Chart.yaml` | `appVersion:` | The application version the chart deploys. Bump on app release. |
| `values.yaml` | `image.tag` (or similar) | Default image tag for the chart's deployments. |
| `values-*.yaml` | Same | Environment-specific overrides. |
| `templates/` | Rarely contain hardcoded versions | Should reference `.Values.image.tag`. |

Both `version` and `appVersion` need thought. Rule of thumb:
- `appVersion` tracks the app it deploys (bump when the app releases)
- `version` tracks the chart itself (bump when templates or values change)
- A release can bump appVersion without bumping version if the chart is unchanged - but most CI gates require version to also bump (to force-refresh installed releases)

### CI / workflows

| File | Check |
|------|-------|
| `.github/workflows/*.yml` | Action pins (`uses: owner/repo@vX.Y.Z`), tool-version env vars |
| `.gitlab-ci.yml`, `.gitlab/*.yml` | `image:` tags, versioned job includes |
| `.circleci/config.yml` | `orb` versions, Docker executor tags |
| `.drone.yml`, `.woodpecker.yml` | Same image-tag pattern |
| `.pre-commit-config.yaml` | `rev:` pins for hook repos |

### Docs and metadata

| File | Check |
|------|-------|
| `README.md` | Version badges (shields.io), installation commands with pinned versions, changelog link headers |
| `CHANGELOG.md` | Add a new section; do not edit historical sections |
| `CHANGES`, `HISTORY.md`, `NEWS.md` | Same |
| `docs/` | Versioned install snippets, compatibility matrices |
| `mkdocs.yml`, `docs/conf.py`, `docusaurus.config.*` | Site version strings |
| `CITATION.cff`, `.zenodo.json` | Academic metadata |

### Installers and bootstrap scripts

| File | Check |
|------|-------|
| `install.sh`, `bootstrap.sh`, `setup.sh` | Hardcoded version pins |
| `Makefile`, `justfile`, `Taskfile.yaml` | Version variables in recipes |
| Homebrew formula (if maintained in-repo) | `version "x.y.z"`, `url`, `sha256` |
| Scoop manifests | `version`, `url`, `hash` |
| `.releaserc`, `release-please-config.json` | Release automation config - don't edit the version, let the tool set it |

### Build outputs and constants

| File | Check |
|------|-------|
| Source files with `VERSION` constants | `const VERSION = "..."`, `__version__`, etc. |
| Generated files (dist/, build/) | Usually ignored - regenerated on build |
| CLI `--version` output | Verify the change surfaces here too |

---

## Strategy by change type

### Patch release (bug fix)

Bump the main manifest. Update:
- Primary package manifest
- Helm `appVersion` (if helm)
- Dockerfile LABEL version (if set)
- CHANGELOG
- Keep chart `version`, image tags, etc. unless they need to propagate for deployment

### Minor release (feature)

Same as patch, plus:
- Helm chart `version` (chart templates may have new capabilities)
- README if installation steps or compatibility changed

### Major release (breaking)

Everything patches cover, plus:
- Breaking-change notes in CHANGELOG
- Migration guide (often `MIGRATION.md` or `UPGRADE.md`)
- README install command if major is pinned differently (e.g., npm `@latest` vs `@1`)
- CI compatibility matrix if languages/runtimes were dropped

### Tooling-only version (dependency bump, no public change)

Usually no public version bump needed. But:
- If the tool is re-exported (e.g., lib in `node_modules` whose types you export), that may be a minor/major of your library
- Lockfiles update automatically; commit them

---

## Confirming the diff

Before editing, show the user something like:

```
Version bump: 1.4.2 → 1.5.0 (minor)

Proposed edits:
  package.json                  "version": "1.4.2" → "1.5.0"
  Dockerfile                    LABEL version="1.4.2" → "1.5.0"
  helm/myapp/Chart.yaml         appVersion: 1.4.2 → 1.5.0
  helm/myapp/values.yaml        image.tag: 1.4.2 → 1.5.0
  CHANGELOG.md                  + new section: ## [1.5.0] - 2026-04-14

Not touching (confirm):
  docs/install.md               shows "install@1" - major-line pin, leave as-is
  test/fixtures/old_response.json   contains "version": "1.0.0" - unrelated fixture
```

Apply after user confirms. If they want changes to the plan, redo the proposal - don't partially apply.

---

## Gotchas

### Generated files

Some files regenerate on build (e.g., `dist/package.json` in some Node setups). Don't edit by hand - they'll be overwritten. Edit the source and rebuild, or commit the regenerated output after a build.

### Monorepo version coordination

Packages in a monorepo may version independently (Lerna/changesets style) or in lockstep. Check the repo's release tooling:
- `changeset/` directory → changesets, bump per package
- `lerna.json` with `"version": "independent"` → per-package
- `lerna.json` with a fixed version → lockstep
- Nx: check `release.yml` or `nx.json`

Don't manually bump every `package.json` in a changesets repo - the tool does it on release.

### SemVer pre-releases

Pre-release tags like `1.5.0-rc.1`, `1.5.0-beta.2` sort before `1.5.0`. Bumping from `1.5.0-rc.1` → `1.5.0` is a release-out-of-prerelease, not a new minor.

### Calendar versioning

Some projects use CalVer (`2026.04.0`, `26.04`) instead of SemVer. Don't silently convert. Match the existing format.

### Language-specific tag prefixes

- Go requires `v` prefix: `v1.2.3`
- npm strips `v` if present
- PyPI does not use `v` prefix
- Docker tags are arbitrary

Match the repo's existing convention. `git tag -l | head -5` usually tells you.
