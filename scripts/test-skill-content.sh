#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016
set -euo pipefail

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=skill-lib.sh
source "$ROOT/scripts/skill-lib.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local file="$1" text="$2" message="$3"
  grep -Fq -- "$text" "$ROOT/$file" || fail "$message"
}

reject_text() {
  local file="$1" text="$2" message="$3"
  if grep -Fq -- "$text" "$ROOT/$file"; then
    fail "$message"
  fi
}

reject_trigger() {
  local skill="$1" trigger="$2" description
  description="$(frontmatter_get "$ROOT/skills/$skill/SKILL.md" description)"
  if grep -Fq -- "'$trigger'" <<< "$description"; then
    fail "$skill still has broad trigger '$trigger'"
  fi
}

contract="skills/_shared/output-contract.md"
for marker in 'P0 🔴' 'P1 🟠' 'P2 🟡' 'P3 🔵' 'info ⚪'; do
  require_text "$contract" "$marker" "output contract is missing severity marker '$marker'"
done
require_text "$contract" '```text' "output contract does not use fenced text blocks"
for glyph in '╔' '═' '╗' '║' '╚' '╝' '╦' '╠' '╬' '╣' '╩'; do
  reject_text "$contract" "$glyph" "output contract still contains box-drawing glyph '$glyph'"
done

for file in \
  skills/security-audit/SKILL.md \
  skills/security-audit/references/report-guide.md \
  skills/repo-audit/SKILL.md \
  skills/repo-audit/references/quick-workflow.md \
  skills/repo-audit/references/exhaustive-workflow.md \
  skills/repo-audit/references/report-templates.md; do
  reject_text "$file" 'SECURITY-AUDIT.md' "$file still prescribes the obsolete security report filename"
done

for file in skills/repo-audit/SKILL.md skills/repo-audit/references/quick-workflow.md; do
  reject_text "$file" '`general-purpose`' "$file still requires a general-purpose worker type"
  reject_text "$file" 'Skill tool' "$file still requires a harness-specific Skill tool"
done

for skill in ci-cd docker; do
  if frontmatter_has "$ROOT/skills/$skill/SKILL.md" paths; then
    fail "$skill still has non-portable paths frontmatter"
  fi
done
reject_text skills/skill-creator/references/conventions.md 'safe to include for progressive enhancement' "skill-creator still describes paths frontmatter as universally safe"
require_text skills/skill-creator/references/conventions.md 'claude.ai uploads and Skills API packaging reject' "skill-creator does not document paths packaging incompatibility"

version_ref="skills/dev-cycle/references/version-bump-sites.md"
require_text "$version_ref" '.version // empty' "dev-cycle does not convert a missing package version to empty"
require_text "$version_ref" 'No valid version source found' "dev-cycle does not fail clearly when no version exists"
require_text "$version_ref" 'rg --fixed-strings --hidden --no-ignore' "dev-cycle does not configure the fixed-string repository search"
require_text "$version_ref" '-- "$CURRENT_VERSION"' "dev-cycle does not terminate rg options before the version"

kubernetes="skills/kubernetes/SKILL.md"
require_text "$kubernetes" 'KUBE_CONTEXT="$(kubectl config current-context)"' "kubernetes does not capture the current context"
require_text "$kubernetes" 'kubectl --context "$KUBE_CONTEXT"' "kubernetes does not bind kubectl to the captured context"
require_text "$kubernetes" 'helm --kube-context "$KUBE_CONTEXT"' "kubernetes does not bind Helm to the captured context"

mcp="skills/mcp/SKILL.md"
require_text "$mcp" 'const handle = await serveStdio(createServer);' "MCP scaffold does not retain the stdio handle"
require_text "$mcp" 'await handle.close();' "MCP scaffold does not close the stdio handle"
require_text "$mcp" 'process.once("SIGINT"' "MCP scaffold does not handle SIGINT"
require_text "$mcp" 'process.once("SIGTERM"' "MCP scaffold does not handle SIGTERM"

