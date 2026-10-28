#!/usr/bin/env bash
set -euo pipefail

# Requires: git repo as CWD. Optional: $1 = scope path for subdirectory filtering.
scope="${1:-}"
include_root="${REPO_AUDIT_ROOT_MANIFESTS:-1}"
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

# shell-scripting
grep -qE '\.sh$|\.bash$|\.zsh$|(^|/)Makefile$|(^|/)justfile$|(^|/)scripts/|\.envrc$' <<< "$files" \
  && matched+=(shell-scripting)

# databases
grep -qE '\.sql$|migrations/|\.prisma$|knexfile\.|alembic|flyway/|drizzle\.config|pgbouncer\.ini|mongod\.conf|my\.cnf|pg_hba\.conf' <<< "$files" \
  && matched+=(databases)

# backend-api (file patterns)
grep -qE 'openapi\.|swagger\.' <<< "$files" \
  && matched+=(backend-api)

# frontend-design
grep -qE 'astro\.config|svelte\.config|next\.config|vite\.config|tailwind\.config|(^|/)(src/)?(app|pages|routes)/|(^|/)components/|\.(css|scss|sass|tsx|jsx|svelte|astro|vue)$' <<< "$files" \
  && matched+=(frontend-design)

# i18n-localization
grep -qE 'locales/|i18n/|\.po$|\.pot$|\.xliff$|\.xlf$|messages\.[a-z].*\.json$|messages\.[a-z].*\.yaml$' <<< "$files" \
  && matched+=(i18n-localization)

# mcp
grep -qE '(^|/)\.?mcp\.json$' <<< "$files" \
  && matched+=(mcp)

# message queues and performance debugging
grep -qEi '(^|/)(kafka|rabbitmq|nats|sqs|queues?|consumers?|producers?|dead-letters?|dlq)(/|[._-])' <<< "$files" \
  && matched+=(message-queues)
grep -qEi '(^|/)(benchmarks?|profiling|flamegraphs?)(/|[._-])|(^|/)(k6|artillery|locust)([._-].*)?\.(js|ts|py|ya?ml|json)$|\.(cpuprofile|heapprofile|pprof)$|(^|/)performance[._-]budget\.(json|ya?ml)$' <<< "$files" \
  && matched+=(performance-debugging)

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

# arch-linux
grep -qE '(^|/)PKGBUILD$|\.install$|(^|/)mkinitcpio\.conf|(^|/)archinstall\.json$|(^|/)etc/pacman\.(d/|conf)' <<< "$files" \
  && matched+=(arch-linux)

# debian-ubuntu
grep -qE '(^|/)debian/(control|changelog|rules|copyright)$|\.dsc$|(^|/)(snap/)?snapcraft\.yaml$' <<< "$files" \
  && matched+=(debian-ubuntu)

# rhel-fedora
grep -qE '\.spec$|(^|/)\.copr/|(^|/)dracut\.conf|(^|/)selinux/.*\.te$|(^|/)comps\.xml|(^|/)dnf/modules\.d/' <<< "$files" \
  && matched+=(rhel-fedora)

# nixos (Nix files and flake.lock are candidate signals)
grep -qE '\.nix$|(^|/)flake\.lock$' <<< "$files" \
  && matched+=(nixos)

# opnsense-pfsense (OPNsense/pfSense config repos)
grep -qE '(^|/)pf\.conf|(^|/)opnsense/|(^|/)pfsense/|(^|/)configctl|(^|/)pf\.anchors/' <<< "$files" \
  && matched+=(opnsense-pfsense)

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

