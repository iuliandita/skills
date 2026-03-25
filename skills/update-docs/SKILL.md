---
name: update-docs
description: "Use when a session involved infrastructure, configuration, architecture, or operational changes. Also use when explicitly asked to update docs, refresh documentation, or at the end of a session after significant work. Triggers: new gotchas discovered, changed IPs/ports/versions, new services added, runbook-worthy procedures, or CLAUDE.md/AGENTS.md growing stale. Do NOT use for writing new documentation from scratch."
source: custom
date_added: "2026-03-25"
effort: low
---

# Update Docs

Post-session documentation sweep. Captures non-obvious knowledge into the right docs, trims bloat, and syncs CLAUDE.md to AGENTS.md.

## Core Principle

**Document what you can't grep.** If it's in the source code, config files, or manifests, it doesn't belong in docs. Document: gotchas, decisions, failure modes, workarounds, implicit dependencies, and "the thing that took 30 minutes to figure out."

## Workflow

1. Identify changes
2. Categorize doc impact
3. Update affected docs
4. Verify internal links
5. Audit CLAUDE.md bloat
6. Sync CLAUDE.md to AGENTS.md
7. Commit doc changes

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

Map changes to documentation targets. Adapt this table to the project's doc structure:

| Change Type | Likely Docs to Update |
|-------------|----------------------|
| New/changed infrastructure specs | `CLAUDE.md` (stack section), inventory docs |
| New service or app deployed | `CLAUDE.md` (relevant section), deployment docs |
| IP/port/endpoint changes | `CLAUDE.md`, network inventory |
| Version bumps (runtimes, deps, images) | `CLAUDE.md` (stack section) |
| New gotcha discovered | `CLAUDE.md` (gotchas section) |
| Operational procedure performed | Runbooks |
| New secret or credential | Secrets inventory |
| CI/CD workflow changes | `CLAUDE.md` (CI/CD section) |
| Docker/Compose changes | `CLAUDE.md` (stack section), deployment docs |
| Proxmox/LXC changes | `CLAUDE.md` (infra section), inventory docs |
| Rust crate/toolchain changes | `CLAUDE.md` (stack section), `README.md` (build prereqs) |
| Architecture decision | ADR if significant (see below), otherwise CLAUDE.md bullet |
| New env vars or config keys | `.env.example`, `README.md` (setup section) |
| New dependencies or setup steps | `README.md` (getting started / prerequisites) |
| API endpoint changes | `README.md` (API docs section), OpenAPI spec if applicable |
| Version bumps / new release cut | Grep for old version strings across Dockerfiles, compose files, Helm values, CI workflows, tests, README badges/install instructions -- stale versions are the #1 post-release doc rot |

**When to write an ADR:** If the decision affects multiple components, constrains future options, or reverses a previous decision, it's worth a dedicated Architecture Decision Record. If it's a one-liner ("switched from X to Y because Z"), a bullet in CLAUDE.md is enough.

### 3. Update Affected Docs

**For each affected doc, read it first, then make targeted edits.**

#### What to ADD:
- Gotchas that aren't obvious from code (e.g., "VIP refuses k8s traffic -- use direct IP")
- Implicit dependencies between components (e.g., "must restart pod after SealedSecret update")
- Failure modes and their symptoms (e.g., "PLEG unhealthy = container runtime frozen")
- Workarounds for known issues
- Operational constraints (e.g., "serial: 1 required -- removing it updates all nodes simultaneously")
- Decisions and their rationale

#### What NOT to add:
- Default values readable from config files or manifests
- Standard framework/platform behavior
- Information already in upstream docs
- Temporary state (in-progress work, one-time migration steps already completed)
- Verbose explanations -- one line per gotcha, expand only if the fix is non-obvious

### 4. Verify Internal Links

After editing docs, check that internal references still resolve:

```bash
# Extract markdown link targets and verify they exist
grep -roEh '\[[^]]*\]\([^)#]+' CLAUDE.md docs/ 2>/dev/null | \
  sed 's/.*](//' | grep -v '^https\?://' | sort -u | while read -r path; do
    [[ -e "$path" ]] || echo "BROKEN LINK: $path"
  done
```

