#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0
for skill in cluster-health kubernetes-health; do
  PROTECTED_REL="skills/$skill/protected"
  PROTECTED_SENTINEL="$PROTECTED_REL/registry.md"

  if ! git -C "$ROOT" check-ignore -q "$PROTECTED_SENTINEL" 2>/dev/null; then
    echo "ERROR: $PROTECTED_REL is not gitignored."
    echo "Expected .gitignore to protect the $skill private overlay."
    errors=$((errors + 1))
  fi

  mapfile -t tracked_files < <(git -C "$ROOT" ls-files -- "$PROTECTED_REL" "$PROTECTED_REL/*")
  if (( ${#tracked_files[@]} > 0 )); then
    echo "ERROR: protected $skill files are tracked:"
    printf '  %s\n' "${tracked_files[@]}"
    errors=$((errors + 1))
  fi

  mapfile -t staged_files < <(git -C "$ROOT" diff --cached --name-only -- "$PROTECTED_REL" "$PROTECTED_REL/*")
  if (( ${#staged_files[@]} > 0 )); then
    echo "ERROR: protected $skill files are staged:"
    printf '  %s\n' "${staged_files[@]}"
    errors=$((errors + 1))
  fi

done

if (( errors > 0 )); then
  exit 1
fi

echo "Protected overlays are ignored and untracked."
