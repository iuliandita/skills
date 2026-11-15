#!/usr/bin/env bash
# shellcheck disable=SC2016  # the git stub is written with literal $* and $@
set -euo pipefail

# Git-fixture tests for scripts/check-contract-sync.sh.

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

# Fixture: one skill "alpha" with generated copies of both shared files.
new_fixture() {
  local f
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts" "$REPO/skills/_shared" "$REPO/skills/alpha/references"
  for f in check-contract-sync.sh gen-contract-refs.sh contract-lib.sh skill-lib.sh skill-frontmatter.py; do
    cp "$ROOT/scripts/$f" "$REPO/scripts/$f"
  done
  printf '# Output contract\n\nShared text.\n' > "$REPO/skills/_shared/output-contract.md"
  printf '# Agent hygiene\n\nShared text.\n' > "$REPO/skills/_shared/agent-hygiene.md"
  printf -- '---\nname: alpha\ndescription: fixture\n---\n\n# Alpha\n' > "$REPO/skills/alpha/SKILL.md"
  git -C "$REPO" init -q
  (cd "$REPO" && bash scripts/gen-contract-refs.sh >/dev/null)
}

run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && bash scripts/check-contract-sync.sh 2>&1)" || STATUS=$?
}

new_fixture
run_check
(( STATUS == 0 )) || fail "clean fixture: expected exit 0, got $STATUS"

new_fixture
printf 'drifted\n' >> "$REPO/skills/alpha/references/output-contract.md"
run_check
expect_fail "drifted generated copy" "drifted from source"

new_fixture
printf 'Read skills/_shared/output-contract.md first.\n' > "$REPO/skills/alpha/references/notes.md"
run_check
expect_fail "runtime _shared reference" "references/notes.md"

# A line that quotes a generated file's path is not one of the generated files.
new_fixture
printf 'Copy of skills/_shared/output-contract.md, see /references/output-contract.md: section 2.\n' \
  > "$REPO/skills/alpha/references/notes.md"
run_check
expect_fail "runtime _shared reference next to a quoted generated path" "references/notes.md"

# A search that cannot run is a failure, not "no references".
new_fixture
mkdir -p "$TMP/stub"
printf '#!/usr/bin/env bash\n[[ " $* " != *" grep "* ]] || exit 2\nexec "%s" "$@"\n' "$(command -v git)" > "$TMP/stub/git"
chmod +x "$TMP/stub/git"
STATUS=0
OUT="$(cd "$REPO" && PATH="$TMP/stub:$PATH" bash scripts/check-contract-sync.sh 2>&1)" || STATUS=$?
expect_fail "git grep error" "git grep"

printf 'contract-sync tests passed (%d cases)\n' "$CASES"
