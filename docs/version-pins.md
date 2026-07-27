# Version pin receipts

Skills that pin specific tool versions ("Prometheus 3.13.1", "Helm 4.2.3") back
that claim with a receipt file, not a month label in prose. A month label only
proves someone ran a find-and-replace; a receipt proves someone checked a
source and recorded when.

## Mechanism

- Any skill that pins tool versions carries `references/versions.md`.
- That file has YAML frontmatter plus a human-readable table body describing
  the same pins for humans reading the rendered skill.
- `scripts/check-version-receipts.sh` validates every `references/versions.md`
  it finds under `skills/*/references/`. `scripts/check-freshness-dates.sh`
  skips its month-label check for any skill that has one (see
  "Interaction with the label gate" below).

## Frontmatter contract

This is the shape `scripts/check-version-receipts.sh` parses. Keys and
structure must match exactly.

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

- `checked_at` (required) — `YYYY-MM-DD`. The date a human or agent actually
  confirmed the numbers below against `source`. It is a claim of work done,
  not a release date, and not a copy of whatever the label bump script wrote
  elsewhere.
- `checked_by` (required) — free text, e.g. `"manual"` or an agent identifier.
- `pins` (required) — a list of one or more entries. Each entry requires:
  - `tool` — the pinned tool's name.
  - `version` — the pinned version string, exactly as it should read in docs.
  - `source` — an `https://` URL a reader can follow to verify the version.
    `http://` is rejected.

## Staleness budget

**120 days.** If `checked_at` is more than 120 days before the date CI runs,
`scripts/check-version-receipts.sh` fails for that skill. Re-verify every pin
against its `source` and bump `checked_at`, or remove pins that are no longer
worth tracking. Override the budget locally with
`SKILLS_PIN_MAX_AGE_DAYS` (days) if you need to test a different threshold.

## SKILL.md bodies must not restate version numbers

Once a skill has `references/versions.md`, its `SKILL.md` must not carry the
version numbers directly — that reintroduces exactly the drift this mechanism
exists to prevent (two places to update, only one of them checked). Point at
the receipt file instead:

```markdown
**Target versions**: see `references/versions.md` (verified per the receipt date
in that file). Do not restate version numbers here.
```

## Interaction with the label gate

`scripts/check-freshness-dates.sh` still enforces the `**Target versions**
(Month Year):` label convention for any skill that has *not* migrated to a
receipt file — that is still most of the collection. The moment a skill grows
`references/versions.md`, the label check is skipped for that skill (it prints
a `note:` line saying so) because the receipt file's `checked_at` field is now
the source of truth for that skill's freshness.

`skills/cluster-health/protected/` stays excluded from both checks, as it
already was from the label gate.

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
   `./scripts/check-freshness-dates.sh` — both must exit 0, and the second
   must print the `note:` line for your skill.

## Current status

Only `observability` uses this mechanism so far (see plan 007). Migrating the
remaining skills is tracked as a follow-up (plan 013+), done in batches by
category so each batch's receipts can be verified in one research pass. Once
every skill that pins versions has a receipt, `scripts/check-freshness-dates.sh`
should be deleted outright rather than kept as a vestigial gate.
