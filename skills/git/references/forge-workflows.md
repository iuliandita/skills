# Forge-Specific Workflows

Patterns for GitHub, GitLab, and Forgejo -- PRs/MRs, releases, branch protection, CLI usage.

Research date: March 2026.

---

## GitHub

### PR creation with `gh`

```bash
# Create PR from current branch
gh pr create --title "feat(auth): add OIDC login" --body "$(cat <<'EOF'
## Summary
- Added OIDC provider integration
- Redirect URI validated against ALLOWED_ORIGIN

## Test plan
- [ ] Login flow with Google OIDC
- [ ] Redirect URI validation rejects spoofed hosts
EOF
)"

# Create draft PR
gh pr create --draft --title "wip: refactor pipeline" --body "Early feedback welcome"

# Create PR targeting non-default branch
gh pr create --base develop --title "fix: memory leak in worker"

# List open PRs
gh pr list --state open

# Merge PR (squash)
gh pr merge <number> --squash --delete-branch
```

**`GITHUB_TOKEN` override**: if the shell has `GITHUB_TOKEN` set for a different account,
prefix with `GITHUB_TOKEN=""` to use the keyring token:

```bash
GITHUB_TOKEN="" gh pr create --title "..." --body "..."
GITHUB_TOKEN="" gh release create v1.0.0 --title "v1.0.0" --notes "..."
```

### GitHub releases

```bash
# Create release from tag (tag must exist and be pushed)
gh release create v1.2.3 --title "v1.2.3" --notes "$(cat <<'EOF'
## Changes
- feat: user search across multiple sources
- fix: auth bypass on setup endpoint
EOF
)"

# Create release with auto-generated notes (from PR titles since last tag)
gh release create v1.2.3 --generate-notes

# Upload assets to release
gh release upload v1.2.3 ./dist/app.tar.gz ./dist/sbom.json

# Create pre-release
gh release create v2.0.0-rc.1 --prerelease --title "v2.0.0-rc.1"
```

### GitHub branch protection (rulesets)

GitHub is migrating from "branch protection rules" to "repository rulesets" (GA since 2024).
Rulesets are more flexible (org-level, tag rules, bypass lists) and the recommended approach.

Key ruleset settings for production branches:
- **Require pull request**: min 1 approval, dismiss stale reviews, require review from code owners
- **Require status checks**: CI must pass (lint, test, typecheck, SAST)
- **Require signed commits**: for PCI-DSS non-repudiation
- **Require linear history**: no merge commits (rebase or squash only)
- **Block force push**: always, no exceptions on release branches
- **Restrict deletions**: prevent branch deletion
- **Bypass list**: only repo admins, and only for emergencies (document each bypass)

```bash
# View rulesets via API
gh api repos/{owner}/{repo}/rulesets

# Branch protection (legacy, still works)
gh api repos/{owner}/{repo}/branches/main/protection
```

### GitHub Actions integration

Tags trigger release workflows. Ensure:
- Tag format matches workflow trigger (`on: push: tags: ['v*']`)
- Version in `package.json`/`Chart.yaml` matches the tag
- CI checks pass on the tagged commit (not just the branch)

---

## GitLab

### MR creation with `glab`

```bash
# Create MR from current branch
glab mr create --title "feat(auth): add SAML provider" --description "$(cat <<'EOF'
## Summary
- SAML 2.0 provider with metadata auto-discovery
- Tested against Okta and Azure AD

## Test plan
- [ ] SAML login flow
- [ ] Metadata refresh
EOF
)"

# Create MR with specific reviewers and labels
glab mr create --title "fix: rate limiter race" \
  --reviewer "senior-dev" \
  --label "bug,security" \
  --milestone "v2.1"

# List open MRs
glab mr list --state opened

# Merge MR (squash)
glab mr merge <number> --squash --remove-source-branch

# Approve MR
glab mr approve <number>
```

**SSH remote gotcha**: `glab` may fail when the git remote resolves to an IP address instead
of the hostname. Use `glab api` with URL-encoded project paths:

```bash
# Instead of: glab mr list (may fail)
glab api "projects/group%2Fsubgroup%2Fproject/merge_requests?state=opened" \
  --hostname gitlab.example.com
```

### GitLab releases

```bash
# Create release from tag
glab release create v1.2.3 --name "v1.2.3" --notes "$(cat <<'EOF'
## Changes
- feat: user search across multiple sources
- fix: auth bypass on setup endpoint
EOF
)"

# Upload assets
glab release upload v1.2.3 ./dist/app.tar.gz --name "app.tar.gz"
```

### GitLab branch protection

GitLab uses "protected branches" with allowed-to-push and allowed-to-merge lists.

Key settings:
- **Allowed to merge**: Maintainers only (or specific users)
- **Allowed to push**: No one (force MR workflow)
- **Require approval**: 1+ approval before merge
- **Require CI to pass**: pipeline must succeed
- **Code owners approval**: CODEOWNERS file enforces per-path reviewers

```bash
# Protect a branch via API
glab api "projects/:id/protected_branches" -X POST \
  -f "name=main" \
  -f "push_access_level=0" \
  -f "merge_access_level=40"
```

### GitLab CI/CD integration

GitLab CI uses `rules:` (not `only:/except:`) for pipeline triggers:

