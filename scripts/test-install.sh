#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

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

test_omp_default_path() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  if [[ ! -e "$tmp/.agents/skills/docker" ]]; then
    fail "omp default path did not install to ~/.agents/skills"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_omp_skills_dir_override() {
  local tmp override
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  override="$tmp/custom-omp"
  HOME="$tmp" OMP_SKILLS_DIR="$override" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  if [[ ! -e "$override/docker" ]]; then
    fail "OMP_SKILLS_DIR override was not honored"
  fi
  if [[ -e "$tmp/.agents/skills/docker" ]]; then
    fail "omp install with OMP_SKILLS_DIR override also wrote the default path"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_omp_link_mode_shares_canonical_dir() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --link --no-backup docker >/dev/null
  if [[ -L "$tmp/.agents/skills/docker" ]]; then
    fail "omp link mode created a self-symlink onto its own canonical dir"
  fi
  if [[ ! -d "$tmp/.agents/skills/docker" ]]; then
    fail "omp link mode did not populate the canonical dir"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_omp_repeat_install_is_idempotent() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  if [[ ! -f "$tmp/.agents/skills/docker/SKILL.md" ]]; then
    fail "repeated omp install did not leave the skill intact"
  fi
  if [[ -e "$tmp/.agents/.skills-backups" ]]; then
    fail "repeated omp install without --force created a backup"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_omp_check_mode() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --link --no-backup >/dev/null
  HOME="$tmp" "$ROOT/install.sh" --check --tool omp >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_omp_and_gemini_share_destination() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp,gemini --link --no-backup docker >/dev/null
  if [[ ! -d "$tmp/.agents/skills/docker" ]]; then
    fail "omp,gemini shared install did not populate ~/.agents/skills"
  fi
  if [[ -L "$tmp/.agents/skills/docker" ]]; then
    fail "omp,gemini shared install created a self-symlink"
  fi

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
  if [[ ! -d "$tmp/.agents/skills/docker" || -e "$tmp/.commandcode" ]]; then
    fail "commandcode target did not install once into ~/.agents/skills"
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

tree_hash() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
digest = hashlib.sha256()
for directory, dirs, files in os.walk(root, followlinks=False):
    dirs.sort()
    for name in sorted(dirs + files):
        path = os.path.join(directory, name)
        digest.update(f"{os.path.relpath(path, root)}\0{os.lstat(path).st_mode:o}\0".encode())
        if os.path.islink(path):
            digest.update(os.readlink(path).encode())
        elif os.path.isfile(path):
            with open(path, "rb") as file:
                digest.update(file.read())
print(digest.hexdigest())
PY
}

# Recreate the pre-#212 layout: commandcode links in ~/.commandcode/skills.
make_legacy_commandcode() {
  local home="$1"
  shift
  HOME="$home" COMMANDCODE_SKILLS_DIR="$home/.commandcode/skills" \
    "$ROOT/install.sh" --tool commandcode --link --no-backup "$@" >/dev/null
}

lock_names() {
  python3 -c 'import json,sys; print(" ".join(sorted(json.load(open(sys.argv[1]))["skills"])))' "$1"
}

