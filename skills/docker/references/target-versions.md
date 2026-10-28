# Docker Target Versions

October 2026 snapshot. Verified 2026-10-28 against Docker release notes, Docker Desktop releases,
and upstream GitHub release APIs. Verify current releases before pinning.

- Docker Engine 29.9.2 (29.8.2+ fixes CVE-2026-92543 registry TLS/HTTP fallback via malicious DNS, high), Docker Desktop 4.93.0 (same version across Windows, macOS, Linux; still bundles Engine 29.8.1)
- Docker Compose v5.6.1 (v5.6.0 added partial `jobs` support, manual triggers only)
- BuildKit v0.34.1 (0.33.1+ fixes CVE-2026-93315 through 93323 and 93326, incl. high-severity cache poisoning CVE-2026-93318)
- containerd 2.3.7 (2.3.x LTS until April 30, 2028; recommended for production after checking release notes). 2.4.2 is the newest non-LTS line; 2.3.6+/2.4.1+ fix CVE-2026-53493
- Podman 6.1.4 (6.1.3+ fixes critical CVE-2026-94603 and removes checkpoint-image support from `podman run`; 5.8.9 for the 5.x lane), Buildah 1.46.0
- runc 1.5.2 (cgroup v2 kernel-bug workaround and fixes, no new CVE; CVE-2025-31133/52565/52881 patched since 1.4.0; GHSA-xjvp-4fhw-gc47, a low-severity /dev symlink issue, fixed in 1.4.3/1.3.6)

Sources: [Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/) and
[Desktop release notes](https://docs.docker.com/desktop/release-notes/). Engine 29.8.2
was released September 30; Desktop 4.93.0 was released September 28, 2026.
