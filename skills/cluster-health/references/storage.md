# Storage

## Purpose

Check PVs, PVCs, storage classes, CSI components, and volume attachment state.

## Commands

```bash
kubectl --context <context> get storageclass
kubectl --context <context> get pv | head -n 120
kubectl --context <context> get pvc -A | head -n 120
kubectl --context <context> get volumeattachments.storage.k8s.io | head -n 120
kubectl --context <context> get pods -A -o wide | grep -Ei 'csi|storage|provisioner' | head -n 80 || true
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | grep -Ei 'volume|mount|attach|provision' | tail -n 80 || true
```

## Criteria

- GREEN: PVCs Bound, PVs Available or Bound as expected, CSI pods healthy.
- YELLOW: isolated Pending PVC, warning events for one namespace, old Released PV needing review.
- RED: many Pending PVCs, attach/mount failures for active workloads, CSI controller degraded.

## Common False Positives

- Released PVs retained intentionally by reclaim policy.
- Pending PVCs from disabled or paused workloads.
- Storage events from completed jobs outside the requested time window.

## Output Caps

Use `head`, `tail`, and namespace filters. Do not describe every PV or PVC unless the broad list
identifies a small suspect set.
