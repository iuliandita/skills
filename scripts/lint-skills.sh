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
  for field in name description source date_added effort; do
    if ! grep -q "^${field}:" "$file"; then
      error "$name: missing frontmatter field '$field'"
    fi
  done

  local src
  src=$(grep -m1 '^source:' "$file" 2>/dev/null | sed 's/source: *//' || true)
  if [[ "$src" != "custom" ]]; then
    error "$name: source must be 'custom', got '$src'"
  fi

  local eff
  eff=$(grep -m1 '^effort:' "$file" 2>/dev/null | sed 's/effort: *//' || true)
  if [[ "$eff" != "low" && "$eff" != "medium" && "$eff" != "high" ]]; then
    error "$name: effort must be low/medium/high, got '$eff'"
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
      # Allow emoji status indicators (they're functional, not decorative)
      if echo "$line" | grep -Pq '[\x{1F534}\x{1F7E2}\x{1F7E1}\x{1F535}\x{26A1}\x{1F3AF}\x{1F480}]' 2>/dev/null; then
        continue
      fi
      error "$name: non-ASCII character at $line"
    done <<< "$bad_lines"
  fi
}

# ── Line count check ───────────────────────────────────────────────────
check_length() {
  local file="$1" name="$2"
  local lines
  lines=$(wc -l < "$file")
  if (( lines > 500 )); then
    error "$name: SKILL.md is $lines lines (max 500)"
  elif (( lines > 450 )); then
    warn "$name: SKILL.md is $lines lines (approaching 500 limit)"
  fi
}

# ── Cross-reference checks ─────────────────────────────────────────────
check_crossrefs() {
  local file="$1" name="$2"
  # Extract skill names from bold references like **skill-name**
  local refs
  refs=$(grep -oP '\*\*([a-z][-a-z0-9]*)\*\*' "$file" | sed 's/\*//g' | sort -u || true)
  for ref in $refs; do
    # Skip common bold words that aren't skill references
    case "$ref" in
      name|description|source|effort|yes|no|not|all|none|note|warning|error|target|rule*) continue ;;
    esac
    if [[ -d "$SKILLS_DIR/$ref" ]]; then
      : # valid reference
    fi
    # Don't error on unknown bold words -- too many false positives
  done
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

# ── Main ────────────────────────────────────────────────────────────────
echo "Linting skills in $SKILLS_DIR..."
echo

skill_count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue

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
  check_crossrefs "$skill_file" "$name"
  check_references "$skill_file" "$name" "$skill_dir"
  check_private_refs "$skill_file" "$name"
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
