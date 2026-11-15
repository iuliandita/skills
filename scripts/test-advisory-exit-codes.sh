#!/usr/bin/env bash
set -euo pipefail

# Pins the exit codes of the two gates that CI and pre-commit run as advisory:
# scripts/check-freshness-dates.sh and scripts/check-version-receipts.sh.
#
# The advisory wrappers downgrade the stale code (10) to a warning and fail
# on any other code. These cases record which inputs produce 10 and which
# produce 1, so a change that moves a code has to change the wrappers with it.

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Nor the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASES=0
STALE=10

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
expect_code "freshness: stale marker" "$STALE" "stale freshness marker"

# A tracked file that cannot be read is a broken input, not a stale one.
if can_deny_read; then
  new_freshness_fixture "Pins verified January 2020."
  chmod 000 "$REPO/skills/alpha/SKILL.md"
  run_freshness env
  chmod 644 "$REPO/skills/alpha/SKILL.md"
  expect_code "freshness: unreadable tracked file" 1 "Permission denied"
  [[ "$OUT" != *"stale freshness marker"* ]] || fail "freshness: unreadable file was reported as a stale marker"

  # Broken wins: a stale marker is reported first, then the unreadable file.
  new_freshness_fixture "Pins verified January 2020."
  mkdir -p "$REPO/skills/beta"
  printf 'Pins verified January 2020.\n' > "$REPO/skills/beta/SKILL.md"
  git -C "$REPO" add skills
  chmod 000 "$REPO/skills/beta/SKILL.md"
  run_freshness env
  chmod 644 "$REPO/skills/beta/SKILL.md"
  expect_code "freshness: stale marker and unreadable file" 1 "stale freshness marker in skills/alpha/SKILL.md"
  [[ "$OUT" == *"Permission denied"* ]] || fail "freshness: unreadable file was not reported"
fi

# Outside a git repository the file listing fails: an error, not an empty scan.
new_freshness_fixture "Pins verified January 2020."
rm -rf "$REPO/.git"
run_freshness env GIT_CEILING_DIRECTORIES="$TMP"
expect_code "freshness: outside a git repository" 1 "could not list tracked files"

# A failing command is exit 1 whatever its own code, here the stale code itself.
new_freshness_fixture "Pins verified January 2020."
mkdir -p "$TMP/stub"
printf '#!/usr/bin/env bash\nexit %d\n' "$STALE" > "$TMP/stub/date"
chmod +x "$TMP/stub/date"
run_freshness env PATH="$TMP/stub:$PATH"
expect_code "freshness: date fails" 1 ""

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
expect_code "receipts: receipt past the age budget" "$STALE" "days old (budget 120 days)"

# The structure step and hook lift the age budget, so an old receipt passes there.
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

# Broken wins: one receipt past the budget and one malformed, in either order.
for broken in beta aaa; do
  new_receipt_fixture "$(receipt 2020-01-01)"
  mkdir -p "$SKILLS/$broken/references"
  printf -- '---\nchecked_by: fixture\n---\n' > "$SKILLS/$broken/references/versions.md"
  run_receipts
  expect_code "receipts: stale receipt and malformed $broken receipt" 1 "$broken: missing checked_at"
  [[ "$OUT" == *"days old (budget 120 days)"* ]] || fail "receipts: stale receipt was not reported beside the malformed one"
done

# A receipt listing that fails is an error, not "nothing to check".
new_receipt_fixture "$(receipt 2020-01-01)"
run_receipts SKILLS_ROOT="$SKILLS/missing"
expect_code "receipts: skills root that does not exist" 1 "could not list receipts"

# A budget that is not a whole number is refused before any receipt is read.
for budget in many 12x -5 ""; do
  new_receipt_fixture "$(receipt 2020-01-01)"
  run_receipts SKILLS_PIN_MAX_AGE_DAYS="$budget"
  if [[ -z "$budget" ]]; then
    # Empty means unset: the default budget applies.
    expect_code "receipts: empty age budget" "$STALE" "days old (budget 120 days)"
    continue
  fi
  expect_code "receipts: age budget '$budget'" 1 "SKILLS_PIN_MAX_AGE_DAYS must be a whole number"
  [[ "$OUT" != *"days old"* ]] || fail "receipts: budget '$budget' was reported as a stale receipt"
done

printf 'advisory-exit-code tests passed (%d cases)\n' "$CASES"
