# Mobile + Touch Patterns

Mobile is not a viewport. It's a different input modality: touch instead of pointer, gestures instead of hover, smaller surface, occluded fingers, no precise targets.

Design narrow screens and touch behavior deliberately while preserving existing responsive
conventions. Aim for 44 x 44 CSS px touch targets. Prefer Pointer Events for custom gestures
and a combined gesture library binding when coordination is needed. Examples below are
independent patterns; adapt their layout and controls to the actual task.

---

## The 44 px rule

Use 44 x 44 CSS px as a mobile design target. WCAG 2.5.5 (AAA) and 2.5.8 (AA) have different
thresholds and exceptions; 24 x 24 CSS px is not an unconditional floor. Inspect spacing,
inline targets, equivalent controls, and the other applicable exceptions before declaring a
violation. See [WCAG target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).
Do not expand controls during a spacing-only task without authorization for that scope.

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

For a new layout, a narrow-screen base with `min-width` enhancements is a useful starting
point. Preserve an existing `max-width` or container-query convention when refining a component.

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
target.style.touchAction = "pan-y";

function resetSwipe(e: PointerEvent) {
  if (e.pointerId !== activePointerId) return;
  activePointerId = null;
  target.style.transform = "";
}

target.addEventListener("pointerdown", (e) => {
  if (!e.isPrimary || e.button !== 0 || activePointerId !== null) return;
  activePointerId = e.pointerId;
  startX = e.clientX;
  delete target.dataset.swipe;
  target.setPointerCapture(e.pointerId);
});

target.addEventListener("pointermove", (e) => {
  if (e.pointerId !== activePointerId) return;
  target.style.transform = `translateX(${e.clientX - startX}px)`;
});

target.addEventListener("pointerup", (e) => {
  if (e.pointerId !== activePointerId) return;
  const dx = e.clientX - startX;
  if (Math.abs(dx) > 100) target.dataset.swipe = dx > 0 ? "right" : "left";
  resetSwipe(e);
});
target.addEventListener("pointercancel", resetSwipe);
target.addEventListener("lostpointercapture", resetSwipe);
```

`setPointerCapture` keeps delivery when the pointer leaves the element. Cancellation must
reset visual and pointer state. Keep a visible button alternative for the swipe action and
dispose listeners when the component unmounts.

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
    scroll-behavior: auto;
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
import { useGesture } from "@use-gesture/react";
import { useId, useRef, useState } from "react";

export function PinchableImage({ src, alt }: { src: string; alt: string }) {
  const instructions = useId();
  const imgRef = useRef<HTMLImageElement>(null);
  const [scale, setScale] = useState(1);
  const [{ x, y }, setPos] = useState({ x: 0, y: 0 });

  // The image scales about its center, so it overhangs the clip by
  // (scale - 1) / 2 of its layout size per side. Never pan past that overhang.
  // offsetWidth/offsetHeight are layout values, unaffected by the transform, and
  // translate() runs in unscaled parent pixels here, so the bound needs no divide.
  const panMax = (s: number) => {
    const el = imgRef.current;
    return {
      x: el ? ((s - 1) * el.offsetWidth) / 2 : 0,
      y: el ? ((s - 1) * el.offsetHeight) / 2 : 0,
    };
  };
  const panBounds = (s: number) => {
    const { x: mx, y: my } = panMax(s);
    return { left: -mx, right: mx, top: -my, bottom: my };
  };
  const clampPos = (pos: { x: number; y: number }, s: number) => {
    const { x: mx, y: my } = panMax(s);
    return {
      x: Math.min(mx, Math.max(-mx, pos.x)),
      y: Math.min(my, Math.max(-my, pos.y)),
    };
  };
  const applyScale = (s: number) => {
    setScale(s);
    setPos((pos) => clampPos(pos, s));
  };

  const bind = useGesture({
    onDrag: ({ offset: [ox, oy] }) => setPos(clampPos({ x: ox, y: oy }, scale)),
    onPinch: ({ offset: [s] }) => applyScale(s),
  }, {
    drag: { from: () => [x, y], bounds: () => panBounds(scale) },
    pinch: { from: () => [scale, 0], scaleBounds: { min: 1, max: 4 } },
  });

  return (
    <figure>
      <p id={instructions}>Drag or use arrow keys to pan. Pinch or use Zoom to resize.</p>
      <div style={{ overflow: "hidden" }}>
        <img
          ref={imgRef}
          src={src} alt={alt} tabIndex={0} aria-describedby={instructions}
          {...bind()}
          onKeyDown={(e) => {
            const directions: Record<string, [number, number]> = { ArrowLeft: [-20, 0], ArrowRight: [20, 0],
              ArrowUp: [0, -20], ArrowDown: [0, 20] };
            const delta = directions[e.key];
            if (!delta) return;
            e.preventDefault();
            setPos((pos) => clampPos({ x: pos.x + delta[0], y: pos.y + delta[1] }, scale));
          }}
          style={{
            maxWidth: "100%",
            transform: `translate(${x}px, ${y}px) scale(${scale})`,
            touchAction: "none", userSelect: "none",
          }}
          draggable={false}
        />
      </div>
      <label>
        Zoom
        <input type="range" min="1" max="4" step="0.1" value={scale}
          onChange={(e) => applyScale(Number(e.currentTarget.value))} />
      </label>
      <button type="button" onClick={() => { setScale(1); setPos({ x: 0, y: 0 }); }}>
        Reset view
      </button>
    </figure>
  );
}
```

