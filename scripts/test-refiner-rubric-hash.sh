#!/usr/bin/env bash
set -euo pipefail

# Fixture tests for scripts/refiner-rubric-hash.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/refiner-rubric-hash.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASES=0

# shellcheck source=./scripts/gate-test-lib.sh
source "$ROOT/scripts/gate-test-lib.sh"

SELF_CHECK="skills/skill-creator/SKILL.md"
INPUTS=(
  skills/skill-refiner/references/evaluation-criteria.md
  skills/skill-refiner/references/test-cases.md
  skills/skill-creator/references/conventions.md
  scripts/lint-skills.sh
  scripts/check-ere-pipe.py
  scripts/validate-spec.sh
  scripts/skill-lib.sh
  scripts/skill-frontmatter.py
  scripts/gen-ref-toc.py
  scripts/contract-lib.sh
)

# Fixture: a rubric root where every input holds its own path.
new_fixture() {
  local rel
  FIX="$TMP/root-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  for rel in "${INPUTS[@]}"; do
    mkdir -p "$FIX/$(dirname "$rel")"
    printf '%s\n' "$rel" > "$FIX/$rel"
  done
  printf '%s\n' '# Skill' '' 'Intro.' '' '## AI Self-Check' '' '- one' '' '## After' '' 'Tail.' > "$FIX/$SELF_CHECK"
}

hash_of() {
  run_gate "$SCRIPT" "$1"
  expect_pass "hash of $1"
  [[ "$OUT" =~ ^[0-9a-f]{64}$ ]] || fail "expected a sha256, got '$OUT'"
}

new_fixture
hash_of "$FIX"
base="$OUT"
hash_of "$FIX"
[[ "$OUT" == "$base" ]] || fail "hash changed between two runs over the same inputs"

# The hash covers file contents, not the root's path.
cp -R "$FIX" "$TMP/copy"
hash_of "$TMP/copy"
[[ "$OUT" == "$base" ]] || fail "hash changed for the same contents under another root"

for rel in "${INPUTS[@]}"; do
  new_fixture
  printf 'edit\n' >> "$FIX/$rel"
  hash_of "$FIX"
  [[ "$OUT" != "$base" ]] || fail "hash did not change after an edit to $rel"

  new_fixture
  rm "$FIX/$rel"
  run_gate "$SCRIPT" "$FIX"
  expect_fail "missing input $rel" "$rel"
done

# Only the AI Self-Check section of the skill-creator SKILL.md is an input.
new_fixture
sed -i.bak 's/^- one$/- two/' "$FIX/$SELF_CHECK"
hash_of "$FIX"
[[ "$OUT" != "$base" ]] || fail "hash did not change after an edit inside AI Self-Check"

new_fixture
sed -i.bak -e 's/^Intro\.$/Changed intro./' -e 's/^Tail\.$/Changed tail./' "$FIX/$SELF_CHECK"
hash_of "$FIX"
[[ "$OUT" == "$base" ]] || fail "hash changed after edits outside AI Self-Check"

run_gate "$SCRIPT" "$TMP/absent"
expect_fail "root that is not a directory" "rubric root is not a directory"

printf 'refiner-rubric-hash tests passed (%d cases)\n' "$CASES"
