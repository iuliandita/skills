#!/usr/bin/env bash
set -Eeuo pipefail

# Check that currentness markers in tracked docs name the collection month.
#
# Exit codes:
#   0   every marker is current
#   10  stale markers only (the advisory wrappers downgrade this one code)
#   1   anything else: the tracked-file listing failed, a file could not be
#       read, a command failed. A run with both a broken and a stale input
#       exits 1.
STALE_EXIT=10
trap 'exit 1' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The markers are written with English month names, whatever the caller's locale.
FRESHNESS_LABEL="${SKILLS_FRESHNESS_LABEL:-$(LC_ALL=C date +'%B %Y')}"

if ! tracked="$(git -C "$ROOT" ls-files)"; then
  printf 'error: could not list tracked files in %s\n' "$ROOT" >&2
  exit 1
fi

mapfile -t files < <(
  printf '%s\n' "$tracked" \
    | grep -E '^(skills/.*|README|INSTALL)[.]md$' \
    | grep -vE '^skills/(cluster-health|kubernetes-health)/protected/' || true
)

errors=0

stale_claim_re='(as of|verified|recheck|snapshot|current as of|Pinned to|Reviewed|Updated for|Research preview context|Key facts \(|Skill Inventory \(|Target versions|Versions worth pinning)'
freshness_line_re='(^\*\*Target versions|^\*\*Versions worth pinning|^#+ .*Target versions|^#+ .*Versions worth pinning|Reviewed [A-Z][a-z]+ 20[0-9]{2}|Updated for .*[A-Z][a-z]+ 20[0-9]{2}|Research preview context|Key facts \([A-Z][a-z]+ 20[0-9]{2}\)|Skill Inventory \([A-Z][a-z]+ 20[0-9]{2}\)|current as of|as of [A-Z][a-z]+ 20[0-9]{2}|verified [A-Z][a-z]+ 20[0-9]{2}|[A-Z][a-z]+ 20[0-9]{2} recheck|[A-Z][a-z]+ 20[0-9]{2} snapshot|Pinned to [A-Z][a-z]+ 20[0-9]{2})'

# A skill that has migrated to a version-receipt file (references/versions.md,
# see docs/version-pins.md) is verified by scripts/check-version-receipts.sh
# instead. Its month-label marker, if any is still present in prose, is no
# longer the freshness signal for that skill - skip it here rather than
# demanding both mechanisms agree.
skill_of() {
  local file="$1"
  if [[ "$file" =~ ^skills/([^/]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

has_version_receipt() {
  local skill="$1"
  [[ -n "$skill" && -s "$ROOT/skills/$skill/references/versions.md" ]]
}

declare -A noted_skills

for file in "${files[@]}"; do
  path="$ROOT/$file"
  [[ -f "$path" ]] || continue

  skill="$(skill_of "$file")"
  if has_version_receipt "$skill"; then
    if [[ -z "${noted_skills[$skill]:-}" ]]; then
      printf 'note: %s uses version receipts; label check skipped\n' "$skill"
      noted_skills[$skill]=1
    fi
    continue
  fi

  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    [[ "$line" =~ $stale_claim_re ]] || continue
    [[ "$line" =~ $freshness_line_re ]] || continue
    [[ "$line" == *"Month Year"* ]] && continue
    if [[ "$line" != *"$FRESHNESS_LABEL"* ]]; then
      printf 'error: stale freshness marker in %s:%d\n' "$file" "$line_no" >&2
      printf '  expected marker: %s\n' "$FRESHNESS_LABEL" >&2
      printf '  line: %s\n' "$line" >&2
      errors=$((errors + 1))
    fi
  done < "$path"
done

if (( errors > 0 )); then
  exit "$STALE_EXIT"
fi

printf 'Freshness markers use %s.\n' "$FRESHNESS_LABEL"
