# Detection Patterns for Wave 3

File-pattern matching table for determining which domain-specific skills to run.
Each match proposes a candidate lens; confirm relevance to the requested scope.

## Detection Method

Run from repo root using `git ls-files` output. A skill activates if at least one
pattern matches. Confirm ambiguous matches before dispatch, especially workspace-root
dependencies that may belong to an unrelated service.

## Pattern Table

| Skill | File patterns | Dependency patterns (check manifests) |
|-------|--------------|--------------------------------------|
| testing | `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`, `pytest.ini`, `conftest.py`, `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `.nycrc*`, `cypress.config.*`, `cypress/` | - |
| command-prompt | `*.sh`, `*.bash`, `*.zsh`, `Makefile`, `justfile`, `.envrc`, `scripts/` | Shebang detection (`#!/bin/bash` in extensionless files) is not implemented in the script - file-extension and directory patterns cover the common cases |
| databases | `*.sql`, `migrations/`, `*.prisma`, `schema.prisma`, `knexfile.*`, `alembic/`, `alembic.ini`, `flyway/`, `drizzle.config.*`, `mongod.conf`, `my.cnf`, `pg_hba.conf`, `pgbouncer.ini` | `sequelize`, `typeorm`, `prisma`, `knex`, `drizzle-orm`, `mongoose`, `pg`, `mysql2` |
| backend-api | `openapi.*`, `swagger.*` | `fastapi`, `flask`, `django`, `express`, `@nestjs/core`, `hono`, `elysia`, `@hono/node-server` |
| frontend-design | `astro.config.*`, `svelte.config.*`, `next.config.*`, `vite.config.*`, `tailwind.config.*`, `src/app/`, `src/pages/`, `src/routes/`, `app/`, `pages/`, `components/`, `*.css`, `*.scss`, `*.sass`, `*.tsx`, `*.jsx`, `*.svelte`, `*.astro`, `*.vue` | `astro`, `@sveltejs/kit`, `svelte`, `next`, `react`, `vue`, `vite`, `tailwindcss`, `@vitejs/plugin-react`, `@astrojs/*` |
| localize | `locales/`, `i18n/`, `*.po`, `*.pot`, `*.xliff`, `*.xlf`, `messages.*.json`, `messages.*.yaml` | `react-i18next`, `vue-i18n`, `next-intl`, `@formatjs/intl`, `i18next` |
| ai-ml | - | `anthropic`, `openai`, `langchain`, `llama-index`, `llama_index`, `transformers`, `torch`, `tensorflow`, `ollama`, `chromadb`, `pinecone-client`, `weaviate-client`, `qdrant-client` |
| mcp | `.mcp.json`, `mcp.json` | `@modelcontextprotocol/sdk`, `fastmcp` |
| docker | `Dockerfile*`, `docker-compose.*`, `compose.*`, `.dockerignore`, `Containerfile*` | - |
| kubernetes | `Chart.yaml`, `helmfile.yaml`, `kustomization.yaml`, `kustomization.yml` | Also: any `.yaml`/`.yml` with both `apiVersion:` and `kind:` (excluding CI and compose files) |
| terraform | `*.tf`, `*.tfvars`, `terragrunt.hcl`, `.terraform-version`, `.terraform.lock.hcl` | - |
| ansible | `ansible.cfg`, `galaxy.yml`, `galaxy.yaml`, `roles/*/tasks/main.yml` | Also: `playbooks/*.yml` containing `hosts:`, or `requirements.yml` containing `roles:` or `collections:` |
| ci-cd | `.github/workflows/*.yml`, `.github/workflows/*.yaml`, `.gitlab-ci.yml`, `.forgejo/workflows/`, `Jenkinsfile`, `.circleci/config.yml` | - |
| networking | `nginx.conf`, `Caddyfile`, `haproxy.cfg`, `traefik.yml`, `traefik.yaml`, `traefik.toml`, `*.zone`, `named.conf`, `dnsmasq.conf`, `wg*.conf`, `nftables.conf` | - |
| observability | `prometheus.yml`, `prometheus.yaml`, `*.rules.yml`, `*.rules.yaml`, `alertmanager.yml`, `alertmanager.yaml`, `otel-collector*.yaml`, `otelcol*.yaml`, `loki*.yaml`, `tempo*.yaml`, `grafana/provisioning/`, `grafana/dashboards/` | - |
| arch-btw | `PKGBUILD`, `*.install`, `mkinitcpio.conf*`, `archinstall.json`, `etc/pacman.d/`, `etc/pacman.conf` | - |
| debian-ubuntu | `debian/control`, `debian/changelog`, `debian/rules`, `debian/copyright`, `*.dsc`, `snapcraft.yaml`, `snap/snapcraft.yaml` | - |
| rhel-fedora | `*.spec`, `.copr/`, `dracut.conf*`, `selinux/*.te`, `comps.xml*`, `dnf/modules.d/` | - |
| nixos-btw | `flake.nix`, `flake.lock`, `*.nix`, `configuration.nix`, `home.nix`, `default.nix`, `shell.nix` | - |
| firewall-appliance | `pf.conf`, `opnsense/`, `pfsense/`, `configctl*`, `pf.anchors/` | - |
| virtualization | `Vagrantfile`, `*.pkr.hcl`, `packer*.json`, `cloud-init*`, `user-data`, `meta-data`, `libvirt/*.xml`, `proxmox-*.json` | - |

