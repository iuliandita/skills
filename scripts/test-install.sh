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

test_backups_stay_outside_skill_root
test_legacy_backups_are_migrated_outside_skill_root
test_opencode_install_allows_installed_skills
test_link_mode_writes_tool_lock
test_backup_preserves_top_level_symlink
printf 'install tests passed\n'
