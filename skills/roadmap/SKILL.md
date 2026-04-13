---
name: roadmap
description: >
  · Capture project ideas, track progress, and scout competitors in a gitignored ROADMAP.md.
  Add ideas, check off shipped items after PRs or releases, scan competing repos and issues
  for what users want, review and prioritize. Triggers: 'roadmap', 'ideas', 'feature ideas',
  'competitive analysis', 'what should I build', 'feature backlog'. Not for structured project
  management (phases, milestones), code review (use code-review), or doc updates (use update-docs).
license: MIT
compatibility: "Requires git. Optional: gh (GitHub CLI) or glab (GitLab CLI) for PR tracking and competitive scanning"
metadata:
  source: iuliandita/skills
  date_added: "2026-04-05"
  effort: medium
  argument_hint: "[ideas... | update | scan <repo-url> | review]"
---

# Roadmap: Lightweight Project Idea Tracker

Manage a project's feature backlog in a gitignored ROADMAP.md. Quick idea capture, progress
tracking after PRs and releases, competitive intelligence from similar repos, and periodic
review to keep priorities honest.

Not a project management system. No phases, no execution plans, no milestones. Just a
scratchpad that evolves with the project.

## When to use

- Capturing feature ideas, brainstorms, or "what if" thoughts for a project
- Tracking which ideas shipped via PRs or releases
- Scanning competing or similar repos for feature inspiration
- Reviewing and prioritizing the idea backlog
- Bootstrapping a fresh ROADMAP.md for a project that doesn't have one
- User says "add to roadmap", "what should I build next", or "what are competitors doing"

## When NOT to use

- Structured project management with phases, milestones, execution plans
- Sprint or iteration planning with task dependencies
- Code review or PR review - use **code-review**
- Writing project docs or READMEs - use **update-docs**
- Tracking bugs or incidents - use issue trackers directly

---

## AI Self-Check

Before writing or modifying ROADMAP.md, verify:

- [ ] **Gitignored**: ROADMAP.md is in .gitignore (or user explicitly opted out of gitignoring)
- [ ] **No secrets**: entries don't contain API keys, internal URLs, or sensitive business info
- [ ] **Attribution preserved**: competitive intel cites the source repo or project
- [ ] **No duplicates**: new ideas don't repeat existing entries (check intent, not just wording)
- [ ] **Format preserved**: edits work within the existing file structure - don't reformat
      sections the user didn't ask to change
- [ ] **Shipped items attributed**: completed entries reference the PR, release, or commit
- [ ] **No hallucinated competitive data**: every feature, issue count, or user demand claim
      from a competitor repo is backed by an actual link or quote - not inferred
- [ ] **No priority inflation**: P0 items are genuine blockers, not aspirational wishes

---

## Roadmap Format

### Sections (fixed order)

Every ROADMAP.md uses these sections in this order. Empty sections can be omitted
but the order is not negotiable - consistency makes the file scannable. When adding
content to a previously omitted section, create it in the canonical position relative
to existing sections.

```markdown
# Roadmap

> Project: {name} | Updated: {date} | Current: v{version}
> Local planning doc, gitignored. Not a commitment.

## Snapshot

{1-2 paragraphs: project state, what the next milestone means, current focus}

## Exit Criteria

What "done" means for the next milestone. Each criterion has a verdict.

### {Criterion Name}

**Verdict**: Pass | Fail | Partial

- {Requirement}
- {Requirement}

## Now - P0

Blocks the next milestone or release. Active work only.

- [in-progress] {Description} - {area} | PR #{n}
- [planned] {Description} - {area}

## Next - P1

Committed direction. Happens after Now is clear.

- [planned] {Description} - {area}
- [exploring] {Description} - {area}

## Later - P2

Good ideas, no timeline. Revisit during review.

- {Description} - {context}

## Experiments

Low confidence. Build only with real demand signal.

- {Description} - {what would validate it}

## Shipped

### v{X.Y.Z} ({date})

- ~~{Description}~~ - {area} | PR #{n}, v{X.Y.Z} ({date})

## Competitive Intel

### {owner/repo}

- {Feature} ({relevant | weak signal | noise}) - {evidence}
- User demand: {issue links, discussion quotes, vote counts}

## Parked

Items deferred with reason.

- {Description} - {reason for parking}
```

### Item format

