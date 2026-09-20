#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

test_backups_stay_outside_skill_root() {
  local tmp dest backup_root
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  dest="$tmp/agent/skills"
  "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  "$ROOT/install.sh" --tool portable --dest "$dest" --force docker >/dev/null

  if find "$dest" -path '*/.backups/*/SKILL.md' -print -quit | grep -q .; then
    fail "backup SKILL.md found under discovery root $dest"
  fi

  backup_root="$tmp/agent/.skills-backups/skills/docker"
  if ! find "$backup_root" -mindepth 2 -name SKILL.md -type f -print -quit 2>/dev/null | grep -q .; then
    fail "expected backup SKILL.md under $backup_root"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_backups_are_migrated_outside_skill_root() {
  local tmp dest migrated_root
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  dest="$tmp/agent/skills"
  mkdir -p "$dest/.backups/docker/legacy"
  printf '%s\n' 'legacy backup' > "$dest/.backups/docker/legacy/SKILL.md"

  "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null

  if [[ -e "$dest/.backups" ]]; then
    fail "legacy .backups directory still exists under discovery root $dest"
  fi

  migrated_root="$tmp/agent/.skills-backups/skills/.legacy"
  if ! find "$migrated_root" -path '*/docker/legacy/SKILL.md' -type f -print -quit 2>/dev/null | grep -q .; then
    fail "expected migrated legacy backup under $migrated_root"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_install_allows_installed_skills() {
  local tmp config
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  config="$tmp/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '%s\n' '{"permission":{"skill":{"*":"deny","ai-ml":"allow","docker":"deny"}}}' > "$config"

  HOME="$tmp" "$ROOT/install.sh" --tool opencode --no-backup backend-api docker >/dev/null

  python3 - "$config" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    config = json.load(f)

skills = config["permission"]["skill"]
assert skills["*"] == "deny"
assert skills["ai-ml"] == "allow"
assert skills["backend-api"] == "allow"
assert skills["docker"] == "deny"
PY

  rm -rf "$tmp"
  trap - RETURN
}

test_link_mode_writes_tool_lock() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool codex --link --no-backup >/dev/null
  HOME="$tmp" "$ROOT/install.sh" --check --tool codex >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_link_mode_writes_tool_lock_gemini() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool gemini --link --no-backup >/dev/null
  HOME="$tmp" "$ROOT/install.sh" --check --tool gemini >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_backup_preserves_top_level_symlink() {
  local tmp dest private backup_root
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  dest="$tmp/agent/skills"
  private="$tmp/private"
  mkdir -p "$dest" "$private"
  printf '%s\n' 'do not copy' > "$private/secret.txt"
  ln -s "$private" "$dest/docker"

  "$ROOT/install.sh" --tool portable --dest "$dest" --force docker >/dev/null

  backup_root="$tmp/agent/.skills-backups/skills/docker"
  if find "$backup_root" -type f -name secret.txt -print -quit 2>/dev/null | grep -q .; then
    fail "backup followed top-level symlink and copied external files"
  fi

  if ! find "$backup_root" -type l -name docker -print -quit 2>/dev/null | grep -q .; then
    fail "expected backup to preserve top-level symlink"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_commandcode_and_agy_targets() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool commandcode --link --no-backup docker >/dev/null
  if [[ ! -e "$tmp/.commandcode/skills/docker" ]]; then
    fail "commandcode target did not install to ~/.commandcode/skills"
  fi

  HOME="$tmp" "$ROOT/install.sh" --tool agy --link --no-backup docker >/dev/null
  if [[ ! -e "$tmp/.gemini/config/skills/docker" ]]; then
    fail "agy alias did not resolve to the Antigravity global skills path"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_lock_preserves_unselected_records() {
  local tmp dest docker_hash
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  dest="$tmp/skills"
  "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  docker_hash="$(LC_ALL=C find "$dest/docker" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$dest/.skills-lock.json" "$docker_hash" <<'PY'
import json
import sys

path = sys.argv[1]
payload = json.load(open(path, encoding="utf-8"))
payload["skills"] = {"docker": sys.argv[2], "preserve-me": "0" * 64}
with open(path, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PY
  "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  python3 - "$dest/.skills-lock.json" <<'PY'
import json
import sys

skills = json.load(open(sys.argv[1], encoding="utf-8"))["skills"]
assert "docker" in skills
assert skills["preserve-me"] == "0" * 64
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_deprecated_selection_and_notice() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  "$ROOT/install.sh" --tool portable --dest "$tmp/default" --no-backup >/dev/null
  [[ ! -e "$tmp/default/anti-slop" ]] || fail "default install selected a deprecated skill"
  output="$("$ROOT/install.sh" --tool portable --dest "$tmp/explicit" --no-backup anti-slop)"
  grep -q 'anti-slop is deprecated' <<< "$output" || fail "explicit deprecated install did not show notice"
  "$ROOT/install.sh" --tool portable --dest "$tmp/explicit" --list > "$tmp/list"
  grep -q 'anti-slop.*deprecated' "$tmp/list" || fail "list did not mark deprecated skill"
  rm -rf "$tmp"
  trap - RETURN
}

test_check_reports_legacy_manifest_skill() {
  local tmp digest output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/skills"
  cp -r "$ROOT/skills/anti-slop" "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": sys.argv[3]}}, f)
PY
  if output="$("$ROOT/install.sh" --tool portable --dest "$tmp/skills" --check 2>&1)"; then
    fail "check accepted a legacy manifest skill"
  fi
  grep -q 'anti-slop.*legacy installed' <<< "$output" || fail "check did not report legacy manifest skill"
  rm -rf "$tmp"
  trap - RETURN
}

test_invalid_manifest_stops_installer() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  printf '%s\n' '{"version":1,"skills":[]}' > "$tmp/invalid.json"
  if output="$(SKILLS_MIGRATIONS_FILE="$tmp/invalid.json" "$ROOT/install.sh" --list 2>&1)"; then
    fail "installer accepted malformed migrations manifest"
  fi
  grep -q 'Cannot continue with an invalid migrations.json' <<< "$output" || fail "invalid manifest failure was unclear"
  rm -rf "$tmp"
  trap - RETURN
}

test_installer_migration_dry_run_and_apply() {
  local tmp digest
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/skills"
  cp -r "$ROOT/skills/anti-slop" "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate > "$tmp/dry-run"
  [[ -d "$tmp/skills/anti-slop" ]] || fail "installer migration dry run retired old skill"
  [[ ! -e "$tmp/skills/code-simplification" ]] || fail "installer migration dry run installed replacement"
  SKILLS_BACKUP_DIR="$tmp/migration-backups" "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/apply"
  [[ ! -e "$tmp/skills/anti-slop" ]] || fail "installer migration apply did not retire old skill"
  [[ -d "$tmp/skills/code-simplification" ]] || fail "installer migration apply did not install replacement"
  if ! find "$tmp/migration-backups/anti-slop" -type f -name SKILL.md -print -quit | grep -q .; then
    fail "installer migration did not honor SKILLS_BACKUP_DIR"
  fi
  if output="$(LC_ALL=en_US.utf8 "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --check 2>&1)"; then
    fail "check accepted incomplete migration fixture"
  fi
  grep -q 'code-simplification.*current' <<< "$output" || fail "locale check did not recognize migrated replacement"
  rm -rf "$tmp"
  trap - RETURN
}

