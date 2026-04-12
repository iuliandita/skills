# Translation Quality

How to produce machine translations that read naturally in context rather than as mechanical
word-by-word output. Covers prompting strategy, voice consistency, protected terms, and
validation.

---

## Context-Aware Translation

The difference between good and bad machine translation is context. "Save" can be "Guardar"
(store data) or "Ahorrar" (save money) in Spanish. Without knowing the app's domain, an LLM
guesses - and often guesses wrong for domain-specific terms.

### Prompt structure

Every translation prompt should include:

1. **App description** - what the app does, who uses it, what domain it operates in.
   "A music discovery app for managing artist libraries" is enough. Don't write a paragraph.
2. **Target context** - these are UI strings (buttons, labels, toasts, validation errors),
   not prose or documentation.
3. **Voice register** - formal or informal, with the specific pronoun form for the language.
4. **Protected terms** - brand names and technical terms that must stay untranslated.
5. **Preservation rules** - placeholders, line breaks, punctuation patterns.

### Full prompt template

```
You are translating UI strings for [APP DESCRIPTION].

Source language: [SOURCE LOCALE]
Target language: [TARGET LOCALE]
Voice: [REGISTER] - use [PRONOUN FORM] consistently.

These are UI strings (buttons, labels, toast messages, form validation errors, empty states).
Translate for natural reading in context, not word-by-word accuracy. A native speaker using
this app should feel the interface was written for them.

Return a JSON object with the exact same keys. No markdown fences, no commentary, no
explanation. JSON only.

Preserve exactly as-is:
- Placeholders: {0}, {1}, {name}, {{var}}, %s, %d - same count, same order, same syntax
- Line breaks within values
- Brand and product names: [LIST OF PROTECTED TERMS]

Do not:
- Add or remove placeholders
- Change placeholder syntax (e.g., {0} to {name})
- Translate brand names or technical identifiers
- Add honorifics or formality markers not present in the source
- Use different register (formal/informal) across strings
```

### Example with context

Bad prompt (no context):
```
Translate this JSON from English to German: {"save": "Save", "discover": "Discover"}
```

Good prompt (with context):
```
You are translating UI strings for a music discovery app that helps users find
new artists based on their library.

Source: en. Target: de. Voice: informal (du-Form).

{"save": "Save", "discover": "Discover new music"}
```

The bad prompt might translate "Discover" as "Entdecken" (generic). The good prompt
produces "Neue Musik entdecken" which fits the UI context.

---

## Voice Consistency

Mixed formality within an app feels broken. A button saying "Melde dich an" (informal)
next to a tooltip saying "Bitte melden Sie sich an" (formal) is jarring.

### Register decisions per language

Decide before translating. Document the decision so every future translation batch stays
consistent.

This table covers common target languages. It is a representative subset - for languages
not listed, research the conventional UI register before translating.

| Language | Common UI register | Pronoun form |
|----------|-------------------|--------------|
| German | Informal for consumer apps, formal for enterprise. SaaS tiebreaker: prefer formal - easier to relax later than retrofit | du/Sie |
| French | Informal trending in tech UIs, formal for finance/gov | tu/vous |
| Spanish | Varies by region - informal common in tech | tu/usted |
| Portuguese (BR) | Informal dominant in tech | voce/o senhor |
| Italian | Informal common for consumer apps | tu/Lei |
| Dutch | Informal standard in tech | je/jij vs u |
| Polish | Mixed - 2nd person or infinitive common | ty/Pan(i) |
| Turkish | Informal for consumer, formal for institutional | sen/siz |
| Russian | Informal for consumer apps | ty/vy |
| Ukrainian | Informal for consumer apps | ty/vy |
| Japanese | Polite form (desu/masu) standard for UI | N/A (use desu/masu) |
| Korean | Polite form (haeyo) standard for UI | N/A (use haeyo-che) |
| Chinese | No pronoun formality, but tone varies | Neutral/direct |

### Enforcing consistency

After generating translations, spot-check for register mixing:

