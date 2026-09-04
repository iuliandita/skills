# Skill Audit Fixes and Report Rendering Design

Date: 2026-09-04
Status: approved for planning
Source audit: `docs/local/audits/skill-creator/2026-09-04-full-collection-audit.md`

## Goal

Resolve every actionable finding from the September 2026 full skill-creator audit and replace the inline Unicode box/table report format with a layout that renders cleanly in Codex, Claude Desktop, and terminal clients.

## Scope

The implementation covers the 15 actionable audit findings:

- MCP path containment, SSRF guidance, and graceful shutdown
- Security-audit output paths and pass numbering
- Full-review and deep-audit cross-harness delegation
- Dev-cycle version detection
- Portable Agent Skills validation
- Kubernetes context binding
- Non-portable `paths:` guidance and declarations
- Trigger precision, missing aliases, reciprocal routes, and ownership boundaries
- Shared output-contract rendering and all generated per-skill copies

The two informational audit items require no source fix. The completed audit report will be updated as fixes are verified.

## Report Rendering

### Inline transcript

Use the approved hybrid terminal treatment:

1. A fenced `text` block provides the report name, state, target, finding count, verification state, and deliverable path. Fenced text gives Codex and Claude Desktop a monospace font without depending on box-drawing glyphs.
2. Severity summaries use small colored markers outside aligned text:
   - red circle for P0
   - orange circle for P1
   - yellow circle for P2
   - blue circle for P3
   - white circle for info
3. Findings are grouped by severity. Each group has a Markdown heading with its colored marker and a fenced `text` block containing numbered one-line summaries.
4. The inline conclusion is a short fenced `text` block with totals, verification result, and the next action. It does not repeat every finding in a fixed-width table.
5. Color is supplemental. The literal severity label remains present, so the report remains understandable in monochrome terminals and for readers who cannot distinguish the marker colors.

Do not emit ANSI escape sequences, HTML styling, Unicode box-drawing borders, or aligned emoji columns. Those forms render inconsistently across desktop and terminal clients.

### Written deliverable

Keep the existing pure-Markdown deliverable format:

- H1 metadata header
- findings grouped under P0/P1/P2/P3/Info headings
- one checkbox per finding
- file, description, suggested action, and fix-applied fields
- normal Markdown conclusion table

The saved file is optimized for GitHub, GitLab, editors, and durable follow-up. It does not need to mimic the compact inline transcript.

### Shared contract rollout

Edit `skills/_shared/output-contract.md`, update every skill section that still promises a boxed header or boxed conclusion table, then run `scripts/gen-contract-refs.sh`. Update lint allowances for the orange and white severity markers. Generated `references/output-contract.md` files remain build outputs and are never hand-edited.

## Functional Fixes

### MCP security and lifecycle

- Replace lexical path-prefix validation with realpath containment for existing targets. Document a separate parent-realpath pattern for new write targets.
- Replace the check-then-fetch SSRF helper. Prefer an explicit hostname allowlist. Where arbitrary hosts are required, validate every resolved address, pin the request to validated resolution, preserve Host/SNI, and revalidate redirects.
- Rework the TypeScript stdio scaffold into an awaited `main()` with explicit server/transport lifecycle, SIGINT/SIGTERM handlers, cleanup, and surfaced errors.
- Verify all SDK names and signatures against current primary documentation before writing the examples.

### Security-audit report consistency

- Make `docs/local/audits/security-audit/<YYYY-MM-DD>-<slug>.md` the only report path.
- Remove root-level `SECURITY-AUDIT.md` generation, relocation, and gitignore instructions from security-audit, full-review, and deep-audit.
- Add Agentic AI and Supply Chain as pass 3 in the report guide and align all later pass numbers with the nine-pass workflow.

### Cross-harness orchestration

- Replace the literal `general-purpose` requirement with capability requirements: independent context, repository read access, the tools required by the assigned audit, and the native ability to load or receive the target skill.
- Tell each harness to use its native skill-loading and delegation mechanism. Exact role names belong only in labeled harness examples.
- Prefer specialized read-only reviewer roles where available, provided they can follow the assigned skill and return the required report.
- Keep fallback behavior explicit when subagents or skill loading are unavailable.

### Scripts and operational safety

- Change dev-cycle version discovery to treat missing and JSON `null` values as empty, validate the selected version before searching, and fail clearly when no source exists.
- Make `scripts/validate-spec.sh` validate the open standard only: require name and description, allow optional license, accept descriptions through 1024 characters, and treat the under-500-line guidance as a warning. Keep stricter collection policy in `scripts/lint-skills.sh`.
- Capture the chosen Kubernetes context and pass it explicitly to every cluster-aware kubectl and Helm validation command.

### Portability and routing

- Remove `paths:` from the portable ci-cd and docker skill sources. Document it as a Claude Code-local extension that can make skills invalid for claude.ai upload and Skills API packaging.
- Qualify broad description triggers with their domain.
- Replace zero-day's bare `CVE` trigger with CVE variant-analysis phrases.
- Replace full-review's generic `run all checks` and `full check` triggers with explicit multi-audit phrases.
- Add missing high-value aliases for app translation, the current MCP server package/client wording, EndeavourOS/Manjaro, and VMware/ESXi.
- Define reciprocal ownership for ci-cd/code-review, terraform/ci-cd, skill-creator/skill-router, databases/observability, domain hardening/security-audit, MCP/backend-api, and frontend-design/jekyll-hyde.

## Verification

Add or update regression coverage for:

- a standard-valid skill without `license`
- descriptions between 601 and 1024 characters
- body-length warning behavior
- missing and `null` package versions
- generated shared-reference synchronization
- absence of the obsolete root security-report protocol
- absence of Unicode box-drawing glyphs from the inline contract
- required severity labels and color markers
- trigger descriptions staying within the collection budget

Run every `scripts/check-*.sh` gate, `scripts/lint-skills.sh`, `scripts/validate-spec.sh`, all `scripts/test-*.sh` tests, shell syntax checks for edited scripts, and `git diff --check`. Forward-test MCP, security-audit, full-review, deep-audit, dev-cycle, and the revised report format with normal and edge-case prompts.

## Delivery

Implement on the existing `skill-creator/2026-09-03-235854` branch in small reviewable batches. Do not edit generated reference copies directly. Update the local audit report checkboxes after verification. Before publishing, create the required tracked issue, open a PR against `main`, wait for green CI, and squash merge only with explicit approval for those external actions.
