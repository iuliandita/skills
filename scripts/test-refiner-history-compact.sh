#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/refiner-history-compact.sh.

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

# A full schema-2 entry with per-skill detail. Args: <run_id>
entry() {
  printf '{"run_id": "%s", "date": "2026-01-01", "schema": 2, "rubric_hash": "%s", "review_weight": 0.05, "primary": {"model": "one"}, "control_failures": [], "skills": [{"name": "alpha", "composite": 91.5}]}' \
    "$1" "$HASH"
}

# new_fixture <run_id>...: a repo holding both scripts and a history of the runs.
new_fixture() {
  local id sep=""
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  HISTORY="$REPO/.refiner-runs.json"
  ARCHIVE="$REPO/.refiner-runs-archive.json"
  mkdir -p "$REPO/scripts"
  cp "$ROOT/scripts/refiner-history-compact.sh" "$ROOT/scripts/check-refiner-state.sh" "$REPO/scripts/"
  git -C "$REPO" init -q
  {
    printf '[\n'
    for id in "$@"; do
      printf '%s  %s' "$sep" "$(entry "$id")"
      sep=$',\n'
    done
    printf '\n]\n'
  } > "$HISTORY"
  cp "$HISTORY" "$TMP/before.json"
}

run_compact() {
  run_gate bash "$REPO/scripts/refiner-history-compact.sh" "$@"
}

# column <file> <ids|compacted|detail|scores>: one value per run, space-separated.
column() {
  python3 - "$1" "$2" <<'PY'
import json, sys

runs = json.load(open(sys.argv[1]))
pick = {
    "ids": lambda r: r["run_id"],
    "compacted": lambda r: r.get("compacted") is True,
    "detail": lambda r: "skills" in r,
    "scores": lambda r: r["skills"][0]["composite"],
}[sys.argv[2]]
print(" ".join(str(pick(r)) for r in runs))
PY
}

new_fixture r1 r2 r3
run_compact --keep 1
expect_pass "compact two of three runs"
[[ "$(column "$HISTORY" ids)" == "r1 r2 r3" ]] \
  || fail "history lost or reordered a run"
[[ "$(column "$HISTORY" compacted)" == "True True False" ]] \
  || fail "the two older runs are not marked compacted"
[[ "$(column "$HISTORY" detail)" == "False False True" ]] \
  || fail "per-skill detail should leave the summaries and stay in the kept run"
grep -qF "$(entry r3)" "$HISTORY" || fail "the kept run is not byte-identical"
# The archive holds the moved entries in full.
[[ "$(column "$ARCHIVE" ids) $(column "$ARCHIVE" scores)" == "r1 r2 91.5 91.5" ]] \
  || fail "archive does not hold the full older entries"

# A second run finds nothing to move and leaves both files alone.
cp "$HISTORY" "$TMP/history.once"
cp "$ARCHIVE" "$TMP/archive.once"
run_compact --keep 1
expect_pass "second run"
[[ "$OUT" == *"Nothing to compact"* ]] || fail "second run should have nothing to compact"
cmp -s "$HISTORY" "$TMP/history.once" || fail "second run rewrote the history"
cmp -s "$ARCHIVE" "$TMP/archive.once" || fail "second run rewrote the archive"

# A later compaction appends to the archive that is already there.
run_compact --keep 0
expect_pass "compact the last run into an existing archive"
[[ "$(column "$ARCHIVE" ids)" == "r1 r2 r3" ]] \
  || fail "archive was not appended to"

new_fixture r1 r2 r3
run_compact --keep 1 --dry-run
expect_pass "dry run"
[[ "$OUT" == *"archive: r1"* && "$OUT" == *"Dry run: nothing written."* ]] || fail "dry run did not report its plan"
cmp -s "$HISTORY" "$TMP/before.json" || fail "dry run changed the history"
[[ ! -e "$ARCHIVE" ]] || fail "dry run wrote an archive"

new_fixture r1 r2
run_compact --keep 5
expect_pass "fewer runs than the retention window"
cmp -s "$HISTORY" "$TMP/before.json" || fail "history changed inside the retention window"

# A history that fails validation once compacted is restored, archive included.
new_fixture r1 r1 r2
run_compact --keep 1
expect_fail "post-compaction validation failure" "restoring original files"
(( STATUS == 1 )) || fail "validation failure: expected exit 1, got $STATUS"
cmp -s "$HISTORY" "$TMP/before.json" || fail "history was not restored after a failed validation"
[[ ! -e "$ARCHIVE" ]] || fail "archive created by a failed compaction was left behind"

# Usage errors exit 2 and touch nothing: <label> <needle> <args...>
usage_case() {
  local label="$1" needle="$2"
  shift 2
  new_fixture r1 r2 r3
  run_compact "$@"
  expect_fail "$label" "$needle"
  (( STATUS == 2 )) || fail "$label: expected exit 2, got $STATUS"
  cmp -s "$HISTORY" "$TMP/before.json" || fail "$label: history changed"
}
usage_case "non-numeric --keep" "--keep must be a non-negative integer" --keep many
usage_case "--keep without a value" "--keep requires a value" --keep
usage_case "unknown option" "unknown option: --prune" --prune
usage_case "history and archive the same file" "must differ" --archive "$TMP/repo-$CASES/.refiner-runs.json"

new_fixture r1
run_compact --history "$REPO/absent.json"
expect_fail "missing history" "history file not found"
(( STATUS == 1 )) || fail "missing history: expected exit 1, got $STATUS"

printf 'refiner-history-compact tests passed (%d cases)\n' "$CASES"
