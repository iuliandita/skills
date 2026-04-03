#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

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
PRIVATE_SKILLS=(cluster-health)

# ── Private skill reference check ──────────────────────────────────────
check_private_refs() {
  local file="$1" name="$2"
  for priv in "${PRIVATE_SKILLS[@]}"; do
    [[ "$name" == "$priv" ]] && continue  # private skill can reference itself
    if grep -q "\\b${priv}\\b" "$file" 2>/dev/null; then
      error "$name: references private skill '$priv' (public skills must not reference private skills)"
    fi
  done
}

# ── Frontmatter checks ─────────────────────────────────────────────────
check_frontmatter() {
  local file="$1" name="$2"

  # Extract frontmatter block (between first --- and second ---)
  local fm
  fm=$(sed -n '2,/^---$/{ /^---$/d; p; }' "$file")

  # Required top-level fields (Agent Skills spec)
  for field in name description license; do
    if ! echo "$fm" | grep -q "^${field}:"; then
      error "$name: missing frontmatter field '$field'"
    fi
  done

  # Required metadata fields (custom, nested under metadata:)
  if ! echo "$fm" | grep -q '^metadata:'; then
    error "$name: missing 'metadata:' block"
  fi
  for field in source date_added effort; do
    if ! echo "$fm" | grep -q "^  ${field}:"; then
      error "$name: missing metadata field '$field'"
    fi
  done

  local src
  src=$(echo "$fm" | grep -m1 '^  source:' 2>/dev/null | sed 's/.*source: *//' || true)
  if [[ -z "$src" ]]; then
    error "$name: metadata.source is empty"
  elif [[ "$src" != "custom" && ! "$src" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
    error "$name: metadata.source must be 'custom' or 'owner/repo' format, got '$src'"
  fi

  local eff
  eff=$(echo "$fm" | grep -m1 '^  effort:' 2>/dev/null | sed 's/.*effort: *//' || true)
  if [[ "$eff" != "low" && "$eff" != "medium" && "$eff" != "high" ]]; then
    error "$name: metadata.effort must be low/medium/high, got '$eff'"
  fi

  # Optional: metadata.argument_hint (string, max 100 chars)
  local arg_hint
  arg_hint=$(echo "$fm" | grep -m1 '^  argument_hint:' 2>/dev/null | sed 's/.*argument_hint: *//' || true)
  if [[ -n "$arg_hint" && ${#arg_hint} -gt 100 ]]; then
    error "$name: metadata.argument_hint exceeds 100 characters"
  fi

  # Optional: metadata.internal (boolean)
  local internal
  internal=$(echo "$fm" | grep -m1 '^  internal:' 2>/dev/null | sed 's/.*internal: *//' || true)
  if [[ -n "$internal" && "$internal" != "true" && "$internal" != "false" ]]; then
    error "$name: metadata.internal must be true or false, got '$internal'"
  fi

  # Validate name matches directory (Agent Skills spec requirement)
  local fm_name
  fm_name=$(echo "$fm" | grep -m1 '^name:' 2>/dev/null | sed 's/name: *//' || true)
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
      stripped=$(echo "$line" | perl -CSD -pe 's/[\x{1F534}\x{1F7E2}\x{1F7E1}\x{1F535}\x{26A1}\x{1F3AF}\x{1F480}]//g' 2>/dev/null || echo "$line")
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
    # Skip the conventions file (it lists banned words as examples)
    [[ "$(basename "$f")" == "conventions.md" ]] && continue
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

# ── AI Self-Check section check ────────────────────────────────────────
check_ai_self_check() {
  local file="$1" name="$2"
  local effort
  effort=$(sed -n '2,/^---$/p' "$file" | grep -m1 'effort:' | sed 's/.*effort: *//' || true)
  if [[ "$effort" == "high" ]]; then
    if ! grep -qi '^## .*Self.Check' "$file"; then
      warn "$name: high-effort skill without 'AI Self-Check' section (recommended for skills that generate output)"
    fi
  fi
}

# ── Main ────────────────────────────────────────────────────────────────
echo "Linting skills in $SKILLS_DIR..."
echo

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
  check_sections "$skill_file" "$name"
  check_ascii "$skill_file" "$name"
  check_length "$skill_file" "$name"
  check_references "$skill_file" "$name" "$skill_dir"
  check_private_refs "$skill_file" "$name"
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
