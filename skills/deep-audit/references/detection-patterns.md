# Detection Patterns for Wave 3

File-pattern matching table for determining which domain-specific skills to run.
Each skill activates when ANY of its patterns match files in the repo.

## Detection Method

Run from repo root using `git ls-files` output. A skill activates if at least one
pattern matches. False positives are acceptable - the skill itself handles repos where
its domain isn't actually present.

## Pattern Table

| Skill | File patterns | Dependency patterns (check manifests) |
|-------|--------------|--------------------------------------|
| testing | `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`, `pytest.ini`, `conftest.py`, `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `.nycrc*`, `cypress.config.*`, `cypress/` | - |
| command-prompt | `*.sh`, `*.bash`, `*.zsh`, `Makefile`, `justfile`, `.envrc`, `scripts/` | Shebang detection (`#!/bin/bash` in extensionless files) is not implemented in the script - file-extension and directory patterns cover the common cases |
| databases | `*.sql`, `migrations/`, `*.prisma`, `schema.prisma`, `knexfile.*`, `alembic/`, `alembic.ini`, `flyway/`, `drizzle.config.*`, `mongod.conf`, `my.cnf`, `pg_hba.conf`, `pgbouncer.ini` | `sequelize`, `typeorm`, `prisma`, `knex`, `drizzle-orm`, `mongoose`, `pg`, `mysql2` |
| backend-api | `openapi.*`, `swagger.*` | `fastapi`, `flask`, `django`, `express`, `@nestjs/core`, `hono`, `elysia`, `@hono/node-server` |
| localize | `locales/`, `i18n/`, `*.po`, `*.pot`, `*.xliff`, `*.xlf`, `messages.*.json`, `messages.*.yaml` | `react-i18next`, `vue-i18n`, `next-intl`, `@formatjs/intl`, `i18next` |
| ai-ml | - | `anthropic`, `openai`, `langchain`, `llama-index`, `llama_index`, `transformers`, `torch`, `tensorflow`, `ollama`, `chromadb`, `pinecone-client`, `weaviate-client`, `qdrant-client` |
| mcp | `.mcp.json`, `mcp.json` | `@modelcontextprotocol/sdk`, `fastmcp` |
| docker | `Dockerfile*`, `docker-compose.*`, `compose.*`, `.dockerignore`, `Containerfile*` | - |
| kubernetes | `Chart.yaml`, `helmfile.yaml`, `kustomization.yaml`, `kustomization.yml` | Also: any `.yaml`/`.yml` with both `apiVersion:` and `kind:` (excluding CI and compose files) |
| terraform | `*.tf`, `*.tfvars`, `terragrunt.hcl`, `.terraform-version`, `.terraform.lock.hcl` | - |
| ansible | `ansible.cfg`, `galaxy.yml`, `galaxy.yaml`, `roles/*/tasks/main.yml` | Also: `playbooks/*.yml` containing `hosts:`, or `requirements.yml` containing `roles:` or `collections:` |
| ci-cd | `.github/workflows/*.yml`, `.github/workflows/*.yaml`, `.gitlab-ci.yml`, `.forgejo/workflows/`, `Jenkinsfile`, `.circleci/config.yml` | - |
| networking | `nginx.conf`, `Caddyfile`, `haproxy.cfg`, `traefik.yml`, `traefik.yaml`, `traefik.toml`, `*.zone`, `named.conf`, `dnsmasq.conf`, `wg*.conf`, `nftables.conf` | - |
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
scope argument to filter detection to a subdirectory.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires: git repo as CWD. Optional: $1 = scope path for subdirectory filtering.
scope="${1:-}"
if [[ -n "$scope" ]]; then
  files=$(git ls-files -- "$scope")
else
  files=$(git ls-files)
fi
matched=()

# --- File-pattern checks ---
# Patterns avoid start-of-line anchors so subdirectory paths match.

# testing
echo "$files" | grep -qE '\.(test|spec)\.|__tests__/|(^|/)tests?/|jest\.config|vitest\.config|playwright\.config|pytest\.ini|conftest\.py|cypress\.config|cypress/|\.nycrc' \
  && matched+=(testing)

