---
name: ci-cd
description: >
  Use when writing, reviewing, or architecting CI/CD pipelines for any platform --
  GitHub Actions, GitLab CI/CD, or Forgejo CI/CD. Also use for pipeline security,
  supply chain hardening, SHA pinning, SBOM generation, CI/CD compliance (PCI-DSS 4.0),
  workflow optimization, or runner configuration. Triggers: 'ci/cd', 'cicd', 'pipeline',
  'workflow' (CI context), 'github actions', 'gitlab ci', 'forgejo', '.github/workflows',
  '.gitlab-ci.yml', '.forgejo/workflows', 'runner', 'sha pinning', 'actions', 'sbom'
  (CI context), 'supply chain' (CI context).
license: MIT
compatibility: "Optional: gh (GitHub CLI), glab (GitLab CLI)"
paths:
  - ".github/workflows/*.yml"
  - ".gitlab-ci.yml"
  - ".forgejo/workflows/*.yml"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-24"
  effort: high
  argument_hint: "[platform-or-workflow]"
---

# CI/CD Pipelines: Multi-Platform Production Infrastructure

Write, review, and architect CI/CD pipelines across GitHub Actions, GitLab CI/CD, and Forgejo
CI/CD. The goal is secure, fast, auditable pipelines that satisfy both engineering needs and
compliance requirements (PCI-DSS 4.0).

**Target versions** (March 2026):
- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 18.10, CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo CI/CD**: Forgejo v14.0, Runner v12.7.x (multi-connection support since v12.7.0)
- **Supply chain**: cosign v3.x (Sigstore), Syft/Trivy for SBOM, SLSA v1.0

This skill covers four domains depending on context:
- **Workflow design** -- stages, jobs, caching, artifacts, parallelism, reusable patterns
- **Security** -- supply chain hardening, SHA pinning, secret management, OIDC, least-privilege
- **Compliance** -- PCI-DSS 4.0 Req 6.x mapping, SBOM generation, signed artifacts, audit trails
- **Cross-platform** -- writing pipelines that work across GitHub/GitLab/Forgejo, migration patterns

## When to use

- Writing or reviewing CI/CD pipeline configs (workflows, `.gitlab-ci.yml`, Forgejo actions)
- Designing pipeline architecture (stages, parallelism, caching, deployment strategies)
- Hardening pipelines against supply chain attacks (SHA pinning, image signing, provenance)
- Setting up security scanning in CI (SAST, SCA, container scanning, secret detection)
- Configuring runners, caching strategies, or artifact management
- PCI-DSS 4.0 compliance for CI/CD (Req 6.2.1, 6.2.4, 6.3.2, 6.4.2, 6.5.3)
- Migrating pipelines between platforms (GitLab -> GitHub, GitHub -> Forgejo)
- Troubleshooting failed pipelines, flaky jobs, or runner issues

## When NOT to use

- Kubernetes manifests, Helm charts, cluster architecture -- use **kubernetes**
- Dockerfiles, Compose stacks, container image optimization -- use **docker**
- Terraform/OpenTofu infrastructure-as-code -- use **terraform**
- Ansible playbooks, configuration management -- use **ansible**
- Security audits of application code (SAST findings, auth bugs) -- use **security-audit**
- Code review of pipeline-adjacent code (the app itself) -- use **code-review**
- The code-review skill has a `cicd-pipelines.md` reference for **bug patterns** in existing
  pipelines. This skill is for **writing and architecting** pipelines.

---

## AI Self-Check

AI tools consistently produce the same CI/CD mistakes. **Before returning any generated
pipeline config, verify against this list:**