test_remapped_tools_install_once_into_agents_dir() {
  local tmp tool home
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  for tool in codex commandcode opencode; do
    HOME="$tmp/$tool-copy" "$ROOT/install.sh" --tool "$tool" --no-backup docker >/dev/null
    HOME="$tmp/$tool-link" "$ROOT/install.sh" --tool "$tool" --link --no-backup docker >/dev/null
    for home in "$tmp/$tool-copy" "$tmp/$tool-link"; do
      [[ -d "$home/.agents/skills/docker" && ! -L "$home/.agents/skills/docker" ]] || fail "$tool did not install into ~/.agents/skills"
      [[ ! -e "$home/.codex/skills" && ! -e "$home/.commandcode" && ! -e "$home/.config/opencode/skills" ]] || fail "$tool created a second skill dir"
    done
  done
  HOME="$tmp/override" CODEX_SKILLS_DIR="$tmp/override/.codex/skills" "$ROOT/install.sh" --tool codex --no-backup docker >/dev/null
  [[ -d "$tmp/override/.codex/skills/docker" ]] || fail "CODEX_SKILLS_DIR override was not honored"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_link_into_canonical_syncs_permissions() {
  local tmp config before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  config="$tmp/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '%s\n' '{"permission":{"skill":{"*":"deny","git":"deny"}}}' > "$config"
  HOME="$tmp" "$ROOT/install.sh" --tool opencode --link --no-backup docker git >/dev/null
  python3 - "$config" <<'PY'
import json
import sys

skills = json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"]
assert skills == {"*": "deny", "git": "deny", "docker": "allow"}, skills
PY
  before="$(tree_hash "$tmp")"
  HOME="$tmp" "$ROOT/install.sh" --tool opencode --link --migrate >/dev/null
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "opencode migration preview on shared canonical changed files"
  HOME="$tmp" "$ROOT/install.sh" --tool opencode --link --migrate --apply >/dev/null
  [[ -d "$tmp/.agents/skills/docker" ]] || fail "opencode migration apply on shared canonical removed a skill"
  rm -rf "$tmp"
  trap - RETURN
}

test_install_hints_at_legacy_cleanup() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  output="$(HOME="$tmp/clean" "$ROOT/install.sh" --tool commandcode --link --no-backup docker)"
  if grep -q 'old link' <<< "$output"; then
    fail "install printed a cleanup hint without legacy links"
  fi
  make_legacy_commandcode "$tmp/old" docker git
  output="$(HOME="$tmp/old" "$ROOT/install.sh" --tool commandcode --no-backup docker)"
  grep -q '2 old link(s) in .*/.commandcode/skills .*--migrate --tool commandcode' <<< "$output" || fail "install did not hint at legacy cleanup"
  [[ -L "$tmp/old/.commandcode/skills/docker" ]] || fail "plain install removed a legacy link"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_cleanup_end_to_end() {
  local tmp old before output backup
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  old="$tmp/.commandcode/skills"
  make_legacy_commandcode "$tmp" docker git ansible
  rm -rf "$tmp/.agents/skills/ansible"
  ln -s "$tmp/.agents/skills/docker" "$old/unlisted"
  ln -s /nonexistent "$old/foreign"
  mkdir "$old/user-skill"
  printf '%s\n' 'mine' > "$old/user-skill/SKILL.md"

  HOME="$tmp" "$ROOT/install.sh" --tool commandcode --link --no-backup docker >/dev/null
  before="$(tree_hash "$tmp")"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate)"
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "cleanup preview changed files"
  grep -q 'DRY-RUN unlink docker' <<< "$output" || fail "preview did not list docker"
  grep -q 'SKIP ansible: broken symlink' <<< "$output" || fail "preview did not report the broken link"

  HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  [[ ! -e "$old/docker" && ! -L "$old/docker" && ! -L "$old/git" ]] || fail "apply kept replaced links"
  [[ -L "$old/ansible" && -L "$old/unlisted" && -L "$old/foreign" && -f "$old/user-skill/SKILL.md" ]] || fail "apply touched entries it does not own"
  [[ "$(lock_names "$old/.skills-lock.json")" == "ansible" ]] || fail "lock does not match the remaining owned entries"
  backup="$(find "$tmp/.commandcode/.skills-backups/skills/.legacy-dir-cleanup" -mindepth 1 -maxdepth 1 -type d)"
  [[ -f "$backup/.skills-lock.json" && -L "$backup/docker" ]] || fail "backup is missing the lock or link"
  [[ "$(cut -f1 "$backup/links.tsv" | tr '\n' ' ')" == "docker git " ]] || fail "backup record lists the wrong links"
  [[ -d "$tmp/.agents/skills/docker" && -d "$tmp/.agents/skills/git" ]] || fail "apply touched the canonical dir"

  before="$(tree_hash "$tmp")"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply)"
  grep -q 'NOOP: nothing to clean up' <<< "$output" || fail "repeat apply was not a no-op"
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "repeat apply changed files"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_cleanup_backup_failure_removes_nothing() {
  local tmp before
  tmp="$(mktemp -d)"
  trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' RETURN
  make_legacy_commandcode "$tmp" docker git
  mkdir "$tmp/readonly"
  chmod 555 "$tmp/readonly"
  before="$(tree_hash "$tmp/.commandcode/skills")"
  if HOME="$tmp" SKILLS_BACKUP_DIR="$tmp/readonly/backups" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null 2>&1; then
    fail "apply succeeded although the backup could not be written"
  fi
  [[ "$(tree_hash "$tmp/.commandcode/skills")" == "$before" ]] || fail "failed backup still changed the legacy dir"
  chmod -R u+w "$tmp"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_cleanup_converges_after_interruption() {
  local tmp old digest before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  old="$tmp/.commandcode/skills"
  make_legacy_commandcode "$tmp" docker git
  mkdir "$old/kept"
  printf '%s\n' 'copy' > "$old/kept/SKILL.md"
  python3 - "$old/.skills-lock.json" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
lock["skills"]["kept"] = "0" * 64
json.dump(lock, open(sys.argv[1], "w", encoding="utf-8"))
PY
  digest="$(sha256sum "$old/.skills-lock.json")"
  rm "$old/docker"
  [[ "$(sha256sum "$old/.skills-lock.json")" == "$digest" ]] || fail "fixture changed the lock"
  HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  [[ ! -L "$old/git" && -d "$old/kept" ]] || fail "retry did not converge"
  [[ "$(lock_names "$old/.skills-lock.json")" == "kept" ]] || fail "retry left stale lock records"
  before="$(tree_hash "$tmp")"
  HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "repeat apply after retry changed files"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_cleanup_refuses_unsafe_layouts() {
  local tmp old before output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  old="$tmp/a/.commandcode/skills"
  make_legacy_commandcode "$tmp/a" docker
  python3 - "$old/.skills-lock.json" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
lock["skills"]["../../.agents/skills/docker"] = "0" * 64
json.dump(lock, open(sys.argv[1], "w", encoding="utf-8"))
PY
  before="$(tree_hash "$tmp/a")"
  if HOME="$tmp/a" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null 2>&1; then
    fail "apply accepted a lock with a traversal name"
  fi
  [[ "$(tree_hash "$tmp/a")" == "$before" ]] || fail "traversal lock changed files"
  printf '%s\n' '{not json' > "$old/.skills-lock.json"
  if output="$(HOME="$tmp/a" "$ROOT/install.sh" --tool commandcode --migrate --apply 2>&1)"; then
    fail "apply accepted a malformed lock"
  fi
  grep -q 'invalid lock file' <<< "$output" || fail "malformed lock error was unclear"
  [[ -L "$old/docker" ]] || fail "malformed lock run removed a link"

  make_legacy_commandcode "$tmp/b" docker
  before="$(tree_hash "$tmp/b")"
  HOME="$tmp/b" COMMANDCODE_SKILLS_DIR="$tmp/b/.commandcode/skills" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  HOME="$tmp/b" "$ROOT/install.sh" --tool commandcode --dest "$tmp/b/.commandcode/skills" --migrate --apply >/dev/null
  [[ -L "$tmp/b/.commandcode/skills/docker" ]] || fail "cleanup ran despite an override or --dest"

  mkdir -p "$tmp/c/.agents/skills"
  HOME="$tmp/c" "$ROOT/install.sh" --tool commandcode --no-backup docker >/dev/null
  mkdir -p "$tmp/c/.commandcode"
  ln -s "$tmp/c/.agents/skills" "$tmp/c/.commandcode/skills"
  output="$(HOME="$tmp/c" "$ROOT/install.sh" --tool commandcode --migrate --apply)"
  grep -q 'SKIP all: legacy directory aliases' <<< "$output" || fail "aliased legacy dir was not skipped"
  [[ -d "$tmp/c/.agents/skills/docker" ]] || fail "aliased legacy dir cleanup removed the canonical skill"
  rm -rf "$tmp"
  trap - RETURN
}

test_legacy_cleanup_custom_canonical_needs_replacement() {
  local tmp old canon
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  old="$tmp/.commandcode/skills"
  canon="$tmp/canon"
  SKILLS_CANONICAL_DIR="$canon" HOME="$tmp" COMMANDCODE_SKILLS_DIR="$old" \
    "$ROOT/install.sh" --tool commandcode --link --no-backup docker git >/dev/null
  SKILLS_CANONICAL_DIR="$canon" HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  [[ -L "$old/docker" && -L "$old/git" ]] || fail "cleanup removed links without a replacement in ~/.agents/skills"
  SKILLS_CANONICAL_DIR="$canon" HOME="$tmp" "$ROOT/install.sh" --tool commandcode --link --no-backup docker >/dev/null
  SKILLS_CANONICAL_DIR="$canon" HOME="$tmp" "$ROOT/install.sh" --tool commandcode --migrate --apply >/dev/null
  [[ ! -L "$old/docker" && -L "$old/git" ]] || fail "subset cleanup did not remove exactly the replaced link"
  [[ "$(lock_names "$old/.skills-lock.json")" == "git" ]] || fail "subset cleanup lock is inconsistent"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_link_migration_on_canonical_allows_replacement() {
  local tmp canonical digest config
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  canonical="$tmp/.agents/skills"
  config="$tmp/.config/opencode/opencode.json"
  mkdir -p "$canonical" "$(dirname "$config")"
  cp -r "$ROOT/skills/anti-slop" "$canonical/anti-slop"
  digest="$(LC_ALL=C find "$canonical/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$canonical/.skills-lock.json" "$ROOT/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  printf '%s\n' '{"permission":{"skill":{"*":"deny"}}}' > "$config"
  HOME="$tmp" "$ROOT/install.sh" --tool opencode --link --migrate --apply >/dev/null
  [[ -d "$canonical/code-simplification" ]] || fail "canonical link migration did not install the replacement"
  python3 - "$config" <<'PY'
import json
import sys

skills = json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"]
assert skills == {"*": "deny", "code-simplification": "allow"}, skills
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_doctor_frontmatter_identity() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.commandcode/skills/foo" "$tmp/.agents/skills/baz" "$tmp/.agents/skills/qux" "$tmp/.agents/skills/quoted"
  printf '%s\n' '---' 'name: bar # renamed' 'description: x' '---' > "$tmp/.commandcode/skills/foo/SKILL.md"
  printf '%s\n' '---' "name: 'foo'" 'description: x' '---' > "$tmp/.agents/skills/baz/SKILL.md"
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode)" || fail "doctor matched a dir name against a frontmatter name: $output"

  mkdir -p "$tmp/.commandcode/skills/docker-local"
  printf '%s\n' '---' 'name: docker # shared skill' 'description: x' '---' > "$tmp/.commandcode/skills/docker-local/SKILL.md"
  printf '%s\n' '---' 'name: "docker" # quoted' 'description: x' '---' > "$tmp/.agents/skills/qux/SKILL.md"
  printf '%s\n' '---' 'name: "a # b"' 'description: x' '---' > "$tmp/.agents/skills/quoted/SKILL.md"
  if output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode)"; then
    fail "doctor missed a frontmatter-name collision"
  fi
  grep -q '\[!\] name docker: .*/.commandcode/skills/docker-local, .*/.agents/skills/qux' <<< "$output" || fail "doctor did not report the frontmatter collision: $output"
  if grep -q -E '# (shared|quoted)|\[!\] (dir|name) (foo|bar|baz|a)\b' <<< "$output"; then
    fail "doctor kept a comment or reported a false collision: $output"
  fi

  mkdir -p "$tmp/.commandcode/skills/esc" "$tmp/.agents/skills/plain" "$tmp/.agents/skills/bad"
  printf '%s\n' '---' 'name: "\u0067it"' 'description: x' '---' > "$tmp/.commandcode/skills/esc/SKILL.md"
  printf '%s\n' '---' 'name: git' 'description: x' '---' > "$tmp/.agents/skills/plain/SKILL.md"
  printf '%s\n' '---' 'name: "\q"' 'description: x' '---' > "$tmp/.agents/skills/bad/SKILL.md"
  mkdir -p "$tmp/.agents/skills/huge"
  printf '%s\n' '---' 'name: "\U00110000"' 'description: x' '---' > "$tmp/.agents/skills/huge/SKILL.md"
  mkdir -p "$tmp/.commandcode/skills/surrogate" "$tmp/.agents/skills/surrogate2"
  printf '%s\n' '---' 'name: "\uD800"' 'description: x' '---' > "$tmp/.commandcode/skills/surrogate/SKILL.md"
  printf '%s\n' '---' 'name: "\uD800"' 'description: x' '---' > "$tmp/.agents/skills/surrogate2/SKILL.md"
  local status=0
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode 2>&1)" || status=$?
  (( status == 1 )) || fail "doctor exited $status on malformed escapes, want 1: $output"
  grep -q 'duplicate skill name(s) reachable' <<< "$output" || fail "doctor did not finish on malformed escapes: $output"
  if grep -q 'Traceback' <<< "$output"; then fail "doctor crashed on malformed escapes: $output"; fi
  grep -q '\[!\] name git: .*/.commandcode/skills/esc, .*/.agents/skills/plain' <<< "$output" || fail "doctor did not decode a YAML escape: $output"
  rm -rf "$tmp"
  trap - RETURN
}

