# Docker Target Versions

July 2026 snapshot. Verified 2026-07-22 against Docker release notes, Docker Desktop releases,
and upstream GitHub release APIs. Verify current releases before pinning.

- Docker Engine 29.6.2, Docker Desktop 4.83.0 (same version across Windows, macOS, Linux)
- Docker Compose v5.3.1 (Go SDK, Bake-delegated builds)
- BuildKit v0.31.2
- containerd 2.3.3 (2.3.x LTS, recommended for production after checking release notes)
- Podman 6.0.2 (major release; review migration notes), Buildah 1.44.0
- runc 1.5.1 (CVE-2025-31133/52565/52881 patched since 1.4.0; GHSA-xjvp-4fhw-gc47, a low-severity /dev symlink issue, fixed in 1.4.3/1.3.6)
