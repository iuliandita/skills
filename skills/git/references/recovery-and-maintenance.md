# Git Recovery & Maintenance

Reflog, bisect, rerere, filter-repo, stash, worktree, submodules, large repo optimization.

Research date: March 2026.

---

## Recovery Operations

### The reflog -- git's safety net

The reflog records every HEAD movement for 90 days. Almost nothing is truly lost in git.

```bash
# View reflog (all HEAD movements)
git reflog

# View reflog for a specific branch
git reflog show feature/auth

# Find a lost commit (e.g., after reset --hard)
git reflog | grep "commit: feat(auth)"
git checkout -b recovered-branch <sha>

# Recover a deleted branch
git reflog | grep "checkout: moving from feature/auth"
git checkout -b feature/auth <sha>

# Recover after a bad rebase
git reflog | grep "rebase"
git reset --hard HEAD@{5}  # number from reflog
```

**Reflog is local only.** It's not pushed to remotes. If you need to recover after a re-clone,
the reflog is gone. This is why `--force-with-lease` is safer than `--force` -- it at least
checks the remote state.

### Undo operations

| Situation | Command | Destructive? |
|-----------|---------|-------------|
| Undo last commit, keep changes staged | `git reset --soft HEAD~1` | No |
| Undo last commit, keep changes unstaged | `git reset HEAD~1` | No |
| Undo last commit, discard changes | `git reset --hard HEAD~1` | **Yes** |
| Revert a pushed commit | `git revert <sha>` | No (new commit) |
| Undo a merge commit | `git revert -m 1 <merge-sha>` | No (new commit) |
| Unstage a file | `git restore --staged <file>` | No |
| Discard changes to a file | `git restore <file>` | **Yes** |
| Discard all changes | `git restore .` | **Yes** |
| Undo an amend | `git reset --soft HEAD@{1}` | No |
| Undo a rebase | `git reset --hard ORIG_HEAD` or reflog | **Yes** |

**Rule**: prefer `revert` over `reset` for shared branches. `revert` creates a new commit
(safe), `reset` rewrites history (requires force-push).

### Bisect -- find the commit that broke things

```bash
# Start bisect
git bisect start

# Mark current as bad
git bisect bad

# Mark a known-good commit
git bisect good v1.0.0

# Git checks out a middle commit. Test it, then:
git bisect good   # if this commit works
git bisect bad    # if this commit is broken

# Repeat until git finds the first bad commit

# Automated bisect (run a test script)
git bisect start HEAD v1.0.0
git bisect run bun test -- src/auth.test.ts

# When done
git bisect reset
```

### Cherry-pick

```bash
# Pick a single commit from another branch
git cherry-pick <sha>

# Pick a range of commits
git cherry-pick <oldest>^..<newest>

# Cherry-pick without committing (stage only)
git cherry-pick --no-commit <sha>

# If cherry-pick conflicts
git cherry-pick --continue   # after resolving
git cherry-pick --abort      # give up
```

**Warning**: cherry-picking creates a new commit with a different SHA. If the original commit
is later merged, git sees them as unrelated changes, which can cause duplicate changes or
conflicts.

---

## Stash

```bash
# Stash working changes
git stash

# Stash with a message
git stash push -m "wip: auth refactor"

# Stash including untracked files
git stash push -u -m "wip: including new files"

# List stashes
git stash list

# Apply most recent stash (keep in stash list)
git stash apply

# Apply and remove from stash list
git stash pop

# Apply a specific stash
git stash apply stash@{2}

# Show stash diff
git stash show -p stash@{0}

# Drop a specific stash
git stash drop stash@{2}

# Clear all stashes
git stash clear
```

**Stash gotcha**: stash is a stack (LIFO). `git stash pop` pops the most recent. If you have
multiple stashes, use `git stash list` and apply by index.

---

## History Rewriting

### Interactive rebase (manual only -- never automated)

Interactive rebase (`git rebase -i`) requires a TTY. Never use it in automated/AI contexts.
Instead, use specific rebase operations:

```bash
# Squash last N commits into one
git reset --soft HEAD~3 && git commit -m "feat: combined change"

# Reword last commit message
git commit --amend -m "fix(auth): correct token validation"

# Rebase onto updated base branch
git rebase origin/main

# Rebase with autosquash (for fixup! and squash! commits)
git rebase --autosquash origin/main
```

### git-filter-repo -- the right tool for history rewriting

`git-filter-repo` (Python) replaces the deprecated `git filter-branch`. It's faster, safer,
and handles edge cases that filter-branch misses.

```bash
# Install
pip install git-filter-repo
# Or: pacman -S git-filter-repo
# Or: brew install git-filter-repo

# Remove a file from entire history
git filter-repo --invert-paths --path secrets.env

# Replace text in all files across history
git filter-repo --replace-text <(echo 'old_domain.com==>REDACTED')

# Remove a directory from history
git filter-repo --invert-paths --path vendor/

# Rename a directory across history
git filter-repo --path-rename old_name/:new_name/

# Filter by message (remove commits matching pattern)
git filter-repo --message-callback 'return message.replace(b"INTERNAL", b"REDACTED")'

# After filter-repo: force-push everything
git remote add origin <url>  # filter-repo removes remotes for safety
git push origin --force --all
git push origin --force --tags
```

**After history rewriting:**
1. All team members must re-clone or `git fetch --all && git reset --hard origin/main`
2. Forge caches may retain old objects. GitHub: contact support for immediate purge.
   GitLab: `git gc` runs automatically. Forgejo: varies by version.
3. Tags referencing rewritten commits become dangling. Recreate them.