- [ ] **SHA pinning**: all third-party actions/images pinned to full commit SHA or digest, not mutable tags. Add `# vX.Y.Z` comment for readability.
- [ ] **Permissions**: explicit `permissions:` block on every GitHub Actions workflow (read-only default). GitLab: protected variables scoped correctly.
- [ ] **No secrets in config**: no hardcoded tokens, passwords, or API keys. Use CI/CD secret variables or vault integration.
- [ ] **No `latest` tags**: runner images, tool images, and base images pinned to specific versions or SHA256 digests.
- [ ] **Caching strategy**: dependencies cached correctly (lockfile-based keys), build outputs use artifacts (not cache).
- [ ] **Fail-fast security**: SAST, dependency scanning, and secret detection run early (not after deployment).
- [ ] **Manual gates for production**: production deployments require explicit approval (not auto-deploy on merge).
- [ ] **SBOM generation**: release pipelines generate and attach SBOMs (SPDX or CycloneDX). Required for PCI-DSS 4.0.
- [ ] **Minimal scope**: jobs have minimum required permissions, access only needed secrets, and run only needed steps.
- [ ] **No `allow_failure` without justification**: if a job can fail, explain why in a comment.
- [ ] **Version pinning on tools**: `node:22`, not `node:lts`. `python:3.13`, not `python:3`. Specific versions prevent silent breakage.
- [ ] **No expression injection** (GitHub Actions): `${{ }}` expressions never used directly in `run:` blocks. Assign to `env:` first. `github.event.*` is attacker-controlled. Avoid `github.ref_name` in security-sensitive contexts (injectable via crafted tag/branch names).

---

## Workflow

### Step 1: Identify the platform

| Signal | Platform |
|--------|----------|
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI/CD |
| `.forgejo/workflows/*.yml` | Forgejo CI/CD |
| User says "work" / "gitlab" / `glab` | GitLab CI/CD |
| User says "home" / "forgejo" / "gitea" | Forgejo CI/CD |
| User says "github" / "ghcr" / `gh` | GitHub Actions |

If unclear, ask. The platforms have significant differences despite surface similarity.

### Step 2: Determine the domain

- **"Create a CI pipeline for my project"** -> Workflow design
- **"Harden my pipeline" / "pin actions"** -> Security
- **"Make this PCI compliant" / "SBOM"** -> Compliance
- **"Port this from GitLab to GitHub"** -> Cross-platform

### Step 3: Gather requirements

Before writing pipeline config:
- **What triggers the pipeline?** Push, PR/MR, tag, schedule, manual
- **What does it build?** Language, runtime, package manager, build tool
- **What does it test?** Unit, integration, e2e, linting, typechecking
- **Where does it deploy?** K8s, Docker registry, cloud, bare metal
- **What compliance requirements?** PCI-DSS, SOC 2, internal policies
- **Self-hosted or managed runners?** Affects available tools and caching

### Step 4: Apply platform-specific patterns

Read the appropriate reference file:
- **GitHub Actions**: `references/github-actions.md`
- **GitLab CI/CD**: `references/gitlab-ci.md`
- **Supply chain / compliance**: `references/supply-chain.md`

For **Forgejo CI/CD**, see the Forgejo section below (smaller scope, inline).

### Step 5: Verify against AI Self-Check

Run through the checklist above before returning any generated config.

---

## Cross-Platform Patterns

### Stage ordering (all platforms)

```
lint -> test -> build -> scan -> deploy
```

1. **Lint** first -- fastest feedback, catches formatting/syntax early
2. **Test** -- unit tests, typechecking
3. **Build** -- compile, bundle, create artifacts
4. **Scan** -- SAST, dependency audit, container scan (on build output)
5. **Deploy** -- staging auto, production manual

### Caching strategy

| What | Cache key | Platform notes |
|------|-----------|----------------|
| **npm/bun** | `${{ hashFiles('**/package-lock.json') }}` or lockb | GH: `actions/cache`. GL: `cache:key:files`. Forgejo: same as GH. |
| **pip** | `${{ hashFiles('**/requirements*.txt') }}` | GH: cache action. GL: cache with `$CI_COMMIT_REF_SLUG` prefix. |
| **Go** | `${{ hashFiles('**/go.sum') }}` | GH: `actions/setup-go` has built-in cache. |
| **Docker layers** | BuildKit cache mount or registry cache | GH: `--cache-from type=gha`. GL: `--cache-from $CI_REGISTRY_IMAGE:cache`. |

