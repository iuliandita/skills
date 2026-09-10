# Kubernetes Core

## Purpose

Check generic cluster health: nodes, namespaces, workloads, events, and resource pressure.

## Commands

```bash
kubectl --context <context> get nodes -o wide
kubectl --context <context> describe nodes | tail -n 120
kubectl --context <context> get namespaces
kubectl --context <context> get pods -A --field-selector=status.phase!=Succeeded
# Inspect every returned pod; narrow by namespace if the result exceeds display capacity.
# Use the bounded event check below for the requested time window.
kubectl --context <context> top nodes 2>&1 | head -n 80
kubectl --context <context> top pods -A --containers 2>&1 | head -n 80
```

Keep `2>&1` on `top`: a missing metrics-server returns `error: Metrics API not available`, which is
a finding, not a healthy zero. Do not mask it with `2>/dev/null`.

## Pod and container states (do not conflate)

Running is a pod phase, not readiness. Running pods can contain crashing or unready containers. Inspect READY, container waiting/termination states, restart counts, and events before classifying.

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

Use namespace/label selectors to keep checks readable. Treat capped output as partial coverage,
never as proof that the omitted resources are healthy. Inspect all pod readiness/state rows;
for large clusters, finish each namespace before aggregating. Narrow `describe` to a specific
namespace, pod, or node instead of truncating a cluster-wide diagnostic.

## Events in the requested window

Use Bash with jq for this check. Set the confirmed context and requested window in seconds (2h = 7200); capture the cutoff once. Unknown timestamps remain explicit coverage gaps. Filter before limiting output; if more than 80 events match, narrow by namespace before claiming complete coverage.

```bash
: "${CONTEXT:?confirmed context}" "${WINDOW_SECONDS:?requested window in seconds}"
case "$WINDOW_SECONDS" in ''|*[!0-9]*) echo 'Invalid window' >&2; exit 1;; esac
EVENT_CUTOFF=$(($(date +%s) - WINDOW_SECONDS))
event_data=$(kubectl --context "$CONTEXT" get events -A -o json) || exit 1
printf '%s' "$event_data" | jq --argjson cutoff "$EVENT_CUTOFF" '
  [.items[] |
   (.series.lastObservedTime // .lastTimestamp // .eventTime // .metadata.creationTimestamp) as $stamp |
   (try ($stamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch null) as $time |
   select($time == null or $time >= $cutoff) |
   {namespace: .metadata.namespace, name: .metadata.name, type, reason, message,
    lastObserved: $stamp, unknownTime: ($time == null)}] |
  {matched: length, events: .[:80]}'
```
