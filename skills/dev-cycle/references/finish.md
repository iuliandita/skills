# Dev Cycle: Finish Mode Reference

Detailed procedures for finishing a unit of work - from verification through merge and release.

## When this reference loads

Load when the user invokes **dev-cycle** in finish mode (see SKILL.md Step 0). Not needed in start mode.

---

## Step B1 details: Pre-close audit and forge detection

Before running expensive checks, sanity-check the branch **and identify the forge**. Every subsequent step that touches a remote (push, PR, CI watch, merge, release) dispatches on `$FORGE`.

### Detect the forge

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
FORGE=""
case "$REMOTE_URL" in
  "")                           FORGE=bare ;;         # no remote at all, purely local
  *github.com[:/]*)             FORGE=github ;;
  *gitlab.com[:/]*|*gitlab.*)   FORGE=gitlab ;;       # gitlab.com or self-hosted gitlab
  *codeberg.org[:/]*)           FORGE=forgejo ;;      # Codeberg runs Forgejo
  *gitea.*|*forgejo.*)          FORGE=forgejo ;;      # self-hosted Forgejo/Gitea
  *bitbucket.org[:/]*)          FORGE=bitbucket ;;
  *)                            FORGE=unknown ;;      # self-hosted; CLI tool may not exist
esac

# Pick the CLI (empty if none available)
FORGE_CLI=""
case "$FORGE" in
  github)                 command -v gh  >/dev/null && FORGE_CLI=gh  ;;
  gitlab)                 command -v glab >/dev/null && FORGE_CLI=glab ;;
  forgejo)                command -v tea  >/dev/null && FORGE_CLI=tea ;;
  bitbucket|unknown|bare) FORGE_CLI="" ;;
esac

echo "Forge: $FORGE | CLI: ${FORGE_CLI:-none}"
```

**What each value means for later steps**:

| `$FORGE` | `$FORGE_CLI` | Push/PR/merge path |
|----------|--------------|--------------------|
| `github` | `gh` | Standard PR flow via `gh` |
| `gitlab` | `glab` | MR flow via `glab` |
| `forgejo` | `tea` | PR flow via `tea` (Codeberg, self-hosted Forgejo/Gitea) |
| `bitbucket` | (none - no official CLI) | Manual push + create PR in web UI; skill provides the URL |
| `unknown` | (none) | Self-hosted. Ask user: is this a Gitea/GitLab/other? If unclear, treat as bare. |
| `bare` | n/a | No remote; share via format-patch or direct ref-push. Manual integration. |

If `$FORGE_CLI` is empty for a forge that normally has one, install it (`brew install gh` etc.) or fall through to the manual web-UI path. Don't silently skip the step.

### Sanity-check the branch

```bash
# Staged or modified files? (untracked files are fine - they're not part of HEAD)
git diff --cached --stat; git diff --stat
# If either is non-empty: commit, stash, or abort. Untracked files in `git status` output
# are NOT a reason to stop - only staged/modified matter here.

# Commits ahead of base?
git log --oneline "$BASE_BRANCH"..HEAD
# If empty: branch has no unique commits. Nothing to ship.

# Diff scope sanity check
git diff "$BASE_BRANCH"..HEAD --stat

# Remote sync (skip if $FORGE is bare)
if [[ "$FORGE" != "bare" ]]; then
  git fetch origin
  git rev-list --left-right --count "origin/$BRANCH_NAME...HEAD" 2>/dev/null
  # left=0 right=N: N local commits not yet pushed (normal)
  # left=N right=0: N remote commits not yet pulled (pull first)
  # left=N right=M: diverged (ask user)