Items have two tiers depending on where they live:

**Active items (Now, Next)** - structured, with status and tracking:
```
- [status] Description - area | tracking
```

Status values: `exploring`, `planned`, `in-progress`

Area values are project-specific shorthand for the component or domain (e.g., `ui`,
`api`, `backend`, `infra`, `docs`, `auth`). Infer from the project's structure. If
unclear, omit the area rather than guessing.

**Backlog items (Later, Experiments)** - lightweight, quick capture:
```
- Description - context or source
```

Items gain structure as they're promoted. A quick idea in Later becomes a tracked
item when it moves to Next.

**Shipped items** always get attribution:
```
- ~~Description~~ - area | PR #N (or MR #N), vX.Y.Z (date)
```

### When a ROADMAP.md already exists

Read the existing structure first. If it doesn't match this format:
- In **add** or **update** modes: work within the existing structure, don't restructure
- In **review** mode: suggest migrating to this format if the current one is disorganized
- If the user asks to restructure: migrate section by section, preserving all content

---

## Workflow

### Step 0: Activity Detection (runs on every invocation)

If no ROADMAP.md exists yet or no recent activity is found, skip silently.

Otherwise, check for recent project activity:

```bash
# Detect forge CLI: gh (GitHub), glab (GitLab), or git-only fallback
# GitHub
gh pr list --state merged --limit 10 \
  --json number,title,mergedAt 2>/dev/null
# GitLab
glab mr list --state merged --per-page 10 2>/dev/null

# Always available (portable - no GNU date required)
git tag --sort=-creatordate 2>/dev/null | head -5
git log --oneline --since="2 weeks ago" 2>/dev/null | head -15
```

