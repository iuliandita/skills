---
checked_at: "2026-10-02"
checked_by: "migration"
pins:
  - tool: "GitHub Actions runners"
    version: "ubuntu-24.04"
    source: "https://github.com/actions/runner-images"
  - tool: "GitLab"
    version: "19.4.1"
    source: "https://docs.gitlab.com/releases/patches/"
  - tool: "Forgejo"
    version: "v16.0.5"
    source: "https://forgejo.org/releases/"
  - tool: "Forgejo Runner"
    version: "v13.2.0"
    source: "https://code.forgejo.org/forgejo/runner/releases"
  - tool: "Gitea"
    version: "v28.0.0"
    source: "https://github.com/go-gitea/gitea/releases"
  - tool: "Gitea Runner"
    version: "v4.1.0"
    source: "https://gitea.com/gitea/runner/releases"
  - tool: "Woodpecker CI"
    version: "v3.18.1"
    source: "https://github.com/woodpecker-ci/woodpecker/releases"
  - tool: "cosign"
    version: "v3.1.3"
    source: "https://github.com/sigstore/cosign/releases"
  - tool: "Syft"
    version: "v1.54.0"
    source: "https://github.com/anchore/syft/releases"
  - tool: "Trivy"
    version: "v0.75.0"
    source: "https://github.com/aquasecurity/trivy/releases"
  - tool: "SLSA"
    version: "v1.2"
    source: "https://slsa.dev/spec/"
---

# CI/CD target versions

October 2026 snapshot. Verified 2026-10-02 against GitLab/Gitea/Forgejo APIs, GitHub releases, and supply-chain tool releases. Verify current releases before pinning.

| Tool | Version | Source | Notes |
|---|---|---|---|
| GitHub Actions runners | ubuntu-24.04 | <https://github.com/actions/runner-images> | Pin explicitly; `ubuntu-latest` maps to ubuntu-24.04 and `windows-latest` to Windows Server 2025 per actions/runner-images on 2026-10-02. arm64 GA, artifact v4, attestations GA |
| GitLab | 19.4.1 | <https://docs.gitlab.com/releases/patches/> | Current (19.4 released September 17, 2026); 19.3.3 / 19.2.7 are the backported patch lanes (critical security release, September 23, 2026 - treat these as the floor; no newer patch release as of 2026-10-02). CI/CD Catalog GA, CI Components with typed `spec: inputs` |
| Forgejo | v16.0.5 | <https://forgejo.org/releases/> | Current; v15.0.9 current LTS (both 2026-09-17) |
| Forgejo Runner | v13.2.0 | <https://code.forgejo.org/forgejo/runner/releases> | 2026-09-18; v13.0.0 was the 13.x major, check its migration notes when coming from 12.x |
| Gitea | v28.0.0 | <https://github.com/go-gitea/gitea/releases> | 2026-09-29; version scheme jumped from 1.27.x, breaking changes incl. Git network operations routed through an internal proxy with new egress settings and `RUN_RETENTION_DAYS` deleting old action runs, plus security fixes; v1.27.3 is the prior release |
| Gitea Runner | v4.1.0 | <https://gitea.com/gitea/runner/releases> | 2026-10-01, adds a Kubernetes job backend; v4.0.0 of 2026-09-24 carried the breaking changes incl. cache routing. Renamed from act_runner in May 2026; binary `gitea-runner`, image `gitea/runner`, no `act_runner` alias |
| Woodpecker CI | v3.18.1 | <https://github.com/woodpecker-ci/woodpecker/releases> | Container-native, Gitea/Forgejo/GitHub/GitLab-compatible |
| cosign | v3.1.3 | <https://github.com/sigstore/cosign/releases> | Sigstore |
| Syft | v1.54.0 | <https://github.com/anchore/syft/releases> |  |
| Trivy | v0.75.0 | <https://github.com/aquasecurity/trivy/releases> |  |
| SLSA | v1.2 | <https://slsa.dev/spec/> | Specification version |

## Security notes (checked 2026-09-10)

[CVE-2026-18252](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-3-1-released/)
allows developer-controlled agent configuration to execute commands in a CI context.
Affected GitLab EE lanes: 18.9 through versions before 19.1.7, 19.2 before 19.2.5,
and 19.3 before 19.3.1. The [September 23 critical release](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-4-1-released/)
(19.4.1 / 19.3.3 / 19.2.7) supersedes those floors.