mcp_security="skills/mcp/references/security.md"
require_text "$mcp_security" 'realpath' "MCP path guidance does not canonicalize paths"
require_text "$mcp_security" 'path.relative' "MCP path guidance does not check canonical containment"
require_text "$mcp_security" '{ all: true' "MCP SSRF guidance does not validate every DNS answer"
require_text "$mcp_security" 'every redirect' "MCP SSRF guidance does not revalidate redirects"
reject_text "$mcp_security" 'async function safeUrl' "MCP SSRF guidance still exposes the check-then-fetch safeUrl helper"

reject_trigger code-review review
reject_trigger code-review 'check this'
reject_trigger ansible role
reject_trigger ansible inventory
reject_trigger shell-scripting script
reject_trigger shell-scripting completion
reject_trigger databases schema
reject_trigger databases migration
reject_trigger testing spec
reject_trigger kubernetes deployment
reject_trigger kubernetes gateway
reject_trigger frontend-design 'design review'
reject_trigger vulnerability-research CVE
reject_trigger repo-audit 'run all checks'
reject_trigger repo-audit 'full check'

# Check useful domain cues without requiring the old quoted keyword-list syntax.
require_description() {
  local skill="$1" text="$2" description
  description="$(frontmatter_get "$ROOT/skills/$skill/SKILL.md" description)"
  grep -Fiq -- "$text" <<< "$description" || fail "$skill description is missing '$text'"
}

require_description i18n-localization 'i18n'
require_description i18n-localization 'catalog'
require_description i18n-localization 'translation'
require_description mcp 'MCP'
require_description mcp 'clients'
require_text skills/mcp/SKILL.md '@modelcontextprotocol/server' "mcp is missing the current server-package reference"
require_description arch-linux 'EndeavourOS'
require_description arch-linux 'Manjaro'
require_description virtualization 'VMware'
require_description virtualization 'ESXi'

# The meta-skill self-check exemption must not silently widen. Pin the exact
# declaration and require the comment that ties phase-1 changes to the guard.
require_text scripts/lint-skills.sh 'GENERIC_SELF_CHECK_EXEMPT=("skill-refiner" "skill-creator")' "lint-skills.sh GENERIC_SELF_CHECK_EXEMPT changed; re-justify the exemption and update this guard"
require_text scripts/lint-skills.sh 'phase-1 changes to this list remain subject to scripts/check-refiner-phase1-guard.sh' "lint-skills.sh exemption comment no longer ties phase-1 changes to the phase-1 guard"

test_scoped_audit_detection() (
  local fixture output
  fixture="$(mktemp -d)"
  trap 'rm -rf "$fixture"' EXIT
  git -C "$fixture" init -q
  mkdir -p "$fixture/service" "$fixture/other"
  printf '%s\n' '{"dependencies":{"kafkajs":"1","clinic":"1"}}' > "$fixture/package.json"
  touch "$fixture/service/user-profile.ts" "$fixture/service/subscription.ts" "$fixture/service/hotel.ts"
  git -C "$fixture" add .
  cd "$fixture"
  output="$(REPO_AUDIT_ROOT_MANIFESTS=0 bash "$ROOT/skills/repo-audit/references/detect.sh" service)"
  if grep -Eq '^(message-queues|performance-debugging|observability)$' <<< "$output"; then
    fail "generic scoped filenames activated broker, profiling, or telemetry lanes"
  fi
  output="$(bash "$ROOT/skills/repo-audit/references/detect.sh" service)"
  grep -qx message-queues <<< "$output" || fail "root queue dependency was not reported as a candidate"
  grep -qx performance-debugging <<< "$output" || fail "root profiling dependency was not reported as a candidate"
  mkdir -p service/Consumers service/profiling other/queues
  touch service/Consumers/orders.ts service/profiling/cpu.cpuprofile other/queues/tasks.ts
  git add .
  output="$(REPO_AUDIT_ROOT_MANIFESTS=0 bash "$ROOT/skills/repo-audit/references/detect.sh" service)"
  grep -qx message-queues <<< "$output" || fail "scoped queue component was not detected case-insensitively"
  grep -qx performance-debugging <<< "$output" || fail "scoped profiling artifact was not detected"
)

