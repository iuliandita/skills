# Browsing Tool Setup

Installation, configuration, and backend-specific patterns for each supported browsing backend.

---

## Lightpanda

Headless browser built from scratch in Zig with V8. Single static binary, no dependencies.
~16x less memory and ~9x faster than Chrome. Native MCP server built in.

### Installation

```bash
# Linux x86_64
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/0.2.9/lightpanda-x86_64-linux
chmod +x lightpanda && sudo mv lightpanda /usr/local/bin/

# Linux aarch64
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/0.2.9/lightpanda-aarch64-linux
chmod +x lightpanda && sudo mv lightpanda /usr/local/bin/

# macOS (Apple Silicon)
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/0.2.9/lightpanda-aarch64-macos
chmod +x lightpanda && sudo mv lightpanda /usr/local/bin/

# Docker
docker run -d --name lightpanda -p 9222:9222 lightpanda/browser:nightly
```

Platforms: Linux x86_64, Linux aarch64, macOS x86_64, macOS aarch64. Windows via WSL2 only.

### Modes

**CLI fetch** (one-shot, no session):
```bash
lightpanda fetch --dump markdown --strip-mode full https://example.com
```

**CDP server** (Playwright/Puppeteer compatible):
```bash
lightpanda serve --host 127.0.0.1 --port 9222
# Connect: await puppeteer.connect({ browserWSEndpoint: "ws://127.0.0.1:9222" })
```

**MCP server** (stdio, native AI agent integration):
```bash
lightpanda mcp
```

Claude Code config (`settings.json` or `~/.claude/settings.json`):
```json
{
  "mcpServers": {
    "lightpanda": {
      "command": "lightpanda",
      "args": ["mcp"]
    }
  }
}
```

### MCP Tools (native)

| Tool | Description | Typical tokens |
|------|-------------|---------------|
| `goto` / `navigate` | Navigate to URL | ~10 |
| `markdown` | Page content as markdown | ~500-2000 |
| `semantic_tree` | Pruned DOM with ARIA roles, XPaths, node IDs | ~200-500 |
| `links` | All `<a href>` links with text | ~100-300 |
| `interactiveElements` | Buttons, inputs, clickable items | ~200-400 |
| `structuredData` | JSON-LD, OpenGraph, meta tags | ~100-500 |
| `evaluate` / `eval` | Execute JavaScript in page context | varies |
| `click` | Click element by backend node ID | ~10 |
| `fill` | Fill text input | ~10 |
| `scroll` | Scroll page or element | ~10 |
| `waitForSelector` | Wait for CSS selector to appear | ~10 |
| `hover` | Trigger hover events | ~10 |
| `press` | Keyboard events | ~10 |
| `selectOption` | Select dropdown option | ~10 |
| `setChecked` | Check/uncheck checkbox | ~10 |
| `findElement` | Find by ARIA role/name | ~50-200 |
| `nodeDetails` | Inspect specific DOM node by ID | ~50-100 |
| `detectForms` | Detect forms and field structure | ~100-300 |

Resources: `mcp://page/html`, `mcp://page/markdown`

### CLI Flags

| Flag | Description |
|------|-------------|
| `--dump html\|markdown\|semantic_tree\|semantic_tree_text` | Output format |
| `--strip-mode js\|css\|ui\|full` | Remove non-content elements |
| `--wait-until networkidle` | Wait for network activity to stop |
| `--wait-selector ".selector"` | Wait for CSS selector to appear |
| `--wait-script "expression"` | Wait for JS expression to return truthy |
| `--obey-robots` | Respect robots.txt |
| `--with-frames` | Include iframe contents |
| `--user-agent-suffix "text"` | Append to user agent string |

### Known Limitations

- No graphical rendering - no screenshots, no visual regression
- Partial Web API coverage - complex SPAs may hit gaps
- CORS not implemented - cross-origin JS may behave differently
- Multi-page/multi-context support is limited
- Default user agent `Lightpanda/1.0` may be blocked by some sites
  (use `--user-agent-suffix` to customize)
- AGPL-3.0 license - share source if running as a modified service
- Telemetry enabled by default (`LIGHTPANDA_DISABLE_TELEMETRY=true` to disable)