```yaml
rules:
  - if: '$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/'
    when: always
```

---

## Forgejo

### PR creation (no official CLI)

Forgejo has a REST API compatible with Gitea. No official CLI, but `tea` (community) works
for basic operations.

```bash
# Create PR via API
curl -s -X POST "https://git.example.com/api/v1/repos/{owner}/{repo}/pulls" \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "feat(pipeline): add subscription scheduler",
    "body": "## Summary\n- Added cron-based subscription scheduling\n\n## Test plan\n- [ ] Scheduler fires on configured cron",
    "head": "feat/subscription-scheduler",
    "base": "main"
  }'

# List PRs
curl -s "https://git.example.com/api/v1/repos/{owner}/{repo}/pulls?state=open" \
  -H "Authorization: token ${FORGEJO_TOKEN}" | jq '.[].title'
```

### Forgejo releases

```bash
# Create release via API
curl -s -X POST "https://git.example.com/api/v1/repos/{owner}/{repo}/releases" \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "tag_name": "v1.2.3",
    "name": "v1.2.3",
    "body": "## Changes\n- feat: user search\n- fix: auth bypass",
    "draft": false,
    "prerelease": false
  }'
```

### Forgejo branch protection

Forgejo supports branch protection via web UI and API:

```bash
# Protect branch via API
curl -s -X PUT "https://git.example.com/api/v1/repos/{owner}/{repo}/branch_protections" \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "branch_name": "main",
    "enable_push": false,
    "enable_merge_whitelist": true,
    "enable_approvals_whitelist": true,
    "required_approvals": 1,
    "enable_status_check": true,
    "block_on_rejected_reviews": true
  }'
```

### Forgejo-specific gotchas

- **No `permissions:` in Actions** -- silently ignored (unlike GitHub where it scopes GITHUB_TOKEN)
- **Self-signed certs** -- `GIT_SSL_NO_VERIFY=true` may be needed for git operations. Set per-remote:
  `git config http.https://git.example.com/.sslVerify false`
- **Runner availability** -- self-hosted runners can be down. Check runner status before relying
  on CI for branch protection checks.
- **Mirror sync delay** -- if Forgejo mirrors from GitHub (or vice versa), there's a sync interval.
  Don't expect immediate consistency across forges.

---

## Cross-Forge Patterns

### Multi-remote push checklist

When a project uses multiple remotes:

1. **Identify which remotes need pushes** -- check the project instruction file or `git remote -v`
2. **Push to primary first** (usually `origin`)
3. **Push to secondary** (e.g., `github`) -- if CI builds happen there, this triggers the build
4. **Push tags to both** -- `git push origin <tag> && git push github <tag>`
5. **Create releases on the right forge** -- release may only exist on one forge (e.g., GitHub for Docker images)

### Handling different SSH keys per remote

```bash
# Push to GitHub with a specific SSH key
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_github -o IdentitiesOnly=yes" git push github main

# Or set it per-remote in git config
git config remote.github.pushurl "git@github.com:user/repo.git"
git config core.sshCommand "ssh -i ~/.ssh/id_default -o IdentitiesOnly=yes"
# Override per-push when needed
```

### Token scoping

| Operation | GitHub scope | GitLab scope |
|-----------|-------------|--------------|
| Push code | `repo` | `write_repository` |
| Create release | `repo` | `api` |
| Create PR/MR | `repo` | `api` |
| Manage branch protection | `repo` (admin) | `api` (maintainer) |
| Merge workflow-touching PRs | `repo` + **`workflow`** | `api` |
| Read packages/registry | `read:packages` | `read_registry` |
| Push packages/registry | `write:packages` | `write_registry` |

**GitHub `workflow` scope**: required to merge PRs that modify `.github/workflows/` files.
Without it, merge fails with 403. Refresh with: `gh auth refresh --hostname github.com --scopes workflow`

---

## Merge Strategies

### When to use each

| Strategy | Use when | Result |
|----------|----------|--------|
| **Squash merge** | Feature branches with messy/WIP commits | Single clean commit on target |
| **Rebase merge** | Feature branches with meaningful commit history | Linear history, each commit preserved |
| **Merge commit** | Long-lived branches, release merges | Explicit merge point, preserves topology |
| **Fast-forward only** | Rebased branches, enforcing linear history | No merge commit, cleanest history |

**Default recommendation**: squash merge for feature branches (clean history), rebase merge
when individual commits matter (e.g., each commit is a self-contained logical change that
reviewers should see separately).

**Never merge the base into a feature branch** (e.g., `git merge main` into `feat/something`).
Rebase instead. Merge commits on feature branches create confusing history and make squash
merge produce ugly messages.

### Merge conflict resolution

1. **Understand both sides** before resolving. Read the conflict markers and understand the intent of each change.
2. **Test after resolving** -- run tests, lint, typecheck. Conflict resolution is error-prone.
3. **Prefer the more recent change** when both sides modified the same logic, unless the older change was a bugfix.
4. **Lock files** (package-lock.json, bun.lockb): regenerate, don't manually resolve. Delete the file, run the package manager, commit the fresh lockfile.
5. **Schema/migration files**: never resolve automatically. These may require creating a new migration that merges both changes.
