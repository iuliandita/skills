#!/usr/bin/env bash
set -euo pipefail

# Reproduces the CI shape from issue #211: a full clone (actions/checkout
# fetch-depth 0) with a PR merge ref checked out as HEAD, built by merging
# the feature branch onto the main tip the PR last synced with (BRANCH_POINT)
# while main has since advanced further (NEW_MAIN). A --depth=1 re-fetch of
# origin/main in that state shallows the whole clone and severs the parent
# link back to BRANCH_POINT, so merge-base(HEAD, origin/main) fails and a
# naive fallback ends up diffing against unrelated old history. Asserts the
# fetch never shallows a full clone and that the refiner phase-1 guard fails
# loudly instead of falling back to a non-ancestor tip when merge-base can't
# be computed.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

git_q() {
  git -C "$1" -c user.email="test@example.com" -c user.name="test" -c commit.gpgsign=false "${@:2}"
}

write_file() {
  local file="$1" body="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$body" > "$file"
}

# Builds a bare origin with:
#   main:    init -> old-phase1 (pre-branch, matches phase-1 subject) -> BRANCH_POINT
#            BRANCH_POINT -> main-advance-1 -> main-advance-2 (NEW_MAIN)
#   feature: branched at BRANCH_POINT, one harmless commit
# Sets BARE_DIR, BRANCH_POINT_SHA, NEW_MAIN_SHA, FEATURE_SHA.
build_base_repo() {
  local tmp="$1" src="$1/src"
  BARE_DIR="$tmp/origin.git"
  git init -q --bare "$BARE_DIR"

  mkdir -p "$src"
  git_q "$src" init -q
  git_q "$src" symbolic-ref HEAD refs/heads/main
  write_file "$src/README.md" "fixture"
  git_q "$src" add -A
  git_q "$src" commit -q -m "chore: initial commit"

  write_file "$src/skills/skill-refiner/SKILL.md" "old phase-1 content"
  git_q "$src" add -A
  git_q "$src" commit -q -m "refactor(skill-refiner): iteration 0"
  BRANCH_POINT_SHA="$(git_q "$src" rev-parse HEAD)"

  git_q "$src" checkout -qb feature
  write_file "$src/feature-work.md" "feature work"
  git_q "$src" add -A
  git_q "$src" commit -q -m "feat: feature work"
  FEATURE_SHA="$(git_q "$src" rev-parse HEAD)"

  git_q "$src" checkout -q main
  write_file "$src/main-1.md" "main advance 1"
  git_q "$src" add -A
  git_q "$src" commit -q -m "chore: main advance 1"
  write_file "$src/main-2.md" "main advance 2"
  git_q "$src" add -A
  git_q "$src" commit -q -m "chore: main advance 2"
  NEW_MAIN_SHA="$(git_q "$src" rev-parse HEAD)"

  git_q "$src" remote add origin "$BARE_DIR"
  git_q "$src" push -q origin main feature
  git_q "$BARE_DIR" symbolic-ref HEAD refs/heads/main
}

# Clones BARE_DIR into $1/clone as a full clone, matching actions/checkout
# with fetch-depth 0: origin/main already sits at NEW_MAIN_SHA with full
# history.
clone_fixture() {
  local tmp="$1" clone="$1/clone"
  git clone -q "$BARE_DIR" "$clone"
  mkdir -p "$clone/scripts"
  cp "$ROOT/scripts/check-whitespace.sh" "$clone/scripts/check-whitespace.sh"
  cp "$ROOT/scripts/check-refiner-phase1-guard.sh" "$clone/scripts/check-refiner-phase1-guard.sh"
  chmod +x "$clone/scripts/check-whitespace.sh" "$clone/scripts/check-refiner-phase1-guard.sh"
  printf '%s\n' "$clone"
}

# Checks out a synthetic PR merge ref (feature merged onto the main tip the
# PR last synced with) as a detached HEAD, like GitHub's refs/pull/N/merge
# when main has advanced further since that sync.
checkout_merge_ref() {
  local clone="$1" onto="${2:-$BRANCH_POINT_SHA}"
  git_q "$clone" checkout -q "$onto"
  git_q "$clone" merge -q --no-ff -m "merge: pr into main" "$FEATURE_SHA"
}

test_full_clone_stays_full_and_guard_passes() {
  local tmp clone status merge_base_before merge_base_after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"
  [[ "$(git_q "$clone" rev-parse origin/main)" == "$NEW_MAIN_SHA" ]] \
    || fail "fixture clone did not start with origin/main at the advanced main tip"
  checkout_merge_ref "$clone"

  status=0
  (cd "$clone" && BASE_REF=main bash scripts/check-whitespace.sh) >/dev/null || status=$?
  (( status == 0 )) || fail "check-whitespace.sh failed on a clean full-clone PR merge ref"

  if [[ "$(git_q "$clone" rev-parse --is-shallow-repository)" != "false" ]]; then
    fail "check-whitespace.sh shallowed a full clone"
  fi

  merge_base_before="$(git_q "$clone" merge-base HEAD origin/main)"
  [[ "$merge_base_before" == "$BRANCH_POINT_SHA" ]] \
    || fail "merge-base after check-whitespace.sh is $merge_base_before, expected $BRANCH_POINT_SHA"

  status=0
  (cd "$clone" && BASE_REF=main bash scripts/check-refiner-phase1-guard.sh) >/dev/null || status=$?
  (( status == 0 )) || fail "phase-1 guard failed on a clean PR merge ref (old history false positive?)"

  merge_base_after="$(git_q "$clone" merge-base HEAD origin/main)"
  [[ "$merge_base_after" == "$merge_base_before" ]] \
    || fail "merge-base changed across checks: $merge_base_before -> $merge_base_after"

  rm -rf "$tmp"
  trap - RETURN
}

test_phase1_commit_touching_immutable_path_fails() {
  local tmp clone status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"
  checkout_merge_ref "$clone"

  write_file "$clone/skills/skill-refiner/SKILL.md" "phase-1 iteration touching the immutable set"
  git_q "$clone" add -A
  git_q "$clone" commit -q -m "refactor(skill-refiner): iteration 1"

  status=0
  output="$(cd "$clone" && BASE_REF=main bash scripts/check-refiner-phase1-guard.sh 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "guard passed despite a phase-1 commit touching skills/skill-refiner"; }
  [[ "$output" == *"skills/skill-refiner/SKILL.md"* ]] \
    || { printf '%s\n' "$output" >&2; fail "guard did not name the offending file"; }

  rm -rf "$tmp"
  trap - RETURN
}

test_unrelated_history_base_fails_loudly() {
  local tmp clone status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"

  git_q "$clone" checkout -q --orphan orphan-head
  git_q "$clone" rm -rq --cached . >/dev/null 2>&1 || true
  write_file "$clone/orphan.md" "unrelated history"
  git_q "$clone" add -A
  git_q "$clone" commit -q -m "chore: unrelated root commit"

  status=0
  output="$(cd "$clone" && BASE_REF=main bash scripts/check-refiner-phase1-guard.sh 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "guard passed on an orphan/unrelated history base"; }
  [[ -n "$output" ]] || fail "guard failed silently on an unrelated history base"

  rm -rf "$tmp"
  trap - RETURN
}

test_full_clone_stays_full_and_guard_passes
test_phase1_commit_touching_immutable_path_fails
test_unrelated_history_base_fails_loudly
printf 'CI base check tests passed (3 cases)\n'
