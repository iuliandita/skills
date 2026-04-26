# Mobile + Touch Patterns

Mobile is not a viewport. It's a different input modality: touch instead of pointer, gestures instead of hover, smaller surface, occluded fingers, no precise targets.

The persona designs mobile first, then adds desktop. Touch targets meet 44 x 44 px. Gesture handlers use modern APIs - Pointer Events first, `@use-gesture` when component logic gets complex. Hammer.js is legacy and not introduced to new code.

---

## The 44 px rule

Apple's HIG and WCAG 2.5.5 (Target Size, Level AAA) both recommend 44 x 44 px minimum touch targets. WCAG 2.5.8 (Target Size, Minimum, Level AA) sets 24 x 24 px as the absolute floor.

The persona uses 44 px on mobile and 32 px minimum on desktop. Smaller is allowed only in dense data tables and code editors where the user is in precision mode.

```css
/* Default targets */
.btn,
.icon-btn,
nav a {
  min-height: 44px;
  min-width: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

/* Inputs: full-width on mobile */
input[type="text"],
input[type="email"],
textarea {
  min-height: 44px;
  font-size: max(16px, 1rem);  /* 16px+ prevents iOS Safari from auto-zooming */
}
```

Pseudo-element padding when the visual element is smaller than 44 px:

```css
/* Visual icon is 16px; tap target is 44px via pseudo-element */
.icon-btn {
  position: relative;
  width: 16px;
  height: 16px;
}

.icon-btn::before {
  content: "";
  position: absolute;
  inset: -14px;  /* expands the hit area to 44 x 44 */
}
```

---

## Mobile-first markup

`min-width` queries, not `max-width`. The unstyled state is the mobile state. Desktop is the enhancement.

```css
/* Mobile (default) */
.layout {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
  padding: 1rem;
}

/* Tablet */
@media (min-width: 48em) {
  .layout {
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    padding: 2rem;
  }
}

/* Desktop */
@media (min-width: 64em) {
  .layout {
    grid-template-columns: 240px 1fr;
    gap: 2rem;
    padding: 3rem;
  }
}
```

Better still: use container queries (Baseline 2023) when the layout depends on the parent's size, not the viewport.

```css
.card-list {
  container-type: inline-size;
}

.card {
  padding: 0.75rem;
}

@container (min-width: 28rem) {
  .card {
    padding: 1.5rem;
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 1rem;
  }
}
```

---

## Pointer Events: the modern foundation

Pointer Events unify mouse, touch, pen, and stylus into one event model. They are supported in every modern browser. Use them instead of `touchstart` / `touchmove` / `touchend` or `mousedown` / `mousemove` / `mouseup`.

```ts
const target = document.querySelector(".swipe-target") as HTMLElement;
let startX = 0;
let activePointerId: number | null = null;

target.addEventListener("pointerdown", (e) => {
  activePointerId = e.pointerId;
  startX = e.clientX;
  target.setPointerCapture(e.pointerId);
});

target.addEventListener("pointermove", (e) => {
  if (e.pointerId !== activePointerId) return;
  const dx = e.clientX - startX;
  target.style.transform = `translateX(${dx}px)`;
});

target.addEventListener("pointerup", (e) => {
  if (e.pointerId !== activePointerId) return;
  activePointerId = null;
  const dx = e.clientX - startX;
  if (Math.abs(dx) > 100) {
    target.dataset.swipe = dx > 0 ? "right" : "left";
  } else {
    target.style.transform = "";
  }
});
```

`setPointerCapture` is the key feature - the element keeps receiving events even if the pointer leaves its bounds.

---

## Swipe carousels: scroll-snap, no JS

For most swipe carousels, CSS scroll-snap is enough. No event handlers, no JS.

```html
<ul class="carousel">
  <li class="slide">Slide 1</li>
  <li class="slide">Slide 2</li>
  <li class="slide">Slide 3</li>
</ul>
```

```css
.carousel {
  display: flex;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;            /* hide on Firefox */
  -webkit-overflow-scrolling: touch;
}
.carousel::-webkit-scrollbar { display: none; }

.slide {
  flex: 0 0 100%;
  scroll-snap-align: start;
  scroll-snap-stop: always;
}

@media (prefers-reduced-motion: reduce) {
  .carousel {
    scroll-snap-type: none;
  }
}
```

For pagination dots and "next slide" buttons, observe slide visibility with `IntersectionObserver` and update state.

---

## `@use-gesture/react` for rich gestures

When you need drag-with-springs, pinch-to-zoom, multi-touch coordination, or to chain gestures, use `@use-gesture/react`. Hook-based, modern, actively maintained.

```bash
bun add @use-gesture/react
```

```tsx
import { useDrag, usePinch } from "@use-gesture/react";
import { useState } from "react";

export function PinchableImage({ src }: { src: string }) {
  const [scale, setScale] = useState(1);
  const [{ x, y }, setPos] = useState({ x: 0, y: 0 });

  const bindDrag = useDrag(({ offset: [ox, oy] }) => {
    setPos({ x: ox, y: oy });
  });

  const bindPinch = usePinch(({ offset: [s] }) => {
    setScale(Math.max(1, Math.min(s, 4)));
  });

  return (
    <img
      src={src}
      {...bindDrag()}
      {...bindPinch()}
      style={{
        transform: `translate(${x}px, ${y}px) scale(${scale})`,
        touchAction: "none",   /* required: disables browser pan/zoom */
        userSelect: "none",
      }}
      draggable={false}
    />
  );
}
```

