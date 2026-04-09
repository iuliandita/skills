# E2E, Accessibility, and Visual Regression Testing

Patterns for browser-based testing with Playwright (primary) and Cypress (secondary). Covers E2E test architecture, accessibility automation with axe-core, visual regression via screenshot comparison, and CI integration.

---

## Playwright E2E Patterns

Playwright is the default E2E tool. Supports Chromium, Firefox, and WebKit. Tests run in parallel by default.

### Project setup

```bash
# Install
npm init playwright@latest
# or
bun create playwright

# Run tests
npx playwright test

# UI mode (interactive debugging)
npx playwright test --ui

# Specific browser
npx playwright test --project=chromium
```

### Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,           // fail if .only in CI
  retries: process.env.CI ? 2 : 0,        // retry in CI only
  workers: process.env.CI ? 4 : undefined, // limit CI workers
  reporter: [
    ["html"],
    ...(process.env.CI ? [["junit", { outputFile: "results.xml" }] as const] : []),
  ],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",              // capture trace on failure
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox",  use: { ...devices["Desktop Firefox"] } },
    { name: "webkit",   use: { ...devices["Desktop Safari"] } },
    { name: "mobile",   use: { ...devices["Pixel 7"] } },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

### Test patterns

```typescript
import { test, expect } from "@playwright/test";

test.describe("Checkout flow", () => {
  test.beforeEach(async ({ page }) => {
    // Seed test data via API, not via UI
    await page.request.post("/api/test/seed", {
      data: { user: "test@example.com", cart: ["widget-1"] },
    });
    await page.goto("/checkout");
  });

  test("completes purchase with valid card", async ({ page }) => {
    await page.getByLabel("Card number").fill("4242424242424242");
    await page.getByLabel("Expiry").fill("12/28");
    await page.getByLabel("CVC").fill("123");
    await page.getByRole("button", { name: "Pay" }).click();

    await expect(page.getByText("Order confirmed")).toBeVisible();
  });

  test("shows error for declined card", async ({ page }) => {
    await page.getByLabel("Card number").fill("4000000000000002");
    await page.getByLabel("Expiry").fill("12/28");
    await page.getByLabel("CVC").fill("123");
    await page.getByRole("button", { name: "Pay" }).click();

    await expect(page.getByText("Card declined")).toBeVisible();
  });
});
```

### Selector strategy

Priority order (matches Testing Library philosophy):

1. **Role**: `page.getByRole("button", { name: "Submit" })` - accessible, resilient
2. **Label**: `page.getByLabel("Email")` - form elements
3. **Text**: `page.getByText("Welcome back")` - visible content
4. **Placeholder**: `page.getByPlaceholder("Search...")` - fallback
5. **Test ID**: `page.getByTestId("checkout-form")` - last resort

Never use CSS selectors (`.btn-primary`), XPath, or DOM structure. Those are the #1 cause of brittle E2E tests.

### Waiting strategy

Playwright auto-waits for elements to be actionable (visible, stable, enabled, receives events). Don't add manual waits. When you need to wait for something Playwright can't auto-detect:

```typescript
// Wait for network response
await page.waitForResponse(resp =>
  resp.url().includes("/api/order") && resp.status() === 200
);

// Wait for element state
await expect(page.getByTestId("loading")).toBeHidden();

// Wait for navigation
await Promise.all([
  page.waitForURL("**/confirmation"),
  page.getByRole("button", { name: "Confirm" }).click(),
]);
```

**Never use `page.waitForTimeout()`** - it's `sleep()` by another name. If you genuinely need a delay (animation settling, third-party widget loading), document why and use the shortest possible duration.

### Authentication

Don't log in through the UI for every test. Use `storageState` to save and reuse auth:

```typescript
// auth.setup.ts - runs once before all tests
import { test as setup } from "@playwright/test";

setup("authenticate", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("test@example.com");
  await page.getByLabel("Password").fill("testpassword");
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("/dashboard");
  await page.context().storageState({ path: ".auth/user.json" });
});

// In playwright.config.ts:
// { name: "setup", testMatch: /auth\.setup\.ts/ },
// { name: "chromium", use: { storageState: ".auth/user.json" }, dependencies: ["setup"] },
```

