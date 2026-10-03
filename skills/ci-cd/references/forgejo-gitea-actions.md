# Forgejo and Gitea Actions: Patterns & Templates

Forgejo and Gitea Actions share the same `act`-based family of workflow engines, but
they are not drop-in GitHub Actions clones. Use this reference for Forgejo/Gitea-specific
syntax, action resolution, troubleshooting, and the Woodpecker alternative.

Gitea ships two viable CI paths in 2026. Which one you use depends on the instance version
and whether you want CI baked into Gitea or run as a separate service.

| Option | When it fits | Syntax |
|--------|--------------|--------|
| **Gitea Actions** (since Gitea 1.21, GA) | Migrating from GitHub; want CI in the same service | GitHub Actions subset (act-based) |
| **Woodpecker CI** (3.x, 2026) | Pre-1.21 Gitea, lightweight self-host, matrix/caching focus | Woodpecker YAML, `.woodpecker/*.yaml` |
| **Drone** (legacy) | Existing deployments only - unmaintained since Harness acquisition | Drone YAML |

Do not run both Gitea Actions and Woodpecker for the same repo; pick one. Running both
means two sets of webhooks, two runners, double the secret surface.

## Contents

- Forgejo Actions patterns
- Gitea Actions
- Forgejo Actions troubleshooting
- Woodpecker CI
- Choosing between Gitea Actions and Woodpecker
- Drone (legacy)
- Cross-references

---

## Forgejo Actions patterns

Forgejo workflow templates and operations. The key-differences table lives in `SKILL.md`.

### Forgejo workflow template

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  ci:
    runs-on: docker                    # self-hosted runner label
    container:
      image: oven/bun:1.2             # pin to minor version minimum
    steps:
      - uses: actions/checkout@<sha>  # pin to SHA; resolves from Forgejo mirror
      - run: bun install --frozen-lockfile
      - run: bun run lint
      - run: bun run typecheck
      - run: bun run test
```

### Forgejo action SHA discovery

Forgejo resolves actions from its own mirror or a configured upstream, not from github.com.
Finding the correct SHA for a self-hosted mirror requires different steps than GitHub.

**Find the SHA on your Forgejo instance**:
```bash
# List tags and their SHAs from the Forgejo mirror
git ls-remote https://forgejo.example.com/actions/checkout.git 'refs/tags/v4*'

# Or use the Forgejo API to get a tag's commit SHA
curl -s https://forgejo.example.com/api/v1/repos/actions/checkout/git/refs/tags/v4.2.2 \
  | jq -r '.object.sha'