test_doctor_reports_duplicates_read_only() {
  local tmp before output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  HOME="$tmp" "$ROOT/install.sh" --tool claude,commandcode --link --no-backup docker >/dev/null
  mkdir -p "$tmp/.config/opencode"
  printf '%s\n' '{"permission":{"skill":{"*":"deny"}}}' > "$tmp/.config/opencode/opencode.json"
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode,opencode)" || fail "doctor failed on a clean layout"
  grep -q 'harness config toggles are not read' <<< "$output" || fail "doctor did not state its static scope"
  grep -q '\[i\] dir docker: .*/.claude/skills/docker, .*/.agents/skills/docker' <<< "$output" || fail "doctor did not report the OpenCode compat overlap as info"

  make_legacy_commandcode "$tmp" git
  before="$(tree_hash "$tmp")"
  if output="$(HOME="$tmp" "$ROOT/install.sh" --doctor 2>&1)"; then
    fail "doctor passed with a planted duplicate"
  fi
  grep -q '\[!\] dir git: .*/.commandcode/skills/git, .*/.agents/skills/git' <<< "$output" || fail "doctor did not name the duplicate paths"
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "doctor changed files"
  if HOME="$tmp" "$ROOT/install.sh" --doctor --link >/dev/null 2>&1; then
    fail "doctor accepted --link"
  fi
  rm -rf "$tmp"
  trap - RETURN
}

