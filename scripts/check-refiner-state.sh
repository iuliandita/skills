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

    # Schema-2 entries opt into stricter validation. Historical entries without
    # a schema field are left as-is and must keep passing.
    schema_errors=""
    if ! schema_errors="$(python3 - "$CANONICAL" <<'PY'
import json, re, sys

runs = json.load(open(sys.argv[1]))
hex64 = re.compile(r"^[0-9a-f]{64}$")
allowed_weights = {0.03, 0.05, 3.0, 5.0}
problems = []


def identity_key(obj):
    if not isinstance(obj, dict):
        return None
    for key in ("resolved_model", "model"):
        if key in obj:
            return key
    return None


for i, run in enumerate(runs):
    if not isinstance(run, dict):
        continue
    schema = run.get("schema")
    if not isinstance(schema, int) or schema < 2:
        continue
    rid = run.get("run_id") or f"index {i}"

    rubric_hash = run.get("rubric_hash")
    if not isinstance(rubric_hash, str) or not hex64.match(rubric_hash):
        problems.append(
            f"{rid}: rubric_hash must be a 64-char lowercase hex string, got {rubric_hash!r}"
        )

    weight_keys = [k for k in ("review_weight", "cap") if k in run]
    if not weight_keys:
        problems.append(f"{rid}: review_weight or cap must be present")
    for key in weight_keys:
        try:
            value = float(run[key])
        except (TypeError, ValueError):
            problems.append(f"{rid}: {key} must be numeric (0.03/0.05 or 3/5), got {run[key]!r}")
            continue
        if value not in allowed_weights:
            problems.append(
                f"{rid}: {key} must be 0.03, 0.05, 3, or 5, got {run[key]!r}"
            )

    primary_key = identity_key(run.get("primary"))
    if primary_key is None:
        problems.append(
            f"{rid}: primary identity must use a consistent key name (resolved_model or model)"
        )

    secondary = run.get("secondary")
    if isinstance(secondary, dict):
        secondary_key = identity_key(secondary)
        if secondary_key is None:
            problems.append(
                f"{rid}: secondary identity must use a consistent key name (resolved_model or model)"
            )
        elif primary_key is not None and secondary_key != primary_key:
            problems.append(
                f"{rid}: primary uses {primary_key!r} but secondary uses {secondary_key!r}; "
                "identity key names must be consistent"
            )

for problem in problems:
    print(problem)
sys.exit(1 if problems else 0)
PY
)"; then
      echo "ERROR: schema>=2 run-history entries failed validation:"
      while IFS= read -r line; do
        echo "  $line"
      done <<< "$schema_errors"
      errors=$((errors + 1))
    fi
  fi
fi

if (( errors > 0 )); then
  exit 1
fi

echo "Refiner run history is a single file with unique run ids; schema>=2 entries valid."