# command-prompt
echo "$files" | grep -qE '\.sh$|\.bash$|\.zsh$|(^|/)Makefile$|(^|/)justfile$|(^|/)scripts/|\.envrc$' \
  && matched+=(command-prompt)

# databases
echo "$files" | grep -qE '\.sql$|migrations/|\.prisma$|knexfile\.|alembic|flyway/|drizzle\.config|pgbouncer\.ini|mongod\.conf|my\.cnf|pg_hba\.conf' \
  && matched+=(databases)

# backend-api (file patterns)
echo "$files" | grep -qE 'openapi\.|swagger\.' \
  && matched+=(backend-api)

# localize
echo "$files" | grep -qE 'locales/|i18n/|\.po$|\.pot$|\.xliff$|\.xlf$|messages\.[a-z].*\.json$|messages\.[a-z].*\.yaml$' \
  && matched+=(localize)

# mcp
echo "$files" | grep -qE '(^|/)\.?mcp\.json$' \
  && matched+=(mcp)

# docker (no -i flag, no start-of-line anchors)
echo "$files" | grep -qE '(^|/)Dockerfile|(^|/)docker-compose\.|(^|/)compose\.|\.dockerignore$|(^|/)Containerfile' \
  && matched+=(docker)

# kubernetes (well-known files)
echo "$files" | grep -qE 'Chart\.yaml$|helmfile\.yaml$|kustomization\.ya?ml$' \
  && matched+=(kubernetes)

# terraform
echo "$files" | grep -qE '\.tf$|\.tfvars$|terragrunt\.hcl$|\.terraform-version$|\.terraform\.lock\.hcl$' \
  && matched+=(terraform)

# ansible
echo "$files" | grep -qE '(^|/)ansible\.cfg$|galaxy\.ya?ml$|roles/.*/tasks/main\.yml' \
  && matched+=(ansible)

# ci-cd
echo "$files" | grep -qE '\.github/workflows/|\.gitlab-ci\.yml$|\.forgejo/workflows/|Jenkinsfile$|\.circleci/' \
  && matched+=(ci-cd)

# networking
echo "$files" | grep -qE 'nginx\.conf|Caddyfile|haproxy\.cfg|traefik\.(ya?ml|toml)|\.zone$|named\.conf|dnsmasq\.conf|wg[0-9]*\.conf$|nftables\.conf' \
  && matched+=(networking)

# arch-btw
echo "$files" | grep -qE '(^|/)PKGBUILD$|\.install$|(^|/)mkinitcpio\.conf|(^|/)archinstall\.json$|(^|/)etc/pacman\.(d/|conf)' \
  && matched+=(arch-btw)

# debian-ubuntu
echo "$files" | grep -qE '(^|/)debian/(control|changelog|rules|copyright)$|\.dsc$|(^|/)(snap/)?snapcraft\.yaml$' \
  && matched+=(debian-ubuntu)

# rhel-fedora
echo "$files" | grep -qE '\.spec$|(^|/)\.copr/|(^|/)dracut\.conf|(^|/)selinux/.*\.te$|(^|/)comps\.xml|(^|/)dnf/modules\.d/' \
  && matched+=(rhel-fedora)

# nixos-btw (any .nix file is a strong signal; flake.lock is the conclusive one)
echo "$files" | grep -qE '\.nix$|(^|/)flake\.lock$' \
  && matched+=(nixos-btw)

# firewall-appliance (OPNsense/pfSense config repos)
echo "$files" | grep -qE '(^|/)pf\.conf|(^|/)opnsense/|(^|/)pfsense/|(^|/)configctl|(^|/)pf\.anchors/' \
  && matched+=(firewall-appliance)

# virtualization (Packer, cloud-init, libvirt, Proxmox, Vagrant)
echo "$files" | grep -qE '(^|/)Vagrantfile|\.pkr\.hcl$|(^|/)packer.*\.json$|(^|/)cloud-init|(^|/)user-data$|(^|/)meta-data$|(^|/)libvirt/.*\.xml$|(^|/)proxmox-.*\.json$' \
  && matched+=(virtualization)

# --- Dependency-manifest checks (only for skills not yet matched) ---

