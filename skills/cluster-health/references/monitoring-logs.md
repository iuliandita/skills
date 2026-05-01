# Monitoring and Logs

## Purpose

Check alert signals, metrics availability, recent logs, and noisy namespaces with bounded output.

## Commands

```bash
kubectl --context <context> get pods -A | grep -Ei 'prometheus|grafana|alertmanager|loki|tempo|metrics' | head -n 80 || true
kubectl --context <context> top nodes 2>/dev/null || true
kubectl --context <context> top pods -A 2>/dev/null | head -n 80 || true
kubectl --context <context> logs -n <namespace> deploy/<app> --since=<timewindow> --tail=120 2>/dev/null || true
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 100
```

## Criteria

- GREEN: metrics available, monitoring pods healthy, logs show no repeated current errors.
- YELLOW: metrics unavailable, one noisy namespace, alerting stack partially degraded.
- RED: monitoring unavailable during incident, repeated errors from critical workloads, alert flood.

## Common False Positives

- Metrics APIs absent in small or local clusters.
- Normal startup warnings during rolling updates.
- Log lines from previous container instances outside the requested time window.

## Output Caps

Always use `--since=<timewindow>` and `--tail`. Summarize repeated lines with counts instead of
including full logs.
