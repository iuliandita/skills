#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/check-protected-overlay.sh.

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

OVERLAYS=(cluster-health kubernetes-health)

# Fixture: both overlays ignored, each holding one untracked private file.
new_fixture() {
  local skill
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts"
  cp "$ROOT/scripts/check-protected-overlay.sh" "$REPO/scripts/check-protected-overlay.sh"
  git -C "$REPO" init -q
  for skill in "${OVERLAYS[@]}"; do
    mkdir -p "$REPO/skills/$skill/protected"
    printf 'private\n' > "$REPO/skills/$skill/protected/registry.md"
    printf 'skills/%s/protected/\n' "$skill" >> "$REPO/.gitignore"
  done
  git -C "$REPO" add .gitignore
}

commit() {
  git -C "$REPO" -c user.email="test@example.com" -c user.name="test" -c commit.gpgsign=false commit -q -m fixture
}

run_check() {
  run_gate bash "$REPO/scripts/check-protected-overlay.sh"
}

new_fixture
run_check
expect_pass "ignored and untracked overlays"

for skill in "${OVERLAYS[@]}"; do
  new_fixture
  grep -v "skills/$skill/protected/" "$REPO/.gitignore" > "$REPO/.gitignore.new"
  mv "$REPO/.gitignore.new" "$REPO/.gitignore"
  run_check
  expect_fail "$skill overlay not ignored" "skills/$skill/protected is not gitignored"

  new_fixture
  git -C "$REPO" add -f "skills/$skill/protected/registry.md"
  commit
  run_check
  expect_fail "$skill overlay file committed" "protected $skill files are tracked"
  [[ "$OUT" == *"skills/$skill/protected/registry.md"* ]] || fail "$skill: tracked file not named"

  # A staged removal is out of the index, so only the staged check sees it.
  git -C "$REPO" rm -q --cached "skills/$skill/protected/registry.md"
  run_check
  expect_fail "$skill overlay change staged" "protected $skill files are staged"
  [[ "$OUT" != *"are tracked"* ]] || fail "$skill: staged removal reported as tracked"
done

printf 'protected-overlay tests passed (%d cases)\n' "$CASES"
