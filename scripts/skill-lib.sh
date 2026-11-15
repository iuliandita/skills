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

# Succeed when a frontmatter flag is boolean true or a string that trims and
# case-folds to "true". The rule itself is skill-frontmatter.py flag(); this
# only asks it, through the cache when the caller preloaded "flag:<path>".
# Args: <file> <path>
frontmatter_flag() {
  local file="$1" path="$2"
  _fm_key "$file"
  if [[ -n "${FM_CACHE_HAS[$FM_KEY|flag:$path]+x}" ]]; then
    [[ "${FM_CACHE_VALUE[$FM_KEY|flag:$path]}" == true ]]
    return
  fi
  python3 "$FRONTMATTER_PY" flag "$file" "$path"
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

# Check SKILL.md length against the shared thresholds (>500 error, >450 warn).
# 500 matches the Agent Skills authoring guidance for the always-loaded body.
# Args: <skill_file> <dir_name> <error_fn> <warn_fn> <warn_message>
# The warn message differs per caller, so it is passed in. The error message is
# identical across callers and lives here.
skill_length_check() {
  local file="$1" dir_name="$2" error_fn="$3" warn_fn="$4" warn_message="$5"
  local lines
  lines=$(wc -l < "$file")
  if (( lines > 500 )); then
    "$error_fn" "$dir_name: SKILL.md is $lines lines (hard max 500)"
  elif (( lines > 450 )); then
    "$warn_fn" "$warn_message"
  fi
}

# The one skill-folder loop: names under <skills_dir>, one per line, sorted.
# With no switch it lists public skills. A public skill has a SKILL.md, is not
# a dot or underscore directory, is not git-ignored (it needs a tracked or
# untracked-but-not-ignored file: a retired skill can leave only an ignored
# private overlay behind), and is not a deprecated notice. Opt-in
# (metadata.internal) skills are public: they are still published.
# Each switch drops one filter:
#   --include-deprecated  deprecated notices are listed too
#   --include-gitignored  the two git filters are skipped
#   --include-missing     folders without a SKILL.md are listed too
# Git is asked from <skills_dir>, so the caller's working directory does not
# matter; outside a git repo nothing counts as ignored. install.sh keeps its
# own discover_skills (see the comment there).
# Args: <skills_dir> [switch...]
list_public_skills() {
  local root="$1" with_deprecated=0 with_gitignored=0 with_missing=0
  local abs_root skill_dir name visible_files
  shift
  while (( $# )); do
    case "$1" in
      --include-deprecated) with_deprecated=1 ;;
      --include-gitignored) with_gitignored=1 ;;
      --include-missing) with_missing=1 ;;
      *)
        printf 'list_public_skills: unknown switch %s\n' "$1" >&2
        return 2
        ;;
    esac
    shift
  done
  abs_root="$(cd "$root" 2>/dev/null && pwd)" || return 0
  for skill_dir in "$abs_root"/*/; do
    [[ -d "$skill_dir" ]] || continue
    name="$(basename "$skill_dir")"
    [[ "$name" == .* || "$name" == _* ]] && continue
    if (( ! with_gitignored )); then
      git -C "$abs_root" check-ignore -q "$skill_dir" 2>/dev/null && continue
      if visible_files="$(git -C "$abs_root" ls-files --cached --others --exclude-standard -- "$skill_dir" 2>/dev/null)" \
        && [[ -z "$visible_files" ]]; then
        continue
      fi
    fi
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
      (( with_missing )) && printf '%s\n' "$name"
      continue
    fi
    if (( ! with_deprecated )); then
      frontmatter_flag "$root/$name/SKILL.md" metadata.deprecated && continue
    fi
    printf '%s\n' "$name"
  done | sort
}

# Names in install.sh's SUPPORTED_TOOLS array, one per line. Reads the file
# named by the first argument, or stdin. Tokens may share the opening line and
# the closing parenthesis may sit anywhere; "#" starts a comment.
list_supported_tools() {
  awk '
    /^SUPPORTED_TOOLS=\(/ {f=1; sub(/^SUPPORTED_TOOLS=\(/, "")}
    f {
      sub(/#.*/, "")
      closed = ($0 ~ /\)/)
      sub(/\).*/, "")
      n = split($0, t, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (t[i] != "") print t[i]
      if (closed) exit
    }
  ' "${1:--}"
}
