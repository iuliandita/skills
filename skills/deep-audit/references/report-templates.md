# Report and Task-List Templates

Templates used by Steps 7, 8, and 9. Read this before writing the audit artifacts.

---

## DEEP-AUDIT.md template

Write to `docs/local/audits/DEEP-AUDIT.md`. Overwrite any prior file - git history is
not retained (the dir is gitignored); users who want to keep an old version should archive
it themselves before re-running.

```markdown
# Deep Audit - {repo_name}

| Field | Value |
|---|---|
| Repo | {owner/repo} |
| Commit | {short_sha} |
| Branch | {branch} |
| Version | {package_version_if_available} |
| Date | {YYYY-MM-DD} |
| Files | {file_count} tracked |
| Audit scope | {scope} |
| Waves completed | {N}/5 ({skills_run}/{skills_dispatched} skill invocations) |

## Headline verdict
{1-2 paragraphs: the dominant risk chain, biggest wins, and systemic patterns}

## Scorecard
| Severity | Count |
|---|---|
| Critical | {n} |
| High | {n} |
| Medium | {n} |
| Low / Info | {n} |

## Wave 1 - Reconnaissance
{matched/skipped skills, languages, file count}

## Wave 2 - Code Quality
{sections per skill, native format preserved}

## Wave 3 - Domain-Specific
{sections per matched skill, native format preserved}

## Wave 4 - Security
{security-audit + zero-day sections, native format preserved}
{reference SECURITY-AUDIT.md location instead of duplicating full content}

## Wave 5 - Documentation & Hygiene
{sections per skill, native format preserved}
```

Preserve each skill's native report format inside its section - do not normalize.

---

## DEEP-AUDIT-TASKS.md template

Write to `docs/local/audits/DEEP-AUDIT-TASKS.md`. Each finding worth acting on becomes
one task entry.

### Task entry format

```markdown
- [ ] **{phase}.{index} {short title}** {priority_marker} ({finding_id}) - {effort}
  - File: `{path}:{line_range}` (or Files: bulleted list if multiple)
  - {1-2 line rationale or fix sketch}
```

- **Priority markers**: `🔴` Critical (blocks release or creates unauthenticated compromise),
  `🟡` Important (correctness or exposed attack surface), `🔵` Minor (polish, stale docs, style).
- **Effort**: rough human estimate (`15m`, `1-2h`, `1 day`). Err toward calibrated estimates,
  not optimistic ones.
- **Finding ID**: reference the origin wave/section (e.g., `Z1` from zero-day, `M3` from
  security-audit, `CR-04` from code-review) so users can trace back to DEEP-AUDIT.md.

### Phase ordering (top-to-bottom = execution order)

1. Security chains that compose to compromise (block everything else)
2. Isolated security findings (SSRF, auth, crypto)
3. Data correctness bugs
4. Database / persistence layer
5. Supply chain & release integrity
6. Kubernetes / Helm
7. Docker / OCI
8. CI/CD pipeline
9. Backend API hygiene
10. Per-domain items (AI/LLM, i18n, etc.)
11. Frontend & testing
12. Documentation, roadmap, git hygiene

Collapse phases that have zero tasks. Renumber so there are no gaps.

### Trailing sections

End the file with:

- **Rough effort total** - per-phase time estimates rolled up.
- **Suggested minimum for next release** - task IDs forming the smallest defensible cut
  (all Critical + enough High to close exposed chains).

---

## Master execution plan template (Step 9b, vanilla-harness fallback only)

Write to `docs/local/specs/{YYYY-MM-DD}-audit-execution-master-plan.md` when no
brainstorming skill is available. Required sections:

1. **Metadata header** - date, status, source audit file + commit, scope, timeline, execution model.
2. **Table of Contents** - per-phase sections plus appendix and decision log.
3. **Operational Contract** - non-negotiable rules: version mapping (phase N -> minor bump),
   branching (`audit/phase-N-<slug>` off `main`), subphase commit rules (atomic, Conventional
   Commits, no AI attribution), pre-commit baseline (lint/typecheck/test), end-of-phase
   release protocol (push, PR, CI, merge, tag).
4. **Testing Gates by Phase Type** - which test commands each phase must pass.
5. **Delegation Model** - who runs what (Claude, Codex, human), when to handoff.
6. **Phase Section Template** - one section per phase with: goal, audit tasks covered, files
   touched, test gates, version mapping, release tag, detailed subphase breakdown.
7. **Quick-Reference Appendix** - one-line per phase summary for at-a-glance navigation.
8. **Decision Log** - running record of scope changes mid-execution.
9. **Handoff Prompt Master Template** - paste-able prompt used to delegate each phase to
   a fresh session.

---

## Per-phase execution plan template (Step 9b, vanilla-harness fallback only)

Write one per non-trivial phase to
`docs/local/plans/{YYYY-MM-DD}-audit-phase-{NN}-{slug}.md` (two-digit phase numbers).
Required sections:

1. **Header** - goal, architecture sketch, tech stack, spec cross-reference.
2. **Pre-work: Branch setup** - concrete commands for cutting the feature branch and
   verifying baseline state (version, clean tree, author identity).
3. **Task sections** - one per subphase commit:
   - Audit task ID(s) covered
   - Files to create / modify
   - Step-by-step checklist (`- [ ]` checkboxes) with exact commands, diff sketches,
     test-gate commands
   - Commit boundary at the end (version bump, checkbox tick in `DEEP-AUDIT-TASKS.md`,
     Conventional Commit message)
4. **Final sweep** - commands to run before pushing (lint, typecheck, test, phase-type gates).
5. **Release** - push + PR + CI + merge + tag sequence.