**Rule**: cache is a speed optimization, not a correctness mechanism. Artifacts are for
inter-job data. Cache may evict at any time -- pipelines must work without it.

### Secret management

| Platform | Mechanism | Scope control |
|----------|-----------|---------------|
| **GitHub** | Repository/org/environment secrets | Per-environment, per-repo, per-org. Deployment branches. |
| **GitLab** | CI/CD variables (project/group/instance) | Protected branches/tags, environments, masked in logs. |
| **Forgejo** | Repository/org secrets | Per-repo, per-org. No environment scoping yet. |

**All platforms**: never echo secrets, never pass as CLI args (visible in `ps`), never write
to artifacts. Use environment variables or file-based injection.

### Deployment gates

| Environment | Trigger | Approval |
|-------------|---------|----------|
| **Dev/Preview** | Every PR/MR push | None |
| **Staging** | Merge to main | None (auto-deploy) |
| **Production** | Tag or manual dispatch | Required reviewer(s) |

GitLab: `when: manual` + `environment:`. GitHub: `environment:` with protection rules.
Forgejo: manual dispatch (`workflow_dispatch`).

---

## Monorepo Patterns

When a repo contains multiple services sharing a common library:

### Path-based triggering
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

---

## Forgejo CI/CD

Forgejo Actions is "designed to be familiar, not designed to be compatible" with GitHub Actions.
It reuses the workflow syntax but makes no compatibility guarantees.

### Key differences from GitHub Actions

| Feature | GitHub Actions | Forgejo Actions |
|---------|---------------|-----------------|
| **`permissions:`** | Controls GITHUB_TOKEN scope | **Not enforced** -- token always has full rw (read-only for fork PRs) |
| **`continue-on-error:`** (job level) | Allows job failure without failing workflow | **Not supported** -- step-level only |
| **Runner images** | Managed `ubuntu-24.04` with 200+ tools | Self-hosted, typically lean Debian/Alpine |
| **Action resolution** | `actions/checkout@v4` -> github.com | Resolves from Forgejo mirror (configurable) |
| **OIDC** | `permissions: id-token: write` | `enable-openid-connect` key |
| **Workflow call defaults** | `inputs.<id>.default` populated | **Always empty** |
| **Matrix + dynamic runs-on** | Supported | Supported since v14.0 |
| **LXC execution** | Not supported | Supported (Forgejo-specific) |

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

### Forgejo-specific gotchas

- **No `ubuntu-latest`** -- `runs-on` maps to your registered runner labels (e.g., `docker`)
- **Missing tools** -- Forgejo runner containers are lean. Add `apt-get install` for git, curl, etc.
- **TLS certs** -- if Forgejo uses self-signed or internal CA certs, configure the runner's trust
  store (`GIT_SSL_CAINFO=/path/to/ca-bundle.crt`) or install the CA into the container image.
  `GIT_SSL_NO_VERIFY=true` is a last resort for dev/test only -- never normalize TLS bypass in production
- **Third-party actions** -- many GitHub Marketplace actions use GitHub-specific API calls and will silently fail
- **Secrets in Forgejo** -- `${{ secrets.* }}` works, but no environment-level scoping
- **`permissions:` not enforced** -- Forgejo parses the field but does not restrict the workflow token.
  The token always has full read-write access (read-only for fork PRs only). Don't assume
  least-privilege from `permissions:` alone -- it has no effect on Forgejo.

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
    env:
      # Prefer GIT_SSL_CAINFO with your CA cert; this bypass is a last resort
      GIT_SSL_NO_VERIFY: "true"               # if cert is periodically expired
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

## PCI-DSS 4.0: CI/CD Compliance Mapping

All future-dated requirements became **mandatory March 31, 2025**.

