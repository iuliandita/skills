#!/usr/bin/env bash

SKILL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTMATTER_PY="$SKILL_LIB_DIR/skill-frontmatter.py"

# Optional per-run cache filled by frontmatter_cache_load. Lookups for files
# or fields that were not preloaded fall back to one python call each.
declare -gA FM_CACHE_VALID=()
declare -gA FM_CACHE_HAS=()
declare -gA FM_CACHE_VALUE=()
FM_KEY=""

_fm_key() {
  FM_KEY="$1"
  while [[ "$FM_KEY" == *//* ]]; do
    FM_KEY="${FM_KEY//\/\//\/}"
  done
}

# Parse every <skills_dir>/*/SKILL.md once and cache validity plus the given
# field paths. Args: <skills_dir> <path>...
frontmatter_cache_load() {
  local root="$1"
  shift
  local tmp record_size count i dir path
  local -a rec=()
  tmp="$(mktemp)"
  if ! python3 "$FRONTMATTER_PY" fields "$root" "$@" > "$tmp"; then
    rm -f "$tmp"
    printf 'frontmatter cache: could not read %s\n' "$root" >&2
    return 1
  fi
  mapfile -d '' -t rec < "$tmp"
  rm -f "$tmp"

  record_size=$(( 2 + 2 * $# ))
  count="${#rec[@]}"
  if (( count % record_size != 0 )); then
    printf 'frontmatter cache: malformed records for %s\n' "$root" >&2
    return 1
  fi
  for (( i = 0; i < count; )); do
    dir="${rec[i]}"
    _fm_key "$root/$dir/SKILL.md"
    FM_CACHE_VALID[$FM_KEY]="${rec[i+1]}"
    i=$(( i + 2 ))
    for path in "$@"; do
      FM_CACHE_HAS[$FM_KEY|$path]="${rec[i]}"
      FM_CACHE_VALUE[$FM_KEY|$path]="${rec[i+1]}"
      i=$(( i + 2 ))
    done
  done
}

frontmatter_valid() {
  local file="$1"
  _fm_key "$file"
  if [[ -n "${FM_CACHE_VALID[$FM_KEY]+x}" ]]; then
    [[ "${FM_CACHE_VALID[$FM_KEY]}" == 1 ]]
    return
  fi
  python3 "$FRONTMATTER_PY" valid "$file"
}

frontmatter_get() {
  local file="$1" path="$2"
  _fm_key "$file"
  if [[ -n "${FM_CACHE_HAS[$FM_KEY|$path]+x}" ]]; then
    [[ "${FM_CACHE_HAS[$FM_KEY|$path]}" == 1 ]] || return 1
    printf '%s\n' "${FM_CACHE_VALUE[$FM_KEY|$path]}"
    return 0
  fi
  python3 "$FRONTMATTER_PY" get "$file" "$path"
}

frontmatter_has() {
  local file="$1" path="$2"
  _fm_key "$file"
  if [[ -n "${FM_CACHE_HAS[$FM_KEY|$path]+x}" ]]; then
    [[ "${FM_CACHE_HAS[$FM_KEY|$path]}" == 1 ]]
    return
  fi
  python3 "$FRONTMATTER_PY" has "$file" "$path"
}

# Check that frontmatter `name` matches the directory name.
# Args: <skill_file> <dir_name> <error_fn>
# Calls <error_fn> with the standard message on mismatch.
frontmatter_name_matches_dir() {
  local file="$1" dir_name="$2" error_fn="$3"
  local fm_name
  fm_name="$(frontmatter_get "$file" "name" 2>/dev/null || true)"
  if [[ "$fm_name" != "$dir_name" ]]; then
    "$error_fn" "$dir_name: frontmatter name '$fm_name' does not match directory name"
  fi
}

# Check SKILL.md length against the shared thresholds (>600 error, >500 warn).
# Args: <skill_file> <dir_name> <error_fn> <warn_fn> <warn_message>
# The warn message differs per caller, so it is passed in. The error message is
# identical across callers and lives here.
skill_length_check() {
  local file="$1" dir_name="$2" error_fn="$3" warn_fn="$4" warn_message="$5"
  local lines
  lines=$(wc -l < "$file")
  if (( lines > 600 )); then
    "$error_fn" "$dir_name: SKILL.md is $lines lines (hard max 600)"
  elif (( lines > 500 )); then
    "$warn_fn" "$warn_message"
  fi
}
