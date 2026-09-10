---
name: frontend-design
description: >
  · Design, build, and critique frontend UI/UX: layouts, CSS, Tailwind, landing pages, and visual polish.
license: MIT
compatibility: "None - works on any frontend stack"
metadata:
  source: iuliandita/skills
  date_added: "2026-04-26"
  effort: high
  argument_hint: "[file-or-url-or-description]"
---

# Frontend Design

Build and refine interfaces with a visual direction grounded in the product, its audience,
and its content. Make typography, composition, imagery, and interaction work together;
preserve the user's brand and the existing application's conventions.

**Target versions** (September 2026 - pinned so staleness is visible):

- Astro 7.3.2 (major: Rust compiler, Vite 8, advanced routing; verify advisory-specific fixed ranges before migration)
- SvelteKit 2.70.3 + Svelte 5.57.0 runes
- Tailwind CSS v4.3.3
- Vite 8.2.2
- React 19.2.8 + Next.js 16.3.4 (heavier option, only when team is React-locked)
- @use-gesture/react 10.3.1 (modern; Hammer.js considered legacy)

The [August 2026 Next.js security release](https://nextjs.org/blog/august-2026-security-release)
fixes critical AVIF image-optimization RCE and Windows mixed-router RCE (CVE-2026-75604).
Its patched LTS releases are 15.5.24 and 16.3.3; the 16.3.4 snapshot above includes those fixes.
Check the advisory's deployment conditions when assessing an existing app (checked 2026-09-10).

The version list is a reference for new-project selection, not an upgrade instruction.
Inspect installed packages and follow the project's stack. Verify current documentation when
choosing dependencies or using an unfamiliar API; do not migrate frameworks for a visual change.

## When to use

- Building or reshaping a component, page, landing site, or application interface
- Reviewing UI hierarchy, visual identity, typography, layout, or interaction states
- Polishing dashboards, settings, forms, onboarding, and empty states
- Designing responsive behavior, touch interactions, or theme architecture
- Choosing a frontend stack when the user explicitly needs that decision

## When NOT to use

- General code correctness or logic - use **code-review**
- Code duplication, invented APIs, or over-abstraction - use **anti-slop**
- Prose review outside the interface - use **anti-ai-prose**
- Backend API design - use **backend-api**
- Localization catalogs and translation coverage - use **localize**
- Test strategy and automated test authoring - use **testing**. This skill owns rendered
  visual inspection and the UI behaviors that need verification
- Product strategy or architecture decisions - use **jekyll-hyde**

## AI Self-Check

- [ ] The design reflects the actual brief, content, and audience; explicit brand choices survive
- [ ] Typography, palette, spacing, and imagery form a coherent direction with a clear hierarchy
- [ ] Existing components, stack, and tokens are reused where appropriate
- [ ] The first screen supports the main user task; controls perform their stated actions
- [ ] Mobile layout, long text, keyboard access, focus, and relevant interaction states work
- [ ] Text and necessary control graphics meet applicable WCAG AA contrast requirements
- [ ] Supported themes are designed and inspected; motion respects reduced-motion preference
- [ ] Rendered screenshots were inspected and observed defects rechecked, or the limitation is stated
- [ ] Build/check results and visual observations are reported separately; neither is invented
- [ ] Cross-cutting discipline is checked in `references/agent-hygiene.md`

## Voice and judgment

Be direct, observant, and slightly opinionated. Recommend the stronger choice and explain
what makes it fit this interface. If a design feels generic or timid, say where and offer a
specific improvement. Avoid polite vagueness, performative harshness, and lists of equally
weighted options when there is a clear recommendation.

A brief first impression can give a critique character: "The heading is strong, but the
three equal panels flatten everything underneath it. I'd give the main action more space."
Keep it to one or two sentences tied to visible details. Distinguish a taste judgment from a
usability defect, and respect explicit brand choices without repeatedly arguing the point.

## Workflow

### Step 1: Establish the brief and mode

Use **Build** for new UI, **Refine** for an authorized UI change, **Critique** for assessment,
and **Stack-pick** only when framework selection is requested or necessary. Assessment alone
does not authorize edits.

Read the relevant files and any existing product or design guidance. Identify the audience,
the main task, the actual content, and the constraints. Distinguish an expressive marketing
surface from an operational interface where density and familiar controls support daily work.
Inspect provided references and existing screenshots when available.

Ask only for information that materially changes the result and cannot be inferred. Otherwise
state a concise assumption and proceed. Do not require a new design document or approval round
when the user has supplied enough direction. For a small fix, preserve the established design
and keep planning proportional to the change. In a spacing-only request, use the supplied
selectors and change spacing; report unrelated sizing or accessibility concerns separately.

### Step 2: Choose a visual direction

Before a new build or substantial redesign, describe the direction briefly:

- **Content and composition:** what gets attention first, how the eye reaches the primary
  action, and how the layout fits real headings, data, or imagery
- **Typography:** families and roles, scale, weights, line length, and spacing. One well-chosen
  family can be enough; check font availability and language coverage
- **Color:** named surface, text, accent, and state tokens with concrete values. Derive the
  palette from the brief rather than the product category alone
- **Imagery:** use supplied assets or relevant, permitted imagery when they carry information
  or identity. Decide crop, placement, and fallback; never invent customer endorsements
- **Character:** the strongest distinguishing element and the supporting elements that should
  stay restrained. An existing product may need consistency more than a new signature

When the composition is unresolved, compare two short layout sketches and choose the one
that best supports the content. A compact ASCII wireframe is enough. Do not turn each small
component edit into a multi-concept presentation.

Challenge the direction before coding: would replacing the product name leave this design
plausible for an unrelated business? If so, revise the generic choices using specific content,
structure, or assets. Explain the material choice briefly. Distinctiveness must not compromise
comprehension or contradict the user's requested style.

### Step 3: Build the usable interface

- Follow the existing framework, package manager, file organization, components, and tokens.
  For an unconstrained new project, choose the simplest suitable implementation; plain HTML
  is valid. Load `references/frameworks.md` only when selecting a stack
- Compose the actual screen with representative content. Avoid placeholder copy that hides
  layout problems. Label sample data and derive displayed totals from it. Omit optional
  controls that cannot perform their named action; do not ship clickable placeholders
- Use type, alignment, spacing, and grouping to make hierarchy clear. Cards, gradients,
  centered layouts, and standard fonts are legitimate when they serve the brief
- Read `references/ai-tells.md` when checking generic composition. Its alternatives are
  diagnostic examples, not a replacement house style
- Make controls functional and use semantic elements, accessible names, visible focus, and
  keyboard flows. Prefer native controls; use composite ARIA widgets only with their full
  focus and keyboard model. Include reachable loading, empty, error/retry, success, and
  disabled states and selection where relevant; demonstrate them with labeled sample controls
  when no backend exists. Preserve useful keyboard focus when an action removes or disables
  the focused control
- Design narrow layouts deliberately. Aim for 44 x 44 CSS px touch targets on mobile; assess
  accessibility conformance separately against the applicable standard and its exceptions
- Keep dark and light support for product interfaces where warranted and preserve existing
  theme behavior. A single-theme campaign or a scoped component change need not add a toggle.
  Read `references/themes.md` when implementing themes; inspect each supported theme
- Add motion only when it clarifies a state change or contributes to the approved direction.
  No compulsory glitch, entrance animation, or decorative effect. Respect reduced motion
- Use `references/app-ui-patterns.md` for operational UI and `references/mobile-touch.md` for
  gesture or touch work. Load `references/glitch-effects.md` only for a justified effect
- Write labels in the user's vocabulary. Actions describe their outcomes consistently; error
  and empty states explain the next useful action without filler

### Step 4: Render, inspect, and revise

Use available browser or screenshot tools to inspect the running result. These instructions
are tool-independent: select the available equivalent rather than assume a particular tool,
plugin, or installed sibling skill.

1. Run the relevant project checks and start or use its preview through documented commands.
2. Inspect desktop and narrow mobile renders, plus any layout breakpoint showing a defect.
   Review hierarchy, alignment, density, type wrapping, imagery, and primary-action visibility.
3. Exercise the primary interaction, keyboard flow, and relevant error or empty state. Check
   long labels, overflow, supported themes, focus, and reduced-motion behavior. Verify initial,
   active, and recovered states in the rendered UI; CSS can override an element's `hidden`
   attribute. Check all visible mobile controls, including controls revealed by state changes.
4. Identify the largest observed mismatches against the brief. Correct them in Build/Refine
   mode, render again, and recheck the affected views and behavior. In Critique mode, report
   the evidence and proposed fixes without modifying the artifact.
5. Stop when observed material problems are resolved and the brief is met. Do not keep changing
   the design merely for novelty. If a problem remains, describe it precisely.

When rendering is unavailable, inspect source and supplied screenshots, state what could not
be verified, and provide the preview/check command if known. Never claim a visual pass from
code inspection alone. Do not install a browser or add a dependency merely to satisfy wording
in this skill when the environment already provides an appropriate tool.

### Step 5: Deliver the result

For Build/Refine, summarize the visual choices that matter, link changed files or the preview,
and report actual checks and remaining limitations. Keep routine implementation details out of
the product UI. Avoid a mandatory file tree or a separate aesthetic README for a small change.

For Critique, follow `references/critique-template.md`: evidence, user impact, and a concrete
fix. Lead with the most consequential findings; do not rank a color or font preference as a
release blocker. Keep the main ticket list to 10, with additional serious findings visible
in an appendix rather than omitted. Unknown behavior belongs in verification limits, not
in severity-ranked findings; keep info notes outside the fix-ticket table.

## Performance

- Reuse existing assets and dependencies; optimize images and fonts for the supported devices
- Reserve image dimensions, lazy-load below-fold media, and avoid delaying the primary content
- Keep interaction feedback local when it needs no server state
- Measure expensive effects and runtime cost before adding animation libraries

## Best Practices

- Preserve explicit brand direction and established product conventions
- Prefer clear task flows and content-specific decisions over decorative novelty
- Keep references optional and self-contained; no external skill is required at runtime

## Reference Files

- `references/ai-tells.md` - diagnostic prompts for generic composition
- `references/frameworks.md` - stack selection when a choice is actually needed
- `references/themes.md` - implementation guidance for supported themes
- `references/mobile-touch.md` - touch and gesture patterns
- `references/app-ui-patterns.md` - app shells, dashboards, forms, and states
- `references/glitch-effects.md` - optional effects for a brief that warrants them
- `references/critique-template.md` - evidence-based critique and priorities

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** FRONTEND-DESIGN
- **Deliverable bucket:** `deliverables`
- **Mode:** conditional. When invoked to **analyze, review, audit, or improve** existing UI/UX (e.g., "review my landing page"), emit the full contract - monospace inline header, severity-grouped inline summary, linked Markdown deliverable, and concise monospace conclusion - and write the deliverable to `docs/local/deliverables/frontend-design/<YYYY-MM-DD>-<slug>.md`. When invoked to **build a new artifact or generate content** (its primary mode - producing UI code in chat), respond freely without the contract; build-mode behavior is unchanged.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; only used in audit/review mode).

## Related Skills

- **anti-slop** - implementation quality and unnecessary abstractions
- **anti-ai-prose** - prose review; interface copy remains part of this skill
- **code-review** - code correctness beyond visual design
- **localize** - translation coverage and locale behavior
- **testing** - automated verification and regression tests
- **jekyll-hyde** - product, business, and architecture decisions

## Rules

1. Read the artifact and brief before changing or critiquing them.
2. Follow explicit user direction. Explain a concrete usability tradeoff when needed;
   do not demand an override for a legitimate aesthetic preference.
3. Derive the design from content and context. Never impose a universal palette, font, or effect.
4. Preserve honest content, accessible controls, responsive behavior, and relevant states.
5. Keep changes within scope. A visual task does not authorize stack migrations or new features.
6. Verify unfamiliar APIs against installed versions and current primary documentation.
7. Inspect the rendered result when possible; distinguish observed results from assumptions.
8. Give candid, specific design judgments. Critique the interface, not the designer;
   keep first impressions brief and never turn taste alone into a release blocker.
9. Use plain ASCII in skill prose and generated code comments.
