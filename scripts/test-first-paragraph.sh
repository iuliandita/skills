#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/check-first-paragraph.sh.

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Nor the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASES=0

GOOD_PARA='Fixture skill that explains one bounded task in plain words, long enough to pass the storefront length floor and short enough to stay under the ceiling.'

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  [[ -z "${OUT:-}" ]] || printf '%s\n' "$OUT" >&2
  exit 1
}

# write_skill <name> <first paragraph> [description]
write_skill() {
  local name="$1" para="$2" desc="${3:-fixture}"
  mkdir -p "$REPO/skills/$name"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n\n%s\n\n## When to use\n' \
    "$name" "$desc" "$name" "$para" > "$REPO/skills/$name/SKILL.md"
}

new_fixture() {
  local f
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts"
  for f in check-first-paragraph.sh skill-lib.sh skill-frontmatter.py; do
    cp "$ROOT/scripts/$f" "$REPO/scripts/$f"
  done
  git -C "$REPO" init -q
  write_skill alpha "$GOOD_PARA"
}

run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && bash scripts/check-first-paragraph.sh 2>&1)" || STATUS=$?
}

expect_pass() {
  (( STATUS == 0 )) || fail "$1: expected exit 0, got $STATUS"
}

expect_fail() {
  local label="$1" needle="$2"
  (( STATUS != 0 )) || fail "$label: expected failure, got exit 0"
  [[ "$OUT" == *"$needle"* ]] || fail "$label: output missing '$needle'"
}

new_fixture
run_check
expect_pass "good first paragraph"

new_fixture
write_skill beta "Too short."
run_check
expect_fail "short first paragraph" "beta 10 TOO-SHORT"

# A gitignored local skill is not part of the published collection.
new_fixture
write_skill private "Too short."
printf 'skills/private/\n' > "$REPO/.gitignore"
run_check
expect_pass "gitignored skill with a bad paragraph"

new_fixture
write_skill beta "$GOOD_PARA" '"Splits a --- b on dashes"'
run_check
expect_pass "--- inside a frontmatter value"

new_fixture
printf '# beta\n\n%s\n' "$GOOD_PARA" > "$REPO/skills/alpha/SKILL.md"
run_check
expect_fail "missing frontmatter" "alpha 0 INVALID-FRONTMATTER"

new_fixture
rm -rf "$REPO/skills/alpha"
mkdir -p "$REPO/skills"
run_check
expect_fail "no public skills" "found no public skills"

printf 'first-paragraph tests passed (%d cases)\n' "$CASES"
