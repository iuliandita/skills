# Framework Picker

Pinned to April 2026. Update versions when refreshing the skill. Hallucinating "Next.js 15" or "Astro 5" in build output is the fastest way to embarrass an AI build.

The persona's bias: minimalist first. Reach for a heavier framework only when the minimalist option starts producing inline code soup.

---

## Decision tree

1. **No-build, single HTML file demo, codepen-style?** -> Plain HTML + CSS + JS, no framework. State the constraint at the top of the file.
2. **Static content, marketing site, blog, docs?** -> **Astro 6.1.9** (or **Astro 5.17** if Astro 6 hasn't shipped a feature you need)
3. **Interactive app, bundle size matters, you want runes?** -> **SvelteKit 2.58** + Svelte 5
4. **Small app, no SSR needed, want Vite directly?** -> **Vite 8.0** + plain TypeScript or a thin layer (Lit, Solid, vanilla)
5. **Team is React-locked or you genuinely need React's ecosystem?** -> **Next.js 16** + **React 19.2**

The persona pushes back on Next.js as a default. It's a fine framework; it is also the heaviest option in the list and gets reached for reflexively. If the answer to "why Next" is "because everyone uses it", that's not a reason.

React/Next is appropriate when the product or team is React-locked; otherwise choose lighter stacks
when they fit.

---

## Astro 6.1.9 (Cloudflare-owned since January 16, 2026)

**When.** Content-heavy: marketing pages, docs, blogs, portfolios, landing sites, hybrid sites with islands of interactivity.

**Why.** Server-renders by default, ships zero JS unless you opt in (islands). Excellent integrations (Tailwind, MDX, Cloudflare). Fast.

**Strengths.**

- Component model with `.astro` files - HTML-first, JS optional
- Islands architecture - hydrate Svelte / React / Vue / Solid components only where needed
- Built-in image optimization (`astro:assets`)
- Server actions for forms
- Astro 6 dev server runs on `workerd` (Cloudflare's open-source Workers runtime), so local dev matches production
- Live Content Collections, stable CSP API, Node 22+ minimum

**When NOT.**

- Highly interactive single-page apps (use SvelteKit or Next)
- App with heavy client state across many routes (use SvelteKit)

**Note.** Astro 5.17 (January 29, 2026) is the latest 5.x and remains production-ready. Astro 6 stable shipped in March 2026 after the Astro team joined Cloudflare; the framework stays MIT-licensed and open-governed. Pick 5 if you don't need Astro 6's new features (workerd dev server, Live Content Collections stable, CSP API stable) or if you're still on Node 18/20.

```bash
# Bun-first (preferred per repo convention)
bun create astro@latest
```

---

## SvelteKit 2.58 + Svelte 5

**When.** Interactive apps where bundle size and runtime cost matter. Apps where the team wants explicit reactivity.

**Why.** Smallest runtime in the meta-framework field (~1.6 KB vs React's 40 KB). Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`) replace the implicit reactivity of Svelte 4 with explicit primitives that work in `.svelte` files and plain `.svelte.ts` files.

**Strengths.**

- Tiny output bundles
- Runes are honest about reactivity (no compiler magic guessing)
- `+page.svelte` / `+page.server.ts` route convention
- First-class form actions, no client-side fetcher boilerplate

**When NOT.**

- Pure static content sites (Astro is lighter)
- Team has no Svelte experience and a tight deadline (the runes shift is non-trivial)

**Required Svelte 5 syntax.** Don't ship Svelte 4 stores in new code:

```svelte
<script lang="ts">
  let count = $state(0);
  let doubled = $derived(count * 2);

  $effect(() => {
    console.log(`count is ${count}`);
  });
</script>
```

`writable` / `readable` stores still work; new code prefers runes.

```bash
bun create svelte@latest
```

---

## Vite 8.0 + plain TS

**When.** Small apps, demos, tools where you want a build but no framework opinions. Single-page tools, internal dashboards with one or two views.

**Why.** Vite is a build tool, not a framework. You bring your own structure. Pair with:

- **Lit** (~5 KB) for web components with reactive properties
- **Solid** for fine-grained reactivity in JSX without React's overhead
- Plain DOM + Pointer Events + CSS for the smallest possible footprint

**Strengths.**

- No framework lock-in
- Hot module reload, fast cold starts
- TypeScript first-class

**When NOT.**

- Multi-route apps (use SvelteKit or Astro)
- SSR / SEO matters (use Astro or SvelteKit)

```bash
bun create vite@latest
```

---

## Next.js 16 + React 19.2

**When.** Team is React-locked, ecosystem dependencies (specific React libraries with no equivalent), or app needs Server Components and Server Actions for a specific reason.

**Why.** It works. It has the largest ecosystem. It's the default when "the team already knows React" outweighs everything else.

**Strengths.**

- Turbopack stable (default bundler in Next 16) - dev startup ~50% faster
- React Server Components, Server Actions; React 19.2 features (View Transitions, useEffectEvent, Activity)
- Cache Components with Partial Pre-Rendering and the `"use cache"` directive
- Largest ecosystem of components, hooks, libraries
- Vercel-tier hosting integration

**When NOT.**

- "Because everyone uses it" - not a reason
- Static content site (Astro is faster, ships less JS)
- You want explicit reactivity (Svelte 5 runes are clearer)
- Bundle size matters (Next is the heaviest in this list)

**Note.** Next.js 15 is still maintained but Next.js 16 stable shipped October 21, 2025; 16.2 (March 18, 2026) is the latest. Use 16 for new projects. Middleware was renamed to `proxy.ts` in 16 to clarify the network boundary.

The persona's pushback when Next is suggested as default: "Why Next over Astro for a marketing site, or SvelteKit for an app? If the answer is 'we always use Next', the answer is wrong."

```bash
bun create next-app@latest
```

---

## Styling: Tailwind v4 by default

**Tailwind CSS v4.2.4** (April 21, 2026) is the default styling layer.

**Why this version matters.** v4 rewrote the engine (Oxide, with Lightning CSS for parsing), 5x faster full builds and 100x+ faster incremental builds, CSS-first config (no `tailwind.config.js`). The 4.2 release added the `@tailwindcss/webpack` package, four new palettes (mauve, olive, mist, taupe), expanded logical property utilities, and a 3.8x recompilation speedup.

```css
/* CSS-first config in v4 */
@import "tailwindcss";

@theme {
  --color-accent: #ff6b00;
  --font-sans: "Inter Variable", system-ui;
}
```

**When NOT Tailwind.**

- Type-safe CSS-in-TS required -> **vanilla-extract**
- Component-scoped CSS without utility classes -> **CSS Modules** or Svelte's built-in `<style>` blocks
- Plain CSS with custom properties -> entirely fine, especially for small projects

The persona doesn't ship Bootstrap, Bulma, or any utility framework that isn't Tailwind. Those are not "wrong" but they're outdated relative to what Tailwind v4 does now.

---

## Animation

- **Plain CSS** - first choice. Transitions, keyframes, `animation-timeline: scroll()` for scroll-driven animations (Baseline 2024)
- **View Transitions API** - cross-document transitions, supported in modern Chromium and Safari 18+. Use for route changes
- **Motion** (formerly Framer Motion) - when you need physics-based gestures or complex orchestration in React. Heavier; only when CSS isn't enough

**Avoid.** GSAP for simple cases (it's overkill), Lottie for icon animations (use SVG with CSS), `tsparticles` (the moment you need a particle system, ask whether the page should have one).

---

## Touch and gestures

- **Pointer Events API** - native, supported everywhere. First choice for swipe, drag, pinch detection
- **CSS scroll-snap** - swipe carousels with zero JS
- **`@use-gesture/react`** - when in React and you need rich gesture coordination (drag-to-dismiss, pinch-to-zoom, multi-touch). Hook-based, modern API
- **`@use-gesture/vanilla`** - same library without React

**Hammer.js is legacy.** It works, it has gesture recognition, but it's larger, instance-managed, and predates Pointer Events. Don't introduce it to new projects.

See `references/mobile-touch.md` for patterns.

---

## Modern reset

Don't ship without one. Options:

- **Josh Comeau's reset** - opinionated, well-explained
- **Andy Bell's modern reset** - minimal, opinionated about defaults
- Hand-rolled - fine if you understand each rule

Tailwind v4 includes Preflight (its own reset). Don't double-stack resets.

---

## Build verification before shipping

Before declaring a build done:

```bash
# Astro
bun run astro check
bun run build

# SvelteKit
bun run check
bun run build

# Next.js (next lint was removed in Next 16; run ESLint or Biome directly)
bunx eslint .
bun run build

# Vite
bun run build
```

If the build fails, ship the fix, not the failure. AI builds love to ship code that "should work".

---

## What NOT to suggest

- **Create React App** - deprecated, replaced by Vite + React or Next
- **Gatsby** - Astro replaced its niche; not actively recommended
- **Vue 2** - end-of-life since December 2023
- **Angular** - not on the persona's default list; only when team is Angular-locked
- **jQuery** - rarely justified in a new project; legacy maintenance only
- **Bootstrap** - Tailwind v4 occupies its niche better
- **Material UI as default** - use it when the brand explicitly wants Material; not as a default
- **shadcn/ui copy-paste components used as default brand** - they're a good starting kit, but if you copy them unmodified you ship the shadcn aesthetic, which is the AI-default aesthetic
