---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Astro"
    version: "7.3.5"
    source: "https://github.com/withastro/astro/releases"
  - tool: "SvelteKit"
    version: "3.0.0"
    source: "https://github.com/sveltejs/kit/releases"
  - tool: "Svelte"
    version: "5.57.1"
    source: "https://github.com/sveltejs/svelte/releases"
  - tool: "Tailwind CSS"
    version: "v4.3.3"
    source: "https://github.com/tailwindlabs/tailwindcss/releases"
  - tool: "Vite"
    version: "8.3.2"
    source: "https://github.com/vitejs/vite/releases"
  - tool: "React"
    version: "19.3.0"
    source: "https://github.com/facebook/react/releases"
  - tool: "Next.js"
    version: "16.4.3"
    source: "https://github.com/vercel/next.js/releases"
  - tool: "@use-gesture/react"
    version: "10.3.1"
    source: "https://github.com/pmndrs/use-gesture/releases"
---

# UI build target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages. The list is a reference for new-project selection, not an upgrade instruction. Inspect installed packages and follow the project's stack.

| Tool | Version | Source | Notes |
|---|---|---|---|
| Astro | 7.3.5 | <https://github.com/withastro/astro/releases> | Major: Rust compiler, Vite 8, advanced routing; verify advisory-specific fixed ranges before migration |
| SvelteKit | 3.0.0 | <https://github.com/sveltejs/kit/releases> | Major released 2026-10-01: TypeScript 6+, Node 22.17+; review migration notes |
| Svelte | 5.57.1 | <https://github.com/sveltejs/svelte/releases> | Runes |
| Tailwind CSS | v4.3.3 | <https://github.com/tailwindlabs/tailwindcss/releases> |  |
| Vite | 8.3.2 | <https://github.com/vitejs/vite/releases> |  |
| React | 19.3.0 | <https://github.com/facebook/react/releases> | Heavier option, only when team is React-locked |
| Next.js | 16.4.3 | <https://github.com/vercel/next.js/releases> | Heavier option, only when team is React-locked |
| @use-gesture/react | 10.3.1 | <https://github.com/pmndrs/use-gesture/releases> | Modern; Hammer.js considered legacy |

## Next.js security notes (checked 2026-10-28)

- [August 2026 security release](https://nextjs.org/blog/august-2026-security-release) fixes critical
  AVIF image-optimization RCE and Windows mixed-router RCE (CVE-2026-75604). Patched LTS releases are
  15.5.24 and 16.3.3.
- [September 22 out-of-band release](https://nextjs.org/blog/nextjs-security-update-september-22-2026)
  fixes a critical Node.js `ImageResponse` (`next/og`) RCE (GHSA-vcvr-r3jv-pc5j) affecting
  `>=16.2.0 <16.3.6`; the floor is 16.3.6 (15.5.26 adds hardening only; 15.x is not affected).
- [September 30 security release](https://github.com/vercel/next.js/releases/tag/v16.3.8) fixes
  high-severity Image Optimization SSRF (CVE-2026-94483) plus medium cache-poisoning and cache-leak
  advisories (floors 16.3.8 / 15.5.27).
- [October 14 security release](https://github.com/vercel/next.js/releases/tag/v16.4.1) fixes
  critical unauthenticated RCEs in SVG Image Optimization (GHSA-2464-fhr4-w9xw, 15.x and 16.x) and
  `use cache` typed arrays (GHSA-673q-mjm6-r5xr, 16.x only) plus high Server Actions DoS
  (GHSA-p3m5-59mp-jv5r); the floors are now 16.4.1 and 15.5.28.
- Check each advisory's deployment conditions when assessing an existing app.
