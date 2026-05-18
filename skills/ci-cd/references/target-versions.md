# CI/CD Target Versions

May 2026 snapshot. Verified 2026-05-19 against GitLab/Gitea/Forgejo APIs, GitHub releases,
and supply-chain tool releases. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 18.11.2 current patch line; 18.10.5 for the 18.10 line. CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v15.0.2, Runner v12.10.1 (check `data.forgejo.org/forgejo/runner` releases before pinning)
- **Gitea Actions**: Gitea v1.26.1, act runner v1.0.4 (GA since Gitea 1.21, March 2024)
- **Woodpecker CI**: v3.14.1 (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.0.6 (Sigstore), Syft v1.44.0, Trivy v0.70.0, SLSA v1.1
