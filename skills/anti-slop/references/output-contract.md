# Output Contract

How a skill reports its findings: an inline surface in the transcript and a written deliverable file. The two shapes below are intentionally different.

## Two surfaces

The contract has two intentionally divergent shapes:

- **Inline (transcript):** monospace metadata header -> severity-grouped summary -> concise monospace conclusion. Scan-friendly, transient, and stable across desktop Markdown renderers and terminals.
- **File (deliverable):** pure markdown - H1/H2 grouped by priority, native `- [ ]` checkboxes per finding, full per-finding detail, "Fix applied" placeholder for the implementer. Renders properly in GitHub, GitLab, VS Code, Obsidian.

## Inline format

### Choose the reporting size

The user's explicit output instructions take precedence over these defaults, including
requests for inline-only output or no file writes. Skill sections that say "full contract"
select this contract; they do not override the size selection here.

For a small, focused review (one concern with up to three findings), use compact inline
output: state the result, list actionable findings with priority and location, and give
verification limits plus one link if a report was saved. For zero findings, say so directly.
Omit metadata fences, severity headings, and a repeated conclusion in this form. Save the
report unless the user requested otherwise; keep detailed run metadata there.

For substantial or multi-area audits, use the expanded format below. Do not append another
skill-specific run summary that repeats its metadata. An explicitly requested report format
overrides either default.

### Monospace header

Use a fenced `text` block so desktop apps and terminals render the metadata with a monospace font. Do not pad fields to a fixed width.

```text
SKILL         CODE-REVIEW
STATUS        complete
TARGET        src/auth/
FINDINGS      5 (P0:2, P1:1, P2:1, P3:0, info:1)
VERIFICATION  passed
DELIVERABLE   docs/local/audits/code-review/2026-05-03-auth-review.md
```

Skill name is the directory name uppercased (`code-review` -> `CODE-REVIEW`). Omit optional metadata fields only when no meaningful value exists; always include skill, status, findings, verification, and deliverable.

### Severity summary

Use literal labels plus color markers. The text carries the meaning; color is supplemental:

P0 🔴  P1 🟠  P2 🟡  P3 🔵  info ⚪

Group findings by severity and omit empty groups. Put the marker in the Markdown heading, outside the aligned text block:

### P0 🔴

```text
1  Missing CSRF check on POST /api/posts
2  SQL injection through the search parameter
```

### P1 🟠

```text
3  Race condition in the worker reconnect path
```

### P2 🟡

```text
4  Repeated authentication helper should be extracted
```

### info ⚪

```text
5  Filename convention drift under src/utils/
```

Each line contains only the report number and a concise summary. Full evidence and actions belong in the linked deliverable.

### Monospace conclusion

Do not repeat every finding in an inline table. End with a compact fenced block:

```text
CONCLUSION    5 findings; 2 must-fix, 1 should-fix, 1 improvement, 1 info
VERIFICATION  passed
DELIVERABLE   docs/local/audits/code-review/2026-05-03-auth-review.md
NEXT          address P0 findings before merge
```

Do not emit ANSI escape sequences, HTML styling, Unicode box-drawing borders, or aligned emoji columns. These forms render inconsistently across desktop and terminal clients.

## File format (deliverable)

Pure markdown. No box-drawing characters. Renders in any viewer; `- [ ]` checkboxes are interactive in GitHub, GitLab, VS Code, Obsidian.

```markdown
# CODE-REVIEW - src/auth/ - 2026-05-03

- **Skill:** code-review
- **Mode:** audit
- **Target:** `src/auth/`
- **Started:** 2026-05-03T14:22Z
- **Findings:** 5 (P0:2, P1:1, P2:1, info:1)

---

## P0 - Must fix

- [ ] **#1 Missing CSRF check on POST /api/posts**
  - **File:** `src/auth/routes.ts:42`
  - **Description:** Handler accepts state-changing requests without verifying CSRF token. Any logged-in user on a malicious page can trigger posts on behalf of the victim.
  - **Suggested action:** Add `requireCsrf()` middleware before the route handler.
  - **Fix applied:** _to be filled by implementer_

- [ ] **#2 SQL injection via search param**
  - **File:** `src/auth/search.ts:88`
  - **Description:** `q` parameter is concatenated into the query string without parameterization.
  - **Suggested action:** Switch to prepared statement with `$1` binding.
  - **Fix applied:** _to be filled by implementer_

## P1 - Should fix

- [ ] **#3 Race condition in worker pool reconnect path**
  - **File:** `src/worker/pool.go:142`
  - **Description:** When N connections exceed pool_max during a reconnect storm, the gate releases before the new conn registers, allowing duplicates.
  - **Suggested action:** Wrap reconnect in a semaphore acquired before pool registration.
  - **Fix applied:** _to be filled by implementer_

## P2 - Nice to fix

- [ ] **#4 Extract repeated auth helper**
  - **File:** `src/auth/helpers.ts:12,55,89`
  - **Description:** Same 8-line cookie-decode block appears in three handlers.
  - **Suggested action:** Extract to `decodeAuthCookie()` in `src/auth/cookie.ts`.
  - **Fix applied:** _to be filled by implementer_

## Info

- [ ] **#5 Naming convention drift in /utils**
  - **File:** `src/utils/`
  - **Description:** Mix of `camelCase` and `snake_case` filenames; repo convention is `kebab-case`.
  - **Suggested action:** Rename in a follow-up PR.
  - **Fix applied:** _to be filled by implementer_

---

## Conclusion

| #  | Type   | Priority | Summary                                | Action     |
|----|--------|----------|----------------------------------------|------------|
| 1  | found  | P0       | Missing CSRF check on /api/posts       | recommend  |
| 2  | found  | P0       | SQL injection via search param         | recommend  |
| 3  | found  | P1       | Race condition in worker pool reconnect| recommend  |
| 4  | rec    | P2       | Extract repeated auth helper           | proposed   |
| 5  | rec    | info     | Naming convention drift in /utils      | proposed   |
```

