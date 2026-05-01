# Forge-Specific Workflows

Patterns for GitHub, GitLab, and Forgejo - PRs/MRs, releases, branch protection, CLI usage.

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

GitLab runs in three deployment modes that share a CLI and API but differ operationally:

| Mode | Who runs it | License | CI runners |
|------|-------------|---------|-----------|
| **gitlab.com** (SaaS) | GitLab Inc. | Paid tiers (Free, Premium, Ultimate) with seat + compute limits | Shared SaaS runners, metered by "compute minutes" |
| **Self-managed CE** (FOSS) | You | MIT-licensed Community Edition | Your own runners, effectively unlimited |
| **Self-managed EE** (with license) | You | EE binary with applied license key | Your own runners, effectively unlimited |

Self-managed CE and EE use the same binary; EE activates additional features only when a
license key is applied. An unlicensed EE install behaves exactly like CE, so the usual
pattern for self-hosting is "install EE, license later if needed" to avoid a reinstall.

### `glab` against self-hosted vs `gitlab.com`

`glab` auto-detects the host from the git remote, so most of the time no host flag is needed.
When it does matter (scripts, cron jobs, repos without remotes yet), these three knobs exist:

```bash
# One-time interactive login for a self-hosted instance
glab auth login --hostname gitlab.example.com
# paste a token or go through OAuth if the instance supports it

# Environment variable - overrides auto-detection for a shell/script
export GITLAB_HOST=https://gitlab.example.com
export GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
glab mr list

# Per-invocation override via env var (most reliable)
GITLAB_HOST=https://gitlab.example.com glab mr list

# `glab api` accepts --hostname directly
glab api "projects/:id/pipelines" --hostname gitlab.example.com
```

**Config location**: `~/.config/glab-cli/config.yml` globally; `.git/glab-cli/` per-repo
overrides. Tokens live in the OS secret store (libsecret/kwallet on Linux) unless the user
opts into the config file.

**CLI provenance**: `glab` was originally `profclems/glab` (community); GitLab Inc. adopted
it in 2023 and it now lives at `gitlab.com/gitlab-org/cli`. The old `profclems/glab` repo is
archived. Scripts referencing the old install path still work but point readers to the new
location.

**Multiple instances** (e.g. `gitlab.com` + work self-hosted): `glab auth login` once per
host. `glab` picks the right token based on the repo's remote. For repos without a remote
yet, use `GITLAB_HOST` or `--host`.

**SSH-IP vs hostname mismatch**: if the SSH remote resolves to an IP and the web URL uses
a hostname, `glab mr list` can fail. Use `glab api` with URL-encoded paths (see `ci-cd/references/gitlab-ci.md`).

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

Forgejo has a Gitea-compatible REST API and a community CLI, **`forgejo-cli`** (binary `fj`),
maintained under `codeberg.org/forgejo-contrib/forgejo-cli`. `fj` is the right default for
interactive use; fall back to `curl` against the API for scripting, CI, or anything `fj`
does not cover yet (e.g. branch protection management).

### `fj` install

| Platform | Command |
|----------|---------|
| Arch / CachyOS (AUR) | `paru -S forgejo-cli` (or `cargo install forgejo-cli`) |
| Debian sid / Ubuntu 25.10+ | `sudo apt install forgejo-cli` (not in Debian stable or Ubuntu LTS as of May 2026 recheck) |
| Fedora | `sudo dnf copr enable lihaohong/forgejo-cli && sudo dnf install forgejo-cli` |
| macOS | `brew install forgejo-cli` |
| Nix | `nix profile install nixpkgs#forgejo-cli` |
| Any with Rust | `cargo install forgejo-cli` or `cargo binstall forgejo-cli` |
| Binaries | Releases tab on Codeberg (x86_64 Linux/Windows) |

Verify: `fj --version` (prefer 0.5.x or newer as of May 2026 recheck; releases before 0.4.1
have a PKCE bug that breaks `fj auth login`).

### `fj` authentication

