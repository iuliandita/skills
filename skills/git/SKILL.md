---
name: git
description: >
  Use when performing git operations, managing branches, creating commits, handling
  remotes, resolving conflicts, writing hooks, configuring git, or working with
  multiple forges (GitHub, GitLab, Forgejo). Also use for commit signing, credential
  management, branch protection, release workflows, PR/MR creation, version bumps,
  git security hardening, or PCI-DSS change management compliance. Use this skill
  even when the user doesn't explicitly say "git" but is clearly doing git work
  (e.g., "push this", "cut a release", "create a PR", "tag this version").
  Triggers: 'git', 'commit', 'branch', 'merge', 'rebase', 'cherry-pick', 'tag',
  'remote', 'push', 'pull', 'stash', 'bisect', 'reflog', 'worktree', 'hook',
  'signing', 'gpg', 'ssh-signing', 'credential', '.gitignore', '.gitattributes',
  'gh' (GitHub CLI), 'glab' (GitLab CLI), 'PR', 'MR', 'pull request',
  'merge request', 'release', 'changelog', 'conventional commits', 'version bump',
  'semver', 'git filter-repo', 'git-crypt', 'pre-commit', 'prek'.
source: custom
date_added: "2026-03-24"
effort: high
---

# Git: Multi-Forge Production Workflow

Perform git operations, manage branches, handle multi-remote setups, create PRs/MRs,
cut releases, and maintain audit-grade change history across GitHub, GitLab, and Forgejo.
The goal is clean, signed, traceable history that satisfies both engineering standards and
compliance requirements (PCI-DSS 4.0).

**Target versions** (March 2026):
- **git**: 2.53.x (current stable). Git 3.0 expected late 2026 (reftable default, SHA-256 default)
- **GitHub CLI (`gh`)**: 2.88.x
- **GitLab CLI (`glab`)**: 1.57.x
- **Forgejo**: v13.0.4+ (critical RCE patched in v13.0.2). v14.0 (Actions multi-connection runners)
- **prek**: 0.3.x (Rust, recommended) or **pre-commit**: 4.5.x (Python, largest ecosystem)
- **git-filter-repo**: 2.46.x
- **gitleaks**: 9.x (secret scanning)
- **cosign**: 3.x (Sigstore, for tag/release signing context)

This skill covers five domains depending on context:
- **Operations** -- commits, branches, merges, rebases, stashing, bisect, reflog, recovery
- **Remotes & forges** -- multi-remote setups, GitHub/GitLab/Forgejo differences, mirroring
- **PR/MR workflow** -- feature branches, review flow, merge strategies, release cutting
- **Security** -- commit signing, credential management, hooks, secret scanning, history scrubbing
- **Compliance** -- PCI-DSS 4.0 change management, audit trails, branch protection as controls

## When to use

- Creating commits (message style, signing, authorship)
- Managing branches (creation, cleanup, protection, naming)
- Working with remotes (push, pull, fetch, multi-remote sync)
- Creating PRs/MRs (title, description, review process, merge strategy)
- Cutting releases (tagging, changelog, GitHub/Forgejo releases)
- Resolving merge conflicts or rebasing
- Recovering from mistakes (reflog, reset, revert, cherry-pick, bisect)
- Configuring git (aliases, hooks, attributes, credentials, signing)
- Scrubbing sensitive data from history (filter-repo)
- Setting up branch protection rules or rulesets
- Multi-forge workflows (mirroring, token management, SSH keys)
- PCI-DSS change management evidence

## When NOT to use

- CI/CD pipeline design (use ci-cd) -- this skill handles git operations *within* pipelines, not pipeline architecture
- PR/MR code review (use code-review) -- this skill creates PRs, doesn't review code in them
- Full application security audit (use security-audit) -- this skill covers secrets *in git history* and git-specific security, not application-level vulnerability assessment
- Docker image tagging strategy (use docker) -- this skill handles git tags, not container tags

---

## AI Self-Check

AI tools consistently produce the same git mistakes. **Before performing any git operation,
verify against this list:**

