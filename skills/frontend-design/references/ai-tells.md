# AI Design Tells: The Catalogue

Use this catalogue to question unexamined defaults, not to ban visual styles. A pattern is a
problem when it obscures the task, conflicts with the brief, or substitutes generic decoration
for meaningful content. Explicit user direction and existing brand conventions take precedence.

Each entry offers a possible alternative. Test whether it fits the actual content; do not apply
all replacements together as a new template. Cream-and-serif editorial pages, neon-on-black
technical pages, and border-heavy asymmetry can become defaults too. Keep a pattern when it
serves the brief and works well. A familiar font, palette, or layout is not itself a defect.

---

## Layout Tells

### 1. Card-grid-of-nothing

**Tell.** Every block of content boxed in a rounded panel with `border-radius: 16px`, a subtle shadow, and `padding: 24px`. Three or four cards in a row. Often `bg-white/5` or `bg-zinc-900/50` on dark backgrounds.

**Why.** Cards are a navigational pattern - they suggest each one leads somewhere. When the cards don't lead anywhere (they're just paragraphs in a box), the user pays a visual tax for nothing.

**Replacement.** Use type hierarchy and spacing. A bold label, a paragraph, and a thin rule between sections beats four cards with the same content.

```html
<!-- Before: card-grid-of-nothing -->
<div class="grid grid-cols-3 gap-6">
  <div class="rounded-2xl bg-zinc-900/50 p-6 shadow-sm">
    <h3>Fast</h3>
    <p>Built with performance in mind.</p>
  </div>
  <!-- two more identical cards -->
</div>

<!-- After: type + spacing carry the load -->
<section class="space-y-12">
  <article>
    <h3 class="text-xl font-semibold">Fast</h3>
    <p class="mt-2 max-w-prose text-zinc-400">Built with performance in mind.</p>
  </article>
  <!-- two more, separated by space, not boxes -->
</section>
```

### 2. Three-column features section

**Tell.** Icon + heading + 12-word description, repeated three times in a grid. Almost always the second section after the hero.

**Why.** Repeated generic claims can hide what the product actually does. A grid is useful when the items genuinely need comparison.

**Replacement.** One feature, shown working. A loop of the actual product, or a single annotated screenshot, beats nine words about three abstract benefits.

### 3. Centered hero with two buttons

**Tell.** Centered headline ("Build [noun] [adverb]."), centered subheading, two buttons (one primary solid, one ghost), then a tilted browser-frame screenshot. Often gradient background.

**Why.** This combination can appear without regard for the content. Check whether both actions and the screenshot help the audience understand the product.

**Replacement.** Let the content determine alignment and the number of actions. A real screenshot or live demo may explain the product; a centered headline may be right for a short, focused message.

### 4. Auto-dashboard

**Tell.** Three stat cards with up-arrow deltas, a line chart, a recent-activity table. Used as a feature when the product is not actually a dashboard.

**Why.** Dashboards are noise unless the user is monitoring something. Showing a fake one in a marketing screenshot is filler.

**Replacement.** Show the actual UI of the actual product. If the product is a CLI, show the terminal. If it's a writing tool, show the editor.

### 5. Centered everything

**Tell.** Every section, every card, every paragraph centered. Buttons centered.

**Why.** Center alignment is the default when you don't have a reason. Everything feels weightless and floats.

**Replacement.** Left-align body text. Off-center hero. Mix center and left for rhythm. Asymmetry is information.

---

## Color Tells

### 6. Purple-pink (or blue-purple) gradients

**Tell.** `from-indigo-500 to-pink-500`, `from-blue-600 via-purple-600 to-pink-500`, etc. On hero backgrounds, on CTAs, in icon fills.

**Why.** Tailwind's docs use it, every shadcn template uses it, every AI product uses it. You will look like every AI product.

**Replacement.** A single accent color. Pick one and commit. Gradient on hover only, or as a 3-stop transition between two analogous colors (e.g., teal-to-mint), not the rainbow tour.