`touch-action: none` is required - without it, browsers handle pan and zoom themselves and your gesture handlers fight them.

For Vue / Svelte / vanilla, use `@use-gesture/vanilla` with the same primitives.

---

## Long-press

Long-press (touch-hold) is a context-menu equivalent on mobile. Use Pointer Events with a timer.

```ts
const target = document.querySelector(".long-press") as HTMLElement;
let timer: number | null = null;
const HOLD_MS = 500;

function start(e: PointerEvent) {
  timer = window.setTimeout(() => {
    target.dispatchEvent(new CustomEvent("longpress", { detail: { x: e.clientX, y: e.clientY } }));
    timer = null;
  }, HOLD_MS);
}

function cancel() {
  if (timer) {
    clearTimeout(timer);
    timer = null;
  }
}

target.addEventListener("pointerdown", start);
target.addEventListener("pointerup", cancel);
target.addEventListener("pointermove", cancel);
target.addEventListener("pointercancel", cancel);
```

Provide a desktop equivalent (right-click menu, kebab button) - long-press is not discoverable on its own.

---

## Pull-to-refresh

Native on iOS Safari and Android Chrome inside scrollable areas. The persona usually does NOT implement custom pull-to-refresh:

- Hard to get right (overscroll behavior, momentum, visual feedback)
- Often a tell that someone copied a native app pattern into the web

When required, use `overscroll-behavior` to constrain native scroll, then implement with Pointer Events.

```css
body {
  overscroll-behavior-y: contain;  /* don't bounce the whole page */
}
```

For a real PTR implementation, consider a small library or follow MDN's overscroll-behavior pattern. Don't reinvent it for marketing demos.

---

## Hover replacement on touch

Don't rely on `:hover` for critical state. Touch devices fire it on tap and stick it until the next tap elsewhere. Use `@media (hover: hover)` for hover-only enhancements.

```css
.card {
  /* Default: no hover effect */
  border: 1px solid var(--border);
}

@media (hover: hover) {
  .card:hover {
    border-color: var(--accent);
  }
}

/* Touch devices: rely on focus or active for feedback */
.card:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
```

---

## Forms on mobile

- `inputmode` directs the keyboard: `numeric`, `decimal`, `tel`, `email`, `url`, `search`
- `autocomplete` (e.g., `one-time-code`, `current-password`, `street-address`) lets the browser autofill
- `enterkeyhint` ("send", "search", "go", "next", "done") customizes the keyboard's enter button
- `font-size: 16px` minimum on inputs to prevent iOS Safari auto-zoom

```html
<form>
  <label>
    Phone
    <input
      type="tel"
      inputmode="tel"
      autocomplete="tel"
      enterkeyhint="next"
      required
    >
  </label>

  <label>
    Verification code
    <input
      type="text"
      inputmode="numeric"
      autocomplete="one-time-code"
      enterkeyhint="done"
      pattern="[0-9]{6}"
      required
    >
  </label>
</form>
```

---

## Mobile-specific layout patterns

### Bottom sheets, not centered modals

Modals on mobile that bottom-sheet feel native. Centered modals leave the user reaching across the screen.

```css
.sheet {
  position: fixed;
  inset: auto 0 0 0;
  max-height: 80vh;
  border-radius: 1rem 1rem 0 0;
  background: var(--bg-elevated);
  transform: translateY(100%);
  transition: transform 200ms ease-out;
}

.sheet[data-open="true"] {
  transform: translateY(0);
}
```

### Fixed bottom action bars

Primary action stays in thumb reach.

```css
.action-bar {
  position: fixed;
  inset: auto 0 0 0;
  padding: 0.75rem 1rem max(0.75rem, env(safe-area-inset-bottom));
  background: var(--bg-elevated);
  border-top: 1px solid var(--border);
}
```

`env(safe-area-inset-bottom)` accounts for iPhone home-bar.

### Navigation: bottom tabs on mobile, side nav on desktop

```css
nav {
  position: fixed;
  inset: auto 0 0 0;       /* bottom on mobile */
  padding: 0.5rem max(1rem, env(safe-area-inset-bottom));
}

@media (min-width: 64em) {
  nav {
    inset: 0 auto 0 0;     /* side on desktop */
    width: 240px;
  }
}
```

---

## Performance on mobile

- Images: AVIF first, WebP fallback, JPEG/PNG last. `srcset` for resolution. `loading="lazy"` below the fold
- Fonts: subset to required glyphs, `font-display: swap`, prefer variable fonts
- JS budget: <100 KB gzipped on initial load for content sites; apps can go higher but every KB hurts on a 3G connection
- Above-the-fold critical CSS inline; rest async

---

## What the persona refuses on mobile

1. **Hover-only interactions for primary actions.** If the user can't get to it on touch, it doesn't exist on mobile.
2. **Carousel as the only navigation for content.** Hamburger menus for primary nav are fine; carousels for primary content are an attention tax.
3. **Tiny tap targets to fit a desktop layout** - 24 x 24 px buttons because that's how it looks on the design.
4. **Auto-playing video on mobile.** Battery, bandwidth, attention - all wrong.
5. **Modal-on-load on mobile.** It's worse than desktop. The user has less screen.
6. **Bottom-fixed banners that block reading without a clear close button.**
7. **`scroll-behavior: smooth` on long pages without `prefers-reduced-motion` opt-out.**
