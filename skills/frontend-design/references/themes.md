# Dark + Light Theme Architecture

Both themes are first-class. Neither is auto-derived from the other. Both are designed - colors picked, contrast checked, semantic tokens defined - then implemented as CSS custom properties with a `[data-theme]` selector for explicit toggle and `prefers-color-scheme` for default.

The persona refuses to ship a theme that's only `filter: invert()` or only auto-generated from the other.

---

## The pattern

Custom properties at `:root` define the default theme. A `[data-theme="dark"]` (or `light`, depending on which is default) override block defines the alternate. JavaScript toggles `data-theme` on `<html>`. System preference picks the initial value.

```css
/* theme.css */

/* Default (light) */
:root {
  /* Surfaces */
  --bg: #fafaf9;
  --bg-subtle: #f5f5f4;
  --bg-elevated: #ffffff;

  /* Text */
  --fg: #1c1917;
  --fg-muted: #57534e;
  --fg-subtle: #a8a29e;

  /* Borders */
  --border: #e7e5e4;
  --border-strong: #a8a29e;

  /* Accent (one, committed) */
  --accent: #d97706;
  --accent-fg: #ffffff;
  --accent-hover: #b45309;

  /* States */
  --success: #15803d;
  --warning: #b45309;
  --error: #b91c1c;

  /* Focus ring */
  --focus-ring: 0 0 0 3px color-mix(in oklch, var(--accent) 40%, transparent);

  /* Type */
  --font-sans: "Inter Variable", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;

  /* Radii */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-full: 9999px;
}

/* Dark theme - designed, not derived */
:root[data-theme="dark"] {
  --bg: #0c0a09;
  --bg-subtle: #1c1917;
  --bg-elevated: #292524;

  --fg: #fafaf9;
  --fg-muted: #a8a29e;
  --fg-subtle: #57534e;

  --border: #292524;
  --border-strong: #57534e;

  --accent: #fb923c;        /* lighter on dark; not the same hex */
  --accent-fg: #1c1917;
  --accent-hover: #fdba74;

  --success: #4ade80;
  --warning: #fbbf24;
  --error: #f87171;

  --focus-ring: 0 0 0 3px color-mix(in oklch, var(--accent) 50%, transparent);
}
```

Note: the dark accent is `#fb923c` (lighter), not the same hex inverted. That is the difference between a designed dark theme and an auto-derived one.

---

## No-FOUC theme initialization

The flash-of-incorrect-theme is the worst class of theme bug. The fix is a synchronous inline script in `<head>`, before the stylesheet, that sets `data-theme` from `localStorage` and `prefers-color-scheme`.

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <!-- Inline script: must run before stylesheet, must be synchronous -->
  <script>
    (function () {
      const stored = localStorage.getItem("theme");
      const system = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
      const theme = stored || system;
      document.documentElement.dataset.theme = theme;
    })();
  </script>

  <!-- Color-scheme meta for native form controls and scrollbars -->
  <meta name="color-scheme" content="light dark">

  <link rel="stylesheet" href="/styles/theme.css">
  <link rel="stylesheet" href="/styles/app.css">
</head>
<body>
  <!-- ... -->
</body>
</html>
```

The inline script is a deliberate exception to the "no inline JS" rule. Reason: any async loading produces FOUC.

---

## Theme toggle

The toggle updates `data-theme` and `localStorage`. It does not reload. It does not animate the swap (transitions on theme change cause every element to animate together, which looks broken).

```ts
// scripts/theme-toggle.ts
function setTheme(theme: "light" | "dark") {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem("theme", theme);
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme;
  setTheme(current === "dark" ? "light" : "dark");
}

document.querySelector("[data-theme-toggle]")?.addEventListener("click", toggleTheme);

// React to system preference if user hasn't picked
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
  if (!localStorage.getItem("theme")) {
    setTheme(e.matches ? "dark" : "light");
  }
});
```

```html
<button type="button" data-theme-toggle aria-label="Toggle theme">
  <svg class="theme-icon-light" aria-hidden="true"><!-- sun --></svg>
  <svg class="theme-icon-dark" aria-hidden="true"><!-- moon --></svg>
</button>
```

```css
/* Show only the icon for the OPPOSITE theme - the action it triggers */
:root[data-theme="light"] .theme-icon-light { display: none; }
:root[data-theme="dark"]  .theme-icon-dark  { display: none; }
```

---

## Suppressing transition flash

When the user toggles, you don't want every animated element to play its theme transition. Add a temporary class on `<html>` that disables transitions, then remove it on the next frame.

```ts
function setTheme(theme: "light" | "dark") {
  const root = document.documentElement;
  root.classList.add("theme-switching");
  root.dataset.theme = theme;
  localStorage.setItem("theme", theme);
  requestAnimationFrame(() => {
    requestAnimationFrame(() => root.classList.remove("theme-switching"));
  });
}
```

```css
.theme-switching * {
  transition: none !important;
}
```

---

## Per-theme considerations

### Dark theme

- Pure black (`#000`) is rarely right; use `#0c0a09` or similar for less eye strain on OLED
- Saturated colors look louder on dark; desaturate accents by ~10-20% from their light-theme equivalent
- Borders need higher luminance contrast than on light; `#292524` on `#0c0a09` is a real border, not invisible
- White text at `#fafaf9` (slightly off) reads softer than pure white

### Light theme

- Pure white (`#fff`) is fine for elevated surfaces; the page background can be slightly off (`#fafaf9`)
- Bigger contrast required for body text on light bg (use `#1c1917`, not `#404040`)
- Drop shadows visible; on dark, use borders instead of shadows
- Accent colors can be deeper; orange `#d97706` on light is warmer than its dark-theme equivalent

---

## Contrast targets

Run a contrast checker on every text-on-surface combination per theme:

| Combination | Minimum |
|---|---|
| Body text on background | WCAG AA (4.5:1), AAA (7:1) where feasible |
| Large text (>=18 pt or 14 pt bold) | WCAG AA (3:1) |
| UI element borders | 3:1 against adjacent surface |
| Icons and graphical UI | 3:1 |
| Disabled text | not subject to WCAG, but should be visibly distinguishable from active text |

Tools: WebAIM contrast checker, browser devtools accessibility panel, `npx pa11y` for CI.

---

## Color-scheme meta

Always include `<meta name="color-scheme" content="light dark">` so native form controls, scrollbars, and the user-agent's default styles match the active theme. Without this, scrollbars stay white in dark mode on Chromium.

---

## Common mistakes the persona refuses

1. **Single theme, "we'll add light later"** - both themes ship together or neither ships. "Later" never happens.
2. **`filter: invert()` for dark mode** - colors become wrong; images break; brand identity disappears.
3. **`@media (prefers-color-scheme: dark)` only, no toggle** - users on browsers that lie about preference can't override.
4. **Toggle that flashes** - missing inline init script.
5. **Same accent color on both themes** - oversaturated on dark, washed-out on light.
6. **Text that says "Switch to dark mode" while in dark mode** - the button text should describe the action (Switch to ...), not the current state. Or use icons.
7. **Toggle that animates a CSS property transition on `--bg`** - every element in the tree retransitions; looks like a bug.
