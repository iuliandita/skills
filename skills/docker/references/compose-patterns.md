# Docker Compose Patterns & Templates

Production-ready Compose patterns for Docker Compose v5.1+ (no `version:` field). Updated March 2026.

---

## Full-Stack Template (App + Database + Cache)

```yaml
services:
  app:
    build:
      context: .
      target: production
      args:
        NODE_ENV: production
    image: myapp:${APP_VERSION:-1.0.0}
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp
    user: "1001:1001"
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      DATABASE_URL_FILE: /run/secrets/database_url
      REDIS_URL: redis://cache:6379
      NODE_ENV: production
    secrets:
      - database_url
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      start_period: 15s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
        reservations:
          memory: 256M
          cpus: "0.25"
    networks:
      - frontend
      - backend
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: postgres:17-alpine
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETUID
      - SETGID
      - FOWNER
      - DAC_OVERRIDE
    tmpfs:
      - /tmp
      - /run/postgresql
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB_FILE: /run/secrets/db_name
      POSTGRES_USER_FILE: /run/secrets/db_user
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_name
      - db_user
      - db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$(cat /run/secrets/db_user) -d $$(cat /run/secrets/db_name)"]
      interval: 10s
      timeout: 5s
      start_period: 30s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: "1.0"
    networks:
      - backend
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  cache:
    image: redis:7-alpine
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    user: "999:999"
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      start_period: 5s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 384M
          cpus: "0.5"
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:

secrets:
  database_url:
    file: ./secrets/database_url.txt
  db_name:
    file: ./secrets/db_name.txt
  db_user:
    file: ./secrets/db_user.txt
  db_password:
    file: ./secrets/db_password.txt
```

---

## Dev/Prod Separation

### Base: `compose.yaml`

Service definitions, networks, volumes. Production-ready by default.

### Dev override: `compose.override.yaml` (auto-loaded by `docker compose up`)

```yaml
services:
  app:
    build:
      target: development
    read_only: false
    security_opt: []
    cap_drop: []
    user: ""
    ports:
      - "3000:3000"
      - "9229:9229"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      NODE_ENV: development
      DEBUG: "app:*"
    command: bun run dev
    depends_on:
      db:
        condition: service_healthy

  db:
    read_only: false
    security_opt: []
    cap_drop: []
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: myapp_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
```

### Production: `compose.prod.yaml` (explicit `-f`)

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

```yaml
services:
  app:
    restart: always
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 1G
          cpus: "2.0"
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "5"
```

---

## Docker Compose Watch (Hot Reload)

Compose v5 replacement for manual bind mounts during development:

```yaml
services:
  app:
    build:
      context: .
      target: development
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
        - action: rebuild
          path: package.json
        - action: sync+restart
          path: ./config
          target: /app/config
```

```bash
docker compose watch
```

Actions:
- `sync` - copies changed files without restart (hot-reload runtimes)
- `rebuild` - full image rebuild + container recreation
- `sync+restart` - copies files and restarts the container process

---

## AI/ML Stack Template

```yaml
services:
  agent:
    build: .
    environment:
      - MODEL_ENDPOINT=http://model-runner:8080/v1
      - OPENAI_BASE_URL=http://model-runner:8080/v1
    # Model Runner provider services don't expose healthcheck endpoints;
    # bare depends_on is acceptable here (no service_healthy possible)
    depends_on:
      - model-runner

  model-runner:
    provider:
      type: model
      options:
        model: ai/llama3.2:3B-Q8_0

  # GPU inference (vLLM)
  inference:
    image: vllm/vllm-openai:v0.18.0  # pin to specific version
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    shm_size: '16gb'
    command: >
      --model /models/my-model
      --max-model-len 4096
      --gpu-memory-utilization 0.9
    volumes:
      - ./models:/models:ro
    ports:
      - "8000:8000"
```

---

## Networking Patterns

### Single stack (default bridge)

```yaml
services:
  web:
    ports: ["8080:8080"]
  api: {}
  db: {}
# All join default bridge automatically. No networks: block needed.
```

### Multi-tier isolation

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true    # no internet access

