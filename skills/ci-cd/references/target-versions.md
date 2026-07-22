# CI/CD Target Versions

July 2026 snapshot. Verified 2026-07-22 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.2.0 current (released July 16, 2026); 19.1.2 / 19.0.4 / 18.11.7 are the latest backported patch lanes. CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v16.0.1 current, v15.0.5 current LTS; Runner v12.13.1 (check `data.forgejo.org/forgejo/runner` releases before pinning)
- **Gitea Actions**: Gitea v1.27.0, act runner v2.1.0 (runner 2.x is a major upgrade; review migration notes)
- **Woodpecker CI**: v3.16.0 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.2 (Sigstore), Syft v1.49.0, Trivy v0.72.0, SLSA v1.1
