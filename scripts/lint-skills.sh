#!/usr/bin/env bash
# shellcheck disable=SC2016,SC1091
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/skill-lib.sh"

# Lint all skills in the collection for common issues.
# Runs in CI and locally. Exit 0 = clean, exit 1 = issues found.
# SC2016: grep patterns use single-quoted backticks intentionally.

SKILLS_DIR="${1:-skills}"
errors=0
warnings=0

error() { echo "  ERROR: $1"; (( errors++ )) || true; }
warn()  { echo "  WARN:  $1"; (( warnings++ )) || true; }

# Private skills: present locally (gitignored) but must not be referenced
# by public skills. They can reference public skills freely.
PRIVATE_SKILLS=()

# ── Private skill reference check ──────────────────────────────────────
check_private_refs() {
  local dir="$1" name="$2"
  for priv in "${PRIVATE_SKILLS[@]}"; do
    [[ "$name" == "$priv" ]] && continue  # private skill can reference itself
    for f in "$dir"/SKILL.md "$dir"/references/*.md; do
      [[ -f "$f" ]] || continue
      if grep -q "\\b${priv}\\b" "$f" 2>/dev/null; then
        error "$name: references private skill '$priv' in $(basename "$f") (public skills must not reference private skills)"
      fi
    done
  done
}

# ── Frontmatter checks ─────────────────────────────────────────────────
check_frontmatter() {
  local file="$1" name="$2"
  if ! frontmatter_valid "$file"; then
    error "$name: invalid YAML frontmatter"
    return
  fi

  # Required top-level fields (Agent Skills spec)
  for field in name description license; do
    if ! frontmatter_has "$file" "$field"; then
      error "$name: missing frontmatter field '$field'"
    fi
  done

  # Required metadata fields (custom, nested under metadata:)
  if ! frontmatter_has "$file" "metadata"; then
    error "$name: missing 'metadata:' block"
  fi
  for field in source date_added effort; do
    if ! frontmatter_has "$file" "metadata.$field"; then
      error "$name: missing metadata field '$field'"
    fi
  done

  local src
  src="$(frontmatter_get "$file" "metadata.source" 2>/dev/null || true)"
  if [[ -z "$src" ]]; then
    error "$name: metadata.source is empty"
  elif [[ "$src" != "custom" && ! "$src" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
    error "$name: metadata.source must be 'custom' or 'owner/repo' format, got '$src'"
  fi

  local eff
  eff="$(frontmatter_get "$file" "metadata.effort" 2>/dev/null || true)"
  if [[ "$eff" != "low" && "$eff" != "medium" && "$eff" != "high" ]]; then
    error "$name: metadata.effort must be low/medium/high, got '$eff'"
  fi

  # Optional: metadata.argument_hint (string, max 100 chars)
  local arg_hint
  arg_hint="$(frontmatter_get "$file" "metadata.argument_hint" 2>/dev/null || true)"
  if [[ -n "$arg_hint" && ${#arg_hint} -gt 100 ]]; then
    error "$name: metadata.argument_hint exceeds 100 characters"
  fi

  # Optional: metadata.internal (boolean)
  local internal
  internal="$(frontmatter_get "$file" "metadata.internal" 2>/dev/null || true)"
  if [[ -n "$internal" && "$internal" != "true" && "$internal" != "false" ]]; then
    error "$name: metadata.internal must be true or false, got '$internal'"
  fi

  # Validate name matches directory (Agent Skills spec requirement)
  local fm_name
  fm_name="$(frontmatter_get "$file" "name" 2>/dev/null || true)"
  if [[ "$fm_name" != "$name" ]]; then
    error "$name: frontmatter name '$fm_name' does not match directory name"
  fi
}

# ── Section checks ──────────────────────────────────────────────────────
check_sections() {
  local file="$1" name="$2"
  for section in "When to use" "When NOT to use" "Workflow" "Rules"; do
    if ! grep -qi "^## .*${section}" "$file"; then
      error "$name: missing '## $section' section"
    fi
  done
}

# ── ASCII checks ────────────────────────────────────────────────────────
check_ascii() {
  local file="$1" name="$2"
  local bad_lines
  bad_lines=$(grep -Pn '[^\x00-\x7F]' "$file" 2>/dev/null || true)
  if [[ -n "$bad_lines" ]]; then
    while IFS= read -r line; do
      # Strip allowed emoji status indicators, then check for remaining non-ASCII
      local stripped
      stripped=$(echo "$line" | perl -CSD -pe 's/[\x{00B7}\x{1F534}\x{1F7E2}\x{1F7E1}\x{1F535}\x{26A1}\x{1F3AF}\x{1F480}]//g' 2>/dev/null || echo "$line")
      if echo "$stripped" | grep -Pq '[^\x00-\x7F]' 2>/dev/null; then
        error "$name: non-ASCII character at $line"
      fi
    done <<< "$bad_lines"
  fi
}

# ── Line count check ───────────────────────────────────────────────────
check_length() {
  local file="$1" name="$2"
  local lines
  lines=$(wc -l < "$file")
  if (( lines > 600 )); then
    error "$name: SKILL.md is $lines lines (hard max 600)"
  elif (( lines > 500 )); then
    warn "$name: SKILL.md is $lines lines (target <500, extract to references/ if possible)"
  fi
}

# ── Reference file checks ──────────────────────────────────────────────
check_references() {
  local file="$1" name="$2" dir="$3"
  # Check that referenced files exist (only in own references/ dir)
  # Skip template examples (e.g., references/<topic-file>) and
  # cross-skill references (lines mentioning other skill names)
  local refs
  refs=$(grep -oP '`references/[^`]+`' "$file" | sed "s/\`//g" || true)
  for ref in $refs; do
    # Skip template placeholders
    [[ "$ref" == *"<"* ]] && continue
    if [[ ! -f "$dir/$ref" ]]; then
      # Check if this line mentions another skill (cross-reference)
      local line
      line=$(grep -F "$ref" "$file" | head -1)
      if echo "$line" | grep -qP '\*\*[a-z][-a-z0-9]+\*\*'; then
        continue  # cross-skill reference, not a local file
      fi
      error "$name: referenced file '$ref' does not exist"
    fi
  done
}

# ── Banned word check (warning only) ──────────────────────────────────
BANNED_WORDS=(delve tapestry nuanced multifaceted utilize commence facilitate synergy leverage holistic empower seamless innovative)

check_banned_words() {
  local dir="$1" name="$2"
  for f in "$dir"/SKILL.md "$dir"/references/*.md; do
    [[ -f "$f" ]] || continue
    # Skip files that legitimately catalog banned words as examples.
    # - skill-creator's conventions.md lists the banned vocabulary
    # - anti-ai-prose is the meta-reference for AI prose tells and must name them
    [[ "$(basename "$f")" == "conventions.md" ]] && continue
    [[ "$name" == "anti-ai-prose" ]] && continue
    local basename_f
    basename_f=$(basename "$f")
    for word in "${BANNED_WORDS[@]}"; do
      # Word-boundary match, case-insensitive, skip fenced code blocks
      local matches
      matches=$(awk '/^```/{skip=!skip; next} !skip{print NR": "$0}' "$f" | grep -i "\\b${word}\\b" || true)
      if [[ -n "$matches" ]]; then
        warn "$name: banned word '$word' in $basename_f"
      fi
    done
  done
}

# ── Description prefix check ───────────────────────────────────────────
# Collection convention (CLAUDE.md): every public skill description starts
# with '·' (U+00B7 MIDDLE DOT) for visual identification in skill lists.
# Internal skills are exempt (they're not listed to users the same way).
check_desc_prefix() {
  local file="$1" name="$2"
  local internal
  internal="$(frontmatter_get "$file" "metadata.internal" 2>/dev/null || true)"
  [[ "$internal" == "true" ]] && return

  local desc
  desc="$(frontmatter_get "$file" "description" 2>/dev/null || true)"
  [[ -z "$desc" ]] && return  # missing-description error already reported

  # Must start with '·' followed by a space
  if [[ "$desc" != "· "* ]]; then
    error "$name: description must start with '· ' (middle dot + space) per collection convention"
  fi
}

# ── AI Self-Check section check ────────────────────────────────────────
check_ai_self_check() {
  local file="$1" name="$2"
  local effort
  effort="$(frontmatter_get "$file" "metadata.effort" 2>/dev/null || true)"
  if [[ "$effort" == "high" ]]; then
    if ! grep -qi '^## .*Self.Check' "$file"; then
      warn "$name: high-effort skill without 'AI Self-Check' section (recommended for skills that generate output)"
    fi
  fi
}

# ── Collection-wide symlink check ──────────────────────────────────────
# Reject committed symlinks under skills/. install.sh's skill_hash uses
# `find` without -L so symlinks are no longer followed, but a committed
# symlink would still confuse downstream tooling. See SECURITY-AUDIT.md
# SEC-007.
check_no_symlinks() {
  local dir="$1"
  local found
  found="$(find "$dir" -type l -print 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    while IFS= read -r link; do
      error "symlink committed under $dir: $link (skills must contain only regular files)"
    done <<< "$found"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────
echo "Linting skills in $SKILLS_DIR..."
echo

check_no_symlinks "$SKILLS_DIR"

skill_count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
  git check-ignore -q "$skill_dir" 2>/dev/null && continue

  skill_file="$skill_dir/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    error "$name: no SKILL.md found"
    continue
  fi

  echo "[$name]"
  check_frontmatter "$skill_file" "$name"
  check_desc_prefix "$skill_file" "$name"
  check_sections "$skill_file" "$name"
  check_ascii "$skill_file" "$name"
  check_length "$skill_file" "$name"
  check_references "$skill_file" "$name" "$skill_dir"
  check_private_refs "$skill_dir" "$name"
  check_ai_self_check "$skill_file" "$name"
  check_banned_words "$skill_dir" "$name"
  (( skill_count++ )) || true
done

echo
echo "────────────────────────────────────────"
echo "Skills checked: $skill_count"
echo "Errors:         $errors"
echo "Warnings:       $warnings"
echo "────────────────────────────────────────"

if (( errors > 0 )); then
  echo "FAILED"
  exit 1
else
  echo "PASSED"
  exit 0
fi
