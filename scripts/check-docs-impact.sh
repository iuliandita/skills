#!/usr/bin/env bash
set -euo pipefail

# Offline PR-range docs-impact check (issue #258). Maps authored changes to the
# docs they obligate. It catches review obligations, not prose correctness.
#
#   R1 (hard)  removed/renamed active skill: key in migrations.json at HEAD and
#              a MIGRATION.md change in the range.
#   R2 (hard)  tool removed from install.sh SUPPORTED_TOOLS: an added INSTALL.md
#              line naming it. Changed TOOL_PATHS default for an existing tool:
#              LEGACY_TOOL_PATHS[tool] at HEAD holds the old default.
#   R3         install.sh changed: INSTALL.md or README.md changed.
#   R4         scripts/{check-*,gen-*,lint-*,validate-*} added/deleted:
#              README.md or docs/skill-authoring.md changed.
#   R3/R4 accept a `Docs-Impact: none - <specific reason>` commit trailer in
#   the range. A trailer never satisfies R1 or R2.
#
# Usage: check-docs-impact.sh [base] | --release <prev-tag>
# Base resolution matches check-refiner-phase1-guard.sh: argument, else BASE_REF,
# else merge base with main or origin/main. install.sh is parsed, never sourced.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

release=0
arg_base=""
if [[ "${1:-}" == "--release" ]]; then
  release=1
  arg_base="${2:-}"
  if [[ -z "$arg_base" ]]; then
    echo "ERROR: --release requires a previous tag" >&2
    exit 2
  fi
else
  arg_base="${1:-}"
fi
BASE_REF="${arg_base:-${BASE_REF:-}}"

ref_exists() {
  git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1
}

resolve_base() {
  local candidate
  for candidate in "$@"; do
    if ref_exists "$candidate"; then
      if base="$(git merge-base HEAD "$candidate" 2>/dev/null)"; then
        return 0
      fi
      echo "ERROR: base ref '${candidate}' exists but no merge-base with HEAD could be computed" >&2
      echo "(shallow clone or unrelated history); refusing to fall back to a non-ancestor tip." >&2
      exit 1
    fi
  done
  base=""
}

base=""
if [[ -n "$BASE_REF" ]]; then
  resolve_base "$BASE_REF" "origin/$BASE_REF"
else
  resolve_base main origin/main
fi

if (( release )) && [[ -z "$base" ]]; then
  echo "ERROR: release base tag '${BASE_REF}' does not resolve" >&2
  exit 1
fi

head_sha="$(git rev-parse HEAD)"
if [[ -z "$base" || "$base" == "$head_sha" ]]; then
  echo "No comparable base (base=${base:-none}); docs-impact check skipped."
  exit 0
fi

errors=0
warnings=0
finding() {
  local level="$1" rule="$2" msg="$3"
  if [[ "$level" == warn ]]; then
    warnings=$((warnings + 1))
    printf 'WARN  %s: %s\n' "$rule" "$msg"
  else
    errors=$((errors + 1))
    printf 'ERROR %s: %s\n' "$rule" "$msg"
  fi
}

# status<TAB>path[<TAB>newpath] lines for tracked paths in the range.
changes="$(git diff --name-status -M "$base..HEAD")"
changed_paths="$(git diff --name-only -M "$base..HEAD")"

path_changed() {
  grep -Fxq -- "$1" <<<"$changed_paths"
}