fi
```

Determine the base branch from the PR target if one exists, else from `origin/HEAD`. For `$FORGE=bare`, ask the user - there's no remote HEAD to read.

---

## Step B2 details: Lint, type, test

### Delegate to the testing skill

Prefer this over a hand-rolled invocation:

> "Invoke the **testing** skill via the Skill tool. Run the repo's full lint, type, and test suites. Report pass/fail with evidence. Do not silence failures or rerun with exclusions."

If the testing skill isn't available, detect the toolchain and run manually.

### Toolchain detection + commands

Check in order - first match wins. If no language manifest matches, **keep going** to the task-runner and custom-script rows. Many repos (infrastructure, skill collections, dotfiles, mixed-language monorepos) have no language manifest at all.

| Signal | Commands |
|--------|----------|
| `package.json` with `"lint"`/`"typecheck"`/`"test"` scripts | `bun run lint && bun run typecheck && bun test` (or npm/pnpm/yarn) |
| `package.json` without lint/test scripts | Check for `eslint`, `tsc`, `jest`/`vitest` in devDependencies; run directly |
| `pyproject.toml` + `ruff` config | `ruff check . && ruff format --check . && mypy . && pytest` |
| `pyproject.toml` without ruff | `flake8 \|\| pylint` + `mypy` + `pytest` |
| `go.mod` | `gofmt -l . && go vet ./... && go test ./...` |
| `Cargo.toml` | `cargo fmt --check && cargo clippy -- -D warnings && cargo test` |
| `Gemfile` | `bundle exec rubocop && bundle exec rspec` |
| `composer.json` (PHP) | `composer run-script lint && composer test` (check scripts block) |
| `pom.xml` / `build.gradle*` | `mvn verify` / `./gradlew check` |
| `mix.exs` | `mix credo && mix test` |
| `Package.swift` | `swift build && swift test` |
| `Makefile` with `lint`/`test`/`check` targets | `make lint test` (or whichever targets exist - grep for target names) |
| `justfile` | `just --list` to discover; run obvious candidates like `just lint test` |
| `Taskfile.yml` | `task --list` then run discovered tasks |
| `scripts/` dir with executable bash/python | Look for `lint`, `test`, `check`, `ci`, `validate`, `verify` in filenames. Run found scripts. |
| `bin/` dir with executable scripts | Same pattern as `scripts/` |
| Nx / Turbo monorepo | `nx run-many -t lint test` or `turbo run lint test` |
| **No detectable toolchain** | **Stop and ask the user**: "I can't detect a lint/test convention in this repo. How should I verify the change? Options: (a) run a specific command you'll provide, (b) skip verification with explicit acknowledgement, (c) abort finish-mode." Do NOT silently proceed - a finish report with no actual verification is a false green. |

### Detection heuristic

```bash
# Quick scan for custom entry points when no manifest matches
find . -maxdepth 2 -type f \( -name Makefile -o -name justfile -o -name Taskfile.yml -o -name Taskfile.yaml \) 2>/dev/null
find scripts bin -maxdepth 2 -type f -executable 2>/dev/null | \
  grep -Ei '(lint|test|check|ci|validate|verify)' | head -20
# Also check README/CONTRIBUTING for documented commands
grep -Ei '^\s*(\$ )?(bash |sh )?\./?(scripts|bin)/[a-z-]+\.sh' README.md CONTRIBUTING.md 2>/dev/null
```

If this returns nothing useful AND no language manifest matched, hit the "No detectable toolchain" row - ask the user, don't guess.

### Inspect output, don't infer

```bash
# WRONG - trusting exit code alone
bun test && echo "ok"

# RIGHT - capture output, verify tests actually ran
bun test 2>&1 | tee /tmp/test-output.log
grep -E "(passed|failed|skipped|tests)" /tmp/test-output.log
```

Common traps:

- Exit 0 with "no tests found" - the runner couldn't locate tests. Fix config.
- Exit 0 with skipped suites - check what was skipped and why.
- Flaky tests - rerun identical commit to confirm. Don't retry until green.

### Red = stop

If anything is red, stop the workflow. Fix the root cause. Do not:

- Use `--no-verify`
- Add `skip` / `xit` / `pytest.mark.skip` to make tests pass
- Commit with "will fix later"
- Merge and file a follow-up ticket

If the failure is outside the branch's scope (pre-existing breakage), stop and ask the user how to proceed.

---

## Step B3 details: Doc and version sync

This is where quality slips. Address it in three parts.

### Part 1: Delegate to update-docs

> "Invoke the **update-docs** skill via the Skill tool. Run in update mode (not read-only). Sweep README, CHANGELOG, roadmap, instruction files, companion files, **AND gitignored context files** (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, files under `.claude/`, `.codex/`, `.opencode/`, and private `.planning/` directories). Address drift caused by the current branch's changes in all of them."

**Why gitignored files still need updating**: these files are often agent instruction files, developer context notes, or per-AI-tool config. They're gitignored because they're local or personal, not because they're disposable. Stale instruction files mislead the next session just as badly as stale READMEs. Keep them current even though they won't be staged.

**Staging discipline**: after update-docs runs, classify each modified file:

```bash
# Tracked docs (stage for commit)
git diff --name-only                              # modified, tracked

