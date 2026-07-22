# Runnable Observability Examples

Use these compact artifacts as starting points. Replace service names and endpoints, then run the
named parser before returning them.

## OpenTelemetry Collector

```yaml
# otel-collector.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  batch: {}

exporters:
  otlphttp/backend:
    endpoint: ${env:OTLP_HTTP_ENDPOINT}

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/backend]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/backend]
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp/backend]
```

```bash
test -n "$OTLP_HTTP_ENDPOINT"
otelcol validate --config otel-collector.yaml
```

## Prometheus SLO rules and tests

This example treats 5xx responses as bad events for a 99.9% availability SLO.

```yaml
# slo-rules.yaml
groups:
  - name: api-slo
    rules:
      - alert: ApiSloFastBurn
        expr: |
          (
            sum(rate(http_requests_total{job="api",code=~"5.."}[5m]))
            / clamp_min(sum(rate(http_requests_total{job="api"}[5m])), 1)
            > 14.4 * 0.001
          )
          and
          (
            sum(rate(http_requests_total{job="api",code=~"5.."}[1h]))
            / clamp_min(sum(rate(http_requests_total{job="api"}[1h])), 1)
            > 14.4 * 0.001
          )
        for: 2m
        labels:
          severity: page
      - alert: ApiSloSlowBurn
        expr: |
          (
            sum(rate(http_requests_total{job="api",code=~"5.."}[30m]))
            / clamp_min(sum(rate(http_requests_total{job="api"}[30m])), 1)
            > 6 * 0.001
          )
          and
          (
            sum(rate(http_requests_total{job="api",code=~"5.."}[6h]))
            / clamp_min(sum(rate(http_requests_total{job="api"}[6h])), 1)
            > 6 * 0.001
          )
        for: 5m
        labels:
          severity: page
```

```yaml
# slo-rules.test.yaml
rule_files:
  - slo-rules.yaml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'http_requests_total{job="api",code="200"}'
        values: '0+100x400'
      - series: 'http_requests_total{job="api",code="500"}'
        values: '0+10x400'
    alert_rule_test:
      - eval_time: 1h
        alertname: ApiSloFastBurn
        exp_alerts:
          - exp_labels:
              severity: page
      - eval_time: 6h
        alertname: ApiSloSlowBurn
        exp_alerts:
          - exp_labels:
              severity: page
```

```bash
promtool check rules slo-rules.yaml
promtool test rules slo-rules.test.yaml
```

## Grafana dashboard JSON

```json
{
  "title": "API RED",
  "schemaVersion": 39,
  "time": { "from": "now-6h", "to": "now" },
  "templating": {
    "list": [
      { "name": "job", "type": "query", "query": "label_values(http_requests_total, job)" }
    ]
  },
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "Request rate",
      "targets": [
        { "refId": "A", "expr": "sum(rate(http_requests_total{job=~\"$job\"}[5m]))" }
      ]
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "Error ratio",
      "targets": [
        { "refId": "A", "expr": "sum(rate(http_requests_total{job=~\"$job\",code=~\"5..\"}[5m])) / clamp_min(sum(rate(http_requests_total{job=~\"$job\"}[5m])), 1)" }
      ]
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "p95 latency",
      "targets": [
        { "refId": "A", "expr": "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job=~\"$job\"}[5m])))" }
      ]
    }
  ]
}
```

```bash
jq -e '.panels | length == 3' api-red-dashboard.json
```
