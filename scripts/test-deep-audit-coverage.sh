#!/usr/bin/env bash
# shellcheck disable=SC2016  # the fixture detector is written with literal shell text
set -euo pipefail

# Git-fixture tests for scripts/check-deep-audit-coverage.sh.

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

# add_skill <name> [frontmatter line]
add_skill() {
  mkdir -p "$REPO/skills/$1"
  printf -- '---\nname: %s\ndescription: fixture\n%s---\n\n# %s\n' "$1" "${2:+$2$'\n'}" "$1" \
    > "$REPO/skills/$1/SKILL.md"
}

# Fixture: alpha and beta are detected Wave 3 lanes, gamma always runs in
# Wave 2, delta is excluded.
new_fixture() {
  local f
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  REFS="$REPO/skills/repo-audit/references"
  mkdir -p "$REPO/scripts" "$REFS"
  for f in check-deep-audit-coverage.sh skill-lib.sh skill-frontmatter.py; do
    cp "$ROOT/scripts/$f" "$REPO/scripts/$f"
  done
  printf '%s\n' '[[ -f a.txt ]] && matched+=(alpha)' '  check_manifest beta' > "$REFS/detect.sh"
  printf '%s\n' \
    '- **gamma** - Wave 2 participants.' \
    '- **alpha**, **beta** - Wave 3 candidates (conditional).' > "$REFS/exhaustive-workflow.md"
  printf '%s\n' '| Skill | Reason |' '| --- | --- |' '| **delta** | Not an audit lane. |' > "$REFS/exclusions.md"
  for f in alpha beta gamma delta; do add_skill "$f"; done
  git -C "$REPO" init -q
}

run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && bash scripts/check-deep-audit-coverage.sh 2>&1)" || STATUS=$?
}

new_fixture
run_check
expect_pass "every public skill covered"
[[ "$OUT" == *"4 public skills (3 wave, 1 excluded)"* ]] || fail "clean fixture: unexpected counts"

new_fixture
add_skill epsilon
run_check
expect_fail "new skill in no wave and not excluded" "repo-audit does not cover public skill: epsilon"

# A deprecated notice is not a public skill, so it needs no coverage.
new_fixture
add_skill epsilon $'metadata:\n  deprecated: true'
run_check
expect_pass "deprecated notice needs no coverage"

new_fixture
rm -r "$REPO/skills/delta"
run_check
expect_fail "excluded skill that does not exist" "repo-audit references missing public skill: delta"

new_fixture
printf '  check_manifest zeta\n' >> "$REFS/detect.sh"
add_skill zeta
run_check
expect_fail "detected lane missing from Wave 3" "detect.sh matches zeta but exhaustive-workflow.md does not list it"

new_fixture
sed -i.bak 's/\*\*beta\*\* - Wave 3/**beta**, **zeta** - Wave 3/' "$REFS/exhaustive-workflow.md"
add_skill zeta
run_check
expect_fail "Wave 3 candidate the detector never matches" "lists Wave 3 candidate zeta but detect.sh never matches it"

# A source whose format changed parses to nothing; that is an error, not "no lanes".
new_fixture
printf '%s\n' '| Skill | Reason |' '| --- | --- |' '| delta | Not an audit lane. |' > "$REFS/exclusions.md"
run_check
expect_fail "exclusion table without bold names" "parsed no excluded skills"

new_fixture
printf '%s\n' '- **gamma** - Wave 2 participants.' '- alpha, beta - Wave 3 lanes' > "$REFS/exhaustive-workflow.md"
run_check
expect_fail "workflow without a Wave 3 candidates line" "parsed no Wave 3 candidates"

new_fixture
rm "$REFS/exclusions.md"
run_check
expect_fail "missing exclusions file" "exclusions file not found"

printf 'deep-audit-coverage tests passed (%d cases)\n' "$CASES"
