---
name: update-docs
description: >
  · Sweep docs after changes: README, changelog, API docs, runbooks, gotchas. Triggers: 'update docs', 'refresh docs', 'docs drift', 'update changelog', 'update README'. Not for PR text or roadmaps.
license: MIT
compatibility: "Requires git. Optional: wc (for size audits)"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: low
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
- Code quality, slop, or maintainability cleanup - use **anti-slop**
- Prompt authoring or reusable skill-file maintenance - use **prompt-generator** or **skill-creator**
- Full codebase audit across multiple domains - use **full-review** (it invokes update-docs as one pass)
- Git commit messages, PR descriptions, release announcement copy, or tag operations - use **git**
- Roadmap prioritization, backlog shaping, or competitor scouting - use **roadmap**

---

## AI Self-Check

Before presenting documentation updates, verify:

- [ ] Only documenting gotchas, decisions, and failure modes - not defaults readable from config
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

---

## Core Principle

**Document what you can't grep, in the file readers will actually check.** If it's in the source code, config files, or manifests, it usually doesn't belong in docs. Document: gotchas, decisions, failure modes, workarounds, implicit dependencies, release-facing deltas, and "the thing that took 30 minutes to figure out."

## Workflow

**Audit-only mode:** When invoked by full-review or when the user asks to "just report" or "check docs," run Steps 1-6 and report findings without making changes or committing. Skip Steps 7-8.

1. Identify changes
2. Categorize doc impact
3. Check whether the repo's docs surface is missing or too thin
4. Update affected docs (or report what needs updating in audit-only mode)
5. Verify internal links
6. Audit instruction-file bloat
7. Sync companion instruction files
8. Commit doc changes

### 1. Identify What Changed

Check git diff and conversation context to understand what was modified:

```bash
# Uncommitted changes
git diff --name-only

# Recent commits on this branch (compare against main/master)
git log --oneline main..HEAD 2>/dev/null || git log --oneline -10
```

Scan for changes in: configuration, infrastructure, service deployments, scripts, CI workflows, network/IP assignments, service versions, and anything operational.

### 2. Categorize Doc Impact

