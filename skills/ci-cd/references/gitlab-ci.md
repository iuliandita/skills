# GitLab CI/CD: Patterns & Templates

Production-ready patterns for GitLab CI/CD pipelines. Updated for GitLab 18.10 (March 2026):
CI/CD Catalog GA, Components with typed inputs, rules-based workflows.

---

## Current State (2026)

- **GitLab 18.10** (released March 19, 2026). Monthly releases on the third Thursday.
- **CI/CD Catalog** GA since GitLab 17.0 (May 2024). Max 100 components per project (raised in 18.5).
- **CI Components** are the endorsed path for reusable pipeline logic. `include:` templates still work
  but components have versioning, typed inputs, and discoverability.
- **`only:/except:` is legacy.** Use `rules:` for all new pipelines. Migration is non-trivial - see
  the bug patterns in the code-review skill's `cicd-pipelines.md`.

---

## gitlab.com (SaaS) vs Self-Managed

The `.gitlab-ci.yml` syntax is identical. Operational behavior is not. Before writing
pipeline config, know which deployment you are targeting.

### Compute minutes / runner quotas

| Mode | Runner model | Quota |
|------|--------------|-------|
| **gitlab.com Free** | Shared SaaS runners (Linux small) | 400 compute min/month, Linux only |
| **gitlab.com Premium** | Shared + larger Linux/macOS/Windows | 10,000 compute min/month |
| **gitlab.com Ultimate** | All of the above | 50,000 compute min/month |
| **Self-managed CE/EE** | Your runners | Effectively unlimited (your hardware) |

**"Compute minutes"** replaced the old "CI minutes" name in 2024. Linux small = 1x multiplier;
Linux medium/large = 2x/3x; macOS = 6x; Windows = 1x. SaaS jobs on paid tiers can burn through
quota fast if you run matrix builds on macOS without realizing the 6x multiplier.

**Self-managed**: quotas can still be imposed per project/group via admin settings, but the
default is unlimited. If the pipeline hangs with "no runner available," check runner tags and
registration - it is never a quota problem on self-managed.

### Runner types and tags

| Runner type | Where it lives | Typical tag |
|-------------|---------------|-------------|
| **SaaS shared (Linux)** | GitLab-managed | `saas-linux-small-amd64`, `saas-linux-medium-amd64`, `saas-linux-large-amd64` |
| **SaaS shared (macOS)** | GitLab-managed | `saas-macos-medium-m1` |
| **SaaS shared (Windows)** | GitLab-managed | `saas-windows-medium-amd64` |
| **Self-managed shared** | Your infra, group/instance scope | Your tags (e.g. `docker`, `k8s`) |
| **Project-specific** | Your infra, single project | Your tags |

On gitlab.com, `tags:` picks the SaaS runner class (and cost multiplier). On self-managed,
`tags:` picks which of your registered runners takes the job. A pipeline written for
gitlab.com with `tags: [saas-linux-medium-amd64]` will sit pending forever on self-managed
unless you register a runner with that exact tag.

### Tier-gated features in `.gitlab-ci.yml`

Self-managed EE without a license behaves like CE. Several features parse without error but
silently no-op on the wrong tier:

| Feature | Tier | Behavior on lower tier |
|---------|------|------------------------|
| **Merge Trains** (`needs:` + merge strategy) | Premium+ | No merge train; normal merge |
| **Secure scanning** (`container_scanning`, `sast`, `dast`, `secret_detection`) | Works on CE, results UI limited to Ultimate | Jobs run; findings not in MR widget on CE/Premium |
| **Compliance pipelines** (`compliance_frameworks`) | Ultimate | Ignored silently |
| **Protected environment approvals (multi-stage)** | Premium+ | Single approval only |
| **CI/CD for external repos** | Premium+ | Unavailable |
| **Pipeline subscriptions** (cross-project triggers) | Premium+ | Ignored silently |

