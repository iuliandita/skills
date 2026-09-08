# Version pin receipts

Version receipts record which source was checked and when. This collection
is migrating version pins from dated prose to `references/versions.md`;
most skills still use the month-label convention. A receipt records a
verification claim, not proof that the source or version remains current.

## Mechanism

- When migrating a skill's version pins, put them in `references/versions.md`.
- That file has YAML frontmatter plus a human-readable table body describing
  the same pins for humans reading the rendered skill.
- `scripts/check-version-receipts.sh` validates every `references/versions.md`
  it finds under `skills/*/references/`. `scripts/check-freshness-dates.sh`
  skips its month-label check for any skill that has one (see
  "Interaction with the label gate" below).

## Frontmatter contract

This is the shape `scripts/check-version-receipts.sh` parses. Keys and
structure should follow this example. The values below illustrate the format;
they are not current version recommendations.

```yaml
---
checked_at: "2026-07-27"
checked_by: "manual"
pins:
  - tool: "Prometheus"
    version: "3.13.1"
    source: "https://github.com/prometheus/prometheus/releases"
  - tool: "Grafana"
    version: "13.1.1"
    source: "https://grafana.com/docs/grafana/latest/whatsnew/"
---
```

- `checked_at` (required) - `YYYY-MM-DD`. The date a human or agent actually
  confirmed the numbers below against `source`. It is a claim of work done,
  not a release date, and not a copy of whatever the label bump script wrote
  elsewhere.
- `checked_by` (required) - free text, e.g. `"manual"` or an agent identifier.
- `pins` (required) - a list of one or more entries. Each entry requires:
  - `tool` - the pinned tool's name.
  - `version` - the pinned version string, exactly as it should read in docs.
  - `source` - an `https://` URL a reader can follow to verify the version.
    `http://` is rejected.

The check validates receipt dates, nonempty pin entries, and HTTPS source
prefixes. It does not fetch sources, require receipts for unmigrated skills,
compare the table with frontmatter, or enforce the `checked_by` convention.
Those checks remain part of review.

## Staleness budget

**120 days.** If `checked_at` is more than 120 days before the date CI runs,
`scripts/check-version-receipts.sh` fails for that skill. Re-verify every pin
against its `source` and bump `checked_at`, or remove pins that are no longer
worth tracking. Override the budget locally with
`SKILLS_PIN_MAX_AGE_DAYS` (days) if you need to test a different threshold.

## SKILL.md bodies must not restate version numbers

Once a skill has `references/versions.md`, its `SKILL.md` must not carry the
version numbers directly - that reintroduces exactly the drift this mechanism
exists to prevent (two places to update, only one of them checked). Point at
the receipt file instead:

```markdown
**Target versions**: see `references/versions.md` (verified per the receipt date
in that file). Do not restate version numbers here.
```

## Interaction with the label gate

`scripts/check-freshness-dates.sh` still enforces the `**Target versions**
(Month Year):` label convention for any skill that has *not* migrated to a
receipt file - that is still most of the collection. The moment a skill grows
`references/versions.md`, the label check is skipped for that skill (it prints
a `note:` line saying so) because the receipt file's `checked_at` field is now
the source of truth for that skill's freshness.

Private overlays do not belong in the public version inventory. The receipt
checker searches recursively for `references/versions.md`, so keep private
notes under a different name.

## Adding receipts to a new skill

1. Create `skills/<name>/references/versions.md` with the frontmatter shape
   above, one `pins` entry per tracked tool.
2. Verify each `version` against its `source` right now, not from memory.
   Set `checked_at` to today's date.
3. Add a human-readable table body below the frontmatter listing the same
   pins, for readers of the rendered file.
4. Replace any inline version numbers in `SKILL.md` with a pointer to
   `references/versions.md`.
5. Run `./scripts/check-version-receipts.sh` and
   `./scripts/check-freshness-dates.sh` - both must exit 0, and the second
   must print the `note:` line for your skill.

## Migration status

[observability](../skills/observability/references/versions.md) provides an
existing receipt example. Discover the migrated skills directly:

```bash
rg --files skills -g versions.md
```

Migrate other skills when their pins are verified against primary sources.
Keep the label gate for skills that have not migrated; creating a receipt
without checking its sources does not establish freshness.