test_manifest_audit_detection() (
  local fixture output bytes status=0
  fixture="$(mktemp -d)"
  trap 'rm -rf "$fixture"' EXIT
  # detect_case <case> <path> <content>: one manifest per fresh repo; prints detected lanes.
  detect_case() {
    mkdir -p "$fixture/$1/$(dirname "$2")"
    git -C "$fixture/$1" init -q
    printf '%s\n' "$3" > "$fixture/$1/$2"
    git -C "$fixture/$1" add .
    (cd "$fixture/$1" && bash "$ROOT/skills/repo-audit/references/detect.sh")
  }
  output="$(detect_case go go.mod $'module x\n\nrequire (\n\tgithub.com/gin-gonic/gin v1.10.0\n\tgithub.com/jackc/pgx/v5 v5.7.0\n)')"
  grep -qx backend-api <<< "$output" || fail "go.mod gin was not detected as backend-api"
  grep -qx databases <<< "$output" || fail "go.mod pgx was not detected as databases"
  output="$(detect_case py pyproject.toml $'[project]\nname = "x"\ndependencies = [\n  "SQLAlchemy>=2",\n  "psycopg[binary]>=3",\n]')"
  grep -qx databases <<< "$output" || fail "pyproject sqlalchemy/psycopg was not detected as databases"
  output="$(detect_case poetry pyproject.toml $'[tool.poetry.dependencies]\npython = "^3.12"\nfastapi = "^0.115"')"
  grep -qx backend-api <<< "$output" || fail "Poetry fastapi was not detected as backend-api"
  output="$(detect_case natsort pyproject.toml $'[project]\ndependencies = ["natsort>=8"]')"
  grep -qx message-queues <<< "$output" && fail "natsort activated message-queues"
  output="$(detect_case js package.json '{"dependencies":{"next-tick":"1","0xproject":"1"}}')"
  grep -qx frontend-design <<< "$output" && fail "next-tick activated frontend-design"
  grep -qx performance-debugging <<< "$output" && fail "0xproject activated performance-debugging"
  output="$(detect_case keywords pyproject.toml $'[project]\nname = "x"\nkeywords = ["mcp"]\ndependencies = []')"
  grep -qx mcp <<< "$output" && fail "a pyproject mcp keyword activated mcp"
  output="$(detect_case tools .github/tools/x/requirements.txt 'mcp==1.0')"
  grep -qx mcp <<< "$output" && fail "a .github tool manifest activated mcp"
  output="$(detect_case rust Cargo.toml $'[package]\nname = "x"\n\n[dependencies]\naxum = "0.7"\nsqlx = { version = "0.8", features = ["postgres"] }')"
  grep -qx backend-api <<< "$output" || fail "Cargo axum was not detected as backend-api"
  grep -qx databases <<< "$output" || fail "Cargo sqlx was not detected as databases"
  output="$(detect_case ruby Gemfile $'source "https://rubygems.org"\ngem "rails", "~> 7.2"\ngem \'pg\'')"
  grep -qx backend-api <<< "$output" || fail "Gemfile rails was not detected as backend-api"
  grep -qx databases <<< "$output" || fail "Gemfile pg was not detected as databases"
  output="$(detect_case php composer.json '{"require":{"laravel/framework":"^11.0"}}')"
  grep -qx backend-api <<< "$output" || fail "composer laravel/framework was not detected as backend-api"
  mkdir -p "$fixture/empty"
  git -C "$fixture/empty" init -q
  bytes="$(cd "$fixture/empty" && bash "$ROOT/skills/repo-audit/references/detect.sh" | wc -c)" || status=$?
  [[ "$status" == 0 ]] || fail "detection exited $status in an empty repo"
  [[ "$bytes" -eq 0 ]] || fail "detection printed output in an empty repo"
)

test_scoped_audit_detection
test_manifest_audit_detection
python3 "$ROOT/scripts/test-llm-examples.py"
printf 'All skill content tests passed.\n'
