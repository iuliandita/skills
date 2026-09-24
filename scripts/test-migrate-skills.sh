#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATOR="$ROOT/scripts/migrate-skills.py"

# Git hooks export GIT_DIR and friends; fixture runs must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

SAFE_PATH="$(for cmd in python3 git sha256sum; do dirname "$(command -v "$cmd")"; done | awk '!seen[$0]++' | paste -sd:):/usr/bin:/bin"
TEST_HOME="$(mktemp -d)"
LOCK_FILE="$TEST_HOME/.local/state/iuliandita-skills/install.lock"
HOLDER=""
trap '[[ -z "$HOLDER" ]] || kill "$HOLDER" 2>/dev/null || true; rm -rf "$TEST_HOME"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Every migrator run gets an allowlisted environment and the temp HOME.
run_migrator() {
  env -i HOME="$TEST_HOME" PATH="$SAFE_PATH" LANG=C \
    SKILLS_LOCK_WAIT="${LOCK_WAIT:-30}" SKILLS_MIGRATE_FAULT="${FAULT:-}" \
    python3 "$MIGRATOR" "$@"
}

hash_skill() {
  LC_ALL=C find "$1" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1
}

write_lock() {
  local dest="$1" source="$2"
  shift 2
  python3 - "$dest/.skills-lock.json" "$source" "$@" <<'PY'
import json
import pathlib
import sys

lock = pathlib.Path(sys.argv[1])
source = sys.argv[2]
skills = {}
for value in sys.argv[3:]:
    name, digest = value.split("=", 1)
    skills[name] = {"hash": digest, "provenance": "source-equal-v1"}
lock.write_text(json.dumps({"version": 1, "source": source, "skills": skills}) + "\n")
PY
}

make_fixture() {
  local tmp="$1"
  mkdir -p "$tmp/source/old" "$tmp/source/new" "$tmp/dest"
  printf '%s\n' 'old source' > "$tmp/source/old/SKILL.md"
  printf '%s\n' 'new source' > "$tmp/source/new/SKILL.md"
  printf '%s\n' 'lowercase' > "$tmp/source/old/a"
  printf '%s\n' 'uppercase' > "$tmp/source/old/B"
  printf '%s\n' 'lowercase replacement' > "$tmp/source/new/a"
  printf '%s\n' 'uppercase replacement' > "$tmp/source/new/B"
  cat > "$tmp/migrations.json" <<'JSON'
{"version":1,"transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1},"skills":{"old":{"action":"rename","replacement":"new"}}}
JSON
}

test_dry_run_and_apply() {
  local tmp old_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  cp -r "$tmp/source/old" "$tmp/dest/old"
  old_hash="$(hash_skill "$tmp/dest/old")"
  write_lock "$tmp/dest" "$tmp/source" "old=$old_hash" "keep=$old_hash"

  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" > "$tmp/dry-run"
  [[ -d "$tmp/dest/old" ]] || fail "dry run retired old skill"
  [[ ! -e "$tmp/dest/new" ]] || fail "dry run installed replacement"
  grep -q 'DRY-RUN.*old.*new' "$tmp/dry-run" || fail "dry run did not report rename"

  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/apply"
  [[ ! -e "$tmp/dest/old" ]] || fail "apply kept migrated old skill"
  [[ -f "$tmp/dest/new/SKILL.md" ]] || fail "apply did not install replacement"
  [[ -e "$tmp/.skills-backups/dest/old" ]] || fail "apply did not create external backup"
  python3 - "$tmp/dest/.skills-lock.json" <<'PY'
import json
import sys
skills = json.load(open(sys.argv[1], encoding="utf-8"))["skills"]
assert "old" not in skills
assert "new" in skills
assert "keep" in skills
PY
  python3 - "$tmp/dest/.skills-lock.json" "$(hash_skill "$tmp/dest/new")" <<'PY'
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))["skills"]["new"]
assert record["hash"] == sys.argv[2]
PY

  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/rerun"
  grep -q 'already absent' "$tmp/rerun" || fail "rerun was not idempotent"
  rm -rf "$tmp"
  trap - RETURN
}