- [ ] **Read before rewrite.** Never `Edit`/`Write` files without `Read`ing them first. Never `git commit` without checking `git status` + `git diff`.
- [ ] **No destructive ops without confirmation.** `reset --hard`, `push --force`, `branch -D`, `clean -fd`, `checkout .` -- all require explicit user approval. Propose safer alternatives first (`--force-with-lease`, `revert`, new branch).
- [ ] **Authorship correct.** Check the project's instruction file for author overrides. Many setups have a local git config that's wrong for the remote (e.g., Forgejo identity vs GitHub identity).
- [ ] **Commit message format.** Follow the project's convention (check recent `git log`). Default: conventional commits (`type(scope): description`).
- [ ] **No secrets in commits.** Check `git diff --cached` for API keys, tokens, passwords, `.env` files, private keys before committing. If found, unstage immediately.
- [ ] **No AI attribution in commits.** Never add `Co-Authored-By` lines or any mention of AI tools in commits. No exceptions unless the project explicitly requires it.
- [ ] **Instruction-file policy respected.** Follow the repo's policy for `AGENTS.md` or other instruction files. Never commit local agent state directories like `.claude/`, and never mention local-only tooling files in commit messages.
- [ ] **No tool-specific paths in commits.** `.claude/`, `.cursor/`, `.superpowers/`, `.worktrees/`, `docs/local/`, `PLAN.md`, `SECURITY-AUDIT.md` are local artifacts. Verify `.gitignore` covers them.
- [ ] **Branch target correct.** Verify you're on the right branch before committing. Verify the PR/MR targets the right base branch.
- [ ] **Remote target correct.** Multi-remote setups exist. Check which remote(s) to push to. Some projects push to multiple remotes (e.g., Forgejo + GitHub).
- [ ] **Signing configured.** If the project requires signed commits, verify signing works before committing (`git log --show-signature -1`).
- [ ] **No `--no-verify`.** Never skip pre-commit hooks unless the user explicitly asks. Hooks exist for a reason -- fix the underlying issue instead.
- [ ] **No interactive flags.** Never use `-i` (interactive) flags (`git rebase -i`, `git add -i`) in automated contexts -- they require TTY input.
- [ ] **Tags pushed separately.** `git push` doesn't push tags by default. Always `git push --tags` or `git push origin <tag>` explicitly.
- [ ] **Feature branch up to date.** Before creating a PR/MR, rebase onto the latest base branch to avoid merge conflicts.

---

## Workflow

### Step 1: Identify the forge and project context

| Signal | Forge |
|--------|-------|
| `.github/` directory, `gh` CLI | GitHub |
| `.gitlab-ci.yml`, `glab` CLI, user says "work" | GitLab |
| `.forgejo/` directory, user says "home" | Forgejo |
| Multiple remotes in `git remote -v` | Multi-forge |

Read the project's instruction file (`AGENTS.md` or equivalent) for:
- **Commit conventions** (message format, scope list, authorship overrides)
- **Branch strategy** (trunk-based, feature branches, release branches)
- **Remote setup** (which remotes exist, which to push to, SSH keys)
- **Release process** (version bump files, tag format, changelog)
- **Signing requirements** (GPG, SSH, or unsigned)
- **Content restrictions** (domains, tool names, paths that must not appear in git history)

### Step 2: Determine the operation

- **"Commit this" / "save my work"** -> Commit workflow (Step 3a)
- **"Create a PR/MR"** -> PR/MR workflow (Step 3b)
- **"Cut a release"** -> Release workflow (Step 3c)
- **"Fix this mess" / "undo" / "recover"** -> Recovery operations (Step 3d)
- **"Set up signing" / "configure git"** -> Configuration (references)
- **"Clean up history" / "scrub secrets"** -> History rewriting (references)
- **"Set up branch protection"** -> Protection rules (references)

### Step 3a: Commit workflow

1. **Check state**: `git status` (never `-uall` on large repos) + `git diff` (staged and unstaged)
2. **Stage selectively**: `git add <specific files>` -- never `git add -A` or `git add .` without reviewing what's included. Check for secrets, binaries, generated files, AI tooling artifacts.
3. **Check the diff**: `git diff --cached` -- read what you're about to commit. Look for debug code, TODO comments, accidental changes to unrelated files.
4. **Write the message**: follow the project's convention. Default format:

```
type(scope): concise description

Optional body explaining *why*, not *what*.
```

