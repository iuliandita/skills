#!/usr/bin/env bash
set -euo pipefail

# Enforce a single skill-refiner run-history file.
#
# The history lived in two places for months because skill-refiner said "the
# collection root" without defining it: runs appended to .refiner-runs.json or
# to skills/.refiner-runs.json depending on how the agent read that phrase, so
# a run could miss the prior baseline for a skill it had already scored.
# Canonical path is the repository root, beside .refiner-ledger.md.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$ROOT/.refiner-runs.json"

errors=0

mapfile -t strays < <(cd "$ROOT" && git ls-files -- '*/.refiner-runs.json')
if (( ${#strays[@]} > 0 )); then
  echo "ERROR: run history must live only at .refiner-runs.json, found:"
  printf '  %s\n' "${strays[@]}"
  echo "Merge the entries into .refiner-runs.json sorted by date, then delete the stray."
  errors=$((errors + 1))
fi

if [[ -f "$CANONICAL" ]]; then
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CANONICAL" 2>/dev/null; then
    echo "ERROR: .refiner-runs.json is not valid JSON."
    errors=$((errors + 1))
  else
    dupes="$(python3 - "$CANONICAL" <<'PY'
import json, sys
from collections import Counter
runs = json.load(open(sys.argv[1]))
ids = [r.get("run_id") for r in runs if r.get("run_id")]
print(" ".join(sorted(i for i, n in Counter(ids).items() if n > 1)))
PY
)"
    if [[ -n "$dupes" ]]; then
      echo "ERROR: duplicate run_id values in .refiner-runs.json: $dupes"
      errors=$((errors + 1))
    fi
  fi
fi

if (( errors > 0 )); then
  exit 1
fi

echo "Refiner run history is a single file with unique run ids."
