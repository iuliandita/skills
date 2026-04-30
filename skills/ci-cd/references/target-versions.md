# CI/CD Target Versions

May 2026 snapshot. Verify current releases before pinning.

- **GitHub Actions**: ubuntu-24.04 runners (ubuntu-latest), arm64 GA, artifact v4, attestations GA
- **GitLab CI/CD**: GitLab 18.10.3, CI/CD Catalog GA, CI Components with typed `spec: inputs`
- **Forgejo Actions**: Forgejo v15.0, Runner v11.x (stable; check `data.forgejo.org/forgejo/runner` releases for current major tag before pinning)
- **Gitea Actions**: Gitea v1.26.0, act runner v0.2.x (GA since Gitea 1.21, March 2024)
- **Woodpecker CI**: v3.13.x (container-native, Gitea/Forgejo/GitHub/GitLab-compatible)
- **Supply chain**: cosign v3.x (Sigstore), Syft/Trivy for SBOM, SLSA v1.1
