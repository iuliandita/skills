#!/usr/bin/env bash
# shellcheck disable=SC2016  # fixtures pass literal $HOME text
set -euo pipefail

# Git-fixture tests for scripts/check-docs-impact.sh.

while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  [[ -z "${OUT:-}" ]] || printf '%s\n' "$OUT" >&2
  exit 1
}

g() {
  git -C "$REPO" -c user.email="test@example.com" -c user.name="test" -c commit.gpgsign=false "$@"
}

put() {
  mkdir -p "$(dirname "$REPO/$1")"
  printf '%s\n' "$2" > "$REPO/$1"
}

commit() {
  g add -A
  g commit -q -m "$1"
}

skill_md() {
  local name="$1" dep="${2:-}"
  printf -- '---\nname: %s\ndescription: x\nmetadata:\n  source: test\n' "$name"
  [[ -z "$dep" ]] || printf '  deprecated: true\n'
  printf -- '---\n\n# %s\n' "$name"
}

write_install() {
  local codex_default="${1:-\$HOME/.agents/skills}" tools="${2:-claude codex}" legacy="${3:-}"
  cat > "$REPO/install.sh" <<INST
#!/usr/bin/env bash
SUPPORTED_TOOLS=(
  $tools
)

declare -A TOOL_PATHS=(
  [claude]="\${CLAUDE_SKILLS_DIR:-\$HOME/.claude/skills}"
  [codex]="\${CODEX_SKILLS_DIR:-$codex_default}"
)

declare -A LEGACY_TOOL_PATHS=(
$legacy
)
INST
}

# Fixture: main holds an active skill "alpha", a deprecated notice "oldnotice"
# (listed in the manifest), install.sh, and the docs. Leaves HEAD on branch
# "feature" at the base commit; v0 tags the base.
new_fixture() {
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts"
  g init -q
  g symbolic-ref HEAD refs/heads/main
  cp "$ROOT/scripts/check-docs-impact.sh" "$REPO/scripts/check-docs-impact.sh"
  put skills/alpha/SKILL.md "$(skill_md alpha)"
  put skills/oldnotice/SKILL.md "$(skill_md oldnotice dep)"
  put skills/alpha/references/output-contract.md "contract"
  put migrations.json '{
  "skills": {
    "oldnotice": {
      "action": "merge"
    }
  }
}'
  write_install
  put README.md "readme"
  put INSTALL.md "install"
  put MIGRATION.md "migration"
  put CHANGELOG.md "changelog"
  commit "chore: init"
  g tag v0
  g checkout -q -b feature
}

# run_check [args...]: sets STATUS and OUT.
run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && BASE_REF=main bash scripts/check-docs-impact.sh "$@" 2>&1)" || STATUS=$?
}

expect_fail() {
  local label="$1" needle="$2"
  (( STATUS != 0 )) || fail "$label: expected failure, got exit 0"
  [[ "$OUT" == *"$needle"* ]] || fail "$label: output missing '$needle'"
}

expect_pass() {
  (( STATUS == 0 )) || fail "$1: expected exit 0, got $STATUS"
}

# --- negative cases ---
new_fixture
g rm -q -r skills/alpha
commit "refactor: drop alpha"
run_check
expect_fail "active skill deleted, no manifest" "R1"

new_fixture
g mv skills/alpha skills/beta
put migrations.json '{ "skills": {
  "alpha": { "action": "rename" },
  "oldnotice": { "action": "merge" } } }'
commit "refactor: rename alpha"
run_check
expect_fail "rename without MIGRATION.md change" "MIGRATION.md"

new_fixture
g rm -q -r skills/alpha
put migrations.json '{ "skills": { "alpha": { "action": "merge" } } }'
g add -A
g commit -q -m "refactor: drop alpha" -m "Docs-Impact: none - this is a long and specific enough reason"
run_check
expect_fail "trailer must not satisfy R1" "R1"

new_fixture
write_install '$HOME/.agents/skills' "claude"
commit "feat: drop codex"
run_check
expect_fail "tool removed without INSTALL line" "R2"

new_fixture
write_install '$HOME/.agents/skills' "claude"
put INSTALL.md "install
unrelated edit"
g add -A
g commit -q -m "feat: drop codex" -m "Docs-Impact: none - this is a long and specific enough reason"
run_check
expect_fail "trailer must not satisfy R2" "R2"