# Gitignored docs (leave unstaged; verify they ARE gitignored, not new-untracked)
git ls-files --others --exclude-standard          # untracked (new files - review before ignoring)
comm -12 <(git ls-files --others | sort) <(git status --short | awk '{print $2}' | sort)
# Or simply: for each ??-marked file in `git status`, check with `git check-ignore <file>`
```

Only `git add` the tracked set. Gitignored edits land locally but are intentionally out of the PR.

Review update-docs findings. Accept, modify, or defer each. Defer only with a note in the PR body ("docs for X tracked in #Y, not blocking this merge").

### Part 2: Version bumps

See `version-bump-sites.md` for grep patterns and locations. Walk the list:

1. Identify all version strings in the repo
2. Determine the new version from the change scope (major/minor/patch)
3. Propose a diff to the user - **do not auto-edit**
4. Apply after confirmation
5. Re-run tests if version strings appear in fixtures

### Part 3: CHANGELOG entry

If a CHANGELOG exists (usually `CHANGELOG.md`):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- {new features from this branch}

### Changed
- {behavior changes}

### Fixed
- {bug fixes}

### Removed
- {deprecations/removals}
```

Match the existing style. Some repos use Keep a Changelog, some use emoji prefixes, some conventional-commits-derived. Preserve their format.

### Part 4: Tests referencing version

Grep for the old version string across tests:

```bash
rg --fixed-strings "$OLD_VERSION" test/ tests/ spec/ __tests__/
rg --fixed-strings "$OLD_VERSION" '*.snap'
```

Update or regenerate snapshots. Rerun tests.

---

## Step B4 details: Final code review

### Delegate to code-review

> "Invoke the **code-review** skill via the Skill tool. Review the diff `{BASE_BRANCH}..HEAD`. Focus on correctness, edge cases, and convention violations. Return blocking issues separately from suggestions."

Pass the base branch, not HEAD alone. The reviewer needs to see the full change set.

### Triage

- **Blocking**: fix before push. Loop back to Step B2 after fixing.
- **Should-fix**: fix in this PR if quick, else file a follow-up.
- **Nit**: ignore or fix at your discretion.

Document the triage in the PR body if the review found issues.

---

## Step B5 details: Push and PR

The **git** skill handles this for every forge. Prefer delegation:

> "Invoke the **git** skill via the Skill tool. Push the current branch to origin (with upstream tracking) and open a PR/MR against `{BASE_BRANCH}`. Conventional-commit title, summary + test plan in body. No AI attribution trailers."

If the git skill isn't available, dispatch on `$FORGE` from Step B1. Skip to "No forge CLI" if `$FORGE_CLI` is empty.

### GitHub (`$FORGE=github`, `gh`)

```bash
git push -u origin "$BRANCH_NAME"

gh pr create \
  --base "$BASE_BRANCH" \
  --title "feat(scope): short description" \
  --body "$(cat <<'EOF'
## Summary

- Bullet 1
- Bullet 2

## Test plan

- [x] Lint clean
- [x] Type checks pass
- [x] Unit tests green
- [x] update-docs run; drift addressed
- [x] code-review run; issues resolved

Closes #123
EOF
)"
```

Recent-PR style check: `gh pr list --state merged --limit 10 --json title --jq '.[].title'`

### GitLab (`$FORGE=gitlab`, `glab`)

