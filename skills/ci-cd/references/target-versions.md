# CI/CD Target Versions

September 2026 snapshot. Verified 2026-09-03 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (pin explicitly; verify the current `ubuntu-latest` mapping), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.3.1 current (19.3 released August 20, 2026); 19.2.5 / 19.1.7 are the latest backported patch lanes. CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v16.0.3 current, v15.0.7 current LTS; Runner v13.0.0 is an unverified prior pin; check the release and migration notes before selecting it
- **Gitea Actions**: Gitea v1.27.3, Gitea Runner was renamed from act_runner; verify the exact release before pinning (the previous v3.0.0 pin remains unconfirmed)
- **Woodpecker CI**: v3.18.0 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.3 (Sigstore), Syft v1.51.1, Trivy v0.74.0, SLSA v1.1

Security checked September 10, 2026: [CVE-2026-18252](https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-3-1-released/)
allows developer-controlled agent configuration to execute commands in a CI context.
Affected GitLab EE lanes: 18.9 through versions before 19.1.7, 19.2 before 19.2.5,
and 19.3 before 19.3.1. The patch versions above contain the fix.
