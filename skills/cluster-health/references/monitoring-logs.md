# Monitoring and Logs

## Purpose

Check alert signals, metrics availability, recent logs, and noisy namespaces with bounded output.

## Commands

```bash
kubectl --context <context> get pods -A | grep -Ei 'prometheus|grafana|alertmanager|loki|tempo|metrics' | head -n 80
kubectl --context <context> top nodes 2>&1 | head -n 80
kubectl --context <context> top pods -A 2>&1 | head -n 80
kubectl --context <context> logs -n <namespace> deploy/<app> --since=<timewindow> --tail=120 2>&1 | tail -n 120
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 100
```

Read stderr, do not discard it. `kubectl logs ... 2>/dev/null` hides the reason a check failed: a
wrong namespace, a wrong deployment name, a pod that was already replaced, or an RBAC denial all
collapse into empty output and read as "no errors found." Capture stderr with `2>&1` and inspect
the actual message before classifying. Common log-fetch failures and what they mean:

| stderr message | Means | Not |
|----------------|-------|-----|
| `Error from server (NotFound)` | wrong namespace or deployment name | "app is healthy" |
| `error: ... forbidden` | RBAC gap for this context/SA | "no logs exist" |
| `previous terminated container ... not found` | container has not restarted (no `-p` history) | clean |
| empty output, exit 0 | genuinely no matching log lines in window | always trustworthy |

When you need the crash reason, fetch the previous container's logs explicitly with
`kubectl --context <context> logs -n <namespace> <pod> -c <container> --previous --tail=120 2>&1`.
Without `--previous` you see the new container, which may look clean while the crash is in the dead one.

## Metric interpretation

- **`kubectl top` requires metrics-server.** When it is absent, `top` returns
  `error: Metrics API not available`. That is a missing-component finding, not a healthy zero. Do
  not report "0 CPU" when the metrics pipeline is simply not installed or not yet scraped.
- **`top` reflects a short scrape window, not sustained load.** A single sample can miss a spike or
  catch a cold-start peak. Treat one reading as a hint, not a verdict.
- **A flat or zero metric can be a scrape-pipeline failure.** If Prometheus, the metrics-server, or
  the scrape target is down, the value reads as zero or stale rather than erroring. A metric that
  stopped updating is a signal to check the collection path, not evidence the workload went idle.
  Check the metric's age, not just its value.
- **Alertmanager "no alerts firing" can mean alerting is broken.** A silent Alertmanager during an
  active incident is a RED signal, not a GREEN one. Confirm the alerting pipeline is actually
  evaluating rules before trusting an empty alert list.

## Schedule-aware staleness

If a metric or log stream has an expected cadence (scrape interval, alert evaluation interval,
log shipper flush), compare recency against that cadence, not a fixed guess. A 5-minute-old scrape
is normal for a 15s interval only if the pipeline is alive; if the newest sample predates the
scrape interval by a wide margin, the collector or target is likely down. Read the configured
interval before judging a metric stale.

## Criteria

- GREEN: metrics available and updating, monitoring pods healthy, logs show no repeated current errors.
- YELLOW: metrics unavailable, one noisy namespace, alerting stack partially degraded, stale-but-recovering scrapes.
- RED: monitoring unavailable during incident, repeated errors from critical workloads, alert flood, or alerting pipeline confirmed down (empty alert list is not the same as healthy).

## Common False Positives

- Metrics APIs absent in small or local clusters (a missing-component finding, not a zero).
- Normal startup warnings during rolling updates.
- Log lines from previous container instances outside the requested time window.

## Output Caps

Always use `--since=<timewindow>` and `--tail`. Summarize repeated lines with counts instead of
including full logs. Keep `2>&1` so error reasons stay visible; cap with `head`/`tail`, not by
discarding stderr.
