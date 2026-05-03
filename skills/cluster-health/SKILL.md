---
name: cluster-health
description: >
  · Check Kubernetes cluster health with read-only diagnostics. Triggers: 'cluster health',
  'health check', 'cluster status', 'diagnostics', 'post-maintenance check', 'node status'.
  Not for manifests or IaC (use kubernetes).
license: MIT
compatibility: "Requires kubectl. Optional: helm, jq, openssl, dig, ssh"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-30"
  effort: high
  argument_hint: "[context-or-alias] [timewindow]"
---

# Cluster Health

Run read-only Kubernetes health checks and report cluster status with evidence. This skill works
without private overlays by requiring an explicit kube context or confirmed current context.
Local users may add ignored protected overlays for aliases and environment-specific checks.

## When to use

- User asks to check cluster health, status, diagnostics, node status, or post-maintenance state
- Verifying cluster-wide symptoms after upgrades, reboots, Helm changes, GitOps syncs, or incidents
- Gathering read-only evidence across nodes, workloads, events, ingress, storage, logs, and policy
- Producing a short traffic-light report from Kubernetes and related observability signals

## When NOT to use

- Writing or reviewing Kubernetes manifests - use **kubernetes**
- Writing Helm charts, Kustomize overlays, or IaC - use **kubernetes** or **terraform**
- Changing resources, restarting pods, deleting objects, or applying fixes - ask for explicit escalation
- Debugging one application deeply after the broad sweep identifies it - use the relevant domain skill

---

## AI Self-Check

Before running checks or reporting results, verify:

- [ ] Target context is explicit or the current context was confirmed
- [ ] Every `kubectl` command includes `--context <context>`
- [ ] Every `helm` command includes `--kube-context <context>`
- [ ] Commands are read-only: no apply, patch, delete, edit, rollout restart, scale, cordon, drain, or exec unless the user explicitly escalates
- [ ] Output is capped with `head`, `tail`, `--since`, `--field-selector`, or selectors
- [ ] Time window is bounded and stated in the report
- [ ] Protected registry contents are not printed unless the user asks for those exact details
- [ ] Findings include evidence, impact, and next action

---
- [ ] **Current source checked**: dated versions, CLI flags, API names, and support windows are verified against primary docs before repeating them
- [ ] **Hidden state identified**: local config, credentials, caches, contexts, branches, cluster targets, or previous runs are made explicit before acting
- [ ] **Verification is real**: final checks exercise the actual runtime, parser, service, or integration point instead of only linting prose or happy paths
- [ ] **Cluster target explicit**: kubeconfig context, namespace, and environment are named before any query
- [ ] **Read-only posture kept**: health checks do not mutate resources or restart workloads unless the user explicitly escalates

## Cluster Registry

This public skill has no built-in private cluster registry.

Users may create local-only overlays under `skills/cluster-health/protected/` for private lab,
homelab, work, or customer cluster details. The directory is gitignored by this collection. If it
exists in the installed skill, read it while using this skill. A user can ask their agent to create
or update these files.

Suggested local layout:

```text
protected/
  registry.md            # aliases, kube contexts, CWD patterns, profile mappings
  private-patterns.txt   # terms that must never appear in public files
  <cluster-or-env>.md    # local namespaces, runbooks, dashboards, thresholds
```

1. If `protected/registry.md` exists, read it first and use its alias, context, CWD pattern, and
   reference mappings.
2. If the registry maps the target to `protected/<cluster-or-env>.md`, read that profile before
   running checks.
3. If no protected registry exists, require an explicit kube context or ask before using the current
   context.
4. Never guess a cluster from a vague request.
5. Never print protected registry contents in public reports unless the user asks for those exact
   details.
6. Treat gitignored as local privacy, not encryption. Do not put protected overlays in shared logs,
   issues, PR comments, or public reports.

## Usage

```
cluster-health [context-or-alias] [timewindow]
```

- `context-or-alias` is a kube context, current-context confirmation, or protected overlay alias.
- `timewindow` defaults to `2h`; use bounded values such as `30m`, `1h`, `2h`, `6h`, or `24h`.

## Workflow

### Step 1: Resolve target

If a protected registry maps the request or current directory to an alias, use that mapping. If no
mapping exists, require an explicit kube context or ask whether to use `kubectl config current-context`.

### Step 2: Confirm read-only scope

State the context and time window before running commands. Do not run mutation commands as part of
this skill.

### Step 3: Run the generic sweep

Start with the cluster-wide checks in `references/kubernetes-core.md`, then load additional
references based on the symptom:

- networking or certificate symptoms -> `references/networking-ingress.md`
- release or reconciliation symptoms -> `references/helm-gitops.md`
- pending pods or volume symptoms -> `references/storage.md`
- noisy errors or alert symptoms -> `references/monitoring-logs.md`
- policy, RBAC, or image-risk symptoms -> `references/security.md`

### Step 4: Classify findings

Use GREEN for healthy signals, YELLOW for degraded or ambiguous state, and RED for user-visible
outage, data-risk, or control-plane risk. Distinguish transient rollout noise from persistent
degradation.

### Step 5: Report

Return a concise report:

```markdown
# Cluster Health Report - <context> (<timewindow>, YYYY-MM-DD HH:MM)

## Summary
- STATUS: GREEN|YELLOW|RED
- Scope: <contexts, namespaces, time window>
- Key findings: <short bullets>

## Evidence
- <area>: <command or source> -> <observed signal>

## Next Actions
- <read-only follow-up or explicit escalation request>
```

## Reference Files

- `references/kubernetes-core.md` - nodes, workloads, events, namespaces, and resource pressure
- `references/helm-gitops.md` - Helm releases, GitOps controllers, and reconciliation state
- `references/networking-ingress.md` - services, ingress, load balancers, DNS, and certificates
- `references/storage.md` - PVs, PVCs, CSI drivers, storage classes, and volume attachment
- `references/monitoring-logs.md` - alerts, metrics availability, log triage, and noisy namespaces
- `references/security.md` - read-only checks for RBAC, secrets exposure signals, image risk, and policy engines

## Output Contract

See `skills/_shared/output-contract.md` for the full contract.

- **Skill name:** CLUSTER-HEALTH
- **Deliverable bucket:** `audits`
- **Mode:** conditional. When invoked to **analyze, review, audit, or improve** existing repo content, emit the full contract -- boxed inline header, body summary inline plus per-finding detail in the deliverable file, boxed conclusion, conclusion table -- and write the deliverable to `docs/local/audits/cluster-health/<YYYY-MM-DD>-<slug>.md`. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; only used in audit/review mode).

## Related Skills

- **kubernetes** - write or review manifests, Helm charts, Kustomize, and GitOps config
- **networking** - debug DNS, routing, proxies, VPNs, and Linux networking
- **security-audit** - review security controls or vulnerability posture beyond read-only cluster signals
- **terraform** - change infrastructure definitions or state

## Rules

1. Read only. Do not mutate cluster state unless the user explicitly changes the task.
2. Use `--context <context>` on every `kubectl` command and `--kube-context <context>` on every `helm` command.
3. Cap output before putting it in context.
4. Never guess a cluster target from a vague request.
5. Keep protected overlay details out of public reports unless the user asks for those exact details.
6. Report failed checks as findings; do not hide missing tools, missing CRDs, or permission errors.
