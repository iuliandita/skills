# Docker Target Versions

September 2026 snapshot. Verified 2026-09-25 against Docker release notes, Docker Desktop releases,
and upstream GitHub release APIs. Verify current releases before pinning.

- Docker Engine 29.8.1, Docker Desktop 4.90.0 (same version across Windows, macOS, Linux)
- Docker Compose v5.5.1 (Go SDK, Bake-delegated builds)
- BuildKit v0.33.0 (Docker Engine 29.8.x bundles 0.33.0)
- containerd 2.3.4 (2.3.x LTS, recommended for production after checking release notes)
- Podman 6.1.2 (major release; review migration notes), Buildah 1.45.0
- runc 1.5.1 (CVE-2025-31133/52565/52881 patched since 1.4.0; GHSA-xjvp-4fhw-gc47, a low-severity /dev symlink issue, fixed in 1.4.3/1.3.6)

Sources: [Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/) and
[Desktop release notes](https://docs.docker.com/desktop/release-notes/). Engine 29.8.1
was released September 15; Desktop 4.90.0 was released September 7, 2026.
