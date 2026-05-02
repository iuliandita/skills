# CI/CD Best Practices: Patterns That Hold Up

Opinionated patterns for building CI/CD pipelines that stay useful over time. Focused on
**integration decisions** - what to run, where, when, and how strictly - not on tool
tutorials. Tools change; the patterns don't.

Scope: dependency updates, linting, scanning, review gates, and rollout. For tool-specific
usage, see:

- SHA pinning, SBOM, cosign: `supply-chain.md`
- Platform-specific syntax: `github-actions.md`, `gitlab-ci.md`, `forgejo-gitea-actions.md`
- Self-hosted runners: `runners.md`
- Code-level security findings and OWASP-style audits: the **security-audit** skill
- PR review mechanics: the **code-review** skill

---

## 1. Dependency Update Strategy

Automated dependency updates are not optional in 2026. The question is only which bot,
what frequency, and what auto-merges.

### Dependabot vs Renovate

| Factor | Dependabot | Renovate |
|--------|-----------|----------|
| Platforms | GitHub only | GitHub, GitLab, Bitbucket, Azure DevOps, Gitea, Forgejo |
| Ecosystems | ~20 | 90+ |
| Grouping | Limited (by ecosystem + update type) | Arbitrary regex/rules; monorepo presets |
| Auto-merge | Requires separate GitHub Action workflow | Built-in, config-driven |
| Security-only updates | Default path | Available via `vulnerabilityAlerts` |
| Config | `.github/dependabot.yml` | `renovate.json` (or org-level preset) |
| Setup cost | Zero on GitHub | App install + JSON config |

**Rule of thumb**: GitHub-only, small repo, you want it working in five minutes -
Dependabot. Monorepo, multi-forge, or more than one project sharing update policy -
Renovate. The two can co-exist but don't; pick one per repo.

**Forgejo/Gitea note**: Dependabot does not work there. Renovate is the only viable
automated updater. Run Renovate on a schedule via Forgejo/Gitea Actions (self-hosted
Renovate) or use the hosted Renovate app on Codeberg if your repo is there.

### What to group

Noise is the enemy. A repo generating 30+ update PRs per week gets ignored. Group
aggressively:

- **By ecosystem**: all Node.js dev dependencies in one PR, all production in another
- **By scope**: all AWS SDK packages, all OpenTelemetry packages, all linting tools
- **By update type**: all patches together, all minor together, majors individually
- **By vendor monorepo**: `@aws-sdk/*`, `@sentry/*`, `@opentelemetry/*`

Renovate preset for this: `"extends": ["config:recommended", "group:allNonMajor",
"group:monorepos"]`. Dependabot does ecosystem + update-type grouping only (added in 2023);
it cannot do vendor-monorepo grouping.

### Auto-merge policy

The safe default:

| Change | Auto-merge? |
|--------|-------------|
| Patch update to dev dependency | Yes, if CI green |
| Patch update to production dependency | Yes, if CI green AND has tests for the changed area |
| Minor update to dev dependency | Yes, if CI green |
| Minor update to production dependency | Manual review |
| Major update (anything) | Always manual |
| Security update (any severity) | Auto-open, manual merge (never skip review on sec) |
| Indirect / transitive | Usually auto if direct passes |

"CI green" must include tests, not just lint. Auto-merging on lint-only gates has bitten
enough teams that it's a documented anti-pattern.

### Security-only updates

For repos with low tolerance for churn (stable libraries, old LTS branches), configure
the bot to open PRs **only for security advisories**:

- Dependabot: `open-pull-requests-limit: 0` on the main config + rely on the separate
  `version: 2` security updates path (security updates are opened regardless of limits)
- Renovate: `"extends": ["default:disableAllUpdates", "security:only"]`

Pair with a quarterly "update sweep" where someone manually bumps everything else.

### Lockfiles and pinning

- **Commit lockfiles.** `package-lock.json`, `bun.lock`, `Cargo.lock`, `go.sum`,
  `uv.lock`, `Pipfile.lock`. The lockfile is the reproducibility guarantee; the manifest
  alone is not.
- **Never hand-edit lockfiles.** Regenerate after manifest changes. Hand-edits break
  integrity checksums and bite months later.