| PCI-DSS Req | What it means for CI/CD | Implementation |
|-------------|-------------------------|----------------|
| **6.2.1** | Secure development training + OWASP-aware processes | SAST on every PR/MR, dependency scanning, secret detection |
| **6.2.4** | Access control + change tracking | Branch protection, required reviewers, signed commits, audit logs |
| **6.3.2** | Software inventory (SBOM) | Generate SPDX/CycloneDX SBOM per release, attach to artifacts |
| **6.4.2** | Changes approved, documented, tested | Gated deployments, required approvals for prod, IaC audit trails |
| **6.5.3** | Consistent security controls across environments | Same scanning in dev/staging/prod, not just prod |

**Customized Approach** (v4.0.1): automated CI/CD controls can satisfy manual review requirements
if properly documented. An automated SAST/DAST/SCA gate with evidence = equivalent to manual
code review for QSA assessment.

Read `references/supply-chain.md` for detailed PCI-DSS compliance patterns.

---

## AI-Age Considerations

AI tools consistently generate insecure CI/CD configs: unpinned actions, missing `permissions:`
blocks, `allow_failure: true` without justification, `:latest` tags, secrets in `run:` blocks.
**Always run the AI Self-Check against AI-generated pipeline code.**

For detailed coverage of slopsquatting, AI agents in CI/CD, prompt injection in pipelines, and
the OWASP Top 10 for Agentic Applications, read `references/supply-chain.md`
(AI-Age Supply Chain Risks section).

---

## Template Conventions

- **`@<sha>`** in GitHub Actions templates is a placeholder. Replace with the real 40-character
  commit SHA for the indicated version. Look up SHAs on the action's releases page or use
  Dependabot to manage them automatically.
- **Image tags** in templates use floating minor versions (e.g., `oven/bun:1.2`, `docker:27.5`)
  for readability. For production, pin to a specific patch version or SHA256 digest. The templates
  show the minimum acceptable granularity, not the ideal.

---

## Reference Files

- `references/github-actions.md` -- GitHub Actions patterns, templates, and security hardening
- `references/gitlab-ci.md` -- GitLab CI/CD 18.x patterns, Catalog, Components, security
- `references/supply-chain.md` -- supply chain security, incident timeline, SHA pinning,
  SBOM/SLSA, PCI-DSS compliance, image signing

## Related Skills

- **code-review** -- has `references/cicd-pipelines.md` for CI/CD **bug patterns** (expression
  injection, variable scoping, cache gotchas, ArgoCD sync issues)
- **security-audit** -- for auditing application code, not pipeline code
- **docker** -- for Dockerfile and container image optimization
- **kubernetes** -- for K8s manifests and Helm charts that pipelines deploy to
- **git** -- for git operations (commits, PRs/MRs, tags, releases) that trigger pipelines.
  CI/CD reacts to git events; git handles the operations that produce them.

## Rules

- **Platform-first.** Always confirm which CI/CD platform before writing config. GitHub Actions
  syntax that "mostly works" in Forgejo will silently break on edge cases.
- **SHA-pin everything.** All third-party actions, all CI tool images. Tags are mutable. SHAs are not.
  The tj-actions, reviewdog, and Trivy compromises proved this is non-negotiable.
- **Secrets are sacred.** Never log, echo, artifact, or pass as CLI arguments. Never use
  protected variables on unprotected branches.
- **Test the pipeline itself.** `act` (GitHub Actions local runner), `gitlab-ci-local`, or dry-run
  modes. Don't discover pipeline bugs in production.
- **Cache != artifact.** Cache is ephemeral speed optimization. Artifacts are guaranteed inter-job
  data. Confusing them causes intermittent failures.
- **Manual gates for prod.** No exceptions. Auto-deploy to staging is fine. Auto-deploy to
  production is how incidents happen.
- **Scan early, deploy late.** Security scanning in the first stages, deployment in the last.
  Finding a CVE after deployment is expensive.
- **PCI-DSS 4.0 is mandatory.** If the pipeline touches CDE (cardholder data environment),
  SBOM generation, signed artifacts, and gated deployments are not optional.
