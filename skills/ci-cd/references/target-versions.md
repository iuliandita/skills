# CI/CD Target Versions

October 2026 snapshot. Verified 2026-10-02 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (pin explicitly; `ubuntu-latest` maps to ubuntu-24.04 and `windows-latest` to Windows Server 2025 per actions/runner-images on 2026-10-02), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.4.1 current (19.4 released September 17, 2026); 19.3.3 / 19.2.7 are the backported patch lanes (critical security release, September 23, 2026 - treat these as the floor; no newer patch release as of 2026-10-02). CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v16.0.5 current, v15.0.9 current LTS (both 2026-09-17); Forgejo Runner v13.2.0 (2026-09-18; v13.0.0 was the 13.x major, check its migration notes when coming from 12.x)
- **Gitea Actions**: Gitea v28.0.0 (2026-09-29; version scheme jumped from 1.27.x, breaking changes incl. Git network operations routed through an internal proxy with new egress settings and `RUN_RETENTION_DAYS` deleting old action runs, plus security fixes; v1.27.3 is the prior release), Gitea Runner (renamed from act_runner in May 2026; binary `gitea-runner`, image `gitea/runner`, no `act_runner` alias) v4.1.0 (2026-10-01, adds a Kubernetes job backend; v4.0.0 of 2026-09-24 carried the breaking changes incl. cache routing)
- **Woodpecker CI**: v3.18.1 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.3 (Sigstore), Syft v1.54.0, Trivy v0.75.0, SLSA v1.2

Security checked September 10, 2026: [CVE-2026-18252](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-3-1-released/)
allows developer-controlled agent configuration to execute commands in a CI context.
Affected GitLab EE lanes: 18.9 through versions before 19.1.7, 19.2 before 19.2.5,
and 19.3 before 19.3.1. The [September 23 critical release](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-4-1-released/)
(19.4.1 / 19.3.3 / 19.2.7) supersedes those floors.