```bash
git push -u origin "$BRANCH_NAME"

glab mr create \
  --target-branch "$BASE_BRANCH" \
  --title "feat(scope): short description" \
  --description "$(cat <<'EOF'
## Summary
- Bullet 1

## Test plan
- [x] Lint/type/tests green
- [x] Docs + versions synced
EOF
)"

# Capture the MR number for later steps (B6 watch, B7 merge).
# glab auto-detects from the current branch for most commands, but being explicit avoids surprises.
MR_IID=$(glab mr view --output json 2>/dev/null | jq -r '.iid // empty')
echo "MR IID: ${MR_IID:-unknown}"
```

Recent-MR style: `glab mr list --state merged --per-page 10 --output json | jq -r '.[].title'`

### Forgejo / Gitea / Codeberg (`$FORGE=forgejo`, `tea`)

```bash
git push -u origin "$BRANCH_NAME"

tea pulls create \
  --base "$BASE_BRANCH" \
  --head "$BRANCH_NAME" \
  --title "feat(scope): short description" \
  --description "$(cat <<'EOF'
## Summary
...
## Test plan
...
EOF
)"
```

### Bitbucket (`$FORGE=bitbucket`, no official CLI)

Push the branch, then open the PR in the web UI:

```bash
git push -u origin "$BRANCH_NAME"

# Compose the create-PR URL (Bitbucket Cloud)
WORKSPACE_REPO=$(git remote get-url origin | sed -E 's|.*bitbucket.org[:/]([^.]+)(\.git)?|\1|')
echo "Open: https://bitbucket.org/$WORKSPACE_REPO/pull-requests/new?source=$BRANCH_NAME&dest=$BASE_BRANCH"
```

Announce the URL to the user. Cannot auto-create the PR without the CLI or the Bitbucket API (which requires auth setup). If the user has scripted the API, delegate via the **git** skill.

### No forge CLI available (`$FORGE=unknown` or tool missing)

Push the branch. Produce a shareable reference for manual review. **Let push errors surface** - auth failures, hook rejections, and permission errors are fixable; silencing them wastes time:

```bash
# Push will fail loudly on auth/hook/permission issues - that's correct.
# Only fall through to bare-git path if there is genuinely no remote.
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin "$BRANCH_NAME"   # surface the real error if it fails
  REMOTE_URL=$(git remote get-url origin | sed 's|\.git$||')
  echo "Branch pushed to: $REMOTE_URL (branch: $BRANCH_NAME)"
  echo "Review via the forge's web UI - skill doesn't know the PR URL pattern for self-hosted $FORGE."
else
  echo "No remote configured. Fall through to the Bare git (\$FORGE=bare) path below."
fi
```

Tell the user what self-hosted forge this is so the skill can route correctly next time. Once identified, `$FORGE` can be set manually.

### Bare git (`$FORGE=bare`, no remote at all)

No push, no PR. Two share options:

```bash
# Option A: format-patch - email-friendly, works with `git am` to apply
mkdir -p /tmp/dev-cycle-patches
git format-patch "$BASE_BRANCH..HEAD" -o "/tmp/dev-cycle-patches/$BRANCH_NAME"
echo "Patches in /tmp/dev-cycle-patches/$BRANCH_NAME - share via email/chat. Reviewer applies with: git am <files>"

# Option B: bundle - portable single-file format, preserves history
git bundle create "/tmp/$BRANCH_NAME.bundle" "$BASE_BRANCH..HEAD"
echo "Bundle: /tmp/$BRANCH_NAME.bundle - share with reviewer. They apply with: git pull /path/to/bundle $BRANCH_NAME"
```

CI and merge are entirely manual. Skip B6 (no CI to watch unless locally configured). Merge happens via Step B7 bare-git path.

### PR title conventions

Match the repo's existing style. Common patterns:

- Conventional commits: `feat(auth): add OAuth login`
- Brief imperative: `Add OAuth login`
- Issue-prefixed: `[#123] Add OAuth login`

### Strip AI attribution

Per the global rule: no `Co-Authored-By`, no "Generated with Claude Code", no robot emoji, no AI markers anywhere. Commit-helper templates inject these - strip before commit/PR/MR.

If you notice the trailer in the final preview, delete it before confirming. Merged PRs preserve trailers forever.

---

## Step B6 details: Watch CI

