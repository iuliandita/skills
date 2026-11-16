#!/usr/bin/env bash
set -euo pipefail

# Trailing whitespace, blank lines at EOF, and leftover conflict markers.
#
# Lives in a script rather than inline in the workflow so the same check runs
# locally. It is the one gate the rest of scripts/ does not cover, so a clean
# local run used to still fail CI.
#
# Compares against origin/<base> on a PR, otherwise against BASE_SHA (the push
# event's previous tip; all zeros means unset), otherwise against the merge base
# with the default branch, otherwise just the last commit.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=./scripts/base-lib.sh
source "$ROOT/scripts/base-lib.sh"

BASE_REF="${BASE_REF:-}"
normalize_base_sha

if [[ -n "$BASE_REF" ]]; then
  # --depth on a full clone writes .git/shallow and breaks merge-base for later checks.
  if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
    git fetch --quiet origin "$BASE_REF" --depth=1
    git merge-base HEAD "origin/$BASE_REF" >/dev/null 2>&1 || git fetch --quiet --deepen=50 origin "$BASE_REF"
  else
    git fetch --quiet origin "$BASE_REF"
  fi
  range="origin/$BASE_REF..HEAD"
elif [[ -n "$BASE_SHA" ]]; then
  range="$BASE_SHA..HEAD"
elif { base="$(git merge-base HEAD origin/develop 2>/dev/null)" || base="$(git merge-base HEAD origin/main 2>/dev/null)"; } && [[ "$base" != "$(git rev-parse HEAD)" ]]; then
  range="$base..HEAD"
else
  # On the base branch itself the merge base is HEAD, which would compare nothing.
  # Compare with the first parent: diff-tree prints nothing for a merge commit.
  if git rev-parse --verify --quiet "HEAD^1^{commit}" >/dev/null; then
    git diff --check HEAD^1 HEAD
  else
    git diff-tree --check --root --no-commit-id -r HEAD
  fi
  echo "Whitespace clean (last commit)."
  exit 0
fi

git diff --check "$range"
echo "Whitespace clean ($range)."
