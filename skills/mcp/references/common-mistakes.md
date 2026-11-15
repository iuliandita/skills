# Common Mistakes

Errors AI models consistently make when generating MCP server code.

## Common Mistakes

AI models consistently make these errors when generating MCP server code:

1. **Shell commands via string interpolation** - the #1 vulnerability. Always use
   argument arrays for system commands.
2. **Missing server-side validation** - generating `inputSchema` but never validating
   against it in the handler. The client may skip validation.
3. **Bare `"type": "string"` in schemas** - no `maxLength`, no `pattern`, no constraints.
   Accepts any string of any length.
4. **Binding HTTP to `0.0.0.0`** - exposes local servers to the network. Use `127.0.0.1`.
5. **No `Origin` header validation** - enables DNS rebinding against local servers.
6. **Leaking error details** - stack traces, file paths, or DB errors in tool responses.
7. **Token passthrough** - accepting OAuth tokens meant for other services without
   audience validation.
8. **Hallucinating SDK methods** - inventing API calls that don't exist. See AI Self-Check for the verification checklist item.
9. **Ignoring elicitation actions** - handling `accept` but crashing on `decline`/`cancel`.
10. **No graceful shutdown** - missing SIGINT/SIGTERM handlers on stdio servers.
