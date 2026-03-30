---
name: mcp
description: >
  Use when building, reviewing, or debugging MCP (Model Context Protocol) servers, tools,
  resources, or prompts. Also use for MCP transport configuration (stdio, SSE, streamable HTTP),
  MCP authentication (OAuth 2.1), tool handler implementation, or reviewing MCP servers for
  security vulnerabilities. Triggers: 'mcp', 'model context protocol', 'mcp server', 'mcp tool',
  'mcp resource', 'mcp prompt', 'tool handler', 'stdio transport', 'SSE transport',
  'streamable HTTP', 'mcp auth', 'mcp oauth', 'elicitation', '@modelcontextprotocol/sdk',
  'mcp-framework', 'fastmcp'. Do NOT use for general API development (just write the code),
  Claude API / Anthropic SDK usage (use claude-api if available), or security auditing of
  existing MCP servers (use security-audit).
source: custom
date_added: "2026-03-30"
effort: high
---

# MCP: Model Context Protocol Server Development

Build, review, and debug MCP servers that expose tools, resources, and prompts to AI coding
assistants. The goal is secure, well-structured servers that follow the protocol spec and don't
become the 43% of MCP implementations with command injection vulnerabilities.

**Target versions** (March 2026):
- MCP specification: 2025-11-05 (current stable)
- TypeScript SDK: @modelcontextprotocol/sdk 1.x
- Python SDK: mcp 1.x
- Protocol transports: stdio, SSE, streamable HTTP

## When to use

- Building a new MCP server (tools, resources, prompts)
- Adding tool handlers to an existing MCP server
- Configuring MCP transport (stdio for local, SSE/HTTP for remote)
- Implementing MCP authentication (OAuth 2.1)
- Implementing MCP elicitation (interactive dialogs)
- Reviewing MCP server code for injection vulnerabilities
- Debugging MCP connection issues between client and server
- Migrating from a custom tool integration to MCP

## When NOT to use

- General REST API development that doesn't use MCP -- just write the API
- Claude API / Anthropic SDK usage -- use claude-api if available
- Security auditing existing servers across a codebase -- use security-audit (it has an MCP section)
- Writing prompts for LLMs (not MCP prompt resources) -- use prompt-generator

---

## AI Self-Check

Before returning any MCP server code, verify:

- [ ] All tool handler inputs are validated and sanitized (no raw string interpolation into
  shell commands, SQL, file paths, or URLs)
- [ ] Tool descriptions are accurate and under 2KB (clients may truncate beyond this)
- [ ] Resource URIs use a defined scheme and are validated before use
- [ ] Error responses use proper MCP error codes, not raw stack traces
- [ ] Authentication is implemented for remote transports (not just stdio)
- [ ] No secrets hardcoded in tool handlers or server configuration
- [ ] Input schemas use JSON Schema with explicit types, required fields, and constraints
- [ ] Server handles graceful shutdown (cleanup on SIGINT/SIGTERM)
- [ ] Elicitation handlers validate server identity and don't auto-submit credentials
- [ ] Transport choice matches deployment context (stdio for local, HTTP for remote)

---

## Workflow

### Step 1: Determine the server's purpose

Before writing code, clarify:
- **What tools will it expose?** Each tool = one operation the AI can invoke.
- **What resources will it serve?** Resources = read-only data the AI can access.
- **What transport?** stdio for local CLI integration, SSE for web, streamable HTTP for production.
- **What authentication?** None for stdio, OAuth 2.1 for remote.
- **What language?** TypeScript (most mature SDK) or Python (simpler, FastMCP).

### Step 2: Scaffold the server

**TypeScript** (recommended for production):

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-server", version: "1.0.0" });

server.tool(
  "search_docs",
  "Search documentation by keyword",
  { query: z.string().describe("Search query"), limit: z.number().default(10) },
  async ({ query, limit }) => {
    const sanitized = query.replace(/[^\w\s-]/g, "");
    const results = await searchIndex(sanitized, limit);
    return { content: [{ type: "text", text: JSON.stringify(results) }] };
  }
);

server.resource("config", "config://app/settings", async (uri) => ({
  contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(config) }],
}));

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Python** (FastMCP for quick prototyping):

```python
from mcp.server.fastmcp import FastMCP
import re

mcp = FastMCP("my-server")

@mcp.tool()
def search_docs(query: str, limit: int = 10) -> str:
    """Search documentation by keyword."""
    sanitized = re.sub(r"[^\w\s-]", "", query)
    return str(search_index(sanitized, limit))

@mcp.resource("config://app/settings")
def get_config() -> str:
    """Application configuration."""
    return json.dumps(config)
```

