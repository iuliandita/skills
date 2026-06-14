# Docker Target Versions

June 2026 snapshot. Verified 2026-06-14 against Docker release notes, Docker Desktop appcast,
and upstream GitHub release APIs. Verify current releases before pinning.

- Docker Engine 29.5.3, Docker Desktop 4.77.0 (same version across Windows, macOS, Linux)
- Docker Compose v5.1.4 (Go SDK, Bake-delegated builds)
- BuildKit v0.30.0
- containerd 2.3.1 (2.3.x LTS, recommended for production after checking release notes)
- Podman 5.8.3, Buildah 1.44.0
- runc 1.4.3 (CVE-2025-31133/52565/52881 patched since 1.4.0; GHSA-xjvp-4fhw-gc47, a low-severity /dev symlink issue, fixed in 1.4.3/1.3.6)