```

**If your instance mirrors from code.forgejo.org** (the default upstream):
```bash
git ls-remote https://code.forgejo.org/actions/checkout.git 'refs/tags/v4*'
```

**Verify a SHA matches what you expect**:
```bash
# Clone at the specific SHA and inspect
git clone --depth 1 https://forgejo.example.com/actions/checkout.git /tmp/checkout-verify
cd /tmp/checkout-verify
git checkout <sha>
# Review action.yml and dist/ - compare against the known-good upstream release
```

**Key differences from GitHub SHA discovery**:
- The same action (e.g., `actions/checkout`) may have different SHAs on Forgejo mirrors vs GitHub
  because Forgejo forks maintain their own commits
- `code.forgejo.org/actions/*` repos are Forgejo-maintained forks, not exact copies of GitHub repos
- Always verify SHAs against your own instance, not against github.com
- If the action repo is not mirrored yet, an admin must add it to the Forgejo mirror list

### Forgejo-specific gotchas

- **No `ubuntu-latest`** - `runs-on` maps to your registered runner labels (e.g., `docker`)
- **Missing tools** - Forgejo runner containers are lean. Add `apt-get install` for git, curl, etc.
- **TLS certs** - if Forgejo uses self-signed or internal CA certs, configure the runner's trust
  store (`GIT_SSL_CAINFO=/path/to/ca-bundle.crt`) or install the CA into the container image.
  `GIT_SSL_NO_VERIFY=true` is a last resort for dev/test only - never normalize TLS bypass in production
- **Third-party actions** - many GitHub Marketplace actions use GitHub-specific API calls and will silently fail
- **Secrets in Forgejo** - `${{ secrets.* }}` works, but no environment-level scoping
- **`permissions:` not enforced** - Forgejo parses the field but does not restrict the workflow token.
  The token always has full read-write access (read-only for fork PRs only). Don't assume
  least-privilege from `permissions:` alone - it has no effect on Forgejo.

### Managing Forgejo Actions with `fj`

The community Forgejo CLI (`fj`, v0.4.1+) covers the day-to-day Actions surface: listing
runs, dispatching workflows, and managing variables/secrets. It is much faster than the web
UI for bulk secret updates and scriptable for one-shot runs. For installation and authentication, use the CLI's official docs and protected credential store. The **git** skill is an optional neighbor.

```bash
# List recent runs (for a quick "is CI green on main?" check)
fj actions tasks

# Trigger a workflow_dispatch run without opening the browser
fj actions dispatch publish.yaml main --inputs version=1.2.3

# Bulk variable/secret management (writes to the repo scope)
fj actions variables create CACHE_BUCKET gs://my-bucket
# Create secrets in the authenticated forge UI unless CLI help verifies stdin/file input.
# Do not pass secret values as positional arguments.
```

**What `fj` does not do yet** (as of 0.4.1): stream runner logs, re-run failed jobs, cancel
running tasks. For those, use the web UI or hit `/api/v1/repos/{owner}/{repo}/actions/tasks/{id}`
directly. Log streaming across the fleet still belongs in your observability stack, not `fj`.

**On Gitea instead of Forgejo?** Use `tea` (`gitea.com/gitea/tea`) - the Gitea CLI covers
a similar surface (issues, PRs, releases) against any Gitea 1.20+ instance. Gitea Actions
lacks `fj`-equivalent CLI tooling; use the web UI or API. If you're running Forgejo,
prefer `fj` - it tracks Forgejo-specific behavior (AGit, Forgejo Actions quirks) that
`tea` does not.

### Forgejo release workflow pattern

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build-and-push:
    runs-on: docker
    container:
      image: catthehacker/ubuntu:act-24.04    # heavier image for multi-tool needs
    # Private-forge TLS: mount your CA and set GIT_SSL_CAINFO=/path/to/ca.crt.
    # GIT_SSL_NO_VERIFY is a dev/test-only last resort - never commit it to a release pipeline.
    steps:
      - uses: actions/checkout@<sha>  # pin to SHA; resolves from Forgejo mirror
      - name: Login to registry
        env:
          TOKEN: ${{ secrets.REGISTRY_TOKEN }}
          HOST: ${{ secrets.REGISTRY_HOST }}
          USER: ${{ secrets.REGISTRY_USER }}
        run: echo "$TOKEN" | docker login "$HOST" -u "$USER" --password-stdin
      - name: Build and push
        env:
          REGISTRY: ${{ secrets.REGISTRY_HOST }}/${{ secrets.REGISTRY_IMAGE }}
          TAG: ${{ github.ref_name }}
        run: |
          docker build -t "$REGISTRY:$TAG" .
          docker push "$REGISTRY:$TAG"
```

**Note**: use secrets for registry host/image to avoid hardcoding private domains in git history.

---

## Gitea Actions

Same `act`-based engine as Forgejo Actions, same GitHub Actions syntax subset, same SHA
pinning and action resolution concerns. All Forgejo Actions guidance (the `SKILL.md` key-differences
table and the Forgejo Actions patterns section above) applies, with these differences:

| Aspect | Forgejo Actions | Gitea Actions |
|--------|-----------------|---------------|
| Workflow path | `.forgejo/workflows/*.yml` | `.gitea/workflows/*.yml` (or `.github/workflows/`) |
| Action mirror | `code.forgejo.org/actions/*` | `gitea.com/actions/*` or configured proxy |
| AGit | Supported | Not supported |
| CLI | `fj actions` | No first-class CLI; use `tea` for basic ops or the API |

### Action SHA discovery

Same pattern as Forgejo: `git ls-remote` against your instance's mirror, or the API:

```bash
curl -s https://gitea.example.com/api/v1/repos/actions/checkout/git/refs/tags/v4.2.2 \
  | jq -r '.object.sha'
```

### Gitea Actions gotchas

- **`permissions:` not enforced** - Gitea accepts the field but does not restrict the
  workflow token. Identical to Forgejo. Do not assume least-privilege from `permissions:`
  alone.
- **Action marketplace compatibility** - most GitHub actions work (`actions/checkout`,
  `actions/setup-node`, `docker/*`). Marketplace actions that use GitHub-specific API
  calls silently fail.
- **Runner labels** - `runs-on` matches labels registered with the runner (`forgejo-runner`
  or `gitea-runner`). `ubuntu-latest` works only if the runner config maps it to an image;
  custom labels like `docker` are common.

## Forgejo Actions troubleshooting

Use this when a Forgejo Actions run fails but the failure is only visible as a
notification or task status, especially for scheduled Docker image builds.

1. Identify the failed task and adjacent successful runs:

```bash
fj actions tasks -p 1
```

Compare task id, commit, event, duration, and workflow/job name. If the same
workflow and commit succeeded immediately before or after, suspect runner,
network, registry, cache, or external service flake before editing code.

2. Inspect the workflow file and reproduce the deterministic shell-visible parts locally:

```bash
sed -n '1,220p' .forgejo/workflows/<workflow>.yaml
```

For Docker build workflows, run the same build context, Dockerfile, tags,
scanner image, scanner flags, and ignore file locally.

```bash
docker build --pull -t local-debug:<name> <context>
docker tag local-debug:<name> <registry>/<owner>/<image>:<tag>

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/<path>/.trivyignore:/work/.trivyignore:ro" \
  -w /work \
  aquasec/trivy:<version> image \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --ignorefile /work/.trivyignore \
  --exit-code 1 \
  --format table \
  <registry>/<owner>/<image>:<tag>
```

If local build and scan pass, do not claim the workflow is fixed. Report the
narrowed failure domain and suggest rerun only if authorized.

3. Keep private registry state explicit. `docker manifest inspect` may fail
locally with `unauthorized` unless this machine is logged in to the registry,
even if the CI runner has a working token. Treat that as an auth-state finding,
not proof that the image is absent.

Some Forgejo versions expose Actions task listings through the CLI but do not
expose job logs through token-friendly API endpoints, or return `403` for
unauthenticated/session-only endpoints. When logs are unavailable, use
`fj actions tasks`, adjacent successful runs, and local reproduction. Avoid
guessing the exact failing step.

### Minimal Gitea Actions workflow

```yaml
# .gitea/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # pin to SHA from your Gitea mirror
      - run: bun install --frozen-lockfile
      - run: bun run test
```

---

## Woodpecker CI

Architecturally different from Actions-based CI: a separate server-plus-agents service
that Gitea/Forgejo talks to via webhook. Smaller surface, container-native, Raspberry-Pi
friendly. Written in Go, MIT-licensed. Current stable: see `references/target-versions.md`.

### Config layout

`.woodpecker/*.yaml` in the repo root. Each file is a separate pipeline. No
multi-job-per-file like Actions - one pipeline per file, one agent per pipeline by default.

```yaml
# .woodpecker/ci.yaml
when:
  - event: [push, pull_request]
    branch: main
  - event: tag

steps:
  - name: lint
    image: oven/bun:1.2
    commands:
      - bun install --frozen-lockfile
      - bun run lint
    when:
      - event: [push, pull_request]

  - name: test
    image: oven/bun:1.2
    commands:
      - bun run test
    when:
      - event: pull_request

  - name: publish
    image: woodpeckerci/plugin-docker-buildx
    settings:
      registry: git.example.com
      repo: git.example.com/team/app
      username: ci
      password:
        from_secret: registry_token
    when:
      - event: tag
```

### Two step types

- **Command steps** (`commands:`) - run arbitrary commands in a container image.
- **Plugin steps** (`settings:`) - use pre-built plugin images that accept structured
  config. Plugin ecosystem is small (~50 common plugins); for anything niche, fall back
  to command steps with shell scripts.

### Secrets

Secrets live in the Woodpecker UI, scoped per-repo or per-org. Reference with
`from_secret: <name>`. No environment scoping (closer to Forgejo than GitHub here).

### Setup on Gitea / Forgejo

1. Register an OAuth app in Gitea (`Settings -> Applications -> OAuth2 Applications`).
2. Deploy Woodpecker server + at least one agent (docker-compose reference in the
   Woodpecker docs).
3. Point `WOODPECKER_GITEA=true` and `WOODPECKER_GITEA_URL=https://git.example.com` at
   the server; paste the OAuth client ID/secret.
4. In Woodpecker UI, activate the repo - it installs the webhook automatically.

For Forgejo, swap `WOODPECKER_GITEA*` for `WOODPECKER_FORGEJO*`.

### Matrix builds

Woodpecker supports true matrix at the pipeline level, which Gitea/Forgejo Actions still
handle awkwardly:

```yaml
matrix:
  NODE_VERSION: [20, 22]
  OS: [linux/amd64, linux/arm64]

steps:
  - name: test-${NODE_VERSION}-${OS}
    image: node:${NODE_VERSION}
    commands:
      - npm test
```

---

## Choosing between Gitea Actions and Woodpecker

**When Woodpecker beats Gitea Actions**:
- Gitea instance is older than 1.21 (no Actions support)
- You want CI as an independent service (easier to scale runners, easier to swap later)
- You need proper matrix builds, caching primitives, or per-step resource limits - Actions
  covers matrix but caching is weaker and resource limits are runner-level only
- You want a smaller attack surface than full Actions compatibility brings

**When Gitea Actions beats Woodpecker**:
- Migrating from GitHub - copy-paste `.github/workflows/` with light edits
- Want one service to operate and monitor
- Need the GitHub Actions marketplace ecosystem (most actions work; some need mirroring)

---

## Drone (legacy)

Drone was the original Gitea CI pairing. Harness acquired it in 2021 and effectively stopped
maintaining the OSS edition. Existing deployments work; do not start new Drone installs. Woodpecker is a community fork that kept the project alive and diverged significantly;
the YAML is related but not drop-in compatible.

---

## Cross-references

- Forgejo Actions patterns (same engine, mostly transferable): Forgejo Actions patterns section above and the `SKILL.md` key-differences table
- GitHub Actions supply chain hardening: `references/github-actions.md`
- Supply chain incident patterns: `references/supply-chain.md`
