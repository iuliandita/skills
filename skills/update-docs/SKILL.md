---
name: update-docs
description: >
  Update READMEs, changelogs, API docs, runbooks, and instruction files after changes; fix doc drift. Use for "update the docs" or a release sweep.
license: MIT
compatibility: "Requires git. Optional: python3 (link check), wc (size audits)"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: medium
  argument_hint: "[doc-or-path] (e.g., CLAUDE.md, docs/runbook.md)"
---

# Update Docs

Post-change documentation sweep. Captures non-obvious knowledge into the right docs, trims bloat, and keeps the repo's documentation surfaces aligned after changes that likely introduced drift.

## When to use

- After infrastructure, configuration, architecture, or operational changes
- After a merged PR, release cut, feature shipment, or version bump when those changes likely caused doc drift
- When asked to refresh docs, instruction files, runbooks, changelogs, API docs, roadmaps, or README content
- When a session uncovered new gotchas, changed setup steps, changed external behavior, or added services
- When an API contract, feature surface, migration path, or release/install path changed
- When the repo's docs surface is obviously underspecified and it is worth suggesting a minimal docs bootstrap to the user

## When NOT to use

- Writing a full documentation set from scratch without user approval
- Code correctness or security review - use **code-review** or **security-audit**
- Code quality, slop, or maintainability cleanup - use **code-simplification**
- Prompt authoring or reusable skill-file maintenance - use **prompt-generator** or **skill-creator**
- Full codebase audit across multiple domains - use **repo-audit** (it invokes update-docs as one pass)
- Git commit messages, PR descriptions, release announcement copy, or tag operations - use **git**
- Roadmap prioritisation and backlog shaping belongs to the **roadmap** skill; moving shipped `[planned]` / `[exploring]` items is roadmap Mode 2; stated version numbers and highlight prose belong here

---

## AI Self-Check

Before presenting documentation updates, verify:

- [ ] Audience needs covered: setup, public behavior, gotchas, decisions, and failure modes; no redundant implementation inventory
- [ ] No stale counts introduced (used "N" or kept count accurate)
- [ ] Internal links verified (no broken references after renames or moves)
- [ ] Companion instruction files still aligned (AGENTS.md synced if CLAUDE.md changed)
- [ ] Existing doc surface checked first before creating a new markdown file
- [ ] Release, API, roadmap, and feature docs updated only if the change actually affected them
- [ ] No orphaned gotchas for already-fixed issues
- [ ] Deprecated entries marked with `[DEPRECATED]` prefix and date, not silently removed
- [ ] `.env.example` updated if env vars or runtime config changed
- [ ] If repo docs are too thin, a minimal docs bootstrap was offered to the user as a suggestion, not forced
- [ ] Size check run (`wc -c`) - instruction files under 40,000 chars
- [ ] README / quality-evidence sections checked for stale dates, stale counts, and old run references
- [ ] All roadmap files (committed AND gitignored) checked - their stated version/date matches current HEAD or latest tag
- [ ] When private and public roadmaps both exist, both are updated, with the public one carrying user-visible highlights only and the private one carrying internal detail
- [ ] **Docs match code**: commands, flags, config names, screenshots, and API examples are checked against the changed implementation
- [ ] **Audience path checked**: README, changelog, API docs, runbooks, and migration notes are updated only where users need them
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

## Core Principle

**Document what the reader needs to act, in the file they will actually check.** Explain setup, public behavior, and required defaults when that audience needs them; avoid duplicating implementation inventories. Document: gotchas, decisions, failure modes, workarounds, implicit dependencies, release-facing deltas, and "the thing that took 30 minutes to figure out."

---

## Practices

- Prefer generated API/schema docs where the project already has generation tooling.
- Keep examples minimal but runnable so future verification is cheap.
- Document behavior changes, deprecations, migration steps, and rollback notes in the place users will look.
- Remove stale instructions instead of appending contradictory notes.
- Keep changelog entries user-facing and avoid internal implementation noise.


## Workflow

**Audit-only mode:** When invoked by repo-audit or asked to report/check docs, inspect applicable Steps 1-7, including companion shape and drift, without editing. Skip commit Step 8. Scope all checks to documentation affected by the requested change; private configuration and unrelated roadmaps are not an automatic sweep target.

Copy this checklist and track progress:

- [ ] 1. Identify changes (1.5 roadmap freshness, 1.6 evidence freshness)
- [ ] 2. Categorize doc impact
- [ ] 3. Check whether the repo's docs surface is missing or too thin
- [ ] 4. Update affected docs (or report what needs updating in audit-only mode)
- [ ] 5. Verify internal links; if any link is broken, fix it and return to Step 5
- [ ] 6. Audit instruction-file bloat
- [ ] 7. Sync companion instruction files
- [ ] 8. Commit doc changes