Dispatch on `$FORGE`. If no CI is configured (no workflow files, no `.gitlab-ci.yml`, etc.), skip this step and note it to the user.

### GitHub (`$FORGE=github`)

```bash
# Blocks until all checks complete, exits non-zero if any fail
gh pr checks --watch --fail-fast

# After it returns, confirm no non-SUCCESS conclusions remain
gh pr view --json statusCheckRollup \
  --jq '.statusCheckRollup[] | select(.conclusion != "SUCCESS" and .conclusion != null)'
```

`gh pr checks` exit codes: `0` = all green, `1` = at least one failure, `8` = some checks still pending. Treat anything non-zero as "not ready to merge." Never infer success from "the command returned" alone - iterate the `statusCheckRollup` array.

### GitLab (`$FORGE=gitlab`)

```bash
# Live pipeline view (blocking, prints updates as jobs progress)
glab ci status --live

# Programmatic status - inspect the pipeline state of the MR
glab mr view --output json | jq '.pipeline | {status: .status, web_url: .web_url}'
```

`glab ci status --live` does not emit JSON. For scripted checks, poll `glab mr view` until `.pipeline.status` reaches `success` / `failed` / `canceled`. Treat anything other than `success` as not ready to merge.

### Forgejo / Gitea / Codeberg (`$FORGE=forgejo`)

```bash
# Check status of a PR by number (from the create-PR output)
tea pulls status "$PR_NUMBER"

# Or list runs for the branch (Actions-enabled instances)
tea actions list --repo "$(git remote get-url origin | sed -E 's|.*[:/]([^/]+/[^/]+)\.git$|\1|')"
```

Forgejo/Gitea Actions API is newer and less uniform than GitHub's. If `tea actions` is unavailable on the instance's version, fall through to web-UI confirmation.

### Bitbucket (`$FORGE=bitbucket`)

No official CLI. Options:
- Watch in the web UI (Pull Request view shows Pipeline status)
- Poll the REST API if scripted: `curl -u "$USER:$APP_PASSWORD" "https://api.bitbucket.org/2.0/repositories/$WORKSPACE_REPO/pipelines/?sort=-created_on&pagelen=5"`

Announce the Pipelines URL to the user and wait for their confirmation. Do not merge until they confirm green.

### Self-hosted / unknown (`$FORGE=unknown`)

Ask the user: "What CI is this repo wired to? (Jenkins, Drone, Woodpecker, Buildkite, Teamcity, in-repo Actions, other)". Give them the branch URL to watch. Do not assume green.

### Bare git (`$FORGE=bare`)

No CI to watch. If the user has a local CI harness (pre-push hook, cron, `act`, `nektos/act`), they ran it before this step. Otherwise, verification relies on Step B2 local runs. Announce: "No remote CI - relying on local lint/test/review output from Step B2."

### If CI fails (any forge)

1. Read the failing job's logs. Don't guess.
2. Identify root cause: flaky test, real bug, env drift, timeout, missing secret.
3. For real bugs: fix locally, push, re-watch.
4. For flakiness: confirm by rerunning identical commit. If confirmed flaky, rerun the job and note it in the PR. Do not fix a real bug by calling it "flaky".
5. For env drift (CI has different versions than local): update lockfiles or CI config.

Never merge with failing checks. Never bypass branch protection.

---

## Step B7 details: Merge

Dispatch on `$FORGE`. Three merge patterns exist everywhere:

- **Squash + merge** - most common; squashes all branch commits into one on base
- **Rebase + merge** - preserves commit history linearly
- **Merge commit** - preserves full branch history with a merge commit

To pick between them when multiple are allowed, check recent merge commits:

```bash
git log --merges --oneline "$BASE_BRANCH" | head -5
# If merges exist: project uses merge commits. If none: squash or rebase - check forge config.
```

### GitHub (`$FORGE=github`)

```bash
# Detect what the repo allows
gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed

# Pick one
gh pr merge --squash  --delete-branch   # most common
gh pr merge --rebase  --delete-branch
gh pr merge --merge   --delete-branch   # merge commit
```

### GitLab (`$FORGE=gitlab`)