If neither `gh` nor `glab` is available, note it once ("PR tracking unavailable -
install gh or glab for full coverage") and continue with git-only data (tags + commits).

If merged PRs or new releases look like they match open roadmap items, mention it
briefly before proceeding:

> "Heads up: PR #142 and v0.15.0 landed since the last roadmap update.
> Want me to check those off first, or continue with {requested mode}?"

Don't block. If the user ignores it, proceed with their request.

---

### Mode 1: Add Ideas (default)

Trigger: user throws ideas at the project, says "add to roadmap", or describes features.

#### Step 1: Bootstrap if needed

1. Check if ROADMAP.md exists in the project root (in monorepos, default to the git
   root unless the user specifies a package - if multiple ROADMAP.md files exist, ask)
2. If not, create it using the starter structure. Read the project's README, package.json,
   or equivalent to fill in the Snapshot section with real context
3. Check if ROADMAP.md is in .gitignore - if not, add it:
   ```
   # Project roadmap (local planning doc)
   ROADMAP.md
   ```
   Inform the user: "Added ROADMAP.md to .gitignore. Remove the entry if you want it tracked."

#### Step 2: Parse and place ideas

Extract actionable items from the user's input. For each idea:
- Write a clear, concise description (keep the user's voice - clean up only if unclear)
- Place it in the right priority tier (ask if genuinely ambiguous, default to P1)
- Add context: where the idea came from, what it enables, any constraints mentioned

Append to the appropriate section. Don't reorder existing items.

#### Step 3: Offer competitive scan

If the roadmap has no competitive intel section and this is the first batch of ideas, ask:

> "Want me to scan similar repos for feature ideas that might fit {project-name}?"

Ask once per session. If declined, don't ask again.

---

### Mode 2: Update / Check Off

Trigger: user says "update roadmap", asks to check off items, or after a PR merge / release.

If no ROADMAP.md exists, redirect to Mode 1 (bootstrap) first.

#### Step 1: Gather recent activity

```bash
# Always available (portable - no GNU date required)
git log --oneline --since="2 weeks ago" 2>/dev/null
git tag --sort=-creatordate 2>/dev/null | head -5

# GitHub
gh pr list --state merged --limit 20 \
  --json title,number,mergedAt 2>/dev/null
# GitLab
glab mr list --state merged --per-page 20 2>/dev/null
```

Adjust the time range if the user specifies one. If the user names specific PRs
directly (e.g., "PR #45"), fetch those with `gh pr view 45 --json title,mergedAt`
(or `glab mr view 45`) instead of relying on the time-windowed list.

#### Step 2: Match activity to roadmap items

Compare commit messages, PR titles, and release notes against open roadmap items.
Use semantic matching - "add dark mode support" matches "Dark mode theme option".

Present matches to the user before making changes:

> Found these potential matches:
> - PR #142 "Add dark mode toggle" -> matches "Dark mode theme option" (P1)
> - v0.15.0 release includes backup/restore -> matches "Backup and restore" (P0)
>
> Check these off?

#### Step 3: Update the file

If the user already stated which items shipped (e.g., "PR #45 adds dark mode"),
treat that as pre-confirmed - present the planned changes for review rather than
re-asking "check these off?"

For confirmed matches:
1. Apply strikethrough: `~~description~~`
2. Add attribution: `-- PR #N, vX.Y.Z (date)` (include both when a PR and release apply)
3. Move to the "Shipped" section (create it if missing), grouped by version or date

Update the "Last updated" line in the header.

---

### Mode 3: Competitive Scan

Trigger: user asks to scan competitors, provides repo URLs, or accepts the Mode 1 offer.

#### Step 1: Identify targets

Accept:
- GitHub or GitLab repo URLs, or `owner/repo` references
- Project names to search for
- "Similar to this project" - infer from README, package.json, or project description

If the user doesn't provide targets, suggest 2-3 based on the project's domain and
tech stack. Confirm before scanning.

#### Step 2: Gather intelligence

For each target repo, fetch (via forge CLI, web fetch, or the browse skill):

| Source | What to look for |
|--------|-----------------|
| README.md | Feature list, project positioning |
| CHANGELOG.md / releases | Recent feature additions, velocity |
| **Issues (open + closed)** | What users are asking for, pain points, feature requests |
| **PRs (open + merged)** | What contributors are building, community direction |
| Discussions (if enabled) | User feedback, wishlists, complaints |
| GitHub topics + description | Market positioning |

**Optionally scan the current project too** (if it has a public repo) for open
feature requests, PR discussions, and user feedback. This supplements the competitive
scan but is secondary to the user's request.

The goal is understanding **what real users want**, not just what competitors built.

**Sampling strategy for large repos**: sort by reactions, cap results, note coverage.

Detect the forge and use the matching CLI:

```bash
# GitHub (gh)
gh issue list -R owner/repo --state all \
  --search "sort:reactions-+1-desc" \
  --limit 50 --json number,title,reactionGroups,comments,labels 2>/dev/null
# Filter for feature/enhancement labels client-side (label names vary per repo)
gh pr list -R owner/repo --state merged \
  --limit 20 --json number,title,mergedAt 2>/dev/null

# GitLab (glab)
glab issue list -R owner/repo --sort popularity --per-page 50 2>/dev/null
glab mr list -R owner/repo --state merged --per-page 20 2>/dev/null
```

If neither `gh` nor `glab` is available, fall back to web fetch or the browse skill.
As a last resort, ask the user to paste relevant sections.

Note coverage limitations in Competitive Intel ("scanned top 50 issues by reactions,
{total} total open").

#### Step 3: Analyze fit (strict filter)

Do not suggest features just because a competitor has them. Every suggestion must
pass this filter:

1. **Does it fit the project's identity?** A feature that makes sense for a competitor
   with a different audience or philosophy doesn't belong here.
2. **Are real users asking for it?** Evidence from issues, PRs, or discussions - not
   just "competitor X shipped it". User demand > competitor parity.
3. **Does it conflict with existing priorities?** If it would distract from P0 work or
   pull the project in a different direction, flag it as a distraction, not a suggestion.

Rate each finding using concrete thresholds:

- **Strong signal**: 3+ distinct commenters, or a single issue with 10+ reactions
  (calibrate to repo size - 10 reactions in a 50k-star repo is weak, 10 in a
  500-star repo is strong). Fits project direction, fills a visible gap.
- **Weak signal**: 1-2 user mentions with unclear fit, or a feature request with
  few reactions that aligns with the project's direction
- **Noise**: no user evidence, different audience, scope creep, feature exists only
  in a competitor with no user demand, or solution without a problem

When scanning multiple repos, note patterns that appear across sources - features
requested in 2+ repos suggest broader user demand beyond any single project.

**Assessing project identity**: infer from README, package.json description, existing
roadmap Snapshot, and the pattern of existing items. Before applying the filter, state
a one-sentence identity assessment (e.g., "This is a self-hosted music discovery tool
targeting audiophiles with large libraries"). If insufficient context, ask the user to
describe the project's scope before rating.

Only present strong-signal items as suggestions. Mention weak signals briefly in the
Competitive Intel section for awareness. Drop noise entirely.

#### Step 3.5: Present findings for approval

Before writing anything to ROADMAP.md, present the filtered findings:

> **Strong signal** (suggesting for roadmap):
> - Feature X - 15 reactions on owner/repo#123, aligns with our P1 direction
>
> **Weak signal** (for awareness only):
> - Feature Y - 1 mention in owner/repo#456, unclear fit
>
> Add the strong-signal items to the roadmap?

Wait for user approval. In headless mode, add strong-signal items and log weak signals
in Competitive Intel without prompting.

#### Step 4: Update roadmap

Add user-approved items to the appropriate priority tier with source attribution:
`-- from: owner/repo-name issues` or `-- user request: issue #N`

Create or update the **Competitive Intel** section with the full analysis per repo,
including what was deliberately excluded and why.

---

### Mode 4: Review / Prioritize

Trigger: user asks to review the roadmap, prioritize, or "what should I work on next".

#### Step 1: Load and summarize

Read ROADMAP.md. Present a summary:
- Item counts by priority tier
- Items currently in progress (if tracked)
- Recently shipped items
- Stale items: items untouched for 60+ days are candidates for archival or re-prioritization
  (use git blame or file modification dates to estimate age)

#### Step 2: Suggest actions

Based on the current state, flag any of these:
- **P0 items not being worked on** - supposed to be urgent; needs explanation or demotion
- **Items untouched 60+ days** - park with reason or promote; sitting isn't a priority
- **Related items scattered across tiers** - group into a cohesive effort
- **Shipped items still in active sections** - move to Shipped
- **Missing structure** - suggest organizational improvements

#### Step 3: Offer structural improvements

If the roadmap lacks clear organization, suggest improvements:
- Adding priority tiers if everything is a flat list
- Separating product work from promotion/go-to-market
- Adding a Snapshot section for project context
- Adding exit criteria for major milestones
- Creating an Experiments section for low-confidence ideas

Present suggestions. Apply only what the user approves.

#### Step 4: Apply changes

With user approval, reorganize, re-prioritize, park, or remove items. Never delete
silently - move to **Parked** with a reason, or confirm deletion explicitly.

---

## Reference Files

- `references/trigger-integration.md` - optional auto-trigger setup for Claude Code hooks,
  GitHub Actions, and git hooks. Read this when the user wants push-based roadmap updates
  instead of (or in addition to) the built-in activity detection.

## Related Skills

- **browse** - competitive scan (Mode 3) may use browse for reading competitor repos
  and documentation when web fetch alone isn't sufficient
- **git** - update mode (Mode 2) reads git history and PR data to match shipped work
- **code-review** - reviews code correctness. This skill tracks what to build;
  code-review evaluates the code that implements it
- **update-docs** - updates project documentation. This skill manages the roadmap;
  update-docs handles READMEs, API docs, and runbooks

## Rules

1. **Gitignore by default.** Ensure ROADMAP.md is in .gitignore before creating or writing it.
   Skip only if the user explicitly asks to track it in git.
2. **Don't rewrite the file.** Edits are additive or targeted. Don't reformat, reorder, or
   restructure sections the user didn't ask to change.
3. **Attribute competitive intel.** Every idea from another repo gets a source tag. Never
   present external features as original ideas.
4. **Ask before checking off.** Present matches and let the user confirm. Don't auto-complete
   roadmap items based on fuzzy matches alone.
5. **One offer per session.** Ask about competitive scanning at most once. If declined, drop it.
6. **No priority inflation.** Default to P1 when priority is unclear. P0 is reserved for
   genuine blockers, not aspirational items.
7. **Preserve user voice.** Keep the user's phrasing when adding ideas. Clean up only when
   genuinely unclear.
8. **Work within existing structure.** If a ROADMAP.md exists, adapt to its format. Suggest
   structural changes through review mode, not silently during adds or updates.
9. **Headless mode.** In non-interactive contexts (`--bare`, Cursor Automations, Codex
   `exec`): skip confirmation prompts, apply only exact matches in Mode 2, add only
   strong-signal items in Mode 3, and don't offer competitive scans in Mode 1.