# Prints lower-cased dependency names declared by a manifest, one per line.
# JSON: keys only, so "keywords" values never count. TOML: keys under *dependencies*
# tables plus requirement strings in dependency arrays. Python/Cargo names: - _ . equal.
deps_of() {
  case "${1##*/}" in
    package.json|composer.json)
      awk '{ s = $0; while (match(s, /"[^"]+"[ \t]*:/)) { k = substr(s, RSTART + 1, RLENGTH - 1); sub(/"[ \t]*:$/, "", k); print k; s = substr(s, RSTART + RLENGTH) } }' "$1" ;;
    requirements.txt)
      awk '/^[ \t]*[A-Za-z0-9]/ { match($0, /[A-Za-z0-9][A-Za-z0-9._-]*/); print substr($0, RSTART, RLENGTH) }' "$1" | tr '_.' '--' ;;
    pyproject.toml|Cargo.toml)
      awk -v q="'" '
        function strs(s,   v) {
          while (match(s, "\"[^\"]*\"|" q "[^" q "]*" q)) {
            v = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
            if (match(v, /^[ \t]*[A-Za-z0-9][A-Za-z0-9._-]*/)) { v = substr(v, RSTART, RLENGTH); gsub(/[ \t]/, "", v); print v }
          }
        }
        function bare(s) { gsub("\"[^\"]*\"|" q "[^" q "]*" q, "", s); sub(/#.*/, "", s); return s }
        arr { strs($0); if (bare($0) ~ /\]/) arr = 0; next }
        /^[ \t]*\[/ { tbl = $0; if (match(tbl, /dependencies\.[A-Za-z0-9_-]+/)) { print substr(tbl, RSTART + 13, RLENGTH - 13); tbl = "" }; next }
        match($0, /^[ \t]*[A-Za-z0-9_.-]+[ \t]*=/) {
          key = substr($0, 1, RLENGTH - 1); gsub(/[ \t]/, "", key); rest = substr($0, RLENGTH + 1)
          if (rest ~ /^[ \t]*\[/ && (key == "dependencies" || tbl ~ /dependenc/)) { strs(rest); if (bare(rest) !~ /\]/) arr = 1 }
          else if (tbl ~ /dependenc/) print key
        }' "$1" | tr '_.' '--' ;;
    go.mod)
      awk '/^require[ \t]*\(/ { blk = 1; next } /^[ \t]*\)/ { blk = 0; next }
        /^require[ \t]/ { m = $2 } blk { m = $1 } m != "" { sub(/\/v[0-9]+$/, "", m); print m; m = "" }' "$1" ;;
    Gemfile) sed -nE "s/^[[:space:]]*gem[[:space:](]+['\"]([^'\"]+)['\"].*/\1/p" "$1" ;;
  esac | tr '[:upper:]' '[:lower:]'
}

# Check repo-root manifests first, then scoped manifests (monorepo support).
# Tool and vendored manifests are not application dependencies.
manifests=()
if [[ "$include_root" == 1 ]]; then
  for name in package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile composer.json; do
    [[ -f "$name" ]] && manifests+=("$name")
  done
fi
while IFS= read -r f; do
  manifests+=("$f")
done < <(grep -E '(^|/)(package\.json|requirements\.txt|pyproject\.toml|go\.mod|Cargo\.toml|Gemfile|composer\.json)$' <<< "$files" \
  | grep -vE '(^|/)(\.github|vendor|node_modules|third_party)/')
deps=""
for manifest in ${manifests[@]+"${manifests[@]}"}; do
  out=$(deps_of "$manifest") || {
    status=$?
    printf 'Detection could not read a candidate file (status %s).\n' "$status" >&2
    exit "$status"
  }
  deps+="$out"$'\n'
done

check_manifest() {
  local skill="$1" pattern="$2"
  printf '%s\n' ${matched[@]+"${matched[@]}"} | grep -qx "$skill" && return 0
  grep -qxiE "$pattern" <<< "$deps" && matched+=("$skill")
  return 0
}