test_modified_unowned_and_collision_are_skipped() {
  local tmp old_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  cp -r "$tmp/source/old" "$tmp/dest/old"
  old_hash="$(hash_skill "$tmp/dest/old")"
  printf '%s\n' 'changed' >> "$tmp/dest/old/SKILL.md"
  write_lock "$tmp/dest" "$tmp/source" "old=$old_hash"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/modified"
  [[ -d "$tmp/dest/old" ]] || fail "modified old skill was retired"
  grep -q 'ownership hash differs' "$tmp/modified" || fail "modified skill skip was not reported"

  cp -r "$tmp/source/old" "$tmp/dest/unowned"
  mv "$tmp/dest/old" "$tmp/dest/old-modified"
  cp -r "$tmp/source/old" "$tmp/dest/old"
  printf '%s\n' '{"version":1,"source":"/wrong/source","skills":{}}' > "$tmp/dest/.skills-lock.json"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/unowned"
  [[ -d "$tmp/dest/old" ]] || fail "unowned old skill was retired"
  grep -q 'lock source' "$tmp/unowned" || fail "unowned skip was not reported"

  old_hash="$(hash_skill "$tmp/dest/old")"
  write_lock "$tmp/dest" "$tmp/source" "old=$old_hash"
  mkdir -p "$tmp/dest/new"
  printf '%s\n' 'foreign' > "$tmp/dest/new/SKILL.md"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/collision"
  [[ -d "$tmp/dest/old" ]] || fail "collision retired old skill"
  grep -q 'replacement collision' "$tmp/collision" || fail "collision skip was not reported"

  rm -rf "$tmp/dest/new"
  ln -s "$tmp/source/new/SKILL.md" "$tmp/dest/old/hidden-link"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/symlink"
  [[ -d "$tmp/dest/old" ]] || fail "interior symlink skill was retired"
  grep -q 'interior symlink' "$tmp/symlink" || fail "interior symlink skip was not reported"

  rm "$tmp/dest/old/hidden-link"
  mkdir "$tmp/dest/old/protected"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/overlay"
  [[ -d "$tmp/dest/old" ]] || fail "protected overlay skill was retired"
  grep -q 'protected overlay' "$tmp/overlay" || fail "protected overlay skip was not reported"
  rm -rf "$tmp"
  trap - RETURN
}

test_source_overlap_is_rejected() {
  local tmp old_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  old_hash="$(hash_skill "$tmp/source/old")"
  write_lock "$tmp/source" "$tmp/source" "old=$old_hash"
  if run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/source" --apply > "$tmp/overlap" 2>&1; then
    fail "source overlap was accepted"
  fi
  grep -q 'destination overlaps the source tree' "$tmp/overlap" || fail "source overlap failure was unclear"
  rm -rf "$tmp"
  trap - RETURN
}

test_missing_destination_is_safe_noop() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  rmdir "$tmp/dest"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" > "$tmp/missing"
  [[ ! -e "$tmp/dest" ]] || fail "migration created a missing destination"
  grep -q 'SKIP all: missing lock file' "$tmp/missing" || fail "missing destination result was unclear"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_hash_only_lock_requires_manual_migration() {
  local tmp old_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  cp -r "$tmp/source/old" "$tmp/dest/old"
  old_hash="$(hash_skill "$tmp/dest/old")"
  python3 - "$tmp/dest/.skills-lock.json" "$tmp/source" "$old_hash" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"old": sys.argv[3]}}, f)
PY
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/legacy"
  [[ -d "$tmp/dest/old" ]] || fail "legacy hash-only lock was treated as ownership"
  grep -q 'legacy lock record has no verified provenance' "$tmp/legacy" || fail "legacy manual migration guidance was missing"
  rm -rf "$tmp"
  trap - RETURN
}

