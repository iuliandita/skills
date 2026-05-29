# Storage

## Purpose

Check PVs, PVCs, storage classes, CSI components, and volume attachment state.

## Commands

```bash
kubectl --context <context> get storageclass
kubectl --context <context> get pv | head -n 120
kubectl --context <context> get pvc -A | head -n 120
kubectl --context <context> get volumeattachments.storage.k8s.io | head -n 120
kubectl --context <context> get pods -A -o wide | grep -Ei 'csi|storage|provisioner' | head -n 80
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | grep -Ei 'volume|mount|attach|provision' | tail -n 80
```

## PVC and PV phase (distinct states)

| Phase | Means | Action |
|-------|-------|--------|
| PVC `Bound` | claim matched to a PV | healthy |
| PVC `Pending` | no matching PV, provisioner not running, or `WaitForFirstConsumer` mode | check provisioner pod, storageclass `volumeBindingMode`, events |
| PV `Available` | unbound, ready to claim | normal for spare capacity |
| PV `Released` | claim deleted, PV not yet reclaimed | normal under `Retain`; needs manual cleanup, not an outage |
| PV `Failed` | reclaim or recycle failed | investigate; data may be stranded |

A `Pending` PVC under `volumeBindingMode: WaitForFirstConsumer` is expected until a pod that uses it
is scheduled. Do not flag it as RED if no consumer pod exists yet; that is by design.

## Capacity metric traps

`kubectl get pvc` shows the requested/provisioned size, not consumed bytes. Reported PV capacity is
the volume's declared size, not its disk footprint. Two common misreads:

- **Thin-provisioned and LVM-thin volumes report provisioned size, not allocation.** With LVM thin
  pools, the pool's `data_percent` (visible on the node via `lvs -a`, not via kubectl) is blocks
  ever written to the pool, not current filesystem usage and not per-volume usage. A high
  `data_percent` after deletes does not mean the filesystem is full; it means blocks were allocated.
  Pool exhaustion, not PVC count, is the real risk on thin pools.
- **PVC "size" is not usage.** Actual disk consumption inside a volume requires looking at the
  filesystem (`df` from inside a pod that mounts it) or a CSI metrics exporter, not the PVC object.
  Do not report a 100Gi PVC as "100Gi used."

When a metric drives status, state what it measures. "PVC provisioned 100Gi" is a capacity claim;
it says nothing about how full the volume is.

## CSI and attachment failures (differentiate)

- A failed `VolumeAttachment` or `FailedAttachVolume` event means the node could not attach the
  disk; often a cloud API limit (max disks per node) or a stuck attachment on a former node.
- A `FailedMount` / `MountVolume.SetUp failed` event is a later stage: attached but not mountable,
  often a missing secret, fsType mismatch, or stale multi-attach on a `ReadWriteOnce` volume moving
  between nodes.
- A degraded CSI controller pod blocks provisioning cluster-wide; a degraded CSI node pod blocks
  only mounts on that node. Distinguish the two before scoping impact.

## Schedule-aware staleness

For volume-snapshot schedules or backup-driven storage classes, compare the newest snapshot against
the configured schedule before calling it stale. A 3-day-old snapshot is overdue for a daily policy
but current for a weekly one. Read the `VolumeSnapshot`/schedule cadence first.

## Criteria

- GREEN: PVCs Bound, PVs Available or Bound as expected, CSI pods healthy.
- YELLOW: isolated Pending PVC, warning events for one namespace, old Released PV needing cleanup, a single WaitForFirstConsumer claim awaiting its pod.
- RED: many Pending PVCs, attach/mount failures for active workloads, CSI controller degraded, or a thin pool approaching exhaustion.

## Common False Positives

- Released PVs retained intentionally by reclaim policy.
- Pending PVCs from disabled or paused workloads, or from `WaitForFirstConsumer` with no consumer yet.
- Storage events from completed jobs outside the requested time window.
- High thin-pool `data_percent` after deletes (allocated blocks, not live usage).

## Output Caps

Use `head`, `tail`, and namespace filters. Do not describe every PV or PVC unless the broad list
identifies a small suspect set.
