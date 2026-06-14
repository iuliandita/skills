#!/usr/bin/env bash
set -euo pipefail

# Guard the self-contained output contract:
#   1. Every public skill ships references/output-contract.md identical to the
#      source of truth (skills/_shared/output-contract.md). No drift.
#   2. No SKILL.md or references/*.md carries a runtime skills/_shared/ link
#      (it would be a dead reference on standalone installs).
#
# Fix drift with: scripts/gen-contract-refs.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./scripts/contract-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/contract-lib.sh"
TARGET_NAME="output-contract.md"

fail=0

if [[ ! -f "$CONTRACT_SRC" ]]; then
  printf '[!] Source contract missing: %s\n' "$CONTRACT_SRC" >&2
  exit 1
fi

# Expected shipped contract (portable portion of the source).
expected="$(render_shipped_contract)"

# ── 1. Drift check ─────────────────────────────────────────────────────
for dir in "$ROOT"/skills/*/; do
  name="$(basename "$dir")"
  [[ "$name" == _* ]] && continue
  [[ -f "$dir/SKILL.md" ]] || continue
  copy="$dir/references/$TARGET_NAME"
  if [[ ! -f "$copy" ]]; then
    printf '[!] %s: missing references/%s (run scripts/gen-contract-refs.sh)\n' "$name" "$TARGET_NAME" >&2
    fail=1
    continue
  fi
  if ! printf '%s\n' "$expected" | cmp -s - "$copy"; then
    printf '[!] %s: references/%s drifted from source (run scripts/gen-contract-refs.sh)\n' "$name" "$TARGET_NAME" >&2
    fail=1
  fi
done

# ── 2. Ban runtime _shared references ──────────────────────────────────
# A skill must not point at skills/_shared/ at runtime - it does not ship.
# The generated output-contract.md copies are exempt: their content is the
# source contract itself, governed by the drift check above, not authored
# per skill.
shared_refs="$(grep -rn 'skills/_shared/' "$ROOT"/skills/*/SKILL.md "$ROOT"/skills/*/references/*.md 2>/dev/null \
  | grep -v '/references/output-contract\.md:' || true)"
if [[ -n "$shared_refs" ]]; then
  printf '[!] runtime reference to skills/_shared/ (use local references/%s instead):\n' "$TARGET_NAME" >&2
  printf '%s\n' "$shared_refs" >&2
  fail=1
fi

if (( fail )); then
  printf '\nContract sync check failed.\n' >&2
  exit 1
fi

printf 'Contract sync OK: all skills carry an in-sync references/%s, no runtime _shared refs.\n' "$TARGET_NAME"
