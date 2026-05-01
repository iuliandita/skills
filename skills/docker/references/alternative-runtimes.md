# Alternative Container Runtimes

Podman, Buildah, Skopeo, and containerd patterns. Updated March 2026.

---

## Podman (v5.8.1)

Daemonless, rootless container engine. CLI-compatible with Docker. `alias docker=podman` works for most commands. Adopted by 40% of Fortune 500 (2025 survey).

### Key differences from Docker

| Aspect | Docker | Podman |
|--------|--------|--------|
| Architecture | Client-server (dockerd daemon) | Daemonless (fork-exec) |
| Root default | Root (rootless optional) | Rootless default |
| Socket | `/var/run/docker.sock` | `$XDG_RUNTIME_DIR/podman/podman.sock` |
| Compose | `docker compose` (v5, built-in) | `podman compose` (requires podman-compose or docker-compose) |
| Systemd | Manual service files | **Quadlet** (native systemd integration) |
| Kubernetes | Docker Desktop only | `podman kube generate/play` |
| Pods | No native pod concept | First-class pods (like K8s pods) |
| Build engine | BuildKit | Buildah (internal) |
| Image format | OCI / Docker | OCI / Docker |
| Swarm | Docker Swarm | Not supported |
| Registries | Docker Hub default | No default (must configure) |

### Installation

```bash
# Arch / CachyOS
sudo pacman -S podman podman-compose buildah skopeo

# Ubuntu / Debian
sudo apt-get install -y podman podman-compose buildah skopeo

# Fedora / RHEL
sudo dnf install -y podman podman-compose buildah skopeo
```

### Common commands

```bash
# Run a container (same as docker run)
podman run -d --name web -p 8080:80 nginx:1.27-alpine

# Build (uses Buildah internally)
podman build -t myapp:1.0.0 .

# Rootless setup (usually automatic)
podman system migrate

# Docker socket compatibility (for tools that need docker.sock)
systemctl --user enable --now podman.socket
# Socket at: /run/user/$(id -u)/podman/podman.sock

# Docker-compatible alias
alias docker=podman
```

### Quadlet (systemd integration)

Podman 5.x includes Quadlet for managing containers as systemd services. Drop `.container` files in `~/.config/containers/systemd/` (user) or `/etc/containers/systemd/` (system).

```ini
# ~/.config/containers/systemd/webapp.container
[Container]
Image=ghcr.io/org/webapp:1.0.0
PublishPort=8080:3000
Environment=NODE_ENV=production
Volume=app-data.volume:/data
Network=backend.network
ReadOnly=true
DropCapability=ALL
UserNS=keep-id

[Service]
Restart=on-failure
TimeoutStartSec=30

[Install]
WantedBy=default.target
```

```ini
# ~/.config/containers/systemd/app-data.volume
[Volume]
```

```ini
# ~/.config/containers/systemd/backend.network
[Network]
Internal=true
```

```bash
# Reload systemd and start
systemctl --user daemon-reload
systemctl --user start webapp.service
systemctl --user status webapp.service

# Quadlet management commands (Podman 5.8+)
podman quadlet list
podman quadlet install <name>
podman quadlet print <name>
podman quadlet rm <name>
```

### Podman pods

Group containers like Kubernetes pods (shared network namespace):

```bash
# Create a pod
podman pod create --name myapp -p 8080:8080

# Add containers to the pod
podman run -d --pod myapp --name web nginx:1.27-alpine
podman run -d --pod myapp --name api myapp:1.0.0

# Generate K8s manifest from pod
podman kube generate myapp > pod.yaml

# Deploy K8s manifest with Podman
podman kube play pod.yaml
```

### Podman Compose

```bash
# Using podman-compose (Python, native)
podman-compose up -d

# Using docker-compose with Podman socket
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
docker compose up -d
```

### Migration from Docker to Podman

