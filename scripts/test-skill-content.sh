#!/usr/bin/env bash
set -euo pipefail

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
  skills/full-review/SKILL.md \
  skills/deep-audit/SKILL.md; do
  reject_text "$file" 'SECURITY-AUDIT.md' "$file still prescribes the obsolete security report filename"
done

for file in skills/full-review/SKILL.md skills/deep-audit/SKILL.md; do
  reject_text "$file" '`general-purpose`' "$file still requires a general-purpose worker type"
  reject_text "$file" 'Skill tool' "$file still requires a harness-specific Skill tool"
done

for skill in ci-cd docker; do
  if frontmatter_has "$ROOT/skills/$skill/SKILL.md" paths; then
    fail "$skill still has non-portable paths frontmatter"
  fi
done

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
reject_trigger command-prompt script
reject_trigger command-prompt completion
reject_trigger databases schema
reject_trigger databases migration
reject_trigger testing spec
reject_trigger kubernetes deployment
reject_trigger kubernetes gateway
reject_trigger frontend-design 'design review'
reject_trigger zero-day CVE
reject_trigger full-review 'run all checks'
reject_trigger full-review 'full check'

require_text skills/localize/SKILL.md "'translate app'" "localize is missing the translate-app alias"
require_text skills/localize/SKILL.md "'multilingual'" "localize is missing the multilingual alias"
require_text skills/localize/SKILL.md "'add language'" "localize is missing the add-language alias"
require_text skills/mcp/SKILL.md "'@modelcontextprotocol/server'" "mcp is missing the current server-package alias"
require_text skills/mcp/SKILL.md "'mcp client'" "mcp is missing the client alias"
require_text skills/arch-btw/SKILL.md "'endeavouros'" "arch-btw is missing the EndeavourOS alias"
require_text skills/arch-btw/SKILL.md "'manjaro'" "arch-btw is missing the Manjaro alias"
require_text skills/virtualization/SKILL.md "'vmware'" "virtualization is missing the VMware alias"
require_text skills/virtualization/SKILL.md "'esxi'" "virtualization is missing the ESXi alias"

printf 'All skill content tests passed.\n'
