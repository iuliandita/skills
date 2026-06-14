#!/usr/bin/env bash
set -euo pipefail

# Generate each skill's local copy of the shared output contract.
#
# Skills are installed individually (npx skills add, install.sh), so a skill may
# not be co-located with skills/_shared/ at runtime. To stay self-contained,
# every skill ships its own references/output-contract.md, generated from the
# single source of truth at skills/_shared/output-contract.md.
#
# Run this after editing the source contract. CI enforces no drift via
# scripts/check-contract-sync.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./scripts/contract-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/contract-lib.sh"
TARGET_NAME="output-contract.md"

if [[ ! -f "$CONTRACT_SRC" ]]; then
  printf 'Source contract not found: %s\n' "$CONTRACT_SRC" >&2
  exit 1
fi

# Render once: the portable contract is everything above the maintainer marker.
shipped="$(render_shipped_contract)"

count=0
for dir in "$ROOT"/skills/*/; do
  name="$(basename "$dir")"
  [[ "$name" == _* ]] && continue          # skip _shared and other build inputs
  [[ -f "$dir/SKILL.md" ]] || continue
  mkdir -p "$dir/references"
  printf '%s\n' "$shipped" > "$dir/references/$TARGET_NAME"
  count=$((count + 1))
done

printf 'Generated %s/%s into %d skill(s).\n' "references" "$TARGET_NAME" "$count"
