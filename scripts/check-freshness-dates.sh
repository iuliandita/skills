#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRESHNESS_LABEL="${SKILLS_FRESHNESS_LABEL:-May 2026}"

mapfile -t files < <(
  git -C "$ROOT" ls-files \
    | grep -E '^(skills/|README[.]md$|INSTALL[.]md$).*[.]md$' \
    | grep -v '^skills/cluster-health/protected/' || true
)

errors=0

stale_claim_re='(as of|verified|recheck|snapshot|current as of|Pinned to|Research preview context|Key facts \(|Skill Inventory \(|Target versions|Versions worth pinning)'
freshness_line_re='(^\*\*Target versions|^\*\*Versions worth pinning|^#+ .*Target versions|^#+ .*Versions worth pinning|Research preview context|Key facts \([A-Z][a-z]+ 20[0-9]{2}\)|Skill Inventory \([A-Z][a-z]+ 20[0-9]{2}\)|current as of|as of [A-Z][a-z]+ 20[0-9]{2}|verified [A-Z][a-z]+ 20[0-9]{2}|[A-Z][a-z]+ 20[0-9]{2} recheck|[A-Z][a-z]+ 20[0-9]{2} snapshot|Pinned to [A-Z][a-z]+ 20[0-9]{2})'

for file in "${files[@]}"; do
  path="$ROOT/$file"
  [[ -f "$path" ]] || continue
  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    [[ "$line" =~ $stale_claim_re ]] || continue
    [[ "$line" =~ $freshness_line_re ]] || continue
    [[ "$line" == *"Month Year"* ]] && continue
    if [[ "$line" != *"$FRESHNESS_LABEL"* ]]; then
      printf 'ERROR: stale freshness marker in %s:%d\n' "$file" "$line_no"
      printf '  expected marker: %s\n' "$FRESHNESS_LABEL"
      printf '  line: %s\n' "$line"
      errors=$((errors + 1))
    fi
  done < "$path"
done

if (( errors > 0 )); then
  exit 1
fi

printf 'Freshness markers use %s.\n' "$FRESHNESS_LABEL"
