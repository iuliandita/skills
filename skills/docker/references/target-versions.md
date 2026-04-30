# Docker Target Versions

May 2026 snapshot. Verify current releases before pinning.

- Docker Engine 29.4.0, Docker Desktop 4.66.1
- Docker Compose v5.1.3 (Go SDK, Bake-delegated builds)
- BuildKit v0.29.0 (bundled with Engine 29.x)
- containerd 2.2.3 / **2.3 LTS** (recommended for production after checking release notes)
- Podman 5.8.2, Buildah 1.43.0
- runc 1.4.1 (latest; CVE-2025-31133/52565/52881 patched since 1.4.0)
