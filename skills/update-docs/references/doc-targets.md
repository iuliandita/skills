# Documentation Targets

The change-type to documentation-target map with the gotcha placement heuristic, and the file location quick reference.

## 2. Categorize Doc Impact

Map changes to documentation targets. Common instruction file names: `CLAUDE.md`, `AGENTS.md`, `CODEX.md`. Adapt to the project's doc structure:

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
| Release cut or version bump (roadmap-side) | `ROADMAP.md` header (`Current` / `Updated`), Shipped Highlights section, status docs |
| Multiple shipped features since last roadmap update | `ROADMAP.md` Shipped Highlights prose and Where-We-Are summary (item status moves belong to **roadmap** Mode 2) |
| Gitignored private roadmap AND committed public roadmap both present | Update both - private gets the deeper internal detail, public gets the user-visible summary |
| Strategy or sequencing changes | `ROADMAP.md`, status docs, milestone docs |

**When to write an ADR:** If the decision affects multiple components, constrains future options, or reverses a previous decision, it's worth a dedicated Architecture Decision Record. If it's a one-liner ("switched from X to Y because Z"), a short bullet in the project's instruction file is enough.

**Gotcha placement heuristic:**
- One-liner gotcha (e.g., "VIP refuses k8s traffic - use direct IP") -> project instruction file bullet.
- Multi-step procedure (e.g., "rotating a cert requires drain, replace, reload in order") -> dedicated runbook section.
- Time-critical pre/post-deploy action (e.g., "Redis FLUSHALL must run after deploy but before traffic is routed back") -> checklist at the top of the runbook, not buried in a section.

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
