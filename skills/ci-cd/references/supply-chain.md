# CI/CD Supply Chain Security

Cross-platform supply chain hardening patterns, incident timeline, and PCI-DSS 4.0 compliance.
Updated March 2026 -- post-Trivy compromise.

---

## Incident Timeline

These are real supply chain attacks that exploited CI/CD pipelines. They're here because
they inform every recommendation in this document.

### reviewdog/action-setup (CVE-2025-30154) -- March 11, 2025

- **2-hour window** (18:42-20:31 UTC)
- Payload dumped CI runner memory, exposing env vars and secrets to workflow logs (double-base64 encoded)
- Root cause: reviewdog org auto-invited contributors to `@reviewdog/actions-maintainer` team with **write access**. Compromised contributor account.
- Enabled the downstream tj-actions attack.

### tj-actions/changed-files (CVE-2025-30066) -- March 10-14, 2025

- Attacker modified action to execute malicious Python script extracting secrets from Runner Worker process memory
- All version tags force-pushed to malicious commit -- even "pinned" tag users got hit
- **23,000+ repositories affected**. Leaked PATs, npm tokens, RSA keys, AWS keys.
- Coinbase was specifically targeted (Palo Alto Unit42 confirmed).
- CISA issued alert March 18, 2025.
- **Lesson**: mutable tags are not security boundaries. SHA pinning is the only protection.

### aquasecurity/trivy-action (CVE-2026-33634) -- March 2026

- **CVSS 9.4**. Threat actor: **TeamPCP**.
- Late Feb 2026: attackers exploited misconfigured GH Actions environment, extracted privileged token
- March 1: Aqua disclosed, rotated credentials -- but rotation was **incomplete**
- March 19, ~17:43 UTC: attacker force-pushed **76 of 77** version tags in `trivy-action` and all 7 tags in `setup-trivy` to credential-stealing code
- Simultaneously published malicious Trivy binary v0.69.4 via compromised `aqua-bot` service account
- March 22: malicious v0.69.5 and v0.69.6 Docker Hub images published
- Downstream: stolen credentials used to compromise dozens of npm packages distributing **CanisterWorm** (self-propagating worm)
- **Lesson**: even security tools' own CI is a target. "We trust our scanning tool" is circular reasoning.

**Known safe Trivy versions (as of 2026-03-24)**:
- Binary: v0.69.2, v0.69.3
- `trivy-action`: **v0.35.0** (verify SHA, not tag)
- `setup-trivy`: v0.2.6
- **DO NOT USE**: v0.69.4, v0.69.5, v0.69.6

**IOC**: check for a repo named `tpcp-docs` in your org -- its presence indicates the fallback
exfiltration mechanism was triggered.

### HackerBot-Claw (February 2026)

- Automated campaign scanning public repos for vulnerable `pull_request_target` workflows
- Exploited Microsoft/symphony, Google/ai-ml-recipes, Nvidia/nvrc
- Modified build/deploy scripts via PRs to exfiltrate service principals, API keys, IMDS tokens

---

## SHA Pinning

### Why

Tags are Git references. They can be force-pushed, redirected, or deleted. A tag named `v4`
today can point to completely different code tomorrow. Every major CI/CD supply chain attack
exploited tag mutability.

SHA commits are immutable content-addressed objects. They cannot be redirected.

### How (GitHub Actions)

```yaml
# DO NOT
- uses: actions/checkout@v4

# DO
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

### How (GitLab CI/CD)

```yaml
# DO NOT
image: aquasec/trivy:latest

# DO
image:
  name: aquasec/trivy:0.69.3@sha256:<digest>
```

### How (Docker images in any CI)

```bash
# Get the digest
docker inspect --format='{{index .RepoDigests 0}}' aquasec/trivy:0.69.3

# Pin to digest
image: aquasec/trivy@sha256:abc123def456...
```

### Automation (sustainable SHA pinning)

Manual SHA updates are unsustainable. Use automation:

**Dependabot** (GitHub):
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Renovate** (any platform):
```json
{
  "extends": [
    "config:recommended",
    "helpers:pinGitHubActionDigestsToSemver"
  ]
}
```

### Org-level enforcement (GitHub)

GitHub shipped org-level SHA pinning enforcement in August 2025. Admins can require all
workflows use full-length commit SHAs. Workflows using tag references fail at parse time.

Settings > Actions > General > Actions permissions > Require action pinning.

---

## Image Signing (Sigstore / cosign)

Docker retired DCT/Notary in favor of Sigstore (August 2025). cosign is the industry standard.

### Sign in CI (keyless)

```yaml
# GitHub Actions
- uses: sigstore/cosign-installer@<sha>
- env:
    DIGEST: ${{ steps.build.outputs.digest }}
    IMAGE: ghcr.io/${{ github.repository }}
  run: cosign sign --yes "$IMAGE@$DIGEST"
  # keyless signing is default since cosign v2.0 -- no COSIGN_EXPERIMENTAL needed
