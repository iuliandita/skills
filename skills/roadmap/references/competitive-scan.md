# Competitive Scan Workflow

Use this reference for Roadmap Mode 3.

## Step 1: Identify Targets

Accept GitHub or GitLab repo URLs, `owner/repo` references, project names to search for,
or "similar to this project" requests inferred from README, package.json, or project
description.

If the user does not provide targets, suggest 2-3 based on the project's domain and tech
stack. Confirm before scanning.

## Step 2: Gather Intelligence

For each target repo, fetch via forge CLI, web fetch, or the browse skill:

| Source | What to look for |
|--------|------------------|
| README.md | Feature list, project positioning |
| CHANGELOG.md / releases | Recent feature additions, velocity |
| **Issues (open + closed)** | What users are asking for, pain points, feature requests |
| **PRs (open + merged)** | What contributors are building, community direction |
| Discussions (if enabled) | User feedback, wishlists, complaints |
| GitHub topics + description | Market positioning |

Optionally scan the current project too, if it has a public repo, for open feature
requests, PR discussions, and user feedback. This supplements the competitive scan but
is secondary to the user's request.

The goal is understanding what real users want, not just what competitors built.

Sampling strategy for large repos: sort by reactions, cap results, and note coverage.

Detect the forge and use the matching CLI:

```bash
# GitHub (gh)
gh issue list -R owner/repo --state all \
  --search "sort:reactions-+1-desc" \
  --limit 50 --json number,title,reactionGroups,comments,labels 2>/dev/null
# Filter for feature/enhancement labels client-side; label names vary per repo.
gh pr list -R owner/repo --state merged \
  --limit 20 --json number,title,mergedAt 2>/dev/null

# GitLab (glab)
glab issue list -R owner/repo --sort popularity --per-page 50 2>/dev/null
glab mr list -R owner/repo --state merged --per-page 20 2>/dev/null
```

If neither `gh` nor `glab` is available, fall back to web fetch or the browse skill.
As a last resort, ask the user to paste relevant sections.

Note coverage limitations in Competitive Intel, for example: "scanned top 50 issues by
reactions, {total} total open".

## Step 3: Analyze Fit

Do not suggest features just because a competitor has them. Every suggestion must pass
this filter:

1. **Does it fit the project's identity?** A feature that makes sense for a competitor
   with a different audience or philosophy does not belong here.
2. **Are real users asking for it?** Evidence from issues, PRs, or discussions. User
   demand is stronger than competitor parity.
3. **Does it conflict with existing priorities?** If it would distract from P0 work or
   pull the project in a different direction, flag it as a distraction.

Rate each finding using concrete thresholds:

- **Strong signal**: 3+ distinct commenters, or a single issue with 10+ reactions
  (calibrate to repo size). Fits project direction and fills a visible gap.
- **Weak signal**: 1-2 user mentions with unclear fit, or a low-reaction feature
  request that aligns with the project's direction.
- **Noise**: no user evidence, different audience, scope creep, feature exists only
  in a competitor with no user demand, or solution without a problem.

When scanning multiple repos, note patterns that appear across sources. Features
requested in 2+ repos suggest broader user demand beyond any single project.

Assess project identity from README, package.json description, existing roadmap Snapshot,
and existing item patterns. Before applying the filter, state a one-sentence identity
assessment. If context is insufficient, ask the user to describe the project's scope.

Only present strong-signal items as suggestions. Mention weak signals briefly in the
Competitive Intel section for awareness. Drop noise entirely.

## Step 3.5: Present Findings

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

## Step 4: Update Roadmap

Add user-approved items to the appropriate priority tier with source attribution:
`-- from: owner/repo-name issues` or `-- user request: issue #N`.

Create or update the **Competitive Intel** section with the full analysis per repo,
including what was deliberately excluded and why.
