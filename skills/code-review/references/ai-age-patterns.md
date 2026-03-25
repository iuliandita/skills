# AI-Age Code Review Patterns

Bug patterns specific to AI-generated code, LLM API integrations, agentic AI systems, and MCP (Model Context Protocol) implementations. As of 2025-2026, AI-generated code is present in most codebases -- these patterns catch what traditional review misses.

Research date: March 2026.

---

## AI-Generated Code Smells

AI-generated code passes linters and compilers but fails in production. PRs with AI-generated code have **1.7x more issues** than human-only PRs. Treat AI output like a junior developer's draft -- it needs review, not trust.

### Hallucinated APIs and Dependencies

One in five AI code samples references libraries or methods that don't exist. The code looks plausible, compiles in isolation (if the import is stubbed), then crashes at runtime.

**Detect:**
- Imports for packages that don't exist in npm/PyPI/pkg.go.dev (e.g., `requests.get_json()`, `pandas.DataFrame.merge_smart()`)
- Method calls on real libraries using non-existent methods -- the library exists, the method doesn't
- "Hallucinated dependencies" -- AI recommends packages with plausible names that aren't in any registry (potential supply chain attack vector: attackers register the hallucinated name)
- API usage patterns that were valid 2-3 years ago but removed in current versions
- Function signatures that almost match the real API but have wrong parameter names or ordering

**Fix:** Verify every unfamiliar import against the official package registry and current docs. Configure static analysis (Semgrep) to flag unknown imports. Cross-reference against `package.json`, `requirements.txt`, or `go.mod`.

### Deprecated and Outdated Patterns

AI training data includes code from many years. Patterns that were standard in 2020-2022 still appear in generated code today.

