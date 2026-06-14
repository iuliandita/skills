# CI/CD Target Versions

June 2026 snapshot. Verified 2026-06-14 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 19.0.2 current (19.0 major released May 21, 2026; 19.0.2 / 18.11.5 / 18.10.8 patch release June 10, 2026); 18.10.x reaches EOL in June 2026, so move backported instances to 18.11.x. CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v15.0.3, Runner v12.10.1 (check `data.forgejo.org/forgejo/runner` releases before pinning)
- **Gitea Actions**: Gitea v1.26.2, act runner v1.0.4 (GA since Gitea 1.21, March 2024)
- **Woodpecker CI**: v3.15.0 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.1.1 (Sigstore), Syft v1.45.1, Trivy v0.71.0, SLSA v1.1