test_protected_replacement_skips_only_its_mapping() {
  local tmp first_hash second_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/source/first" "$tmp/source/second" "$tmp/source/new-first/protected" "$tmp/source/new-second" "$tmp/dest"
  printf '%s\n' first > "$tmp/source/first/SKILL.md"
  printf '%s\n' second > "$tmp/source/second/SKILL.md"
  printf '%s\n' new-first > "$tmp/source/new-first/SKILL.md"
  printf '%s\n' new-second > "$tmp/source/new-second/SKILL.md"
  cat > "$tmp/migrations.json" <<'JSON'
{"version":1,"transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1},"skills":{"first":{"action":"rename","replacement":"new-first"},"second":{"action":"rename","replacement":"new-second"}}}
JSON
  cp -r "$tmp/source/first" "$tmp/dest/first"
  cp -r "$tmp/source/second" "$tmp/dest/second"
  first_hash="$(hash_skill "$tmp/dest/first")"
  second_hash="$(hash_skill "$tmp/dest/second")"
  write_lock "$tmp/dest" "$tmp/source" "first=$first_hash" "second=$second_hash"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/protected"
  [[ -d "$tmp/dest/first" ]] || fail "protected replacement mapping was retired"
  [[ ! -e "$tmp/dest/new-first" ]] || fail "protected replacement was copied"
  [[ ! -e "$tmp/dest/second" && -d "$tmp/dest/new-second" ]] || fail "clean mapping did not migrate beside protected replacement"
  grep -q 'first: replacement protected overlay exists' "$tmp/protected" || fail "protected replacement skip was not reported"
  rm -rf "$tmp"
  trap - RETURN
}

test_remove_merge_and_link_target() {
  local tmp old_hash second_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/source/one" "$tmp/source/two" "$tmp/source/new" "$tmp/canonical" "$tmp/tool"
  printf '%s\n' one > "$tmp/source/one/SKILL.md"
  printf '%s\n' two > "$tmp/source/two/SKILL.md"
  printf '%s\n' new > "$tmp/source/new/SKILL.md"
  cat > "$tmp/migrations.json" <<'JSON'
{"version":1,"transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1},"skills":{"one":{"action":"merge","replacement":"new"},"two":{"action":"remove","replacement":null}}}
JSON
  cp -r "$tmp/source/one" "$tmp/canonical/one"
  cp -r "$tmp/source/two" "$tmp/canonical/two"
  old_hash="$(hash_skill "$tmp/canonical/one")"
  second_hash="$(hash_skill "$tmp/canonical/two")"
  write_lock "$tmp/canonical" "$tmp/source" "one=$old_hash" "two=$second_hash"
  ln -s "$tmp/canonical/one" "$tmp/tool/one"
  write_lock "$tmp/tool" "$tmp/source" "one=$old_hash"

  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/canonical" --apply --preserve-shared-canonical > "$tmp/canonical-run"
  [[ -d "$tmp/canonical/one" ]] || fail "protected canonical legacy target was removed"
  [[ -d "$tmp/canonical/new" ]] || fail "canonical replacement was not installed"
  [[ -d "$tmp/canonical/two" ]] || fail "protected canonical remove target was removed"

  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/tool" --link-root "$tmp/canonical" --apply > "$tmp/link-run"
  [[ ! -e "$tmp/tool/one" ]] || fail "owned selected link was not retired"
  [[ -L "$tmp/tool/new" ]] || fail "replacement link was not created"
  [[ "$(readlink "$tmp/tool/new")" == "$tmp/canonical/new" ]] || fail "replacement link target is wrong"
  if ! find "$tmp/.skills-backups/tool/one" -path '*/one.target/SKILL.md' -type f -print -quit | grep -q .; then
    fail "link backup did not preserve target contents"
  fi

  mkdir -p "$tmp/remove-dest"
  cp -r "$tmp/source/two" "$tmp/remove-dest/two"
  second_hash="$(hash_skill "$tmp/remove-dest/two")"
  write_lock "$tmp/remove-dest" "$tmp/source" "two=$second_hash"
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/remove-dest" --apply > "$tmp/remove-run"
  [[ ! -e "$tmp/remove-dest/two" ]] || fail "owned remove action was not applied"
  rm -rf "$tmp"
  trap - RETURN
}

# Runs the fixture migration in $tmp (from the caller's scope).
mig() {
  run_migrator --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" "$@"
}

setup_owned_copy() {
  make_fixture "$1"
  cp -r "$1/source/old" "$1/dest/old"
  write_lock "$1/dest" "$1/source" "old=$(hash_skill "$1/dest/old")" "keep=$(hash_skill "$1/dest/old")"
}

lock_names() {
  python3 -c 'import json, sys; print(" ".join(sorted(json.load(open(sys.argv[1], encoding="utf-8"))["skills"])))' "$1"
}

file_mode() {
  python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"
}

# Converged: replacement installed and recorded, legacy retired into one complete backup.
assert_converged() {
  local tmp="$1" label="$2" backups
  [[ ! -e "$tmp/dest/old" && ! -L "$tmp/dest/old" ]] || fail "$label: legacy entry still present"
  [[ "$(hash_skill "$tmp/dest/new")" == "$(hash_skill "$tmp/source/new")" ]] || fail "$label: replacement differs from source"
  [[ "$(lock_names "$tmp/dest/.skills-lock.json")" == "keep new" ]] || fail "$label: lock records are $(lock_names "$tmp/dest/.skills-lock.json")"
  [[ ! -e "$tmp/.skills-migrate-staging" ]] || fail "$label: staging area left behind"
  backups="$(find "$tmp/.skills-backups/dest/old" -mindepth 1 -maxdepth 1 | wc -l)"
  (( backups == 1 )) || fail "$label: expected one backup of old, found $backups"
  [[ "$(hash_skill "$(find "$tmp/.skills-backups/dest/old" -mindepth 2 -maxdepth 2 -name old)")" == "$(hash_skill "$tmp/source/old")" ]] \
    || fail "$label: backup of old is incomplete"
}

hold_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"
  rm -f "$1"
  ( exec 8>>"$LOCK_FILE"; flock 8; touch "$1"; exec sleep 30 ) &
  HOLDER=$!
  for _ in $(seq 100); do [[ -e "$1" ]] && break; sleep 0.1; done
  [[ -e "$1" ]] || fail "lock holder did not start"
}

release_lock() {
  kill "$HOLDER"
  wait "$HOLDER" 2>/dev/null || true
  HOLDER=""
}

test_lock_write_cleans_only_its_temp() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  chmod 640 "$tmp/dest/.skills-lock.json"
  cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
  printf '%s\n' outside > "$tmp/outside"
  printf '%s\n' stale > "$tmp/dest/.skills-lock.json.tmp"
  printf '%s\n' decoy > "$tmp/dest/.skills-lock.json.decoy.tmp"
  ln -s "$tmp/outside" "$tmp/dest/.skills-lock.json.link.tmp"

  FAULT=fail-lock-write mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 2 )) || fail "failed lock write exited $status, want 2"
  cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "failed lock write changed the lock"
  [[ -d "$tmp/dest/old" ]] || fail "failed lock write retired the legacy skill"
  [[ "$(find "$tmp/dest" -maxdepth 1 -name '.skills-lock.json.*' | sort | tr '\n' ' ')" \
    == "$tmp/dest/.skills-lock.json.decoy.tmp $tmp/dest/.skills-lock.json.link.tmp $tmp/dest/.skills-lock.json.tmp " ]] \
    || fail "failed lock write left or removed temp files"

  mig --apply > "$tmp/retry"
  assert_converged "$tmp" "retry after failed lock write"
  [[ "$(file_mode "$tmp/dest/.skills-lock.json")" == 0o640 ]] || fail "lock write did not keep the lock's mode"
  [[ "$(<"$tmp/dest/.skills-lock.json.tmp")" == stale && "$(<"$tmp/dest/.skills-lock.json.decoy.tmp")" == decoy ]] \
    || fail "lock write touched unrelated temp-like files"
  [[ -L "$tmp/dest/.skills-lock.json.link.tmp" && "$(<"$tmp/outside")" == outside ]] || fail "lock write touched an unrelated symlink"
  rm -rf "$tmp"
  trap - RETURN
}

