# Dockerfile & Container Slop Patterns

## Fat Images (Noise)

The #1 Dockerfile sin. Production images carrying build tools, package caches, and dev dependencies.

**Detect:**
- No multi-stage build when the app has a build step (TypeScript, Go, Rust, Java)
- `apt-get install` / `apk add` without `--no-cache` or `rm -rf /var/cache/apt/*`
- `npm install` (includes devDependencies) instead of `npm ci --omit=dev` or `bun install --production`
- `pip install` without `--no-cache-dir`
- `COPY . .` before dependency install (busts cache on every source change)
- Build tools (gcc, make, python3-dev) in the final image
- Multiple `RUN` commands that should be chained (`RUN apt update && apt install -y ...`)

**Fix:** Multi-stage build. Install deps in builder stage, copy only artifacts to slim/distroless final stage.

```dockerfile
# SLOP: everything in one stage
FROM node:22
COPY . .
RUN npm install
RUN npm run build
CMD ["node", "dist/index.js"]

# CLEAN: multi-stage Node app with an npm lockfile
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build --chown=65532:65532 /app/dist ./dist
COPY --from=build --chown=65532:65532 /app/node_modules ./node_modules
COPY --from=build --chown=65532:65532 /app/package.json ./package.json
CMD ["dist/index.js"]
```

## Layer Waste (Noise)

Each `RUN`, `COPY`, `ADD` creates a layer. Unnecessary layers bloat the image.

**Detect:**
- Separate `RUN` for each `apt-get install` package
- `COPY` followed by `RUN mv` (just `COPY` to the right path)
- `ADD` for local files (use `COPY` - `ADD` auto-extracts and fetches URLs, rarely what you want)
- `RUN cd /dir && ...` instead of `WORKDIR /dir`

**Fix:** Chain related `RUN` commands with `&&`. Use `WORKDIR` for directory changes.

## Security Smells (Lies)

**Detect:**
- Running as root (no `USER` directive, or `USER root` without switching back)
- `chmod 777` on anything
- Secrets in build args or env vars (`ARG PASSWORD`, `ENV API_KEY=...`)
- `--privileged` or `--cap-add=ALL` in compose/run commands
- Pulling from unverified registries or using `latest` tag
- `.dockerignore` missing or not excluding `.git`, `.env`, `node_modules`, `__pycache__`

**Fix:**
```dockerfile
# Add non-root user
RUN addgroup --system app && adduser --system --ingroup app app
USER app
```

For secrets: use build secrets (`--mount=type=secret`) or runtime secret injection, never bake into the image.

## Compose Bloat (Noise)

**Detect:**
- `container_name` on every service (breaks scaling, usually unnecessary)
- Restart behavior and health checks that do not match recovery needs; unhealthy status alone does not cause a Docker restart
- `network_mode: host` when port mapping would work
- `volumes` mounting the entire project directory in production (dev pattern leak)
- Hardcoded ports that should be in `.env`
- `depends_on` without `condition: service_healthy` (just ordering, no readiness)

**Fix:** Remove `container_name` unless needed for external references. Add healthchecks. Use `depends_on` with conditions.

## Stale Patterns (Lies)

**Detect:**
- Unsupported or affected base images; verify the chosen release line against the application and current advisories rather than treating example tags as current-version guidance
- `MAINTAINER` directive (deprecated - use `LABEL maintainer=`)
- Installing into a distro-managed Python environment without an appropriate virtual environment; do not add `--break-system-packages` automatically
- Incorrect ENTRYPOINT/CMD composition: an exec-form ENTRYPOINT can intentionally use CMD as overridable default arguments
- `HEALTHCHECK` using `curl` when `wget` is available (alpine) or vice versa

**Fix:** Choose supported base images and use `LABEL` for metadata. Verify the combined ENTRYPOINT and CMD invocation and signal behavior.

## Docker Compose Anti-Patterns (Noise + Lies)

### Version Field (Lies)
```yaml
# SLOP: version field is deprecated since Compose v2
version: "3.8"

# CLEAN: just remove it
services:
  app:
    ...
```

### Inline Build + Deploy Confusion (Soul)
**Detect:**
- `build:` and `image:` on the same service without clarity on which is used when
- Build args that duplicate `.env` values
- `platform: linux/amd64` on every service when the host already matches

### Network Overkill (Noise)
**Detect:**
- Custom networks for single-service stacks (the default bridge is fine)
- Repeated custom-network declarations without a needed network boundary; services join the default network only when no explicit networks are configured
- `external: true` networks whose required pre-provisioning is missing; Compose reports an error when the network is absent

```yaml
# SLOP: explicit network everyone joins anyway
networks:
  app-net:

services:
  web:
    networks: [app-net]
  db:
    networks: [app-net]

# CLEAN: default network handles it
services:
  web: ...
  db: ...
```

### Volume Anti-Patterns (Noise)
**Detect:**
- Volumes whose lifecycle does not match the data; a named volume is useful for persistent data even with one consumer
- `driver: local` on every volume (it's the default)
- Bind mounts with absolute host paths that only work on one machine

### Environment Variable Sprawl (Noise)
**Detect:**
- 20+ `environment:` entries inline instead of `env_file:`
- Duplicated env vars across services (extract to shared `.env` or `env_file`)
- Secrets committed inline or exposed through container configuration; env_file still becomes environment data, so use a supported file-based secret when that boundary is required

### Proxmox / LXC Compose Gotchas (Lies)
When running Docker inside Proxmox LXC containers:
- Verify supported nesting configuration and isolation requirements; do not enable privileged LXC or privileged Compose services by default
- `cgroup` version mismatches (Proxmox default is cgroupv2; some old images need v1)
- Diagnose mount permissions before changing storage; a bind mount has different persistence and isolation semantics from tmpfs
- GPU passthrough requires LXC config, not just compose `deploy.resources.reservations`

## Hardened Compose Baseline (reference template)

Use this as a starting point when the application supports these restrictions. Select a health command present in the image, and set resource values for the workload:

```yaml
services:
  app:
    image: myapp:1.0.0  # pinned, never :latest
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add: []          # add ONLY what's needed (e.g., CHOWN, NET_BIND_SERVICE)
    tmpfs:
      - /tmp
    user: "1000:1000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
```
