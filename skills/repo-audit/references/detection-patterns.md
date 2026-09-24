# Exhaustive Domain Detection Patterns

File-pattern matching table for determining which domain-specific skills to run.
Each match proposes a candidate lens; confirm relevance to the requested scope.

## Detection Method

Run `references/detect.sh` from repo root; it uses `git ls-files` output and scoped manifest reads. A skill activates if at least one
pattern matches. Confirm ambiguous matches before dispatch, especially workspace-root
dependencies that may belong to an unrelated service.

## Pattern Table

| Skill | File patterns | Dependency patterns (check manifests) |
|-------|--------------|--------------------------------------|
| testing | `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`, `pytest.ini`, `conftest.py`, `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `.nycrc*`, `cypress.config.*`, `cypress/` | - |
| shell-scripting | `*.sh`, `*.bash`, `*.zsh`, `Makefile`, `justfile`, `.envrc`, `scripts/` | Shebang detection (`#!/bin/bash` in extensionless files) is not implemented in the script - file-extension and directory patterns cover the common cases |
| databases | `*.sql`, `migrations/`, `*.prisma`, `schema.prisma`, `knexfile.*`, `alembic/`, `alembic.ini`, `flyway/`, `drizzle.config.*`, `mongod.conf`, `my.cnf`, `pg_hba.conf`, `pgbouncer.ini` | `sequelize`, `typeorm`, `prisma`, `knex`, `drizzle-orm`, `mongoose`, `pg`, `mysql2` |
| backend-api | `openapi.*`, `swagger.*` | `fastapi`, `flask`, `django`, `express`, `@nestjs/core`, `hono`, `elysia`, `@hono/node-server` |
| frontend-design | `astro.config.*`, `svelte.config.*`, `next.config.*`, `vite.config.*`, `tailwind.config.*`, `src/app/`, `src/pages/`, `src/routes/`, `app/`, `pages/`, `components/`, `*.css`, `*.scss`, `*.sass`, `*.tsx`, `*.jsx`, `*.svelte`, `*.astro`, `*.vue` | `astro`, `@sveltejs/kit`, `svelte`, `next`, `react`, `vue`, `vite`, `tailwindcss`, `@vitejs/plugin-react`, `@astrojs/*` |
| i18n-localization | `locales/`, `i18n/`, `*.po`, `*.pot`, `*.xliff`, `*.xlf`, `messages.*.json`, `messages.*.yaml` | `react-i18next`, `vue-i18n`, `next-intl`, `@formatjs/intl`, `i18next` |
| llm-app-development | - | `anthropic`, `openai`, `langchain`, `llama-index`, `llama_index`, `transformers`, `torch`, `tensorflow`, `ollama`, `chromadb`, `pinecone-client`, `weaviate-client`, `qdrant-client` |
| mcp | `.mcp.json`, `mcp.json` | `@modelcontextprotocol/sdk`, `@modelcontextprotocol/server`, `@modelcontextprotocol/client`, `@modelcontextprotocol/core`, `fastmcp`, Python `mcp` as a requirements/Poetry line (`mcp`, `mcp>=`, `mcp[cli]`, `mcp = `) or a quoted requirement with a version or extras (`"mcp>=2"`); a bare `"mcp"` string is not matched, so keywords and descriptions do not trigger it |
| message-queues | `kafka.*`, `rabbitmq.*`, `nats.*`, `sqs.*`, `queues/`, `consumers/`, `producers/`, `dead-letter.*`, `dlq/` | `kafkajs`, `amqplib`, `bullmq`, `celery`, `nats`, `@aws-sdk/client-sqs` |
| performance-debugging | `benchmarks/`, `profiling/`, `flamegraph.*`, `*.cpuprofile`, `*.heapprofile`, `*.pprof`, `k6.*.js`, `artillery.yml`, `locust.py`, `performance-budget.json` | `benchmark`, `autocannon`, `clinic`, `0x`, `k6`, `artillery`, `locust` |
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
- **Shebang detection**: the table notes shebang matching for `shell-scripting` but the script
  does not implement it (would require reading file contents, significantly slower). The
  `*.sh`/`*.bash`/`Makefile`/`scripts/` patterns catch the vast majority of cases.