Select `type` from: `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `build`, `revert`.
Extended types (use if the project convention allows): `test`, `perf`, `security`.
**Always check the project's instruction file and recent `git log` first** -- the project may have a
different type list or naming convention. Project instructions override these defaults.

**Scopes** are strongly recommended but not blindly enforced. A scope adds context that makes
`git log --oneline` scannable: `fix(auth): token expiry` vs `fix: token expiry`. Use the
component, module, or area name. Skip the scope only when the change is truly cross-cutting
or the project doesn't use scopes.

**Breaking changes**: append `!` after the type/scope: `feat(api)!: drop v1 endpoints`.
For detailed breakage notes, add `BREAKING CHANGE:` in the commit body footer.

Message guidelines:
- Imperative mood ("add feature", not "added feature" or "adds feature")
- First line under 72 characters
- Body wrapped at 72 characters
- Explain *why* the change was made, not *what* changed (the diff shows *what*)
- Reference issue/ticket numbers where applicable
- **Casual, human-sounding tone.** Like a competent human wrote it, not an AI.
  Good: `fix(caddy): self-healing volume permissions`, `feat(auth): add OIDC login`
  Bad: "fix stuff", "wip", "update files", "enhance the robustness of the authentication module"
- **Plain ASCII only.** No em-dashes, curly quotes, ligatures, or fancy punctuation in commit messages.
- **Never mention local instruction files or AI tooling** in commit messages or bodies.
  If you're updating local-only instruction files alongside code changes, don't include them in the commit.
- **Never add `Co-Authored-By` or AI attribution** lines. No `Signed-off-by: AI`. No mentions
  of specific AI tools in the commit metadata.

5. **Commit**: with any required authorship overrides and signing flags from project config.
6. **Verify**: `git log -1 --format="%h %s%n  Author: %an <%ae>%n  Committer: %cn <%ce>"` -- check authorship is correct before pushing.

### Step 3b: PR/MR workflow

**First check**: does the project use feature branches? Read the project instruction file. Some projects
(especially solo projects) work directly on `main` by preference. The default here assumes
collaborative development with review. Adapt to the project's actual workflow.

Read `references/forge-workflows.md` for forge-specific PR/MR creation
patterns (GitHub `gh pr create`, GitLab `glab mr create`, Forgejo web UI or API).

General flow:
1. **Create feature branch**: `git checkout -b type/short-description` (e.g., `feat/user-search`, `fix/auth-bypass`). Keep branch names lowercase, hyphenated, prefixed with type.
2. **Make changes**: commit early, commit often. Each commit should be a logical unit.
3. **Rebase onto base**: `git fetch origin && git rebase origin/main` (or whatever the base branch is). Resolve conflicts. Never merge the base into the feature branch. For conflict resolution tips and merge strategy guidance, see `references/forge-workflows.md` (Merge Strategies section).
4. **Push**: `git push -u origin feat/short-description`
5. **Create PR/MR**: with a clear title (under 70 chars), body with summary + test plan.
6. **Review cycle**: address feedback, force-push rebased commits (squash fixups).
7. **Merge**: squash-merge for clean history (default), or rebase-merge if commit history is meaningful.
8. **Cleanup**: delete the remote branch after merge. `git branch -d feat/short-description` locally.

Branch naming convention:
- `feat/description` -- new features
- `fix/description` -- bug fixes
- `refactor/description` -- code restructuring
- `chore/description` -- maintenance, deps, config
- `docs/description` -- documentation only
- `ci/description` -- CI/CD changes
- `security/description` -- security fixes (consider if this should be a private advisory instead)

### Step 3c: Release workflow

Read `references/forge-workflows.md` for forge-specific release creation.

**Versioning scheme**: semver `vMAJOR.MINOR.PATCH` with optional pre-release suffixes.

| Version | When | CI behavior |
|---------|------|-------------|
| `v0.12.0-alpha.1` | Start of new minor version, iterating on new features | Tag + release (marked pre-release). Image build optional per project. |
| `v0.12.0-alpha.2` | Continued iteration, not stable yet | Same as above. |
| `v0.12.0` | Features stable, ready for production | Full release: tag + release + image build + deploy. |
| `v0.12.1` | Patch fix on stable release | Full release. |

**Alpha workflow**:
- When starting work on a new minor version, tag `vX.Y.0-alpha.1`
- Increment the alpha number (`-alpha.2`, `-alpha.3`) as you iterate
- When stable, drop the `-alpha` suffix and release `vX.Y.0`
- Alpha tags still get GitHub/Forgejo releases (marked `--prerelease`) so CI can optionally build images
- The project instruction file defines whether alpha tags trigger image builds or not

General flow:
1. **Version bump**: update all version files (check the project instruction file for the list -- every project is different).
2. **Commit**: `chore: bump version to X.Y.Z` (or `chore: bump version to X.Y.Z-alpha.N`)
3. **Tag**: `git tag -a vX.Y.Z -m "vX.Y.Z"` (annotated tags, not lightweight).
4. **Push**: push commits AND tags. `git push origin main && git push origin vX.Y.Z`. If multi-remote, push to all.
5. **Create release**: GitHub (`gh release create`), GitLab (`glab release create`), or Forgejo (API/web).
   For alpha/pre-release: `gh release create vX.Y.Z-alpha.N --prerelease --title "vX.Y.Z-alpha.N"`
6. **Verify**: check that CI/CD picked up the tag and started the release pipeline.

**Changelog generation**: conventional commits feed tools like `git-cliff`, `release-please`,
or `conventional-changelog` to auto-generate changelogs from commit history. GitHub's
`gh release create --generate-notes` also works (uses PR titles since last tag). The `!`
breaking change marker and consistent scopes make these tools significantly more useful.

### Step 3d: Recovery operations

Read `references/recovery-and-maintenance.md` for detailed recovery
procedures (reflog, bisect, rerere, filter-repo, etc.).

**Golden rule**: don't panic. Git almost never loses data. The reflog has 90 days of history.

Quick reference:
- **Undo last commit (keep changes)**: `git reset --soft HEAD~1`
- **Undo last commit (discard changes)**: `git reset --hard HEAD~1` -- **DESTRUCTIVE, confirm first**
- **Revert a pushed commit**: `git revert <sha>` (creates a new commit, safe for shared branches)
- **Find lost commits**: `git reflog` -- shows every HEAD movement for 90 days
- **Find which commit broke something**: `git bisect start && git bisect bad && git bisect good <sha>`
- **Recover deleted branch**: `git reflog`, find the SHA, `git checkout -b branch-name <sha>`
- **Scrub secrets from history**: `git filter-repo --replace-text <(echo 'SECRET==>REDACTED')` -- then force-push ALL branches and tags. Coordinate with team. See references.

---

## Multi-Forge Patterns

Many projects use multiple git remotes (e.g., Forgejo for self-hosted CI + GitHub for public releases,
or GitLab at work + GitHub for open source mirrors).

- Keep `origin` as the primary development remote and name mirrors explicitly.
- Push to multiple remotes explicitly; do not make “push everywhere” the default.
- Use separate SSH keys per forge.
- Remember that CLI auth can be overridden by environment variables, especially `GITHUB_TOKEN`.

Detailed multi-forge workflows stay in `references/forge-workflows.md`.

---

## Commit Signing
- Sign commits because unsigned authorship is trivial to spoof.
- SSH signing is the default recommendation for most teams.
- GPG still matters where long-lived key lifecycles or policy require it.
- gitsign is attractive for low-management open-source flows, but it changes the trust model.

Detailed signing setup stays in `references/security-and-signing.md`.

---

## Security
- Keep credentials out of the repo, including `.env` files, keys, and embedded connection strings.
- Use secure credential helpers, not plaintext storage.
- Use hooks for secrets, lint, and branch protection, but treat untrusted hook configs as code execution surfaces.
- If a secret hit history, scrub it and rotate it. History rewriting does not undo the exposure.
- Keep `.gitignore` and `.gitattributes` intentional; AI tooling artifacts belong out of the repo by default.

Detailed security and signing guidance stays in `references/security-and-signing.md`.

---

## PCI-DSS 4.0: Change Management Mapping

Source code management requirements that map to git practices.

| PCI-DSS Req | What it means for git | Implementation |
|-------------|----------------------|----------------|
| **6.2.2** | Annual security training for developers | Not a git control, but signed commits prove *who* was trained |
| **6.2.4** | Access control + change tracking | Branch protection, required reviewers, signed commits, audit trail |
| **6.4.1** | Separate dev/test/prod environments | Branch-per-environment or tag-based promotion |
| **6.4.2** | Changes approved, documented, tested | PR/MR with required approvals, linked CI checks, merge audit log |
| **6.5.1** | Custom code reviewed before production | PR/MR required reviews, no direct push to release branches |
| **6.5.2** | Custom code reviewed for vulnerabilities | SAST/secret-scan in PR/MR checks, pre-commit hooks |

- Branch protection, required review, signed commits, and CI evidence are the main git-side controls.
- `CODEOWNERS` and protected branches matter more than policy prose with no enforcement.

---

## AI-Age Considerations
- Common AI git failures are still destructive resets, wrong authorship, leaked local tool artifacts, generic commit messages, and unjustified force pushes.
- Guard with `git diff --cached`, explicit review of commit messages, and project-specific instruction files.
- Keep local agent artifacts in `.gitignore` proactively.

---

## Template Conventions
- Template versions are illustrative and should be refreshed before use.
- CLI examples show patterns, not immutable commands.
- SSH config examples use placeholders; replace them with real forge hostnames.

---

## Reference Files

- `references/forge-workflows.md` -- GitHub, GitLab, and Forgejo-specific patterns for PRs/MRs,
  releases, branch protection, rulesets, CLI usage, and API calls
- `references/security-and-signing.md` -- commit signing setup (SSH/GPG/gitsign), credential
  management, secret scanning, CVE reference, git security hardening
- `references/recovery-and-maintenance.md` -- reflog, bisect, rerere, filter-repo, stash,
  worktree, submodule/subtree, large repo optimization, housekeeping

## Related Skills

- **ci-cd** -- pipeline design that triggers on git events (push, PR, tag). This skill handles
  the git operations; ci-cd handles the pipeline that reacts to them.
- **security-audit** -- application-level secret scanning and vulnerability assessment. This skill
  covers secrets *in git history* and git-specific security (signing, hooks, credentials).
- **code-review** -- reviews code quality. This skill creates the PR/MR; code-review evaluates
  the code in it.
- **update-docs** -- post-session documentation sweep. May update shared instruction files with new git gotchas
  discovered during a session.

## Rules

- **No destructive git operations without explicit user confirmation.** `reset --hard`, `push --force`,
  `branch -D`, `clean -fd`, `checkout .`, `rebase` on shared branches -- all require a yes.
  Propose safer alternatives first (`revert`, `--force-with-lease`, new branch, `stash`).
- **Verify authorship before pushing.** Multi-remote setups frequently have wrong local config.
  Always check `git log -1 --format="%an <%ae>"` after committing.
- **Selective staging.** `git add <file>` by name, not `git add -A` or `git add .`. Review
  what you're staging. Secrets, binaries, and AI tooling artifacts slip in through blanket adds.
- **Never skip hooks.** `--no-verify` is a code smell. Fix the issue the hook caught.
- **Conventional commits by default.** `type(scope): description`. Follow the project's convention
  if it differs. Check recent `git log` for the established style.
- **Tags are explicit.** `git push` doesn't push tags. Always push tags separately and to all
  relevant remotes.
- **Feature branches for collaboration.** When others will review the work, use feature branches
  with PRs/MRs. Direct-to-main is acceptable for solo projects when the user explicitly prefers it.
- **Rebase workflow.** Rebase feature branches onto base, don't merge base into feature. Squash
  on merge for clean history unless the commit history is meaningful.
- **Annotated tags for releases.** `git tag -a vX.Y.Z -m "vX.Y.Z"`, not lightweight tags.
  Annotated tags carry metadata (tagger, date, message) and are what forges use for releases.
- **Force-push safety.** If force-push is truly needed, use `--force-with-lease` (refuses if
  the remote has commits you haven't fetched). Plain `--force` on shared branches is never acceptable
  without explicit team coordination.
- **PCI-DSS evidence.** In regulated environments, git history IS the audit trail. Protect it:
  signed commits, branch protection, required reviews, no history rewriting on release branches.
- **Run the AI self-check.** Every git operation gets verified against the checklist above.