**How to detect at runtime**: `$GITLAB_FEATURES` is a predefined CI variable containing a
comma-separated list of enabled feature flags (e.g. `merge_trains`, `security_dashboard`).
Check this in `rules:` if you maintain one pipeline across SaaS-Ultimate and self-managed CE.

### Predefined variables that differ

| Variable | gitlab.com | Self-managed |
|----------|------------|--------------|
| `CI_SERVER_HOST` | `gitlab.com` | Your hostname (e.g. `gitlab.example.com`) |
| `CI_SERVER_URL` | `https://gitlab.com` | Your URL |
| `CI_SERVER_FQDN` | `gitlab.com` | Your FQDN |
| `CI_API_V4_URL` | `https://gitlab.com/api/v4` | `https://<host>/api/v4` |
| `GITLAB_FEATURES` | Full list per tier | CE-limited list or EE features from license |
| `CI_PROJECT_URL` | `https://gitlab.com/group/project` | `https://<host>/group/project` |

Never hardcode `gitlab.com` in a pipeline. Use `$CI_SERVER_HOST` and `$CI_API_V4_URL` so the
same config works on either deployment. Hardcoded hostnames are a common migration blocker
when moving a project from SaaS to self-managed or vice versa.

### Auth to the GitLab API from jobs

- **gitlab.com**: `CI_JOB_TOKEN` has scoped access to the project; `GITLAB_TOKEN` (user
  PAT) still works but is rate-limited per user.
- **Self-managed**: same primitives, plus admins can configure higher rate limits, disable
  the instance-level `CI_JOB_TOKEN` scope expansion, or issue longer-lived PATs.
