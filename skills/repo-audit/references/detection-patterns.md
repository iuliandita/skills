# Exhaustive Domain Detection Patterns

File-pattern matching table for determining which domain-specific skills to run.
Each match proposes a candidate lane; confirm relevance to the requested scope.

## Detection Method

Run `references/detect.sh` from repo root; it uses `git ls-files` output and scoped manifest reads. A skill activates if at least one
pattern matches. Confirm ambiguous matches before dispatch, especially workspace-root
dependencies that may belong to an unrelated service.

## Pattern Table

| Skill | File patterns | Dependency patterns (check manifests) |
|-------|--------------|--------------------------------------|
| testing | `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`, `pytest.ini`, `conftest.py`, `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `.nycrc*`, `cypress.config.*`, `cypress/` | - |
| shell-scripting | `*.sh`, `*.bash`, `*.zsh`, `Makefile`, `justfile`, `.envrc`, `scripts/` | Shebang detection (`#!/bin/bash` in extensionless files) is not implemented in the script - file-extension and directory patterns cover the common cases |
| databases | `*.sql`, `migrations/`, `*.prisma`, `schema.prisma`, `knexfile.*`, `alembic/`, `alembic.ini`, `flyway/`, `drizzle.config.*`, `mongod.conf`, `my.cnf`, `pg_hba.conf`, `pgbouncer.ini` | JS: `sequelize`, `typeorm`, `prisma`, `@prisma/client`, `knex`, `drizzle-orm`, `mongoose`, `mongodb`, `pg`, `mysql2`, `ioredis`, `redis`. Python: `sqlalchemy`, `sqlmodel`, `psycopg`, `psycopg2`, `psycopg2-binary`, `asyncpg`, `pymongo`, `motor`, `pymysql`, `mysqlclient`, `peewee`, `tortoise-orm`, `redis`. Go: `github.com/jackc/pgx`, `github.com/lib/pq`, `gorm.io/gorm`, `github.com/jmoiron/sqlx`, `go.mongodb.org/mongo-driver`, `github.com/redis/go-redis`, `github.com/go-sql-driver/mysql`, `entgo.io/ent`. Rust: `diesel`, `sqlx`, `sea-orm`, `tokio-postgres`, `redis`. Ruby: `activerecord`, `pg`, `sequel`, `mongoid`, `redis`. PHP: `doctrine/orm`, `doctrine/dbal`, `illuminate/database`, `predis/predis` |
| backend-api | `openapi.*`, `swagger.*` | JS: `express`, `@nestjs/core`, `hono`, `@hono/node-server`, `elysia`, `fastify`, `koa`. Python: `fastapi`, `flask`, `django`, `starlette`, `litestar`, `aiohttp`. Go: `github.com/gin-gonic/gin`, `github.com/labstack/echo`, `github.com/gofiber/fiber`, `github.com/go-chi/chi`, `github.com/gorilla/mux`, `google.golang.org/grpc`. Rust: `actix-web`, `axum`, `rocket`, `warp`, `tonic`. Ruby: `rails`, `sinatra`, `grape`, `hanami`. PHP: `laravel/framework`, `symfony/http-kernel`, `slim/slim` |
| frontend-design | `astro.config.*`, `svelte.config.*`, `next.config.*`, `vite.config.*`, `tailwind.config.*`, `src/app/`, `src/pages/`, `src/routes/`, `app/`, `pages/`, `components/`, `*.css`, `*.scss`, `*.sass`, `*.tsx`, `*.jsx`, `*.svelte`, `*.astro`, `*.vue` | `astro`, `@sveltejs/kit`, `svelte`, `next`, `react`, `vue`, `vite`, `tailwindcss`, `@vitejs/plugin-react`, `@astrojs/*` |
| i18n-localization | `locales/`, `i18n/`, `*.po`, `*.pot`, `*.xliff`, `*.xlf`, `messages.*.json`, `messages.*.yaml` | `react-i18next`, `vue-i18n`, `next-intl`, `@formatjs/intl`, `i18next` |
| llm-app-development | - | JS: `@anthropic-ai/sdk`, `openai`, `langchain`, `@langchain/*`, `ollama`, `chromadb`. Python: `anthropic`, `openai`, `langchain`, `langchain-*`, `llama-index`, `llama-index-*`, `transformers`, `torch`, `tensorflow`, `ollama`, `chromadb`, `pinecone-client`, `weaviate-client`, `qdrant-client`. Go: `github.com/anthropics/anthropic-sdk-go`, `github.com/openai/openai-go`, `github.com/sashabaranov/go-openai`. Rust: `async-openai`. Ruby: `ruby-openai`. PHP: `openai-php/client` |
| mcp | `.mcp.json`, `mcp.json` | JS: `@modelcontextprotocol/sdk`, `@modelcontextprotocol/server`, `@modelcontextprotocol/client`, `@modelcontextprotocol/core`. Python: `mcp`, `fastmcp`. Go: `github.com/modelcontextprotocol/go-sdk`, `github.com/mark3labs/mcp-go`. Rust: `rmcp`. A `keywords` entry or description mentioning `mcp` is not a dependency |
| message-queues | `kafka.*`, `rabbitmq.*`, `nats.*`, `sqs.*`, `queues/`, `consumers/`, `producers/`, `dead-letter.*`, `dlq/` | JS: `kafkajs`, `amqplib`, `bullmq`, `nats`, `@aws-sdk/client-sqs`. Python: `celery`, `kafka-python`, `confluent-kafka`, `aiokafka`, `pika`, `nats-py`. Go: `github.com/segmentio/kafka-go`, `github.com/IBM/sarama`, `github.com/rabbitmq/amqp091-go`, `github.com/nats-io/nats.go`. Rust: `rdkafka`, `lapin`, `async-nats`. Ruby: `bunny`, `ruby-kafka`. PHP: `php-amqplib/php-amqplib` |
| performance-debugging | `benchmarks/`, `profiling/`, `flamegraph.*`, `*.cpuprofile`, `*.heapprofile`, `*.pprof`, `k6.*.js`, `artillery.yml`, `locust.py`, `performance-budget.json` | Exact package names: `benchmark`, `autocannon`, `clinic`, `0x`, `k6`, `artillery`, `locust` (so `0xproject` or `pytest-benchmark` does not match) |
| docker | `Dockerfile*`, `docker-compose.*`, `compose.*`, `.dockerignore`, `Containerfile*` | - |
| kubernetes | `Chart.yaml`, `helmfile.yaml`, `kustomization.yaml`, `kustomization.yml` | Also: any `.yaml`/`.yml` with both `apiVersion:` and `kind:` (excluding CI and compose files) |
| terraform | `*.tf`, `*.tfvars`, `terragrunt.hcl`, `.terraform-version`, `.terraform.lock.hcl` | - |
| ansible | `ansible.cfg`, `galaxy.yml`, `galaxy.yaml`, `roles/*/tasks/main.yml` | Also: `playbooks/*.yml` containing `hosts:`, or `requirements.yml` containing `roles:` or `collections:` |
| ci-cd | `.github/workflows/*.yml`, `.github/workflows/*.yaml`, `.gitlab-ci.yml`, `.forgejo/workflows/`, `Jenkinsfile`, `.circleci/config.yml` | - |
| networking | `nginx.conf`, `Caddyfile`, `haproxy.cfg`, `traefik.yml`, `traefik.yaml`, `traefik.toml`, `*.zone`, `named.conf`, `dnsmasq.conf`, `wg*.conf`, `nftables.conf` | - |
| observability | `prometheus.yml`, `prometheus.yaml`, `*.rules.yml`, `*.rules.yaml`, `alertmanager.yml`, `alertmanager.yaml`, `otel-collector*.yaml`, `otelcol*.yaml`, `loki*.yaml`, `tempo*.yaml`, `grafana/provisioning/`, `grafana/dashboards/` | - |
| arch-linux | `PKGBUILD`, `*.install`, `mkinitcpio.conf*`, `archinstall.json`, `etc/pacman.d/`, `etc/pacman.conf` | - |
| debian-ubuntu | `debian/control`, `debian/changelog`, `debian/rules`, `debian/copyright`, `*.dsc`, `snapcraft.yaml`, `snap/snapcraft.yaml` | - |
| rhel-fedora | `*.spec`, `.copr/`, `dracut.conf*`, `selinux/*.te`, `comps.xml*`, `dnf/modules.d/` | - |
| nixos | `flake.nix`, `flake.lock`, `*.nix`, `configuration.nix`, `home.nix`, `default.nix`, `shell.nix` | - |
| opnsense-pfsense | `pf.conf`, `opnsense/`, `pfsense/`, `configctl*`, `pf.anchors/` | - |
| virtualization | `Vagrantfile`, `*.pkr.hcl`, `packer*.json`, `cloud-init*`, `user-data`, `meta-data`, `libvirt/*.xml`, `proxmox-*.json` | - |