### API testing with Playwright

Playwright's `request` context works for API-only tests too:

```typescript
import { test, expect } from "@playwright/test";

test("GET /api/users returns 200", async ({ request }) => {
  const response = await request.get("/api/users");
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  expect(body).toHaveLength(3);
  expect(body[0]).toHaveProperty("email");
});

test("POST /api/users validates input", async ({ request }) => {
  const response = await request.post("/api/users", {
    data: { name: "" }, // missing required fields
  });
  expect(response.status()).toBe(400);
});
```

---

## Cypress (secondary)

Use Cypress when the project already uses it. Don't introduce Cypress into a new project - Playwright is faster, has better parallel support, and tests all browsers.

Key differences from Playwright:
- Cypress runs in the browser process (same-origin only without workarounds)
- Cypress commands are chainable and auto-retry by default
- Cypress has no native multi-tab/multi-browser support
- Cypress `cy.intercept()` replaces Playwright's `page.route()` for network mocking

```javascript
// Cypress equivalent
describe("Checkout", () => {
  beforeEach(() => {
    cy.request("POST", "/api/test/seed", { user: "test@example.com" });
    cy.visit("/checkout");
  });

  it("completes purchase", () => {
    cy.findByLabelText("Card number").type("4242424242424242");
    cy.findByRole("button", { name: "Pay" }).click();
    cy.findByText("Order confirmed").should("be.visible");
  });
});
```

---

## Accessibility Testing

### Playwright + axe-core

The `@axe-core/playwright` package integrates axe-core into Playwright tests. Run accessibility scans as part of your regular E2E suite.

```typescript
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// Scan a full page
test("homepage passes WCAG 2.1 AA", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  expect(results.violations).toEqual([]);
});

// Scan a specific component
test("navigation menu is accessible", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page })
    .include("[data-testid='main-nav']")
    .analyze();
  expect(results.violations).toEqual([]);
});

// Exclude known issues (with tracking)
test("dashboard is accessible (known issues excluded)", async ({ page }) => {
  await page.goto("/dashboard");
  const results = await new AxeBuilder({ page })
    .exclude("#third-party-widget")  // tracked in JIRA-1234
    .withTags(["wcag2a", "wcag2aa"])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

### WCAG tag reference

| Tag | Standard | Level |
|-----|----------|-------|
| `wcag2a` | WCAG 2.0 | A (minimum) |
| `wcag2aa` | WCAG 2.0 | AA (standard target) |
| `wcag21a` | WCAG 2.1 | A |
| `wcag21aa` | WCAG 2.1 | AA (recommended target) |
| `wcag22aa` | WCAG 2.2 | AA (latest) |
| `best-practice` | axe best practices | beyond WCAG |

Target `wcag21aa` at minimum. Add `wcag22aa` for new projects.

### Custom accessibility fixtures

```typescript
// fixtures/accessibility.ts
import { test as base, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

type A11yFixtures = {
  makeAxeBuilder: () => AxeBuilder;
};

export const test = base.extend<A11yFixtures>({
  makeAxeBuilder: async ({ page }, use) => {
    await use(() =>
      new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    );
  },
});

// Usage in tests
test("page is accessible", async ({ page, makeAxeBuilder }) => {
  await page.goto("/settings");
  const results = await makeAxeBuilder().analyze();
  expect(results.violations).toEqual([]);
});
```

### Keyboard navigation testing

axe-core catches many issues, but keyboard navigation requires explicit testing:

```typescript
test("tab order follows visual order", async ({ page }) => {
  await page.goto("/form");

  // Tab through the form
  await page.keyboard.press("Tab");
  await expect(page.getByLabel("First name")).toBeFocused();

  await page.keyboard.press("Tab");
  await expect(page.getByLabel("Last name")).toBeFocused();

  await page.keyboard.press("Tab");
  await expect(page.getByLabel("Email")).toBeFocused();
});

test("modal traps focus", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Open dialog" }).click();

  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();

  // Focus should be inside the dialog
  const focused = page.locator(":focus");
  await expect(focused).toBeAttached();

  // Tab to the last element, then tab again - should cycle back
  for (let i = 0; i < 10; i++) {
    await page.keyboard.press("Tab");
  }

  // Focus should still be inside the dialog
  const stillFocused = await page.evaluate(() => {
    const dialog = document.querySelector("[role='dialog']");
    return dialog?.contains(document.activeElement);
  });
  expect(stillFocused).toBe(true);
});
```

---

## Visual Regression Testing

Screenshot comparison catches unintended visual changes. Useful after CSS refactors, dependency updates, or component library upgrades.

### Playwright built-in screenshots

```typescript
test("login page matches snapshot", async ({ page }) => {
  await page.goto("/login");
  // Wait for fonts and images to load
  await page.waitForLoadState("networkidle");
  await expect(page).toHaveScreenshot("login-page.png", {
    maxDiffPixels: 100,  // allow minor anti-aliasing differences
  });
});

