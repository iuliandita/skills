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
kubectl --context <context> top nodes 2>/dev/null || true
kubectl --context <context> top pods -A --containers 2>/dev/null | head -n 80 || true
```

## Criteria

- GREEN: nodes Ready, no broad pending/crashing workload pattern, recent events are routine.
- YELLOW: isolated NotReady node, repeated warnings in one namespace, metrics unavailable.
- RED: multiple NotReady nodes, control-plane symptoms, many CrashLoopBackOff or Pending pods.

## Common False Positives

- Short-lived rollout pods during deployments.
- Completed jobs outside the requested time window.
- Metrics server missing on small clusters.

## Output Caps

Use `head -n 80`, `tail -n 120`, label selectors, and field selectors. Avoid full `describe` output
unless narrowing to one namespace, pod, or node.
