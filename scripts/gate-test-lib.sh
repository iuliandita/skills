#!/usr/bin/env bash
# Shared by the gate tests (the scripts/test-*.sh files that exercise
# lint-skills.sh and the check-*.sh gates). Sourced, not run.
#
# A test runs its gate into STATUS (exit code) and OUT (stdout and stderr),
# then states the expected outcome with expect_pass or expect_fail.

# Print the reason and, when a run was captured, its output.
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  [[ -z "${OUT:-}" ]] || printf '%s\n' "$OUT" >&2
  exit 1
}

# run_gate <command> [args...]: sets STATUS and OUT.
run_gate() {
  STATUS=0
  OUT="$("$@" 2>&1)" || STATUS=$?
}

# expect_pass <label>
expect_pass() {
  (( STATUS == 0 )) || fail "$1: expected exit 0, got $STATUS"
}

# expect_fail <label> [needle]: non-zero exit, and OUT holds the needle.
expect_fail() {
  local label="$1" needle="${2:-}"
  (( STATUS != 0 )) || fail "$label: expected failure, got exit 0"
  [[ -z "$needle" || "$OUT" == *"$needle"* ]] || fail "$label: output missing '$needle'"
}