This catches `[text](path)` and `![alt](path)` links, strips anchors (`#section`),
and skips external URLs. Works on both GNU and BSD grep (no `-P` flag needed).
If files were renamed or moved, update all references.

### 5. Audit CLAUDE.md / AGENTS.md for Bloat

After updates, review CLAUDE.md critically:

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
- CLAUDE.md: **must stay under 40,000 characters** (Claude Code warns at this threshold and performance degrades). Aim for under 500 lines. If over, move detailed sections to `docs/` and link.
- Individual sections: if a section exceeds 30 lines, consider splitting into a dedicated doc.
- Check size after edits: `wc -c CLAUDE.md` (target: <40000). If over, aggressively condense or extract sections to `docs/` files and replace with one-line pointers.

### 6. Sync CLAUDE.md to AGENTS.md

AGENTS.md is a copy of CLAUDE.md for non-Claude agents. After updating CLAUDE.md:

```bash
cp CLAUDE.md AGENTS.md
```

If CLAUDE.md contains Claude-specific instructions (references to the Skill tool, XML tags, Claude-specific behavior), review AGENTS.md after copying and adapt or remove those references so other agents aren't confused by instructions they can't follow.

**Default: both files go in .gitignore.** Some projects commit a project-level CLAUDE.md as part of the repo (check .gitignore and existing git history). If the project commits CLAUDE.md, update it in-tree. If not, keep it gitignored.

### 7. Commit Documentation Changes

Only commit changes to tracked docs (inventory, runbooks, ADRs, and CLAUDE.md/AGENTS.md if the project commits them).

```bash
# Stage specific changed docs (don't blindly add everything)
git diff --name-only docs/ README.md 2>/dev/null | xargs -r git add
# Only if docs changed:
git diff --cached --quiet || git commit -m "docs: update [target] after [what changed]"
```

## Quick Reference: File Locations

| File | Purpose | Committed? |
|------|---------|-----------|
| `CLAUDE.md` | Project instructions for Claude | Depends on project (check .gitignore) |
| `AGENTS.md` | Same, for non-Claude agents | Depends on project (check .gitignore) |
| `docs/` | Project documentation (inventory, runbooks, ADRs) | Yes |
| `README.md` | Repo overview | Yes |
| `~/.claude/projects/*/memory/MEMORY.md` | Auto-memory (cross-session) | No |

## Handling Deprecated Features

When a feature, service, or API is deprecated during a session:
- **Keep the doc entry** with a `[DEPRECATED]` prefix and the date -- don't delete immediately
- **Add the replacement** in the same section so readers find both
- **Remove deprecated entries** after 2 release cycles or when confirmed no longer referenced anywhere
- **Breaking changes** deserve their own bullet: what broke, what replaces it, any migration steps

## Related Skills

- **full-review** -- orchestrates code-review, anti-slop, security-audit, and update-docs in
  parallel. Update-docs is one of the four passes.
- **git** -- for commit message conventions and PR descriptions. Update-docs covers project
  documentation files; git covers version control operations.

---

## Common Mistakes

- **Documenting everything**: If it's in config files, don't repeat the default value in CLAUDE.md. Document the gotcha around it.
- **Stale counts**: "13 dashboards" becomes wrong when you add one. Use "N dashboards" or keep the count accurate.
- **Orphaned gotchas**: A gotcha about a bug that was fixed 3 months ago is noise. Prune regularly.
- **Missing the AGENTS.md sync**: Non-Claude agents need the same context. Always sync after CLAUDE.md changes.
- **Over-documenting migrations**: Once a migration is complete and verified, condense to a one-liner and remove the step-by-step procedure.
- **Dangling links**: Renaming a doc without updating references elsewhere creates dead links that erode trust in documentation.
- **Deleting deprecated docs too early**: Keep deprecated entries visible for at least one release cycle so people find the migration path.
