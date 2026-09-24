---
checked_at: "2026-09-25"
checked_by: "manual"
pins:
  - tool: "Prometheus"
    version: "3.14.0"
    source: "https://github.com/prometheus/prometheus/releases"
  - tool: "OpenTelemetry Collector"
    version: "v0.161.0"
    source: "https://github.com/open-telemetry/opentelemetry-collector-releases/releases"
  - tool: "Grafana"
    version: "13.2.2"
    source: "https://github.com/grafana/grafana/releases"
  - tool: "Grafana Loki"
    version: "3.7.8"
    source: "https://github.com/grafana/loki/releases"
  - tool: "Grafana Tempo"
    version: "3.0.3"
    source: "https://github.com/grafana/tempo/releases"
  - tool: "Alertmanager"
    version: "0.34.1"
    source: "https://github.com/prometheus/alertmanager/releases"
---

# Observability target versions

Pins referenced by `../SKILL.md`. Record the checked date, exact version, and primary
source when refreshing a pin. Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Source |
|---|---|---|
| Prometheus | 3.14.0 | <https://github.com/prometheus/prometheus/releases> |
| OpenTelemetry Collector | v0.161.0 | <https://github.com/open-telemetry/opentelemetry-collector-releases/releases> |
| Grafana | 13.2.2 | <https://github.com/grafana/grafana/releases> |
| Grafana Loki | 3.7.8 | <https://github.com/grafana/loki/releases> |
| Grafana Tempo | 3.0.3 | <https://github.com/grafana/tempo/releases> |
| Alertmanager | 0.34.1 | <https://github.com/prometheus/alertmanager/releases> |

## Security notes (checked 2026-09-10)

- [CVE-2026-14199](https://grafana.com/security/security-advisories/cve-2026-14199/):
  self-managed Grafana Enterprise with Auth Proxy and `sync_ttl > 0` can confuse cached
  identities and permit session takeover. The 13.2 lane is fixed in 13.2.1; other patched
  lanes are 13.1.5, 13.0.8, and 12.4.10. Check the advisory for the deployed branch.
- [CVE-2026-75889](https://grafana.com/security/security-advisories/cve-2026-75889/):
  Alloy before 1.19.0 can disclose local files through a ServiceMonitor `bearerTokenFile`
  when a less-privileged user can write watched ServiceMonitors. Use Alloy 1.19.0 or later
  and restrict ServiceMonitor writes and the collector service account's permissions.
