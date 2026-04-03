---
name: update-docs
description: "Use when a session involved infrastructure, configuration, architecture, or operational changes. Also use when explicitly asked to update docs, refresh documentation, or at the end of a session after significant work. Triggers: 'update docs', 'refresh docs', 'sync docs', 'update CLAUDE.md', 'update AGENTS.md', 'update README', new gotchas discovered, changed IPs/ports/versions, new services added, runbook-worthy procedures, or project instruction files growing stale. Do NOT use for writing new documentation from scratch."
license: MIT
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: low
  argument_hint: "[doc-or-path]"
---

# Update Docs

Post-session documentation sweep. Captures non-obvious knowledge into the right docs, trims bloat, and keeps project instruction files in sync.

## When to use

- After infrastructure, configuration, architecture, or operational changes
- When asked to refresh docs, instruction files, runbooks, or README content
- When a session uncovered new gotchas, changed versions, or added services

## When NOT to use

- Writing brand-new documentation sets from scratch
- Code correctness or security review -- use **code-review** or **security-audit**
- Code quality, slop, or maintainability cleanup -- use **anti-slop**
- Prompt authoring or reusable skill-file maintenance -- use **prompt-generator** or **skill-creator**

---

## AI Self-Check

Before presenting documentation updates, verify:

- [ ] Only documenting gotchas, decisions, and failure modes -- not defaults readable from config
- [ ] No stale counts introduced (used "N" or kept count accurate)
- [ ] Internal links verified (no broken references after renames or moves)
- [ ] Companion instruction files still aligned (AGENTS.md synced if CLAUDE.md changed)
- [ ] No orphaned gotchas for already-fixed issues
- [ ] Deprecated entries marked with `[DEPRECATED]` prefix and date, not silently removed
- [ ] Size check run (`wc -c`) -- instruction files under 40,000 chars

---

## Core Principle

**Document what you can't grep.** If it's in the source code, config files, or manifests, it doesn't belong in docs. Document: gotchas, decisions, failure modes, workarounds, implicit dependencies, and "the thing that took 30 minutes to figure out."

## Workflow

**Audit-only mode:** When invoked by full-review or when the user asks to "just report" or "check docs," run Steps 1-5 and report findings without making changes or committing. Skip Steps 6-7.

1. Identify changes
2. Categorize doc impact
3. Update affected docs (or report what needs updating in audit-only mode)
4. Verify internal links
5. Audit instruction-file bloat
6. Sync companion instruction files
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

Map changes to documentation targets. Common instruction file names: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CODEX.md`. Adapt to the project's doc structure:

| Change Type | Likely Docs to Update |
|-------------|----------------------|
| New/changed infrastructure specs | Project instruction file (`AGENTS.md` or equivalent), inventory docs |
| New service or app deployed | Project instruction file, deployment docs |
| IP/port/endpoint changes | Project instruction file, network inventory |
| Version bumps (runtimes, deps, images) | Project instruction file |
| New gotcha discovered | Project instruction file |
| Operational procedure performed | Runbooks |
| New secret or credential | Secrets inventory |
| CI/CD workflow changes | Project instruction file, pipeline docs |
| Docker/Compose changes | Project instruction file, deployment docs |
| Proxmox/LXC changes | Project instruction file, inventory docs |
| Rust crate/toolchain changes | Project instruction file, `README.md` (build prereqs) |
| Architecture decision | ADR if significant (see below), otherwise a short bullet in the instruction file |
| New env vars or config keys | `.env.example`, `README.md` (setup section) |
| New dependencies or setup steps | `README.md` (getting started / prerequisites) |
| API endpoint changes | `README.md` (API docs section), OpenAPI spec if applicable |
| Version bumps / new release cut | Grep for old version strings across Dockerfiles, compose files, Helm values, CI workflows, tests, README badges/install instructions -- stale versions are the #1 post-release doc rot |

**When to write an ADR:** If the decision affects multiple components, constrains future options, or reverses a previous decision, it's worth a dedicated Architecture Decision Record. If it's a one-liner ("switched from X to Y because Z"), a short bullet in the project's instruction file is enough.

### 3. Update Affected Docs

**For each affected doc, read it first, then make targeted edits.**

#### What to ADD:
- Gotchas that aren't obvious from code (e.g., "VIP refuses k8s traffic -- use direct IP")
- Implicit dependencies between components (e.g., "must restart pod after SealedSecret update")
- Failure modes and their symptoms (e.g., "PLEG unhealthy = container runtime frozen")
- Workarounds for known issues
- Operational constraints (e.g., "serial: 1 required -- removing it updates all nodes simultaneously")
- Connection strings and service endpoints when IPs, ports, or hostnames change
- Decisions and their rationale

#### When no docs exist yet:
- Don't create a full documentation set from scratch (out of scope)
- DO add a minimal entry to the project instruction file (CLAUDE.md, AGENTS.md, or equivalent) with the gotcha or operational note that prompted this
- If the project has no instruction file at all, note this to the user and suggest creating one with the essential gotcha. Don't block on it.

#### What NOT to add:
- Default values readable from config files or manifests
- Standard framework/platform behavior
- Information already in upstream docs
- Temporary state (in-progress work, one-time migration steps already completed)
- Verbose explanations -- one line per gotcha, expand only if the fix is non-obvious

### 4. Verify Internal Links

After editing docs, check that internal references still resolve:

```bash
# Adjust <instruction-files> to the repo's actual instruction files
grep -roEh '\[[^]]*\]\([^)#]+' <instruction-files> docs/ README.md 2>/dev/null | \
  sed 's/.*](//' | grep -v '^https\?://' | sort -u | while read -r path; do
    [[ -e "$path" ]] || echo "BROKEN LINK: $path"
  done