check_manifest() {
  local skill="$1" pattern="$2"
  # Skip if already matched
  printf '%s\n' "${matched[@]}" | grep -qx "$skill" && return 0
  # Check repo-root manifests first, then scoped manifests (monorepo support)
  local manifest_files=()
  for name in package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile composer.json; do
    [[ -f "$name" ]] && manifest_files+=("$name")
  done
  # Also find manifests within the scoped file tree
  if [[ -n "$scope" ]]; then
    while IFS= read -r f; do
      manifest_files+=("$f")
    done < <(echo "$files" | grep -E '(^|/)(package\.json|requirements\.txt|pyproject\.toml|go\.mod|Cargo\.toml|Gemfile|composer\.json)$' | head -10)
  fi
  for manifest in "${manifest_files[@]}"; do
    grep -qEi "$pattern" "$manifest" 2>/dev/null && matched+=("$skill") && return 0
  done
  return 0
}

check_manifest backend-api 'fastapi|flask|django|"express"|@nestjs/core|"hono"|"elysia"'
check_manifest databases 'sequelize|typeorm|prisma|"knex"|drizzle-orm|mongoose|"pg"|mysql2'
check_manifest localize 'react-i18next|vue-i18n|next-intl|@formatjs|i18next'
check_manifest ai-ml 'anthropic|openai|langchain|llama[-_]index|transformers|torch|tensorflow|ollama|chromadb|pinecone|weaviate|qdrant'
check_manifest mcp '@modelcontextprotocol/sdk|fastmcp'

# kubernetes: check for raw manifests if Chart.yaml etc. not found
printf '%s\n' "${matched[@]}" | grep -qx kubernetes || {
  while IFS= read -r f; do
    grep -q 'apiVersion:' "$f" 2>/dev/null && grep -q 'kind:' "$f" 2>/dev/null \
      && matched+=(kubernetes) && break
  done < <(echo "$files" | grep -E '\.ya?ml$' | grep -vE 'docker-compose|compose\.|\.github/|\.gitlab-ci|\.forgejo/' | head -20)
}

# ansible: check for playbooks and requirements.yml if ansible.cfg not found
printf '%s\n' "${matched[@]}" | grep -qx ansible || {
  # check requirements.yml for roles:/collections:
  while IFS= read -r f; do
    grep -qE '^\s*(roles|collections):' "$f" 2>/dev/null && matched+=(ansible) && break
  done < <(echo "$files" | grep -E '(^|/)requirements\.ya?ml$' | head -5)
}
printf '%s\n' "${matched[@]}" | grep -qx ansible || {
  # check playbook-like files for hosts: (exclude .github/ to avoid CI false positives)
  while IFS= read -r f; do
    grep -q 'hosts:' "$f" 2>/dev/null && matched+=(ansible) && break
  done < <(echo "$files" | grep -E '(playbook|site|main).*\.ya?ml$' | grep -v '\.github/' | head -10)
}

# --- Output ---
printf '%s\n' "${matched[@]}" | sort -u
```

## Edge Cases

- **Monorepos**: pass the scope path as `$1` to filter detection to that subtree.
  The script uses `git ls-files -- "$scope"` when an argument is provided.
  Note: repo-root manifests (e.g., a workspace-level `package.json`) are always
  checked even in scoped mode. This can cause false activations if the root manifest
  lists dependencies belonging to other services. Acceptable trade-off - the invoked
  skill will quickly identify that the scoped subtree has no relevant code.
- **Polyglot repos**: multiple Wave 3 skills matching is expected. Run all of them.
- **No matches**: skip Wave 3 entirely with a note.
- **False positives**: a `test/` directory with only fixture data may trigger `testing`.
  Acceptable - the testing skill will recognize the situation and report accordingly.
- **Large repos (>5000 files)**: the detection script is fast (grep on file list, not file
  contents) but the dependency manifest checks read files. Both are negligible even at scale.
- **Shebang detection**: the table notes shebang matching for `command-prompt` but the script
  does not implement it (would require reading file contents, significantly slower). The
  `*.sh`/`*.bash`/`Makefile`/`scripts/` patterns catch the vast majority of cases.
