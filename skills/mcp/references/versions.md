---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "MCP specification"
    version: "2026-07-28"
    source: "https://modelcontextprotocol.io/specification"
  - tool: "TypeScript SDK (@modelcontextprotocol/server, client, core)"
    version: "2.4.0"
    source: "https://github.com/modelcontextprotocol/typescript-sdk/releases"
  - tool: "Python SDK (mcp)"
    version: "2.3.0"
    source: "https://github.com/modelcontextprotocol/python-sdk/releases"
---

# MCP target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages.

| Tool | Version | Source | Notes |
|---|---|---|---|
| MCP specification | 2026-07-28 | <https://modelcontextprotocol.io/specification> | Current stable; stateless core, extensions framework, and no initialize/session handshake |
| TypeScript SDK (@modelcontextprotocol/server, client, core) | 2.4.0 | <https://github.com/modelcontextprotocol/typescript-sdk/releases> | The monolithic `@modelcontextprotocol/sdk` 1.32.2 is the legacy line; the 2026-10-02 releases restrict client redirects to the same origin, and 2.3.0+ serves one connection per `Server` instance |
| Python SDK (mcp) | 2.3.0 | <https://github.com/modelcontextprotocol/python-sdk/releases> | 2.x stable; review the v1-to-v2 migration guide |

## Protocol transports

stdio and Streamable HTTP. The standalone HTTP+SSE transport is deprecated and available only as a
temporary legacy bridge.

## Security floors

- TypeScript SDK (October 20 advisories, see `security.md`): server and client 2.3.0, sdk 1.32.0,
  server-legacy 2.3.1, express 2.0.2. These supersede the OAuth credential-redirect floors
  ([CVE-2026-104850](https://github.com/modelcontextprotocol/typescript-sdk/security/advisories/GHSA-6qxp-vccf-f47h))
  of client 2.2.0 / sdk 1.31.0.
- Python SDK: 2.2.0 (or 1.30.0 on 1.x) is the floor for the high-severity OAuth credential-redirect
  (GHSA-qx49, [GHSA-qx49-fqc8-xw99](https://github.com/modelcontextprotocol/python-sdk/security/advisories/GHSA-qx49-fqc8-xw99))
  and medium unreclaimed-session
  ([CVE-2026-59951](https://github.com/modelcontextprotocol/python-sdk/security/advisories/GHSA-84m7-p3x7-pcfv)) advisories.
