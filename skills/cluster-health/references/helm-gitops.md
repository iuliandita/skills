# Helm and GitOps

## Purpose

Check release state, failed upgrades, and GitOps reconciliation without changing resources.

## Commands

```bash
helm --kube-context <context> list -A --all --max 100
helm --kube-context <context> history <release> -n <namespace> --max 10
kubectl --context <context> get applications.argoproj.io -A 2>/dev/null | head -n 80 || true
kubectl --context <context> get kustomizations.toolkit.fluxcd.io -A 2>/dev/null | head -n 80 || true
kubectl --context <context> get helmreleases.helm.toolkit.fluxcd.io -A 2>/dev/null | head -n 80 || true
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 80
```

## Criteria

- GREEN: releases deployed, GitOps resources synced or ready, no recent warning burst.
- YELLOW: one failed or pending release with no broad user impact; reconciliation delayed.
- RED: repeated failed reconciliations, failed release for critical workloads, widespread drift.

## Common False Positives

- CRDs absent because the cluster does not use that GitOps controller.
- Intentionally suspended GitOps resources.
- Helm history showing old failed revisions after a later successful rollback or upgrade.

## Output Caps

Use `--max`, `head`, and `tail`. Inspect one release at a time after the broad list identifies it.
