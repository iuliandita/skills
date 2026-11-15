#!/usr/bin/env bash
set -euo pipefail

# Pins the exit codes of the two gates that CI and pre-commit run as advisory:
# scripts/check-freshness-dates.sh and scripts/check-version-receipts.sh.
#
# The advisory wrappers downgrade exit 1 to a warning and fail on any other
# code. These cases record which inputs produce 1, so a change that moves a
# code has to change the wrappers with it.

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

# expect_code <label> <code> <needle>
expect_code() {
  (( STATUS == $2 )) || fail "$1: expected exit $2, got $STATUS"
  [[ "$OUT" == *"$3"* ]] || fail "$1: output missing '$3'"
}

# Root reads a mode-000 file, so the unreadable-file cases need another user.
can_deny_read() { (( $(id -u) != 0 )); }

# --- check-freshness-dates.sh ---

# Fixture: a repo with one tracked skill file holding <its one line>.
new_freshness_fixture() {
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts" "$REPO/skills/alpha"
  cp "$ROOT/scripts/check-freshness-dates.sh" "$REPO/scripts/check-freshness-dates.sh"
  printf '%s\n' "$1" > "$REPO/skills/alpha/SKILL.md"
  git -C "$REPO" init -q
  git -C "$REPO" add skills
}

run_freshness() {
  STATUS=0
  OUT="$(cd "$REPO" && "$@" bash scripts/check-freshness-dates.sh 2>&1)" || STATUS=$?
}

new_freshness_fixture "Pins verified $(LC_ALL=C date +'%B %Y')."
run_freshness env
expect_pass "freshness: current marker"

new_freshness_fixture "Pins verified January 2020."
run_freshness env
expect_code "freshness: stale marker" 1 "stale freshness marker"

# A tracked file that cannot be read also exits 1: the wrapper reports it as stale.
if can_deny_read; then
  new_freshness_fixture "Pins verified January 2020."
  chmod 000 "$REPO/skills/alpha/SKILL.md"
  run_freshness env
  chmod 644 "$REPO/skills/alpha/SKILL.md"
  expect_code "freshness: unreadable tracked file" 1 "Permission denied"
  [[ "$OUT" != *"stale freshness marker"* ]] || fail "freshness: unreadable file was reported as a stale marker"
fi

# A failing date keeps its own exit code, which the wrapper does not downgrade.
new_freshness_fixture "Pins verified January 2020."
mkdir -p "$TMP/stub"
printf '#!/usr/bin/env bash\nexit 3\n' > "$TMP/stub/date"
chmod +x "$TMP/stub/date"
run_freshness env PATH="$TMP/stub:$PATH"
expect_code "freshness: date fails" 3 ""

# --- check-version-receipts.sh ---

# Fixture: a skills root with one receipt for "alpha". Args: <frontmatter body>
new_receipt_fixture() {
  SKILLS="$TMP/skills-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  RECEIPT="$SKILLS/alpha/references/versions.md"
  mkdir -p "$(dirname "$RECEIPT")"
  printf '%s\n' "$1" > "$RECEIPT"
}

receipt() {
  printf -- '---\nchecked_at: %s\nchecked_by: fixture\npins:\n  - tool: demo\n    version: "1.0"\n    source: https://example.com/releases\n---' "$1"
}

run_receipts() {
  run_gate env SKILLS_ROOT="$SKILLS" "$@" bash "$ROOT/scripts/check-version-receipts.sh"
}

new_receipt_fixture "$(receipt "$(date -u +%Y-%m-%d)")"
run_receipts
expect_pass "receipts: fresh receipt"

new_receipt_fixture "$(receipt 2020-01-01)"
run_receipts
expect_code "receipts: receipt past the age budget" 1 "days old (budget 120 days)"

# Structure failures share exit 1, which is why CI runs the structure step
# (age budget lifted) before the advisory age step.
new_receipt_fixture "$(receipt 2020-01-01)"
run_receipts SKILLS_PIN_MAX_AGE_DAYS=36500
expect_pass "receipts: old receipt with the age budget lifted"

new_receipt_fixture $'---\nchecked_at: 2020-01-01'
run_receipts SKILLS_PIN_MAX_AGE_DAYS=36500
expect_code "receipts: frontmatter without a closing fence" 1 "pins: has no entries"

if can_deny_read; then
  new_receipt_fixture "$(receipt 2020-01-01)"
  chmod 000 "$RECEIPT"
  run_receipts SKILLS_PIN_MAX_AGE_DAYS=36500
  chmod 644 "$RECEIPT"
  expect_code "receipts: unreadable receipt" 1 "missing checked_at"
fi

# A budget that is not a number stops the script with exit 1 as well.
new_receipt_fixture "$(receipt 2020-01-01)"
run_receipts SKILLS_PIN_MAX_AGE_DAYS=many
expect_code "receipts: non-numeric age budget" 1 "unbound variable"
[[ "$OUT" != *"days old"* ]] || fail "receipts: non-numeric budget was reported as a stale receipt"

printf 'advisory-exit-code tests passed (%d cases)\n' "$CASES"