Manifests to check for dependency patterns: `package.json`, `requirements.txt`,
`pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `composer.json`.

Dependency names are matched exactly, not as substrings, after per-format extraction:
`package.json` and `composer.json` keys, `requirements.txt` requirement names,
`pyproject.toml` and `Cargo.toml` keys under dependency tables plus requirement strings in
dependency arrays, `go.mod` require paths without a `/vN` suffix, and `Gemfile` gems.
Python and Cargo names compare with `-`, `_` and `.` as equal. Manifests under `.github/`,
`vendor/`, `node_modules/` and `third_party/` are tool or vendored dependencies and are
skipped. When nothing matches, the script prints nothing and exits 0: no candidates.

## Detection Script

Run the installed skill's `references/detect.sh` from the repository root, with an
optional scope path as its first argument. It prints candidate skill names, one per line.
The executable is the single source of detection logic; do not maintain a second copy.
The file inventory assumes ordinary filenames without embedded newlines or Git quoting;
use a NUL-delimited inventory for unusual paths and report that coverage limitation.

Queue and profiling file signals are case-insensitive and bounded to path components or
specific profile extensions. A user-profile page, billing subscription, or arbitrary
substring is not evidence for either new lane. Dependency matches remain candidates;
confirm actual scoped use before dispatch.

## Edge Cases

- **Monorepos**: pass the scope path as `$1` to filter detection to that subtree.
  The script uses `git ls-files -- "$scope"` when an argument is provided.
  Note: repo-root manifests (e.g., a workspace-level `package.json`) are always
  checked by default even in scoped mode. Run the same scope again with
  `REPO_AUDIT_ROOT_MANIFESTS=0` to get scoped-only matches; the set difference is
  root-manifest-only candidates. This can cause false activations if the root manifest
  lists dependencies belonging to other services. Treat these as candidates and confirm actual scoped usage before dispatch.
- **Polyglot repos**: multiple Wave 3 skills matching is expected. Run all of them.
- **No matches**: skip Wave 3 entirely with a note.
- **False positives**: a `test/` directory with only fixture data may trigger `testing`.
  Inspect ambiguous fixtures before dispatch.
- **Large repos (>5000 files)**: the detection script is fast (grep on file list, not file
  contents) but the dependency manifest checks read files. No file-count caps silently omit later manifests. Report unreadable tracked files as coverage gaps.
