# Gitea CI/CD: Patterns & Templates

Gitea ships two viable CI paths in 2026. Which one you use depends on the instance version
and whether you want CI baked into Gitea or run as a separate service.

| Option | When it fits | Syntax |
|--------|--------------|--------|
| **Gitea Actions** (since Gitea 1.21, GA) | Migrating from GitHub; want CI in the same service | GitHub Actions subset (act-based) |
| **Woodpecker CI** (3.x, 2026) | Pre-1.21 Gitea, lightweight self-host, matrix/caching focus | Woodpecker YAML, `.woodpecker/*.yaml` |
| **Drone** (legacy) | Existing deployments only - unmaintained since Harness acquisition | Drone YAML |

Do not run both Gitea Actions and Woodpecker for the same repo; pick one. Running both
means two sets of webhooks, two runners, double the secret surface.

---

## Gitea Actions

Same `act`-based engine as Forgejo Actions, same GitHub Actions syntax subset, same SHA
pinning and action resolution concerns. All Forgejo Actions guidance in `SKILL.md` applies,
with these differences:

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
- **Runner labels** - no `ubuntu-latest`. Use the labels registered with `act_runner`
  (commonly `ubuntu-latest` mapped to a specific image in the runner config, or custom
  labels like `docker`).

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
friendly. Written in Go, MIT-licensed. Current stable: 3.13.x (2026).

### Config layout

`.woodpecker/*.yaml` in the repo root. Each file is a separate pipeline. No
multi-job-per-file like Actions - one pipeline per file, one agent per pipeline by default.

```yaml
# .woodpecker/ci.yaml
when:
  - event: [push, pull_request]
    branch: main

steps:
  - name: lint
    image: oven/bun:1.2
    commands:
      - bun install --frozen-lockfile
      - bun run lint

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
  - name: test-${{ matrix.NODE_VERSION }}-${{ matrix.OS }}
    image: node:${{ matrix.NODE_VERSION }}
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
maintaining the OSS edition. Existing deployments work; do not start new Drone installs in
2026. Woodpecker is a community fork that kept the project alive and diverged significantly;
the YAML is related but not drop-in compatible.

---

## Cross-references

- Forgejo Actions patterns (same engine, mostly transferable): `SKILL.md` Forgejo section
- GitHub Actions supply chain hardening: `references/github-actions.md`
- Supply chain incident patterns: `references/supply-chain.md`
