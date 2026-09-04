# CI/CD Target Versions

September 2026 snapshot. Verified 2026-09-03 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.3.1 current (19.3 released August 20, 2026); 19.2.5 / 19.1.7 are the latest backported patch lanes. CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v16.0.3 current, v15.0.7 current LTS; Runner v13.0.0 is a breaking security and predictability upgrade
- **Gitea Actions**: Gitea v1.27.3, Gitea Runner v3.0.0 (renamed from act_runner; review major-version migration notes)
- **Woodpecker CI**: v3.18.0 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.3 (Sigstore), Syft v1.51.1, Trivy v0.74.0, SLSA v1.1
