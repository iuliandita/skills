#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTECTED_REL="skills/cluster-health/protected"
PROTECTED_SENTINEL="$PROTECTED_REL/registry.md"

errors=0

if ! git -C "$ROOT" check-ignore -q "$PROTECTED_SENTINEL" 2>/dev/null; then
  echo "ERROR: $PROTECTED_REL is not gitignored."
  echo "Expected .gitignore to protect the cluster-health private overlay."
  errors=$((errors + 1))
fi

mapfile -t tracked_files < <(git -C "$ROOT" ls-files -- "$PROTECTED_REL" "$PROTECTED_REL/*")
if (( ${#tracked_files[@]} > 0 )); then
  echo "ERROR: protected cluster-health files are tracked:"
  printf '  %s\n' "${tracked_files[@]}"
  errors=$((errors + 1))
fi

mapfile -t staged_files < <(git -C "$ROOT" diff --cached --name-only -- "$PROTECTED_REL" "$PROTECTED_REL/*")
if (( ${#staged_files[@]} > 0 )); then
  echo "ERROR: protected cluster-health files are staged:"
  printf '  %s\n' "${staged_files[@]}"
  errors=$((errors + 1))
fi

if (( errors > 0 )); then
  exit 1
fi

echo "Protected cluster-health overlay is ignored and untracked."
