# Kubernetes Core

## Purpose

Check generic cluster health: nodes, namespaces, workloads, events, and resource pressure.

## Commands

```bash
kubectl --context <context> get nodes -o wide
kubectl --context <context> describe nodes | tail -n 120
kubectl --context <context> get namespaces
kubectl --context <context> get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | head -n 80
kubectl --context <context> get events -A --sort-by=.lastTimestamp | tail -n 80
kubectl --context <context> top nodes 2>&1 | head -n 80
kubectl --context <context> top pods -A --containers 2>&1 | head -n 80
```

Keep `2>&1` on `top`: a missing metrics-server returns `error: Metrics API not available`, which is
a finding, not a healthy zero. Do not mask it with `2>/dev/null`.

## Pod not-running states (do not conflate)

A non-Running pod can fail in distinct ways with different remediation. Read the `STATUS` column
and the pod events before classifying.

| State | Means | Where to look next |
|-------|-------|--------------------|
| `Pending` | unschedulable - no node fits, or a PVC/quota is blocking | `kubectl describe pod`: scheduler events, taints, resource requests, unbound PVC |
| `CrashLoopBackOff` | container starts then exits repeatedly | `logs --previous`, exit code in `describe`, readiness/liveness probe config |
| `ImagePullBackOff` / `ErrImagePull` | image cannot be pulled | image name/tag, registry auth (`imagePullSecrets`), registry reachability |
| `ContainerCreating` (stuck) | volume mount, CNI, or secret/configmap not ready | events for mount/attach errors, CNI pod health, missing referenced object |
| `Terminating` (stuck) | finalizer or node-unreachable grace period | finalizers on the object, node Ready status |

`Pending` is a scheduling problem; `CrashLoopBackOff` is a runtime problem; `ImagePullBackOff` is a
supply problem. Reporting "pods are down" without the distinction sends remediation the wrong way.

## Node capacity vs allocatable

`describe nodes` reports two resource figures. Do not read `Capacity` as schedulable headroom.

- **Capacity** = total hardware on the node.
- **Allocatable** = Capacity minus reserved amounts (`kube-reserved`, `system-reserved`, eviction
  thresholds). This is what the scheduler can actually place pods against.
- **Allocated resources** (the `Requests`/`Limits` table near the bottom of `describe node`) shows
  what is already requested, summed across pods. Pressure is `Requests` approaching `Allocatable`,
  not approaching `Capacity`.

A node can show plenty of `Capacity` and still be unschedulable because `Requests` already fill
`Allocatable`. `Pending` pods next to "lots of free CPU" usually mean requests, not raw usage, are
the constraint. Node conditions (`MemoryPressure`, `DiskPressure`, `PIDPressure`) in `describe node`
are separate from this and indicate active eviction risk.

## Criteria

- GREEN: nodes Ready, no broad pending/crashing workload pattern, recent events are routine.
- YELLOW: isolated NotReady node, repeated warnings in one namespace, metrics unavailable, a single workload in a transient backoff.
- RED: multiple NotReady nodes, control-plane symptoms, many CrashLoopBackOff or Pending pods, or node pressure conditions causing eviction.

## Common False Positives

- Short-lived rollout pods during deployments.
- Completed jobs outside the requested time window.
- Metrics server missing on small clusters (report as missing component, not as zero load).
- A single `CrashLoopBackOff` early in a deploy that self-resolves once a dependency comes up.

## Output Caps

Use `head -n 80`, `tail -n 120`, label selectors, and field selectors. Avoid full `describe` output
unless narrowing to one namespace, pod, or node.
