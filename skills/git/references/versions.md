---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "git"
    version: "2.56.0"
    source: "https://github.com/git/git/tags"
  - tool: "GitHub CLI (gh)"
    version: "2.102.0"
    source: "https://github.com/cli/cli/releases"
  - tool: "GitLab CLI (glab)"
    version: "1.120.0"
    source: "https://gitlab.com/gitlab-org/cli/-/releases"
  - tool: "Forgejo CLI (fj)"
    version: "0.6.0"
    source: "https://codeberg.org/forgejo-contrib/forgejo-cli/releases"
  - tool: "Forgejo"
    version: "v16.0.5"
    source: "https://forgejo.org/releases/"
  - tool: "prek"
    version: "0.5.4"
    source: "https://github.com/j178/prek/releases"
  - tool: "pre-commit"
    version: "4.6.2"
    source: "https://github.com/pre-commit/pre-commit/releases"
  - tool: "git-filter-repo"
    version: "2.47.0"
    source: "https://github.com/newren/git-filter-repo/releases"
  - tool: "gitleaks"
    version: "8.30.1"
    source: "https://github.com/gitleaks/gitleaks/releases"
  - tool: "cosign"
    version: "3.1.3"
    source: "https://github.com/sigstore/cosign/releases"
---

# Git target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages.

| Tool | Version | Source | Notes |
|---|---|---|---|
| git | 2.56.0 | <https://github.com/git/git/tags> | Current stable, 2026-09-28. Additions include `git refs` create/delete/update/rename, `fetch.followRemoteHEAD`, and `git history drop`; 2.55 added Linux fsmonitor, remote-group push, and parallel compatible hooks |
| GitHub CLI (gh) | 2.102.0 | <https://github.com/cli/cli/releases> |  |
| GitLab CLI (glab) | 1.120.0 | <https://gitlab.com/gitlab-org/cli/-/releases> |  |
| Forgejo CLI (fj) | 0.6.0 | <https://codeberg.org/forgejo-contrib/forgejo-cli/releases> | Latest Codeberg release, rechecked 2026-10-02; `fj pr merge --help` confirmed September 25. Rust-written, official community CLI. Covers PRs (incl. AGit), issues, repos, releases, tags, actions |
| Forgejo | v16.0.5 | <https://forgejo.org/releases/> | Current; v15.0.9 is the current LTS (both 2026-09-17). Critical RCE (CVE-2025-68937) patched in v13.0.2+ |
| prek | 0.5.4 | <https://github.com/j178/prek/releases> | Rust, recommended |
| pre-commit | 4.6.2 | <https://github.com/pre-commit/pre-commit/releases> | Python, largest ecosystem |
| git-filter-repo | 2.47.0 | <https://github.com/newren/git-filter-repo/releases> |  |
| gitleaks | 8.30.1 | <https://github.com/gitleaks/gitleaks/releases> | Secret scanning |
| cosign | 3.1.3 | <https://github.com/sigstore/cosign/releases> | Sigstore, for tag/release signing context |