// Component-level screenshot
test("button variants match snapshot", async ({ page }) => {
  await page.goto("/storybook/button");
  const button = page.getByTestId("primary-button");
  await expect(button).toHaveScreenshot("primary-button.png");
});
```

### Screenshot comparison tips

- **Mask dynamic content**: dates, avatars, ads - anything that changes between runs.
```typescript
await expect(page).toHaveScreenshot({
  mask: [page.getByTestId("timestamp"), page.getByTestId("avatar")],
});
```
- **Consistent viewport**: set in `playwright.config.ts`, not per-test.
- **Font loading**: wait for `networkidle` or explicitly wait for font load. Font rendering differences are the #1 cause of false positives.
- **CI vs local**: screenshots may differ between OS/GPU. Generate baseline screenshots in CI, not locally. Use `--update-snapshots` in CI to regenerate.
- **Threshold**: `maxDiffPixels` or `maxDiffPixelRatio` - start permissive, tighten as you gain confidence.

### Storybook + visual regression

For component libraries, test visual regression through Storybook:

```typescript
// Tests each Storybook story as a visual regression test
import { test, expect } from "@playwright/test";

const stories = ["Button--primary", "Button--secondary", "Card--default"];

for (const story of stories) {
  test(`visual: ${story}`, async ({ page }) => {
    await page.goto(`/storybook/iframe.html?id=${story}`);
    await page.waitForLoadState("networkidle");
    await expect(page.locator("#storybook-root")).toHaveScreenshot(`${story}.png`);
  });
}
```

---

## CI Integration for Browser Tests

### GitHub Actions

```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Run E2E tests
        run: npx playwright test --project=chromium
        env:
          CI: true

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
```

### Sharding across runners

```yaml
jobs:
  e2e:
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - name: Run tests (shard ${{ matrix.shard }}/4)
        run: npx playwright test --shard=${{ matrix.shard }}/4
```

### GitLab CI

```yaml
e2e:
  image: mcr.microsoft.com/playwright:v1.59.0-noble
  stage: test
  script:
    - npm ci
    - npx playwright test --project=chromium
  artifacts:
    when: always
    paths:
      - playwright-report/
    reports:
      junit: results.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Accessibility gate in CI

Fail the build on accessibility violations:

```typescript
// a11y.spec.ts - run as a separate CI job or as part of E2E
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const pages = ["/", "/about", "/login", "/dashboard", "/settings"];

for (const path of pages) {
  test(`a11y: ${path}`, async ({ page }) => {
    await page.goto(path);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();

    // Log violations for debugging
    for (const violation of results.violations) {
      console.log(`${violation.id}: ${violation.help} (${violation.nodes.length} instances)`);
    }

    expect(results.violations).toEqual([]);
  });
}
```

### Docker for consistent test environments

```dockerfile
FROM mcr.microsoft.com/playwright:v1.59.0-noble

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

CMD ["npx", "playwright", "test"]
```

Run browser tests in Docker to eliminate "works on my machine" issues. The official Playwright Docker image includes all browser dependencies pre-installed.