---

## Rerere -- remember conflict resolutions

`rerere` (reuse recorded resolution) records how you resolve merge conflicts and automatically
applies the same resolution next time.

```bash
# Enable rerere
git config --global rerere.enabled true

# When you resolve a conflict, rerere records it automatically
# Next time the same conflict occurs, git applies your previous resolution

# View recorded resolutions
git rerere status

# Forget a specific resolution
git rerere forget <file>
```

Particularly useful for long-lived feature branches that frequently rebase against a moving
base branch -- you resolve each conflict once, and rerere handles it on subsequent rebases.

---

## Worktrees

Worktrees create additional working directories linked to the same repo. Useful for:
- Working on two branches simultaneously without stashing
- Running tests on one branch while coding on another
- Code review (check out PR branch in a worktree)

```bash
# Create a worktree for an existing branch
git worktree add ../myrepo-feature feature/auth

# Create a worktree with a new branch
git worktree add -b fix/bug ../myrepo-fix main

# List worktrees
git worktree list

# Remove a worktree
git worktree remove ../myrepo-feature

# Prune stale worktree references
git worktree prune
```

**Worktree gotcha**: you can't have the same branch checked out in two worktrees. If you try,
git refuses. This prevents conflicting changes to the same branch.

---

## Submodules vs Subtrees

### Submodules

Pointer to a specific commit in another repo. The parent repo stores the URL and commit SHA.

```bash
# Add a submodule
git submodule add https://github.com/lib/repo vendor/lib

# Clone a repo with submodules
git clone --recurse-submodules <url>

# Update submodules to latest
git submodule update --remote --merge

# Initialize submodules after clone (if --recurse-submodules wasn't used)
git submodule update --init --recursive
```

**Submodule gotchas**:
- Developers forget `--recurse-submodules` on clone, get empty dirs
- Submodule updates are a separate commit (easy to forget)
- Detached HEAD in submodules is confusing
- CI needs `--recurse-submodules` in checkout step

### Subtrees

Merges the external repo's history into your repo. Simpler for consumers, complex for maintainers.

```bash
# Add a subtree
git subtree add --prefix vendor/lib https://github.com/lib/repo main --squash

# Update a subtree
git subtree pull --prefix vendor/lib https://github.com/lib/repo main --squash
```

**When to use which**:
- **Submodules**: external dependency that's independently versioned, you don't modify it
- **Subtrees**: vendored code you may need to modify, or you want consumers to not deal with submodules

---

## Large Repository Optimization

### Partial clone (git 2.25+)

```bash
# Clone without blob objects (download on demand)
git clone --filter=blob:none <url>

# Clone without trees (even lighter, for CI)
git clone --filter=tree:0 <url>

# Shallow clone (only latest N commits)
git clone --depth 1 <url>

# Deepen a shallow clone later
git fetch --deepen=50
git fetch --unshallow  # full history
```

### Sparse checkout (git 2.37+ cone mode)

```bash
# Enable sparse checkout
git sparse-checkout init --cone

# Only check out specific directories
git sparse-checkout set src/ tests/

# Add more directories
git sparse-checkout add docs/

# Disable (get everything back)
git sparse-checkout disable
```

Useful for monorepos where you only need a subset of the codebase.

### Maintenance and gc

```bash
# Run maintenance tasks (repack, gc, commit-graph, multi-pack-index)
git maintenance start  # schedules periodic maintenance

# Manual gc
git gc --aggressive  # full repack, slow but thorough

# Check repo health
git fsck --full

# Prune unreachable objects
git prune --expire=now  # usually handled by gc

# Check repo size
git count-objects -vH
```

### commit-graph (git 2.34+)

```bash
# Generate commit-graph (speeds up log, merge-base, reachability)
git commit-graph write --reachable

# Verify commit-graph
git commit-graph verify
```

Significant speedup for repos with 10k+ commits. The `git maintenance` schedule handles this
automatically.

---

## Useful Aliases

```bash
# Log formats
git config --global alias.lg "log --oneline --graph --decorate -20"
git config --global alias.ll "log --pretty=format:'%C(yellow)%h%Creset %s %C(dim)(%cr by %an)%Creset' -20"

# Status shortcuts
git config --global alias.st "status -sb"
git config --global alias.staged "diff --cached --stat"

# Branch management
git config --global alias.branches "branch -vv"
git config --global alias.gone "!git branch -vv | grep ': gone]' | awk '{print \$1}'"
git config --global alias.cleanup "!git branch --merged main | grep -v main | xargs -r git branch -d"

# Undo shortcuts
git config --global alias.undo "reset --soft HEAD~1"
git config --global alias.unstage "restore --staged"

# Diff shortcuts
git config --global alias.last "diff HEAD~1"
```

---

## Housekeeping Checklist

Regular maintenance for healthy repos:

- [ ] **Prune merged branches**: `git branch --merged main | grep -v main | xargs -r git branch -d`
- [ ] **Prune remote tracking branches**: `git fetch --prune` (removes tracking branches for deleted remotes)
- [ ] **Check for large files**: `git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print $3, $4}' | sort -rn | head`
- [ ] **Verify repo integrity**: `git fsck --full`
- [ ] **Run gc if needed**: `git gc` (usually automatic, but manual after large filter-repo ops)
- [ ] **Update hooks**: check pre-commit config is current, hook tools are up to date
- [ ] **Review .gitignore**: new tools, new build artifacts, new AI tooling dirs
- [ ] **Check credential helper**: `git config credential.helper` -- ensure it's not `store` (plaintext)
