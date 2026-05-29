# App UI Patterns

Patterns for logged-in tools and operational interfaces, where the job is user work, not marketing
composition. Read this before building an app shell, dashboard, form, settings page, onboarding
flow, or empty state. The rule under all of them: optimize for the user's task, not for a
screenshot.

## App Shells

The shell is the persistent frame around changing content: navigation, page title, primary action,
and a content region.

- Keep navigation in one place and stable across routes. Sidebar for many top-level areas (roughly
  6+), top bar for few. Do not move or reorder nav items between pages.
- Reserve a single, predictable slot for the primary action (top-right of the content header is the
  common home). One primary action per view; everything else is secondary or in a menu.
- Constrain reading and form content to roughly 60-80ch; let tables and canvases use full width.
- Give every route a visible page title that matches the nav label and the document title.
- On mobile, collapse the sidebar to a drawer or bottom nav. Do not hide the primary action behind
  a hamburger.
- Anti-pattern: a marketing hero, centered headline, or "Build X faster" band inside a logged-in
  tool. The shell is chrome, not a pitch.

## Dashboards

A dashboard exists to answer "is anything wrong, and what changed" at a glance.

- Lead with the few metrics that drive a decision, top-left, largest. Do not open with three
  equal-weight stat cards by reflex (that is the AI-dashboard tell).
- Pair every metric with context: a delta, a trend sparkline, or a comparison period. A bare number
  is noise.
- Show data freshness ("updated 2m ago") near the data, and a real empty state when there is no
  data yet.
- Provide filtering and a drill-down path from each summary to its underlying rows.
- Put time-series and comparisons where scanning is natural (left-to-right, top-to-bottom); keep
  related metrics adjacent.
- Anti-pattern: auto-generated stat-cards + line-chart + activity-table layout when the product is
  not actually a dashboard.

## Forms

Forms are where data quality and user trust are won or lost.

- One column. Top-aligned labels (never placeholder-as-label; placeholders vanish on input and fail
  accessibility).
- Group related fields with headings; order fields the way the user thinks about the task, not the
  way the database stores it.
- Validate inline on blur, not only on submit. Show the error next to the field, in text plus color
  (never color alone), and keep the field's value.
- Preserve all input on a server error; never clear a form the user spent two minutes filling.
- Disable and show a loading state on the submit button during the request; prevent double-submit.
- Mark required vs. optional explicitly and consistently. Keep the submit action visible without a
  scroll on long forms (sticky footer on mobile).
- Anti-pattern: a wall of fields with no grouping, validation only on submit, and a reset that wipes
  user work.

## Settings

Settings is a reference surface, not a wizard. People arrive to change one thing.

- Group by the user's mental model (Account, Notifications, Billing, Security), not by data table.
  Use sections or sub-pages once it exceeds one screen.
- Separate read-only account facts (plan, user ID, joined date) from editable preferences so people
  do not hunt for the editable control.
- Make each change's save scope obvious: per-field autosave with confirmation, or an explicit Save
  per section. Do not mix silently.
- Put destructive actions (delete account, revoke keys, leave team) in a clearly separated "danger"
  area, styled distinctly, with a confirmation that requires intent (type-to-confirm for the worst
  ones).
- Anti-pattern: one giant ungrouped list, or a destructive button sitting inline next to a benign
  toggle with the same styling.

## Onboarding

Onboarding should get the user to their first real success, then get out of the way.

- Drive toward the first meaningful action (create the first project, connect the first source), not
  a tour of buttons whose purpose is self-evident.
- Prefer inline, contextual hints and a short checklist over a modal carousel. Always offer a skip,
  and never block the product behind it.
- Pre-fill and use sensible defaults so the first success needs the fewest decisions.
- Show progress honestly ("2 of 3") and let users leave and resume; persist partial state.
- Anti-pattern: a multi-slide modal on first load that explains the obvious, with no skip and no
  resumable state.

## Empty States

An empty state is a designed screen, not a blank region. It is often the user's first impression of
a feature.

- State three things: what is empty, why it matters here, and the single next action (a real button,
  not just text).
- Distinguish first-run empty (never any data: teach + primary action) from filtered empty (data
  exists but none matches: offer "clear filters") from error empty (load failed: offer retry). They
  are different screens.
- Keep it lightweight: one short line plus the action. Optional small illustration; skip stock
  blobby figures.
- Anti-pattern: a decorative card grid of placeholder skeletons left visible, or a cheerful
  illustration with no action to take.