```bash
# Note: --delete-branch in gh is --remove-source-branch in glab
glab mr merge --squash --remove-source-branch
glab mr merge --rebase --remove-source-branch
# GitLab's default is "merge commit" if no flag is passed
glab mr merge --remove-source-branch
```

Check project settings for allowed merge methods: `glab repo view --output json | jq '{merge_method, squash_option}'`

### Forgejo / Gitea (`$FORGE=forgejo`)

```bash
tea pulls merge "$PR_NUMBER" --style squash   # or: merge, rebase, rebase-merge, squash
```

Available styles depend on the repo's settings. If the style isn't allowed, the command errors - adjust and retry.

### Bitbucket (`$FORGE=bitbucket`)

Merge in the web UI (no official CLI). Or via REST API if scripted:

```bash
curl -X POST -u "$USER:$APP_PASSWORD" \
  "https://api.bitbucket.org/2.0/repositories/$WORKSPACE_REPO/pullrequests/$PR_ID/merge" \
  -H 'Content-Type: application/json' \
  -d '{"type":"pullrequest","close_source_branch":true,"merge_strategy":"squash"}'
```

### Self-hosted / unknown (`$FORGE=unknown`)

Use whatever merge UI/API the host provides. If none, fall through to the bare-git path.

### Bare git (`$FORGE=bare`)

No forge, no PR to merge. Integrate locally. Detect whether a remote exists before pulling/pushing:

```bash
git checkout "$BASE_BRANCH"

HAS_REMOTE=false
git remote get-url origin >/dev/null 2>&1 && HAS_REMOTE=true
$HAS_REMOTE && git pull --ff-only   # fail loud if remote exists and base diverged

# Pick one based on the repo's convention:
git merge --no-ff "$BRANCH_NAME"          # preserves branch history (merge commit)
# or
git merge --ff-only "$BRANCH_NAME"        # linear, if base hasn't moved
# or rebase first, then fast-forward:
# git checkout "$BRANCH_NAME" && git rebase "$BASE_BRANCH" && git checkout "$BASE_BRANCH" && git merge --ff-only "$BRANCH_NAME"

# Push if a remote exists (common for self-hosted bare repos over SSH)
$HAS_REMOTE && git push origin "$BASE_BRANCH"

# Safe delete only; escalate manually if unmerged
git branch -d "$BRANCH_NAME"
```

### After merge (all forges)

Sync the local base branch. **Don't blanket-silence errors** - a failed pull or a refused branch-delete is information, not noise.

```bash
git checkout "$BASE_BRANCH"

if [[ "$FORGE" != "bare" ]]; then
  git pull --ff-only   # fail loud if base diverged
fi

# Safe delete only (-d). Do NOT escalate to -D automatically - unmerged commits
# indicate either incomplete merge or wrong branch; stop and investigate.
if ! git branch -d "$BRANCH_NAME" 2>/dev/null; then
  echo "branch $BRANCH_NAME not fully merged into $BASE_BRANCH; investigate before deleting"
fi
```

---

## Step B8 details: Release

### Detection - is this repo release-capable?

**First, fetch remote tags.** Local-only `git tag -l` can miss tags that exist on the remote but haven't been pulled - false-negative release detection is the worst outcome of this step. Do this before any tag-based signal check:

```bash
# Fetch tags if a remote exists; let errors print but don't block on offline/auth failure
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --tags origin 2>&1 | grep -vE '^(From |$)' || true
fi
```

Check all signals. **Require at least 2 independent positive signals** before treating the repo as release-capable. A single stale tag on a scratch repo is not a convention. Signals below are forge-agnostic where possible; forge-specific signals only count on the matching forge.

