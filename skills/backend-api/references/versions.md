---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "FastAPI"
    version: "0.142.2"
    source: "https://github.com/fastapi/fastapi/releases"
  - tool: "Express"
    version: "5.2.1"
    source: "https://github.com/expressjs/express/releases"
  - tool: "NestJS"
    version: "12.1.2"
    source: "https://github.com/nestjs/nest/releases"
  - tool: "OpenAPI Specification"
    version: "3.2.1"
    source: "https://github.com/OAI/OpenAPI-Specification/releases"
  - tool: "HTTP Semantics"
    version: "RFC 9110"
    source: "https://www.rfc-editor.org/rfc/rfc9110"
  - tool: "Problem Details for HTTP APIs"
    version: "RFC 9457"
    source: "https://www.rfc-editor.org/rfc/rfc9457"
  - tool: "OAuth 2.0 Security Best Current Practice"
    version: "RFC 9700"
    source: "https://www.rfc-editor.org/rfc/rfc9700"
---

# Backend API target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages.

| Tool | Version | Source | Notes |
|---|---|---|---|
| FastAPI | 0.142.2 | <https://github.com/fastapi/fastapi/releases> |  |
| Express | 5.2.1 | <https://github.com/expressjs/express/releases> | Published 2025-12-01 |
| NestJS | 12.1.2 | <https://github.com/nestjs/nest/releases> | Major release; check migration notes before upgrading. 12.0.2+ fixes high-severity microservice (GHSA-m8vh-jmq9-5rjg) and Fastify middleware-bypass (GHSA-9c5c-9qcx-q35q) advisories |
| OpenAPI Specification | 3.2.1 | <https://github.com/OAI/OpenAPI-Specification/releases> | Published 2026-09-10 |
| HTTP Semantics | RFC 9110 | <https://www.rfc-editor.org/rfc/rfc9110> | June 2022 |
| Problem Details for HTTP APIs | RFC 9457 | <https://www.rfc-editor.org/rfc/rfc9457> | July 2023 |
| OAuth 2.0 Security Best Current Practice | RFC 9700 | <https://www.rfc-editor.org/rfc/rfc9700> | January 2025 |

## Security notes (checked 2026-10-28)

- Express/NestJS upload stacks using Multer <2.3.0 are affected by high-severity multipart
  denial of service, [CVE-2026-82333](https://github.com/expressjs/multer/security/advisories/GHSA-535w-7cp7-47q4).
- Upgrade Multer to 2.5.0+. 2.5.0 fixes high-severity DoS from a pending async `fileFilter` after
  request teardown, [CVE-2026-113872](https://github.com/expressjs/multer/security/advisories/GHSA-q7qp-rjg7-q26m);
  2.4.0 fixed medium-severity aborted-upload disk exhaustion,
  [CVE-2026-88932](https://github.com/expressjs/multer/security/advisories/GHSA-3pph-fpjx-jg34).
- Bound `limits.fieldArrayIndexLimit` to application needs. Checking only the top-level framework
  version misses vulnerable middleware.
