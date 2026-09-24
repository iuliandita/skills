# CI/CD Target Versions

September 2026 snapshot. Verified 2026-09-25 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (pin explicitly; verify the current `ubuntu-latest` mapping), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.4.1 current; 19.3.3 / 19.2.7 are the backported patch lanes (critical security release, September 23, 2026 - treat these as the floor). CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v16.0.5 current, v15.0.9 current LTS (both 2026-09-17); Runner v13.0.0 is an unverified prior pin; check the release and migration notes before selecting it
- **Gitea Actions**: Gitea v1.27.3, Gitea Runner (renamed from act_runner in May 2026; binary `gitea-runner`, image `gitea/runner`, no `act_runner` alias) v4.0.0 (2026-09-24, breaking changes incl. cache routing; v3.5.0 is the prior release)
- **Woodpecker CI**: v3.18.1 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.3 (Sigstore), Syft v1.52.0, Trivy v0.74.0, SLSA v1.2

Security checked September 10, 2026: [CVE-2026-18252](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-3-1-released/)
allows developer-controlled agent configuration to execute commands in a CI context.
Affected GitLab EE lanes: 18.9 through versions before 19.1.7, 19.2 before 19.2.5,
and 19.3 before 19.3.1. The [September 23 critical release](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-4-1-released/)
(19.4.1 / 19.3.3 / 19.2.7) supersedes those floors.
