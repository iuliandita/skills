# Docker Target Versions

May 2026 snapshot. Verified 2026-05-19 against Docker release notes, Docker Desktop appcast,
and upstream GitHub release APIs. Verify current releases before pinning.

- Docker Engine 29.4.3, Docker Desktop 4.73.x (4.73.1 Windows, 4.73.0 macOS/Linux)
- Docker Compose v5.1.3 (Go SDK, Bake-delegated builds)
- BuildKit v0.30.0
- containerd 2.3.0 LTS (recommended for production after checking release notes)
- Podman 5.8.2, Buildah 1.43.1
- runc 1.4.2 (CVE-2025-31133/52565/52881 patched since 1.4.0)
