#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/gen-contract-refs.sh.

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

SHARED=(output-contract.md agent-hygiene.md)

# add_skill <name> [frontmatter line]
add_skill() {
  mkdir -p "$REPO/skills/$1"
  printf -- '---\nname: %s\ndescription: fixture\n%s---\n\n# %s\n' "$1" "${2:+$2$'\n'}" "$1" \
    > "$REPO/skills/$1/SKILL.md"
}

# Fixture: one skill "alpha" and both shared sources, each with maintainer
# notes below the marker and blank lines above it.
new_fixture() {
  local f
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts" "$REPO/skills/_shared"
  for f in gen-contract-refs.sh contract-lib.sh skill-lib.sh skill-frontmatter.py; do
    cp "$ROOT/scripts/$f" "$REPO/scripts/$f"
  done
  for f in "${SHARED[@]}"; do
    printf '# %s\n\nShipped text.\n\n\n<!-- maintainer-notes:not-shipped -->\nBuild note.\n' "$f" \
      > "$REPO/skills/_shared/$f"
  done
  add_skill alpha
  git -C "$REPO" init -q
}

run_gen() {
  STATUS=0
  OUT="$(cd "$REPO" && bash scripts/gen-contract-refs.sh 2>&1)" || STATUS=$?
}

new_fixture
mkdir -p "$REPO/skills/alpha/references"
printf 'stale copy\n' > "$REPO/skills/alpha/references/output-contract.md"
run_gen
expect_pass "generate into one skill"
for f in "${SHARED[@]}"; do
  printf '# %s\n\nShipped text.\n' "$f" > "$TMP/expected"
  cmp -s "$TMP/expected" "$REPO/skills/alpha/references/$f" \
    || fail "$f: copy is not the source text above the marker, ending in one newline"
  [[ "$OUT" == *"Generated references/$f into 1 skill(s)."* ]] || fail "$f: count not reported"
done
[[ ! -e "$REPO/skills/_shared/references" ]] || fail "generated into the _shared build input"

# Deprecated notices, ignored private skills, and directories without a
# SKILL.md get no copy.
new_fixture
add_skill beta
add_skill retired $'metadata:\n  deprecated: true'
add_skill private
printf 'skills/private/\n' > "$REPO/.gitignore"
mkdir -p "$REPO/skills/notes"
run_gen
expect_pass "generate with skipped directories"
[[ "$OUT" == *"into 2 skill(s)."* ]] || fail "expected 2 skills, got: $OUT"
[[ -f "$REPO/skills/beta/references/agent-hygiene.md" ]] || fail "beta got no copy"
for f in retired private notes; do
  [[ ! -e "$REPO/skills/$f/references" ]] || fail "$f should get no generated copy"
done

for f in "${SHARED[@]}"; do
  new_fixture
  rm "$REPO/skills/_shared/$f"
  run_gen
  expect_fail "missing source $f" "Source file not found"
  [[ "$OUT" == *"skills/_shared/$f"* ]] || fail "missing source $f not named"
done

printf 'gen-contract-refs tests passed (%d cases)\n' "$CASES"