### Step 3: Implement tools securely

This is where 43% of MCP servers fail. Every tool handler is an attack surface.

**The #1 rule: never interpolate user input into commands, queries, or paths.**

**Common injection vectors in MCP tools:**

| Vector | Bad pattern | Safe pattern |
|--------|-----------|--------------|
| Shell | Interpolated command strings | `execFile` with argument arrays + path validation |
| SQL | String concatenation in queries | Parameterized queries with `$1` placeholders |
| File paths | Direct `readFile(userPath)` | Resolve path, validate prefix against allowlist |
| URLs | Direct `fetch(userUrl)` | Parse URL, validate scheme + host against allowlist |
| Templates | Dynamic code evaluation | Sandboxed template engine with no code execution |

**Path traversal prevention:**

```typescript
import path from "node:path";

function safePath(base: string, userInput: string): string {
  const resolved = path.resolve(base, userInput);
  if (!resolved.startsWith(path.resolve(base) + path.sep)) {
    throw new Error("Path traversal detected");
  }
  return resolved;
}
```

### Step 4: Configure transport

| Transport | Use case | Auth needed | Notes |
|-----------|----------|-------------|-------|
| **stdio** | Local tools, CLI integration | No | Runs as user's process |
| **SSE** | Web integrations, shared servers | Yes (OAuth 2.1) | Persistent connection |
| **Streamable HTTP** | Production remote servers | Yes (OAuth 2.1) | Resumable, reconnectable |

For remote transports, implement OAuth 2.1 with PKCE (mandatory per MCP spec). No API key auth
for user-facing flows.

### Step 5: Handle elicitation safely

MCP elicitation lets servers request structured input from users mid-task. This is a social
engineering attack surface.

**Safe**: genuine user decisions (file selection, confirmation dialogs) with clear context.
**Dangerous**: fake "re-authenticate" dialogs, credential requests, auto-submitting responses.

Never request credentials or secrets through elicitation. Never auto-submit without user review.

### Step 6: Test the server

```bash
# Test with MCP Inspector (official debugging tool)
npx @modelcontextprotocol/inspector your-server-command

# Verify tool listing
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node your-server.js
```

Test each tool handler with: valid inputs (happy path), missing required fields,
malicious inputs (injection, path traversal, oversized payloads), concurrent requests.

---

## Common Mistakes

AI models consistently make these errors when generating MCP server code:

1. **String interpolation in shell/SQL** -- the most common vulnerability. Always use
   parameterized queries and argument arrays for system commands.
2. **Missing input validation** -- tool inputs arrive as JSON but may contain anything.
   Use Zod (TS) or Pydantic (Python) schemas with explicit constraints.
3. **Oversized tool descriptions** -- clients may cap descriptions at 2KB. Keep them concise.
4. **No error handling** -- uncaught exceptions crash the server. Wrap tool handlers and return
   structured MCP errors.
5. **Hardcoded secrets** -- use environment variables or a secret manager.
6. **No graceful shutdown** -- handle SIGINT/SIGTERM, especially for stdio servers.
7. **Blocking the event loop** -- use async operations for I/O in tool handlers.
8. **Returning raw errors** -- stack traces leak internals. Return user-friendly messages.

---

## Related Skills

- **security-audit** -- for auditing MCP servers as part of a broader security review. The
  security-audit skill's ASI and MCP sections cover vulnerability patterns; this skill covers
  building servers correctly from the start.
- **code-review** -- for reviewing MCP server code for correctness beyond security.
- **docker** -- for containerizing MCP servers with minimal capabilities.

---

## Rules

1. **Validate all tool inputs.** Every tool handler receives untrusted data. Use schema
   validation (Zod, Pydantic) with explicit types, ranges, and constraints. No raw string
   interpolation into commands, queries, or paths.
2. **No shell execution with string interpolation.** Use argument arrays for system commands.
   This prevents shell metacharacter injection.
3. **Keep descriptions under 2KB.** MCP clients truncate tool descriptions beyond this limit.
4. **Authenticate remote transports.** stdio is local (no auth needed). SSE and streamable HTTP
   must use OAuth 2.1 with PKCE. No API key auth for user-facing flows.
5. **Return structured errors.** Use MCP error codes and human-readable messages. Never expose
   stack traces, file paths, or internal state in error responses.
6. **Test with malicious inputs.** Every tool handler must be tested with injection payloads,
   path traversal attempts, and oversized inputs before deployment.
7. **Handle shutdown gracefully.** Register signal handlers. Clean up resources and exit cleanly.
8. **Run the AI Self-Check.** Every generated MCP server gets verified against the checklist
   above before returning to the user.