Two flows. Pick based on whether your instance is in the default OAuth client list
(Codeberg, `forgejo.org`, Disroot, and ~12 others ship client IDs; self-hosted usually is not).

**OAuth (browser)** - default for supported public instances:

```bash
# Log in to the default host (first run prompts for host)
fj auth login

# Log in to a specific instance
fj -H codeberg.org auth login
```

**Token (self-hosted / no OAuth)** - generate at
`https://<instance>/user/settings/applications` with the scopes you actually need
(`write:repository`, `write:issue`, `write:user` covers normal dev work), then:

```bash
fj -H git.example.com auth add-key
# paste the token when prompted
```

**Config location (Linux)**: `~/.config/forgejo-cli/client_ids` for custom instance client IDs.
Credentials live in the OS secret store (libsecret/kwallet on Linux), not plaintext.

**Per-repo auto-detection**: when inside a git repo, `fj` resolves the host from the `origin`
remote. No `-H` flag needed for day-to-day operations.

**Multi-instance setups** (e.g. self-hosted Forgejo + Codeberg mirror): run `fj auth login`
once per host; `fj` picks the right credential based on the repo's remote or the `-H` override.

### `fj` PR workflow

```bash
# Create a PR from the current branch
fj pr create "feat(pipeline): add subscription scheduler" \
  --body-from-file .github/pr-body.md \
  --base main

# Autofill title and body from commits
fj pr create --autofill

# AGit flow - push directly to the upstream without forking
# (Forgejo feature; pushes to refs/for/<base> and opens the PR in one step)
fj pr create "feat(x): ..." --agit

# Shorthand: --autofill + --agit
fj pr create -aA

# Open the new-PR page in the browser instead
fj pr create --web

# View a PR (owner/repo#N, or ^N when cwd is the fork and you want the parent repo)
fj pr view forgejo-contrib/forgejo-cli#42
fj pr checkout ^16

# Status with CI check polling (blocks until all checks finish)
fj pr status --wait

# Merge (rebase + delete source branch)
fj pr merge --method rebase --delete

# Close with a message
fj pr close 42 --with-msg "superseded by #45"
```

Merge methods: `merge`, `rebase`, `rebase-merge`, `squash`, `fast-forward-only`. Match the
repo's branch protection policy - `fj` will surface the error if the method is not allowed.

### `fj` issues

```bash
fj issue create "token refresh races on concurrent logins" \
  --repo org/repo --body-from-file bug.md
fj issue create --web               # new-issue page in browser
fj issue create --template bug.md   # use a repo issue template
fj issue view 16
fj issue view 16 comments
fj issue comment 16 "reproduces on v1.2.3 with OIDC enabled"
fj issue close org/repo#16 --with-msg "fixed in #45"
fj issue search --state open --label bug
```

### `fj` releases and tags

`fj` can publish releases (listed as a supported capability in the README), but as of
v0.4.1 the wiki does not yet document the exact `fj release` subcommand flags. Run
`fj release --help` on the target version to confirm syntax before scripting.

The reliable pattern is git-side tagging + `fj` for the release object:

```bash
# Annotated tag + push (fj works alongside git, not instead of it)
git tag -a v1.2.3 -m "v1.2.3"
git push origin v1.2.3

# Publish the release for the pushed tag via fj
# Flags (title, body-from-file, prerelease, asset upload) track closely to `gh release`
# and `glab release`; verify against `fj release --help` on your installed version.
fj release --help
```

When `fj release` is not yet an option in your installed version, fall back to the REST
API section below - `POST /api/v1/repos/{owner}/{repo}/releases` is stable.

For projects that prefer one command to tag + release, `fj tag` (new in v0.4.0) manages
git tags on the Forgejo side; keep tag creation in git and the release in `fj` for a
clean separation.

### `fj` Forgejo Actions

`fj` manages Actions variables, secrets, and manual dispatch. It does not yet expose
log streaming or re-run controls - use the web UI for those.

