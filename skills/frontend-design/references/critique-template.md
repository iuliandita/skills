# Critique Template: Rant -> Filter -> Ticket

Adversarial UX review with the persona's voice on the front end and clean tickets on the back. The rant captures honest reactions; the filter strips taste-only items; the tickets are what the team can act on.

Cap tickets at 10. Discipline matters more than completeness. The team will fix the top issues; the rest is noise.

---

## Phase 1: Rant

The rant is the persona's first reading. Honest, opinionated, in-character. Captured in full so nothing valuable gets lost in over-eager filtering.

**Format.** Free prose. Numbered or bulleted is fine. No structure required.

**What goes in.**

- First impressions ("hero looks like every shadcn template I've seen this month")
- Specific anti-patterns spotted by name (refer to `references/ai-tells.md`)
- Accessibility violations (contrast, focus, target size)
- Mobile-specific problems
- Inconsistencies (border-radius scale, spacing, type weight)
- Things that work and shouldn't be lost in a fix
- Personal taste reactions (these get filtered later)

**Length.** No fixed limit. 200-600 words for a typical UI.

**Sample (for a hypothetical SaaS landing page):**

> Centered hero with the "Build [verb] [adverb]." formula. Two buttons, one solid indigo, one ghost. Below it, a tilted browser frame holding a stock dashboard screenshot. This is the literal default Vercel template. There is no reason it had to be this; it just was.
>
> Three-column features section. Lucide icon, 4-word heading, 12-word description. Repeated. The icons are decorative; they don't add information. The headings are so vague they could describe any product.
>
> Color palette: indigo accent (Tailwind default `indigo-600`), purple-pink gradient on the hero CTA, gray cards. The accent is unmodified default. The gradient is the AI-product gradient. Together they say "we shipped before we picked a brand".
>
> Typography: Inter on everything. Same weight on h1, h2, body. No display font. No personality. Could be any product.
>
> Mobile: actually decent layout, but tap targets on the nav are 32 px. Footer links are 28 px. Trying to hit them while walking is going to fail.
>
> Glass-morphism on the testimonial cards over a flat background. The blur is doing nothing because there's nothing behind to blur. It's just opacity-with-extra-steps.
>
> Light theme only. No dark theme toggle. The marketing site is at least consistent here, but the app behind it had better have one.
>
> Things that are good: the type scale uses `clamp()` for fluid sizing. The footer is left-aligned with proper hierarchy. The CTA copy is specific ("Start your free trial - no card required") not generic ("Get started").

---

## Phase 2: Filter

The filter strips the rant down to prioritized tickets and notes. Five categories, each with a rule.

| Priority | Rule |
|---|---|
| **P0** - must fix | Blocks use, breaks the UI, or creates a severe accessibility failure |
| **P1** - should fix | Significant UX/design/brand issue that should be fixed before release |
| **P2** - fix if cheap | Edge case or stylistic. Worth flagging, not worth blocking |
| **P3** - backlog | Non-urgent polish worth tracking, not blocking |
| **info** - no fix | Positive pattern to preserve, out-of-scope item, personal taste, or hypothetical |

**Filter pass.** For each rant item, assign a priority. `info` items can be surfaced as notes but do not become fix tickets.

**Example mapping (from the rant above):**

| Rant item | Priority | Reasoning |
|---|---|---|
| Centered-hero-with-two-buttons template | P1 | Erodes brand - looks like every other AI product |
| Three-column features section | P1 | Same template-ness; primary above-fold real estate |
| Tailwind default indigo | P1 | Unmodified default = "shipped before picking brand" |
| Purple-pink gradient on CTA | P1 | AI-product tell, accessibility variable |
| Inter on everything, same weight | P2 | Not breaking anything but no personality |
| Mobile tap targets 28-32 px on footer/nav | P1 | WCAG 2.5.5 violation; should fix before release |
| Glass-morphism without blur subject | P2 | Pattern misuse; not breaking |
| No dark theme toggle on marketing | info | Marketing site is light-themed deliberately; not in scope |
| `clamp()` fluid type | info | Working pattern; surface so it propagates without creating a fix ticket |
| Specific CTA copy | info | Working pattern; surface so it propagates without creating a fix ticket |

---

## Phase 3: Tickets

What the team sees. Clean, actionable, priority-tagged. Max 10. P0/P1 ship; P2 ships if there is room. P3 items sit in a deferred backlog section after the table. Info notes sit outside the ticket table.

**Format.** Markdown table.

```markdown
| ID | Priority | Pattern | Where | Fix |
|----|----------|---------|-------|-----|
| 01 | P1 | centered-hero-with-two-buttons | hero section | Replace centered layout with off-center grid; one CTA, no tilted browser frame; consider live demo or static screenshot at full opacity |
| 02 | P1 | three-column features section | below hero | Replace with one feature shown working (loop or annotated screenshot). Three-column features are a generic template marker |
| 03 | P1 | Tailwind default indigo as accent | hero CTA, links | Override `--color-accent` in theme. Pick one brand color and commit. Suggested: warm orange `#d97706` or muted lime - move away from indigo |
| 04 | P1 | purple-pink gradient on CTA | hero CTA button | Replace with solid accent. Gradient on hover only, or two-stop in analogous colors |
| 05 | P1 | mobile tap targets below 44 px | footer links, nav | Add `min-height: 44px` to interactive elements; use pseudo-element padding for visually small icons |
| 06 | P2 | Inter on every text, no weight contrast | typography | Pair Inter with a distinctive display font for headings; introduce 300/700 weight contrast |
| 07 | P2 | glass-morphism without spatial reason | testimonial cards | Replace with solid panels or remove entirely; reserve blur for layered surfaces |
```

Optional info notes outside the ticket cap:

- `clamp()` fluid type is working well; keep it as the convention for the rest of the site.
- Specific CTA copy ("Start free trial - no card required") is stronger than generic CTA language.

Deferred backlog (P3):

- Low-priority polish that should be tracked but not fixed in this pass.

**Cap rules.**

- Hard cap at 10 tickets total
- P0/P1 priority
- If P0 count > 8, drop P2/P3 rows entirely
- If P0 + P1 > 10, surface the most actionable; the rest goes in a "deferred" appendix
- P3 never blocks shipping; list it only in the deferred backlog

---

## Output structure for the user

```markdown
## Critique: [Site / component / page name]

### Rant

[Persona voice, 200-600 words]

### Tickets

[Table with up to 10 entries]

### Deferred

[Anything that didn't make the cut, listed as one-liners]

### Notes

[Optional info items: positive patterns to preserve, scoped-out observations, or no-fix context]
```

The rant is the persona's voice; the tickets are what the team will track. Deferred items
are backlog. Notes are optional context, not required work. All sections can ship when non-empty.

---

## What NOT to do in critique

1. **Ship the rant as tickets.** Tickets need to be actionable; rants are reactions.
2. **Pad the table with info-tier items.** A 30-row table with 25 trivial nits trains the team to ignore tickets.
3. **Blame instead of fix.** "Whoever designed this didn't think about mobile" is unhelpful. "Mobile tap targets violate WCAG 2.5.5; fix with min-height: 44px" is.
4. **Use jargon without referencing.** When you call something "card-grid-of-nothing", link or refer to `references/ai-tells.md` so the team knows what the term means.
5. **Turn positive info into fix tickets.** Surface good patterns as concise notes when useful; do not make them required work.
6. **Critique without a target.** If the user paste isn't enough to assess, ask for the missing piece (live URL, mobile screenshot, code) instead of guessing.
