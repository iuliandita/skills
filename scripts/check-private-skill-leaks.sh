#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTECTED_DIR="$ROOT/skills/cluster-health/protected"
PATTERN_FILE="$PROTECTED_DIR/private-patterns.txt"

if [[ ! -f "$PATTERN_FILE" ]]; then
  echo "No protected cluster-health overlay found; skipping private leak check."
  exit 0
fi

mapfile -t tracked_files < <(git -C "$ROOT" ls-files)
mapfile -t patterns < <(grep -vE '^[[:space:]]*(#|$)' "$PATTERN_FILE")

errors=0
for pattern in "${patterns[@]}"; do
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if grep -qiF -- "$pattern" "$ROOT/$file"; then
      echo "ERROR: private pattern '$pattern' found in tracked file $file"
      errors=$((errors + 1))
    fi
  done < <(printf '%s\n' "${tracked_files[@]}")
done

if (( errors > 0 )); then
  exit 1
fi

echo "No private cluster-health patterns found in tracked files."
