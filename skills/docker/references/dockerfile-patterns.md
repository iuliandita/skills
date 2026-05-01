# Dockerfile Patterns & Templates

Production-ready templates with multi-stage builds, non-root users, health checks, and BuildKit features. Updated for Docker Engine 29.x / BuildKit 0.28.

---

## BuildKit Feature Reference

Require `# syntax=docker/dockerfile:1` at the top of the Dockerfile (or Docker Engine 23.0+ where BuildKit is default).

### Heredocs

Multi-line commands without backslash continuation:

```dockerfile
# syntax=docker/dockerfile:1
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
rm -rf /var/lib/apt/lists/*
EOF
```

Inline config files:

```dockerfile
COPY <<EOF /etc/app/config.yaml
server:
  port: 8080
  host: 0.0.0.0
logging:
  level: info
EOF
```

Heredocs work in `RUN` and `COPY`. Do NOT work in `CMD`, `ENTRYPOINT`, or `ENV`.

### Cache mounts

Persist package manager caches across builds (up to 70% faster rebuilds):

```dockerfile
# Node.js / Bun
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev
RUN --mount=type=cache,target=/root/.bun/install/cache bun install --frozen-lockfile --production

# Python (cache mount handles caching - don't use --no-cache-dir here)
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

# Go
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app ./cmd/server

# Rust
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release

# apt (Debian/Ubuntu)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl
```

### Secret mounts

Secrets available during build without baking into layers:

```dockerfile
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) && \
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc && \
    npm ci && rm -f .npmrc
```

Build command: `docker build --secret id=npm_token,src=.npm_token .`

### COPY --link

Copies files independently of previous layers (better cache reuse with out-of-order rebuilds):

```dockerfile
COPY --link --from=build /app/dist /app/dist
COPY --link --from=build /app/node_modules /app/node_modules
```

### Build checks (Buildx 0.15+)

Dry-run lint without building (bundled with Engine 28+):

```bash
docker build --check .
```

### SLSA provenance + SBOM

```bash
docker buildx build --provenance=true --sbom=true -t myapp:1.0.0 --push .
```

Attestations are stored in the registry alongside the image. Requires `--push`.

---

## Base Image Decision Matrix

| Base | Size | libc | Shell | Package mgr | Security | Best for |
|------|------|------|-------|-------------|----------|----------|
| **scratch** | 0 | none | no | no | Minimal surface | Static Go/Rust binaries |
| **Chainguard/Wolfi** | ~15MB | glibc | no* | apk (dev) | Zero-CVE, nightly rebuild, SBOM+Sigstore | PCI/compliance production |
| **Distroless** (Google) | ~20MB | glibc | no | no | Very low surface | Production runtimes |
| **Alpine** | ~8MB | musl | yes | apk | Small, fast patches | Simple apps, CI images |
| **Slim** (Debian) | ~80MB | glibc | yes | apt | Broad compat | Apps with native deps |
| **Full** (Debian/Ubuntu) | ~200MB+ | glibc | yes | apt | Large surface | Dev/debug ONLY |

\* Chainguard dev variants include shell; prod variants don't.

**Choose Chainguard** for: zero-CVE at build time, built-in SBOM + Sigstore, nightly rebuilds, glibc compat, PCI/regulatory compliance. 2000+ images available as of May 2026 recheck.

**Choose Alpine** when: you need a shell, all deps work with musl, image size is top priority.

**Choose Distroless** when: Google-maintained minimal images, standard runtimes (Node.js, Python, Java, .NET), no shell needed.

**Choose Scratch** only for: statically linked binaries (`CGO_ENABLED=0` Go, `--target x86_64-unknown-linux-musl` Rust). No DNS, no CA certs - copy them from the builder stage.

---

## Language Templates

### Node.js (npm)

```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /app
COPY --from=build --chown=1001:1001 /app/dist ./dist
COPY --from=build --chown=1001:1001 /app/node_modules ./node_modules
COPY --from=build --chown=1001:1001 /app/package.json ./
USER 1001
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://localhost:3000/health').then(r=>r.ok?process.exit(0):process.exit(1)).catch(()=>process.exit(1))"]
CMD ["dist/index.js"]
```

### Bun

```dockerfile
# syntax=docker/dockerfile:1
FROM oven/bun:1 AS build
WORKDIR /app
COPY package.json bun.lockb ./
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun install --frozen-lockfile
COPY . .
RUN NODE_ENV=production bun run build
RUN bun install --frozen-lockfile --production

FROM oven/bun:1-slim
WORKDIR /app
RUN addgroup --system --gid 1001 app && \
    adduser --system --uid 1001 --ingroup app app
COPY --from=build --chown=app:app /app/dist ./dist
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/package.json ./
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD bun -e "fetch('http://localhost:3000/health').then(r=>r.ok?process.exit(0):process.exit(1)).catch(()=>process.exit(1))"
CMD ["bun", "run", "dist/index.js"]
```

**Bun gotcha**: `NODE_ENV=production` must be set BEFORE `bun run build` because Bun's bundler inlines `process.env.*` at build time. Without it, `process.env.NODE_ENV === 'production'` evaluates to false and guarded code gets dead-code eliminated.

### Go

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /app ./cmd/server

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /app /app
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app"]
```

`CGO_ENABLED=0` for scratch/distroless. `-ldflags="-s -w"` strips debug info (~30% smaller). No `HEALTHCHECK` in scratch/distroless - there's no shell to run it. Use Compose `healthcheck:` or K8s probes instead.

### Python

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.14-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
COPY . .

FROM python:3.14-slim
RUN addgroup --system --gid 1001 app && \
    adduser --system --uid 1001 --ingroup app app
WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY --from=build --chown=app:app /app .
ENV PATH="/opt/venv/bin:$PATH"
USER 1001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000"]
```