# Trailer: valid only as "none - <specific reason>" (reason >= 20 chars).
valid_trailer=""
while IFS= read -r value; do
  [[ -n "$value" ]] || continue
  [[ "$value" == "none - "* ]] || continue
  reason="${value#none - }"
  reason="${reason#"${reason%%[![:space:]]*}"}"
  reason="${reason%"${reason##*[![:space:]]}"}"
  lowered="$(printf '%s' "${reason%.}" | tr '[:upper:]' '[:lower:]')"
  case "$lowered" in
    none|n/a|na|"no impact"|"docs reviewed"|internal|"not needed"|trivial|refactor) continue ;;
  esac
  (( ${#reason} >= 20 )) || continue
  valid_trailer="$value"
  break
done < <(git log --format='%(trailers:key=Docs-Impact,valueonly)' "$base..HEAD")

soft_level=error
(( release )) && soft_level=warn

satisfied_by_trailer() {
  [[ -n "$valid_trailer" ]]
}

# --- R1 ---------------------------------------------------------------
skill_active_at_base() {
  git show "$base:skills/$1/SKILL.md" 2>/dev/null | awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    /^[[:space:]]+deprecated:[[:space:]]*"?true"?[[:space:]]*$/ { dep = 1 }
    END { exit dep ? 1 : 0 }'
}

removed_skills=()
while IFS=$'\t' read -r status old _; do
  [[ -n "$status" ]] || continue
  case "$status" in D|R*) ;; *) continue ;; esac
  [[ "$old" =~ ^skills/([^/]+)/SKILL\.md$ ]] || continue
  name="${BASH_REMATCH[1]}"
  skill_active_at_base "$name" || continue
  removed_skills+=("$name")
  if ! git show "HEAD:migrations.json" 2>/dev/null | python3 -c '
import json, sys
sys.exit(0 if sys.argv[1] in json.load(sys.stdin).get("skills", {}) else 1)' "$name" 2>/dev/null; then
    finding error R1 "active skill '${name}' removed/renamed ($old) without a migrations.json entry"
  fi
  if ! path_changed MIGRATION.md; then
    finding error R1 "active skill '${name}' removed/renamed ($old) without a MIGRATION.md change in the range"
  fi
done <<<"$changes"

if (( release )) && (( ${#removed_skills[@]} > 0 )); then
  changelog_added="$(git diff "$base..HEAD" -- CHANGELOG.md | grep '^+' | grep -v '^+++' || true)"
  for name in "${removed_skills[@]}"; do
    if ! grep -Fq -- "$name" <<<"$changelog_added"; then
      finding error R1 "removed/renamed skill '${name}' is not mentioned in the CHANGELOG.md diff"
    fi
  done
fi

# --- R2 ---------------------------------------------------------------
supported_tools() {
  awk '
    /^SUPPORTED_TOOLS=\(/ { on = 1; next }
    on && /^\)/ { exit }
    on { sub(/#.*/, ""); for (i = 1; i <= NF; i++) print $i }'
}

# Emits "tool<TAB>default" from `[tool]="${VAR:-default}"` lines of TOOL_PATHS.
tool_path_defaults() {
  awk '
    /^declare -A TOOL_PATHS=\(/ { on = 1; next }
    on && /^\)/ { exit }
    on && /^[[:space:]]*\[[A-Za-z0-9_-]+\]=/ {
      line = $0
      sub(/^[[:space:]]*\[/, "", line)
      tool = line; sub(/\].*/, "", tool)
      if (index(line, ":-") == 0) next
      def = line; sub(/^[^:]*:-/, "", def); sub(/\}"[[:space:]]*$/, "", def)
      print tool "\t" def
    }'
}

# Emits "tool<TAB>value" from LEGACY_TOOL_PATHS.
legacy_paths() {
  awk '
    /^declare -A LEGACY_TOOL_PATHS=\(/ { on = 1; next }
    on && /^\)/ { exit }
    on && /^[[:space:]]*\[[A-Za-z0-9_-]+\]=/ {
      line = $0
      sub(/^[[:space:]]*\[/, "", line)
      tool = line; sub(/\].*/, "", tool)
      val = line; sub(/^[^=]*=/, "", val); gsub(/^"|"[[:space:]]*$/, "", val)
      print tool "\t" val
    }'
}

if git cat-file -e "$base:install.sh" 2>/dev/null && git cat-file -e "HEAD:install.sh" 2>/dev/null; then
  base_install="$(git show "$base:install.sh")"
  head_install="$(git show "HEAD:install.sh")"

  base_tools="$(supported_tools <<<"$base_install")"
  head_tools="$(supported_tools <<<"$head_install")"
  install_added="$(git diff "$base..HEAD" -- INSTALL.md | grep '^+' | grep -v '^+++' || true)"
  while IFS= read -r tool; do
    [[ -n "$tool" ]] || continue
    grep -Fxq -- "$tool" <<<"$head_tools" && continue
    if ! grep -Fwiq -- "$tool" <<<"$install_added"; then
      finding error R2 "tool '${tool}' removed from SUPPORTED_TOOLS (install.sh) without an added INSTALL.md line mentioning it"
    fi
  done <<<"$base_tools"

  base_defaults="$(tool_path_defaults <<<"$base_install")"
  head_defaults="$(tool_path_defaults <<<"$head_install")"
  head_legacy="$(legacy_paths <<<"$head_install")"
  while IFS=$'\t' read -r tool old_default; do
    [[ -n "$tool" ]] || continue
    new_default="$(awk -F'\t' -v t="$tool" '$1 == t { print $2; exit }' <<<"$head_defaults")"
    [[ -n "$new_default" && "$new_default" != "$old_default" ]] || continue
    legacy="$(awk -F'\t' -v t="$tool" '$1 == t { print $2; exit }' <<<"$head_legacy")"
    if [[ -z "$legacy" || "$legacy" != *"$old_default"* ]]; then
      finding error R2 "TOOL_PATHS default for '${tool}' changed from '${old_default}' but LEGACY_TOOL_PATHS[${tool}] does not hold the old default (install.sh)"
    fi
  done <<<"$base_defaults"
fi

# --- R3 ---------------------------------------------------------------
if path_changed install.sh; then
  if ! path_changed INSTALL.md && ! path_changed README.md && ! satisfied_by_trailer; then
    finding "$soft_level" R3 "install.sh changed without an INSTALL.md or README.md change (or a valid 'Docs-Impact: none - <reason>' trailer)"
  fi
fi

# --- R4 ---------------------------------------------------------------
tooling=()
while IFS=$'\t' read -r status p1 p2; do
  [[ -n "$status" ]] || continue
  case "$status" in
    A) paths=("$p1") ;;
    D) paths=("$p1") ;;
    R*) paths=("$p1" "$p2") ;;
    *) continue ;;
  esac
  for p in "${paths[@]}"; do
    case "$p" in
      scripts/check-*.sh|scripts/gen-*|scripts/lint-*|scripts/validate-*) tooling+=("$p") ;;
    esac
  done
done <<<"$changes"

if (( ${#tooling[@]} > 0 )); then
  if ! path_changed README.md && ! path_changed docs/skill-authoring.md && ! satisfied_by_trailer; then
    finding "$soft_level" R4 "gate scripts added/removed (${tooling[*]}) without a README.md or docs/skill-authoring.md change (or a valid trailer)"
  fi
fi

if (( errors > 0 )); then
  echo
  echo "Docs-impact check failed ($errors finding(s)). Update the docs named above, or for R3/R4 add a"
  echo "'Docs-Impact: none - <specific reason, 20+ chars>' trailer to a commit in the range."
  exit 1
fi

echo "docs-impact check OK ($base..HEAD, ${warnings} warning(s))."