write_fixture_skill() {
  mkdir -p "$1/skills/$2"
  printf '%s\n' "$3" > "$1/skills/$2/SKILL.md"
}

installed_dirs() {
  find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | paste -sd' '
}

make_frontmatter_fixture() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  cp "$ROOT/install.sh" "$repo/install.sh"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$repo/scripts/"
  write_fixture_skill "$repo" public $'---\nname: public\ndescription: d\nmetadata:\n  internal: false\n---'
  write_fixture_skill "$repo" bare $'---\ndescription: no name or metadata\n---'
  write_fixture_skill "$repo" private $'---\nname: private\ndescription: d\nmetadata:\n  internal: true\n---'
  write_fixture_skill "$repo" team $'---\nname: team\ndescription: tracked but internal\nmetadata:\n  internal: true\n---'
  write_fixture_skill "$repo" ignored $'---\nname: ignored\ndescription: d\n---'
  write_fixture_skill "$repo" old $'---\nname: old\ndescription: d\nmetadata:\n  deprecated: true\n---'
  printf '%s\n' 'skills/private/' 'skills/ignored/' > "$repo/.gitignore"
  git -C "$repo" init -q
}

test_frontmatter_cache_selects_skills() {
  local tmp repo output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  repo="$tmp/repo"
  make_frontmatter_fixture "$repo"
  export SKILLS_MIGRATIONS_FILE="$tmp/none.json"

  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/default" --no-backup >/dev/null
  [[ "$(installed_dirs "$tmp/default")" == "bare public" ]] || fail "default install picked: $(installed_dirs "$tmp/default")"

  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/internal" --no-backup --include-internal >/dev/null
  [[ "$(installed_dirs "$tmp/internal")" == "bare private public team" ]] || fail "--include-internal picked: $(installed_dirs "$tmp/internal")"

  # A tracked skill marked internal is discovered, left out of the default
  # selection, and still installs when requested by name.
  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/listed" --list > "$tmp/list"
  grep -q '^  team' "$tmp/list" || fail "tracked internal skill missing from --list"
  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/named" --no-backup team >/dev/null
  [[ "$(installed_dirs "$tmp/named")" == "team" ]] || fail "named internal install picked: $(installed_dirs "$tmp/named")"
  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/named-internal" --no-backup --include-internal team >/dev/null
  [[ "$(installed_dirs "$tmp/named-internal")" == "team" ]] || fail "named --include-internal install picked: $(installed_dirs "$tmp/named-internal")"

  output="$(HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/explicit" --no-backup old)"
  grep -q 'old is deprecated and scheduled for removal' <<< "$output" || fail "deprecated notice missing from cached lookup"
  unset SKILLS_MIGRATIONS_FILE
  rm -rf "$tmp"
  trap - RETURN
}