test_skipped_custom_skill_keeps_old_lock_and_migration_skips_it() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --no-backup anti-slop >/dev/null
  printf '%s\n' 'custom local change' >> "$tmp/skills/anti-slop/SKILL.md"
  "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --no-backup anti-slop >/dev/null
  "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/migration"
  [[ -d "$tmp/skills/anti-slop" ]] || fail "migration retired a skipped custom skill"
  [[ ! -e "$tmp/skills/code-simplification" ]] || fail "migration installed replacement for custom skill"
  output="$(<"$tmp/migration")"
  grep -q 'anti-slop: ownership hash differs' <<< "$output" || fail "custom skill ownership failure was not reported"
  rm -rf "$tmp"
  trap - RETURN
}

test_foreign_lock_is_backed_up_before_fresh_install() {
  local tmp digest output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills" "$tmp/foreign-source"
  cp -r "$ROOT/skills/docker" "$tmp/skills/docker"
  digest="$(LC_ALL=C find "$tmp/skills/docker" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$tmp/foreign-source" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"docker": sys.argv[3]}}, f)
PY
  output="$("$ROOT/install.sh" --tool portable --dest "$tmp/skills" --no-backup docker 2>&1)"
  grep -q 'unverified lock backed up' <<< "$output" || fail "foreign lock backup was not reported"
  if ! find "$tmp/.skills-backups/skills/.unverified-locks" -type f -name '*.skills-lock.json' -print -quit | grep -q .; then
    fail "foreign lock was not backed up outside the discovery root"
  fi
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
assert lock["source"] == sys.argv[2]
assert lock["skills"] == {"docker": {"hash": lock["skills"]["docker"]["hash"], "provenance": "source-equal-v1"}}
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_copy_mode_migrates_each_selected_tool_destination() {
  local tmp digest
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/claude" "$tmp/codex"
  cp -r "$ROOT/skills/anti-slop" "$tmp/claude/anti-slop"
  cp -r "$ROOT/skills/anti-slop" "$tmp/codex/anti-slop"
  digest="$(LC_ALL=C find "$tmp/claude/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/claude/.skills-lock.json" "$tmp/codex/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

for path in sys.argv[1:3]:
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "source": sys.argv[3], "skills": {"anti-slop": {"hash": sys.argv[4], "provenance": "source-equal-v1"}}}, f)
PY
  CLAUDE_SKILLS_DIR="$tmp/claude" CODEX_SKILLS_DIR="$tmp/codex" "$ROOT/install.sh" --tool claude,codex --migrate --apply >/dev/null
  for destination in "$tmp/claude" "$tmp/codex"; do
    [[ ! -e "$destination/anti-slop" && -d "$destination/code-simplification" ]] || fail "copy migration missed $destination"
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_copy_canonical_migration_preserves_legacy_target() {
  local tmp canonical digest
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  canonical="$tmp/canonical"
  mkdir -p "$canonical" "$tmp/unselected"
  cp -r "$ROOT/skills/anti-slop" "$canonical/anti-slop"
  digest="$(LC_ALL=C find "$canonical/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$canonical/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  ln -s "$canonical/anti-slop" "$tmp/unselected/anti-slop"
  GEMINI_SKILLS_DIR="$canonical" SKILLS_CANONICAL_DIR="$canonical" "$ROOT/install.sh" --tool gemini --migrate --apply >/dev/null
  [[ -d "$canonical/anti-slop" && -d "$canonical/code-simplification" ]] || fail "canonical migration retired shared legacy target"
  [[ -e "$tmp/unselected/anti-slop/SKILL.md" ]] || fail "canonical migration broke an unselected tool link"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_migration_syncs_apply_only() {
  local tmp digest config_before config_after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills" "$tmp/config"
  cp -r "$ROOT/skills/anti-slop" "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  config_before='{"permission":{"skill":{"*":"deny","custom":"deny"}}}'
  printf '%s\n' "$config_before" > "$tmp/config/opencode.json"
  OPENCODE_SKILLS_DIR="$tmp/skills" OPENCODE_CONFIG_FILE="$tmp/config/opencode.json" "$ROOT/install.sh" --tool opencode --migrate >/dev/null
  config_after="$(<"$tmp/config/opencode.json")"
  [[ "$config_after" == "$config_before" ]] || fail "OpenCode migration dry run changed permissions"
  OPENCODE_SKILLS_DIR="$tmp/skills" OPENCODE_CONFIG_FILE="$tmp/config/opencode.json" "$ROOT/install.sh" --tool opencode --migrate --apply >/dev/null
  python3 - "$tmp/config/opencode.json" <<'PY'
import json
import sys

skills = json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"]
assert skills["*"] == "deny"
assert skills["custom"] == "deny"
assert skills["code-simplification"] == "allow"
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_noop_apply_keeps_permissions_unchanged() {
  local tmp digest config_before config_after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills" "$tmp/config"
  cp -r "$ROOT/skills/code-simplification" "$tmp/skills/code-simplification"
  digest="$(LC_ALL=C find "$tmp/skills/code-simplification" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"code-simplification": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  config_before='{"permission":{"skill":{"*":"deny","custom":"deny"}}}'
  printf '%s\n' "$config_before" > "$tmp/config/opencode.json"
  OPENCODE_SKILLS_DIR="$tmp/skills" OPENCODE_CONFIG_FILE="$tmp/config/opencode.json" "$ROOT/install.sh" --tool opencode --migrate --apply >/dev/null
  config_after="$(<"$tmp/config/opencode.json")"
  [[ "$config_after" == "$config_before" ]] || fail "OpenCode no-op migration changed permissions"
  rm -rf "$tmp"
  trap - RETURN
}

test_copy_migration_rejects_backup_inside_canonical_root() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/canonical"
  if output="$(SKILLS_CANONICAL_DIR="$tmp/canonical" SKILLS_BACKUP_DIR="$tmp/canonical/backups" "$ROOT/install.sh" --tool portable --dest "$tmp/tool" --migrate 2>&1)"; then
    fail "copy migration accepted backup directory inside canonical root"
  fi
  grep -q 'backup directory must be outside the protected root' <<< "$output" || fail "canonical backup rejection was unclear"
  [[ ! -e "$tmp/tool" ]] || fail "rejected copy migration created destination"
  rm -rf "$tmp"
  trap - RETURN
}

test_migration_rejects_irrelevant_flags() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if output="$("$ROOT/install.sh" --tool portable --dest "$tmp/skills" --migrate --force 2>&1)"; then
    fail "migration accepted --force"
  fi
  grep -q -- '--force and --no-backup cannot be used with --migrate' <<< "$output" || fail "migration flag rejection was unclear"
  rm -rf "$tmp"
  trap - RETURN
}