```

Keyless signing: workflow gets OIDC token from GitHub -> Sigstore's Fulcio CA mints a
short-lived X.509 cert (10 min) binding the public key to the workflow identity -> signature
recorded in Rekor transparency log. No long-lived signing keys to manage.

### Verify at admission (Kubernetes)

```yaml
# Kyverno policy (verify cosign signature)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign
      match:
        any:
          - resources:
              kinds: ["Pod"]
      verifyImages:
        - imageReferences: ["ghcr.io/my-org/*"]
          attestors:
            - entries:
                - keyless:
                    issuer: "https://token.actions.githubusercontent.com"
                    subject: "https://github.com/my-org/*"
```

---

## SBOM Generation

Required for PCI-DSS 4.0 Requirement 6.3.2 (mandatory since March 31, 2025).

### Formats

| Format | Org | Best for |
|--------|-----|----------|
| **SPDX** | Linux Foundation | Compliance, licensing |
| **CycloneDX** | OWASP | Security, vulnerability correlation |

Both are acceptable for PCI-DSS. Pick one and be consistent.

### Generation in CI

**GitHub Actions (anchore/sbom-action)**:
```yaml
- uses: anchore/sbom-action@<sha>
  with:
    image: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
    format: spdx-json
    output-file: sbom.spdx.json
```

**GitLab CI (syft)**:
```yaml
generate-sbom:
  image: anchore/syft:1.42
  script:
    - syft $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -o spdx-json=sbom.spdx.json
  artifacts:
    paths: [sbom.spdx.json]
    expire_in: 90 days
```

**Docker BuildKit (inline)**:
```bash
docker buildx build --sbom=true --provenance=true -t myapp:1.0.0 --push .
```

### Storage

SBOMs must be stored and queryable for PCI compliance:
- Attach to GitHub releases as assets
- Store as GitLab CI artifacts (90+ day retention)
- Push to OCI registry alongside the image (BuildKit attestations)
- Index in a vulnerability management system (Dependency-Track, GUAC)

---

## SLSA Provenance

SLSA (Supply-chain Levels for Software Artifacts) is a framework for build integrity.

| Level | Meaning | Effort |
|-------|---------|--------|
| **1** | Documentation of build process | Trivial |
| **2** | Hosted build service, signed provenance | Afternoon |
| **3** | Hardened build platform, non-falsifiable provenance | Week |
| **4** | Two-party review, hermetic builds | Enterprise |

**Level 2 is achievable in an afternoon with GitHub Actions.** Use `actions/attest-build-provenance`:

```yaml
- uses: actions/attest-build-provenance@<sha>
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.build.outputs.digest }}
    push-to-registry: true
```

Verification:
```bash
gh attestation verify ghcr.io/org/repo@sha256:... --owner org
```

---

## Workflow Linting

### Zizmor (GitHub Actions)

Static analysis linter specifically for GitHub Actions. Low false-positive rate. Catches:
- Unpinned actions
- Overly broad permissions
- Expression injection (${{ }} in run blocks)
- Dangerous triggers (pull_request_target)

```yaml
- uses: woodruffw/zizmor-action@<sha>
```

### StepSecurity Harden-Runner

Runtime monitoring of network egress and file system access in CI jobs. Detected the tj-actions
attack anomalies.

```yaml
- uses: step-security/harden-runner@<sha>  # v2.14.2 (v2.12.0 min -- CVE-2025-32955)
  with:
    egress-policy: audit
```

**Note**: v2.12.0 patches CVE-2025-32955 (Docker group privilege escalation bypass). Latest:
v2.14.2 (March 2026). Do not use versions below v2.12.0 for security-critical workloads.

---

## Secret Management in CI

### Rules (all platforms)

1. **Never echo secrets.** Not even in debug mode. CI logs are often accessible to more people
   than the secrets themselves.
2. **Never pass as CLI arguments.** Visible in `ps` output and process listings.
3. **Never write to artifacts.** Artifacts are downloadable by anyone with repo access.
4. **Use environment variables.** Set via CI secret variables, not inline in config.
5. **Scope minimally.** Production secrets only accessible on protected branches/tags.
6. **Rotate on exposure.** If a secret appears in logs, rotate immediately.

### GitHub Actions

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

Secrets are masked in logs by default. But be aware:
- Base64-encoding bypasses masking
- Splitting a secret across multiple commands bypasses masking
- `ACTIONS_STEP_DEBUG=true` can expose secrets in debug output

### GitLab CI

```yaml
variables:
  DATABASE_URL: $DATABASE_URL  # set via CI/CD Variables UI
