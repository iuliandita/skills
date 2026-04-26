# Glitch Effects

Glitch as accent, not theme. Used on technical interfaces - terminals, dashboards, dev tools, status pages, hacker-aesthetic landing pages. Always with `prefers-reduced-motion: reduce` fallback to static.

The persona uses glitch sparingly. One deliberate use in the right place beats glitch on every element.

---

## When glitch is appropriate

- Terminal-style UIs, dev tools, monitoring dashboards
- 404 / error pages on technical products
- Hero accents on a single element (logo, headline word)
- Loading states for systems where data integrity is part of the brand
- Easter eggs and intentional moments

## When glitch is wrong

- Marketing pages selling reliability or stability
- Healthcare, finance, government, anything where "glitch" reads as broken
- On every element - it loses meaning when overused
- Body text - readability tax with no payoff
- When the user has reduced-motion preference (degrade to static)

---

## RGB split (chromatic aberration)

Splits text into three color channels offset by a small amount. Looks like cheap CRT bleed.

```css
.glitch-rgb {
  position: relative;
  color: var(--fg);
}

.glitch-rgb::before,
.glitch-rgb::after {
  content: attr(data-text);
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.glitch-rgb::before {
  color: #ff00aa;
  transform: translateX(-1px);
  mix-blend-mode: screen;
  animation: rgb-shift 3s infinite steps(8);
}

.glitch-rgb::after {
  color: #00ffee;
  transform: translateX(1px);
  mix-blend-mode: screen;
  animation: rgb-shift 3s infinite steps(8) reverse;
}

@keyframes rgb-shift {
  0%, 90%, 100% { transform: translateX(-1px); }
  92% { transform: translateX(-2px); }
  94% { transform: translateX(0); }
  96% { transform: translateX(-3px); }
}

/* Reduced-motion: kill the animation, drop the offsets */
@media (prefers-reduced-motion: reduce) {
  .glitch-rgb::before,
  .glitch-rgb::after {
    display: none;
  }
}
```

```html
<h1 class="glitch-rgb" data-text="STATUS: OK">STATUS: OK</h1>
```

The `data-text` duplication is required for the pseudo-elements to render the same text. Set it via JS if the content is dynamic.

---

## Scanlines

Horizontal lines overlaid on a surface. Reads as CRT or terminal display.

```css
.scanlines {
  position: relative;
  isolation: isolate;
}

.scanlines::after {
  content: "";
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: repeating-linear-gradient(
    to bottom,
    transparent 0,
    transparent 2px,
    rgba(0, 0, 0, 0.15) 2px,
    rgba(0, 0, 0, 0.15) 3px
  );
  z-index: 1;
}

/* Optional: subtle scroll animation */
.scanlines--moving::after {
  animation: scanline-scroll 8s linear infinite;
}

@keyframes scanline-scroll {
  from { background-position: 0 0; }
  to   { background-position: 0 6px; }
}

@media (prefers-reduced-motion: reduce) {
  .scanlines--moving::after {
    animation: none;
  }
}
```

```html
<div class="scanlines">
  <pre class="terminal-output">$ deploy --env=prod
✓ Built successfully
✓ Tests passed
✓ Deployed to production</pre>
</div>
```

Tune the line spacing (the `2px` / `3px` numbers) and opacity (`0.15`) to taste. Less is more.

---

## Type displacement (text glitch)

Text occasionally jumps to a slightly wrong position. Used on a single character or word, not a paragraph.

```css
.glitch-displace {
  display: inline-block;
  animation: type-glitch 4s infinite steps(1);
}

@keyframes type-glitch {
  0%, 92%, 100% { transform: translate(0, 0); }
  93%           { transform: translate(-2px, 0); clip-path: inset(20% 0 60% 0); }
  94%           { transform: translate(2px, 0);  clip-path: inset(40% 0 40% 0); }
  95%           { transform: translate(-1px, 1px); clip-path: inset(0 0 80% 0); }
  96%           { transform: translate(1px, -1px); clip-path: none; }
}

@media (prefers-reduced-motion: reduce) {
  .glitch-displace {
    animation: none;
  }
}
```

```html
<h1>SYSTEM <span class="glitch-displace">FAULT</span></h1>
```

---

## Controlled stutter (frame skip)

Element flickers briefly at intervals. Useful for "live" indicators on technical UIs.

```css
.stutter {
  animation: stutter 5s infinite steps(1);
}

@keyframes stutter {
  0%, 96%, 100% { opacity: 1; }
  97%           { opacity: 0.4; }
  98%           { opacity: 1; }
  98.5%         { opacity: 0.6; }
  99%           { opacity: 1; }
}

@media (prefers-reduced-motion: reduce) {
  .stutter {
    animation: none;
  }
}
```

```html
<span class="stutter" aria-hidden="true">●</span> LIVE
```

---

## Glitch on hover

Best of both: static by default, glitch on interaction. No autoplay.

```css
.glitch-hover {
  position: relative;
}

.glitch-hover:hover::before {
  content: attr(data-text);
  position: absolute;
  inset: 0;
  color: var(--accent);
  transform: translate(2px, 0);
  clip-path: inset(20% 0 60% 0);
  mix-blend-mode: screen;
  animation: glitch-hover 0.3s steps(4);
}

@keyframes glitch-hover {
  0%   { transform: translate(0, 0); }
  25%  { transform: translate(-2px, 1px); clip-path: inset(40% 0 40% 0); }
  50%  { transform: translate(2px, -1px); clip-path: inset(60% 0 20% 0); }
  75%  { transform: translate(-1px, 0); clip-path: inset(20% 0 60% 0); }
  100% { transform: translate(0, 0); clip-path: inset(0 0 0 0); }
}

@media (prefers-reduced-motion: reduce) {
  .glitch-hover:hover::before {
    animation: none;
    transform: none;
  }
}
```

```html
<a class="glitch-hover" data-text="VIEW DOCS" href="/docs">VIEW DOCS</a>
```

---

## Restraint rules

The persona's restraint rules for glitch:

1. **One glitch element on screen at a time.** Two competing glitches read as broken.
2. **Glitch the noun, not the verb.** Nouns (status indicators, brand marks, headings) carry meaning. Verbs (buttons, links) need clarity, not noise.
3. **Time the loop above 3 seconds.** Faster is migraine-inducing. Most of the cycle should be static.
4. **Always reduced-motion fallback.** Test it: open DevTools, toggle `prefers-reduced-motion`, confirm no animation runs.
5. **Glitch on dark.** Glitch is harder to land on light backgrounds; reads as a bug, not a style.
6. **Skip the animation on the first paint.** No glitch on initial load - users haven't agreed to it yet. Trigger after first interaction or a short delay.
7. **Keep contrast.** RGB-split colors should still hit AA contrast against the background; the glitch is decoration, the underlying text is the message.

---

## What NOT to do

- Glitch on body text or paragraphs - illegible
- Glitch on form inputs - users think the form is broken
- Permanent glitch (no quiet phase) - exhausting
- Glitch + scanlines + stutter all at once on the same element - visual mud
- Glitch animations longer than 800ms per cycle - feels broken, not stylish
- `text-shadow` glitch on body type at small sizes - blurs reading
