---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "OPNsense CE"
    version: "26.7.7 (Xenial Xenops, released 2026-10-13)"
    source: "https://docs.opnsense.org/releases/CE_26.7.html"
  - tool: "pfSense CE"
    version: "2.9.0"
    source: "https://docs.netgate.com/pfsense/en/latest/releases/versions.html"
  - tool: "pfSense Plus"
    version: "26.07"
    source: "https://docs.netgate.com/pfsense/en/latest/releases/versions.html"
  - tool: "CrowdSec"
    version: "v1.8.2"
    source: "https://github.com/crowdsecurity/crowdsec/releases"
---

# OPNsense and pfSense target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Notes |
|---|---|---|
| OPNsense CE | 26.7.7 | current Community Edition update, released 2026-10-13, "Xenial Xenops". Business Edition remains a separate even-quarter lane - do not quote the BE number as the CE version |
| pfSense CE | 2.9.0 | |
| pfSense Plus | 26.07 | |
| CrowdSec | v1.8.2 | |

Check [OPNsense release notes](https://docs.opnsense.org/releases/CE_26.7.html)
and the [pfSense version matrix](https://docs.netgate.com/pfsense/en/latest/releases/versions.html)
before selecting a firmware image; CE, Plus, and Business Edition have separate patch lanes.
