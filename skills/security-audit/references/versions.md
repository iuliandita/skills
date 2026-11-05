---
checked_at: "2026-10-28"
checked_by: "migration"
pins:
  - tool: "Semgrep"
    version: "1.182.0"
    source: "https://github.com/semgrep/semgrep/releases"
  - tool: "Bandit"
    version: "1.9.4"
    source: "https://github.com/PyCQA/bandit/releases"
  - tool: "Gitleaks"
    version: "8.30.1"
    source: "https://github.com/gitleaks/gitleaks/releases"
  - tool: "Betterleaks"
    version: "1.9.0"
    source: "https://github.com/betterleaks/betterleaks/releases/tag/v1.9.0"
  - tool: "TruffleHog"
    version: "3.99.7"
    source: "https://github.com/trufflesecurity/trufflehog/releases"
  - tool: "Trivy"
    version: "0.76.1"
    source: "https://github.com/aquasecurity/trivy/releases"
  - tool: "OpenSSF Scorecard"
    version: "5.6.0 (v6 in proposal stage)"
    source: "https://github.com/ossf/scorecard/releases"
  - tool: "OWASP Top 10"
    version: "2025 (released November 2025)"
    source: "https://owasp.org/Top10/"
  - tool: "OWASP Agentic Top 10"
    version: "2026 (released December 2025)"
    source: "https://genai.owasp.org/"
---

# Security audit target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026
(release check 2026-10-28). Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Notes |
|---|---|---|
| Semgrep | 1.182.0 | |
| Bandit | 1.9.4 | |
| Gitleaks | 8.30.1 | |
| [Betterleaks](https://github.com/betterleaks/betterleaks/releases/tag/v1.9.0) | 1.9.0 | same author as Gitleaks |
| TruffleHog | 3.99.7 | |
| Trivy | 0.76.1 | 0.69.4-0.69.6 was compromised - see known incidents; 0.69.3 is also inside the CVE-2026-63328 range, so stay on 0.72.0+ |
| OpenSSF Scorecard | 5.6.0 | v6 in proposal stage |
| OWASP Top 10 | 2025 | released November 2025 |
| OWASP Agentic Top 10 | 2026 | released December 2025 |
