---
checked_at: "2026-09-03"
checked_by: "manual"
pins:
  - tool: "Prometheus"
    version: "3.14.0"
    source: "https://github.com/prometheus/prometheus/releases"
  - tool: "OpenTelemetry Collector"
    version: "v0.160.0"
    source: "https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
  - tool: "Grafana"
    version: "13.2.1"
    source: "https://github.com/grafana/grafana/releases"
  - tool: "Grafana Loki"
    version: "3.7.7"
    source: "https://github.com/grafana/loki/releases"
  - tool: "Grafana Tempo"
    version: "3.0.3"
    source: "https://github.com/grafana/tempo/releases"
  - tool: "Alertmanager"
    version: "0.34.0"
    source: "https://github.com/prometheus/alertmanager/releases"
---

# Observability target versions

Pins referenced by `../SKILL.md`. See `docs/version-pins.md` for the receipt
contract and staleness budget (120 days).

| Tool | Version | Source |
|---|---|---|
| Prometheus | 3.14.0 | <https://github.com/prometheus/prometheus/releases> |
| OpenTelemetry Collector | v0.160.0 | <https://github.com/open-telemetry/opentelemetry-collector-releases/releases> |
| Grafana | 13.2.1 | <https://github.com/grafana/grafana/releases> |
| Grafana Loki | 3.7.7 | <https://github.com/grafana/loki/releases> |
| Grafana Tempo | 3.0.3 | <https://github.com/grafana/tempo/releases> |
| Alertmanager | 0.34.0 | <https://github.com/prometheus/alertmanager/releases> |