For authenticated work, prefer the MCP or CDP server modes over one-shot `fetch` so cookies,
local storage, redirects, and CSRF tokens stay in one browser context. Clear storage between
unrelated tenants or accounts.

---

## Playwright MCP

Full browser automation via Microsoft's official MCP server. Controls real Chromium, Firefox,
or WebKit. Higher token cost than Lightpanda but complete Web API coverage.

### Installation

```bash
# As Claude Code plugin (if available in your plugin marketplace)
# Or standalone:
npx @playwright/mcp@0.0.72
```

### Key Tools

| Tool | Description |
|------|-------------|
| `browser_navigate` | Navigate to URL |
| `browser_snapshot` | Accessibility tree snapshot |
| `browser_click` | Click element by accessible name/role |
| `browser_fill_form` | Fill form fields |
| `browser_take_screenshot` | Visual screenshot (high token cost) |
| `browser_evaluate` | Execute JavaScript |
| `browser_press_key` | Keyboard input |
| `browser_select_option` | Select dropdown |
| `browser_hover` | Hover element |
| `browser_drag` | Drag element |
| `browser_file_upload` | Upload files |
| `browser_handle_dialog` | Handle alert/confirm/prompt dialogs |
| `browser_tabs` | List open tabs |
| `browser_navigate_back` | Navigate back |
| `browser_wait_for` | Wait for condition |
| `browser_close` | Close browser |

### When to prefer over Lightpanda

- Full Web API compatibility needed (complex SPAs, WebRTC, WebGL)
- Screenshot or visual verification required
- Multi-tab workflows
- File upload/download
- Dialog handling (alert, confirm, prompt)
- Sites that block non-standard user agents

For screenshots, take a DOM or accessibility snapshot first and screenshot only the page or
element that needs visual evidence. Avoid base64 screenshots when text extraction is enough.

### Token cost comparison

| Action | Playwright MCP | Lightpanda |
|--------|---------------|------------|
| Page snapshot/tree | ~2000-5000 (full a11y tree) | ~200-500 (semantic tree) |
| Screenshot | ~8000+ (base64 image) | N/A (no rendering) |
| Page content | via evaluate | ~500-2000 (markdown) |

---

## agent-browser

Rust CLI from Vercel Labs. Maximum token efficiency through accessibility snapshots with
element refs. The LLM issues shell commands; agent-browser is pure automation with no
built-in reasoning.

### Installation

```bash
npx agent-browser@0.26.0
# or: npm install -g agent-browser
```

### Key Commands

```bash
agent-browser open <url>              # Navigate
agent-browser snapshot                # Text snapshot of page
agent-browser snapshot -i             # Interactive elements with refs (@e1, @e2...)
agent-browser click @e3               # Click by ref
agent-browser fill @e5 "search text"  # Fill input by ref
agent-browser scroll down             # Scroll
agent-browser wait <selector>         # Wait for element
agent-browser close                   # Close browser
```

### When to prefer

- CLI-first environments without MCP support
- Maximum token efficiency (~200-400 tokens per snapshot)
- Batch automation via JSON piping
- Auth vault for encrypted credential storage

### Batch execution

```bash
echo '[
  {"action":"open","url":"https://example.com"},
  {"action":"snapshot","interactive":true}
]' | agent-browser batch
```

### Engine selection

agent-browser supports Lightpanda as an alternative engine:
```bash
agent-browser open --engine lightpanda <url>
```

This combines agent-browser's snapshot/ref system with Lightpanda's lightweight engine.

---

## WebFetch (Built-in)

Many AI tools include built-in web fetch:
- **Claude Code**: `WebFetch` tool
- **Other platforms**: varies

Best for static pages where JavaScript rendering isn't needed. Zero setup, lowest overhead.

### When to use

- Documentation pages (most render server-side)
- API documentation
- Blog posts and articles
- Any page where server-rendered HTML has the content you need

### When NOT to use

- SPAs that render content client-side
- Pages requiring authentication
- Interactive workflows
- Sites that serve empty shells populated via JavaScript
