#!/usr/bin/env bash
set -euo pipefail

# Guard the self-contained shared references:
#   1. Every public skill ships a references/<name>.md identical to the
#      source of truth (skills/_shared/<name>.md) for each file in
#      SHARED_FILE_NAMES (contract-lib.sh). No drift.
#   2. No SKILL.md or references/*.md carries a runtime skills/_shared/ link
#      (it would be a dead reference on standalone installs).
#
# Fix drift with: scripts/gen-contract-refs.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./scripts/contract-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/contract-lib.sh"

fail=0
exempt_pattern=""
for n in "${SHARED_FILE_NAMES[@]}"; do
  esc="${n//./\\.}"
  if [[ -z "$exempt_pattern" ]]; then
    exempt_pattern="/references/${esc}:"
  else
    exempt_pattern="${exempt_pattern}|/references/${esc}:"
  fi
done

# ── 1. Drift check ─────────────────────────────────────────────────────
for target_name in "${SHARED_FILE_NAMES[@]}"; do
  src="$ROOT/skills/_shared/$target_name"
  if [[ ! -f "$src" ]]; then
    printf '[!] Source file missing: %s\n' "$src" >&2
    exit 1
  fi
  expected="$(render_shipped_file "$src")"

  for dir in "$ROOT"/skills/*/; do
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [[ -f "$dir/SKILL.md" ]] || continue
    copy="$dir/references/$target_name"
    if [[ ! -f "$copy" ]]; then
      printf '[!] %s: missing references/%s (run scripts/gen-contract-refs.sh)\n' "$name" "$target_name" >&2
      fail=1
      continue
    fi
    if ! printf '%s\n' "$expected" | cmp -s - "$copy"; then
      printf '[!] %s: references/%s drifted from source (run scripts/gen-contract-refs.sh)\n' "$name" "$target_name" >&2
      fail=1
    fi
  done
done

# ── 2. Ban runtime _shared references ──────────────────────────────────
# A skill must not point at skills/_shared/ at runtime - it does not ship.
# The generated copies (references/<name>.md for each SHARED_FILE_NAMES
# entry) are exempt: their content is the source file itself, governed by
# the drift check above, not authored per skill.
shared_refs="$(grep -rn 'skills/_shared/' "$ROOT"/skills/*/SKILL.md "$ROOT"/skills/*/references/*.md 2>/dev/null \
  | grep -vE "$exempt_pattern" || true)"
if [[ -n "$shared_refs" ]]; then
  printf '[!] runtime reference to skills/_shared/ (use local references/<name>.md instead):\n' >&2
  printf '%s\n' "$shared_refs" >&2
  fail=1
fi

if (( fail )); then
  printf '\nContract sync check failed.\n' >&2
  exit 1
fi

printf 'Contract sync OK: all skills carry in-sync shared references, no runtime _shared refs.\n'
