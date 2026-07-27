---
checked_at: "2026-07-27"
checked_by: "manual"
pins:
  - tool: "Prometheus"
    version: "3.13.1"
    source: "https://github.com/prometheus/prometheus/releases"
  - tool: "OpenTelemetry Collector"
    version: "v0.156.0"
    source: "https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
  - tool: "Grafana"
    version: "13.1.1"
    source: "https://github.com/grafana/grafana/releases"
  - tool: "Grafana Loki"
    version: "3.7.3"
    source: "https://github.com/grafana/loki/releases"
  - tool: "Grafana Tempo"
    version: "3.0.2"
    source: "https://github.com/grafana/tempo/releases"
  - tool: "Alertmanager"
    version: "0.33.1"
    source: "https://github.com/prometheus/alertmanager/releases"
---

# Observability target versions

Pins referenced by `../SKILL.md`. See `docs/version-pins.md` for the receipt
contract and staleness budget (120 days).

| Tool | Version | Source |
|---|---|---|
| Prometheus | 3.13.1 | <https://github.com/prometheus/prometheus/releases> |
| OpenTelemetry Collector | v0.156.0 | <https://github.com/open-telemetry/opentelemetry-collector-releases/releases> |
| Grafana | 13.1.1 | <https://github.com/grafana/grafana/releases> |
| Grafana Loki | 3.7.3 | <https://github.com/grafana/loki/releases> |
| Grafana Tempo | 3.0.2 | <https://github.com/grafana/tempo/releases> |
| Alertmanager | 0.33.1 | <https://github.com/prometheus/alertmanager/releases> |
