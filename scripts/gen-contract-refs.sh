#!/usr/bin/env bash
set -euo pipefail

# Generate each skill's local copy of every shared reference file.
#
# Skills are installed individually (npx skills add, install.sh), so a skill may
# not be co-located with skills/_shared/ at runtime. To stay self-contained,
# every skill ships its own references/<name>.md for each file listed in
# SHARED_FILE_NAMES (contract-lib.sh), generated from the single source of
# truth at skills/_shared/<name>.md.
#
# Run this after editing a source file. CI enforces no drift via
# scripts/check-contract-sync.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./scripts/contract-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/contract-lib.sh"

total=0
for target_name in "${SHARED_FILE_NAMES[@]}"; do
  src="$ROOT/skills/_shared/$target_name"
  if [[ ! -f "$src" ]]; then
    printf 'Source file not found: %s\n' "$src" >&2
    exit 1
  fi

  # Render once: the portable content is everything above the maintainer marker.
  shipped="$(render_shipped_file "$src")"

  count=0
  for dir in "$ROOT"/skills/*/; do
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue          # skip _shared and other build inputs
    [[ -f "$dir/SKILL.md" ]] || continue
    mkdir -p "$dir/references"
    printf '%s\n' "$shipped" > "$dir/references/$target_name"
    count=$((count + 1))
  done

  printf 'Generated %s/%s into %d skill(s).\n' "references" "$target_name" "$count"
  total=$((total + count))
done
