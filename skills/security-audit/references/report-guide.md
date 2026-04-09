# Security Audit: Report Guide

Reference material for generating the final audit report. Includes severity classification, OWASP mapping, and report template.

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|----------|
| **Critical** | Unauthenticated RCE, credential exfiltration, full auth bypass, arbitrary file write | Unauthed admin endpoint returns all API keys; zip slip with root container |
| **High** | Authenticated RCE, privilege escalation, SSRF to internal services, path traversal with write | Non-admin can access admin routes; SSRF bypasses IP allowlist |
| **Medium** | Stored XSS, CSRF, information disclosure (stack traces, internal paths), weak crypto | SHA-256 password hashing; verbose error responses in production |
| **Low** | Reflected XSS (limited), verbose errors in dev mode, missing security headers, TLS config issues | Missing HSTS header; `rejectUnauthorized: false` with opt-in flag |
| **Informational** | Best practice deviations, missing governance files, unpinned actions | No SECURITY.md; actions pinned to tags not SHAs; no SBOM |

## OWASP Top 10:2025 Quick Reference

Tag each finding to the correct category.

| ID | Category | Key Checks |
|----|----------|------------|
| A01 | Broken Access Control | Auth bypass, IDOR, privilege escalation, missing function-level auth |
| A02 | Security Misconfiguration | Default creds, verbose errors, CORS *, unnecessary features enabled, permissive headers |
| A03 | Supply Chain Failures | Unpinned deps, no lockfile integrity, compromised packages, no SBOM, mutable CI actions |
| A04 | Injection | SQL, NoSQL, OS command, LDAP, XSS, template injection, header injection |
| A05 | Insecure Design | Missing rate limiting, no abuse case analysis, client-controlled security state |
| A06 | Vulnerable Components | Known CVEs in deps, abandoned deps, no update automation |
| A07 | Auth & Session Failures | Weak passwords, broken session management, missing MFA, credential stuffing exposure |
| A08 | Data Integrity Failures | Unsigned updates, insecure deserialization, CI/CD pipeline manipulation |
| A09 | Logging & Monitoring Failures | No audit trail, unmonitored auth failures, sensitive data in logs |
| A10 | Mishandling Exceptional Conditions | Fail-open behavior, unhandled errors exposing state, silent error swallowing |

## Report Template

Save to `SECURITY-AUDIT.md` in the repo root. Warn the user this file MUST be gitignored - it contains vulnerability details.

```
# Security Audit Report

**Date**: YYYY-MM-DD
**Scope**: [files/directories audited]
**Commit**: [short SHA]
**Tools used**: [list of tools that ran successfully]
**Tools skipped**: [list of tools not available, with install commands]

## Executive Summary

X findings: N critical, N high, N medium, N low, N informational.
[1-3 sentence overall assessment]

## Findings

### [SEV-NNN] [CRITICAL|HIGH|MEDIUM|LOW|INFO]: [Title]

**OWASP**: [A01:2025 - Category Name]
**CWE**: [CWE-NNN if applicable]
**Location**: `file:line` (or `multiple files` with list)
**Description**: [What the vulnerability is]
**Impact**: [What an attacker can do - be specific about preconditions and blast radius]
**Evidence**:
[code snippet, tool output, or reproduction steps]
**Remediation**: [Specific fix with code example where possible]
**References**: [Links to CWE, OWASP guide, or relevant documentation]

---

[repeat for each finding, ordered by severity then by pass number]

## Pass Summary

| Pass | Method | Tool | Findings | Status |
|------|--------|------|----------|--------|
| 1 | Secret Scanning | gitleaks / trufflehog / manual | N | Done/Skipped |
| 2 | Dependency Audit | bun audit / trivy | N | Done/Skipped |
| 3 | Static Analysis | semgrep / bandit | N | Done/Skipped |
| 4 | Auth & Authz Review | Manual | N | Done |
| 5 | Injection & Input | Manual + grep | N | Done |
| 6 | Crypto & Data | Manual | N | Done |
| 7 | Container & Infra | Manual | N | Done |
| 8 | CI/CD & Supply Chain | Manual | N | Done |

## Tool Installation Reference

[For each skipped tool, provide install command]:
- betterleaks: `brew install betterleaks` or see https://github.com/zricethezav/betterleaks (gitleaks successor)
- semgrep: `pip install semgrep` or `brew install semgrep`
- gitleaks: `brew install gitleaks` or `go install github.com/gitleaks/gitleaks/v8@latest`
- trufflehog: `brew install trufflehog` or `go install github.com/trufflesecurity/trufflehog/v3@latest`
- trivy: `brew install trivy` or see https://aquasecurity.github.io/trivy (use v0.69.3 - versions 0.69.4-0.69.6 are compromised)
- scorecard: `go install github.com/ossf/scorecard/v5/cmd/scorecard@latest`
- checkov: `pip install checkov`

## Methodology Notes

[Any context about scope limitations, areas not covered, or assumptions made]
```
