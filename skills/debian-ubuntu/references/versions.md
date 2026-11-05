---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Debian stable"
    version: "13 (trixie)"
    source: "https://www.debian.org/releases/"
  - tool: "Ubuntu LTS"
    version: "26.04 (Resolute Raccoon)"
    source: "https://ubuntu.com/about/release-cycle"
  - tool: "Ubuntu interim lane"
    version: "26.10 Stonking Stingray, released 2026-10-15, supported to July 2027; 25.10 EOL July 2026"
    source: "https://ubuntu.com/about/release-cycle"
  - tool: "Ubuntu 26.04 linux package (CVE-2026-53362 fix)"
    version: "7.0.0-31.31"
    source: "https://ubuntu.com/security/CVE-2026-53362"
  - tool: "Ubuntu 24.04 linux-hwe-7.0 (CVE-2026-53362 fix)"
    version: "7.0.0-31.31~24.04.1"
    source: "https://ubuntu.com/security/CVE-2026-53362"
---

# Debian and Ubuntu target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled verified October 2026.
Only pin versions here when they materially affect compatibility or troubleshooting shape. For
ordinary Debian and Ubuntu package work, prefer the live distro lane and package policy over a
stale package-version table. Reverify before use if the receipt exceeds 120 days.

| Component | Version | Why it matters |
|-----------|---------|----------------|
| Debian stable | 13 (trixie) | current stable baseline and repo behavior |
| Ubuntu LTS | 26.04 (Resolute Raccoon) | current LTS baseline for most Ubuntu guidance |
| Ubuntu interim lane | verify live (26.10 "Stonking Stingray" released 2026-10-15, supported to July 2027; 25.10 EOL July 2026) | interim releases move fast; check the active upgrade path instead of memorizing one short-lived codename |
| Ubuntu HWE lane | verify live | kernel metapackage and hardware-enablement behavior matter more than one exact kernel number |
| NVIDIA driver branch | verify live | proprietary branch choice affects Wayland, gaming, and DKMS behavior |
| Mesa stack | verify live | AMD and Intel graphics behavior tracks the shipped Mesa lane |
| Kernel security | verify live via USN tracker | patch high-severity privesc CVEs promptly; mid-2026 examples to confirm fixed: Copy Fail CVE-2026-31431 (CISA KEV, exploited), Dirty Frag CVE-2026-43284/43500, Fragnesia CVE-2026-46300 (ESP-in-TCP, public PoC, not in CISA KEV), ptrace CVE-2026-46333 |

## Security recheck (2026-09-10)

[CVE-2026-53362](https://ubuntu.com/security/CVE-2026-53362)
is a high-priority Linux IPv6 flaw that Canonical lists as CISA KEV. Ubuntu 26.04's
`linux` package is fixed in `7.0.0-31.31`; Ubuntu 24.04's `linux-hwe-7.0` is fixed in
`7.0.0-31.31~24.04.1`. The 24.04 `linux` lane remains marked vulnerable in that record.
Check the exact release and kernel package; these are not universal kernel version floors.