Manifests to check for dependency patterns: `package.json`, `requirements.txt`,
`pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `composer.json`.

## Detection Script

Run from repo root. Outputs matched skill names, one per line. Accepts an optional
scope argument to filter detection to a subdirectory. The line-based example assumes
ordinary filenames without embedded newlines or Git quoting; for unusual paths, use a
NUL-delimited inventory and preserve that representation through matching.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires: git repo as CWD. Optional: $1 = scope path for subdirectory filtering.
scope="${1:-}"
include_root="${DEEP_AUDIT_ROOT_MANIFESTS:-1}"
if [[ -n "$scope" ]]; then
  files=$(git ls-files -- "$scope")
else
  files=$(git ls-files)
fi
matched=()

# --- File-pattern checks ---
# Patterns avoid start-of-line anchors so subdirectory paths match.

# testing
grep -qE '\.(test|spec)\.|__tests__/|(^|/)tests?/|jest\.config|vitest\.config|playwright\.config|pytest\.ini|conftest\.py|cypress\.config|cypress/|\.nycrc' <<< "$files" \
  && matched+=(testing)

# command-prompt
grep -qE '\.sh$|\.bash$|\.zsh$|(^|/)Makefile$|(^|/)justfile$|(^|/)scripts/|\.envrc$' <<< "$files" \
  && matched+=(command-prompt)

# databases
grep -qE '\.sql$|migrations/|\.prisma$|knexfile\.|alembic|flyway/|drizzle\.config|pgbouncer\.ini|mongod\.conf|my\.cnf|pg_hba\.conf' <<< "$files" \
  && matched+=(databases)

# backend-api (file patterns)
grep -qE 'openapi\.|swagger\.' <<< "$files" \
  && matched+=(backend-api)

# frontend-design
grep -qE 'astro\.config|svelte\.config|next\.config|vite\.config|tailwind\.config|(^|/)(src/)?(app|pages|routes)/|(^|/)components/|\.(css|scss|sass|tsx|jsx|svelte|astro|vue)$' <<< "$files" \
  && matched+=(frontend-design)

# localize
grep -qE 'locales/|i18n/|\.po$|\.pot$|\.xliff$|\.xlf$|messages\.[a-z].*\.json$|messages\.[a-z].*\.yaml$' <<< "$files" \
  && matched+=(localize)

# mcp
grep -qE '(^|/)\.?mcp\.json$' <<< "$files" \
  && matched+=(mcp)

# docker (no -i flag, no start-of-line anchors)
grep -qE '(^|/)Dockerfile|(^|/)docker-compose\.|(^|/)compose\.|\.dockerignore$|(^|/)Containerfile' <<< "$files" \
  && matched+=(docker)

# kubernetes (well-known files)
grep -qE 'Chart\.yaml$|helmfile\.yaml$|kustomization\.ya?ml$' <<< "$files" \
  && matched+=(kubernetes)

# terraform
grep -qE '\.tf$|\.tfvars$|terragrunt\.hcl$|\.terraform-version$|\.terraform\.lock\.hcl$' <<< "$files" \
  && matched+=(terraform)

# ansible
grep -qE '(^|/)ansible\.cfg$|galaxy\.ya?ml$|roles/.*/tasks/main\.yml' <<< "$files" \
  && matched+=(ansible)

# ci-cd
grep -qE '\.github/workflows/|\.gitlab-ci\.yml$|\.forgejo/workflows/|Jenkinsfile$|\.circleci/' <<< "$files" \
  && matched+=(ci-cd)

# networking
grep -qE 'nginx\.conf|Caddyfile|haproxy\.cfg|traefik\.(ya?ml|toml)|\.zone$|named\.conf|dnsmasq\.conf|wg[0-9]*\.conf$|nftables\.conf' <<< "$files" \
  && matched+=(networking)

# observability (Prometheus/Alertmanager/OTel/Loki/Tempo config, Grafana provisioning)
grep -qE '(^|/)prometheus\.ya?ml$|\.rules\.ya?ml$|(^|/)alertmanager\.ya?ml$|(^|/)otel-collector.*\.ya?ml$|(^|/)otelcol.*\.ya?ml$|(^|/)loki.*\.ya?ml$|(^|/)tempo.*\.ya?ml$|(^|/)grafana/(provisioning|dashboards)/' <<< "$files" \
  && matched+=(observability)

# arch-btw
grep -qE '(^|/)PKGBUILD$|\.install$|(^|/)mkinitcpio\.conf|(^|/)archinstall\.json$|(^|/)etc/pacman\.(d/|conf)' <<< "$files" \
  && matched+=(arch-btw)

# debian-ubuntu
grep -qE '(^|/)debian/(control|changelog|rules|copyright)$|\.dsc$|(^|/)(snap/)?snapcraft\.yaml$' <<< "$files" \
  && matched+=(debian-ubuntu)

# rhel-fedora
grep -qE '\.spec$|(^|/)\.copr/|(^|/)dracut\.conf|(^|/)selinux/.*\.te$|(^|/)comps\.xml|(^|/)dnf/modules\.d/' <<< "$files" \
  && matched+=(rhel-fedora)

# nixos-btw (Nix files and flake.lock are candidate signals)
grep -qE '\.nix$|(^|/)flake\.lock$' <<< "$files" \
  && matched+=(nixos-btw)

# firewall-appliance (OPNsense/pfSense config repos)
grep -qE '(^|/)pf\.conf|(^|/)opnsense/|(^|/)pfsense/|(^|/)configctl|(^|/)pf\.anchors/' <<< "$files" \
  && matched+=(firewall-appliance)

# virtualization (Packer, cloud-init, libvirt, Proxmox, Vagrant)
grep -qE '(^|/)Vagrantfile|\.pkr\.hcl$|(^|/)packer.*\.json$|(^|/)cloud-init|(^|/)user-data$|(^|/)meta-data$|(^|/)libvirt/.*\.xml$|(^|/)proxmox-.*\.json$' <<< "$files" \
  && matched+=(virtualization)

# Content errors are coverage failures, not negative matches.
check_content() {
  local status=0
  grep "$@" || status=$?
  if (( status > 1 )); then
    printf 'Detection could not read a candidate file (status %s).\n' "$status" >&2
    exit "$status"
  fi
  return "$status"
}

# --- Dependency-manifest checks (only for skills not yet matched) ---

check_manifest() {
  local skill="$1" pattern="$2"
  # Skip if already matched
  printf '%s\n' "${matched[@]}" | grep -qx "$skill" && return 0
  # Check repo-root manifests first, then scoped manifests (monorepo support)
  local manifest_files=()
  if [[ "$include_root" == 1 ]]; then
    for name in package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile composer.json; do
      [[ -f "$name" ]] && manifest_files+=("$name")
    done
  fi
  # Include every tracked nested manifest in both full and scoped runs.
  while IFS= read -r f; do
    manifest_files+=("$f")
  done < <(grep -E '(^|/)(package\.json|requirements\.txt|pyproject\.toml|go\.mod|Cargo\.toml|Gemfile|composer\.json)$' <<< "$files")
  for manifest in "${manifest_files[@]}"; do
    check_content -qEi "$pattern" "$manifest" && matched+=("$skill") && return 0
  done
  return 0
}

check_manifest backend-api 'fastapi|flask|django|"express"|@nestjs/core|"hono"|"elysia"'
check_manifest frontend-design 'astro|@sveltejs/kit|"svelte"|next|react|vue|vite|tailwindcss|@vitejs/plugin-react|@astrojs/'
check_manifest databases 'sequelize|typeorm|prisma|"knex"|drizzle-orm|mongoose|"pg"|mysql2'
check_manifest localize 'react-i18next|vue-i18n|next-intl|@formatjs|i18next'
check_manifest ai-ml 'anthropic|openai|langchain|llama[-_]index|transformers|torch|tensorflow|ollama|chromadb|pinecone|weaviate|qdrant'
check_manifest mcp '@modelcontextprotocol/sdk|fastmcp'

# kubernetes: check for raw manifests if Chart.yaml etc. not found
printf '%s\n' "${matched[@]}" | grep -qx kubernetes || {
  while IFS= read -r f; do
    check_content -q 'apiVersion:' "$f" && check_content -q 'kind:' "$f" \
      && matched+=(kubernetes) && break
  done < <(grep -E '\.ya?ml$' <<< "$files" | grep -vE 'docker-compose|compose\.|\.github/|\.gitlab-ci|\.forgejo/')
}

# ansible: check for playbooks and requirements.yml if ansible.cfg not found
printf '%s\n' "${matched[@]}" | grep -qx ansible || {
  # check requirements.yml for roles:/collections:
  while IFS= read -r f; do
    check_content -qE '^\s*(roles|collections):' "$f" && matched+=(ansible) && break
  done < <(grep -E '(^|/)requirements\.ya?ml$' <<< "$files")
}
printf '%s\n' "${matched[@]}" | grep -qx ansible || {
  # check playbook-like files for hosts: (exclude .github/ to avoid CI false positives)
  while IFS= read -r f; do
    check_content -q 'hosts:' "$f" && matched+=(ansible) && break
  done < <(grep -E '(playbook|site|main).*\.ya?ml$' <<< "$files" | grep -v '\.github/')
}

# --- Output ---
printf '%s\n' "${matched[@]}" | sort -u
```

