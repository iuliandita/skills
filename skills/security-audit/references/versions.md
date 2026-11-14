---
checked_at: "2026-11-14"
checked_by: "manual"
pins:
  - tool: "Semgrep"
    version: "1.185.0"
    source: "https://github.com/semgrep/semgrep/releases"
  - tool: "Bandit"
    version: "1.9.4"
    source: "https://github.com/PyCQA/bandit/releases"
  - tool: "Gitleaks"
    version: "8.30.1"
    source: "https://github.com/gitleaks/gitleaks/releases"
  - tool: "Betterleaks"
    version: "1.10.1"
    source: "https://github.com/betterleaks/betterleaks/releases/tag/v1.10.1"
  - tool: "TruffleHog"
    version: "3.99.9"
    source: "https://github.com/trufflesecurity/trufflehog/releases"
  - tool: "Trivy"
    version: "0.76.2"
    source: "https://github.com/aquasecurity/trivy/releases"
  - tool: "OpenSSF Scorecard"
    version: "5.6.0 (no v6 release yet)"
    source: "https://github.com/ossf/scorecard/releases"
  - tool: "OWASP Top 10"
    version: "2025 (released November 2025)"
    source: "https://owasp.org/Top10/"
  - tool: "OWASP Agentic Top 10"
    version: "2026 (released December 2025)"
    source: "https://genai.owasp.org/"
---

# Security audit target versions

Pins referenced by `../SKILL.md`. Every pin re-verified against its source on 2026-11-14.
Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Notes |
|---|---|---|
| Semgrep | 1.185.0 | |
| Bandit | 1.9.4 | |
| Gitleaks | 8.30.1 | |
| [Betterleaks](https://github.com/betterleaks/betterleaks/releases/tag/v1.10.1) | 1.10.1 | same author as Gitleaks; 2.0.0 is release-candidate only |
| TruffleHog | 3.99.9 | |
| Trivy | 0.76.2 | minimum 0.72.0: CVE-2026-63328 affects every earlier release; 0.69.4-0.69.6 were compromised - see known incidents |
| OpenSSF Scorecard | 5.6.0 | no v6 release yet |
| OWASP Top 10 | 2025 | released November 2025 |
| OWASP Agentic Top 10 | 2026 | released December 2025 |