### 7. Pastel-on-white "soft" palette

**Tell.** Off-white background, pastel-blue and pastel-pink accents, friendly rounded type. Feels like every empathetic-AI startup.

**Why.** It's the literal default of the "warm UI" trend. Indistinguishable across products.

**Replacement.** Choose surface, text, accent, and state roles from the brand and content. Keep a soft palette when it fits; verify contrast and avoid substituting another category-based palette by reflex.

### 8. Tailwind default indigo as accent

**Tell.** `bg-indigo-600`, `text-indigo-500`. The unmodified default.

**Why.** It's the unmodified default. It says "I shipped before I picked a color."

**Replacement.** Override `--color-accent` in theme. Pick something - lime, rust, slate, magenta - and use it consistently.

### 9. Gradient text on h1

**Tell.** `bg-clip-text text-transparent bg-gradient-to-r from-indigo-500 to-pink-500` on h1.

**Why.** Same purple-pink problem, plus illegibility on busy backgrounds, plus poor contrast checking.

**Replacement.** Check hierarchy and contrast first. A solid treatment may be clearer; do not automatically accent one word as a substitute. Keep a requested gradient when text remains legible across it.

---

## Surface Tells

### 10. Glass-morphism (frosted glass)

**Tell.** `backdrop-blur-md bg-white/10`. Applied as a default panel style without anything behind it that would benefit from blur.

**Why.** Blur is a depth cue. Used without depth, it's just opacity-with-extra-steps.

**Replacement.** Use solid panels. Reserve blur for actual layers - sticky nav over scrolling content, modal over a real backdrop.

### 11. Uniform `rounded-2xl`

**Tell.** Every element - button, card, input, image, badge, avatar - has the same large corner radius.

**Why.** Lazy. Different elements warrant different radii. A button and an avatar are not the same thing.

**Replacement.** Tier the radii: `--radius-sm` (4px) for inputs and small buttons, `--radius-md` (8px) for cards, `--radius-full` for avatars and pill badges. Or use square corners and earn the geometric look.

### 12. AI shimmer on non-AI features

**Tell.** Loading state with a sweeping rainbow gradient or sparkle animation, regardless of whether AI is involved.

**Why.** An elaborate loading effect can distract or imply behavior the surrounding copy does not support. Animation alone does not establish whether a feature uses AI.

**Replacement.** Match feedback to the wait: skeleton for a known content shape, spinner for unknown duration, progress bar for measurable progress. Keep descriptions accurate and motion restrained.

### 12.5. shadcn default stack

**Tell.** Every app becomes the same default shadcn cards, muted text, tables, and dropdowns with no
domain-specific hierarchy.

**Why.** shadcn is a component starting point, not a product direction. Unedited defaults make
operations tools feel interchangeable.

**Replacement.** Keep the accessible primitives, then redesign hierarchy, density, spacing, and
state treatment around the actual domain.

---

## Iconography Tells

### 13. Lucide / Heroicons stroke icons everywhere

**Tell.** Same 24px stroke icon next to every list item, every stat, every nav entry. Defaults to Lucide.

**Why.** Stroke icons are designed to be neutral. Used everywhere, they make the entire UI feel neutral - i.e., generic.

**Replacement.** Use icons sparingly, where they replace words. Use a different family if the brand is technical (pixel icons, custom glyphs, monospace symbols). Don't add an icon to every label.

### 14. Emoji as section markers

**Tell.** 🚀 on the speed section, ⚡ on performance, ✨ on AI features, 🎨 on design.

**Why.** Cute on a personal blog. In product UI, it's a tell that someone ran out of ideas.

**Replacement.** Use clear headings. Add a meaningful icon only when it aids scanning; number sections only when sequence or reference matters.

### 15. Stock 3D blobby figures

**Tell.** Memphis-style shapes, Notion-illustrations-clone, Lordicon, Storyset. Cartoon figures floating on white.

**Why.** Recognizable across hundreds of products. Stock illustrations age in months.