| Signal | Applies when | Command |
|--------|--------------|---------|
| Semver tags exist | any forge | `git tag -l 'v[0-9]*' \| head -1` (after `git fetch --tags`; match `v` + digit, not arbitrary `v*`) |
| CHANGELOG exists | any forge | `[[ -f CHANGELOG.md ]] \|\| [[ -f CHANGES.md ]] \|\| [[ -f HISTORY.md ]]` |
| Release workflow file | any forge | `find .github/workflows .gitlab-ci.yml .forgejo/workflows .gitea/workflows .woodpecker.yml .drone.yml 2>/dev/null \| xargs grep -lE "(release\|publish)" 2>/dev/null \| head -1` |
| Release-automation config | any forge | `[[ -f release-please-config.json ]] \|\| [[ -f .release-please-manifest.json ]] \|\| [[ -f .releaserc ]]` |
| Published releases (forge-specific) | depends on `$FORGE` | see below |
| Published package | any forge | `jq -e '.private != true and .version' package.json 2>/dev/null` or `grep -q '^\[project\]' pyproject.toml 2>/dev/null` or a non-empty `[package]` block in `Cargo.toml` |

**Forge-specific "published releases" check**:

```bash
case "$FORGE" in
  github)  [[ -n "$(gh release list --limit 1 2>/dev/null)" ]] && echo "has releases" ;;
  gitlab)  [[ -n "$(glab release list --per-page 1 2>/dev/null)" ]] && echo "has releases" ;;
  forgejo) tea releases list 2>/dev/null | head -n 1 | grep -q . && echo "has releases" ;;
  *)       echo "forge-specific release history not checkable; rely on tags" ;;
esac
```

**Hard skips** (stop, do not release):
- `jq -e '.private == true' package.json` returns 0 - the package opted out of publication
- No tags AND no CHANGELOG AND no release workflow - this repo has never released
- `$FORGE=bare` AND no intention of local-only tags. Ask the user this exact question:
  > "This repo has no remote, so there's no platform release to cut. Do you want me to (a) create a local semver tag anyway (e.g., for local versioning or a bundle distribution), (b) skip release entirely, or (c) push the tag to a specific remote I should add first?"

**Ambiguous single-signal cases** (ask the user):
- Only one tag exists and it's >6 months old - might be abandoned, might be stable. Ask.
- CHANGELOG exists but has never had a release section populated - new repo, ask.

If neither threshold met: announce "No release convention detected (signals: N of 6) - skipping release cut. Version-bump work from Step B3 still applies."

### Release automation in PR mode

If the repo uses `release-please` in PR mode, do **not** hand-cut tags or GitHub Releases after merging the feature PR.
Treat the bot-generated release PR as the release step.

Detection signals:
- `release-please-config.json` and `.release-please-manifest.json` exist
- README or repo docs say releases happen through release-please PRs
- a branch like `release-please--branches--main` exists remotely
- an open PR titled like `chore(main): release X.Y.Z` appears right after merging a releasable commit

Workflow for release-please PR mode:
1. Merge the user-facing feature PR first.
2. Check for the newly opened release PR.
3. Review its title/body/version bump briefly instead of editing release files by hand.
4. Merge that release PR when ready.
5. Confirm the resulting tag and GitHub Release exist.

In this mode, "cut release" means "merge the release-please PR and verify the tag/release", not "create the tag manually".

### Determine bump type

From conventional commits in the merged branch:

- `feat:` or `feat!:` → minor (or major if breaking)
- `fix:` → patch
- `perf:`, `refactor:`, `docs:`, `chore:`, `test:`, `ci:` → patch (usually)
- `BREAKING CHANGE:` footer anywhere → major

If unclear, ask the user. Offer the three options with the current version shown.

### Cut the release

```bash
git checkout "$BASE_BRANCH"
git pull --ff-only  # merge commit is here now

NEW_VERSION="X.Y.Z"
# git tag -l always exits 0 - check for non-empty output instead
if git rev-parse --verify --quiet "refs/tags/v$NEW_VERSION" >/dev/null; then
  echo "tag v$NEW_VERSION already exists; stop and investigate"; exit 1
fi

# Annotated, signed if the repo requires it
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
# Or signed
git tag -s "v$NEW_VERSION" -m "Release v$NEW_VERSION"

git push origin "v$NEW_VERSION"
```

### Create the release (forge-specific)

```bash
# Extract the new version's CHANGELOG section (portable - no head -n -1).
# Prints lines between "## [NEW_VERSION]" and the next "## [" header, exclusive.
extract_changelog() {
  awk -v v="$1" '
    $0 ~ "^## \\["v"\\]" { in_section=1; next }
    in_section && /^## \[/ { exit }
    in_section { print }
  ' CHANGELOG.md
}
```