new_fixture
write_install '$HOME/.codex/skills'
commit "feat: move codex default"
run_check
expect_fail "TOOL_PATHS default changed without legacy entry" "TOOL_PATHS"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
commit "fix: tweak installer"
run_check
expect_fail "install.sh change without docs or trailer" "R3"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
g add -A
g commit -q -m "fix: tweak installer" -m "Docs-Impact: none - internal"
run_check
expect_fail "generic trailer 'internal'" "R3"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
g add -A
g commit -q -m "fix: tweak installer" -m "Docs-Impact: none - n/a"
run_check
expect_fail "short trailer" "R3"

# valid trailer on a commit before the merge base is outside the range
new_fixture
g checkout -q main
put extra.txt "x"
g add -A
g commit -q -m "chore: earlier" -m "Docs-Impact: none - this is a long and specific enough reason"
g checkout -q feature
g merge -q --no-edit main
put install.sh "$(cat "$REPO/install.sh")
# tweak"
commit "fix: tweak installer"
run_check
expect_fail "trailer outside the range" "R3"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
put skills/alpha/references/output-contract.md "regenerated contract"
commit "fix: tweak installer"
run_check
expect_fail "generated skills copy is not docs" "R3"

new_fixture
put scripts/check-new.sh "#!/usr/bin/env bash"
commit "ci: add gate"
run_check
expect_fail "new gate script without README" "R4"

new_fixture
g rm -q -r skills/alpha
put migrations.json '{ "skills": { "alpha": { "action": "merge" } } }'
put MIGRATION.md "migration
alpha removed"
commit "refactor: drop alpha"
run_check --release v0
expect_fail "release: skill missing from CHANGELOG" "CHANGELOG.md"

new_fixture
g checkout -q --orphan orphan
g rm -rq --cached . > /dev/null 2>&1 || true
put orphan.md "unrelated"
commit "chore: unrelated root"
run_check
expect_fail "no merge-base" "merge-base"

# --- positive cases ---
new_fixture
g rm -q -r skills/oldnotice
put migrations.json '{ "skills": { "oldnotice": { "action": "merge" } } }'
commit "chore: retire notice"
run_check
expect_pass "deleting an already-deprecated notice"

new_fixture
g mv skills/alpha skills/beta
put migrations.json '{ "skills": { "alpha": { "action": "rename" }, "oldnotice": { "action": "merge" } } }'
put MIGRATION.md "migration
alpha renamed to beta"
commit "refactor: rename alpha"
run_check
expect_pass "rename with manifest and MIGRATION.md"

new_fixture
g rm -q -r skills/alpha
put migrations.json '{ "skills": { "alpha": { "action": "merge" } } }'
put MIGRATION.md "migration
alpha removed"
put CHANGELOG.md "changelog
- removed alpha"
commit "refactor: drop alpha"
run_check --release v0
expect_pass "release: skill in CHANGELOG"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
put INSTALL.md "install
updated"
commit "fix: tweak installer"
run_check
expect_pass "install.sh change with INSTALL.md change"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
g add -A
g commit -q -m "fix: tweak installer" -m "Docs-Impact: none - comment-only change with no user-visible effect"
run_check
expect_pass "install.sh change with specific trailer"

new_fixture
write_install '$HOME/.agents/skills' "claude"
put INSTALL.md "install
codex is no longer a supported target"
commit "feat: drop codex"
run_check
expect_pass "tool removal with INSTALL.md line"

new_fixture
write_install '$HOME/.codex/skills' "claude codex" '  [codex]="$HOME/.agents/skills"'
put INSTALL.md "install
updated"
commit "feat: move codex default"
run_check
expect_pass "TOOL_PATHS default change with legacy entry"

new_fixture
put scripts/check-new.sh "#!/usr/bin/env bash"
put README.md "readme
gate documented"
commit "ci: add gate"
run_check
expect_pass "new gate script with README change"

new_fixture
put install.sh "$(cat "$REPO/install.sh")
# tweak"
commit "fix: tweak installer"
run_check --release v0
expect_pass "release: R3 is a warning"
[[ "$OUT" == *"WARN"* ]] || fail "release: R3 warning not printed"

new_fixture
g checkout -q main
OUT="$(cd "$REPO" && BASE_REF=main bash scripts/check-docs-impact.sh 2>&1)" || fail "base == HEAD should skip"
[[ "$OUT" == *"skipped"* ]] || fail "base == HEAD: no skipped message"

new_fixture
STATUS=0
OUT="$(cd "$REPO" && BASE_REF=does-not-exist bash scripts/check-docs-impact.sh 2>&1)" || STATUS=$?
expect_pass "unresolvable base"
[[ "$OUT" == *"skipped"* ]] || fail "unresolvable base: no skipped message"

printf 'docs-impact tests passed (%d cases)\n' "$CASES"