1. Install Podman + Buildah + Skopeo
2. `alias docker=podman` for CLI compatibility
3. Enable Podman socket for tools needing `docker.sock`
4. Convert Docker Compose -> Quadlet files (for systemd-managed containers) or keep using `podman compose`
5. Test: most Dockerfiles build without changes via Buildah
6. Gotchas:
   - `docker.sock` path is different (some tools hardcode Docker's path)
   - `podman compose` features may lag behind `docker compose` (Podman Compose is a separate project)
   - BuildKit-specific features (`--mount=type=cache`, `--mount=type=secret`) work via Buildah but syntax compatibility varies
   - Network defaults differ (bridge behavior, DNS resolution)
   - `podman-docker` package provides `/usr/bin/docker` symlink for compatibility

---

## Buildah (v1.43.0)

Build OCI images without a daemon. Can build from Dockerfiles or programmatically via CLI commands.

### Dockerfile builds (same as Podman/Docker)

```bash
buildah build -t myapp:1.0.0 .
buildah push myapp:1.0.0 docker://ghcr.io/org/myapp:1.0.0
```

### Scriptable builds (no Dockerfile needed)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Create a working container from base image
ctr=$(buildah from node:22-slim)

# Run commands in the container
buildah run $ctr - npm ci --omit=dev
buildah copy $ctr ./dist /app/dist

# Configure the image
buildah config --user 1001:1001 $ctr
buildah config --port 3000 $ctr
buildah config --cmd '["node", "/app/dist/index.js"]' $ctr
buildah config --label maintainer="team@org.com" $ctr

# Commit to an image
buildah commit $ctr myapp:1.0.0

# Clean up
buildah rm $ctr
```

### When to use Buildah directly

- CI environments where you can't run a Docker daemon
- Rootless builds in restricted environments
- Scriptable image construction without Dockerfiles
- OpenShift/RHEL environments where Docker isn't available

---

## Skopeo

Inspect and copy container images between registries without pulling them locally. No daemon needed.

### Common operations

```bash
# Inspect remote image (no pull)
skopeo inspect docker://ghcr.io/org/myapp:1.0.0

# Copy between registries (no local pull/push)
skopeo copy \
  docker://ghcr.io/org/myapp:1.0.0 \
  docker://registry.internal/org/myapp:1.0.0

# Copy with digest preservation
skopeo copy --all \
  docker://ghcr.io/org/myapp:1.0.0 \
  docker://registry.internal/org/myapp:1.0.0

# Sync entire repo between registries
skopeo sync --src docker --dest docker \
  ghcr.io/org/myapp registry.internal/org/myapp

# Copy to local directory (OCI layout)
skopeo copy docker://ghcr.io/org/myapp:1.0.0 oci:./myapp-oci:1.0.0

# Delete remote image tag
skopeo delete docker://registry.internal/org/myapp:old-tag

# List tags
skopeo list-tags docker://ghcr.io/org/myapp
```

### When to use Skopeo

- Mirror images between registries (public -> private, multi-registry)
- Inspect images without pulling (check labels, layers, manifests)
- CI/CD promotion (copy tested image from staging registry to prod registry)
- Air-gapped environments (copy to OCI directory, transfer, copy to internal registry)
- Registry cleanup (delete old tags)

---

## containerd (v2.2.2)

Low-level container runtime. Kubernetes uses it directly. Docker Engine uses it under the hood.

### Key facts (May 2026)

- **containerd 2.3.0** was released in April 2026 as the first annual LTS release, supported for 2+ years
- **containerd 2.2.3** remains a supported 2.2 patch release through November 2026
- **K8s 1.36+** will require containerd 2.0+ (1.x support dropped)
- containerd 2.0 removed Docker-schemaV1 image support, CRI v1alpha2, and several deprecated APIs
- Migration from 1.6/1.7 to 2.0 is supported with built-in migration tools

### Direct usage (rare outside K8s)

```bash
# Pull image
ctr images pull ghcr.io/org/myapp:1.0.0

# Run container
ctr run --rm -t ghcr.io/org/myapp:1.0.0 my-container

# List containers
ctr containers list

# Namespace management (containerd uses namespaces, not the Docker default)
ctr namespaces list
```

Most users interact with containerd indirectly via Docker, Podman, or Kubernetes. Direct `ctr` usage is for debugging, node-level troubleshooting, or specialized automation.

### nerdctl (Docker-compatible CLI for containerd)

```bash
# Install nerdctl for Docker-compatible commands on containerd
nerdctl run -d --name web -p 8080:80 nginx:1.27-alpine
nerdctl build -t myapp:1.0.0 .
nerdctl compose up -d
```

nerdctl supports BuildKit, Compose, rootless mode, and most Docker CLI flags. Useful on K8s nodes where Docker isn't installed but you need familiar commands.

---

## Decision Matrix

| Scenario | Recommended |
|----------|-------------|
| Local development (macOS/Windows) | **Docker Desktop** (includes Docker Engine, BuildKit, Compose, Scout) |
| Local development (Linux) | **Docker Engine** or **Podman** (preference) |
| CI/CD image builds | **Docker** (BuildKit) or **Buildah** (daemonless) |
| Rootless-first environment | **Podman** |
| RHEL/OpenShift | **Podman + Buildah + Skopeo** |
| Registry mirroring / air-gap | **Skopeo** |
| Kubernetes runtime | **containerd** (bundled, don't replace) |
| systemd service management | **Podman Quadlet** |
| Scripted image construction | **Buildah** |
| Docker socket needed for tools | **Docker Engine** (or Podman with socket emulation) |
| PCI-DSS CDE | **Docker Engine** or **Podman** (both support full hardening) |
