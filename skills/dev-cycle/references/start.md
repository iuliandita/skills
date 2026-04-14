# Dev Cycle: Start Mode Reference

Detailed procedures for starting a unit of work. Referenced from the main SKILL.md.

## When this reference loads

Load when the user invokes **dev-cycle** and the mode resolves to `start` (see SKILL.md Step 0). Not needed in finish mode.

---

## Step A1 details: Clean state + pull latest

The goal is to branch from an up-to-date base. Do not branch from stale local refs or from a dirty working tree.

### Pre-flight

```bash
# Must be inside a git work tree (not a submodule, not a worktree of another repo without intent)
git rev-parse --is-inside-work-tree

# Submodule guard: if inside a submodule, stop. Branching here requires the parent repo to
# update its pinned commit - that's a coordinated change, not a plain feature branch.
if git rev-parse --show-superproject-working-tree 2>/dev/null | grep -q .; then
  echo "Inside a submodule. Branch in the submodule only if that's intentional and"
  echo "you will coordinate the parent repo pin update. Otherwise cd to the parent."
  exit 1
fi

# Working tree must be clean (untracked files are fine; staged/modified are not).
git diff --cached --stat; git diff --stat
# Non-empty output means: commit, stash, or abort.

# If dirty, options:
#   a) commit the work on the current branch
#   b) stash it (git stash push -m "wip: pre-dev-cycle")
#   c) abort and ask the user what the leftover work is
```

Never silently stash - the user might have important uncommitted work. Ask.

### Determine the base branch

In order of reliability:

```bash
# 1. Explicit remote HEAD (most reliable)
git symbolic-ref --quiet refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'

# 2. Default branch from the forge
gh   repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null
glab repo view --output json 2>/dev/null | jq -r '.default_branch'
tea  repos show --output simple 2>/dev/null | awk '/^Default Branch:/ {print $3}'

# 3. Heuristic: main or master
git show-ref --verify --quiet refs/heads/main && echo main || echo master
```

If all three disagree, ask the user. Do not guess.

### Pull with fast-forward only

```bash
git fetch origin --prune
git checkout "$BASE_BRANCH"
git pull --ff-only
```