```

This catches `[text](path)` and `![alt](path)` links, strips anchors (`#section`),
and skips external URLs. Works on both GNU and BSD grep (no `-P` flag needed).
If files were renamed or moved, update all references.

### 5. Audit Project Instruction Files for Bloat

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
- Check size after edits: `wc -c <instruction-files> 2>/dev/null`

### 6. Sync Companion Instruction Files

If the project keeps multiple instruction files (`AGENTS.md` plus tool-specific variants, for example), keep them aligned after updates.

```bash
# Example: sync a canonical shared file into a tool-specific companion
test -f AGENTS.md && test -f <companion-instruction-file> && cp AGENTS.md <companion-instruction-file>
```

Review the copied file after syncing and remove any tool-specific commands or behavior that do not apply to that target.

**Default: instruction files are usually gitignored unless the project intentionally tracks them.** Check `.gitignore` and existing history before committing them.

### 7. Commit Documentation Changes

Only commit changes to tracked docs (inventory, runbooks, ADRs, and instruction files if the project commits them).

```bash
# Stage specific changed docs (don't blindly add everything)
git diff --name-only docs/ README.md 2>/dev/null | xargs -r git add
# Only if docs changed:
git diff --cached --quiet || git commit -m "docs: update [target] after [what changed]"
```

## Quick Reference: File Locations

| File | Purpose | Committed? |
|------|---------|-----------|
| `AGENTS.md` | Cross-tool project instructions | Depends on project (check .gitignore) |
| Tool-specific instruction file | Companion instructions for a specific agent/tool when a project keeps one | Depends on project (check .gitignore) |
| `docs/` | Project documentation (inventory, runbooks, ADRs) | Yes |
| `README.md` | Repo overview | Yes |

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

- **Documenting everything**: If it's in config files, don't repeat the default value in the instruction file. Document the gotcha around it.
- **Stale counts**: "13 dashboards" becomes wrong when you add one. Use "N dashboards" or keep the count accurate.
- **Orphaned gotchas**: A gotcha about a bug that was fixed 3 months ago is noise. Prune regularly.
- **Missing the companion sync**: If the project keeps multiple instruction files, keep them aligned after changes.
- **Over-documenting migrations**: Once a migration is complete and verified, condense to a one-liner and remove the step-by-step procedure.
- **Dangling links**: Renaming a doc without updating references elsewhere creates dead links that erode trust in documentation.
- **Deleting deprecated docs too early**: Keep deprecated entries visible for at least one release cycle so people find the migration path.

---

## Rules

- **Document deltas, not defaults.** Capture what changed, what broke, and what future sessions need to know.
- **Do not rewrite healthy docs for style alone.** Keep edits tied to real operational value.
- **Keep companion instruction files aligned.** If the repo maintains more than one instruction surface, update the others or note the drift explicitly.
- **Prefer stable wording over brittle counts.** Avoid numbers and one-off migration prose that will rot immediately.
