#!/usr/bin/env bash
set -euo pipefail

# Trailing whitespace, blank lines at EOF, and leftover conflict markers.
#
# Lives in a script rather than inline in the workflow so the same check runs
# locally. It is the one gate the rest of scripts/ does not cover, so a clean
# local run used to still fail CI.
#
# Compares against origin/<base> on a PR, otherwise against the merge base with
# the default branch, otherwise just the last commit.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE_REF="${BASE_REF:-}"

if [[ -n "$BASE_REF" ]]; then
  git fetch --quiet origin "$BASE_REF" --depth=1
  range="origin/$BASE_REF..HEAD"
elif base="$(git merge-base HEAD origin/main 2>/dev/null)" && [[ "$base" != "$(git rev-parse HEAD)" ]]; then
  range="$base..HEAD"
else
  # On the base branch itself the merge base is HEAD, which would compare nothing.
  git diff-tree --check --no-commit-id -r HEAD
  echo "Whitespace clean (last commit)."
  exit 0
fi

git diff --check "$range"
echo "Whitespace clean ($range)."