`--ff-only` refuses to create a merge commit on the base branch. If it fails, the local base has diverged - investigate (don't just `reset --hard`).

---

## Step A2 details: Size classification

Full table in `size-heuristics.md`. Apply the table, state the classification, and list the signals that drove it.

Good: "Classifying as **large** - adds a new public API endpoint, requires DB schema migration, and user said 'proper design needed'."

Bad: "This is large." (no signals shown)

When ambiguous, ask up to 2 disambiguating questions:
1. "How many files do you expect to touch?"
2. "Is this adding new public API/behavior or just modifying existing logic?"

Default to large on uncertainty. Spending 5 minutes on a spec for a 20-line fix wastes less than skipping a spec for a 2-week refactor.

---

## Step A3 details: Branch naming

### Forge-specific conventions

Check recent branches for patterns:

```bash
git branch -a --sort=-committerdate | head -20 | sed 's|remotes/origin/||' | sort -u
```

Common patterns:

| Pattern | Example |
|---------|---------|
| `type/description` | `feat/oauth-login`, `fix/token-race`, `chore/bump-deps` |
| `issue-number/description` | `123/oauth-login`, `456/token-race` |
| `user/description` | `alice/oauth-login` |
| `type/issue-description` | `feat/123-oauth-login` |

If no clear pattern, use `type/short-description` (conventional-commit-aligned).

### Type prefixes (aligned with conventional commits)

- `feat/` - new feature
- `fix/` - bug fix
- `refactor/` - code restructuring, no behavior change
- `perf/` - performance improvement
- `docs/` - documentation only
- `test/` - test additions/fixes
- `chore/` - build, tooling, deps
- `ci/` - CI config changes
- `revert/` - revert a previous change

### Create the branch

```bash
# Start point = current HEAD on the base branch (fresh pull)
git checkout -b "$BRANCH_NAME"
```

Verify: `git branch --show-current` and `git log -1 --oneline` should show the latest base commit.

---

## Step A4 details: Brainstorming fallback chain

### Order of preference

1. **`superpowers:brainstorming`** - the superpowers skill. Structured ideation with user-intent exploration.
2. **Other installed brainstorming skills** - try these names via the Skill tool:
   - `brainstorm`
   - `brainstorming`
   - `gsd-explore`
   - `ideate`
3. **Inline Socratic fallback** - when no brainstorming skill is available.

If the Skill tool reports "skill not found" for a name, move to the next. Don't retry the same name.

### Inline Socratic template

When no skill is installed AND the session is interactive, ask these questions one at a time. Wait for each answer before the next - do not batch them.

**If the session is non-interactive** (`--bare`, Codex `exec`, automations): skip the Q&A. Extract what you can from available context - issue body, branch name, conventional-commit scope, diff base, recent git log - and write a minimal spec. Mark each field that had no source with a `TODO:` prefix so a human can fill it in later. Do not block waiting for answers that cannot arrive.

```
1. Goal: "In one sentence, what should this work accomplish?"

2. Success: "How will we know it's done? What's the measurable or observable outcome?"

3. Out of scope: "What are we explicitly NOT doing here?"

4. Constraints: "What's the hardest constraint? (performance target, compatibility, deadline, team coordination, etc.)"

5. Risks: "What could go wrong or surprise us? Where are the unknowns?"

6. Reuse: "What existing code, patterns, or skills should we lean on?"
```

After the answers, compose the spec.

### Spec file template

Write to `SPEC.md` at repo root, or `specs/<branch-name>.md` if a `specs/` dir already exists.

```markdown
# Spec: {one-line title}

**Branch**: `{branch-name}`
**Date**: {YYYY-MM-DD}
**Size**: {small|medium|large}

## Goal

{one sentence}

## Success criteria

- {measurable outcome 1}
- {measurable outcome 2}

## Out of scope

- {explicit non-goal}

## Constraints

- {hard constraint}

## Risks and unknowns

- {risk 1 - what could go wrong}
- {unknown 1 - what to research}

## Approach sketch

{bullet points or short paragraphs - not a full design}

## Skills likely to engage

- {e.g., databases for migrations, docker for image updates}
```

Commit the spec as the first commit on the branch:

```bash
git add SPEC.md
git commit -m "docs: add spec for {title}"
```

### When NOT to write a spec

- Small work (typo, bump, single-file fix). Spec overhead exceeds task scope.
- User explicitly said "skip the spec, I've already scoped this in my head". Honor it, but note classification.
- A clear issue/ticket already exists and covers the spec content. Link to it in the PR body instead.

---

## Step A5 details: Handoff

End start mode cleanly. The next session will pick up in finish mode or continue implementation. Output should include:

```markdown
## Start Mode Complete

**Branch**: `{branch-name}` (from `{base-branch}` @ `{short-sha}`)
**Classification**: {small|medium|large} - {signals}
**Spec**: {path, if written, or "skipped - small"}

### Next steps

- Implement the change. Suggested skills based on what you'll touch:
  - {e.g., **databases** for the migration}
  - {e.g., **docker** when updating the image}
  - {e.g., **testing** when writing tests}

- When ready to ship, invoke **dev-cycle** in finish mode.

### Reminders

- Commit early, commit often. Keep commits atomic.
- Rebase against base periodically if the branch is long-lived.
- Do NOT add AI attribution to commits.
```

Do not start editing source files in start mode. If the user immediately asks you to begin implementation in the same session, that's fine - but the mode has ended. Switch to whatever implementation skill fits the task.

---

## Edge cases

### Already on a feature branch

If the current branch isn't the base branch when start mode runs:

- If it's a new branch with no commits (fresh checkout): safe to switch away
- If it has unpushed commits: ask the user. Options:
  - Finish that branch first (switch to finish mode)
  - Stash the branch and start fresh (`git stash` or `git worktree add` for parallel work)
  - Resume it later (leave alone, warn the user)

### Detached HEAD

Stop. Detached HEAD is almost always a mistake in this context. Ask the user to check out a named branch first.

### Submodules / monorepos

Run the pull/branch commands at the repo root. Submodules update via `git submodule update --init --recursive` after the pull. Monorepo subtrees may have different base branches - ask.

### No remote

Local-only repo. Skip the `fetch` and `pull` but still branch off the base. Warn the user that push/PR steps in finish mode won't work without a remote.
