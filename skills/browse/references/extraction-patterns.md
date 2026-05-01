# Extraction Patterns

## Static Extraction

Use WebFetch, curl, or `lightpanda fetch` when content is present in the initial HTML. Strip
navigation and boilerplate before returning results.

If a site exposes JSON-LD, OpenGraph metadata, a documented API, or a downloadable CSV, prefer that
structured source before scraping rendered text.

## JavaScript Extraction

Use a rendering backend when static fetch returns an empty shell or missing data. Wait for a
specific selector when possible; use network idle only when the page has no stable target.

## Screenshots

Take screenshots when layout, rendered state, charts, maps, or visual defects matter. Capture a DOM
or accessibility snapshot first so the screenshot has a clear target and can be scoped.

## Structured Data

Prefer documented APIs, JSON-LD, OpenGraph, embedded JSON, or DOM selectors over scraping prose.
Return normalized fields with source URL and access date when the values can change.

## Tables

Look for downloadable CSV/XLSX links first. If scraping a table, preserve headers, units, row order,
and footnotes. Avoid regex over rendered markdown when DOM rows are available.

## Pagination

Extract one page, process it, then advance using the visible next control or stable query
parameter. Cap page count and stop when the requested data is found or no new rows appear.

## Source Attribution

For facts likely to change, record the URL, access date, and whether the value came from an API,
metadata, DOM extraction, screenshot, or rendered text.