### 1. Identify What Changed

Check git diff and conversation context to understand what was modified:

```bash
# Uncommitted changes
git diff --name-only

# Compare against the roadmap's stated version (as written, then with/without `v`),
# falling back to the last tag, falling back to the last 10 commits
ROADMAP_VER=$(grep -hoE 'Current:?\s*v?[0-9]+\.[0-9]+\.[0-9]+' ROADMAP.md docs/ROADMAP.md 2>/dev/null | head -1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+')
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
BASE=""
for c in ${ROADMAP_VER:+"$ROADMAP_VER" "v${ROADMAP_VER#v}" "${ROADMAP_VER#v}"} "$LAST_TAG"; do
  [[ -n "$c" ]] && git rev-parse -q --verify "refs/tags/$c" >/dev/null && { BASE="$c"; break; }
done
if [[ -n "$BASE" ]]; then
  git log --oneline "$BASE..HEAD"   # empty output = no commits since $BASE
else
  echo "No matching tag; showing last 10 commits"
  git log --oneline -10
fi
```

With a resolved `$BASE`, an empty log means no commits since that tag, not a failed lookup.

Scan for changes in: configuration, infrastructure, service deployments, scripts, CI workflows, network/IP assignments, service versions, and anything operational.

### 1.5. Roadmap Freshness Check

Roadmaps drift the hardest because they restate facts the code, tags, and commit history already prove. Run this check whenever the repo has a roadmap - committed OR gitignored. If none is found, the step is silent; absence of `ROADMAP.md` is not an error.

Run the script in `references/roadmap-freshness.md`. It discovers every roadmap file (tracked and gitignored), parses each `Current` / `Updated` / `Version` header, and reports `ROADMAP DRIFT` when the stated version is older than the latest tag, a release was cut after the header date, or the header is more than 14 calendar days behind HEAD. On drift it widens `RANGE` for Step 2. The reference also has the side-channel check for stale `Scanned` / `as of` dates inside the roadmap body; report those as separate observations.

Do NOT fabricate refreshed content. The user wants staleness called out so they can decide whether to refresh manually, not invented data.

### 1.6. Evidence Freshness Check

README files often contain "quality evidence" paragraphs that rot quietly: old benchmark dates,
old run IDs, stale skill counts, stale test counts, old release versions, or claims like
"latest run" that no longer match repository state. Run this check whenever touching README,
CHANGELOG, release docs, project status docs, or any doc with evidence/quality/status wording.

```bash
# Find brittle evidence claims in tracked docs.
DOCS=$(git ls-files '*.md' 'docs/**/*.md' 2>/dev/null)
if [[ -n "$DOCS" ]]; then
  printf '%s\n' "$DOCS" | while IFS= read -r doc; do
    git grep -n -E '([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]+/[0-9]+|quality evidence|benchmark|latest (run|score|evidence|benchmark)|current (run|score|evidence|gates|version)|score[: ]|passed (for|in|on))' -- "$doc" 2>/dev/null || true
  done
fi
# Any claimed count ("N plugins", "N endpoints", "N tests") is only as good as the inventory
# that proves it. Recount from the repo's own source of truth before repeating the number:
#   git ls-files '<the tracked glob the claim describes>' | wc -l
# Do the same for scores, run IDs, and benchmark dates: re-read the artifact that stores them.
```

Every evidence claim needs its own artifact re-read in the same session - a count from the repo
inventory, a score or run ID from the file that records it, a date from the report it came from.
Never restate one from an earlier session or from the doc making the claim.

When a stale evidence claim is found, either update it from the source artifact or rewrite it to
avoid brittle counts. Good: "Current repository gates pass for the public skill collection."
Risky: "Current gates pass for all 42 skills" unless you verified the count in the same run.

### 2. Categorize Doc Impact

Map each change to its documentation targets with the change-type table and the gotcha placement heuristic in `references/doc-targets.md`.

### 3. Check Whether the Repo's Docs Surface Is Missing or Too Thin

If the repo has no meaningful documentation surface, or only a minimal `README.md`, treat that as a separate observation before editing anything.

**Examples of "too thin":**
- No `docs/` directory and no durable markdown files beyond a stub `README.md`
- A `README.md` that only names the project and gives no setup, usage, API, or feature overview
- Repeated change-driven doc drift with nowhere sensible to record it