```bash
# List recent action runs
fj actions tasks

# Manually dispatch a workflow_dispatch workflow
fj actions dispatch publish.yaml main --inputs version=1.2.3

# Variables (non-secret config)
fj actions variables list
fj actions variables create CACHE_BUCKET gs://my-bucket
fj actions variables delete CACHE_BUCKET

# Secrets (write-only; value never echoed back)
fj actions secrets list
fj actions secrets create REGISTRY_TOKEN "$REGISTRY_TOKEN"
fj actions secrets delete REGISTRY_TOKEN
```

### Falling back to the REST API

`fj` does not cover branch protection, webhooks, or org/team admin. Use `curl` against
the Gitea-compatible API:

```bash
# Protect a branch
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

# Create a PR without fj (CI contexts where installing fj is overkill)
curl -s -X POST "https://git.example.com/api/v1/repos/{owner}/{repo}/pulls" \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "feat(x): ...",
    "body": "summary + test plan",
    "head": "feat/x",
    "base": "main"
  }'
```

### Forgejo-specific gotchas

- **No `permissions:` in Actions** - silently ignored (unlike GitHub where it scopes GITHUB_TOKEN).
- **Self-signed certs** - `GIT_SSL_NO_VERIFY=true` may be needed for git operations. Set per-remote:
  `git config http.https://git.example.com/.sslVerify false`. For `fj`, ensure the CA is in
  the system trust store; `fj` uses the OS TLS stack and does not expose a skip-verify flag.
- **Runner availability** - self-hosted runners can be down. Check runner status before relying
  on CI for branch protection checks.
- **Mirror sync delay** - if Forgejo mirrors from GitHub (or vice versa), there's a sync interval.
  Don't expect immediate consistency across forges.
- **`fj` version** - `fj auth login` fails with PKCE errors on v0.4.0 and earlier. Use 0.4.1+.
- **AGit requires Forgejo 7+** - older self-hosted instances reject `refs/for/<branch>` pushes.
  Fall back to `fj pr create` without `--agit` (push a branch first).

### On Gitea, not Forgejo?

`tea` (`gitea.com/gitea/tea`) is the Gitea community CLI. It predates `fj` and still works
against Gitea 1.20+ instances. Install: `go install code.gitea.io/tea@latest`, Arch
`paru -S tea-bin`, macOS `brew install tea-cli`. Auth: `tea login add --name home --url
https://gitea.example.com --token <token>` (no OAuth flow - token only).

Rough feature parity: `tea pulls create`, `tea issues create`, `tea releases create`,
`tea repos clone`. No AGit support (Gitea does not ship it), no Actions secret/variable
CLI (`tea` predates Gitea Actions and has not caught up). If you are still on Gitea for
infrastructure reasons, `tea` covers the basics; for anything Actions-related, fall back
to the Gitea-compatible REST API directly.

**Running Forgejo?** Use `fj`, not `tea`. `fj` tracks Forgejo-specific behavior (AGit,
Forgejo Actions secrets/variables, v14 features) that `tea` does not. `tea` still works
against Forgejo because the API is Gitea-compatible, but you will miss Forgejo features
and hit rough edges where the two projects have diverged.

---

## Cross-Forge Patterns

### Multi-remote push checklist

When a project uses multiple remotes:

1. **Identify which remotes need pushes** - check the project instruction file or `git remote -v`
2. **Push to primary first** (usually `origin`)
3. **Push to secondary** (e.g., `github`) - if CI builds happen there, this triggers the build
4. **Push tags to both** - `git push origin <tag> && git push github <tag>`
5. **Create releases on the right forge** - release may only exist on one forge (e.g., GitHub for Docker images)

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
2. **Test after resolving** - run tests, lint, typecheck. Conflict resolution is error-prone.
3. **Prefer the more recent change** when both sides modified the same logic, unless the older change was a bugfix.
4. **Lock files** (package-lock.json, bun.lockb): regenerate, don't manually resolve. Delete the file, run the package manager, commit the fresh lockfile.
5. **Schema/migration files**: never resolve automatically. These may require creating a new migration that merges both changes.