Map changes to documentation targets. Common instruction file names: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CODEX.md`. Adapt to the project's doc structure:

| Change Type | Likely Docs to Update |
|-------------|----------------------|
| New/changed infrastructure specs | Project instruction file (`AGENTS.md` or equivalent), inventory docs |
| New service or app deployed | Project instruction file, deployment docs |
| IP/port/endpoint changes | Project instruction file, network inventory |
| Version bumps (runtimes, deps, images) | Project instruction file |
| New gotcha discovered | Project instruction file |
| Operational procedure performed | Runbooks or deployment checklists (include when in the deploy cycle the procedure runs) |
| New secret or credential | Secrets inventory |
| CI/CD workflow changes | Project instruction file, pipeline docs |
| Docker/Compose changes | Project instruction file, deployment docs |
| Proxmox/LXC changes | Project instruction file, inventory docs |
| Rust crate/toolchain changes | Project instruction file, `README.md` (build prereqs) |
| Architecture decision | ADR if significant (see below), otherwise a short bullet in the instruction file |
| New or changed env vars, config keys, or runtime config | `.env.example`, `README.md` (setup section) |
| New dependencies or setup steps | `README.md` (getting started / prerequisites) |
| API endpoint or contract changes | `API.md`, `README.md` (API section), endpoint docs, OpenAPI spec if applicable |
| Feature added, removed, or materially changed | `README.md`, feature docs (`FEATURES.md`, `FEATURESET.md`, `docs/features/*.md`), changelog |
| Merged PR with user-visible impact | Changelog, roadmap/status docs, release notes, affected feature/API/setup docs |
| Version bumps / new release cut | `CHANGELOG.md`, release notes, `README.md`, install/upgrade docs, badges, package manager instructions |
| Strategy or sequencing changes | `ROADMAP.md`, status docs, milestone docs |

**When to write an ADR:** If the decision affects multiple components, constrains future options, or reverses a previous decision, it's worth a dedicated Architecture Decision Record. If it's a one-liner ("switched from X to Y because Z"), a short bullet in the project's instruction file is enough.

**Gotcha placement heuristic:**
- One-liner gotcha (e.g., "VIP refuses k8s traffic - use direct IP") -> `CLAUDE.md` bullet.
- Multi-step procedure (e.g., "rotating a cert requires drain, replace, reload in order") -> dedicated runbook section.
- Time-critical pre/post-deploy action (e.g., "Redis FLUSHALL must run after deploy but before traffic is routed back") -> checklist at the top of the runbook, not buried in a section.

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
- Default values readable from config files or manifests
- Standard framework/platform behavior
- Information already in upstream docs
- Temporary state (in-progress work, one-time migration steps already completed)
- Verbose explanations - one line per gotcha, expand only if the fix is non-obvious

### 5. Verify Internal Links

After editing docs, check that internal references still resolve:

```bash
# Check tracked and new markdown files
{ git ls-files '*.md'; git ls-files --others --exclude-standard - '*.md'; } 2>/dev/null | sort -u | while read -r file; do
  grep -oEh '\[[^]]*\]\([^)#]+' "$file"
done | sed 's/.*](//' | grep -v '^https\?://' | sort -u | while read -r path; do
  [[ -e "$path" ]] || echo "BROKEN LINK: $path"
done
```

This catches `[text](path)` and `![alt](path)` links, strips anchors (`#section`),
and skips external URLs. Works on both GNU and BSD grep (no `-P` flag needed).
If files were renamed or moved, update all references.

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

```bash
# Example: sync AGENTS.md into a tool-specific companion
test -f AGENTS.md && test -f CLAUDE.md && cp AGENTS.md CLAUDE.md
```

Review the copied file after syncing and remove any tool-specific commands or behavior that do not apply to that target.

**Default: instruction files are usually gitignored unless the project intentionally tracks them.** Check `.gitignore` and existing history before committing them.

### 8. Commit Documentation Changes

Only commit changes to tracked docs (inventory, runbooks, ADRs, changelogs, feature docs, API docs, roadmaps, and instruction files if the project commits them).

```bash
# Stage specific changed docs (don't blindly add everything)
{ git diff --name-only - '*.md' '.env.example'; git ls-files --others --exclude-standard - '*.md' '.env.example'; } 2>/dev/null | sort -u | \
  while read -r path; do
    [[ -n "$path" ]] && git add - "$path"
  done
# Only if docs changed:
git diff --cached --quiet || git commit -m "docs: update [target] after [what changed]"
```

## Quick Reference: File Locations

| File | Purpose | Committed? |
|------|---------|-----------|
| `README.md` | Repo overview, setup, install, usage | Yes |
| `CHANGELOG.md` | Release-facing history and breaking changes | Usually yes |
| `API.md` | Human-readable API surface and contract notes | Usually yes |
| `ROADMAP.md` | Public or private plan/status surface | Depends on project |
| `FEATURES.md` / `FEATURESET.md` | User-visible capability inventory | Depends on project |
| Other `*.md` docs | Release notes, status docs, migration notes, architecture docs | Depends on project |
| `AGENTS.md` | Cross-tool project instructions | Depends on project (check .gitignore) |
| Tool-specific instruction file | Companion instructions for a specific agent/tool when a project keeps one | Depends on project (check .gitignore) |
| `docs/` | Project documentation (inventory, runbooks, ADRs, migration notes, release docs) | Yes |

## Handling Deprecated Features

When a feature, service, or API is deprecated during a session:
- **Keep the doc entry** with a `[DEPRECATED]` prefix and the date - don't delete immediately
- **Add the replacement** in the same section so readers find both
- **Remove deprecated entries** after 2 release cycles or when confirmed no longer referenced anywhere
- **Breaking changes** deserve their own bullet: what broke, what replaces it, any migration steps

## Related Skills

- **full-review** - orchestrates code-review, anti-slop, security-audit, and update-docs in
  parallel. Update-docs is one of the four passes.
- **git** - for commit message conventions and PR descriptions. Update-docs covers project
  documentation files; git covers version control operations.

---

## Common Mistakes

- **Documenting everything**: If it's in config files, don't repeat the default value in the instruction file. Document the gotcha around it.
- **Stale counts**: "13 dashboards" becomes wrong when you add one. Use "N dashboards" or keep the count accurate.
- **Orphaned gotchas**: A gotcha about a bug that was fixed 3 months ago is noise. Prune regularly.
- **Assuming every merge needs docs**: A merged PR is a strong hint, not an automatic docs task. Check for actual drift.
- **Forgetting non-README surfaces**: API changes belong in `API.md`; release deltas belong in `CHANGELOG.md`; feature drift belongs in feature docs.
- **Missing the companion sync**: If the project keeps multiple instruction files, keep them aligned after changes.
- **Over-documenting migrations**: Once a migration is complete and verified, condense to a one-liner and remove the step-by-step procedure.
- **Dangling links**: Renaming a doc without updating references elsewhere creates dead links that erode trust in documentation.
- **Bootstrapping without consent**: If the repo lacks docs, suggest a minimal docs surface; don't silently create a documentation tree the user did not ask for.
- **Deleting deprecated docs too early**: Keep deprecated entries visible for at least one release cycle so people find the migration path.

---

## Rules

- **Document deltas, not defaults.** Capture what changed, what broke, and what future sessions need to know.
- **Treat merged PRs and releases as doc-drift signals, not guarantees.** Verify likely impact before editing.
- **Prefer the right existing doc over the nearest convenient one.** Put API changes in API docs, release deltas in changelogs, and planning changes in roadmap/status docs.
- **Do not rewrite healthy docs for style alone.** Keep edits tied to real operational value.
- **Offer docs bootstrap suggestions when the repo is under-documented, but keep them dismissable.**
- **Keep companion instruction files aligned.** If the repo maintains more than one instruction surface, update the others or note the drift explicitly.
- **Prefer stable wording over brittle counts.** Avoid numbers and one-off migration prose that will rot immediately.
