---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "DSM 7.4"
    version: "7.4.1-90080 (7.4 GA was 90075, 2026-06-16)"
    source: "https://www.synology.com/en-global/releaseNote/DSM"
  - tool: "DSM 7.3 LTS patch floor"
    version: "7.3.2-86009-4"
    source: "https://www.synology.com/en-global/security/advisory/Synology_SA_26_13"
  - tool: "DSM 7.2.2 patch floor"
    version: "7.2.2-72806-9"
    source: "https://www.synology.com/en-global/security/advisory/Synology_SA_26_13"
  - tool: "DSM 7.2.1 patch floor"
    version: "7.2.1-69057-12"
    source: "https://www.synology.com/en-global/security/advisory/Synology_SA_26_13"
  - tool: "MailPlus Server (DSM 7.3)"
    version: "4.0.1-31663"
    source: "https://www.synology.com/en-global/security/advisory/Synology_SA_26_11"
  - tool: "MailPlus Server (DSM 7.2.2/7.2.1)"
    version: "4.0.1-21663"
    source: "https://www.synology.com/en-global/security/advisory/Synology_SA_26_11"
---

# Synology DSM target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Reverify before use if the receipt exceeds 120 days.

- DSM 7.4.1-90080 - current release (7.4 GA was 90075, 2026-06-16)
- DSM 7.3 (released 2025-10-08) - Long-Term Support line, maintained to October 2027. Patch
  floor is **7.3.2-86009-4 or above** ([SA-26:13](https://www.synology.com/en-global/security/advisory/Synology_SA_26_13),
  critical, 2026-09-18). `-2` carries the SA-26:06 fixes but not SA-26:03 (CVE-2026-32746);
  `-3` predates SA-26:13
- DSM 7.2 - end of maintenance December 2025, yet it still received fixes in SA-26:06 (April
  2026). Treat continued patching as unreliable rather than as policy, and plan an upgrade
- Advisories: Synology-SA-26:03 (CVE-2026-32746, telnetd buffer overflow, CVSS 9.8, unauthenticated
  RCE - keep Telnet off), Synology-SA-26:06 (multiple DSM CVEs, 2026-04-15), Synology-SA-26:11 (MailPlus Server), Synology-SA-26:13 (critical DSM file read/write, 2026-09-18)
- [SA-26:11](https://www.synology.com/en-global/security/advisory/Synology_SA_26_11):
  critical MailPlus Server CVE-2026-13136 and CVE-2025-15660; fixed in
  4.0.1-31663+ for DSM 7.3 or 4.0.1-21663+ for DSM 7.2.2/7.2.1. Update the
  package separately from DSM; the advisory lists no mitigation.
- [SA-26:13](https://www.synology.com/en-global/security/advisory/Synology_SA_26_13) (critical,
  CVE-2026-13684 CVSS 9.8 unauthenticated file read/write) raises DSM 7.2.2 to 7.2.2-72806-9+ and
  DSM 7.2.1 to 7.2.1-69057-12+ ([SA-26:03](https://www.synology.com/en-global/security/advisory/Synology_SA_26_03)
  floors were -8 / -11). These advisory floors do not establish ongoing lifecycle support.
