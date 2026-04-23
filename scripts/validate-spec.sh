#!/usr/bin/env bash
# shellcheck disable=SC2016,SC1091
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/skill-lib.sh"

# Validate skills against the Agent Skills open standard (agentskills.io/specification).
# Checks naming conventions, required fields, and structural requirements.

SKILLS_DIR="${1:-skills}"
errors=0
warnings=0

error() { echo "  FAIL: $1"; (( errors++ )) || true; }
warn()  { echo "  WARN: $1"; (( warnings++ )) || true; }
pass()  { echo "  OK:   $1"; }

validate_name() {
  local name="$1"
  if [[ ${#name} -gt 64 ]]; then
    error "name '$name' exceeds 64 characters"
    return
  fi
  if [[ "$name" =~ ^- ]] || [[ "$name" =~ -$ ]]; then
    error "name '$name' starts or ends with a hyphen"
    return
  fi
  if [[ "$name" =~ -- ]]; then
    error "name '$name' contains consecutive hyphens"
    return
  fi
  if ! [[ "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    error "name '$name' contains invalid characters (lowercase alphanumeric and hyphens only)"
    return
  fi
}

validate_description() {
  local file="$1" name="$2"
  local desc
  desc="$(frontmatter_get "$file" "description" 2>/dev/null || true)"
  if [[ -z "$desc" ]]; then
    error "$name: description is empty"
    return
  fi
  if [[ ${#desc} -gt 600 ]]; then
    error "$name: description exceeds 600 characters (${#desc})"
  elif [[ ${#desc} -gt 300 ]]; then
    warn "$name: description exceeds Codex-friendly 300 character target (${#desc})"
  fi
}

validate_compatibility() {
  local file="$1" name="$2"
  local compat
  compat="$(frontmatter_get "$file" "compatibility" 2>/dev/null || true)"
  if [[ -n "$compat" && ${#compat} -gt 500 ]]; then
    error "$name: compatibility exceeds 500 characters (${#compat})"
  fi
}

echo "Validating Agent Skills spec compliance in $SKILLS_DIR..."
echo

skill_count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
  git check-ignore -q "$skill_dir" 2>/dev/null && continue

  skill_file="$skill_dir/SKILL.md"
  [[ ! -f "$skill_file" ]] && continue

  echo "[$name]"

  # Spec: name must match directory name
  prev_errors=$errors
  validate_name "$name"

  # Spec: SKILL.md must start with frontmatter
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    error "$name: SKILL.md must start with YAML frontmatter (---)"
  fi

  if ! frontmatter_valid "$skill_file"; then
    error "$name: invalid YAML frontmatter"
    (( skill_count++ )) || true
    continue
  fi

  fm_name="$(frontmatter_get "$skill_file" "name" 2>/dev/null || true)"
  if [[ "$fm_name" != "$name" ]]; then
    error "$name: frontmatter name '$fm_name' does not match directory name"
  fi

  # Spec: required fields
  if ! frontmatter_has "$skill_file" "name"; then
    error "$name: missing required field 'name'"
  fi
  if ! frontmatter_has "$skill_file" "description"; then
    error "$name: missing required field 'description'"
  fi
  if ! frontmatter_has "$skill_file" "license"; then
    error "$name: missing required field 'license'"
  fi

  # Spec: field constraints
  validate_description "$skill_file" "$name"
  validate_compatibility "$skill_file" "$name"

  # Spec: SKILL.md body recommended under 500 lines (soft target, 600 hard max)
  lines=$(wc -l < "$skill_file")
  if (( lines > 600 )); then
    error "$name: SKILL.md is $lines lines (hard max 600)"
  elif (( lines > 500 )); then
    warn "$name: SKILL.md is $lines lines (spec recommends < 500)"
  fi

  if [[ $errors -eq $prev_errors ]]; then
    pass "spec-compliant"
  fi

  (( skill_count++ )) || true
done

echo
echo "────────────────────────────────────────"
echo "Skills validated: $skill_count"
echo "Spec violations:  $errors"
echo "Warnings:         $warnings"
echo "────────────────────────────────────────"

if (( errors > 0 )); then
  echo "FAILED"
  exit 1
else
  echo "PASSED"
  exit 0
fi
