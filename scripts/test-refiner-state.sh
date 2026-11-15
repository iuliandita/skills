#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/check-refiner-state.sh.

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Nor the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASES=0

# shellcheck source=./scripts/gate-test-lib.sh
source "$ROOT/scripts/gate-test-lib.sh"

HASH="$(printf 'a%.0s' {1..64})"

# A schema-2 entry that passes. Args: <run_id> [extra fields, each ending in a comma]
entry() {
  printf '{"run_id": "%s", "schema": 2, %s"rubric_hash": "%s", "review_weight": 0.05, "primary": {"model": "one"}, "secondary": {"model": "two"}, "control_failures": [], "skills": [{"name": "alpha", "composite": 91.5}]}' \
    "$1" "${2:-}" "$HASH"
}

# new_fixture [history text]: a repo holding the gate and, when given, a history.
new_fixture() {
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts"
  cp "$ROOT/scripts/check-refiner-state.sh" "$REPO/scripts/check-refiner-state.sh"
  git -C "$REPO" init -q
  [[ $# -eq 0 ]] || printf '%s\n' "$1" > "$REPO/.refiner-runs.json"
}

run_check() {
  run_gate bash "$REPO/scripts/check-refiner-state.sh" "$@"
}

new_fixture
run_check
expect_pass "no history file"

new_fixture "[$(entry r1), $(entry r2)]"
run_check
expect_pass "valid schema-2 history"

# Entries from before schema 2 are not validated.
new_fixture '[{"run_id": "old", "rubric_hash": "short", "cap": "high", "composite": "n/a"}]'
run_check
expect_pass "legacy entry"

new_fixture "[$(entry r1)]"
mkdir -p "$REPO/skills"
cp "$REPO/.refiner-runs.json" "$REPO/skills/.refiner-runs.json"
git -C "$REPO" add skills/.refiner-runs.json
run_check
expect_fail "second tracked history file" "skills/.refiner-runs.json"

new_fixture '[{"run_id": "r1",'
run_check
expect_fail "truncated history" "is not valid JSON"

new_fixture "[$(entry r1), $(entry r2), $(entry r1)]"
run_check
expect_fail "duplicate run id" "duplicate run_id values in .refiner-runs.json: r1"

# One schema-2 rule per case: <label> <entry text> <expected message>.
schema_case() {
  new_fixture "[$2]"
  run_check
  expect_fail "$1" "$3"
}

good="$(entry r1)"
schema_case "short rubric hash" "${good/$HASH/abc123}" "r1: rubric_hash must be a 64-char lowercase hex string"
schema_case "weight outside the allowed set" "${good/0.05/0.04}" "r1: review_weight must be 0.03, 0.05, 3, or 5"
schema_case "non-numeric weight" "${good/0.05/\"high\"}" "r1: review_weight must be numeric"
schema_case "no weight or cap" "${good/\"review_weight\": 0.05, /}" "r1: review_weight or cap must be present"
schema_case "primary without an identity key" "${good/\"primary\": \{\"model\": \"one\"\}/\"primary\": \{\}}" \
  "r1: primary identity must use a consistent key name"
schema_case "mixed identity keys" "${good/\"secondary\": \{\"model\"/\"secondary\": \{\"resolved_model\"}" \
  "identity key names must be consistent"
schema_case "control_failures not an array" "${good/\"control_failures\": []/\"control_failures\": 0}" \
  "r1: control_failures must be an array"
schema_case "string score" "${good/91.5/\"91.5\"}" "r1: score field skills[0].composite must be numeric"

# A compacted summary drops the per-skill scores but keeps the shared fields.
new_fixture "[$(entry r1 '"compacted": true, "aggregate": {"composite": "dropped"},')]"
run_check
expect_pass "compacted summary without numeric scores"

new_fixture '[{"run_id": "old", "compacted": true, "rubric_hash": "short"}]'
run_check
expect_fail "compacted legacy summary with a bad hash" "old: rubric_hash must be"

# The optional argument validates another file instead of the canonical one.
new_fixture "[$(entry r1)]"
printf '[%s, %s]\n' "$(entry r2)" "$(entry r2)" > "$TMP/other.json"
run_check "$TMP/other.json"
expect_fail "history given as an argument" "duplicate run_id"

printf 'refiner-state tests passed (%d cases)\n' "$CASES"
