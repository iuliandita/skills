#!/usr/bin/env bash
set -euo pipefail

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

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
  cp "$ROOT/scripts/check-docs-impact.sh" "$clone/scripts/check-docs-impact.sh"
  chmod +x "$clone/scripts/check-whitespace.sh" "$clone/scripts/check-refiner-phase1-guard.sh" "$clone/scripts/check-docs-impact.sh"
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
  local target="$1" tmp clone status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"
  checkout_merge_ref "$clone"

  write_file "$clone/$target" "phase-1 iteration touching the immutable set"
  git_q "$clone" add -A "$target"
  git_q "$clone" commit -q -m "refactor(skill-refiner): iteration 1"

  status=0
  output="$(cd "$clone" && BASE_REF=main bash scripts/check-refiner-phase1-guard.sh 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "guard passed despite a phase-1 commit touching $target"; }
  [[ "$output" == *"$target"* ]] \
    || { printf '%s\n' "$output" >&2; fail "guard did not name the offending file $target"; }

  rm -rf "$tmp"
  trap - RETURN
}

# A branch commit that drops an entry from the guard's list must not let a
# later phase-1 commit edit that path: the base revision's list still applies.
test_guard_list_shrink_uses_base_list() {
  local tmp clone status output guard="scripts/check-refiner-phase1-guard.sh"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"
  git_q "$clone" add "$guard"
  git_q "$clone" commit -q -m "chore: track the guard"
  git_q "$clone" checkout -qb shrink

  sed -i '/^  "scripts\/lint-skills.sh"$/d' "$clone/$guard"
  git_q "$clone" commit -qam "chore: relax the guard"
  write_file "$clone/scripts/lint-skills.sh" "weakened lint"
  git_q "$clone" add scripts/lint-skills.sh
  git_q "$clone" commit -q -m "refactor(skill-refiner): iteration 1"

  status=0
  output="$(cd "$clone" && BASE_REF=main bash "$guard" 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "guard passed after its list was shrunk on the branch"; }
  [[ "$output" == *"scripts/lint-skills.sh"* ]] \
    || { printf '%s\n' "$output" >&2; fail "guard did not name scripts/lint-skills.sh"; }

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

test_docs_impact_passes_on_merge_ref() {
  local tmp clone status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  build_base_repo "$tmp"
  clone="$(clone_fixture "$tmp")"
  checkout_merge_ref "$clone"

  status=0
  output="$(cd "$clone" && BASE_REF=main bash scripts/check-docs-impact.sh 2>&1)" || status=$?
  (( status == 0 )) || { printf '%s\n' "$output" >&2; fail "docs-impact check failed on a clean PR merge ref"; }

  rm -rf "$tmp"
  trap - RETURN
}

test_docs_impact_unrelated_history_fails_loudly() {
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
  output="$(cd "$clone" && BASE_REF=main bash scripts/check-docs-impact.sh 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "docs-impact check passed on an orphan/unrelated history base"; }
  [[ "$output" == *"merge-base"* ]] || { printf '%s\n' "$output" >&2; fail "docs-impact check did not report the missing merge-base"; }

  rm -rf "$tmp"
  trap - RETURN
}

# Reproduces a push to main (issue #297): a --no-ff merge whose branch adds
# trailing whitespace lands on main and origin/main already points at it, so
# only BASE_SHA (the push event's "before") gives the checks a real range.
# Sets PUSH_CLONE and PRE_PUSH_SHA.
push_merge_to_main() {
  local tmp="$1"
  build_base_repo "$tmp"
  PUSH_CLONE="$(clone_fixture "$tmp")"
  PRE_PUSH_SHA="$(git_q "$PUSH_CLONE" rev-parse HEAD)"
  [[ "$PRE_PUSH_SHA" == "$NEW_MAIN_SHA" ]] || fail "fixture clone did not start on the main tip"

  git_q "$PUSH_CLONE" checkout -qb dirty
  printf 'trailing space \n' > "$PUSH_CLONE/dirty.md"
  git_q "$PUSH_CLONE" add dirty.md
  git_q "$PUSH_CLONE" commit -q -m "docs: dirty note"
  git_q "$PUSH_CLONE" checkout -q main
  git_q "$PUSH_CLONE" merge -q --no-ff -m "merge: dirty into main" dirty
  git_q "$PUSH_CLONE" update-ref refs/remotes/origin/main HEAD
}

test_push_base_sha_checks_the_pushed_range() {
  local tmp status output range
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  push_merge_to_main "$tmp"
  range="$PRE_PUSH_SHA..HEAD"

  status=0
  output="$(cd "$PUSH_CLONE" && bash scripts/check-whitespace.sh 2>&1)" || status=$?
  (( status == 0 )) || { printf '%s\n' "$output" >&2; fail "fixture: whitespace check without BASE_SHA was expected to miss the merge"; }

  status=0
  output="$(cd "$PUSH_CLONE" && BASE_SHA="$PRE_PUSH_SHA" bash scripts/check-whitespace.sh 2>&1)" || status=$?
  (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "whitespace check passed a pushed merge that adds trailing whitespace"; }
  [[ "$output" == *"dirty.md"* ]] || { printf '%s\n' "$output" >&2; fail "whitespace check did not name the offending file"; }

  status=0
  output="$(cd "$PUSH_CLONE" && BASE_SHA="$PRE_PUSH_SHA" bash scripts/check-refiner-phase1-guard.sh 2>&1)" || status=$?
  (( status == 0 )) || { printf '%s\n' "$output" >&2; fail "phase-1 guard failed on a clean pushed range"; }
  [[ "$output" == *"($range)"* ]] || { printf '%s\n' "$output" >&2; fail "phase-1 guard did not check the pushed range"; }

  status=0
  output="$(cd "$PUSH_CLONE" && BASE_SHA="$PRE_PUSH_SHA" bash scripts/check-docs-impact.sh 2>&1)" || status=$?
  (( status == 0 )) || { printf '%s\n' "$output" >&2; fail "docs-impact check failed on a clean pushed range"; }
  [[ "$output" == *"($range,"* ]] || { printf '%s\n' "$output" >&2; fail "docs-impact check did not check the pushed range"; }

  rm -rf "$tmp"
  trap - RETURN
}

test_push_zero_base_sha_keeps_fallback() {
  local tmp status output zero="0000000000000000000000000000000000000000"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  push_merge_to_main "$tmp"

  status=0
  output="$(cd "$PUSH_CLONE" && BASE_SHA="$zero" bash scripts/check-whitespace.sh 2>&1)" || status=$?
  if (( status != 0 )) || [[ "$output" != *"(last commit)"* ]]; then
    printf '%s\n' "$output" >&2
    fail "whitespace check did not treat an all-zero BASE_SHA as unset"
  fi

  for script in check-refiner-phase1-guard.sh check-docs-impact.sh; do
    status=0
    output="$(cd "$PUSH_CLONE" && BASE_SHA="$zero" bash "scripts/$script" 2>&1)" || status=$?
    if (( status != 0 )) || [[ "$output" != *"No comparable base"* ]]; then
      printf '%s\n' "$output" >&2
      fail "$script did not treat an all-zero BASE_SHA as unset"
    fi
  done

  rm -rf "$tmp"
  trap - RETURN
}

test_push_missing_base_sha_fails_loudly() {
  local tmp status output missing="1111111111111111111111111111111111111111"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  push_merge_to_main "$tmp"

  for script in check-whitespace.sh check-refiner-phase1-guard.sh check-docs-impact.sh; do
    status=0
    output="$(cd "$PUSH_CLONE" && BASE_SHA="$missing" bash "scripts/$script" 2>&1)" || status=$?
    (( status != 0 )) || { printf '%s\n' "$output" >&2; fail "$script passed with a BASE_SHA missing from the clone"; }
    [[ "$output" == *"BASE_SHA"* ]] || { printf '%s\n' "$output" >&2; fail "$script did not report the missing BASE_SHA"; }
  done

  rm -rf "$tmp"
  trap - RETURN
}

test_full_clone_stays_full_and_guard_passes
test_phase1_commit_touching_immutable_path_fails skills/skill-refiner/SKILL.md
test_phase1_commit_touching_immutable_path_fails scripts/skill-lib.sh
test_guard_list_shrink_uses_base_list
test_unrelated_history_base_fails_loudly
test_docs_impact_passes_on_merge_ref
test_docs_impact_unrelated_history_fails_loudly
test_push_base_sha_checks_the_pushed_range
test_push_zero_base_sha_keeps_fallback
test_push_missing_base_sha_fails_loudly
printf 'CI base check tests passed (10 cases)\n'