test_crash_after_promote_converges() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
  FAULT=after-promote mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 99 )) || fail "after-promote fault exited $status"
  [[ -d "$tmp/dest/new" && -d "$tmp/dest/old" ]] || fail "after-promote crash state is wrong"
  cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "lock changed before the crash point"
  mig --apply > "$tmp/retry"
  assert_converged "$tmp" "retry after promote crash"
  rm -rf "$tmp"
  trap - RETURN
}

test_crash_during_cross_device_retirement_converges() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  FAULT=force-exdev,mid-retirement mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 99 )) || fail "mid-retirement fault exited $status"
  [[ ! -e "$tmp/dest/old" ]] || fail "mid-retirement crash left a partial legacy entry at its working path"
  [[ "$(lock_names "$tmp/dest/.skills-lock.json")" == "keep new old" ]] || fail "first lock publication missing before retirement"
  [[ -d "$tmp/.skills-migrate-staging/dest/.retiring-old" ]] || fail "retirement debris is not confined to the staging area"
  mig --apply > "$tmp/retry"
  grep -q 'APPLIED prune lock record old' "$tmp/retry" || fail "retry did not prune the retired record"
  assert_converged "$tmp" "retry after mid-retirement crash"

  rm -rf "$tmp"
  tmp="$(mktemp -d)"
  setup_owned_copy "$tmp"
  FAULT=force-exdev mig --apply > "$tmp/out"
  assert_converged "$tmp" "cross-device retirement"
  rm -rf "$tmp"
  trap - RETURN
}

