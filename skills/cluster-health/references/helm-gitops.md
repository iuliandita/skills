# Helm and GitOps

## Purpose

Check release state, failed upgrades, and GitOps reconciliation without changing resources.

## Commands

```bash
helm --kube-context <context> list -A --all --max 100
helm --kube-context <context> history <release> -n <namespace> --max 10
kubectl --context <context> get applications.argoproj.io -A 2>&1 | head -n 80
kubectl --context <context> get kustomizations.toolkit.fluxcd.io -A 2>&1 | head -n 80
kubectl --context <context> get helmreleases.helm.toolkit.fluxcd.io -A 2>&1 | head -n 80
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 80
```

Keep `2>&1` on the CRD queries so a real error is visible. Distinguish two outcomes that
`2>/dev/null` would flatten into the same empty result:

- `error: the server doesn't have a resource type "applications.argoproj.io"` -> the controller is
  not installed. The cluster does not use that GitOps engine. Not a finding.
- `Error from server (Forbidden)` -> the controller may be installed but this context lacks RBAC to
  read it. That is a coverage gap to report, not "no apps."

## Reconciliation state interpretation

GitOps status fields are not boolean. Read both sync and health where the controller exposes them.

- **Argo CD**: `SYNC STATUS` (`Synced`/`OutOfSync`) is desired-vs-live drift; `HEALTH STATUS`
  (`Healthy`/`Progressing`/`Degraded`/`Missing`) is whether the live resources are working.
  `Synced` + `Degraded` means the manifests match git but the workload is broken - that is a real
  problem, not a green light. `OutOfSync` alone may be an intentional manual change or a pending
  auto-sync, not necessarily failure.
- **Flux**: a Kustomization/HelmRelease `Ready=False` carries a reason and message in the status
  conditions; read the message. A `Suspended` resource is intentionally paused, not failed - it
  simply stopped reconciling, and "not reconciling" is expected there.
- **Helm**: `STATUS` of `deployed` is current; `failed`, `pending-install`, `pending-upgrade`, or
  `pending-rollback` indicate an interrupted operation. An old `failed` revision in `history` that
  is followed by a later `deployed` revision is not a current problem.

## Schedule-aware staleness

GitOps controllers reconcile on an interval (Flux `spec.interval`, Argo CD sync/refresh cadence). A
"last reconciled" timestamp that is older than the configured interval suggests the controller is
stalled or its source is unreachable, not that everything is fine. Read the interval before judging
a reconcile timestamp stale. A controller that stopped reconciling silently can leave drift
unnoticed; a stale timestamp is a signal to check the controller pod and its source, not a pass.

## Criteria

- GREEN: releases deployed, GitOps resources Synced/Ready and Healthy, reconcile timestamps within interval, no recent warning burst.
- YELLOW: one failed or pending release with no broad user impact, reconciliation delayed but recovering, or OutOfSync with a known manual change.
- RED: repeated failed reconciliations, Synced-but-Degraded critical apps, failed release for critical workloads, a stalled controller, or widespread drift.

## Common False Positives

- CRDs absent because the cluster does not use that GitOps controller (distinct from an RBAC denial).
- Intentionally suspended GitOps resources (paused on purpose, not failing).
- Helm history showing old failed revisions after a later successful rollback or upgrade.
- `OutOfSync` reflecting a deliberate manual change pending the next sync.

## Output Caps

Use `--max`, `head`, and `tail`. Inspect one release at a time after the broad list identifies it.
