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