test_force_refreshes_active_legacy_hash_without_provenance_upgrade() {
  local tmp digest output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills"
  cp -r "$ROOT/skills/docker" "$tmp/skills/docker"
  python3 - "$tmp/skills/.skills-lock.json" "$ROOT/skills" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"docker": "0" * 64}}, f)
PY
  "$ROOT/install.sh" --tool portable --dest "$tmp/skills" --force docker >/dev/null
  digest="$(LC_ALL=C find "$tmp/skills/docker" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$digest" <<'PY'
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))["skills"]["docker"]
assert record == sys.argv[2]
PY
  if output="$("$ROOT/install.sh" --tool portable --dest "$tmp/skills" --check 2>&1)"; then
    fail "check accepted incomplete legacy-only install"
  fi
  grep -q 'docker.*current' <<< "$output" || fail "force refresh did not make active skill current"
  if grep -q 'docker.*outdated' <<< "$output"; then
    fail "force refresh left the legacy lock hash outdated"
  fi
  rm -rf "$tmp"
  trap - RETURN
}

test_backups_stay_outside_skill_root
test_legacy_backups_are_migrated_outside_skill_root
test_opencode_install_allows_installed_skills
test_link_mode_writes_tool_lock
test_link_mode_writes_tool_lock_gemini
test_backup_preserves_top_level_symlink
test_commandcode_and_agy_targets
test_lock_preserves_unselected_records
test_deprecated_selection_and_notice
test_check_reports_legacy_manifest_skill
test_invalid_manifest_stops_installer
test_installer_migration_dry_run_and_apply
test_skipped_custom_skill_keeps_old_lock_and_migration_skips_it
test_foreign_lock_is_backed_up_before_fresh_install
test_copy_mode_migrates_each_selected_tool_destination
test_copy_canonical_migration_preserves_legacy_target
test_opencode_migration_syncs_apply_only
test_opencode_noop_apply_keeps_permissions_unchanged
test_copy_migration_rejects_backup_inside_canonical_root
test_migration_rejects_irrelevant_flags
test_force_refreshes_active_legacy_hash_without_provenance_upgrade
printf 'install tests passed\n'