- **Libraries vs applications**: libraries commit manifests but typically not lockfiles
  (consumers resolve); applications always commit lockfiles. Exception: Rust libraries
  that ship binaries commit both.
- **Pin dev tooling.** Your linter version matters - `eslint@9.17.0` vs `eslint@9.18.0`
  can flip lint results on unchanged code. Pin via the same lockfile.

### Ignore lists, not forever

Every `ignore` / `allowlist` entry needs an expiry date in a comment. Unmaintained ignore
lists become zombie tech debt. Example:

```json
{
  "ignoreDeps": [
    "lodash"
  ],
  "// lodash": "Pinned at 4.17.21 pending audit - revisit 2026-Q2 - owner: platform"
}
```

---

## 2. Linting: Pre-commit -> CI -> Blocking

Linting works when it's fast locally and authoritative in CI. Three layers, each with a
different job:

### Layer 1: Pre-commit (local, optional but recommended)

Catch the obvious stuff before the commit ever happens. Use `prek` (Rust, 10x faster) or
`pre-commit` (Python, bigger ecosystem). Shared config at `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.2
    hooks:
      - id: ruff
      - id: ruff-format
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.7
    hooks:
      - id: actionlint
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.24.0
    hooks:
      - id: gitleaks
```

Pre-commit is advisory. Do not treat it as the source of truth - developers can skip it
with `--no-verify` or have it misconfigured locally. CI runs the same checks to enforce.

### Layer 2: CI (authoritative)

CI runs the full linter suite on every PR. Same config as pre-commit where possible, so
there's no "works on my machine" divergence.

Language-specific linters to wire up:

| Language | Linter | Notes |
|----------|--------|-------|
| Python | `ruff` (replaces flake8 + black + isort + more) | Fast, opinionated, one-tool-fits-most |
| JS/TS | `eslint` + `prettier` | Or `biome` (Rust-based, replaces both) |
| Go | `golangci-lint` | Wraps 50+ linters, one config |
| Rust | `cargo clippy` + `cargo fmt` | Both blocking |
| Shell | `shellcheck` | Blocking; mature since forever |
| YAML | `yamllint` | Catches stupid indentation bugs |
| Dockerfile | `hadolint` | Flags anti-patterns like `ADD` instead of `COPY` |
| Terraform | `tflint` + `terraform fmt -check` | Plus `tfsec`/Trivy for security |
| Ansible | `ansible-lint` | |
| Markdown | `markdownlint-cli2` | Optional; useful for docs-heavy repos |

### Layer 3: CI linters people forget

These lint your **CI itself** and catch bugs that would otherwise only show up at runtime:

- **`actionlint`** - lints GitHub Actions / Forgejo Actions / Gitea Actions YAML for
  syntax errors, unknown expressions, outdated action versions. Run on every PR touching
  `.github/workflows/` or `.forgejo/workflows/`.
- **`shellcheck`** on inline `run:` blocks - `actionlint` invokes it automatically for
  shell steps.
- **`yamllint`** on all CI YAML - catches tab/space mix-ups and duplicate keys before the
  pipeline silently uses the wrong value.
- **`hadolint`** on Dockerfiles that run in CI (including runner images).

These four catch more real bugs per line of config than any other CI-lint investment.

### Caching lint tools

Lint jobs should complete in under 60s. Slow lint = skipped lint. Cache:

- Python: `~/.cache/ruff`, `~/.cache/pre-commit` (key: hash of lock file + config)
- Node: `~/.cache/npm` or `bun install --frozen-lockfile` cached; `eslint` cache file
- Go: `~/.cache/go-build`, `~/go/pkg/mod`
- Rust: `~/.cargo/registry`, `target/` (with `cargo-cache` or `Swatinem/rust-cache`)

### Fix vs check

In CI, always run with `--check` / `--no-fix`. Auto-fix in CI is a foot-gun: the PR's
HEAD gets silently rewritten, reviews get harder, and merge conflicts appear from
nowhere. Auto-fix belongs in pre-commit or a manual `make fix` target.

---

## 3. Scanning: What, When, Where

Scanners all claim "shift left." In practice, you run different scanners at different
pipeline stages for different reasons.

### Scanning matrix