Always use a venv in the container (Python 3.12+ externally managed). `--no-cache-dir` avoids storing wheels.

### Rust

```dockerfile
# syntax=docker/dockerfile:1
FROM rust:1.94-slim AS build
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release
COPY src ./src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release && cp target/release/myapp /usr/local/bin/

FROM gcr.io/distroless/cc-debian12
COPY --from=build /usr/local/bin/myapp /app
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Dummy `main.rs` trick: builds deps first so they're cached, then real source builds only the app.

### Static site (Nginx/Caddy)

```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM caddy:2-alpine
COPY --from=build /app/dist /srv
COPY Caddyfile /etc/caddy/Caddyfile
USER 1001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO /dev/null http://localhost:8080/health || exit 1
```

---

## .dockerignore Template

```
.git
.github
.forgejo
.gitignore
.env*
!.env.example
node_modules
dist
build
target
__pycache__
*.pyc
.pytest_cache
.mypy_cache
.ruff_cache
.venv
*.log
*.md
!README.md
LICENSE
Dockerfile*
compose*.y*ml
.dockerignore
.editorconfig
.eslintrc*
.prettierrc*
biome.json
tsconfig*.json
jest.config*
vitest.config*
.vscode
.idea
coverage
docs
tests
.claude
CLAUDE.md
AGENTS.md
```

---

## Multi-Platform Builds

```bash
# Create dedicated builder (once)
docker buildx create --name multiarch --driver docker-container --use

# Build + push for multiple architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --provenance=true \
  --sbom=true \
  --tag ghcr.io/org/app:1.0.0 \
  --push .
```

---

## Image Tagging Strategy

Standard tag matrix for published images. Each image gets the full set:

| Tag | Example | Moves on release? | Use for |
|-----|---------|-------------------|---------|
| `MAJOR.MINOR.PATCH` | `0.12.26` | No (pinned) | Production, CI, digest-level trust |
| `MAJOR.MINOR.PATCH-VARIANT` | `0.12.26-alpine` | No (pinned) | Pinned + variant |
| `MAJOR.MINOR` | `0.12` | Yes (latest patch) | Dev environments wanting bugfixes |
| `MAJOR.MINOR-VARIANT` | `0.12-alpine` | Yes (latest patch) | Dev + variant |
| `latest` | `latest` | Yes (latest release) | Default pull - dev/testing only |
| `VARIANT` | `alpine` | Yes (latest release) | Variant of latest - dev/testing only |

**Pinned tags** (`MAJOR.MINOR.PATCH[-VARIANT]`) are immutable - once pushed, never overwritten. Production and CI reference these. For maximum immutability, pin to `@sha256:` digests.

**Floating tags** (`MAJOR.MINOR`, `latest`, variant names) move on every release. A `docker pull` on a floating tag may return a different image tomorrow. Never use in production.

**CI tagging example:**

```bash
VERSION="0.12.26"
MINOR="${VERSION%.*}"
IMAGE="ghcr.io/org/app"

docker buildx build \
  --tag "$IMAGE:$VERSION" \
  --tag "$IMAGE:$MINOR" \
  --tag "$IMAGE:latest" \
  --provenance=true --sbom=true \
  --push .
```

For variant builds (alpine, distroless), use separate Dockerfile targets or `--build-arg` switches, each getting the full tag matrix.

---

## Common Gotchas

- **PID 1 / signal handling**: the first process in a container runs as PID 1 and must handle SIGTERM for graceful shutdown. Node.js, Python, and most runtimes do NOT handle signals as PID 1 by default. Solutions: (1) `CMD ["node", "dist/index.js"]` exec form (not shell form `CMD node dist/index.js`), (2) use `tini` as init (`--init` flag on `docker run`, or `init: true` in Compose), (3) `ENTRYPOINT ["tini", "--"]` in Dockerfile. Without this, `docker stop` sends SIGTERM, container ignores it, Docker waits 10s, then SIGKILL. Distroless images include a minimal init. Compose `stop_grace_period: 30s` extends the timeout but doesn't fix the root cause.
- **Bun/Vite build-time env**: they inline `process.env.*` at build time. Set `NODE_ENV=production` BEFORE `RUN bun run build`, not just in the runtime stage.
- **Alpine musl**: Node.js native addons, Python C extensions, and some Go CGO builds may fail on musl. Use slim (glibc) or Chainguard (glibc) instead.
- **`npm ci` vs `npm install`**: `ci` is reproducible (lockfile-only), `install` may modify lockfile.
- **`--omit=dev`** (npm 8+): replaces `--only=production`.
- **Distroless has no shell**: `docker exec -it ... sh` won't work. Use ephemeral debug containers or Chainguard dev variants for debugging.
- **Scratch has no CA certs**: copy `/etc/ssl/certs/ca-certificates.crt` from the build stage for HTTPS.
- **Go `CGO_ENABLED=0`**: required for scratch/distroless. With CGO enabled, you need glibc in the runtime image.
- **Multi-arch + distroless**: Google distroless images support amd64 + arm64. Chainguard Wolfi images support both too. When using `--platform` in multi-stage builds, the build stage platform and runtime stage platform are independent - `FROM --platform=$BUILDPLATFORM golang:1.26 AS build` cross-compiles on the host arch, then `FROM gcr.io/distroless/static-debian12` uses the target arch automatically.
- **pip `--no-cache-dir` vs cache mounts**: pick one approach. With `--mount=type=cache,target=/root/.cache/pip`, pip caches to the mount (fast rebuilds) - don't add `--no-cache-dir` or it defeats the mount. Without cache mounts, use `--no-cache-dir` to avoid caching in the image layer.
