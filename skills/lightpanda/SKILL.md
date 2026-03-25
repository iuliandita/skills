---
name: lightpanda
description: >
  Browse JavaScript-heavy web pages, extract content, and interact with SPAs using the Lightpanda
  headless browser via MCP. Trigger when: scraping JS-rendered pages, reading SPAs, extracting
  structured data from websites, when WebFetch returns empty/incomplete content from dynamic sites,
  or when the user needs to read a page that requires JavaScript execution. Also trigger when
  dealing with React, Vue, Angular, or Next.js rendered content, dashboards, or any page where
  WebFetch clearly won't work.
source: custom
date_added: "2026-03-22"
effort: low
---

# Lightpanda Headless Browser

Browse the web with full JavaScript execution via Lightpanda, a lightweight headless browser.
DOM + V8 only, no rendering engine. Connected via MCP -- the connection URL is configured in the
MCP server settings, not in this skill.

**Status (March 2026):** browser and MCP are still in beta. The original Go-based MCP server
(`lightpanda-io/gomcp`) was archived March 13, 2026 and replaced by Lightpanda's TypeScript
MCP server (`lightpanda-io/mcp-server`). For tasks requiring rendering, screenshots, or complex
multi-step interactions, use the Playwright MCP server instead.

## When to Use

- **WebFetch returned empty/broken content** from a SPA or JS-rendered page
- **Need to read JavaScript-rendered pages** (dashboards, dynamic docs, SPAs)
- **Extract structured data** (JSON-LD, OpenGraph, Twitter Cards) from any page
- **Run JavaScript** on a page to extract or interact with content
- **Get a semantic tree** of the DOM for efficient analysis

## When NOT to Use

- Static pages that WebFetch handles fine -- try WebFetch first, switch to Lightpanda only if it fails
- API calls, file downloads, or anything that doesn't need JavaScript execution
- Visual testing, screenshots, or CSS layout verification -- use Playwright instead
- Complex multi-step browser interactions (login flows, form wizards) -- use Playwright instead

## Available Tools

All tools are MCP-provided and prefixed `mcp__lightpanda__`. They only exist when the lightpanda MCP server is running. If the tools aren't available, tell the user the MCP server needs to be started.

| Tool | Purpose | When to use |
|------|---------|-------------|
| `goto` | Navigate to URL | Always call first before other tools |
| `markdown` | Page as clean markdown | Reading articles, docs, text content |
| `semantic_tree` | Pruned DOM with ARIA roles | Understanding page structure (token-efficient) |
| `links` | All `<a href>` links | Finding navigation, references, resources |
| `interactive_elements` | Buttons, inputs, forms | Understanding available page actions |
| `structured_data` | JSON-LD, OG tags, meta | Extracting SEO/metadata from pages |
| `evaluate` | Run arbitrary JS | Custom data extraction, page interaction |
| `screenshot_text` | Text-based page summary | Quick overview (not visual -- returns text only) |

## Common Patterns

### Read a JavaScript-rendered page
```
1. goto(url)
2. markdown()
```

### Understand page structure (token-efficient)
```
1. goto(url)
2. semantic_tree(format="text", prune=true)
```

### Extract specific data from a page
```
1. goto(url)
2. evaluate(code="document.querySelector('.price').textContent")
```

### Get all metadata
```
1. goto(url)
2. structured_data()
```

### Scrape multiple pages
```
For each URL:
  1. goto(url)
  2. markdown() or evaluate() for extraction
Note: goto() replaces the current page -- there's no tab/window support.
```

## Limitations

- **No rendering**: no screenshots, no visual testing, no CSS layout, no `getBoundingClientRect()`
- **No media**: no images, audio, video, WebGL, canvas
- **Single page at a time**: `goto()` replaces the current page, no tabs
- **Nightly builds**: some complex SPAs may hit unimplemented Web APIs
- **300s timeout**: connections timeout after 5 minutes of inactivity
- **`networkidle0` wait**: `goto()` waits until no network activity for 500ms before returning -- may hang on pages with persistent connections (WebSockets, SSE, polling)

## Agentic Patterns

### Retry logic for flaky pages
```
1. goto(url) -- if timeout/error:
2.   Wait 2s, retry goto(url) once
3.   If still fails, fall back to WebFetch
4.   If WebFetch also empty, report to user
```

### Multi-page scraping with rate awareness
```
For each URL in batch:
  1. goto(url)
  2. markdown() or evaluate()
  3. Brief pause between pages (Lightpanda has no built-in rate limiting)
Don't scrape > 20 pages without checking with user first.
```

### Auth-gated pages
Lightpanda has no cookie/session persistence between goto() calls. For pages behind auth:
- Use `evaluate()` to inject auth tokens via `document.cookie` or `localStorage`
- Or pass auth headers via the MCP server config (if supported)
- For complex login flows, use **Playwright** instead

## Error Handling

If tools fail with connection errors:
1. The lightpanda MCP server may not be running -- tell the user
2. The browser container may be down -- suggest checking the k8s pod
3. For `goto()` timeouts on pages with persistent connections, try the URL with WebFetch as fallback
4. If `evaluate()` throws, the page JS may use APIs Lightpanda hasn't implemented -- try a simpler extraction or switch to Playwright

## Choosing Between Tools

| Scenario | Use |
|----------|-----|
| Static HTML page | **WebFetch** (faster, no MCP needed) |
| JS-rendered SPA content | **Lightpanda** |
| Visual testing / screenshots | **Playwright** |
| Complex multi-step interactions | **Playwright** |
| Content extraction from dynamic page | **Lightpanda** (lighter than Playwright) |
| WebFetch returned empty/broken | **Lightpanda** (retry with JS execution) |