test_crash_after_retirement_converges() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  FAULT=after-retirement mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 99 )) || fail "after-retirement fault exited $status"
  [[ ! -e "$tmp/dest/old" ]] || fail "after-retirement crash kept the legacy entry"
  [[ "$(lock_names "$tmp/dest/.skills-lock.json")" == "keep new old" ]] || fail "after-retirement lock state is wrong"
  mig > "$tmp/preview"
  grep -q 'DRY-RUN prune lock record old' "$tmp/preview" || fail "preview did not report the stale record"
  mig --apply > "$tmp/retry"
  grep -q 'APPLIED prune lock record old' "$tmp/retry" || fail "retry did not prune the retired record"
  assert_converged "$tmp" "retry after retirement crash"
  rm -rf "$tmp"
  trap - RETURN
}

test_inserted_target_is_never_overwritten() {
  local tmp kind
  for kind in dir symlink; do
    tmp="$(mktemp -d)"
    setup_owned_copy "$tmp"
    cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
    FAULT="insert-target-$kind" mig --apply > "$tmp/out"
    grep -q 'SKIP old: replacement collision' "$tmp/out" || fail "$kind insertion was not refused"
    if [[ "$kind" == dir ]]; then
      [[ ! -L "$tmp/dest/new" && "$(<"$tmp/dest/new/SKILL.md")" == inserted && "$(find "$tmp/dest/new" -type f | wc -l)" == 1 ]] \
        || fail "inserted directory was overwritten"
    else
      [[ "$(readlink "$tmp/dest/new")" == /nonexistent-inserted-target ]] || fail "inserted symlink was overwritten"
    fi
    [[ "$(hash_skill "$tmp/dest/old")" == "$(hash_skill "$tmp/source/old")" ]] || fail "$kind insertion changed the legacy skill"
    cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "$kind insertion changed the lock"
    [[ ! -e "$tmp/.skills-migrate-staging" ]] || fail "$kind insertion left staging behind"
    rm -rf "$tmp"
  done
}

test_no_replace_unavailable_fails_closed() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
  FAULT=force-enosys mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 1 )) || fail "unavailable no-replace rename exited $status, want 1"
  grep -q 'SKIP old: atomic no-replace rename is unavailable' "$tmp/out" || fail "fail-closed reason missing"
  [[ ! -e "$tmp/dest/new" && -d "$tmp/dest/old" ]] || fail "fail-closed run changed skills"
  cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "fail-closed run changed the lock"
  [[ ! -e "$tmp/.skills-migrate-staging" ]] || fail "fail-closed run left staging behind"
  mig --apply > "$tmp/retry"
  assert_converged "$tmp" "retry after fail-closed run"
  rm -rf "$tmp"
  trap - RETURN
}

test_shared_replacement_and_protected_overlay() {
  local tmp status=0 overlay_before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"
  cat > "$tmp/migrations.json" <<'JSON'
{"version":1,"transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1},"skills":{"old":{"action":"merge","replacement":"new"},"older":{"action":"merge","replacement":"new"},"guarded":{"action":"merge","replacement":"new"}}}
JSON
  cp -r "$tmp/source/old" "$tmp/dest/old"
  cp -r "$tmp/source/old" "$tmp/dest/older"
  cp -r "$tmp/source/old" "$tmp/dest/guarded"
  write_lock "$tmp/dest" "$tmp/source" "old=$(hash_skill "$tmp/dest/old")" "older=$(hash_skill "$tmp/dest/older")" \
    "guarded=$(hash_skill "$tmp/dest/guarded")" "keep=$(hash_skill "$tmp/dest/old")"
  mkdir "$tmp/dest/guarded/protected"
  printf '%s\n' private > "$tmp/dest/guarded/protected/notes"
  overlay_before="$(cd "$tmp/dest/guarded" && find . | LC_ALL=C sort; hash_skill .)"

  FAULT=after-promote mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 99 )) || fail "shared replacement fault exited $status"
  mig --apply > "$tmp/apply"
  grep -q 'APPLIED merge old -> new' "$tmp/apply" || fail "shared replacement did not retire old"
  grep -q 'APPLIED merge older -> new' "$tmp/apply" || fail "shared replacement did not retire older"
  grep -q 'SKIP guarded: protected overlay exists' "$tmp/apply" || fail "protected overlay skip missing"
  [[ ! -e "$tmp/dest/old" && ! -e "$tmp/dest/older" ]] || fail "shared replacement kept a legacy skill"
  [[ "$(hash_skill "$tmp/dest/new")" == "$(hash_skill "$tmp/source/new")" ]] || fail "shared replacement differs from source"
  [[ "$(cd "$tmp/dest/guarded" && find . | LC_ALL=C sort; hash_skill .)" == "$overlay_before" ]] || fail "protected overlay changed"
  [[ "$(lock_names "$tmp/dest/.skills-lock.json")" == "guarded keep new" ]] || fail "shared replacement lock is wrong"
  rm -rf "$tmp"
  trap - RETURN
}