- **OIDC to cloud providers**: works identically via `id_tokens:` - the JWT's `iss` claim
  is `CI_SERVER_URL`, which means self-managed needs its own trust configuration in AWS/GCP
  (can't share the `https://gitlab.com` trust policy).

### Operational differences that bite

- **Upgrade cadence**: gitlab.com is always current; self-managed can lag months. Feature
  documentation assumes the latest version. Check `/help` on the self-managed instance for
  actual version before assuming a feature exists.
- **Runner image pre-warming**: SaaS runners have common images cached. Self-managed
  runners pull cold unless you warm the image cache or run a pull-through registry.
- **Artifact storage limits**: gitlab.com caps job artifacts (size and retention per tier);
  self-managed limits are whatever the admin configured (often higher).
- **Outbound network**: SaaS jobs have unrestricted egress; self-managed often runs behind
  a corporate proxy. Configure runner `http_proxy`/`https_proxy` env vars at the runner
  level, not in every job.

---

## Pipeline Structure

### Recommended stage order

```yaml
stages:
  - lint
  - test
  - build
  - scan
  - deploy
```

Lint first (fastest feedback), scan after build (scans build output), deploy last.

### Workflow rules (prevent duplicate pipelines)

**Always define `workflow:rules`** when jobs use `rules:`. Without it, pushing to a branch with
an open MR triggers both a push pipeline AND a merge request pipeline, running every job twice.

```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never    # suppress push pipeline when MR is open
    - if: $CI_COMMIT_BRANCH
    - if: $CI_COMMIT_TAG
```

### Minimal CI pipeline

```yaml
stages:
  - lint
  - test
  - build

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

variables:
  BUN_INSTALL: "$CI_PROJECT_DIR/.bun"

.bun-setup: &bun-setup
  image: oven/bun:1.2
  before_script:
    - bun install --frozen-lockfile
  cache:
    key:
      files:
        - bun.lockb
    paths:
      - node_modules/
    policy: pull-push

lint:
  <<: *bun-setup
  stage: lint
  script:
    - bun run lint

typecheck:
  <<: *bun-setup
  stage: lint
  script:
    - bun run typecheck

test:
  <<: *bun-setup
  stage: test
  script:
    - bun run test
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

build:
  <<: *bun-setup
  stage: build
  script:
    - bun run build
  artifacts:
    paths:
      - dist/
    expire_in: 7 days
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Docker build and push

```yaml
build-image:
  stage: build
  image: docker:29.3
  services:
    - docker:29.3-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - |
      docker build \
        --tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA \
        --tag $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG \
        --label "org.opencontainers.image.revision=$CI_COMMIT_SHA" \
        --label "org.opencontainers.image.source=$CI_PROJECT_URL" \
        .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
```

---

## CI/CD Components (Catalog)

Components are versioned, typed, and discoverable. They replace the old `include:` pattern.

### Using a component

```yaml
include:
  - component: gitlab.example.com/my-org/ci-components/sast@1.0.0
    inputs:
      severity: HIGH,CRITICAL
      fail-on-findings: true
```

### Creating a component

```yaml
# templates/sast.yml
spec:
  inputs:
    severity:
      type: string
      default: "HIGH,CRITICAL"
    fail-on-findings:
      type: boolean
      default: false

---
sast-scan:
  stage: test
  image: semgrep/semgrep:1.124
  script:
    - semgrep scan --config auto --severity $[[ inputs.severity ]]
  allow_failure: $[[ !inputs.fail-on-findings ]]
```

**Key differences from `include:` templates**:
- Typed inputs with validation (string, boolean, number, array)
- Default values
- Version pinning (semver tags on the component repo)
- Discoverable via GitLab's CI/CD Catalog UI
- Max 100 components per project

### When to use components vs includes

| Pattern | Use case |
|---------|----------|
| **Components** | Reusable across projects, needs versioning, has inputs |
| **`include: local`** | Project-specific templates in the same repo |
| **`include: remote`** | Ad hoc sharing, no versioning needed |

---

## Rules (replacing only/except)

### Common patterns

```yaml
# Run on MR events and default branch pushes
rules:
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Run on tags only
rules:
  - if: $CI_COMMIT_TAG

# Manual deployment to production
rules:
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    when: manual
    allow_failure: false    # blocks pipeline until manual approval

# Skip for draft MRs
rules:
  - if: $CI_MERGE_REQUEST_TITLE =~ /^Draft:/
    when: never
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"

# Changes-based (only run when specific files change)
rules:
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    changes:
      - src/**/*
      - package.json
      - bun.lockb
```

### Critical rule: `when: never` as final catch-all

Without a final `when: never`, unmatched conditions fall through and the job runs anyway.
This is the opposite of `only/except` behavior.

```yaml
# DANGEROUS: job runs on every pipeline
rules:
  - if: $CI_COMMIT_TAG
    when: manual

# CORRECT: job only runs on tags, skipped otherwise
rules:
  - if: $CI_COMMIT_TAG
    when: manual
  - when: never
```

---

## Caching Strategies

```yaml
# Lockfile-based cache key (recommended)
cache:
  key:
    files:
      - bun.lockb
  paths:
    - node_modules/
  policy: pull-push    # default: download cache, update after job

# Branch-scoped cache (fallback to default branch)
cache:
  key: $CI_COMMIT_REF_SLUG
  paths:
    - .cache/
  fallback_keys:
    - $CI_DEFAULT_BRANCH
```

**Cache vs artifacts**:
- **Cache**: speed optimization, may not be available, uses `pull-push`/`pull`/`push` policies
- **Artifacts**: guaranteed inter-job data, has `expire_in`, can generate reports

Never treat cache as guaranteed. Pipelines must work on a cold cache.

### Cache key prefix (shared runners)

When multiple projects share runners, cache keys collide. Prefix with project name:

```yaml
cache:
  key:
    prefix: $CI_PROJECT_NAME
    files:
      - bun.lockb
  paths:
    - node_modules/
```

---

## Needs (DAG Pipelines)

`needs:` enables out-of-order job execution by declaring explicit dependencies.

```yaml
stages:
  - build
  - test
  - deploy

build-frontend:
  stage: build
  script: bun run build:frontend
  artifacts:
    paths: [dist/frontend/]

build-backend:
  stage: build
  script: bun run build:backend
  artifacts:
    paths: [dist/backend/]

test-frontend:
  stage: test
  needs: [build-frontend]
  script: bun run test:frontend

test-backend:
  stage: test
  needs: [build-backend]
  script: bun run test:backend

deploy:
  stage: deploy
  needs: [test-frontend, test-backend]
  script: deploy.sh
```

**Gotchas**:
- `needs: []` (empty) = "run immediately, no dependencies." Not "don't run."
- `needs` referencing a job excluded by `rules:` = pipeline fails with "job not found"
- `needs` chains that run through deployment can cause modules to deploy at different versions

---

## Multi-Environment Deployment

```yaml
.deploy-template:
  stage: deploy
  image: alpine/k8s:1.32.3
  before_script:
    - kubectl config use-context $KUBE_CONTEXT

deploy-staging:
  extends: .deploy-template
  variables:
    KUBE_CONTEXT: staging
  script:
    - kubectl apply -f k8s/ -n staging
    - kubectl rollout status deployment/app -n staging --timeout=300s
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  extends: .deploy-template
  variables:
    KUBE_CONTEXT: production
  script:
    - kubectl apply -f k8s/ -n production
    - kubectl rollout status deployment/app -n production --timeout=300s
  environment:
    name: production
    url: https://app.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
      allow_failure: false
```

---

## Security Scanning

### Built-in templates

```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml
```

### Custom Trivy scan (pinned to safe version)

```yaml
trivy-scan:
  stage: scan
  image:
    name: aquasec/trivy:0.69.3    # known safe - do NOT use 0.69.4/5/6
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  allow_failure: true    # non-blocking for dev/staging; set to false for release pipelines (PCI 6.2.1)
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### SBOM generation

```yaml
generate-sbom:
  stage: scan
  image: anchore/syft:1.42
  script:
    - syft $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -o spdx-json=sbom.spdx.json
  artifacts:
    paths:
      - sbom.spdx.json
    expire_in: 90 days
  rules:
    - if: $CI_COMMIT_TAG
```

---

## Variables and Secrets

### Scoping

| Variable type | Scope | Protected | Masked |
|---------------|-------|-----------|--------|
| Project CI/CD variable | All branches/tags | Optional | Optional |
| Protected variable | Protected branches/tags only | Yes | Usually |
| Environment variable | Specific environment only | By environment | Optional |
| Group variable | All projects in group | Optional | Optional |

**Warning**: protected variables on non-protected branches are silently empty. The job runs
but with an empty string, causing partial/broken deployments with no error.

### Variable precedence (highest to lowest)

1. Pipeline trigger variables / extra variables
2. Project-level CI/CD variables
3. Group-level CI/CD variables (nearest ancestor first)
4. Instance-level CI/CD variables
5. `.gitlab-ci.yml` `variables:` block

A group variable is silently overridden by a project variable with the same name. No warning.

### Process substitution for secrets

Never write secrets to disk in CI. Use process substitution:

```yaml
deploy:
  script:
    - ansible-playbook deploy.yml --vault-password-file <(echo "$VAULT_PASSWORD")
```

---

## Terraform Pipeline

```yaml
stages:
  - validate
  - plan
  - apply

variables:
  TF_ROOT: ${CI_PROJECT_DIR}/terraform

.tf-template:
  image: hashicorp/terraform:1.14
  before_script:
    - cd $TF_ROOT
    - terraform init

tf-validate:
  extends: .tf-template
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check

tf-plan:
  extends: .tf-template
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - $TF_ROOT/tfplan
    expire_in: 1 day
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

tf-apply:
  extends: .tf-template
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - tf-plan
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
      allow_failure: false
```

---

## glab CLI Integration

The `glab` CLI can interact with self-hosted GitLab instances. If the SSH remote resolves
to an IP different from the web URL, `glab mr list` may fail. Use the API with URL-encoded paths:

```bash
glab api "projects/group%2Fsubgroup%2Fproject/merge_requests" --hostname gitlab.example.com
```

---

## Common Gotchas

- **`rules:` and `only:/except:` in the same job**: silently rejected. One or the other per job.
- **Missing `workflow:rules`**: push to MR branch triggers both push AND MR pipelines.
- **Default artifact expiry is 30 days**: artifacts from old pipelines silently disappear.
- **Runner tags**: job with `tags: [specific-runner]` where runner is offline sits pending forever.
- **`dotenv` variables in `rules:`**: rules evaluate before jobs run, so dotenv vars don't exist.
- **`after_script` isolation**: runs in a separate shell. Variables from `script` are not available.
- **Cache as guarantee**: cache may not be available. Always handle cold cache gracefully.
- **`keep latest artifacts` + intermediate pipelines**: only the latest pipeline's artifacts survive.

---

## Monorepo Pipeline (Three Services + Shared Lib)

Complete `.gitlab-ci.yml` for a monorepo with `services/api`, `services/web`, `services/worker`,
and a shared library `libs/common`. Each service builds only when its own code or the shared lib
changes. All three services share a common lint/test stage pattern.

```yaml
stages:
  - lint
  - test
  - build
  - scan
  - deploy

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH
    - if: $CI_COMMIT_TAG

variables:
  DOCKER_TLS_CERTDIR: "/certs"

# --- Shared templates ---

.changes-api: &changes-api
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        paths: [services/api/**, libs/common/**]
        compare_to: refs/heads/main
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths: [services/api/**, libs/common/**]

.changes-web: &changes-web
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        paths: [services/web/**, libs/common/**]
        compare_to: refs/heads/main
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths: [services/web/**, libs/common/**]

.changes-worker: &changes-worker
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        paths: [services/worker/**, libs/common/**]
        compare_to: refs/heads/main
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths: [services/worker/**, libs/common/**]

.node-setup: &node-setup
  image: node:22-slim
  before_script:
    - cd $SERVICE_DIR
    - npm ci
  cache:
    key:
      prefix: $CI_PROJECT_NAME-$SERVICE_NAME
      files:
        - $SERVICE_DIR/package-lock.json
    paths:
      - $SERVICE_DIR/node_modules/
    policy: pull-push

.docker-build:
  stage: build
  image: docker:29.3
  services:
    - docker:29.3-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - |
      docker build \
        --tag $CI_REGISTRY_IMAGE/$SERVICE_NAME:$CI_COMMIT_SHA \
        --tag $CI_REGISTRY_IMAGE/$SERVICE_NAME:$CI_COMMIT_REF_SLUG \
        --label "org.opencontainers.image.revision=$CI_COMMIT_SHA" \
        -f $SERVICE_DIR/Dockerfile \
        .
    - docker push $CI_REGISTRY_IMAGE/$SERVICE_NAME:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE/$SERVICE_NAME:$CI_COMMIT_REF_SLUG

# --- Shared lib (lint + test only, no container) ---

lint-common:
  <<: *node-setup
  stage: lint
  variables:
    SERVICE_DIR: libs/common
    SERVICE_NAME: common
  script:
    - npm run lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        paths: [libs/common/**]
        compare_to: refs/heads/main
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths: [libs/common/**]

test-common:
  <<: *node-setup
  stage: test
  variables:
    SERVICE_DIR: libs/common
    SERVICE_NAME: common
  script:
    - npm run test
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        paths: [libs/common/**]
        compare_to: refs/heads/main
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths: [libs/common/**]

# --- API service ---

lint-api:
  <<: [*node-setup, *changes-api]
  stage: lint
  variables:
    SERVICE_DIR: services/api
    SERVICE_NAME: api
  script:
    - npm run lint

test-api:
  <<: [*node-setup, *changes-api]
  stage: test
  variables:
    SERVICE_DIR: services/api
    SERVICE_NAME: api
  script:
    - npm run test

build-api:
  extends: .docker-build
  <<: *changes-api
  variables:
    SERVICE_DIR: services/api
    SERVICE_NAME: api

# --- Web service ---

lint-web:
  <<: [*node-setup, *changes-web]
  stage: lint
  variables:
    SERVICE_DIR: services/web
    SERVICE_NAME: web
  script:
    - npm run lint

test-web:
  <<: [*node-setup, *changes-web]
  stage: test
  variables:
    SERVICE_DIR: services/web
    SERVICE_NAME: web
  script:
    - npm run test

build-web:
  extends: .docker-build
  <<: *changes-web
  variables:
    SERVICE_DIR: services/web
    SERVICE_NAME: web

# --- Worker service ---

lint-worker:
  <<: [*node-setup, *changes-worker]
  stage: lint
  variables:
    SERVICE_DIR: services/worker
    SERVICE_NAME: worker
  script:
    - npm run lint

test-worker:
  <<: [*node-setup, *changes-worker]
  stage: test
  variables:
    SERVICE_DIR: services/worker
    SERVICE_NAME: worker
  script:
    - npm run test

build-worker:
  extends: .docker-build
  <<: *changes-worker
  variables:
    SERVICE_DIR: services/worker
    SERVICE_NAME: worker

# --- Security scan (all images) ---

scan:
  stage: scan
  image:
    name: aquasec/trivy:0.69.3
  script:
    - |
      for svc in api web worker; do
        echo "--- Scanning $svc ---"
        trivy image --exit-code 1 --severity HIGH,CRITICAL \
          $CI_REGISTRY_IMAGE/$svc:$CI_COMMIT_SHA || SCAN_FAILED=1
      done
      [ -z "$SCAN_FAILED" ] || exit 1
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# --- Deployment ---

deploy-staging:
  stage: deploy
  image: alpine/k8s:1.32.3
  script:
    - |
      for svc in api web worker; do
        kubectl set image deployment/$svc \
          $svc=$CI_REGISTRY_IMAGE/$svc:$CI_COMMIT_SHA \
          -n staging
      done
    - |
      for svc in api web worker; do
        kubectl rollout status deployment/$svc -n staging --timeout=300s
      done
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  image: alpine/k8s:1.32.3
  script:
    - |
      for svc in api web worker; do
        kubectl set image deployment/$svc \
          $svc=$CI_REGISTRY_IMAGE/$svc:$CI_COMMIT_SHA \
          -n production
      done
    - |
      for svc in api web worker; do
        kubectl rollout status deployment/$svc -n production --timeout=300s
      done
  environment:
    name: production
    url: https://app.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
      allow_failure: false
```

**Key patterns**:
- **YAML anchors** (`.changes-api`, `.changes-web`, `.changes-worker`) centralize per-service `rules:` + `changes:` filters. Each service's lint, test, and build jobs inherit the same trigger rules.
- **`compare_to: refs/heads/main`** ensures `changes:` compares against main, not the previous commit (which misses multi-commit MRs).
- **Shared lib (`libs/common/**`)** is included in every service's change filter. If only the shared lib changes, all dependent services rebuild.
- **Cache key prefix** uses `$SERVICE_NAME` to avoid cache collisions between services on shared runners.
- **Single scan job** iterates all service images. In larger setups, split into per-service scan jobs for parallelism.

---

## PCI-DSS 4.0 Compliance (GitLab)

| Requirement | GitLab implementation |
|-------------|----------------------|
| **6.2.1** SAST/SCA | Include Security templates, require pipeline success on protected branches |
| **6.2.4** Change control | Protected branches, required MR approvals (min 2 for CDE repos), audit events |
| **6.3.2** SBOM | `generate-sbom` job on every release tag, stored as artifact |
| **6.4.2** Gated deploys | `when: manual` + `allow_failure: false` on production deploy jobs |
| **6.5.3** Consistent controls | Same security templates included in all environments' pipelines |

**Protected branches**: at minimum, `main` should require MR approval and passing pipeline.
For CDE repos, require 2+ approvals and include SAST results in MR widget.