**Detect:**
- Deprecated crypto algorithms (MD5, SHA1 for security, `Math.random()` for secrets)
- Old API patterns (callbacks where promises/async-await is standard, XMLHttpRequest instead of fetch)
- Framework version mismatches -- React class components in a hooks-based codebase, Express 4 patterns in Express 5, Vue Options API in a Composition API project
- Deprecated stdlib functions (Python's `os.path.join` when the project uses `pathlib`, `unittest` when `pytest` is standard)
- Outdated dependency versions hardcoded in config (AI copies version numbers from training data)

### Over-Defensive Error Handling

AI models add excessive try/catch, null checks, and validation -- especially around internal code that doesn't need it. This obscures real errors.

**Detect:**
- Try/catch blocks around pure, infallible operations (string concatenation, math on known-good types)
- Null checks on values that are guaranteed non-null by the type system or prior validation
- Redundant validation at every layer instead of validating once at the boundary
- Empty catch blocks or catch blocks that log and continue (swallowing errors that should propagate)
- Multiple nested try/catch blocks when a single outer handler would suffice
- "Defensive" returns of default values that hide bugs (returning `[]` instead of surfacing an error)

### Unnecessary Abstractions

AI-generated code tends toward over-abstraction -- wrapping simple operations in classes, factories, or utility functions that add indirection without value.

**Detect:**
- Single-use wrapper classes around stdlib functionality
- Factory patterns for objects that are instantiated in exactly one place
- Abstract base classes with a single concrete implementation
- "Manager" / "Handler" / "Helper" / "Utility" classes that just proxy to one other thing
- Generic naming (`DataProcessor`, `ItemHandler`) instead of domain-specific names
- Adapter patterns where no adaptation is needed (wrapping a REST client in another REST client)

### Insecure Defaults from Training Data

AI mimics patterns from training data, including bad security practices from tutorials and Stack Overflow.

**Detect:**
- Hardcoded credentials: `apiKey`, `admin:admin`, `password123`, `sk-...` placeholders left in code
- `CORS: *` or overly permissive CORS headers
- HTTP instead of HTTPS in URLs
- `verify=False` or TLS verification disabled
- Debug mode enabled by default (`DEBUG=True`, verbose logging with sensitive data)
- Insecure session/cookie defaults (missing `httpOnly`, `secure`, `sameSite` flags)
- SQL queries built with string concatenation instead of parameterized queries
- Dynamic code execution on user-controlled input (eval, exec, Function constructor)
- File paths from user input without sanitization (path traversal)
- **45% of AI-generated code contains security vulnerabilities**; Java implementations show 70%+ failure rates

### Performance Anti-Patterns

AI prioritizes clarity over efficiency. Code works at dev scale but fails under load.

**Detect:**
- O(n^2) nested iterations where O(n) is possible -- AI defaults to the naive approach
- String concatenation in loops instead of builders/join
- N+1 database queries inside loops (AI doesn't see the ORM's lazy loading trap)
- Loading entire datasets into memory when streaming would work
- Inefficient data structure choices (array lookups where a Set/Map would be O(1))
- Missing pagination on unbounded queries
- GPT-4 generated code runs **3x slower** than human-written equivalents on benchmarks

### Inconsistent Code Quality

**Detect:**
- Formatting inconsistencies: **2.66x more common** in AI code vs human code
- Naming violations: **2x more common** -- generic identifiers, mismatched terminology
- Code that appears consistent but breaks local project patterns (camelCase in a snake_case project)
- Error handling approaches vary within the same file (sometimes throws, sometimes returns null, sometimes logs)
- Import style inconsistent with the rest of the codebase

### Logic and Correctness Errors

Account for **60% of faults** in AI-generated code. The code runs, produces output, but the output is wrong.

**Detect:**
- Off-by-one errors in loops, slices, ranges (AI training data contains both 0-indexed and 1-indexed patterns)
- Boundary conditions not handled (empty arrays, null values, max integers, negative numbers)
- Business logic that looks correct superficially but doesn't match actual domain requirements
- Control flow that handles the happy path but silently drops edge cases
- Incorrect variable assignments or swapped parameters
- Error handling that's **2x more likely** to be missing or wrong compared to human code

### The Three-Minute Triage

Quick filter that catches ~60% of AI-generated issues before deeper review:
1. Run linter for syntax/import errors
2. Run type checker for type inconsistencies
3. Execute existing tests for behavioral regressions

If all three pass, proceed to manual review focusing on logic, edge cases, and API contracts.

---

## Agentic AI Patterns

Code that interacts with LLM APIs, builds AI agents, or uses tool/function calling.

### Prompt Injection in User-Facing LLM Apps

Prompt injection is #1 on the OWASP Top 10 for LLM Applications 2025. Found in over 73% of production AI deployments assessed during security audits.

**Detect:**
- User input concatenated directly into system prompts without sanitization
- External data sources (web pages, documents, emails, database records) injected into LLM context without isolation -- indirect prompt injection vector
- Missing input/output validation on LLM responses before executing actions
- LLM output used directly in SQL queries, shell commands, or API calls without sanitization
- System prompts exposed via simple "repeat your instructions" attacks
- Multi-agent systems where agents trust each other's output -- "second-order" injection: attacker injects into a low-privilege agent, which tricks a high-privilege agent (ServiceNow incident, 2025)
- Missing output content filtering on LLM responses displayed to users

**Fix:** Isolate system prompts from user input. Treat all LLM output as untrusted. Apply least-privilege to agent capabilities. Validate outputs before executing actions. Use structured output schemas.

### Missing Rate Limiting on LLM API Calls

**Detect:**
- No per-request or per-user rate limiting on endpoints that call LLM APIs -- a single user can exhaust the entire API quota
- No per-run token/cost caps on agentic workflows -- an agent loop can consume thousands of dollars in minutes
- Missing `Retry-After` header handling -- hammering a rate-limited API with retries makes it worse
- No circuit breaker pattern when LLM provider is degraded -- cascading failures when the API returns 500s
- Concurrent requests exceeding account limits (e.g., 200 coroutines when account supports 10 concurrent)
- Missing prompt caching -- repeated identical prompts waste tokens. Anthropic's cached input tokens don't count toward ITPM limits

### Token Limit and Context Window Handling

**Detect:**
- No token counting before sending requests -- context window overflow causes hard failures (newer Claude models return validation errors instead of truncating)
- Tool results submitted back into conversation without size limits -- large tool outputs push the context over the window limit
- Extended thinking blocks not preserved when posting tool results -- Anthropic requires the entire unmodified thinking block with cryptographic signatures; truncating breaks the conversation
- Token count tracking only updated after successful responses -- a single turn that pushes from 88% to 100%+ triggers overflow without any threshold check
- No auto-compaction or summarization strategy for long conversations
- Missing fallback to smaller model or context compression when approaching limits
- Hardcoded context window sizes that don't account for model upgrades/changes

### Streaming Response Edge Cases

**Detect:**
- Missing error handling during streaming -- Anthropic reports ~1 in 100 streaming requests fail with "Overloaded" errors even with `max_retries=3`
- Streaming with `response_format` and tools simultaneously -- can cause all tool calls to be converted to content chunks instead of tool call events (LiteLLM/Anthropic SDK bug)
- Fallback routing failing during streaming -- provider overload during active stream prevents fallback to alternate providers
- SSE (Server-Sent Events) parsing differences between providers -- Bedrock proxy sends data-only lines (no event field), while SDKs expect event fields like `message_start`
- No handling for partial/interrupted streams -- client receives half a response with no indication of truncation
- Streaming responses not properly closed on client disconnect (resource leak)

### Tool/Function Calling Validation

**Detect:**
- LLM-generated function arguments not validated against the schema before execution -- the model can hallucinate parameters, call non-existent tools, or pass wrong types
- Tool definitions with ambiguous parameter descriptions -- models dither or pass incorrect values when constraints aren't explicit
- No validation of tool results before returning to the model -- malformed tool output causes the next turn to fail
- Missing error handling when tool execution fails -- bare exceptions or swallowed errors instead of structured error responses back to the model
- Tool call chains without intermediate validation -- agent executes a sequence of tools without checking each result
- `function_call` / `tool_choice` forcing a specific tool without checking if the model's reasoning supports it
- Schema drift: tool definitions in code don't match the actual function signatures (added/removed parameters)

### Agentic Workflow Reliability

**Detect:**
- Single-loop agent architecture without plan-and-execute separation -- agent iterates inefficiently on complex tasks
- No intermediate output validation between steps -- an early step produces garbage, later steps build on it
- Missing success criteria / acceptance thresholds per step -- agent "completes" tasks without verifiable outcomes
- Excessive privilege scope -- agent holds broad API credentials instead of scoped, short-lived tokens
- Agent output used without sanitization in downstream systems -- prompt injection through tool outputs
- Credential exposure in execution traces/logs -- API keys logged during debugging
- No audit trail of agent reasoning chains -- can't diagnose failures post-incident
- "Hope and retry" pattern -- assuming transient failures resolve without exponential backoff or circuit breakers
- Agent-only solutions for deterministic workflows -- static DAGs are better for predictable pipelines

---

## LLM SDK Common Bugs

### Anthropic SDK

**Detect:**
- Not handling the January 2026 API change that detects and rejects requests from third-party clients
- Prompt caching not supported through Anthropic's OpenAI SDK compatibility layer -- code using the compatibility layer silently misses caching benefits
- System/developer messages in OpenAI-compatible mode -- Anthropic hoists and concatenates them to the beginning since only a single initial system message is supported; multi-system-message patterns break
- Extended thinking with tool use requires the final assistant message to start with a thinking block preceding tool_use/tool_result blocks -- wrong ordering causes validation errors
- Streaming operations over 10 minutes -- Anthropic now strongly recommends streaming for long operations; non-streaming calls may timeout
- Missing handling for `overloaded_error` (529) during streaming -- retries on the same request don't help if the error is capacity-related
- Rate limits measured in RPM + ITPM + OTPM (input/output tokens per minute separately) -- tracking only RPM misses token-based limits

### OpenAI SDK

**Detect:**
- `response_format: { type: "json_object" }` without "JSON" in the system prompt -- the model may not produce valid JSON
- Structured outputs (`response_format: { type: "json_schema" }`) with optional fields -- the model sometimes omits them entirely vs. returning null
- `tool_choice: "auto"` in loops -- model may call tools indefinitely without producing a final response
- `stream: true` without handling `[DONE]` sentinel -- client hangs waiting for more chunks
- Token counting differences between tiktoken (client-side) and actual API consumption (server-side) -- off by enough to cause unexpected truncation
- Missing `max_tokens` / `max_completion_tokens` -- defaults vary by model, some models generate until context exhaustion

### General LLM API Patterns

**Detect:**
- No exponential backoff on retries -- linear retries or fixed delays flood a recovering service
- Not reading rate limit headers (`Retry-After`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) -- guessing wait times instead of using the server's guidance
- Synchronous API calls blocking the main thread/event loop -- use async clients for concurrent workloads
- Missing request timeouts -- a hanging API call blocks the entire application indefinitely
- No cost tracking or spending alerts -- agentic loops can burn through budget without visibility
- Raw API error responses (request IDs, JSON payloads) shown to end users -- not actionable and leaks internal details
- API key in source code or environment variables without rotation strategy

---

## MCP (Model Context Protocol) Bugs

MCP is still maturing in security. As of March 2026: 43% of MCP servers contain command injection vulnerabilities, 43% have flawed OAuth authentication flows, 33% allow unrestricted network access, 5% of open-source MCP servers are seeded with tool poisoning attacks.

### Command Injection and RCE

**Detect:**
- User input passed to shell execution functions without sanitization (CVE-2025-53355: Kubernetes MCP, CVE-2025-6514: mcp-remote, CVSS 9.6)
- Malicious MCP server sending crafted `authorization_endpoint` during OAuth flow -- mcp-remote passed it straight to the system shell (437,000+ downloads affected)
- `.git/config` manipulation through git MCP server operations (CVE-2025-68145, CVE-2025-68143, CVE-2025-68144 in Anthropic's mcp-server-git)
- Unsanitized input from tool parameters used in subprocess calls (CVE-2025-53967: Figma/Framelink MCP)
- Direct string concatenation of user data into shell commands in any MCP server tool handler

### Tool Poisoning

**Detect:**
- Tool descriptions containing hidden instructions that manipulate the AI model's behavior -- instructions are shown to the model but may be hidden from the user
- Tool definitions that request sensitive context: `system_prompt`, `conversation_history`, API keys as "required parameters"
- Post-approval tool redefinition -- server changes tool behavior after initial approval, enabling silent behavior changes
- Tool name collisions between MCP servers -- a malicious server registers a tool with the same name as a legitimate one
- Line-jumping attacks -- malicious instructions trigger during initial connection before user approval
- ANSI escape codes in tool descriptions hiding instructions from terminal display

### Path Traversal and File Access

**Detect:**
- Filesystem MCP server sandbox escape via symlink bypass (found in Anthropic's own Filesystem-MCP server)
- Path validation using string matching instead of canonical path resolution -- `../` sequences bypass blacklists (CVE-2025-67366)
- Smithery MCP hosting path traversal in `smithery.yaml` build configuration -- leaked Fly.io API token controlling 3,000+ hosted applications

### Network and Authentication

**Detect:**
- SSRF vulnerabilities: 36.7% of MCP servers on the web may be affected. Found in Microsoft's MarkItDown, Fetch MCP (CVE-2025-65513), Microsoft Learn servers
- Session identifiers in URLs -- tokens exposed in logs, browser history, and referrer headers
- MCP Inspector developer tool allowing unauthenticated RCE (CVE-2025-49596 in Anthropic's own tool)
- Grafana MCP binding to `0.0.0.0:8000` by default -- accessible from any network, not just localhost
- DNS rebinding attacks on localhost-bound SSE servers -- multiple SDKs lack protection
- Cross-client data leaks in TypeScript SDK (CVE-2026-25536)

### Data Exposure

**Detect:**
- Cross-tenant data exposure -- Asana MCP server bug allowed one organization's data to be seen by others
- WhatsApp MCP tool exploited to exfiltrate entire conversation history
- GitHub MCP prompt injection via public issues leaking private repository contents
- Overly broad Personal Access Token / API key scopes passed to MCP servers
- API keys stored in plaintext on local filesystem by MCP configuration

### MCP Server Implementation Bugs

**Detect:**
- Missing input validation on tool parameters -- the model sends whatever it wants, and the server trusts it
- No rate limiting on tool calls -- model in a loop can hammer external services
- Missing authentication on tool endpoints -- any MCP client can connect and execute tools
- Excessive permissions: MCP server tools having broader system access than the tool description implies
- No logging or audit trail of tool executions -- can't detect or investigate abuse
- Missing error handling that causes the entire server to crash on malformed input
- "Consent fatigue" pattern: server designs that require repeated user approvals, training users to click "allow" without reading

---

## MCP Security Breach Timeline (Reference)

- **Apr 2025**: WhatsApp MCP tool poisoning -- entire chat history exfiltrated
- **May 2025**: GitHub MCP prompt injection -- private repo data leaked via public issues
- **Jun 2025**: Asana MCP cross-tenant data exposure; Anthropic MCP Inspector RCE (CVE-2025-49596)
- **Jul 2025**: mcp-remote OS command injection (CVE-2025-6514, 437K+ downloads)
- **Aug 2025**: Anthropic Filesystem MCP sandbox escape and symlink bypass
- **Sep 2025**: Malicious Postmark-impersonating MCP server (supply chain)
- **Oct 2025**: Smithery MCP path traversal (leaked Fly.io token for 3K+ apps); Figma/Framelink MCP command injection (CVE-2025-53967)

---

## AI Code Review Process Adjustments

When reviewing code in a codebase that uses AI assistants (Copilot, Cursor, Claude, etc.), adjust the review process:

### Enhanced Scrutiny Areas

1. **Verify every import** -- AI hallucinates packages. Check that dependencies exist and are at the right version
2. **Check API signatures** -- AI generates plausible but wrong function signatures. Verify against current docs, not memory
3. **Test edge cases hard** -- AI handles happy paths well but misses boundaries. Empty inputs, nulls, max values, Unicode
4. **Audit error handling** -- AI either over-handles (swallowing real errors) or under-handles (only happy-path coverage). Error handling issues are 2x more common in AI code
5. **Look for logic correctness** -- 75% higher logic/correctness issues in AI PRs. Business logic mistakes, incorrect control flow, wrong dependencies
6. **Security is 2.74x worse** -- improper password handling, insecure object references, missing input validation. Run CodeQL/Semgrep on every AI-generated PR
7. **Performance under load** -- I/O issues are 8x higher. Profile before merging performance-sensitive code
8. **Concurrency bugs** -- 2x more likely. Check for race conditions, incorrect ordering, misused primitives

### Red Flags (Likely AI-Generated and Unreviewed)

- Code that's syntactically perfect but doesn't match the project's idioms
- Generic variable names (`data`, `result`, `item`, `handler`) instead of domain-specific names
- Overly verbose comments that restate what the code does
- Classes/abstractions where a function would do
- Framework-version-specific patterns from 2+ years ago
- Error handling that catches everything and logs nothing useful
- Multiple approaches to the same problem in the same file (AI regenerated parts with different prompts)
- Suspiciously polished boilerplate with subtle logic errors buried inside

### Metrics to Track

- AI-generated PRs: expect 10.83 issues/PR avg vs 6.45 for human-only
- Readability issues: 3x+ higher in AI code
- Security issues: up to 2.74x higher
- Performance (I/O): 8x higher
- AI code usage at 84% adoption in 2025, but developer trust at only 29%

Sources for statistics: CodeRabbit State of AI vs Human Code Generation Report, Stack Overflow Developer Survey 2025.