test_staging_area_clearing_is_scoped() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  mkdir -p "$tmp/.skills-migrate-staging/dest/junk" "$tmp/.skills-migrate-staging/other" "$tmp/outside"
  printf '%s\n' debris > "$tmp/.skills-migrate-staging/dest/junk/file"
  printf '%s\n' keep > "$tmp/.skills-migrate-staging/other/keep"
  printf '%s\n' outside > "$tmp/outside/file"
  ln -s "$tmp/outside" "$tmp/.skills-migrate-staging/dest/link"
  mig > "$tmp/preview"
  [[ -f "$tmp/.skills-migrate-staging/dest/junk/file" ]] || fail "preview cleared the staging area"
  mig --apply > "$tmp/out"
  [[ ! -e "$tmp/.skills-migrate-staging/dest" ]] || fail "apply did not clear its staging area"
  [[ "$(<"$tmp/.skills-migrate-staging/other/keep")" == keep ]] || fail "apply cleared another destination's staging area"
  [[ "$(<"$tmp/outside/file")" == outside ]] || fail "staging cleanup followed a symlink"

  rm -rf "$tmp"
  tmp="$(mktemp -d)"
  setup_owned_copy "$tmp"
  mkdir "$tmp/elsewhere"
  ln -s "$tmp/elsewhere" "$tmp/.skills-migrate-staging"
  mig --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 2 )) || fail "symlinked staging area exited $status, want 2"
  grep -q 'migration staging path is a symlink' "$tmp/out" || fail "symlinked staging area error unclear"
  [[ -d "$tmp/dest/old" && ! -e "$tmp/dest/new" ]] || fail "symlinked staging area run changed skills"
  rm -rf "$tmp"
  trap - RETURN
}

test_backup_inside_staging_area_is_rejected() {
  local tmp backup status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
  ln -s "$tmp/.skills-migrate-staging" "$tmp/alias"
  for backup in "$tmp/.skills-migrate-staging/backups" "$tmp/alias/backups" "$tmp"; do
    status=0
    mig --apply --backup-dir "$backup" > "$tmp/out" 2>&1 || status=$?
    (( status == 2 )) || fail "backup $backup exited $status, want 2"
    grep -q 'backup directory must be outside the migration staging area' "$tmp/out" || fail "backup $backup rejection unclear"
    [[ -d "$tmp/dest/old" && ! -e "$tmp/dest/new" && ! -e "$tmp/.skills-migrate-staging" ]] || fail "backup $backup rejection changed files"
    cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "backup $backup rejection changed the lock"
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_apply_holds_installer_lock() {
  local tmp status out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  cp "$tmp/dest/.skills-lock.json" "$tmp/lock-before"
  printf '%s\n' other > "$tmp/other-file"

  hold_lock "$tmp/held"
  mig > "$tmp/preview" || fail "preview needed the installer lock"
  for out in direct inherited-other inherited-unlocked; do
    status=0
    case "$out" in
      direct) LOCK_WAIT=1 mig --apply > "$tmp/out" 2>&1 || status=$? ;;
      inherited-other) ( exec 9>>"$tmp/other-file"; LOCK_WAIT=1 mig --apply ) > "$tmp/out" 2>&1 || status=$? ;;
      inherited-unlocked) ( exec 9>>"$LOCK_FILE"; LOCK_WAIT=1 mig --apply ) > "$tmp/out" 2>&1 || status=$? ;;
    esac
    (( status == 3 )) || fail "$out apply under a held lock exited $status, want 3"
    grep -q 'another install.sh run holds' "$tmp/out" || fail "$out lock contention was not explained"
    [[ -d "$tmp/dest/old" && ! -e "$tmp/dest/new" ]] || fail "$out apply changed skills without the lock"
    cmp -s "$tmp/lock-before" "$tmp/dest/.skills-lock.json" || fail "$out apply changed the lock without holding it"
  done
  release_lock
  [[ "$(<"$tmp/other-file")" == other ]] || fail "migrator wrote to an unrelated inherited descriptor"

  # A parent that already holds the lock on fd 9, as install.sh does, lets the child proceed.
  ( exec 9>>"$LOCK_FILE"; flock 9; LOCK_WAIT=0 mig --apply ) > "$tmp/out" 2>&1 || fail "inherited held lock was refused: $(<"$tmp/out")"
  assert_converged "$tmp" "apply under inherited lock"
  [[ "$(file_mode "$(dirname "$LOCK_FILE")")" == 0o700 ]] || fail "lock directory is not private"
  rm -rf "$tmp"
  trap - RETURN
}

