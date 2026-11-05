---
checked_at: "2026-10-28"
checked_by: "migration"
pins:
  - tool: "Docker Engine"
    version: "29.9.2"
    source: "https://docs.docker.com/engine/release-notes/29/"
  - tool: "Docker Desktop"
    version: "4.93.0"
    source: "https://docs.docker.com/desktop/release-notes/"
  - tool: "Docker Compose"
    version: "v5.6.1"
    source: "https://github.com/docker/compose/releases"
  - tool: "BuildKit"
    version: "v0.34.1"
    source: "https://github.com/moby/buildkit/releases"
  - tool: "containerd"
    version: "2.3.7"
    source: "https://github.com/containerd/containerd/releases"
  - tool: "Podman"
    version: "6.1.4"
    source: "https://github.com/containers/podman/releases"
  - tool: "Buildah"
    version: "1.46.0"
    source: "https://github.com/containers/buildah/releases"
  - tool: "runc"
    version: "1.5.2"
    source: "https://github.com/opencontainers/runc/releases"
---

# Docker target versions

October 2026 snapshot. Verified 2026-10-28 against Docker release notes, Docker Desktop releases, and upstream GitHub release APIs. Verify current releases before pinning.

| Tool | Version | Source | Notes |
|---|---|---|---|
| Docker Engine | 29.9.2 | <https://docs.docker.com/engine/release-notes/29/> | 29.8.2+ fixes CVE-2026-92543 registry TLS/HTTP fallback via malicious DNS, high. Engine 29.8.2 was released September 30 |
| Docker Desktop | 4.93.0 | <https://docs.docker.com/desktop/release-notes/> | Same version across Windows, macOS, Linux; still bundles Engine 29.8.1. Released September 28, 2026 |
| Docker Compose | v5.6.1 | <https://github.com/docker/compose/releases> | v5.6.0 added partial `jobs` support, manual triggers only |
| BuildKit | v0.34.1 | <https://github.com/moby/buildkit/releases> | 0.33.1+ fixes CVE-2026-93315 through 93323 and 93326, incl. high-severity cache poisoning CVE-2026-93318 |
| containerd | 2.3.7 | <https://github.com/containerd/containerd/releases> | 2.3.x LTS until April 30, 2028; recommended for production after checking release notes. 2.4.2 is the newest non-LTS line; 2.3.6+/2.4.1+ fix CVE-2026-53493 |
| Podman | 6.1.4 | <https://github.com/containers/podman/releases> | 6.1.3+ fixes critical CVE-2026-94603 and removes checkpoint-image support from `podman run`; 5.8.9 for the 5.x lane |
| Buildah | 1.46.0 | <https://github.com/containers/buildah/releases> |  |
| runc | 1.5.2 | <https://github.com/opencontainers/runc/releases> | Cgroup v2 kernel-bug workaround and fixes, no new CVE; CVE-2025-31133/52565/52881 patched since 1.4.0; GHSA-xjvp-4fhw-gc47, a low-severity /dev symlink issue, fixed in 1.4.3/1.3.6 |