```bash
# German: check for Sie/Ihr mixed with du/dein
grep -n "Sie \|Ihr \|Ihnen\|Ihrem\|Ihres" messages/de.ts
grep -n " du \| dein\| dich\| dir " messages/de.ts

# French: check for vous mixed with tu
grep -n " vous \| votre \| vos " messages/fr.ts
grep -n " tu \| ton \| ta \| tes \| toi " messages/fr.ts

# Spanish: check for usted mixed with tu
grep -n " usted\| su \| sus " messages/es.ts | grep -iv "Spotify\|Discord"  # filter brand names with "su"
grep -n " tu \| tus \| ti " messages/es.ts
```

If both patterns appear, the catalog has mixed register. Fix before committing.

### CJK and length-sensitive locales

Japanese, Korean, and Chinese translations are often shorter than English, but German,
French, and Finnish commonly expand 20-40%. This affects:

- **Button labels** - may overflow or wrap unexpectedly
- **Table headers** - column widths may need to flex
- **Placeholder text** - input fields may truncate long translations

No catalog-level fix exists for this - it is a UI/CSS concern. But flag it during
translation review: if a translated string is significantly longer than the source, note
it so the UI can be tested. For CJK locales, verify that full-width punctuation
(period, comma, parentheses) is used where the locale convention expects it.

---

## Protected Terms

Brand names, product names, and technical identifiers that must not be translated.

### Building the list

Start with:
- The app's own name
- Third-party service names the app integrates with
- Technical terms that are industry-standard in English (API, URL, JSON, etc.)
- Open source project names

### Validation

After translation, verify protected terms appear exactly:

```typescript
function countOccurrences(str: string, sub: string): number {
  let count = 0, pos = 0
  while ((pos = str.indexOf(sub, pos)) !== -1) { count++; pos += sub.length }
  return count
}

function validateProtectedTerms(
  sourceCatalog: Record<string, string>,
  targetCatalog: Record<string, string>,
  protectedTerms: string[],
): string[] {
  const errors: string[] = []
  for (const key of Object.keys(sourceCatalog)) {
    const source = sourceCatalog[key]
    const translated = targetCatalog[key]
    if (!source || !translated) continue
    for (const term of protectedTerms) {
      const sourceCount = countOccurrences(source, term)
      if (sourceCount === 0) continue
      const translatedCount = countOccurrences(translated, term)
      if (translatedCount !== sourceCount)
        errors.push(`${key}: "${term}" count mismatch (${sourceCount} vs ${translatedCount})`)
    }
  }
  return errors
}
```

### Edge cases

- **Case sensitivity**: "spotify" vs "Spotify" - protect both forms if both appear
- **Compound terms**: "OpenAI-compatible" should stay as-is, not become "compatible con OpenAI"
- **Names inside sentences**: "Connect Spotify in Settings" - "Spotify" and "Settings" may
  have different protection rules. "Settings" is a UI label that should be translated;
  "Spotify" is a brand that should not.

---

## Placeholder Validation

Placeholders are the most fragile part of translated strings. A missing `{0}` in a translated
string causes a visible `{0}` in the UI or a silent rendering bug.

### Detection pattern

```typescript
// Covers: {0}, {name}, {{var}}, ${expr}, %s/%d, and ICU {count, plural, ...}
const PLACEHOLDER_PATTERN = /\$\{[^}]+\}|\{\{[^}]+\}\}|\{[A-Za-z0-9_]+(?:,[^}]*)?\}|%[sdif]/g
const LINE_BREAK_PATTERN = /\r\n|\n|\r/g

function validatePlaceholders(
  sourceCatalog: Record<string, string>,
  translatedCatalog: Record<string, string>,
): string[] {
  const errors: string[] = []

  for (const key of Object.keys(sourceCatalog)) {
    const source = sourceCatalog[key]
    const translated = translatedCatalog[key]
    if (!source || !translated) continue

    // Placeholder count and order
    const sourcePH = source.match(PLACEHOLDER_PATTERN) ?? []
    const translatedPH = translated.match(PLACEHOLDER_PATTERN) ?? []
    if (sourcePH.join(',') !== translatedPH.join(',')) {
      errors.push(`${key}: placeholder mismatch - source [${sourcePH}] vs translated [${translatedPH}]`)
    }

    // Line break preservation
    const sourceLB = source.match(LINE_BREAK_PATTERN) ?? []
    const translatedLB = translated.match(LINE_BREAK_PATTERN) ?? []
    if (sourceLB.length !== translatedLB.length) {
      errors.push(`${key}: line break count mismatch`)
    }
  }

  return errors
}
```