**What to do:**
- Suggest a minimal docs bootstrap to the user as a dismissable recommendation
- Keep the suggestion small and concrete, for example: `README.md`, `CHANGELOG.md`, `API.md`, `ROADMAP.md`, or `docs/adr/`
- Tailor the suggestion to the repo type; don't propose a generic docs tree mechanically
- If the user declines, continue with the best available existing doc surface and note the limitation

**What NOT to do:**
- Don't automatically create a full new docs set
- Don't block routine doc maintenance on the bootstrap suggestion

### 4. Update Affected Docs

**For each affected doc, read it first, then make targeted edits.**

#### What to ADD:
- Gotchas that aren't obvious from code (e.g., "VIP refuses k8s traffic - use direct IP")
- Implicit dependencies between components (e.g., "must restart pod after SealedSecret update")
- Failure modes and their symptoms (e.g., "PLEG unhealthy = container runtime frozen")
- Workarounds for known issues
- Operational constraints (e.g., "serial: 1 required - removing it updates all nodes simultaneously")
- Operational timing - when a procedure must run relative to a deployment step, say so explicitly (e.g., "Redis FLUSHALL must run after the new image is deployed but before traffic is routed back")
- Connection strings and service endpoints when IPs, ports, or hostnames change
- Decisions and their rationale
- User-visible feature additions, removals, and caveats in the doc where readers expect them
- Release-facing deltas: upgraded versions, upgrade notes, breaking changes, and migration pointers
- API behavior changes in `API.md`, endpoint docs, or the repo's canonical API surface

#### When no docs exist yet:
- Don't create a full documentation set from scratch unless the user explicitly asks
- DO offer a minimal docs bootstrap suggestion if the repo is under-documented
- DO add a minimal entry to the project instruction file (CLAUDE.md, AGENTS.md, or equivalent) with the gotcha or operational note that prompted this
- If the project has no instruction file at all, note this to the user and suggest creating one with the essential gotcha. Don't block on it.

#### What NOT to add:
- Implementation defaults that the intended reader does not need for setup or correct use
- Standard framework/platform detail unrelated to the reader's task
- Information already in upstream docs
- Temporary state (in-progress work, one-time migration steps already completed)
- Verbose explanations - one line per gotcha, expand only if the fix is non-obvious

### 5. Verify Internal Links

After editing docs, check that internal references still resolve:

Prefer the repository's Markdown/link checker for affected documents. If none exists, this limited inline-link check resolves paths relative to each source document; it does not validate heading anchors, reference-style links, or nested Markdown syntax. Pass the reviewed document paths explicitly.

```bash
python3 - README.md docs/guide.md <<'PYLINK'
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re, sys
failed = False
for name in sys.argv[1:]:
    source = Path(name)
    for raw in re.findall(r'\[[^\]]*\]\(([^()]+)\)', source.read_text()):
        destination = raw.strip().split(' "', 1)[0].strip('<>')
        url = urlsplit(destination)
        if url.scheme or url.netloc or not url.path:
            continue
        if url.path.startswith('/'):
            print(f"SITE-ROOT LINK: {source}: {raw}; validate against site configuration")
            continue
        target = source.parent / unquote(url.path)
        if not target.exists():
            print(f"BROKEN LINK: {source}: {raw}")
            failed = True
sys.exit(1 if failed else 0)
PYLINK
```

Fix each `BROKEN LINK` and rerun until the check exits 0. If files moved, search incoming references as well. Report unsupported link forms as unchecked, not passed.

### 6. Audit Project Instruction Files for Bloat

After updates, review the project's shared instruction file critically:

**Remove or condense if:**
- A gotcha was fixed and no longer applies (mark as resolved, then delete next session)
- Information is now in a runbook (replace with pointer)
- A section restates what's in the source (e.g., listing every container image tag)
- Multiple bullet points say the same thing differently
- A migration or one-time procedure is fully complete and won't recur
- Version numbers that Renovate/CI keeps current automatically

**Keep if:**
- You'd waste 15+ minutes rediscovering it without the doc
- It's a cross-component interaction not visible in any single file
- It contradicts what you'd expect from reading the code
- It's a "don't do X" warning born from actual breakage

**Size targets:**
- Shared instruction files: aim for **under 40,000 characters** and under 500 lines even if the tool allows more. If over, move detailed sections to `docs/` and link.
- Individual sections: if a section exceeds 30 lines, consider splitting into a dedicated doc.
- Check size after edits: `wc -c CLAUDE.md AGENTS.md 2>/dev/null`

### 7. Sync Companion Instruction Files

If the project keeps multiple instruction files (`AGENTS.md` plus tool-specific variants, for example), keep them aligned after updates.