services:
  proxy:
    networks: [frontend]
  app:
    networks: [frontend, backend]
  db:
    networks: [backend]
```

### Cross-stack communication

```yaml
# Stack A
networks:
  shared:
    name: shared-net

# Stack B
networks:
  shared:
    external: true
    name: shared-net
```

---

## Health Check Patterns

### HTTP endpoint

```yaml
healthcheck:
  test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
  interval: 30s
  timeout: 5s
  start_period: 15s
  retries: 3
```

Use `wget --spider` over `curl -f` in Alpine images (wget is built-in).

### Databases

```yaml
# PostgreSQL
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]

# MySQL / MariaDB
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]

# Redis
healthcheck:
  test: ["CMD", "redis-cli", "ping"]

# MongoDB
healthcheck:
  test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
```

### TCP port check (generic)

```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z localhost 8080 || exit 1"]
```

---

## Resource Limits Reference

```yaml
deploy:
  resources:
    limits:
      memory: 512M        # hard limit (OOM killed if exceeded)
      cpus: "1.0"         # throttled if exceeded
    reservations:
      memory: 256M        # guaranteed minimum
      cpus: "0.25"        # guaranteed minimum
```

**Note**: `deploy.resources` is supported in Docker Compose v2+ (standalone mode). The legacy Python `docker-compose` v1 silently ignores `deploy:` entirely - resource limits won't apply. Verify with `docker compose version` (not `docker-compose --version`).

Rough sizing guide:

| Service type | Memory limit | CPU limit |
|-------------|-------------|-----------|
| Static site / reverse proxy | 128M | 0.25 |
| Node.js / Bun API | 256M-512M | 0.5-1.0 |
| Python API | 256M-512M | 0.5-1.0 |
| PostgreSQL (small) | 512M-1G | 0.5-1.0 |
| Redis (cache) | 256M-384M | 0.25-0.5 |
| AI model inference | 4G-32G+ | 2-8+ GPU |

---

## Logging Configuration

### JSON file with rotation (default, recommended)

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
    tag: "{{.Name}}"
```

Without `max-size`, Docker logs grow unbounded and fill disks.

### Forward to syslog

```yaml
logging:
  driver: syslog
  options:
    syslog-address: "udp://logserver:514"
    tag: "{{.Name}}"
```

---

## Common Gotchas

### `version:` field
The old file format versions (2.x/3.x) were unified into the versionless Compose Specification in 2020. The `version` field is ignored and triggers deprecation warnings in Compose v5. Delete it.

### `restart: always` vs `unless-stopped`
- `always`: restarts on daemon restart, even after `docker compose stop`
- `unless-stopped`: respects manual stops. Usually what you want.

### `container_name`
Prevents `docker compose up --scale`. Only use when external systems reference the container by name (reverse proxy hardcoded upstream, etc.).

### Environment variable precedence
1. Compose file `environment:` (highest)
2. Shell environment variables
3. `.env` file (in project directory)
4. Dockerfile `ENV`

### Secrets in Swarm vs standalone
`secrets:` with `file:` works without Swarm mode. Compose mounts the file as a tmpfs volume at `/run/secrets/<name>`. `external: true` requires Swarm or a secrets manager integration.

### Build + image on same service
Both `build:` and `image:` on the same service is intentional: Compose builds the image and tags it with the `image:` name. Useful for CI (build and tag in one step). But confusing if unintentional.

### LXC / Proxmox gotchas
- Docker in unprivileged LXC: needs `nesting=1` and `keyctl=1` features on the LXC
- `tmpfs` mounts may fail in unprivileged LXC - use bind mounts instead
- cgroup v2 required (Proxmox 7+ default); some old images need cgroup v1
- GPU passthrough: configure in LXC `.conf` (`lxc.cgroup2.devices.allow`), not just Compose

### PostgreSQL with read_only
PostgreSQL needs writable dirs for the socket and temp files. Add tmpfs mounts:
```yaml
tmpfs:
  - /tmp
  - /run/postgresql
```
And add capabilities: `CHOWN`, `SETUID`, `SETGID`, `FOWNER`, `DAC_OVERRIDE`.