check_manifest backend-api 'fastapi|flask|django|starlette|litestar|aiohttp|express|@nestjs/core|hono|@hono/node-server|elysia|fastify|koa|github\.com/(gin-gonic/gin|labstack/echo|gofiber/fiber|go-chi/chi|gorilla/mux)|google\.golang\.org/grpc|actix-web|axum|rocket|warp|tonic|rails|sinatra|grape|hanami|laravel/framework|symfony/http-kernel|slim/slim'
check_manifest frontend-design 'astro|@astrojs/.*|@sveltejs/kit|svelte|next|react|vue|vite|@vitejs/plugin-react|tailwindcss'
check_manifest databases 'sequelize|typeorm|prisma|@prisma/client|knex|drizzle-orm|mongoose|mongodb|pg|mysql2|ioredis|redis|sqlalchemy|sqlmodel|psycopg|psycopg2(-binary)?|asyncpg|pymongo|motor|pymysql|mysqlclient|peewee|tortoise-orm|github\.com/(jackc/pgx|lib/pq|jmoiron/sqlx|redis/go-redis|go-sql-driver/mysql)|gorm\.io/gorm|go\.mongodb\.org/mongo-driver|entgo\.io/ent|diesel|sqlx|sea-orm|tokio-postgres|activerecord|sequel|mongoid|doctrine/(orm|dbal)|illuminate/database|predis/predis'
check_manifest i18n-localization 'react-i18next|vue-i18n|next-intl|@formatjs/.*|i18next'
check_manifest llm-app-development 'anthropic|@anthropic-ai/sdk|openai|langchain|langchain-.*|@langchain/.*|llama-index(-.*)?|transformers|torch|tensorflow|ollama|chromadb|pinecone-client|weaviate-client|qdrant-client|github\.com/(anthropics/anthropic-sdk-go|openai/openai-go|sashabaranov/go-openai)|async-openai|ruby-openai|openai-php/client'
check_manifest mcp '@modelcontextprotocol/(sdk|server|client|core)|fastmcp|mcp|github\.com/(modelcontextprotocol/go-sdk|mark3labs/mcp-go)|rmcp'
check_manifest message-queues 'kafkajs|amqplib|bullmq|@aws-sdk/client-sqs|celery|kafka-python|confluent-kafka|aiokafka|pika|nats|nats-py|github\.com/(segmentio/kafka-go|ibm/sarama|rabbitmq/amqp091-go|nats-io/nats\.go)|rdkafka|lapin|async-nats|bunny|ruby-kafka|php-amqplib/php-amqplib'
check_manifest performance-debugging 'benchmark|autocannon|clinic|0x|k6|artillery|locust'

# kubernetes: check for raw manifests if Chart.yaml etc. not found
printf '%s\n' ${matched[@]+"${matched[@]}"} | grep -qx kubernetes || {
  while IFS= read -r f; do
    check_content -q 'apiVersion:' "$f" && check_content -q 'kind:' "$f" \
      && matched+=(kubernetes) && break
  done < <(grep -E '\.ya?ml$' <<< "$files" | grep -vE 'docker-compose|compose\.|\.github/|\.gitlab-ci|\.forgejo/')
}

# ansible: check for playbooks and requirements.yml if ansible.cfg not found
printf '%s\n' ${matched[@]+"${matched[@]}"} | grep -qx ansible || {
  # check requirements.yml for roles:/collections:
  while IFS= read -r f; do
    check_content -qE '^\s*(roles|collections):' "$f" && matched+=(ansible) && break
  done < <(grep -E '(^|/)requirements\.ya?ml$' <<< "$files")
}
printf '%s\n' ${matched[@]+"${matched[@]}"} | grep -qx ansible || {
  # check playbook-like files for hosts: (exclude .github/ to avoid CI false positives)
  while IFS= read -r f; do
    check_content -q 'hosts:' "$f" && matched+=(ansible) && break
  done < <(grep -E '(playbook|site|main).*\.ya?ml$' <<< "$files" | grep -v '\.github/')
}

# --- Output ---
if (( ${#matched[@]} )); then
  printf '%s\n' "${matched[@]}" | sort -u
fi