test_malformed_frontmatter_fails_install() {
  local tmp repo output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  repo="$tmp/repo"
  make_frontmatter_fixture "$repo"
  printf '%s\n' '---' 'name: broken' 'description: no closing marker' > "$repo/skills/public/SKILL.md"

  if output="$(HOME="$tmp" SKILLS_MIGRATIONS_FILE="$tmp/none.json" "$repo/install.sh" --tool portable --dest "$tmp/dest" --no-backup 2>&1)"; then
    fail "install accepted malformed frontmatter"
  fi
  grep -q "invalid frontmatter in $repo/skills/public/SKILL.md" <<< "$output" || fail "malformed frontmatter error did not name the file"
  grep -q 'Cannot continue with invalid skill frontmatter' <<< "$output" || fail "installer did not stop on malformed frontmatter"
  [[ ! -e "$tmp/dest" ]] || fail "install wrote files despite malformed frontmatter"
  rm -rf "$tmp"
  trap - RETURN
}

test_backups_stay_outside_skill_root
test_legacy_backups_are_migrated_outside_skill_root
test_opencode_install_allows_installed_skills
test_link_mode_writes_tool_lock
test_link_mode_writes_tool_lock_gemini
test_omp_default_path
test_omp_skills_dir_override
test_omp_link_mode_shares_canonical_dir
test_omp_repeat_install_is_idempotent
test_omp_check_mode
test_omp_and_gemini_share_destination
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
test_remapped_tools_install_once_into_agents_dir
test_opencode_link_into_canonical_syncs_permissions
test_install_hints_at_legacy_cleanup
test_legacy_cleanup_end_to_end
test_legacy_cleanup_backup_failure_removes_nothing
test_legacy_cleanup_converges_after_interruption
test_legacy_cleanup_refuses_unsafe_layouts
test_legacy_cleanup_custom_canonical_needs_replacement
test_opencode_link_migration_on_canonical_allows_replacement
test_doctor_frontmatter_identity
test_doctor_reports_duplicates_read_only
test_frontmatter_cache_selects_skills
test_malformed_frontmatter_fails_install
printf 'install tests passed\n'
