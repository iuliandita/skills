#!/usr/bin/env bash
set -euo pipefail

# Verify version-pin receipts: skills/*/references/versions.md.
#
# Each file carries YAML frontmatter (checked_at, checked_by, pins: [...]).
# This script fails a skill's receipt if:
#   - checked_at is missing or not YYYY-MM-DD
#   - checked_at is older than the staleness budget (default 120 days)
#   - any pins: entry is missing tool, version, or source
#   - any pins: entry's source is not an https:// URL
#
# See docs/version-pins.md for the contract. Nothing to check (no
# versions.md anywhere) is success, not an error.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$ROOT/skills}"
MAX_AGE_DAYS="${SKILLS_PIN_MAX_AGE_DAYS:-120}"

fail=0

# Parse frontmatter of a versions.md file into machine-readable lines:
#   CHECKED_AT=<value>
#   CHECKED_BY=<value>
#   PIN<n>_TOOL=<value>
#   PIN<n>_VERSION=<value>
#   PIN<n>_SOURCE=<value>
# Values have surrounding quotes stripped. Malformed frontmatter (no closing
# fence) yields no output, which the caller treats as a validation failure.
parse_frontmatter() {
  awk '
    function strip(v) {
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^".*"$/) { v = substr(v, 2, length(v) - 2) }
      return v
    }
    function shquote(v) {
      gsub(/\\/, "\\\\", v)
      gsub(/"/, "\\\"", v)
      gsub(/\$/, "\\$", v)
      gsub(/`/, "\\`", v)
      return "\"" v "\""
    }
    function emit(key, v) { print key "=" shquote(strip(v)) }
    BEGIN { fence = 0; in_pins = 0; pin_i = 0 }
    NR == 1 && $0 == "---" { fence = 1; next }
    fence == 1 && $0 == "---" { fence = 2; next }
    fence != 1 { next }
    /^checked_at:[ \t]*/ {
      v = $0; sub(/^checked_at:[ \t]*/, "", v)
      emit("CHECKED_AT", v)
      in_pins = 0
      next
    }
    /^checked_by:[ \t]*/ {
      v = $0; sub(/^checked_by:[ \t]*/, "", v)
      emit("CHECKED_BY", v)
      in_pins = 0
      next
    }
    /^pins:[ \t]*$/ { in_pins = 1; next }
    in_pins && /^[a-zA-Z_]+:/ { in_pins = 0 }
    in_pins && /^[ \t]*-[ \t]*tool:[ \t]*/ {
      pin_i++
      v = $0; sub(/^[ \t]*-[ \t]*tool:[ \t]*/, "", v)
      emit("PIN" pin_i "_TOOL", v)
      next
    }
    in_pins && /^[ \t]+version:[ \t]*/ {
      v = $0; sub(/^[ \t]+version:[ \t]*/, "", v)
      emit("PIN" pin_i "_VERSION", v)
      next
    }
    in_pins && /^[ \t]+source:[ \t]*/ {
      v = $0; sub(/^[ \t]+source:[ \t]*/, "", v)
      emit("PIN" pin_i "_SOURCE", v)
      next
    }
    END { print "PIN_COUNT=" pin_i }
  ' "$1"
}

# Portable day count from a YYYY-MM-DD date to now. Tries GNU date first
# (the CI runner, ubuntu-24.04, has it), falls back to BSD date for local
# macOS use.
days_since() {
  local date_str="$1" then_epoch now_epoch
  now_epoch="$(date -u +%s)"
  if then_epoch="$(date -u -d "$date_str" +%s 2>/dev/null)"; then
    :
  elif then_epoch="$(date -u -j -f '%Y-%m-%d' "$date_str" +%s 2>/dev/null)"; then
    :
  else
    return 1
  fi
  echo $(( (now_epoch - then_epoch) / 86400 ))
}

mapfile -t receipt_files < <(find "$SKILLS_ROOT" -type f -path '*/references/versions.md' 2>/dev/null | sort)

if (( ${#receipt_files[@]} == 0 )); then
  printf 'Version receipts OK: no skills carry references/versions.md yet.\n'
  exit 0
fi

skill_count=0
oldest_date=""

for file in "${receipt_files[@]}"; do
  rel="${file#"$SKILLS_ROOT"/}"
  skill="${rel%%/references/versions.md}"

  eval "$(parse_frontmatter "$file")"

  if [[ -z "${CHECKED_AT:-}" ]]; then
    printf '[!] %s: missing checked_at in frontmatter\n' "$skill" >&2
    fail=1
    continue
  fi

  if [[ ! "$CHECKED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '[!] %s: checked_at %q is not YYYY-MM-DD\n' "$skill" "$CHECKED_AT" >&2
    fail=1
    continue
  fi

  age_days="$(days_since "$CHECKED_AT")" || {
    printf '[!] %s: could not parse checked_at date %q\n' "$skill" "$CHECKED_AT" >&2
    fail=1
    continue
  }

  if (( age_days > MAX_AGE_DAYS )); then
    printf '[!] %s: checked_at %s is %d days old (budget %d days) - re-verify pins or remove them\n' \
      "$skill" "$CHECKED_AT" "$age_days" "$MAX_AGE_DAYS" >&2
    fail=1
  fi

  pin_count="${PIN_COUNT:-0}"
  if (( pin_count == 0 )); then
    printf '[!] %s: pins: has no entries\n' "$skill" >&2
    fail=1
  fi

  for (( i = 1; i <= pin_count; i++ )); do
    tool_var="PIN${i}_TOOL"
    version_var="PIN${i}_VERSION"
    source_var="PIN${i}_SOURCE"
    tool="${!tool_var:-}"
    version="${!version_var:-}"
    source="${!source_var:-}"

    if [[ -z "$tool" || -z "$version" || -z "$source" ]]; then
      printf '[!] %s: pins[%d] is missing tool, version, or source\n' "$skill" "$i" >&2
      fail=1
      continue
    fi

    if [[ "$source" != https://* ]]; then
      printf '[!] %s: pins[%d] (%s) source %q is not an https:// URL\n' "$skill" "$i" "$tool" "$source" >&2
      fail=1
    fi
  done

  skill_count=$((skill_count + 1))
  if [[ -z "$oldest_date" || "$CHECKED_AT" < "$oldest_date" ]]; then
    oldest_date="$CHECKED_AT"
  fi

  unset CHECKED_AT CHECKED_BY PIN_COUNT
  for (( i = 1; i <= pin_count; i++ )); do
    unset "PIN${i}_TOOL" "PIN${i}_VERSION" "PIN${i}_SOURCE"
  done
done

if (( fail )); then
  printf '\nVersion receipt check failed.\n' >&2
  exit 1
fi

printf 'Version receipts OK: %d skill(s), oldest check %s.\n' "$skill_count" "$oldest_date"
