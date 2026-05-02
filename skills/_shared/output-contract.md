# Output Contract — Single Source of Truth

This file is the canonical output contract for every public skill in iuliandita/skills. Each `skills/<name>/SKILL.md` references this file from a `## Output Contract` section and declares its mode (always-on or conditional) and deliverable bucket.

This directory has no `SKILL.md`, so `install.sh`, `scripts/lint-skills.sh`, and `scripts/validate-spec.sh` skip it. Do not add a `SKILL.md` here.

## Two surfaces

The contract has two intentionally divergent shapes:

- **Inline (transcript):** boxed Unicode-art header → compact body summary → boxed conclusion header → boxed conclusion table. Visual identity, scan-friendly, transient.
- **File (deliverable):** pure markdown — H1/H2 grouped by priority, native `- [ ]` checkboxes per finding, full per-finding detail, "Fix applied" placeholder for the implementer. Renders properly in GitHub, GitLab, VS Code, Obsidian.

## Inline format

### Header box

Double-line, exactly 80 characters wide, variable height. No figlet/toilet runtime detection — boxes are static text the model emits directly.

Minimum form (3 lines):

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  CODE-REVIEW  →  docs/local/audits/code-review/2026-05-03-auth-review.md     ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

Extended form (when surfacing mode/target/started):

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  CODE-REVIEW                                                                 ║
║  Mode: audit  ·  Target: src/auth/  ·  Started: 2026-05-03T14:22Z            ║
║  Deliverable: docs/local/audits/code-review/2026-05-03-auth-review.md        ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

Conclusion header (same shape, name suffixed `· CONCLUSION`):

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  CODE-REVIEW · CONCLUSION                                                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

Skill name is the directory name uppercased (`code-review` → `CODE-REVIEW`).

### Conclusion table

All-double Unicode box-drawing, fixed 80 chars wide, fixed 5 columns:

```
╔════╦══════════╦══════════╦══════════════════════════════════════╦════════════╗
║ #  ║ Type     ║ Priority ║ Summary                              ║ Action     ║
╠════╬══════════╬══════════╬══════════════════════════════════════╬════════════╣
║ 1  ║ found    ║ P0       ║ Missing CSRF check on /api/posts     ║ recommend  ║
║ 2  ║ found    ║ P0       ║ SQL injection via search param       ║ recommend  ║
║ 3  ║ found    ║ P1       ║ Race condition in worker pool        ║ recommend  ║
║ 4  ║ rec      ║ P2       ║ Extract repeated auth helper         ║ proposed   ║
║ 5  ║ rec      ║ info     ║ Naming convention drift in /utils    ║ proposed   ║
╚════╩══════════╩══════════╩══════════════════════════════════════╩════════════╝
```

Column widths (cell content + 1 char padding either side):

| Column   | Width | Allowed values                                          |
|----------|-------|---------------------------------------------------------|
| #        | 4     | numeric, padded                                         |
| Type     | 10    | `found` / `fixed` / `rec` / `skipped` / `error`         |
| Priority | 10    | `P0` / `P1` / `P2` / `P3` / `info`                      |
| Summary  | 38    | one-liner; truncate with `…` if it exceeds 36 chars     |
| Action   | 12    | `applied` / `proposed` / `recommend` / `open` / `n/a`   |

Outer walls + 4 inner separators = 80 chars total. Long summaries are tightened to fit; the unabridged description lives in the deliverable file's body.

## File format (deliverable)

Pure markdown. No box-drawing characters. Renders in any viewer; `- [ ]` checkboxes are interactive in GitHub, GitLab, VS Code, Obsidian.

```markdown
# CODE-REVIEW — src/auth/ — 2026-05-03

- **Skill:** code-review
- **Mode:** audit
- **Target:** `src/auth/`
- **Started:** 2026-05-03T14:22Z
- **Findings:** 5 (P0:2, P1:1, P2:1, info:1)

---

## P0 — Must fix

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

## P1 — Should fix

- [ ] **#3 Race condition in worker pool reconnect path**
  - **File:** `src/worker/pool.go:142`
  - **Description:** When N connections exceed pool_max during a reconnect storm, the gate releases before the new conn registers, allowing duplicates.
  - **Suggested action:** Wrap reconnect in a semaphore acquired before pool registration.
  - **Fix applied:** _to be filled by implementer_

## P2 — Nice to fix

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
- Numbering (`#1`, `#2`, …) is monotonic across the whole report, not per-section. The conclusion table at the bottom uses the same numbers.
- Conclusion is a standard markdown table in the file, not box-drawing — that style is reserved for inline.

### Deliverable filename

`docs/local/<bucket>/<skill-name>/<YYYY-MM-DD>-<slug>.md`

If the same skill writes twice in one day, append `-2`, `-3`, etc. to the slug.

## Severity / priority scale

One scale, used in both inline and file:

| Label  | Meaning                                              | File section heading       |
|--------|------------------------------------------------------|----------------------------|
| `P0`   | Must fix — breaks functionality, security, or build  | `## P0 — Must fix`         |
| `P1`   | Should fix — significant correctness or design bug   | `## P1 — Should fix`       |
| `P2`   | Nice to fix — improvement, lower urgency             | `## P2 — Nice to fix`      |
| `P3`   | Backlog — track but not now                          | `## P3 — Backlog`          |
| `info` | Informational — no action required                   | `## Info`                  |

Skills currently using a different scale must migrate. Document the old → new mapping inline at the top of the affected skill's `## Output Contract` section as a 3–5 line note.

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

- **Always-on:** every invocation emits the full contract. Used by audit/report skills (code-review, anti-slop, security-audit, deep-audit, full-review, update-docs, code-slimming, anti-ai-prose, localize).

- **Conditional:** the agent applies this rule per invocation:

  > When invoked to **analyze, review, audit, or improve** existing repo content, emit the full contract and write a deliverable file to the declared bucket. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.

## Fix protocol

**Layer 1 — Convention.** Any agent reading a deliverable file with `- [ ]` checkboxes and `_to be filled by implementer_` placeholders understands the protocol: as fixes land, flip the box to `- [x]`, replace the italic placeholder with a one-line description of what was actually done. Optionally append a commit SHA in parentheses.

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

**Layer 2 — Same-conversation auto-fill.** When the user invokes a skill in audit-and-fix mode (e.g., "review my repo and fix what you find"), the agent:

1. Runs the audit skill, writes the report to `docs/local/audits/<skill>/<date>-<slug>.md`.
2. Iterates findings in priority order (P0 first).
3. For each finding: implements the fix, updates the report file in place (checkbox → `[x]`, placeholder → one-line fix description), optionally commits the change atomically.
4. After the loop, emits an updated inline conclusion table reflecting the new `Type` (`fixed`) and `Action` (`applied`) values.

Layer 3 (a dedicated `apply-report` skill that takes a report path and runs the loop without re-running the auditor) is a future follow-up — not part of this contract.