Use one [combined binding](https://use-gesture.netlify.app/docs/gestures/) so drag and pinch
do not overwrite each other's event handlers. Keep control-driven state synchronized with
[gesture offsets](https://use-gesture.netlify.app/docs/options/) using `from`.

Clamp every offset write (drag, arrow keys, zoom change) through the same bound so repeated
key presses cannot push the image out of the clip. Give drag a dynamic
[`bounds`](https://use-gesture.netlify.app/docs/options/) function as well: clamping only the
React state lets the gesture's internal offset keep accumulating past the edge, so the user
would have to drag all the way back before the image moved again. Test: hold ArrowRight at scale 1 (no
movement), at scale 4 (stops at the edge), zoom back to 1 (offset returns to 0), then Reset.
Scope `touch-action: none` to a dedicated manipulation surface: it disables browser pan/zoom
there, so preserve page scrolling elsewhere and provide keyboard zoom/pan and reset controls.
Set intrinsic image dimensions from real asset metadata and keep a visible focus style.
For Safari trackpad pinch, use the documented target/ref integration when required; do not
block browser zoom globally.

For Vue / Svelte / vanilla, use `@use-gesture/vanilla` with the same primitives.

---

## Long-press

Long-press (touch-hold) is a context-menu equivalent on mobile. Use Pointer Events with a timer.

```ts
const target = document.querySelector(".long-press") as HTMLElement;
let timer: number | null = null;
let pointerId: number | null = null;
let startX = 0;
let startY = 0;
const HOLD_MS = 500;
const MOVE_TOLERANCE = 8;

function cancel() {
  if (timer !== null) window.clearTimeout(timer);
  timer = null;
  pointerId = null;
}

target.addEventListener("pointerdown", (e) => {
  if (!e.isPrimary || e.button !== 0 || pointerId !== null) return;
  pointerId = e.pointerId;
  startX = e.clientX;
  startY = e.clientY;
  target.setPointerCapture(e.pointerId);
  timer = window.setTimeout(() => {
    target.dispatchEvent(new CustomEvent("longpress", { detail: { x: startX, y: startY } }));
    timer = null;
  }, HOLD_MS);
});
target.addEventListener("pointermove", (e) => {
  if (e.pointerId === pointerId && Math.hypot(e.clientX - startX, e.clientY - startY) > MOVE_TOLERANCE) cancel();
});
for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
  target.addEventListener(name, (e) => {
    if ((e as PointerEvent).pointerId === pointerId) cancel();
  });
}
```

Provide a visible menu button usable by touch and keyboard; long-press is not discoverable
on its own. Dispose listeners and cancel the timer when the component unmounts.

---

## Pull-to-refresh

Native on iOS Safari and Android Chrome inside scrollable areas. Custom pull-to-refresh is usually unnecessary:

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

@media (prefers-reduced-motion: reduce) {
  .sheet { transition: none; }
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

`env(safe-area-inset-bottom)` accounts for the home indicator. Reserve matching space in
the scrollable content so the fixed bar does not cover the last row or focused control.

### Navigation: bottom tabs on mobile, side nav on desktop

```css
nav {
  position: fixed;
  inset: auto 0 0 0;       /* bottom on mobile */
  padding: 0.5rem 1rem max(0.5rem, env(safe-area-inset-bottom));
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

## Mobile review priorities

- Keep primary actions available without hover and give gestures visible alternatives.
- Assess target size and spacing against the applicable criterion; preserve scoped changes.
- Provide pause controls for moving media and respect reduced-motion preferences.
- Avoid optional interruptions on arrival; explain required access or consent decisions.
- Keep fixed navigation and banners clear of content, focused controls, and device safe areas.
- Preserve discrete scroll snapping under reduced motion while disabling smooth scrolling.
