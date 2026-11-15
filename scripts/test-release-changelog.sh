#!/usr/bin/env bash
set -euo pipefail

# Git-fixture tests for scripts/check-release-changelog.sh.

while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Fixture repos must not pick up the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=./scripts/gate-test-lib.sh
source "$ROOT/scripts/gate-test-lib.sh"

g() {
  git -C "$REPO" -c user.email="test@example.com" -c user.name="test" -c commit.gpgsign=false "$@"
}

# changelog <section>...: each section is "X.Y.Z" (with notes) or "X.Y.Z:empty".
changelog() {
  local section version
  printf '# Changelog\n\n## [Unreleased]\n'
  for section in "$@"; do
    version="${section%%:*}"
    printf '\n## [%s] - 2026-01-01\n' "$version"
    [[ "$section" == *":empty" ]] || printf '\n### Bug Fixes\n\n* note for %s.\n' "$version"
  done
  printf '\n[Unreleased]: https://example.com/compare/v%s...HEAD\n' "${1%%:*}"
}

commit() {
  g add -A
  g commit -q -m "$1"
}

# Fixture: main holds release 1.0.0, tagged v1.0.0. Leaves HEAD on branch
# "release", one commit ahead, like the merge ref of a pull request into main.
new_fixture() {
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts"
  g init -q
  g symbolic-ref HEAD refs/heads/main
  cp "$ROOT/scripts/check-release-changelog.sh" "$ROOT/scripts/changelog-notes.sh" "$REPO/scripts/"
  changelog 1.0.0 > "$REPO/CHANGELOG.md"
  commit "chore(release): 1.0.0"
  g tag v1.0.0
  g checkout -q -b release
  printf 'work\n' > "$REPO/work.md"
  commit "fix: work"
}

# run_check [args...]: sets STATUS and OUT. BASE_REF is main, as on a release PR.
run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && BASE_REF=main bash scripts/check-release-changelog.sh "$@" 2>&1)" || STATUS=$?
}

# --- negative cases ---
new_fixture
run_check
expect_fail "unchanged changelog" "not newer than v1.0.0"

new_fixture
changelog 1.1.0:empty 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
run_check
expect_fail "empty section" "no release notes"

# A tag that is not merged into the base still blocks its version.
new_fixture
changelog 1.1.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
g tag v1.1.0
run_check
expect_fail "existing tag" "tag v1.1.0 already exists"

new_fixture
changelog 0.9.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 0.9.0"
run_check
expect_fail "older version" "not newer than v1.0.0"

# Numeric, not lexical: 1.2.0 is older than 1.10.0.
new_fixture
g tag v1.10.0 main
changelog 1.2.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.2.0"
run_check
expect_fail "numeric comparison" "not newer than v1.10.0"

new_fixture
changelog 1.1.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
g tag -d v1.0.0 >/dev/null
run_check
expect_fail "no reachable tag" "no vX.Y.Z tag is reachable"

# A shallow clone has the tag name but not its commit in the base's history.
new_fixture
changelog 1.1.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
g checkout -q main
printf 'later\n' > "$REPO/later.md"
commit "chore: later main commit"
git clone -q --depth 1 --no-tags --branch main "file://$REPO" "$TMP/shallow"
REPO="$TMP/shallow"
run_check
expect_fail "shallow clone" "no vX.Y.Z tag is reachable"

# Only strict vX.Y.Z tags count as a previous version.
new_fixture
changelog 1.1.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
g tag -d v1.0.0 >/dev/null
g tag v1.0.0-rc1 main
g tag nightly main
run_check
expect_fail "non-version tags only" "no vX.Y.Z tag is reachable"

new_fixture
printf '# Changelog\n\n## [Unreleased]\n' > "$REPO/CHANGELOG.md"
commit "docs: drop sections"
run_check
expect_fail "no numbered section" "no numbered"

new_fixture
STATUS=0
OUT="$(cd "$REPO" && bash scripts/check-release-changelog.sh does-not-exist 2>&1)" || STATUS=$?
expect_fail "unresolvable base" "does not resolve"

new_fixture
run_check --previous-tag
expect_fail "--previous-tag without a base" "requires a base"

# --- positive cases ---
new_fixture
changelog 1.1.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 1.1.0"
run_check
expect_pass "new non-empty section"
[[ "$OUT" == *"(v1.0.0 -> v1.1.0)"* ]] || fail "new non-empty section: versions not reported"

# The base is found as origin/<base> when no local branch exists, as in CI.
new_fixture
changelog 2.0.0 1.0.0 > "$REPO/CHANGELOG.md"
commit "chore(release): 2.0.0"
g update-ref refs/remotes/origin/main main
g checkout -q --detach
g branch -q -D main
run_check
expect_pass "base resolved through origin/main"

new_fixture
g tag v1.0.1 main
run_check --previous-tag main
expect_pass "--previous-tag"
[[ "$OUT" == "v1.0.1" ]] || fail "--previous-tag: printed '$OUT', expected v1.0.1"

# Only pull requests into main are releases.
new_fixture
for ref in develop ""; do
  STATUS=0
  OUT="$(cd "$REPO" && BASE_REF="$ref" bash scripts/check-release-changelog.sh 2>&1)" || STATUS=$?
  expect_pass "base '${ref}' is skipped"
  [[ "$OUT" == *"skipped"* ]] || fail "base '${ref}': no skipped message"
done

# An explicit base is always checked.
new_fixture
STATUS=0
OUT="$(cd "$REPO" && BASE_REF=develop bash scripts/check-release-changelog.sh main 2>&1)" || STATUS=$?
expect_fail "explicit base overrides BASE_REF" "not newer than v1.0.0"

printf 'release-changelog tests passed (%d cases)\n' "$CASES"