Inspect whether companions are symlinks, import stubs, generated files, or independent documents before editing. For a symlink to the canonical file, edit that source once; copying onto the same file is unnecessary. Preserve import stubs. For generated companions, edit their source fragments and run the repository generator. For independent files, update only the corresponding shared guidance and retain target-specific sections. Review the resulting diff; never overwrite an entire distinct companion as a synchronization shortcut.

**Default: instruction files are usually gitignored unless the project intentionally tracks them.** Check `.gitignore` and existing history before committing them.

### 8. Commit Documentation Changes

Record the initial staged and dirty state before editing. Keep a list of task-owned paths and hunks, including intended new public docs. Leave ignored/private files local. Stage only reviewed task changes with explicit paths or patch staging.

Before committing, inspect the complete staged diff and compare it with the initial index. If unrelated work was already staged, preserve it and leave the task's edits uncommitted unless the user has authorized an isolation method. Do not reset another person's index, stage every dirty Markdown file, or commit the whole index merely because some documentation changed. Follow the repository's commit workflow only when committing is within the request's scope.

## Quick Reference: File Locations

The file, purpose, and committed-or-not table is in `references/doc-targets.md`.

## Handling Deprecated Features

When a feature, service, or API is deprecated during a session:
- **Keep the doc entry** with a `[DEPRECATED]` prefix and the date - don't delete immediately
- **Add the replacement** in the same section so readers find both
- **Follow repository and explicit user retirement policy first.** Verify its release, publication-date, and elapsed-time conditions before removing entries; lack of incoming references cannot shorten a promised grace period.
- **Only when no policy exists**, keep entries for two completed release cycles after the deprecation is published, then remove them only after checking incoming references and preserving any still-needed migration guidance. If release or publication evidence is unavailable, retain the entry and report what remains unverified.
- **Breaking changes** deserve their own bullet: what broke, what replaces it, any migration steps

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** UPDATE-DOCS
- **Deliverable bucket:** `audits`
- **Mode:** always-on. Every invocation applies the reporting size and evidence rules in `references/output-contract.md`.
- **Deliverable path:** `docs/local/audits/update-docs/<YYYY-MM-DD>-<slug>.md`
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract).

## Related Skills

- **repo-audit** - orchestrates code-review, code-simplification, security-audit, and update-docs in
  parallel. Update-docs is one of the four passes.
- **git** - for commit message conventions and PR descriptions. Update-docs covers project
  documentation files; git covers version control operations.

## Reference Files

- `references/roadmap-freshness.md` - the roadmap drift script and side-channel date check; run it in Step 1.5
- `references/agent-hygiene.md` - cross-cutting checks applied before returning (generated)
- `references/output-contract.md` - report format for every invocation (generated)
- `references/doc-targets.md` - change-type to doc-target table, gotcha placement heuristic, file locations; read in Step 2

---

## Common Mistakes

- **Documenting everything**: Avoid repeating implementation inventories. Include a default when readers need it to configure or use the product correctly.
- **Stale quality evidence**: README claims like "latest run", "current score", or "39/39 skills" must be checked against the source artifact in the same session.
- **Orphaned gotchas**: A gotcha about a bug that was fixed 3 months ago is noise. Prune regularly.
- **Assuming every merge needs docs**: A merged PR is a strong hint, not an automatic docs task. Check for actual drift.
- **Forgetting non-README surfaces**: API changes belong in `API.md`; release deltas belong in `CHANGELOG.md`; feature drift belongs in feature docs.
- **Over-documenting migrations**: Once a migration is complete and verified, condense to a one-liner and remove the step-by-step procedure.
- **Deleting deprecated docs too early**: Follow repository and explicit user policy; no-reference evidence does not waive its grace period. Use the two-completed-release fallback above only when neither defines retirement conditions.
- **Skipping the roadmap header check**: A roadmap with `Current: v0.27` while HEAD is on `v0.43` is the loudest possible drift signal. Always parse and compare the header before deciding whether the roadmap needs updates.
- **Treating a gitignored roadmap as out of scope**: Private roadmaps drift hardest because nobody complains about them publicly. Run the freshness check against ALL roadmaps the `find` command surfaces, not just tracked ones.

---

## Rules

- **Document deltas, not defaults.** Capture what changed, what broke, and what future sessions need to know.
- **Treat merged PRs and releases as doc-drift signals, not guarantees.** Verify likely impact before editing.
- **Prefer the right existing doc over the nearest convenient one.** Put API changes in API docs, release deltas in changelogs, and planning changes in roadmap/status docs.
- **Do not rewrite healthy docs for style alone.** Keep edits tied to real operational value.