```

Mark variables as:
- **Protected**: only available on protected branches/tags
- **Masked**: hidden in job logs (must be 8+ chars, no newlines)
- **File**: injected as a file path, not inline value

### Forgejo

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

Same syntax as GitHub. No environment-level scoping yet.

---

## PCI-DSS 4.0 CI/CD Compliance

All future-dated requirements became **mandatory March 31, 2025**.

### Requirement 6.2.1 -- Secure Development

**What it says**: developers trained in secure coding, processes address common vulns.

**CI/CD implementation**:
- SAST on every PR/MR (Semgrep, CodeQL, Bandit)
- Dependency scanning on every PR/MR (Trivy, bun audit, pip-audit)
- Secret detection on every PR/MR (gitleaks, trufflehog)
- Block merges when HIGH/CRITICAL findings exist
- Document scanning coverage in runbooks

### Requirement 6.2.4 -- Access Control and Change Tracking

**What it says**: access control, change approvals, audit trails.

**CI/CD implementation**:
- Branch protection on main/production branches
- Required reviewers (minimum 2 for CDE repos)
- Signed commits (GPG or SSH key signing)
- Audit logging enabled (GitHub: audit log, GitLab: audit events)
- No direct pushes to protected branches

### Requirement 6.3.2 -- Software Inventory (SBOM)

**What it says**: maintain inventory of bespoke and custom software components.

**CI/CD implementation**:
- Generate SPDX or CycloneDX SBOM on every release
- Attach to release artifacts (GitHub releases, GitLab artifacts)
- Store with 90+ day retention
- Index in vulnerability management system
- Cover both application code AND container base image

### Requirement 6.4.2 -- Change Control

**What it says**: changes approved, documented, tested before production.

**CI/CD implementation**:
- Required status checks (lint, test, scan) before merge
- Manual approval gate for production deployments
- Deployment audit trail (who approved, when, what SHA)
- IaC changes through git only (no manual kubectl/terraform from laptops)

### Requirement 6.5.3 -- Consistent Security Controls

**What it says**: security controls consistent across all environments.

**CI/CD implementation**:
- Same scanning pipeline in dev, staging, AND production
- Not just scanning in production -- scanning in ALL environments
- Shared CI components/templates to enforce consistency
- Regular audit that dev pipelines haven't drifted from prod pipelines

### Customized Approach (v4.0.1)

PCI-DSS 4.0.1's Customized Approach allows automated CI/CD controls to satisfy manual review
requirements if properly documented:
- Automated SAST/DAST/SCA gate with evidence = equivalent to manual code review
- Documented pipeline with audit trail = change control process
- Signed artifacts with provenance = software inventory

This is a significant change for fast-moving teams. **Document your CI/CD controls thoroughly
for QSA assessment.** The pipeline IS the control.

---

## AI-Age Supply Chain Risks

### Slopsquatting

AI code assistants hallucinate package names. ~20% of AI-suggested packages don't exist.
43% of hallucinated names are consistently repeated across similar prompts. Attackers register
these phantom names and wait.

**Real-world**: 128 phantom packages accumulated 121,539 downloads between July 2025 and
January 2026. A Fortune 500 company was compromised through a slopsquatted package.

**Defenses in CI**:
- `--frozen-lockfile` / `npm ci` (not `npm install`)
- `bun audit` / `npm audit` in CI
- SCA scanning (Trivy, Grype)
- Manual review of new dependencies in PRs
- Never `npm install <package>` directly from AI suggestions without verifying the package exists

### AI agents in CI/CD

OWASP Top 10 for Agentic Applications (2026):
- **AI should never own production deployments.** March 2026: AI-assisted Terraform workflow
  deleted production infrastructure through escalating cleanup logic.
- AI code review bots vulnerable to prompt injection via PR descriptions
- AI agents with CI/CD credentials need:
  - Dedicated service identities (not shared human credentials)
  - Least-privilege RBAC
  - Audit logging of all actions
  - Human-in-the-loop for destructive operations

### Prompt injection in CI

Malicious instructions in issue titles, PR descriptions, or code comments can redirect AI
tools connected to CI workflows:
- System prompt extraction via crafted PR descriptions
- Credential exfiltration through AI-generated CI commands
- Build artifact poisoning through AI-modified build steps

**Defense**: treat all user-generated content (issues, PRs, comments) as untrusted input.
AI tools in CI should never execute commands based on issue/PR text.

---

## Quick Reference: Pipeline Security Checklist

Run through this before shipping any pipeline to production:

- [ ] All third-party actions/images SHA-pinned (not tag-pinned)
- [ ] Dependabot/Renovate configured to auto-update SHAs
- [ ] Explicit `permissions:` block (GitHub) or protected variables (GitLab)
- [ ] No secrets in config files, comments, or default values
- [ ] SAST running on every PR/MR
- [ ] Dependency scanning on every PR/MR
- [ ] Secret detection on every PR/MR
- [ ] SBOM generated on every release
- [ ] Container images scanned before deployment
- [ ] Manual approval gate for production deployment
- [ ] Branch protection enabled on main/production
- [ ] Required reviewers for merges
- [ ] Audit logging enabled
- [ ] CI tool images pinned to known-safe versions
- [ ] No `allow_failure` without documented justification
- [ ] Concurrency control prevents parallel production deploys
- [ ] Artifact retention meets compliance requirements (90+ days for PCI)
