#!/usr/bin/env bash
set -euo pipefail

scope="${1:-}"
include_root="${REPO_AUDIT_ROOT_MANIFESTS:-1}"
if [[ -n "$scope" ]]; then files="$(git ls-files -- "$scope")"; else files="$(git ls-files)"; fi
matched=()
has_file() { grep -qE "$1" <<< "$files"; }
has_manifest() {
  local pattern="$1" manifest
  local manifests=()
  [[ "$include_root" == 1 ]] && manifests+=(package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile composer.json)
  while IFS= read -r manifest; do manifests+=("$manifest"); done < <(grep -E '(^|/)(package\.json|requirements\.txt|pyproject\.toml|go\.mod|Cargo\.toml|Gemfile|composer\.json)$' <<< "$files" || true)
  for manifest in "${manifests[@]}"; do [[ -f "$manifest" ]] && grep -qiE "$pattern" "$manifest" && return 0; done
  return 1
}
add() { matched+=("$1"); }
has_file '\.(test|spec)\.|(^|/)tests?/|jest\.config|vitest\.config|playwright\.config|pytest\.ini|conftest\.py|cypress' && add testing
has_file '\.(sh|bash|zsh)$|(^|/)(Makefile|justfile)$|(^|/)scripts/|\.envrc$' && add shell-scripting
if has_file '\.sql$|migrations/|\.prisma$|alembic|flyway|drizzle\.config' || has_manifest 'sequelize|typeorm|prisma|knex|drizzle-orm|mongoose|"pg"|mysql'; then add databases; fi
if has_file 'openapi\.|swagger\.' || has_manifest 'fastapi|flask|django|"express"|@nestjs/core|"hono"'; then add backend-api; fi
if has_file 'astro\.config|svelte\.config|next\.config|vite\.config|tailwind\.config|(^|/)(app|pages|routes|components)/|\.(css|scss|sass|tsx|jsx|svelte|astro|vue)$' || has_manifest 'astro|svelte|next|react|vue|vite|tailwindcss'; then add frontend-design; fi
if has_file 'locales/|i18n/|\.(po|pot|xliff|xlf)$|messages\.[a-z].*\.(json|yaml)$' || has_manifest 'i18next|formatjs|next-intl'; then add i18n-localization; fi
has_manifest 'openai|anthropic|langchain|llama|transformers|torch|tensorflow|ollama|chromadb|pinecone|weaviate|qdrant' && add llm-app-development || true
if has_file '(^|/)\.?(mcp)\.json$' || has_manifest '@modelcontextprotocol/sdk|fastmcp'; then add mcp; fi
has_file '(^|/)(Dockerfile|Containerfile)|(^|/)(docker-compose|compose)\.|\.dockerignore$' && add docker
has_file 'Chart\.yaml$|helmfile\.yaml$|kustomization\.ya?ml$|(^|/)k8s/' && add kubernetes
has_file '\.tf$|\.tfvars$|terragrunt\.hcl$|\.terraform\.lock\.hcl$' && add terraform
has_file '(^|/)ansible\.cfg$|galaxy\.ya?ml$|roles/.*/tasks/main\.yml|playbooks/' && add ansible
has_file '\.github/workflows/|\.gitlab-ci\.yml$|\.forgejo/workflows/|Jenkinsfile$|\.circleci/' && add ci-cd
has_file 'nginx\.conf|Caddyfile|haproxy\.cfg|traefik\.|\.zone$|named\.conf|dnsmasq\.conf|wg[0-9]*\.conf$|nftables\.conf' && add networking
has_file 'prometheus\.ya?ml$|\.rules\.ya?ml$|alertmanager\.ya?ml$|otel|loki|tempo|grafana/(provisioning|dashboards)' && add observability
if has_file 'kafka|rabbitmq|nats|sqs|queue|consumer|producer|dead-letter|dlq|topic|subscription' || has_manifest 'kafkajs|amqplib|bullmq|celery|nats|@aws-sdk/client-sqs'; then add message-queues; fi
if has_file 'benchmark|benchmarks|k6|artillery|locust|flamegraph|profile|performance.*budget' || has_manifest 'benchmark|autocannon|clinic|0x|k6|artillery|locust'; then add performance-debugging; fi
has_file '(^|/)PKGBUILD$|\.install$|mkinitcpio\.conf|archinstall\.json|etc/pacman\.' && add arch-linux
has_file '(^|/)debian/|\.dsc$|(^|/)(snap/)?snapcraft\.yaml$' && add debian-ubuntu
has_file '\.spec$|(^|/)\.copr/|dracut\.conf|(^|/)selinux/.*\.te$' && add rhel-fedora
has_file '\.nix$|flake\.lock$' && add nixos
has_file 'pf\.conf|(^|/)(opnsense|pfsense)/|configctl|pf\.anchors/' && add opnsense-pfsense
has_file 'Vagrantfile|\.pkr\.hcl$|packer.*\.json$|cloud-init|user-data$|meta-data$|libvirt/.*\.xml$|proxmox-.*\.json$' && add virtualization
printf '%s\n' "${matched[@]}" | sort -u
