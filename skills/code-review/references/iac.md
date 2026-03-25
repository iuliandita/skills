# Infrastructure as Code Bug Patterns

Bug patterns specific to Terraform, Ansible, Helm, and Kubernetes manifests. Focused on correctness -- not style (see anti-slop) or security (see security-audit).

---

## Terraform

### Dependency Bugs

**Detect:**
- Missing `depends_on` when there's an implicit ordering requirement that Terraform can't infer (e.g., IAM policy must exist before the resource that uses it, but they're linked by ARN string, not reference)
- Wrong `depends_on` creating unnecessary serial execution
- `data` sources that depend on resources created in the same apply -- data sources are read during plan, so the resource doesn't exist yet
- `count` or `for_each` depending on a value that isn't known until apply (e.g., output of another resource)

**Example:**
```hcl
# bug: data source reads DNS record during plan, but the record is created
# as a side effect of the resource and doesn't exist yet
resource "aws_lb" "main" {
  name = "my-lb"
}

data "dns_a_record_set" "lb" {
  host = aws_lb.main.dns_name  # DNS may not have propagated yet
}

# also a bug: count/for_each depending on a value unknown at plan time
resource "aws_instance" "worker" {
  count = data.external.cluster_size.result.count  # unknown at plan
}
```

### Lifecycle Bugs

**Detect:**
- `create_before_destroy` on resources that have unique constraints (names, ports, IPs) -- the new resource can't be created while the old one exists
- Missing `create_before_destroy` on resources behind a load balancer (causes downtime)
- `prevent_destroy` on resources that need to be replaced during upgrades
- `ignore_changes` hiding drift that should be corrected (legitimate use: external automation managing a field)

### State & Drift

**Detect:**
- Resources managed by Terraform but also modified manually (state drift)
- `terraform import` without updating the HCL (state says it exists, but HCL doesn't describe it)
- Resources removed from HCL without `terraform state rm` (Terraform will try to destroy them)
- Multiple workspaces or state files managing the same resource (collision)

### Conditional Resource Bugs

**Detect:**
- `count = var.enabled ? 1 : 0` on a resource with dependents that don't check `length(resource.name)` -- dependents crash when count is 0
- `for_each` on a set that can be empty -- all downstream references break
- Splat expressions `resource.name[*].id` vs `resource.name.*.id` behavior differences

### Provider & Module Versioning

**Detect:**
- Unpinned provider versions (`version = ">= 3.0"` instead of `version = "~> 5.30"`)
- Module sources without version pinning (git refs, registry versions)
- Provider version constraints that are too loose (major version bumps can break)

---

## Ansible

### Handler Bugs

Handlers only run when notified, and only once, at the end of the play (or when flushed).

**Detect:**
- Handler never notified (typo in handler name, or the notifying task is skipped by `when`)
- Handler expected to run mid-play but only runs at end (use `meta: flush_handlers` if ordering matters)
- Handler notified multiple times but only runs once (by design, but surprising if you expect per-notification execution)
- Handler in a role that's never included

**Example:**
```yaml
# bug: handler name doesn't match
tasks:
  - name: Update config
    template: src=app.conf.j2 dest=/etc/app.conf
    notify: restart app  # typo: handler is named "Restart app"

handlers:
  - name: Restart app
    service: name=app state=restarted
```

### Variable Precedence Surprises

Ansible has 22+ levels of variable precedence. Common traps:

**Detect:**
- `set_fact` overriding role defaults unexpectedly (set_fact has very high precedence)
- `vars` in a play overridden by `-e` / `--extra-vars` (extra vars win everything)
- Role defaults (`defaults/main.yml`) expected to override inventory vars (they don't -- role defaults are the lowest precedence)
- `group_vars` and `host_vars` precedence when a host is in multiple groups

### Idempotency Violations

The whole point of Ansible is idempotency. Tasks that aren't idempotent break on re-runs.

**Detect:**
- `command` / `shell` tasks without `creates` / `removes` guards or `changed_when`
- `lineinfile` with a regex that matches multiple lines (modifies the wrong line on re-run)
- `blockinfile` without a unique marker (multiple runs insert duplicate blocks)
- Tasks that append to files without checking if content already exists
- `git` module with `version: HEAD` (always reports changed)

### `when` Condition Bugs

**Detect:**
- `when: var` where `var` is undefined (error) vs `when: var is defined and var` (safe)
- `when: result.rc == 0` without `ignore_errors: true` on the registered task (task fails before `when` is evaluated)
- Bare variable in `when`: `when: my_var` -- if `my_var` is the string `"false"`, Jinja2 treats it as truthy (it's a non-empty string). Use `when: my_var | bool`
- `when` conditions that reference `item` outside a loop context

### Delegation & Connection Bugs

**Detect:**
- `delegate_to: localhost` but the task needs remote-host facts (facts are from the delegated host)
- `local_action` without considering that it runs as the Ansible user, not the remote user
- `become: true` with `delegate_to` -- become applies on the delegated host, not the original
- Connection plugins not matching the target (e.g., `ssh` for a network device that needs `network_cli`)

---

## Helm

### Template Rendering Bugs

Helm templates are Go templates. Errors only surface at deploy time if `helm template` isn't used.

**Detect:**
- Missing `required` on values that must be provided (chart installs with empty/nil values, k8s objects are malformed)
- `{{ .Values.foo.bar }}` without `{{ if .Values.foo }}` guard (nil pointer if `foo` is not set)
- Wrong indentation with `nindent` / `indent` (YAML is whitespace-sensitive, and template indentation doesn't match the output indentation)
- `toYaml` output not indented properly: `{{ toYaml .Values.resources | nindent 12 }}` -- wrong nindent value breaks the manifest
- Accessing `.Release.Namespace` in a helper that's called from a different context

**Example:**
```yaml
# bug: crashes if resources is not set in values
resources:
  {{ toYaml .Values.resources | nindent 2 }}

# fix: guard with default or required
resources:
  {{- toYaml (.Values.resources | default dict) | nindent 2 }}
```

### Value Type Mismatches

**Detect:**
- String expected but number provided (e.g., `port: 8080` vs `port: "8080"` -- YAML parses unquoted numbers as integers)
- Boolean strings: `"true"` vs `true` in YAML (Helm treats them differently)
- `null` vs empty string vs not-set -- all behave differently in Go templates
- Multiline strings in values (need `|` or `>` block scalars, raw strings break)

### Chart Dependency Issues

**Detect:**
- Sub-chart values not scoped correctly (sub-chart values need `subchart-name.key`, not just `key`)
- Dependency version not pinned in `Chart.yaml`
- Condition/tags on dependencies that don't match any values key
- Alias conflicts when using the same chart as a dependency multiple times

---

## Kubernetes Manifests

### Probe Bugs

Misconfigured probes are a top cause of unnecessary pod restarts and deployment failures.

**Detect:**
- Liveness probe with too-short `initialDelaySeconds` (kills pods that are still starting)
- Liveness probe checking the same endpoint as readiness probe (if the app is overloaded, liveness kills it instead of just removing from service)
- Missing readiness probe (traffic sent to pods that aren't ready)
- `tcpSocket` probe on a port that's open before the app is ready (passes too early)
- `exec` probes that are expensive (they run every `periodSeconds` and consume resources)
- `failureThreshold * periodSeconds` too short for the app's recovery time

**Example:**
```yaml
# bug: kills pods during slow startup
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5   # app takes 30s to start
  periodSeconds: 5
  failureThreshold: 3      # killed after 20s total

# fix: give the app time to start
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
startupProbe:              # use startupProbe for slow starters
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 5
  failureThreshold: 30     # 150s to start
```

### Resource Bugs

**Detect:**
- Memory limit equal to request (no burst room, OOMKilled on any spike)
- CPU limit set too low (causes throttling, which looks like slowness not errors -- hard to debug)
- No resource requests (scheduler can't make good decisions, pods get evicted first)
- Ephemeral storage not set (container logs / tmp files can fill the node)
- ResourceQuota in namespace but pod doesn't set requests/limits (pod rejected)

### Deployment & Rollout Bugs

**Detect:**
- `maxUnavailable: 0` AND `maxSurge: 0` (deployment can never make progress)
- Missing `PodDisruptionBudget` for HA workloads (voluntary evictions can take all replicas)
- `revisionHistoryLimit: 0` (can't rollback)
- `terminationGracePeriodSeconds` shorter than the app's shutdown time (SIGKILL before graceful shutdown completes)
- No `preStop` hook for apps that need to drain connections

### Label & Selector Bugs

**Detect:**
- Service selector doesn't match pod labels (service has no endpoints, traffic goes nowhere)
- Deployment selector changed after creation (immutable, causes error)
- NetworkPolicy label selector doesn't match intended pods (policy has no effect)
- Same labels on pods from different deployments (service load-balances across unrelated pods)

### Volume & Storage Bugs

**Detect:**
- PVC with `ReadWriteOnce` but pod scheduled on multiple nodes (can't mount)
- `emptyDir` used for data that needs to persist across pod restarts (data lost)
- `hostPath` in a multi-node cluster (pod can't access the path on a different node)
- Missing `fsGroup` in security context (pod can't write to mounted volume)
- `subPath` with ConfigMap/Secret (doesn't auto-update when the ConfigMap/Secret changes)

---

## ArgoCD / GitOps

### Application Bugs

**Detect:**
- `targetRevision: HEAD` on a production Application (tracks latest commit, no pinning -- any push deploys immediately)
- `syncPolicy.automated.prune: true` on production without understanding the blast radius (deletes resources removed from git)
- `syncPolicy.automated.selfHeal: true` combined with operators that modify resources (infinite reconciliation loop)
- Missing `ignoreDifferences` for fields managed by controllers (e.g., replica count managed by HPA, annotations added by admission webhooks)
- Application `destination.namespace` not matching the namespace in the manifests (resources created in the wrong namespace or rejected)

**Example:**
```yaml
# bug: auto-sync with prune on production -- deleting a file from git
# immediately deletes the resource in prod
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  syncPolicy:
    automated:
      prune: true      # dangerous for prod
      selfHeal: true
  destination:
    namespace: production

# fix: manual sync for prod, or at minimum require prune explicitly
spec:
  syncPolicy:
    automated:
      selfHeal: true    # ok: fixes drift
      prune: false      # requires manual prune
```

### Sync Wave & Hook Bugs

**Detect:**
- Resources without sync wave annotations when ordering matters (e.g., namespace must exist before deployments)
- `argocd.argoproj.io/hook: PreSync` on jobs that depend on resources not yet synced
- `hook-delete-policy: HookSucceeded` on debug/troubleshooting hooks (can't inspect them after success)
- Sync waves that create circular dependencies (wave 1 depends on wave 2)

### Health Check Issues

**Detect:**
- Custom health checks that never report `Healthy` (Application stuck in `Progressing` forever)
- Missing health checks for CRDs (ArgoCD doesn't know how to assess health of custom resources)
- `health.lua` scripts that don't handle all status conditions (e.g., missing `Degraded` state)

### Multi-Cluster / App-of-Apps Bugs

**Detect:**
- App-of-apps where child Applications target the wrong cluster (copy-paste from another environment)
- `ApplicationSet` generators that produce overlapping Applications (same name, different params)
- Missing `finalizers` on Applications (orphaned resources when Application is deleted)
- Cluster secrets with wrong API server URL or expired credentials

---

## Docker / Containerfiles

### Build Bugs

**Detect:**
- `COPY` or `ADD` referencing paths outside the build context (build fails, not caught until CI)
- Multi-stage build `COPY --from=builder` referencing wrong stage name or index
- `RUN` commands that assume specific OS packages are available (works locally with fat base image, fails in CI with slim image)
- Missing `.dockerignore` causing `node_modules`, `.git`, or secrets to be included in context (slow builds, image bloat, potential secret exposure)
- `ARG` used before `FROM` (only available in the first stage, silently empty in subsequent stages)

**Example:**
```dockerfile
# bug: ARG is scoped to the build stage where it's defined
ARG VERSION=latest
FROM node:${VERSION}
# VERSION is available here

FROM node:${VERSION}-slim
# bug: VERSION is empty here! ARG is reset after FROM
# fix: redeclare the ARG after FROM
ARG VERSION=latest
```

### Runtime Bugs

**Detect:**
- `ENTRYPOINT` as a string (shell form) instead of array (exec form) -- PID 1 is shell, signals not forwarded, `docker stop` waits 10s then SIGKILLs
- `CMD` providing defaults that conflict with `ENTRYPOINT` (common when both are set)
- Missing `EXPOSE` (documentation issue, but some orchestrators rely on it)
- `USER root` without switching back to non-root (container runs as root in production)
- Volume mounts that shadow files baked into the image (confusing behavior, files "disappear")

**Fix:** Use exec form for `ENTRYPOINT`: `ENTRYPOINT ["node", "server.js"]` not `ENTRYPOINT node server.js`. This ensures the process receives signals directly.