### Common placeholder formats

| Format | Example | Common in |
|--------|---------|-----------|
| Positional | `{0}`, `{1}` | Custom i18n, simple interpolation |
| Named | `{name}`, `{count}` | i18next, most libraries |
| Double-brace | `{{name}}` | Angular, some custom setups |
| ICU MessageFormat | `{count, plural, one {# item} other {# items}}` | react-intl, FormatJS, i18next with ICU plugin |
| Printf-style | `%s`, `%d` | Older codebases, Node.js util.format |
| Template literal | `${variable}` | Should not appear in catalogs - extract first |

If `${variable}` appears in a catalog value, it means a template literal was copied directly
instead of being converted to a placeholder pattern. Fix the source catalog first.

---

## Complete Validation Script

Combines all checks into a single validation pass:

```typescript
interface ValidationResult {
  locale: string
  missing: string[]
  extra: string[]
  empty: string[]
  placeholderErrors: string[]
  protectedTermErrors: string[]
}

function validateCatalog(
  sourceKeys: string[],
  sourceCatalog: Record<string, string>,
  targetCatalog: Record<string, string>,
  locale: string,
  protectedTerms: string[],
): ValidationResult {
  const keys = Object.keys(targetCatalog)
  const missing = sourceKeys.filter(k => !(k in targetCatalog))
  const extra = keys.filter(k => !sourceKeys.includes(k))
  const empty = sourceKeys.filter(k => targetCatalog[k]?.trim() === '')

  const placeholderErrors = validatePlaceholders(sourceCatalog, targetCatalog)
  const protectedTermErrors = validateProtectedTerms(sourceCatalog, targetCatalog, protectedTerms)

  return { locale, missing, extra, empty, placeholderErrors, protectedTermErrors }
}

function validateAll(
  sourceCatalog: Record<string, string>,
  locales: string[],
  getCatalog: (locale: string) => Record<string, string>,
  protectedTerms: string[],
): ValidationResult[] {
  const sourceKeys = Object.keys(sourceCatalog)
  return locales.map(locale =>
    validateCatalog(sourceKeys, sourceCatalog, getCatalog(locale), locale, protectedTerms)
  )
}
```

### CI integration

Add to the project's test or lint script:

```json
{
  "scripts": {
    "i18n:check": "bun scripts/i18n-check.ts",
    "pretest": "bun run i18n:check"
  }
}
```

The validation script should exit non-zero on any finding. In CI, this blocks merging PRs
that introduce untranslated keys.

---

## Translation Batch Strategy

For large catalogs (500+ keys), translate in batches to stay within LLM context limits
and catch errors early.

### Recommended approach

1. **Batch by namespace** - group keys by their dot-notation prefix (`auth.*`, `settings.*`).
   This gives the LLM semantic context for each batch.
2. **One locale at a time** - translate all batches for one locale, validate, then move
   to the next. Don't interleave.
3. **Validate between batches** - run placeholder checks after each batch, not just at the end.
4. **Merge carefully** - when combining batches, check for duplicate keys (can happen if
   namespaces were split inconsistently).

### Handling large catalogs

If the catalog exceeds the LLM's output token limit:

- Split into chunks of ~200 keys
- Include 2-3 translated keys from the previous chunk as context anchors
- Reassemble and validate the complete catalog before committing

### Incremental updates

When adding new keys to an existing catalog:

1. Extract only the new/changed keys from the source catalog
2. Include 5-10 existing translated keys as "style reference" so the LLM matches the
   established voice
3. Translate the new keys
4. Merge into the existing target catalog
5. Validate the complete catalog
