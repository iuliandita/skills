---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Fedora stable"
    version: "44 / verify live"
    source: "https://fedoraproject.org/wiki/Releases"
  - tool: "Fedora next branch"
    version: "45 / verify live"
    source: "https://fedoraproject.org/wiki/Releases"
  - tool: "RHEL enterprise lane"
    version: "10.x"
    source: "https://access.redhat.com/support/policy/updates/errata"
  - tool: "RHEL previous major"
    version: "9.x"
    source: "https://access.redhat.com/support/policy/updates/errata"
  - tool: "Amazon Linux"
    version: "AL2023 / verify live release"
    source: "https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes.html"
---

# RHEL and Fedora target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled verified October 2026.
Only pin versions here when they materially affect compatibility or troubleshooting shape. For
ordinary package work, prefer the live distro lane and repo state over a stale package table.
Reverify before use if the receipt exceeds 120 days.

| Component | Version | Why it matters |
|-----------|---------|----------------|
| Fedora stable | 44 / verify live | current mainstream baseline (Fedora ships ~every 6 months and EOLs ~13 months, faster than this table is bumped - confirm live) |
| Fedora next branch | 45 / verify live | useful when a bug is really Fedora-next behavior |
| RHEL enterprise lane | 10.x | current enterprise baseline in the new major lane |
| RHEL previous major | 9.x | still widely deployed and behaviorally different from 10 |
| Rocky Linux | verify live major lane | close to RHEL, but current docs and vault state still matter |
| AlmaLinux | verify live major lane | close to RHEL, but current release notes and policy docs still matter |
| Oracle Linux | verify live major lane | current Oracle lane matters, but UEK vs RHCK matters more |
| Amazon Linux | AL2023 / verify live release | release-note lane matters more than memorizing one point version |
| SELinux | verify live | policy package and mode matter more than memorized version strings |
| DNF | verify live | Fedora moves faster than enterprise lanes; DNF 5 vs legacy expectations matter |
| Podman | verify live | rootless and quadlet behavior depend on the shipped distro lane |
| Kernel security | verify live via RHSA/FEDORA tracker | patch high-severity privesc CVEs promptly; mid-2026 examples to confirm fixed: Copy Fail CVE-2026-31431 (CISA KEV, exploited), Dirty Frag CVE-2026-43284/43500, Fragnesia CVE-2026-46300 (ESP-in-TCP, public PoC, not in CISA KEV), ptrace CVE-2026-46333; newer: CVE-2026-53266 (netfilter ebtables SNAT, CISA KEV 2026-09-18, Red Hat Important, no RHEL errata listed at the 2026-10-02 check) |

For kernel advisories, use the exact vendor package and support stream. Red Hat rates
[Copy Fail CVE-2026-31431](https://access.redhat.com/security/cve/CVE-2026-31431)
Important; use the linked bulletin and RHSA package matrix for affected and fixed builds.
Do not transfer Ubuntu kernel patch floors to RHEL, Fedora, or a downstream clone.