| Scanner type | Tool (2026 default) | Pre-commit | On PR | On merge to main | Pre-release | Continuous |
|--------------|--------------------|-----------:|:-----:|:----------------:|:-----------:|:----------:|
| Secret scanning | `gitleaks` (or `trufflehog`) | Yes | Yes | Yes | - | Yes (push-protection) |
| SCA (library CVEs) | Trivy `fs` or Grype | - | Yes | Yes | Yes | Yes (cron) |
| Container image | Trivy `image` or Grype | - | On image change | Yes | Yes (blocking) | Yes (registry-side) |
| IaC misconfig | Trivy `config` (absorbs tfsec) + Checkov | - | On IaC change | Yes | - | - |
| SAST | Semgrep / CodeQL | - | Yes | Yes | Yes | Weekly deep scan |
| License | Trivy `--scanners license` or FOSSA | - | Yes | Yes | Yes | - |
| SBOM | Syft | - | - | Yes (artifact) | Yes (attest) | - |

### Secret scanning: three layers

1. **Push protection** at the forge (GitHub Secret Scanning, Gitea/Forgejo via gitleaks
   server-side hook). Rejects the push entirely if a known secret pattern is detected.
2. **Pre-commit** with `gitleaks protect` - same scan client-side, faster feedback.
3. **CI on every PR** - catches what slipped past both. Run against `git diff` to keep
   it fast, not the full history.

Scan the **diff**, not the whole repo, on every PR. Full-history scans belong on a
nightly cron or pre-release job; they take minutes and block nothing useful on a PR.

### Container scanning: Trivy vs Grype

Both are good. Pick one per pipeline and stick with it.

- **Trivy** - one binary, scans images + filesystems + IaC + secrets + licenses. Good
  default for teams who want fewer tools. After the 2025 TeamPCP incident, pin to a
  verified version (`v0.69.3` or later from a trusted source; avoid `v0.69.4/5/6` which
  were compromised).
- **Grype** - vulnerability-matching only, but has **risk scoring** that combines CVSS
  + EPSS (exploit probability) + CISA KEV. Better signal-to-noise on severity gates -
  a critical CVE with 0.1% EPSS is not the same as a high CVE in CISA KEV with 95% EPSS,
  and Grype surfaces that difference.

Run container scans **twice**:

1. **In the image build pipeline**, before push to registry. Fail the build on severity
   threshold exceeded.
2. **Registry-side, continuously** (Harbor, GHCR, ECR all have this). Catches CVEs
   published after your image was built. Feed findings into an alert, not a build break.

### Severity gates: ratchet pattern

Turning on a scanner that finds 400 Criticals and blocking CI is how scanners get turned
off the next day. The rollout that works:

1. **Week 1** - run the scanner, **non-blocking**, post findings as a PR comment. Team
   sees the reality.
2. **Week 2-3** - fix or suppress every Critical. Record the baseline.
3. **Week 4** - turn on **blocking for new Criticals only** (compare against baseline).
   Existing Criticals stay in the ignore list with an expiry date.
4. **Month 2** - extend to Highs for new vulnerabilities.
5. **Month 3+** - work through the baseline. Drop entries as vulnerabilities are fixed.

Non-blocking forever means nobody fixes anything. Blocking from day 1 means nobody ships.
The ratchet lets both work.

### How to implement "block on new only" in practice

"Compare against baseline" sounds nice; the mechanic varies per scanner:

- **Trivy**: maintain `.trivyignore` at the repo root. One CVE ID per line with an expiry
  comment (`CVE-2024-XXXXX  # glibc, upstream fix pending, revisit 2026-Q3 - owner: platform`).
  Run `trivy image --ignorefile .trivyignore --exit-code 1 --severity CRITICAL ...` in CI.
  CVEs in the ignore file pass; anything new fails. Trivy has no built-in diff mode;
  the ignorefile *is* the baseline.
- **Grype**: similar via `--fail-on critical` + a `.grype.yaml` `ignore:` block keyed by CVE
  ID. Supports glob-style matching for transient fix windows.
- **Docker Scout / Snyk / Anchore Enterprise**: these have first-class "baseline" or
  "policy" objects stored server-side - CI reads the policy rather than a file.
