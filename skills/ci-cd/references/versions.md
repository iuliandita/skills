---
checked_at: "2026-11-14"
checked_by: "manual"
pins:
  - tool: "GitHub Actions runners"
    version: "ubuntu-24.04"
    source: "https://github.com/actions/runner-images"
  - tool: "GitLab"
    version: "19.5.5"
    source: "https://docs.gitlab.com/releases/patches/"
  - tool: "Forgejo"
    version: "v17.0.1"
    source: "https://forgejo.org/releases/"
  - tool: "Forgejo Runner"
    version: "v13.2.1"
    source: "https://code.forgejo.org/forgejo/runner/releases"
  - tool: "Gitea"
    version: "v28.3.0"
    source: "https://github.com/go-gitea/gitea/releases"
  - tool: "Gitea Runner"
    version: "v6.0.0"
    source: "https://gitea.com/gitea/runner/releases"
  - tool: "Woodpecker CI"
    version: "v3.20.1"
    source: "https://github.com/woodpecker-ci/woodpecker/releases"
  - tool: "cosign"
    version: "v3.1.4"
    source: "https://github.com/sigstore/cosign/releases"
  - tool: "Syft"
    version: "v1.57.1"
    source: "https://github.com/anchore/syft/releases"
  - tool: "Trivy"
    version: "v0.76.2"
    source: "https://github.com/aquasecurity/trivy/releases"
  - tool: "SLSA"
    version: "v1.2"
    source: "https://slsa.dev/spec/"
---

# CI/CD target versions

November 2026 snapshot. Every pin re-verified 2026-11-14 against its source: the GitLab release feeds, the Gitea and Forgejo release APIs, GitHub releases, and the SLSA spec. Verify current releases before pinning.

| Tool | Version | Source | Notes |
|---|---|---|---|
| GitHub Actions runners | ubuntu-24.04 | <https://github.com/actions/runner-images> | Pin explicitly; `ubuntu-latest` maps to ubuntu-24.04 and `windows-latest` to Windows Server 2025 per actions/runner-images on 2026-11-14. arm64 GA, artifact v4, attestations GA |
| GitLab | 19.5.5 | <https://docs.gitlab.com/releases/patches/> | Current (19.5 released October 15, 2026; 19.5.5 / 19.4.7 of November 12, 2026 carry no security fixes). Floor: the November 10, 2026 critical release 19.5.4 / 19.4.6 / 19.3.8. CI/CD Catalog GA, CI Components with typed `spec: inputs` |
| Forgejo | v17.0.1 | <https://forgejo.org/releases/> | Current; v16.0.7 is the previous stable lane and v15.0.11 the LTS (all three 2026-10-26, with security fixes). Upstream advised against upgrading to v17.0.0; skip it |
| Forgejo Runner | v13.2.1 | <https://code.forgejo.org/forgejo/runner/releases> | 2026-10-29; v13.0.0 was the 13.x major, check its migration notes when coming from 12.x |
| Gitea | v28.3.0 | <https://github.com/go-gitea/gitea/releases> | 2026-11-01; v28.0.0 of 2026-09-29 jumped the version scheme from 1.27.x, breaking changes incl. Git network operations routed through an internal proxy with new egress settings and `RUN_RETENTION_DAYS` deleting old action runs, plus security fixes; v1.27.3 is the prior release |
| Gitea Runner | v6.0.0 | <https://gitea.com/gitea/runner/releases> | 2026-11-11; removes `builtin:checkout` (use `actions/checkout`) and requires Gitea 1.26.2 or newer. v5.0.0 of 2026-10-08 requires Git 2.34.1+ on the runner and in job images and expands `${NAME}` in config values; v4.0.0 of 2026-09-24 changed cache routing. Renamed from act_runner in May 2026; binary `gitea-runner`, image `gitea/runner`, no `act_runner` alias |
| Woodpecker CI | v3.20.1 | <https://github.com/woodpecker-ci/woodpecker/releases> | Container-native, Gitea/Forgejo/GitHub/GitLab-compatible |
| cosign | v3.1.4 | <https://github.com/sigstore/cosign/releases> | Sigstore |
| Syft | v1.57.1 | <https://github.com/anchore/syft/releases> |  |
| Trivy | v0.76.2 | <https://github.com/aquasecurity/trivy/releases> | Minimum v0.72.0: CVE-2026-63328 affects every earlier release; v0.69.4-v0.69.6 were compromised |
| SLSA | v1.2 | <https://slsa.dev/spec/> | Specification version |

## Security notes (checked 2026-09-10)

[CVE-2026-18252](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-3-1-released/)
allows developer-controlled agent configuration to execute commands in a CI context.
Affected GitLab EE lanes: 18.9 through versions before 19.1.7, 19.2 before 19.2.5,
and 19.3 before 19.3.1. The [September 23 critical release](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-4-1-released/)
(19.4.1 / 19.3.3 / 19.2.7) superseded those floors.

Checked 2026-11-14: the [November 10 critical release](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-5-4-released/)
(19.5.4 / 19.4.6 / 19.3.8) fixes CVE-2026-105437, a heap overflow in the bundled Git that
affects every version from 16.2 up to those releases. It is the current floor.
