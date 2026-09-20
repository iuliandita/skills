# String Audit Patterns

Grep commands for finding hardcoded user-facing strings, organized by category and framework.
Use these during Step 3 of the i18n workflow.

These patterns catch the most common sources of missed strings. Run them against `src/` (or
your project's source directory). Adapt file extensions to your project.

---

## Universal Patterns (any framework)

These work regardless of UI framework.

### Toast / notification messages

```bash
# Common toast libraries
grep -rn "toast\.\(success\|error\|info\|warning\|warn\)" --include='*.ts' --include='*.tsx' src/
grep -rn "notify\|notification\|addToast\|showToast\|enqueueSnackbar" --include='*.ts' --include='*.tsx' src/
```

**What to look for:** string arguments and template literals inside toast/notification calls.
Dynamic parts (like service names) need interpolation placeholders.

### Validation / error messages

```bash
# Common patterns for form validation
grep -rn "setError\|setFieldError\|addError\|setMessage" --include='*.ts' --include='*.tsx' src/
grep -rn "message:\s*['\"]" --include='*.ts' --include='*.tsx' src/
grep -rn "throw new Error('[A-Z]" --include='*.ts' --include='*.tsx' src/
```

**What to look for:** string literals passed to error state setters. These are user-facing
even though they live in logic code, not templates. Note: `throw new Error()` messages need
manual review - many are caught internally and never shown to users. Only translate errors
that surface in the UI.

### Confirm dialogs

```bash
grep -rn "confirm(" --include='*.ts' --include='*.tsx' src/
grep -rn "window\.confirm\|window\.alert\|window\.prompt" --include='*.ts' --include='*.tsx' src/
```

### Document / page titles

```bash
grep -rn "document\.title\s*=" --include='*.ts' --include='*.tsx' src/
grep -rn "<title>" --include='*.tsx' --include='*.html' src/
```

### Intl formatting with hardcoded locale

```bash
grep -rn "Intl\.\(DateTimeFormat\|NumberFormat\|RelativeTimeFormat\)" src/ | grep -E "'en|\"en"
grep -rn "toLocaleString\|toLocaleDateString\|toLocaleTimeString" src/ | grep -E "'en|\"en"
```

---

## React / JSX Patterns

### Text content in JSX elements

```bash
# Elements with literal text content (starts with uppercase = likely a sentence)
grep -rn '>[A-Z][a-z]' --include='*.tsx' --include='*.jsx' src/

# Ternary expressions with string literals in JSX
grep -rn "? '[A-Z]\|: '[A-Z]" --include='*.tsx' --include='*.jsx' src/

# Template literals in JSX (often interpolated messages)
grep -rn '>\s*{`' --include='*.tsx' --include='*.jsx' src/
```

### Attribute values

```bash
# Placeholder attributes
grep -rn 'placeholder="[A-Za-z]' --include='*.tsx' --include='*.jsx' src/
grep -rn "placeholder='[A-Za-z]" --include='*.tsx' --include='*.jsx' src/
# Bound placeholder with string expression (check value is hardcoded, not t())
grep -rn 'placeholder={' --include='*.tsx' --include='*.jsx' src/ | grep -v "t("

# Accessibility attributes
grep -rn 'aria-label="[A-Za-z]' --include='*.tsx' --include='*.jsx' src/
grep -rn "aria-label='[A-Za-z]" --include='*.tsx' --include='*.jsx' src/
grep -rn 'aria-labelledby\|aria-describedby' --include='*.tsx' --include='*.jsx' src/

# Title and alt attributes
grep -rn 'title="[A-Za-z]' --include='*.tsx' --include='*.jsx' src/
grep -rn "title='[A-Za-z]" --include='*.tsx' --include='*.jsx' src/
grep -rn 'alt="[A-Za-z]' --include='*.tsx' --include='*.jsx' src/
grep -rn "alt='[A-Za-z]" --include='*.tsx' --include='*.jsx' src/
```

### Loading and conditional states

```bash
# Common loading text patterns
grep -rn "'Loading\|\"Loading\|'Saving\|\"Saving\|'Applying\|\"Applying" --include='*.tsx' --include='*.jsx' src/

# Conditional text fragments
grep -rn "'(not \|\"(not \|'(no \|\"(no " --include='*.tsx' --include='*.jsx' src/

# Ternary with short strings (often loading states or toggle labels)
grep -rn "? '[a-z]\|: '[a-z]" --include='*.tsx' --include='*.jsx' src/ | grep -v "import\|require\|from "
```

### Select / option elements

```bash
grep -rn '<option[^>]*>[A-Z]' --include='*.tsx' --include='*.jsx' src/
grep -rn '<option value=' --include='*.tsx' --include='*.jsx' src/
```

### Table headers

```bash
grep -rn '<th[^>]*>[A-Z]' --include='*.tsx' --include='*.jsx' src/
```

### Empty states and fallbacks

```bash
grep -rn "'No \|\"No \|'None\|\"None\|'Nothing\|\"Nothing" --include='*.tsx' --include='*.jsx' src/
grep -rn "'not found\|\"not found\|'empty\|\"empty" --include='*.tsx' --include='*.jsx' src/ | grep -iv "import\|const\|404"
```

---

## Vue Template Patterns

### Text content

```bash
# Literal text in templates (between tags)
grep -rn '>[A-Z][a-z]' --include='*.vue' src/

# Text outside v-if/v-else blocks
grep -rn 'v-else>[A-Z]' --include='*.vue' src/
```

### Attribute values

```bash
# Static attributes (not bound with :)
grep -rn 'placeholder="[A-Za-z]' --include='*.vue' src/
grep -rn 'aria-label="[A-Za-z]' --include='*.vue' src/
grep -rn 'title="[A-Za-z]' --include='*.vue' src/
grep -rn 'alt="[A-Za-z]' --include='*.vue' src/

# Bound attributes with string literals
grep -rn ':placeholder="'"'"'[A-Za-z]' --include='*.vue' src/
grep -rn ':title="'"'"'[A-Za-z]' --include='*.vue' src/
```

### Vue 3 composition API patterns

```bash
# vue-i18n composable: const { t } = useI18n() - check for hardcoded strings
# in files that already use useI18n (partially migrated)
grep -rl "useI18n" --include='*.vue' --include='*.ts' src/ | \
  xargs grep -El '>[A-Z][a-z]|placeholder="[A-Z]' 2>/dev/null

# v-t directive usage (alternative to $t() in vue-i18n)
grep -rn 'v-t="' --include='*.vue' src/

# <i18n> SFC blocks (inline per-component translations)
grep -rn '<i18n' --include='*.vue' src/
```

### Script section

```bash
# Strings in component logic (same as universal patterns but scoped to .vue)
grep -rn "toast\.\|notify\|setError\|confirm(" --include='*.vue' src/
```

---

## Svelte Template Patterns

### Text content

```bash
grep -rn '>[A-Z][a-z]' --include='*.svelte' src/
```

### Attribute values

```bash
grep -rn 'placeholder="[A-Za-z]' --include='*.svelte' src/
grep -rn 'aria-label="[A-Za-z]' --include='*.svelte' src/
grep -rn 'title="[A-Za-z]' --include='*.svelte' src/
grep -rn 'alt="[A-Za-z]' --include='*.svelte' src/
```

---

## Angular Template Patterns

Angular has two i18n approaches: the built-in `@angular/localize` with `i18n` attributes
and compile-time extraction, or third-party libraries like `@ngx-translate/core`. The
patterns below find strings regardless of which approach is used.

### Text content

```bash
grep -rn '>[A-Z][a-z]' --include='*.html' src/

# Check for elements missing the i18n attribute (Angular built-in i18n)
# Elements with text content but no i18n attribute need extraction
grep -rn '>[A-Z][a-z]' --include='*.html' src/ | grep -v 'i18n'
```

### Attribute values

```bash
grep -rn 'placeholder="[A-Za-z]' --include='*.html' src/
grep -rn 'aria-label="[A-Za-z]' --include='*.html' src/
grep -rn 'title="[A-Za-z]' --include='*.html' src/

# Bound attributes with hardcoded strings
grep -rn '\[attr\.placeholder\]="' --include='*.html' src/
grep -rn '\[attr\.aria-label\]="' --include='*.html' src/

# Check component TS files for strings in decorators and class properties
grep -rn "title:\s*'[A-Z]\|label:\s*'[A-Z]\|message:\s*'[A-Z]" --include='*.ts' src/

# $localize template tags (Angular built-in)
grep -rn '\$localize' --include='*.ts' src/
```

---

## Vanilla JS / TS Patterns

For apps without a component framework - plain DOM manipulation, web components, or
server-rendered pages with client-side JS.

### DOM text assignment

```bash
# Direct text content assignment
grep -rn "\.textContent\s*=" --include='*.ts' --include='*.js' src/
grep -rn "\.innerText\s*=" --include='*.ts' --include='*.js' src/
grep -rn "\.innerHTML\s*=" --include='*.ts' --include='*.js' src/

# insertAdjacentText / insertAdjacentHTML with string literals
grep -rn "insertAdjacentText\|insertAdjacentHTML" --include='*.ts' --include='*.js' src/
```

### Attribute assignment

```bash
# setAttribute with user-facing attributes
grep -rn "setAttribute('placeholder'\|setAttribute(\"placeholder\"" --include='*.ts' --include='*.js' src/
grep -rn "setAttribute('aria-label'\|setAttribute(\"aria-label\"" --include='*.ts' --include='*.js' src/
grep -rn "setAttribute('title'\|setAttribute(\"title\"" --include='*.ts' --include='*.js' src/
grep -rn "setAttribute('alt'\|setAttribute(\"alt\"" --include='*.ts' --include='*.js' src/

# Direct property assignment
grep -rn "\.placeholder\s*=\s*['\"]" --include='*.ts' --include='*.js' src/
grep -rn "\.title\s*=\s*['\"]" --include='*.ts' --include='*.js' src/
```

---

## False Positives to Skip

Not every string needs translation. Skip:

| Pattern | Why |
|---------|-----|
| `console.log`, `console.error`, `console.warn` | Developer-facing, not shown to users |
| CSS class names | `className="text-sm font-bold"` |
| Data attributes | `data-testid="submit-btn"` |
| URL paths and route patterns | `'/api/auth/login'` |
| Environment variable names | `process.env.DATABASE_URL` |
| Import/require paths | `import { foo } from './bar'` |
| Type/interface definitions | Not runtime strings |
| Technical identifiers | Event names, enum values, key constants |
| Brand names used as code values | `provider === 'Spotify'` (the comparison, not the UI label) |
| Log messages for debugging | Only shown in browser console or server logs |

**Edge case: service/brand alt text.** `alt="Spotify"` on a Spotify logo icon is an
accessibility concern. Whether to translate depends on the language - some keep the brand
name, others add a generic descriptor. Decide per project.

---

## Post-Audit Verification

After extracting strings from all files, run a reverse check:

```bash
# Find files that still have hardcoded strings but also use t()
# These are partially-migrated files - the most dangerous state
# Covers: react-i18next (useTranslation), next-intl (useTranslations with 's'),
#         vue-i18n ($t, useI18n), custom (useI18n, t()imports)
grep -rEl "useI18n|useTranslation|useTranslations|\\\$t\(|FormattedMessage" \
  --include='*.tsx' --include='*.jsx' --include='*.vue' --include='*.ts' src/ | \
  xargs grep -El '>[A-Z][a-z]|placeholder="[A-Z]|aria-label="[A-Z]' 2>/dev/null
```

Files that appear in this output use the translation function but still have hardcoded
strings - they were partially audited and need another pass.

For Svelte (`svelte-i18n`, Paraglide) and Angular (`$localize`, `translate` pipe),
the function names vary more widely. Check those files manually or adapt the grep
to match the project's specific i18n function.