- **GitHub Secret Scanning, Dependabot**: baseline is implicit - the forge remembers which
  alerts are open, dismissed, or resolved. CI just blocks on "new alerts" without a file.

Whichever scanner, **expiry dates on ignore entries are the load-bearing bit**. Without
them, suppressions become zombie tech debt and the baseline grows forever. Put the expiry
in a comment and run a quarterly sweep to revisit expired entries.

### SAST: don't block on it

SAST tools (Semgrep, CodeQL, SonarQube) generate false positives. Run them on PRs for
visibility and as a weekly deep scan against main, but **don't gate merges on SAST
findings** unless you have a tuned ruleset and a team that triages weekly. Gating on
noisy SAST is how you get "SAST fatigue" and ignored findings.

Exception: very specific SAST rules with near-zero false positives (e.g. Semgrep's
`hardcoded-secret`, `dangerous-eval`) are fine to block on.

### License scanning

Default ignored; flipped on when legal asks. Trivy `--scanners license` is the simplest.
Block on "unknown" or "copyleft-strict" (AGPL-3.0) when the org's license policy
prohibits them; otherwise advisory only.

---

## 4. Review Gates and Policy-as-Code

CI enforces mechanical checks. Reviews enforce judgment. Both need to be
automatable-but-not-automated.

### CODEOWNERS

`.github/CODEOWNERS` / `.gitlab/CODEOWNERS` / `.forgejo/CODEOWNERS`. Path-based
auto-assignment for reviews. Keep it specific enough to be useful, general enough to be
maintainable:

```
# Own by default
*                                   @org/platform

# Security-critical paths need security team
/auth/                              @org/platform @org/security
/crypto/                            @org/security
.github/workflows/                  @org/platform @org/security

# Infra changes need SRE
/terraform/                         @org/sre
/k8s/                               @org/sre
/.github/actions/                   @org/sre @org/platform

# Domain ownership
/services/payments/                 @org/payments-team
/services/notifications/            @org/messaging-team
```

Pair with **required review from CODEOWNERS** in branch protection. Without the "required
review" bit, CODEOWNERS is suggestion-only.

### Changed-path deployment fan-out

For infra repos that deploy by changed path, inspect the workflow before assuming one
top-level deploy command runs on every push. Many Forgejo/Gitea/GitHub workflows use a
detect-changes job that emits booleans for specific roles, playbooks, services, or
inventory areas.

When adding a new deployable path, update all required pieces together:

- workflow `on.push.paths` / `on.pull_request.paths` entries when path filtering is used
- detect-change outputs, such as `baseline: ${{ steps.changes.outputs.baseline }}`
- deploy jobs that actually run the new playbook, service deploy, or image build
- manual `workflow_dispatch` inputs for one-shot reruns when production operations need them

Validation:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml
yaml.safe_load(Path('.forgejo/workflows/deploy.yml').read_text())
print('yaml-ok')
PY

