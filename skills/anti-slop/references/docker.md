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

# CLEAN: multi-stage
FROM node:22-slim AS build
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

FROM gcr.io/distroless/nodejs22-debian12
COPY --from=build /app/dist /app
CMD ["/app/index.js"]
```

## Layer Waste (Noise)

Each `RUN`, `COPY`, `ADD` creates a layer. Unnecessary layers bloat the image.

**Detect:**
- Separate `RUN` for each `apt-get install` package
- `COPY` followed by `RUN mv` (just `COPY` to the right path)
- `ADD` for local files (use `COPY` -- `ADD` auto-extracts and fetches URLs, rarely what you want)
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
- `restart: always` without health checks (restarts broken containers forever)
- `network_mode: host` when port mapping would work
- `volumes` mounting the entire project directory in production (dev pattern leak)
- Hardcoded ports that should be in `.env`
- `depends_on` without `condition: service_healthy` (just ordering, no readiness)

**Fix:** Remove `container_name` unless needed for external references. Add healthchecks. Use `depends_on` with conditions.

## Stale Patterns (Lies)

**Detect:**
- `FROM node:18` or `FROM python:3.10` when 22/3.13 are current
- `MAINTAINER` directive (deprecated -- use `LABEL maintainer=`)
- `RUN pip install` without `--break-system-packages` or a venv in newer Python images
- `ENTRYPOINT` + `CMD` confusion (both set, unclear which is the "real" command)
- `HEALTHCHECK` using `curl` when `wget` is available (alpine) or vice versa

**Fix:** Use current base image versions. Use `LABEL` for metadata. Pick one of ENTRYPOINT or CMD and be explicit.

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
- Every service explicitly joined to the same custom network (they all join by default)
- `external: true` networks that don't exist yet (fails silently until deploy)

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
- Named volumes defined but only used by one service (anonymous or bind mount is simpler)
- `driver: local` on every volume (it's the default)
- Bind mounts with absolute host paths that only work on one machine

### Environment Variable Sprawl (Noise)
**Detect:**
- 20+ `environment:` entries inline instead of `env_file:`
- Duplicated env vars across services (extract to shared `.env` or `env_file`)
- Secrets passed as plain `environment:` values instead of Docker secrets or env_file

### Proxmox / LXC Compose Gotchas (Lies)
When running Docker inside Proxmox LXC containers:
- `privileged: true` is often needed for nesting but should be on the LXC, not the compose service
- `cgroup` version mismatches (Proxmox default is cgroupv2; some old images need v1)
- `tmpfs` mounts may fail in unprivileged LXC -- use bind mounts instead
- GPU passthrough requires LXC config, not just compose `deploy.resources.reservations`

## Hardened Compose Baseline (reference template)

Every production service should start from this, then relax only what's needed:

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