## Edge Cases

- **Monorepos**: pass the scope path as `$1` to filter detection to that subtree.
  The script uses `git ls-files -- "$scope"` when an argument is provided.
  Note: repo-root manifests (e.g., a workspace-level `package.json`) are always
  checked by default even in scoped mode. Run the same scope again with
  `DEEP_AUDIT_ROOT_MANIFESTS=0` to get scoped-only matches; the set difference is
  root-manifest-only candidates. This can cause false activations if the root manifest
  lists dependencies belonging to other services. Treat these as candidates and confirm actual scoped usage before dispatch.
- **Polyglot repos**: multiple Wave 3 skills matching is expected. Run all of them.
- **No matches**: skip Wave 3 entirely with a note.
- **False positives**: a `test/` directory with only fixture data may trigger `testing`.
  Inspect ambiguous fixtures before dispatch.
- **Large repos (>5000 files)**: the detection script is fast (grep on file list, not file
  contents) but the dependency manifest checks read files. No file-count caps silently omit later manifests. Report unreadable tracked files as coverage gaps.
- **Shebang detection**: the table notes shebang matching for `command-prompt` but the script
  does not implement it (would require reading file contents, significantly slower). The
  `*.sh`/`*.bash`/`Makefile`/`scripts/` patterns catch the vast majority of cases.
