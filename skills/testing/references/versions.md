---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Vitest"
    version: "5.0.5"
    source: "https://github.com/vitest-dev/vitest/releases"
  - tool: "Jest"
    version: "30.5.2"
    source: "https://github.com/jestjs/jest/releases"
  - tool: "Playwright"
    version: "1.64.1"
    source: "https://github.com/microsoft/playwright/releases"
  - tool: "Cypress"
    version: "16.1.1"
    source: "https://github.com/cypress-io/cypress/releases"
  - tool: "pytest"
    version: "9.2.0"
    source: "https://pypi.org/project/pytest/"
  - tool: "pytest-cov"
    version: "7.1.0"
    source: "https://pypi.org/project/pytest-cov/"
  - tool: "Go"
    version: "1.27.3"
    source: "https://go.dev/doc/devel/release"
  - tool: "Rust"
    version: "1.99.0"
    source: "https://github.com/rust-lang/rust/releases"
  - tool: "cargo-nextest"
    version: "0.9.150"
    source: "https://github.com/nextest-rs/nextest/releases"
  - tool: "Testing Library"
    version: "16.3.3"
    source: "https://github.com/testing-library/react-testing-library/releases"
  - tool: "axe-core"
    version: "4.14.0"
    source: "https://github.com/dequelabs/axe-core/releases"
  - tool: "Grafana k6"
    version: "2.3.0"
    source: "https://github.com/grafana/k6/releases"
---

# Target versions

| Tool | Version | Source |
|------|---------|--------|
| Vitest | 5.0.5 | [Releases](https://github.com/vitest-dev/vitest/releases) |
| Jest | 30.5.2 | [Releases](https://github.com/jestjs/jest/releases) |
| Playwright | 1.64.1 | [Releases](https://github.com/microsoft/playwright/releases) |
| Cypress | 16.1.1 | [Releases](https://github.com/cypress-io/cypress/releases) |
| pytest | 9.2.0 | [Releases](https://pypi.org/project/pytest/) |
| pytest-cov | 7.1.0 | [Releases](https://pypi.org/project/pytest-cov/) |
| Go | 1.27.3 | [Releases](https://go.dev/doc/devel/release) |
| Rust | 1.99.0 | [Releases](https://github.com/rust-lang/rust/releases) |
| cargo-nextest | 0.9.150 | [Releases](https://github.com/nextest-rs/nextest/releases) |
| Testing Library | 16.3.3 | [Releases](https://github.com/testing-library/react-testing-library/releases) |
| axe-core | 4.14.0 | [Releases](https://github.com/dequelabs/axe-core/releases) |
| Grafana k6 | 2.3.0 | [Releases](https://github.com/grafana/k6/releases) |

**Target versions** (October 2026):
- Vitest **5.0.5**, Jest **30.5.2**
- Playwright **1.64.1**, Cypress **16.1.1** (both Vitest and Cypress are major upgrades; review migration notes)
- pytest **9.2.0**, pytest-cov **7.1.0**
- Go **1.27.3** (testing stdlib, `testing/synctest` GA)
- Rust **1.99.0** (`cargo test`, cargo-nextest **0.9.150**)
- Testing Library **16.3.3** (`@testing-library/react`)
- axe-core **4.14.0** (`@axe-core/playwright`)
- Grafana k6 **2.3.0**

Security check (2026-10-28): [GHSA-2h32-95rg-cppp](https://github.com/vitest-dev/vitest/security/advisories/GHSA-2h32-95rg-cppp)
is critical browser-runner script injection that can expose the API token and lead to local code
execution. It affects `@vitest/browser` >=4.0.17,<4.1.6 and >=5.0.0-beta.0,<5.0.0-beta.3;
fixes are 4.1.6 and 5.0.0-beta.3. Keep browser packages aligned with the stable runner and do not
open untrusted runner URLs while the server is active. Later critical browser-mode advisories
([GHSA-g8mr-85jm-7xhm](https://github.com/advisories/GHSA-g8mr-85jm-7xhm), [GHSA-p63j-vcc4-9vmv](https://github.com/advisories/GHSA-p63j-vcc4-9vmv))
raise the 4.x floor to 4.1.10 and the 3.x floor to 3.2.7. October 21 advisories raise them again:
[GHSA-p458-7748-mcp3](https://github.com/advisories/GHSA-p458-7748-mcp3) (`server.fs.deny` bypass
serving `.env`, keys, and the API token; `@vitest/ui`/`@vitest/browser` <5.0.5) and
[GHSA-qxg6-89mg-rqv8](https://github.com/advisories/GHSA-qxg6-89mg-rqv8) (mock-registration code
injection; `@vitest/mocker` <4.1.12 and 5.0.x <5.0.3). Floors are 5.0.5 and 4.1.12; 3.x has no
patched release, so move off it.