**Replacement.** Photographs (real ones), commissioned illustration, abstract geometric, or no illustration at all. Empty space + good type beats stock art.

---

## Trust Tells

### 16. "Trusted by" logo row with no relationship

**Tell.** Grayscale logos of companies the product is not partnered with - "as seen in TechCrunch" without an article, customer logos that aren't customers.

**Why.** Dishonest. Users learn to distrust grayscale logo rows generally.

**Replacement.** Real testimonials with real names. Real customer count. Or no social proof until you have it.

### 17. Centered testimonial cards with avatar + quote

**Tell.** Three centered cards, headshot circle, italic pull-quote, name in bold, role in gray. Identical across SaaS sites.

**Why.** Same template-ness as the cards problem.

**Replacement.** One testimonial, full width, with a real photograph (not a circle crop), unedited quote with linebreaks the speaker used, and a link to the source if it was public.

---

## Behavior Tells

### 18. Modal-on-load

**Tell.** Newsletter signup, cookie consent, "we use AI now" announcement - opens within 2 seconds of page load.

**Why.** It's the worst place to put it. The user came for the content, not your modal.

**Replacement.** Inline newsletter signup at the bottom of the article. Cookie consent as a sticky strip (CMP if regulated), not a modal. Announcements as a thin banner with one-click dismiss.

### 19. Toast for things that should be inline

**Tell.** "Settings saved" appears as a toast in the corner, while the user is looking at the form.

**Why.** Toasts are for events without a place. Settings have a place - the form.

**Replacement.** Inline "saved" indicator next to the field or form heading. Toast only for events that happen outside the user's current context.

### 20. Confetti on routine actions

**Tell.** Confetti, balloons, sparkles when the user saves a record, signs up, completes a form.

**Why.** Saving is not an achievement. Celebrating routine actions trains users to ignore celebrations.

**Replacement.** Confetti for genuinely rare wins (first time a milestone is reached). Plain success state for everything else.

### 21. Auto-playing video hero

**Tell.** Looping video background under the hero text, playing on load, no controls.

**Why.** Bandwidth tax, attention tax, and on mobile, it's often blocked anyway.

**Replacement.** Static hero image (AVIF, optimized) or a live demo of the product. If video is required, autoplay muted with a visible play/pause control.

---

## Typography Tells

### 22. Inter / Geist / Space Grotesk on every product

**Tell.** The same font treatment is reused without considering the content, language support, or existing brand.

**Why.** Font selection alone does not establish hierarchy. A familiar family can work well with deliberate size, weight, spacing, and line length.

**Replacement.** Define text roles and test them with real copy. Keep an existing brand family; add another only when it contributes a necessary distinction. Check availability, loading cost, and glyph coverage.

### 23. Same weight everywhere

**Tell.** All text is `font-medium` or `font-normal`. No weight contrast.

**Why.** Hierarchy disappears. Everything reads at the same level.

**Replacement.** Use weight as a primary hierarchy tool. Light + bold contrast (300 vs 700) beats different sizes alone.

### 24. Centered short paragraphs

**Tell.** Body paragraphs centered. Often justified in marketing copy.

**Why.** Centered prose breaks reading rhythm; eyes lose the start of each line.

**Replacement.** Left-align prose. Cap line length at ~65 characters with `max-w-prose` or `max-width: 65ch`.

---

## Critique mode: establish impact

Describe the visible problem, where it occurs, and how it affects the user's task or the brief.
Pattern names may help explain a finding, but they are not evidence of failure by themselves.
Do not make a release-blocking ticket solely because a design uses indigo, cards, or a standard
font. Keep successful conventions and separate optional aesthetic alternatives from defects.

## Build mode: respect direction

Follow legitimate style requests without requiring the user to overrule this catalogue.
Explain a specific accessibility or usability tradeoff when one exists, then solve it while
preserving the requested direction where possible. Never fabricate endorsements, customer
relationships, or product capabilities. Correct misleading content without treating a visual
style or animation as inherently dishonest.
