#!/usr/bin/env bash
# Shared by the base-ref checks: check-whitespace.sh,
# check-refiner-phase1-guard.sh and check-docs-impact.sh. Sourced, not run.

# Normalize BASE_SHA, the push event's previous tip. All zeros means unset. A
# BASE_SHA that would be used (no BASE_REF) and is not a commit in this clone
# exits 1. Call after BASE_REF holds its final value.
normalize_base_sha() {
  BASE_SHA="${BASE_SHA:-}"
  if [[ "$BASE_SHA" =~ ^0+$ ]]; then
    # A push that creates a ref reports an all-zero "before" sha.
    BASE_SHA=""
  fi
  if [[ -z "${BASE_REF:-}" && -n "$BASE_SHA" ]] && ! git rev-parse --verify --quiet "${BASE_SHA}^{commit}" >/dev/null; then
    echo "error: BASE_SHA '${BASE_SHA}' is not a commit in this clone" >&2
    exit 1
  fi
}

ref_exists() {
  git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1
}

# Set the global `base` to the merge base of HEAD and the first candidate that
# is a commit here, or to "" when none is. A candidate that exists but shares
# no history with HEAD exits 1.
resolve_base() {
  local candidate
  for candidate in "$@"; do
    if ref_exists "$candidate"; then
      if base="$(git merge-base HEAD "$candidate" 2>/dev/null)"; then
        return 0
      fi
      echo "error: base ref '${candidate}' exists but no merge-base with HEAD could be computed" >&2
      echo "(shallow clone or unrelated history); refusing to fall back to a non-ancestor tip." >&2
      exit 1
    fi
  done
  # shellcheck disable=SC2034  # read by the sourcing script
  base=""
}