### GitHub (`$FORGE=github`)

```bash
gh release create "v$NEW_VERSION" \
  --title "v$NEW_VERSION" \
  --notes-file <(extract_changelog "$NEW_VERSION")

# Or auto-generate from commits
gh release create "v$NEW_VERSION" --generate-notes
```

### GitLab (`$FORGE=gitlab`)

```bash
glab release create "v$NEW_VERSION" \
  --name "v$NEW_VERSION" \
  --notes "$(extract_changelog "$NEW_VERSION")"
```

### Forgejo / Gitea (`$FORGE=forgejo`)

```bash
tea releases create \
  --tag "v$NEW_VERSION" \
  --title "v$NEW_VERSION" \
  --note "$(extract_changelog "$NEW_VERSION")"
```

### Bitbucket (`$FORGE=bitbucket`)

Bitbucket doesn't have GitHub-style Releases. The tag push IS the release. If you publish artifacts via Pipelines, they're already produced by the tag push. Announce the tag URL to the user.

### Bare git / unknown (`$FORGE=bare|unknown`)

The pushed tag (or locally-tagged commit) is the release. No platform-level release object exists. Release notes, if needed, live only in `CHANGELOG.md`. If artifacts need to be published (e.g., to an internal Artifactory/Nexus), delegate to the user's known pipeline.

### Watch the release workflow

Dispatch on `$FORGE`. Every forge's "watch" command has the same class of trap: default exit code may not reflect workflow failure. Always use the explicit-exit flag or parse status after the watch.

**GitHub (`$FORGE=github`)** - `gh run watch` needs an explicit run ID in non-interactive mode AND it exits `0` by default even on failure. MUST pass `--exit-status`:

```bash
LATEST_RUN=$(gh run list --limit 1 --json databaseId,name,status \
  --jq '.[0] | "\(.databaseId) \(.name) \(.status)"')
echo "About to watch: $LATEST_RUN"
RUN_ID=$(echo "$LATEST_RUN" | cut -d' ' -f1)
gh run watch "$RUN_ID" --exit-status
```

**GitLab (`$FORGE=gitlab`)**:

```bash
# Live view blocks until the pipeline finishes, but doesn't reliably exit non-zero on failure
glab ci status --live
# Verify after
glab ci status --output json | jq -e '.status == "success"'
```

**Forgejo/Gitea (`$FORGE=forgejo`)**:

```bash
# Actions support varies by instance. If available:
tea actions list --repo "$REPO" --limit 1
# Otherwise, watch in web UI
```

**Others**: announce the release URL/tag and rely on the user to confirm pipeline success. Do not assume green.

If the watch exits non-zero, the release workflow failed. The tag is already pushed - debug the workflow, do NOT re-cut the release. See the "Release workflow fails at B8" row in the recovery table below.

---

## Rollback playbook

If the release breaks production after merge:

1. **Don't panic-delete the tag.** Deleted tags leave artifacts orphaned.
2. **Revert the merge commit**:
   ```bash
   git revert -m 1 "$MERGE_SHA"
   git push origin "$BASE_BRANCH"
   ```
3. **Cut a new patch release** with the revert, don't try to replace the broken tag.
4. **File a post-mortem item** (roadmap skill) about what CI missed.

Never force-push to the base branch. Never delete a published tag.

---

## Failure modes and recovery

| Failure | Recovery |
|---------|----------|
| Tests red after Step B2 | Fix root cause, return to B2. Do not proceed. |
| CI red in Step B6 | Read logs, fix, push. Return to B6. |
| PR feedback requires refactor | Loop back to B2 (tests), B4 (review) after changes. |
| Merge conflict at B7 | Rebase onto latest base, resolve, push, return to B6 (CI rerun). |
| Tag already exists at B8 | Investigate - is this a retry of a completed release? If so, stop (already released). If a mistake, discuss with user before any destructive action. |
| Release workflow fails at B8 | Release is cut (tag exists) but artifacts didn't publish. Debug workflow; do not re-tag. |