Notes:

- Header is markdown H1 + a small bullet list of metadata. No box-drawing characters in the file.
- Findings grouped by priority section. Sections with zero findings are omitted.
- Each finding is a top-level `- [ ]` checkbox with bolded `#N Title`. Sub-bullets carry `File`, `Description`, `Suggested action`, `Fix applied`.
- Numbering (`#1`, `#2`, ...) is monotonic across the whole report, not per-section. The conclusion table at the bottom uses the same numbers.
- Conclusion is a standard markdown table in the file. The inline surface uses the concise monospace conclusion instead.

### Deliverable filename

`docs/local/<bucket>/<skill-name>/<YYYY-MM-DD>-<slug>.md`

If the same skill writes twice in one day, append `-2`, `-3`, etc. to the slug.

## Severity / priority scale

One scale, used in both inline and file:

| Label  | Meaning                                              | File section heading       |
|--------|------------------------------------------------------|----------------------------|
| `P0`   | Must fix - breaks functionality, security, or build  | `## P0 - Must fix`         |
| `P1`   | Should fix - significant correctness or design bug   | `## P1 - Should fix`       |
| `P2`   | Nice to fix - improvement, lower urgency             | `## P2 - Nice to fix`      |
| `P3`   | Backlog - track but not now                          | `## P3 - Backlog`          |
| `info` | Informational - no action required                   | `## Info`                  |

Skills currently using a different scale must migrate. Document the old -> new mapping inline at the top of the affected skill's `## Output Contract` section as a 3-5 line note.

## Storage layout

```
docs/local/
  prompts/         # prompt-generator outputs
  audits/          # audit / review / scan reports (the checkbox-style files)
  plans/           # reserved for upstream skills (e.g. superpowers:writing-plans)
  specs/           # reserved for upstream skills (e.g. superpowers:brainstorming)
  deliverables/    # catch-all (sketches, generated docs, ad-hoc artifacts)
```

`plans/` and `specs/` are reserved for upstream skills. Repo-owned skills MUST NOT default to those buckets unless they genuinely produce a plan or spec artifact.

## Mode detection

Each skill declares one of two modes in its `## Output Contract` section:

- **Always-on:** every invocation emits the full contract. Used by audit/report skills (code-review, anti-slop, security-audit, deep-audit, full-review, update-docs, code-slimming).

- **Conditional:** the agent applies this rule per invocation:

  > When invoked to **analyze, review, audit, or improve** existing repo content, emit the full contract and write a deliverable file to the declared bucket. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.

  A conditional skill may also run as a background filter on the agent's own output, with no
  target artifact at all (anti-ai-prose does this). That path emits no contract, no deliverable,
  and no announcement: there is nothing to report on, so reporting would be noise. Only an
  invocation against a real target produces a deliverable.

## Fix protocol

**Layer 1 - Convention.** Any agent reading a deliverable file with `- [ ]` checkboxes and `_to be filled by implementer_` placeholders understands the protocol: as fixes land, flip the box to `- [x]`, replace the italic placeholder with a one-line description of what was actually done. Optionally append a commit SHA in parentheses.

Example, before:

```markdown
- [ ] **#1 Missing CSRF check on POST /api/posts**
  ...
  - **Fix applied:** _to be filled by implementer_
```

After:

```markdown
- [x] **#1 Missing CSRF check on POST /api/posts**
  ...
  - **Fix applied:** Added `requireCsrf()` middleware to all state-changing /api routes (a1b2c3d).
```

**Layer 2 - Same-conversation auto-fill.** When the user invokes a skill in audit-and-fix mode (e.g., "review my repo and fix what you find"), the agent:

1. Runs the audit skill, writes the report to `docs/local/audits/<skill>/<date>-<slug>.md`.
2. Iterates findings in priority order (P0 first).
3. For each finding: implements the fix, updates the report file in place (checkbox -> `[x]`, placeholder -> one-line fix description), optionally commits the change atomically.
4. After the loop, updates the saved Markdown conclusion table and emits a concise inline conclusion with the new fixed/open totals and verification state.

Layer 3 (a dedicated `apply-report` skill that takes a report path and runs the loop without re-running the auditor) is a future follow-up, not part of this contract.