test_concurrent_applies_serialize() {
  local tmp first status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_owned_copy "$tmp"
  rm -rf "$(dirname "$LOCK_FILE")"
  FAULT=sleep-after-lock mig --apply > "$tmp/first.out" 2> "$tmp/first.err" &
  first=$!
  for _ in $(seq 100); do grep -q 'FAULT sleep-after-lock' "$tmp/first.err" 2>/dev/null && break; sleep 0.05; done
  grep -q 'FAULT sleep-after-lock' "$tmp/first.err" || fail "first apply did not take the lock"
  LOCK_WAIT=0 mig --apply > "$tmp/second" 2>&1 || status=$?
  (( status == 3 )) || fail "second apply exited $status while the first held the lock"
  [[ -d "$tmp/dest/old" && ! -e "$tmp/dest/new" ]] || fail "second apply changed files while the first held the lock"
  mig --apply > "$tmp/third"
  wait "$first" || fail "first apply failed: $(<"$tmp/first.err")"
  grep -q 'APPLIED rename old -> new' "$tmp/first.out" || fail "first apply did not migrate"
  grep -q 'SKIP old: already absent' "$tmp/third" || fail "waiting apply did not see the finished migration"
  assert_converged "$tmp" "concurrent applies"
  rm -rf "$tmp"
  trap - RETURN
}

