# Dark + Light Theme Architecture

Both themes are first-class. Neither is auto-derived from the other. Both are designed - colors picked, contrast checked, semantic tokens defined - then implemented as CSS custom properties with a `[data-theme]` selector for explicit toggle and `prefers-color-scheme` for default.

Apply this reference when theme implementation is in scope. Preserve the project's supported
themes; a single-theme campaign or a scoped component fix does not require adding a toggle.
The palette and fonts below illustrate token structure, not a default visual identity. Choose
values from the brief and verify each actual text/surface combination before reuse.
Do not create an alternate theme solely with `filter: invert()` without inspecting the result.

---

## The pattern

Custom properties at `:root` define the default theme. A `[data-theme="dark"]` (or `light`, depending on which is default) override block defines the alternate. JavaScript toggles `data-theme` on `<html>`. System preference picks the initial value.

```css
/* theme.css */

/* Default (light) */
:root {
  color-scheme: light;
  /* Surfaces */
  --bg: #fafaf9;
  --bg-subtle: #f5f5f4;
  --bg-elevated: #ffffff;

  /* Text */
  --fg: #1c1917;
  --fg-muted: #57534e;
  --fg-subtle: #57534e;

  /* Borders */
  --border: #e7e5e4;
  --border-strong: #78716c;

  /* Accent (one, committed) */
  --accent: #b45309;
  --accent-fg: #ffffff;
  --accent-hover: #92400e;

  /* States */
  --success: #15803d;
  --warning: #b45309;
  --error: #b91c1c;

  /* Focus ring */
  --focus-ring: 0 0 0 3px var(--accent);

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
  color-scheme: dark;
  --bg: #0c0a09;
  --bg-subtle: #1c1917;
  --bg-elevated: #292524;

  --fg: #fafaf9;
  --fg-muted: #a8a29e;
  --fg-subtle: #a8a29e;

  --border: #292524;
  --border-strong: #a8a29e;

  --accent: #fb923c;        /* lighter on dark; not the same hex */
  --accent-fg: #1c1917;
  --accent-hover: #fdba74;

  --success: #4ade80;
  --warning: #fbbf24;
  --error: #f87171;

  --focus-ring: 0 0 0 3px var(--accent);
}
```

The example uses a lighter accent on dark surfaces. Choose separate or shared values based
on measured contrast and the brief; different hex values are not a quality requirement.

---

## Initialize and choose a theme

Use one controller for initial theme, user choice, and later system changes. Persist only
explicit choices; a system change must not become a saved manual preference. Validate stored
values and keep the current page usable when storage is denied.

Place this script before the stylesheet. Under a Content Security Policy, authorize it with
an appropriate nonce or hash, or use the framework's existing server/theme initialization.
Do not relax the site's CSP to paste this example.

```html
<script>
  (() => {
    const root = document.documentElement;
    const system = matchMedia("(prefers-color-scheme: dark)");
    let preference = "system";
    try {
      const saved = localStorage.getItem("theme");
      if (saved === "dark" || saved === "light") preference = saved;
    } catch {
      console.warn("Theme storage unavailable; using system preference.");
    }

    function applyTheme() {
      root.dataset.theme = preference === "system"
        ? (system.matches ? "dark" : "light")
        : preference;
    }
    applyTheme();
    system.addEventListener("change", () => {
      if (preference === "system") applyTheme();
    });

    document.addEventListener("DOMContentLoaded", () => {
      const control = document.querySelector("[data-theme-preference]");
      if (!control) return;
      control.value = preference;
      control.addEventListener("change", () => {
        preference = control.value === "dark" || control.value === "light"
          ? control.value : "system";
        applyTheme();
        try {
          if (preference === "system") localStorage.removeItem("theme");
          else localStorage.setItem("theme", preference);
        } catch {
          console.warn("Theme choice applies to this page but could not be saved.");
        }
      });
    });
  })();
</script>
<link rel="stylesheet" href="/styles/theme.css">
```

Place the labeled control in the page body:

```html
<label for="theme-preference">Theme</label>
<select id="theme-preference" data-theme-preference>
  <option value="system">System</option>
  <option value="light">Light</option>
  <option value="dark">Dark</option>
</select>
```

In a component framework, use its lifecycle and dispose media-query listeners on unmount.
Keep the same distinction between the user's preference and the currently resolved theme.
Test repeated system changes, manual override, return to System, reload, invalid saved values,
and denied storage. Native controls must follow `color-scheme` on the active theme selector.

## Per-theme considerations

Choose surfaces and accents from the brief, then measure their actual combinations. Pure
black, white, and a shared accent across themes are valid when they meet the design and
contrast requirements. Do not apply a fixed desaturation percentage or substitute a house
palette. Use subtle borders for decoration and stronger tokens where the boundary is needed
to identify a control. Avoid global theme-change animations that compete with interaction.

---

## Contrast targets

Run a contrast checker on every text-on-surface combination per theme:

| Combination | Minimum |
|---|---|
| Body text on background | WCAG AA (4.5:1), AAA (7:1) where feasible |
| Large text (>=18 pt or 14 pt bold) | WCAG AA (3:1) |
| Boundaries needed to identify a control or state | 3:1 against adjacent surface |
| Necessary icons and graphical UI | 3:1; decorative graphics are excluded |
| Disabled text | not subject to WCAG, but should be visibly distinguishable from active text |

Tools: WebAIM contrast checker, browser devtools accessibility panel, `npx pa11y` for CI.

---

## Native controls and persistence

Declare `color-scheme: light` and `color-scheme: dark` on the matching theme selectors, as
above. A `light dark` meta tag advertises support but does not synchronize a manual override
with the document's actual theme. Verify native selects, inputs, and scrollbars after changing
away from the OS preference.

References: [color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/color-scheme),
[localStorage exceptions](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage).
