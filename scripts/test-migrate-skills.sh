#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATOR="$ROOT/scripts/migrate-skills.py"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
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

  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" > "$tmp/dry-run"
  [[ -d "$tmp/dest/old" ]] || fail "dry run retired old skill"
  [[ ! -e "$tmp/dest/new" ]] || fail "dry run installed replacement"
  grep -q 'DRY-RUN.*old.*new' "$tmp/dry-run" || fail "dry run did not report rename"

  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/apply"
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

  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/rerun"
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
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/modified"
  [[ -d "$tmp/dest/old" ]] || fail "modified old skill was retired"
  grep -q 'ownership hash differs' "$tmp/modified" || fail "modified skill skip was not reported"

  cp -r "$tmp/source/old" "$tmp/dest/unowned"
  mv "$tmp/dest/old" "$tmp/dest/old-modified"
  cp -r "$tmp/source/old" "$tmp/dest/old"
  printf '%s\n' '{"version":1,"source":"/wrong/source","skills":{}}' > "$tmp/dest/.skills-lock.json"
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/unowned"
  [[ -d "$tmp/dest/old" ]] || fail "unowned old skill was retired"
  grep -q 'lock source' "$tmp/unowned" || fail "unowned skip was not reported"

  old_hash="$(hash_skill "$tmp/dest/old")"
  write_lock "$tmp/dest" "$tmp/source" "old=$old_hash"
  mkdir -p "$tmp/dest/new"
  printf '%s\n' 'foreign' > "$tmp/dest/new/SKILL.md"
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/collision"
  [[ -d "$tmp/dest/old" ]] || fail "collision retired old skill"
  grep -q 'replacement collision' "$tmp/collision" || fail "collision skip was not reported"

  rm -rf "$tmp/dest/new"
  ln -s "$tmp/source/new/SKILL.md" "$tmp/dest/old/hidden-link"
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/symlink"
  [[ -d "$tmp/dest/old" ]] || fail "interior symlink skill was retired"
  grep -q 'interior symlink' "$tmp/symlink" || fail "interior symlink skip was not reported"

  rm "$tmp/dest/old/hidden-link"
  mkdir "$tmp/dest/old/protected"
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/overlay"
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
  if "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/source" --apply > "$tmp/overlap" 2>&1; then
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
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" > "$tmp/missing"
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
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/legacy"
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
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/dest" --apply > "$tmp/protected"
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

  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/canonical" --apply --preserve-shared-canonical > "$tmp/canonical-run"
  [[ -d "$tmp/canonical/one" ]] || fail "protected canonical legacy target was removed"
  [[ -d "$tmp/canonical/new" ]] || fail "canonical replacement was not installed"
  [[ -d "$tmp/canonical/two" ]] || fail "protected canonical remove target was removed"

  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/tool" --link-root "$tmp/canonical" --apply > "$tmp/link-run"
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
  "$MIGRATOR" --manifest "$tmp/migrations.json" --source "$tmp/source" --dest "$tmp/remove-dest" --apply > "$tmp/remove-run"
  [[ ! -e "$tmp/remove-dest/two" ]] || fail "owned remove action was not applied"
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
printf 'migration tests passed\n'