git diff --check
```

After pushing, verify with the forge's Actions task view or CLI. A broad path filter
like `infra/**` can trigger the workflow while every fan-out job skips if no
detect-change output matches the new path. Include the workflow file itself in
path filters if workflow edits should trigger a verification run.

### Required status checks

On protected branches, require:

| Check type | Required? | Why |
|------------|-----------|-----|
| Lint | Yes | Cheap; no reason to ever merge lint failures |
| Unit tests | Yes | The baseline contract |
| Integration tests | Yes (on main-bound PRs) | Catches integration bugs |
| E2E tests | Maybe | Flaky E2E breaks more PRs than it catches bugs - gate as advisory until flake rate <1% |
| Type check | Yes (for typed languages) | Cheap |
| Build | Yes | If CI can't build, nobody can |
| Secret scan | Yes | Blocking on secrets is non-negotiable |
| Container scan | Yes (for new/changed Criticals only) | Ratchet pattern above |
| SAST | Advisory | Too noisy for hard block |
| Coverage | Usually no, sometimes yes | Covered below |
| SBOM diff | Advisory | Surfaces dependency changes for review |

### Coverage thresholds

"95% coverage or the build fails" is a cargo cult. Coverage measures what's exercised,
not what's tested. Reasonable patterns:

- **No regression below baseline**: block if coverage drops more than 0.5% from main.
  Rewards adding tests without demanding perfection.
- **Per-PR coverage floor**: changed lines in the PR must hit some threshold
  (`codecov` / `coverallsapp` support this as "patch coverage"). Forces new code to be
  tested without re-testing legacy.
- **No overall threshold on untested legacy code**. Don't demand 80% coverage on a
  codebase that has 15% - you'll get tests written to cover lines, not behavior.

### Merge queues

For high-velocity repos, merge queues prevent "green PR merges, base branch goes red
five minutes later" - the classic PR interaction bug.

| Forge | Mechanism | Behavior |
|-------|-----------|----------|
| GitHub | Merge Queue (GA 2023) | Sequential: creates a temp branch with base + queued PRs; reruns required checks against that; merges if green. Workflows need `on: merge_group` trigger. |
| GitLab Premium+ | Merge Trains | Parallel: each queued MR gets a cumulative-state ref; pipelines run in parallel. If one fails, it drops out and subsequent pipelines restart. |
| Forgejo/Gitea | No native merge queue. Use `merge-queue` GitHub Action or manual coordination. |
| Bitbucket | "Auto-merge" but not a true merge queue. |

Rule of thumb: enable a merge queue once you have >5 PRs merging per day and >2% of
merges trigger a post-merge revert. Below that, the queue adds latency without much
benefit.

### Policy-as-code (advanced)

When review rules get complex enough to encode, reach for policy engines:

- **OPA / Conftest** - write Rego policies that gate CI or admission. Good for
  Terraform/K8s manifests, container images, PR metadata ("all PRs touching X must have
  label Y").
- **Sentinel** (Terraform Enterprise) - same idea, HashiCorp-native.
- **GitLab Security Policies** / **GitHub Repository Rulesets** - declarative policies
  that apply across repos in an org. Use these over per-repo branch protection when
  managing >20 repos.

---

## 5. Rollout Order

Introducing all of the above at once is how you get an org-wide pipeline revolt. The
order that works in practice:

### Week 1-2: foundation

1. **Lockfiles everywhere** + **lint-as-CI** (advisory, informational comment only).
   No team hates learning that `yamllint` catches real bugs.
2. **Secret scanning, blocking.** Secrets are the one thing that should block from day
   one. Gitleaks on PR + push protection if the forge supports it.
3. **Dependabot or Renovate**, configured for weekly schedule, grouping on, **no
   auto-merge yet**.

### Month 1: gates

4. **Lint becomes blocking.** Fix everything that fails; then flip the switch.
5. **Test suites blocking** on the paths everyone touches. Unit + integration for core.
6. **Branch protection + CODEOWNERS.** Required review, no direct push to main.

### Month 2: security

7. **Container scan, non-blocking**, post findings to PR.
8. **Baseline existing Criticals.** Fix what you can; suppress what you can't with
   expiry dates.
9. **Container scan blocking on new Criticals.**
10. **SBOM generation** on releases (attest but don't gate).

### Month 3: polish

11. **Auto-merge for Dependabot/Renovate patches** with test gates.
12. **Merge queue** if velocity warrants it.
13. **Ratchet up** scan severity: Highs now gate.
14. **Coverage regression gate** (not absolute threshold).

### Don't do these

- **Block day 1 on SAST.** False-positive fatigue guaranteed.
- **Block on absolute coverage thresholds.** Tests get written to fix the number, not the
  code.
- **Auto-merge majors.** Semver is not a contract with reality.
- **Turn on 10 scanners at once.** Each needs baseline + triage time; the team hits
  "ignore all" mode and you're worse off than before.
- **Require every check to pass on drafts.** Drafts are for WIP; save the gate budget
  for ready-for-review PRs.

---

## Cross-references

- SHA pinning, image signing, SBOM attestations: `supply-chain.md`
- Platform-specific pipeline syntax: `github-actions.md`, `gitlab-ci.md`, `forgejo-gitea-actions.md`
- Self-hosted runner hardening: `runners.md`
- Tool-level security audits (CVE triage, exploit chains): **security-audit** skill
- PR-level code review practices: **code-review** skill
- Git workflow that pairs with these CI gates: **git** skill
