#!/usr/bin/env bash

SKILL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTMATTER_PY="$SKILL_LIB_DIR/skill-frontmatter.py"

frontmatter_valid() {
  local file="$1"
  python3 "$FRONTMATTER_PY" valid "$file"
}

frontmatter_get() {
  local file="$1" path="$2"
  python3 "$FRONTMATTER_PY" get "$file" "$path"
}

frontmatter_has() {
  local file="$1" path="$2"
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