test_installer_migration_apply_requires_lock() {
  local tmp dir file status digest debris
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills" "$tmp/no-flock"
  cp -r "$ROOT/skills/anti-slop" "$tmp/skills/anti-slop"
  digest="$(hash_skill "$tmp/skills/anti-slop")"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  # Record-less transaction debris: recovery deletes it, so it shows whether recovery ran.
  debris="$tmp/.skills-txn/skills/code-simplification"
  mkdir -p "$debris/staging"
  printf '%s\n' debris > "$debris/staging/SKILL.md"
  for dir in ${SAFE_PATH//:/ }; do
    for file in "$dir"/*; do
      [[ "${file##*/}" == flock || -e "$tmp/no-flock/${file##*/}" || -L "$tmp/no-flock/${file##*/}" ]] || ln -s "$file" "$tmp/no-flock/${file##*/}"
    done
  done

  status=0
  env -i HOME="$TEST_HOME" PATH="$tmp/no-flock" LANG=C SKILLS_BACKUP_DIR="$tmp/backups" \
    "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/out" 2>&1 || status=$?
  (( status == 10 )) || fail "migration apply without flock exited $status, want 10: $(<"$tmp/out")"
  grep -q 'flock (util-linux) is required for .*--migrate --apply' "$tmp/out" || fail "missing flock hint absent: $(<"$tmp/out")"
  [[ "$(<"$debris/staging/SKILL.md")" == debris ]] || fail "migration apply without flock ran recovery"
  [[ -d "$tmp/skills/anti-slop" && ! -e "$tmp/skills/code-simplification" && ! -e "$tmp/backups" ]] \
    || fail "migration apply without flock changed files"
  env -i HOME="$TEST_HOME" PATH="$tmp/no-flock" LANG=C \
    "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate > "$tmp/out" 2>&1 \
    || fail "migration preview needed flock: $(<"$tmp/out")"

  hold_lock "$tmp/held"
  status=0
  env -i HOME="$TEST_HOME" PATH="$SAFE_PATH" LANG=C SKILLS_LOCK_WAIT=1 SKILLS_BACKUP_DIR="$tmp/backups" \
    "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/out" 2>&1 || status=$?
  release_lock
  (( status == 3 )) || fail "migration apply under a held lock exited $status, want 3: $(<"$tmp/out")"
  [[ "$(<"$debris/staging/SKILL.md")" == debris ]] || fail "migration apply under a held lock ran recovery"
  [[ -d "$tmp/skills/anti-slop" && ! -e "$tmp/skills/code-simplification" ]] || fail "migration apply under a held lock changed files"

  env -i HOME="$TEST_HOME" PATH="$SAFE_PATH" LANG=C SKILLS_BACKUP_DIR="$tmp/backups" \
    "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/out" 2>&1 \
    || fail "migration apply failed once the lock was free: $(<"$tmp/out")"
  [[ ! -e "$debris" ]] || fail "locked migration apply did not recover transaction debris"
  [[ ! -e "$tmp/skills/anti-slop" && -d "$tmp/skills/code-simplification" ]] || fail "locked migration apply did not migrate"
  rm -rf "$tmp"
  trap - RETURN
}

setup_legacy_dir() {
  local tmp="$1"
  mkdir -p "$tmp/source/x" "$tmp/canonical" "$tmp/tools/legacy" "$tmp/tools/new"
  printf '%s\n' x > "$tmp/source/x/SKILL.md"
  cp -r "$tmp/source/x" "$tmp/canonical/x"
  ln -s "$tmp/canonical/x" "$tmp/tools/legacy/x"
  ln -s "$tmp/canonical/x" "$tmp/tools/new/x"
  write_lock "$tmp/tools/legacy" "$tmp/source" "x=$(hash_skill "$tmp/canonical/x")"
}

cleanup_legacy() {
  run_migrator --source "$tmp/source" --legacy-dir "$tmp/tools/legacy" --new-dir "$tmp/tools/new" \
    --link-root "$tmp/canonical" "$@"
}

test_legacy_cleanup_backup_outside_staging_area() {
  local tmp backup status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  setup_legacy_dir "$tmp"
  cp "$tmp/tools/legacy/.skills-lock.json" "$tmp/lock-before"
  ln -s "$tmp/tools/.skills-migrate-staging" "$tmp/alias"
  for backup in "$tmp/tools/.skills-migrate-staging/legacy/backups" "$tmp/alias/legacy/backups" "$tmp/tools"; do
    status=0
    cleanup_legacy --backup-dir "$backup" --apply > "$tmp/out" 2>&1 || status=$?
    (( status == 2 )) || fail "legacy backup $backup exited $status, want 2"
    grep -q 'backup directory must be outside the migration staging area' "$tmp/out" || fail "legacy backup $backup rejection unclear"
    [[ -L "$tmp/tools/legacy/x" && ! -e "$tmp/tools/.skills-migrate-staging" ]] || fail "legacy backup $backup rejection changed files"
    cmp -s "$tmp/lock-before" "$tmp/tools/legacy/.skills-lock.json" || fail "legacy backup $backup rejection changed the lock"
  done

  # An accepted backup must survive a later ordinary migration, which clears the staging area.
  cleanup_legacy --backup-dir "$tmp/tools/.skills-backups/legacy" --apply > "$tmp/out"
  [[ ! -e "$tmp/tools/legacy/x" ]] || fail "legacy cleanup did not unlink"
  make_fixture "$tmp/later"
  mkdir -p "$tmp/tools/legacy/old"
  cp -r "$tmp/later/source/old/." "$tmp/tools/legacy/old/"
  write_lock "$tmp/tools/legacy" "$tmp/later/source" "old=$(hash_skill "$tmp/tools/legacy/old")"
  run_migrator --manifest "$tmp/later/migrations.json" --source "$tmp/later/source" --dest "$tmp/tools/legacy" --apply > "$tmp/out"
  grep -q 'APPLIED rename old -> new' "$tmp/out" || fail "later ordinary migration did not run"
  [[ -L "$(find "$tmp/tools/.skills-backups/legacy/.legacy-dir-cleanup" -mindepth 2 -maxdepth 2 -name x)" ]] \
    || fail "later ordinary migration removed the legacy cleanup backup"
  rm -rf "$tmp"
  trap - RETURN
}

test_dry_run_and_apply
test_modified_unowned_and_collision_are_skipped
test_remove_merge_and_link_target
test_source_overlap_is_rejected
test_missing_destination_is_safe_noop
test_legacy_hash_only_lock_requires_manual_migration
test_protected_replacement_skips_only_its_mapping
test_lock_write_cleans_only_its_temp
test_crash_after_promote_converges
test_crash_during_cross_device_retirement_converges
test_crash_after_retirement_converges
test_inserted_target_is_never_overwritten
test_no_replace_unavailable_fails_closed
test_shared_replacement_and_protected_overlay
test_staging_area_clearing_is_scoped
test_backup_inside_staging_area_is_rejected
test_apply_holds_installer_lock
test_concurrent_applies_serialize
test_installer_migration_apply_requires_lock
test_legacy_cleanup_backup_outside_staging_area
printf 'migration tests passed\n'
