# Output Contract

Report evidence, actionable findings, and verification limits without repeating the same summary in several formats. The user's requested format and location take precedence.

## When to report

An always-on audit skill reports each invocation. A conditional skill reports reviews of existing content; questions, teaching, new artifacts, and background prose cleanup need no audit report. "Full contract" means applying these rules, not expanding every response.

For up to three focused findings, use concise inline prose with priority, location, and suggested action. Say directly when there are no findings. For larger audits, group findings by priority and link the detailed report. Avoid duplicate conclusions, decorative borders, ANSI escapes, and padded columns.

Optional metadata for a substantial audit:

```text
SKILL code-review
STATUS complete
TARGET src/auth/
FINDINGS 3 open
VERIFICATION tests passed; deployment not checked
```

## Priorities

Use the same scale inline and in saved reports. Text carries the meaning; color is optional.

- P0 🔴 Must fix: broken functionality, security, or build.
- P1 🟠 Should fix: significant correctness or design bug.
- P2 🟡 Improvement: lower urgency.
- P3 🔵 Backlog: track for later.
- info ⚪ Informational: no action required.

Separate observed defects from recommendations. Include enough evidence to reproduce a finding and state uncertainty. Do not infer a passing check from an unrun command or hide incomplete coverage.

## Saved reports

Save audit findings unless the user requests otherwise. Default to
`docs/local/audits/<skill-name>/<YYYY-MM-DD>-<slug>.md`; use the bucket declared by the skill for other artifacts. Append `-2`, `-3`, etc. for collisions. Keep private reports out of version control.

Start with the skill, target, mode, date, scope, and verification state. Group findings under priority headings, omit empty groups, and number findings across the whole report. Each finding contains:

- [ ] **#1 Finding title**
  - **Location:** file and line, resource, or other precise target.
  - **Evidence:** observed behavior, impact, and reproduction or source.
  - **Suggested action:** concrete next step and how to verify it.
  - **Fix applied:** _to be filled by implementer_

Finish with fixed/open totals and material limitations. A repeated findings table is unnecessary.

## Applying findings

Audit-only requests authorize reporting, not edits. When fixes are requested, work in priority order within the user's scope. After each verified fix, change its checkbox to `[x]` and replace the placeholder with what changed and the check result; optionally include a commit ID. Leave deferred or failed fixes open and explain why. Update totals and report the final verification state. A recommendation is not a completed fix.
