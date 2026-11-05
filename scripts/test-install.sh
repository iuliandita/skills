#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

# Installer overrides must not leak into test fixtures.
while IFS= read -r var; do unset "$var"; done < <(compgen -e | grep -E '^([A-Z0-9_]+_SKILLS_DIR|SKILLS_[A-Z0-9_]+|OPENCODE_CONFIG_FILE|XDG_(CONFIG|STATE|DATA|CACHE)_HOME)$' || true)

# Even older --dest-only tests must acquire locks under a temporary HOME.
TEST_INSTALL_HOME="$(mktemp -d)"
export HOME="$TEST_INSTALL_HOME"
trap 'rm -rf "$TEST_INSTALL_HOME"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_legacy_notice() {
  mkdir -p "$1"
  cat > "$1/SKILL.md" <<'NOTICE'
---
name: anti-slop
description: >
  Deprecated name. Use code-simplification; load this notice only when anti-slop is explicitly requested.
license: MIT
metadata:
  source: iuliandita/skills
  date_added: "2026-09-20"
  effort: low
  deprecated: "true"
---

# Deprecated: anti-slop

This old skill name is retained temporarily to explain the catalog migration. It provides migration guidance only and does not contain the former task workflow.

Use **code-simplification** instead.
NOTICE
}

# Minimal installer source tree that still carries a deprecated notice, so the
# tests do not depend on a retired skill existing in the real source tree.
make_legacy_source() {
  local src="$1"
  mkdir -p "$src/scripts" "$src/skills"
  cp "$ROOT/install.sh" "$ROOT/migrations.json" "$src/"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$ROOT/scripts/migrate-skills.py" "$src/scripts/"
  cp -r "$ROOT/skills/code-simplification" "$src/skills/code-simplification"
  cp -r "$ROOT/skills/docker" "$src/skills/docker"
  write_legacy_notice "$src/skills/anti-slop"
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

test_backup_override_separates_destinations() {
  local tmp count
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  HOME="$tmp" "$ROOT/install.sh" --tool claude --no-backup docker >/dev/null
  HOME="$tmp" "$ROOT/install.sh" --tool cursor --no-backup docker >/dev/null
  HOME="$tmp" SKILLS_BACKUP_DIR="$tmp/b" "$ROOT/install.sh" --tool claude,cursor --force docker >/dev/null
  count="$(find "$tmp/b" -mindepth 1 -maxdepth 1 -type d -name 'skills-*' | wc -l)"
  [[ "$count" -eq 2 ]] || fail "expected two destination backup folders"
  rm -rf "$tmp"
  trap - RETURN
}

test_unverified_lock_backups_are_unique() {
  local tmp dest i
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/s"
  for i in 1 2; do
    mkdir -p "$dest"
    printf '%s\n' '{"version":1,"source":"/nope","skills":{}}' > "$dest/.skills-lock.json"
    HOME="$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  done
  [[ "$(find "$tmp/.skills-backups/s/.unverified-locks" -type f | wc -l)" -eq 2 ]] || fail "expected two lock backups"
  rm -rf "$tmp"
  trap - RETURN
}

test_shared_destination_is_installed_once() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  HOME="$tmp" "$ROOT/install.sh" --tool codex --no-backup docker >/dev/null
  echo EDIT >> "$tmp/.agents/skills/docker/SKILL.md"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool codex,opencode,kimi,commandcode --force docker)"
  [[ "$(grep -c 'docker backed up' <<< "$output")" -eq 1 ]] || fail "shared destination backed up more than once"
  [[ "$(grep -l EDIT "$tmp"/.agents/.skills-backups/skills/docker/*/SKILL.md | wc -l)" -eq 1 ]] || fail "edited backup missing"
  rm -rf "$tmp"
  trap - RETURN
}

test_backup_retention_keeps_three_unique() {
  local tmp dest root i newest
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/s"; root="$tmp/.skills-backups/s/docker"
  HOME="$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  for i in 1 2 3 4 5; do
    echo "EDIT$i" >> "$dest/docker/SKILL.md"
    HOME="$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --force docker >/dev/null
  done
  [[ "$(find "$root" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 3 ]] || fail "expected three backups"
  newest="$(find "$root" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
  grep -q EDIT5 "$newest/SKILL.md" || fail "newest backup lacks last edit"
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

test_legacy_backup_migration_keeps_layout_on_collision() {
  local tmp dest root date_cmd
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"; root="$tmp/agent/.skills-backups/skills/.legacy"
  date_cmd="$(command -v date)"
  mkdir -p "$tmp/bin" "$root/20260101-000000-00" "$dest/.backups/docker/legacy" "$tmp/elsewhere"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\n[ "$1" = +%%Y%%m%%d-%%H%%M%%S ] && { echo 20260101-000000; exit 0; }\nexec %s "$@"\n' "$date_cmd" > "$tmp/bin/date"
  chmod +x "$tmp/bin/date"
  echo keep > "$root/20260101-000000-00/keep"
  echo legacy > "$dest/.backups/docker/legacy/SKILL.md"
  echo hidden > "$dest/.backups/.hidden"
  HOME="$tmp" PATH="$tmp/bin:$PATH" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  [[ "$(find "$root/20260101-000000-00" -mindepth 1 | wc -l)" -eq 1 && -f "$root/20260101-000000-00/keep" ]] || fail "collision overwrote existing backup"
  [[ -f "$root/20260101-000000-01/docker/legacy/SKILL.md" && -f "$root/20260101-000000-01/.hidden" && ! -e "$root/20260101-000000-01/.backups" && ! -e "$dest/.backups" ]] || fail "legacy backup layout changed"
  echo untouched > "$tmp/elsewhere/keep"
  ln -s "$tmp/elsewhere" "$dest/.backups"
  HOME="$tmp" PATH="$tmp/bin:$PATH" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  [[ -L "$root/20260101-000000-02" && "$(readlink "$root/20260101-000000-02")" == "$tmp/elsewhere" && "$(cat "$tmp/elsewhere/keep")" == untouched ]] || fail "legacy symlink migration changed target"
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

test_link_mode_never_links_canonical_onto_itself() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  output="$(HOME="$tmp" SKILLS_CANONICAL_DIR="$tmp/.agents/skills/" "$ROOT/install.sh" --tool codex --link --force --no-backup docker)"
  [[ -f "$tmp/.agents/skills/docker/SKILL.md" && ! -L "$tmp/.agents/skills/docker" ]] || fail "trailing slash linked canonical onto itself"
  grep -q 'matches canonical, skipping links' <<< "$output" || fail "trailing slash canonical match not reported"

  mkdir -p "$tmp/other"
  mv "$tmp/.agents/skills" "$tmp/other/skills"
  rmdir "$tmp/.agents"
  ln -s "$tmp/other" "$tmp/.agents"
  output="$(HOME="$tmp" CODEX_SKILLS_DIR="$tmp/.agents/skills" SKILLS_CANONICAL_DIR="$tmp/other/skills" "$ROOT/install.sh" --tool codex --link --force --no-backup docker)"
  [[ -f "$tmp/other/skills/docker/SKILL.md" && ! -L "$tmp/other/skills/docker" ]] || fail "symlinked path linked canonical onto itself"
  grep -q 'matches canonical, skipping links' <<< "$output" || fail "symlinked canonical match not reported"

  rm -rf "$tmp"
  trap - RETURN
}

test_link_mode_keeps_foreign_symlink_without_force() {
  local tmp backup
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/mine" "$tmp/.claude/skills"
  ln -s "$tmp/mine" "$tmp/.claude/skills/docker"
  HOME="$tmp" "$ROOT/install.sh" --tool claude --link docker >/dev/null
  [[ "$(readlink "$tmp/.claude/skills/docker")" == "$tmp/mine" ]] || fail "foreign symlink replaced without force"
  HOME="$tmp" "$ROOT/install.sh" --tool claude --link --force docker >/dev/null
  [[ "$(readlink "$tmp/.claude/skills/docker")" == "$tmp/.agents/skills/docker" ]] || fail "foreign symlink not replaced with force"
  backup="$(find "$tmp/.claude/.skills-backups" -type l -name docker)"
  [[ -n "$backup" && "$(readlink "$backup")" == "$tmp/mine" ]] || fail "foreign symlink not backed up"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_string_permissions_are_preserved() {
  local tmp config case output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  config="$tmp/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  for case in global skill invalid; do
    case "$case" in
      global) printf '%s\n' '{"permission":"ask"}' > "$config" ;;
      skill) printf '%s\n' '{"permission":{"bash":"deny","skill":"deny"}}' > "$config" ;;
      invalid) printf '%s\n' '{"permission":["x"]}' > "$config" ;;
    esac
    cp "$config" "$tmp/before.json"
    if [[ "$case" == invalid ]]; then
      if output="$(HOME="$tmp" "$ROOT/install.sh" --tool opencode --no-backup docker 2>&1)"; then
        fail "invalid OpenCode permission was accepted"
      fi
      grep -q 'OpenCode permission sync failed' <<< "$output" || fail "OpenCode failure was not reported"
      cmp "$tmp/before.json" "$config" || fail "invalid OpenCode permission was changed"
    else
      HOME="$tmp" "$ROOT/install.sh" --tool opencode --no-backup docker >/dev/null
      python3 - "$config" "$case" <<'PYTEST'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    permission = json.load(f)["permission"]
if sys.argv[2] == "global":
    assert list(permission) == ["*", "skill"]
    assert permission["*"] == "ask"
    expected = "ask"
else:
    assert permission["bash"] == "deny"
    expected = "deny"
skill = permission["skill"]
assert list(skill) == ["*", "docker"]
assert skill == {"*": expected, "docker": "allow"}
PYTEST
    fi
  done
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

test_removed_gemini_tool_is_unknown() {
  local tmp output rc=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  output="$(HOME="$tmp" "$ROOT/install.sh" --check --tool gemini 2>&1)" || rc=$?
  [[ "$rc" -eq 1 ]] || fail "--check --tool gemini exited $rc, expected 1"
  grep -q 'error: unknown tool: gemini;' <<< "$output" || fail "--check --tool gemini did not report an unknown tool"

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

test_plain_install_reports_current_for_unchanged_copies() {
  local tmp output lock_before lock_after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker git >/dev/null
  lock_before="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker git 2>&1)" \
    || fail "reinstall of unchanged skills failed: $output"
  grep -q '\[=\] docker current' <<< "$output" || fail "docker not reported current: $output"
  grep -q '\[=\] git current' <<< "$output" || fail "git not reported current: $output"
  grep -q -- '--force' <<< "$output" && fail "unchanged reinstall mentioned --force: $output"
  lock_after="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  [[ "$lock_after" == "$lock_before" ]] || fail "lock changed for an all-current reinstall"

  rm -rf "$tmp"
  trap - RETURN
}

test_plain_install_reports_differs_for_locally_edited_copy() {
  local tmp output lock_before lock_after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker git >/dev/null
  printf 'local edit\n' >> "$tmp/.agents/skills/docker/SKILL.md"
  lock_before="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker git 2>&1)" \
    || fail "reinstall with one differing skill failed: $output"
  grep -q '\[~\] docker differs from source (use --force to overwrite)' <<< "$output" \
    || fail "differing skill not reported: $output"
  grep -q '\[=\] git current' <<< "$output" || fail "unaffected skill not reported current: $output"
  (( "$(grep -c '\[~\]' <<< "$output")" == 1 )) || fail "expected exactly one differs line: $output"
  grep -q '1 skill(s) differ; use --force to overwrite' <<< "$output" || fail "differ count line missing: $output"
  lock_after="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  [[ "$lock_after" == "$lock_before" ]] || fail "lock changed though docker was left unpublished"

  rm -rf "$tmp"
  trap - RETURN
}

test_plain_install_leaves_unrecorded_differing_copy_unrecorded() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/.agents/skills/docker"
  cp -r "$ROOT/skills/docker/." "$tmp/.agents/skills/docker/"
  printf 'stray local copy\n' >> "$tmp/.agents/skills/docker/SKILL.md"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker 2>&1)" \
    || fail "install over an unrecorded differing copy failed: $output"
  grep -q '\[~\] docker' <<< "$output" || fail "unrecorded differing copy not reported: $output"
  if [[ -f "$tmp/.agents/skills/.skills-lock.json" ]]; then
    grep -q '"docker"' "$tmp/.agents/skills/.skills-lock.json" \
      && fail "unrecorded differing copy gained a lock record: $(cat "$tmp/.agents/skills/.skills-lock.json")"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_plain_install_reports_rename_and_symlink_target_differences() {
  local tmp src output lock lock_before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  src="$tmp/repo"
  mkdir -p "$src/scripts" "$src/skills"
  cp "$ROOT/install.sh" "$ROOT/migrations.json" "$src/"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$ROOT/scripts/migrate-skills.py" "$src/scripts/"
  cp -R "$ROOT/skills/git" "$src/skills/git"
  printf 'notes\n' > "$src/skills/git/notes-a.md"
  ln -s SKILL.md "$src/skills/git/alias.md"

  HOME="$tmp/home" "$src/install.sh" --tool omp --no-backup git >/dev/null
  lock="$tmp/home/.agents/skills/.skills-lock.json"
  lock_before="$(cat "$lock")"

  # Rename-only: identical bytes at a different relative path. The v1
  # content hash (which ignores paths) still matches the source; the v2
  # tree digest (which encodes paths) does not.
  mv "$tmp/home/.agents/skills/git/notes-a.md" "$tmp/home/.agents/skills/git/notes-z.md"
  output="$(HOME="$tmp/home" "$src/install.sh" --tool omp --no-backup git 2>&1)" \
    || fail "reinstall over a rename-only difference failed: $output"
  grep -q '\[~\] git differs from source (use --force to overwrite)' <<< "$output" \
    || fail "rename-only difference not reported: $output"
  [[ "$(cat "$lock")" == "$lock_before" ]] || fail "lock changed for an unpublished rename-only difference"
  mv "$tmp/home/.agents/skills/git/notes-z.md" "$tmp/home/.agents/skills/git/notes-a.md"

  # Symlink-target-only: skill_hash (v1) never looks at symlinks at all, so
  # only the v2 tree digest notices the retargeted link.
  ln -sfn notes-a.md "$tmp/home/.agents/skills/git/alias.md"
  output="$(HOME="$tmp/home" "$src/install.sh" --tool omp --no-backup git 2>&1)" \
    || fail "reinstall over a symlink-target-only difference failed: $output"
  grep -q '\[~\] git differs from source (use --force to overwrite)' <<< "$output" \
    || fail "symlink-target-only difference not reported: $output"
  [[ "$(cat "$lock")" == "$lock_before" ]] || fail "lock changed for an unpublished symlink-target-only difference"

  rm -rf "$tmp"
  trap - RETURN
}

test_plain_install_keeps_unverifiable_copy_unpublished() {
  local tmp output lock_before lock_after status=0
  if (( EUID == 0 )); then
    printf 'SKIP: running as root, unreadable-file test not meaningful\n'
    return
  fi
  tmp="$(mktemp -d)"
  trap 'chmod -R u+rwX "$tmp"; rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  lock_before="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  chmod 000 "$tmp/.agents/skills/docker/SKILL.md"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker 2>&1)" || status=$?
  chmod u+rw "$tmp/.agents/skills/docker/SKILL.md"
  (( status == 0 )) || fail "unverifiable copy made the install fail ($status): $output"
  grep -q '\[~\] docker already exists (use --force to overwrite)' <<< "$output" \
    || fail "unverifiable copy not reported with the fallback wording: $output"
  if grep -q '\[=\] docker current' <<< "$output"; then fail "unverifiable copy reported current: $output"; fi
  lock_after="$(cat "$tmp/.agents/skills/.skills-lock.json")"
  [[ "$lock_after" == "$lock_before" ]] || fail "lock changed for an unverifiable copy"

  chmod -R u+rwX "$tmp"
  rm -rf "$tmp"
  trap - RETURN
}

test_force_still_overwrites_a_differing_copy() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup docker >/dev/null
  printf 'local edit\n' >> "$tmp/.agents/skills/docker/SKILL.md"
  output="$(HOME="$tmp" "$ROOT/install.sh" --tool omp --no-backup --force docker 2>&1)" \
    || fail "forced reinstall failed: $output"
  grep -q '\[+\] docker installed' <<< "$output" || fail "forced reinstall did not report installed: $output"
  cmp -s "$ROOT/skills/docker/SKILL.md" "$tmp/.agents/skills/docker/SKILL.md" \
    || fail "forced reinstall did not restore source content"

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

test_omp_and_kimi_share_destination() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  HOME="$tmp" "$ROOT/install.sh" --tool omp,kimi --link --no-backup docker >/dev/null
  if [[ ! -d "$tmp/.agents/skills/docker" ]]; then
    fail "omp,kimi shared install did not populate ~/.agents/skills"
  fi
  if [[ -L "$tmp/.agents/skills/docker" ]]; then
    fail "omp,kimi shared install created a self-symlink"
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
  local tmp output src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"

  "$src/install.sh" --tool portable --dest "$tmp/default" --no-backup >/dev/null
  [[ ! -e "$tmp/default/anti-slop" ]] || fail "default install selected a deprecated skill"
  output="$("$src/install.sh" --tool portable --dest "$tmp/explicit" --no-backup anti-slop)"
  grep -q 'anti-slop is deprecated' <<< "$output" || fail "explicit deprecated install did not show notice"
  "$src/install.sh" --tool portable --dest "$tmp/explicit" --list > "$tmp/list"
  grep -q 'anti-slop.*deprecated' "$tmp/list" || fail "list did not mark deprecated skill"
  rm -rf "$tmp"
  trap - RETURN
}

test_check_reports_legacy_manifest_skill() {
  local tmp digest output src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"

  mkdir -p "$tmp/skills"
  write_legacy_notice "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": sys.argv[3]}}, f)
PY
  if output="$("$src/install.sh" --tool portable --dest "$tmp/skills" --check 2>&1)"; then
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
  grep -q 'cannot continue with an invalid migrations.json' <<< "$output" || fail "invalid manifest failure was unclear"
  rm -rf "$tmp"
  trap - RETURN
}

test_installer_migration_dry_run_and_apply() {
  local tmp digest src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"

  mkdir -p "$tmp/skills"
  write_legacy_notice "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  "$src/install.sh" --tool portable --dest "$tmp/skills" --migrate > "$tmp/dry-run"
  [[ -d "$tmp/skills/anti-slop" ]] || fail "installer migration dry run retired old skill"
  [[ ! -e "$tmp/skills/code-simplification" ]] || fail "installer migration dry run installed replacement"
  SKILLS_BACKUP_DIR="$tmp/migration-backups" "$src/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/apply"
  [[ ! -e "$tmp/skills/anti-slop" ]] || fail "installer migration apply did not retire old skill"
  [[ -d "$tmp/skills/code-simplification" ]] || fail "installer migration apply did not install replacement"
  if ! find "$tmp/migration-backups/anti-slop" -type f -name SKILL.md -print -quit | grep -q .; then
    fail "installer migration did not honor SKILLS_BACKUP_DIR"
  fi
  if output="$(LC_ALL=en_US.utf8 "$src/install.sh" --tool portable --dest "$tmp/skills" --check 2>&1)"; then
    fail "check accepted incomplete migration fixture"
  fi
  grep -q 'code-simplification.*current' <<< "$output" || fail "locale check did not recognize migrated replacement"
  rm -rf "$tmp"
  trap - RETURN
}

test_skipped_custom_skill_keeps_old_lock_and_migration_skips_it() {
  local tmp output src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"

  "$src/install.sh" --tool portable --dest "$tmp/skills" --no-backup anti-slop >/dev/null
  printf '%s\n' 'custom local change' >> "$tmp/skills/anti-slop/SKILL.md"
  "$src/install.sh" --tool portable --dest "$tmp/skills" --no-backup anti-slop >/dev/null
  "$src/install.sh" --tool portable --dest "$tmp/skills" --migrate --apply > "$tmp/migration"
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
  local tmp digest src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"
  mkdir -p "$tmp/claude" "$tmp/codex"
  write_legacy_notice "$tmp/claude/anti-slop"
  write_legacy_notice "$tmp/codex/anti-slop"
  digest="$(LC_ALL=C find "$tmp/claude/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/claude/.skills-lock.json" "$tmp/codex/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

for path in sys.argv[1:3]:
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "source": sys.argv[3], "skills": {"anti-slop": {"hash": sys.argv[4], "provenance": "source-equal-v1"}}}, f)
PY
  CLAUDE_SKILLS_DIR="$tmp/claude" CODEX_SKILLS_DIR="$tmp/codex" "$src/install.sh" --tool claude,codex --migrate --apply >/dev/null
  for destination in "$tmp/claude" "$tmp/codex"; do
    [[ ! -e "$destination/anti-slop" && -d "$destination/code-simplification" ]] || fail "copy migration missed $destination"
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_copy_canonical_migration_preserves_legacy_target() {
  local tmp canonical digest src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"
  canonical="$tmp/canonical"
  mkdir -p "$canonical" "$tmp/unselected"
  write_legacy_notice "$canonical/anti-slop"
  digest="$(LC_ALL=C find "$canonical/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$canonical/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  ln -s "$canonical/anti-slop" "$tmp/unselected/anti-slop"
  KIMI_SKILLS_DIR="$canonical" SKILLS_CANONICAL_DIR="$canonical" "$src/install.sh" --tool kimi --migrate --apply >/dev/null
  [[ -d "$canonical/anti-slop" && -d "$canonical/code-simplification" ]] || fail "canonical migration retired shared legacy target"
  [[ -e "$tmp/unselected/anti-slop/SKILL.md" ]] || fail "canonical migration broke an unselected tool link"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_migration_syncs_apply_only() {
  local tmp digest config_before config_after src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"
  mkdir -p "$tmp/skills" "$tmp/config"
  write_legacy_notice "$tmp/skills/anti-slop"
  digest="$(LC_ALL=C find "$tmp/skills/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$tmp/skills/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  config_before='{"permission":{"skill":{"*":"deny","custom":"deny"}}}'
  printf '%s\n' "$config_before" > "$tmp/config/opencode.json"
  OPENCODE_SKILLS_DIR="$tmp/skills" OPENCODE_CONFIG_FILE="$tmp/config/opencode.json" "$src/install.sh" --tool opencode --migrate >/dev/null
  config_after="$(<"$tmp/config/opencode.json")"
  [[ "$config_after" == "$config_before" ]] || fail "OpenCode migration dry run changed permissions"
  OPENCODE_SKILLS_DIR="$tmp/skills" OPENCODE_CONFIG_FILE="$tmp/config/opencode.json" "$src/install.sh" --tool opencode --migrate --apply >/dev/null
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

# json_check JSON PYTHON_EXPRESSION LABEL: the expression sees the parsed object as d.
# The expressions are written in this file; nothing external reaches eval.
json_check() {
  python3 -I -c 'import json, sys; d = json.loads(sys.argv[1]); sys.exit(0 if eval(sys.argv[2]) else 1)' "$1" "$2" \
    || fail "$3: $1"
}

# run_json HOME ARGS...: sets JSON_OUT (stdout), JSON_ERR (stderr), JSON_STATUS.
run_json() {
  local home="$1"
  JSON_STATUS=0
  JSON_OUT="$(isolated "$home" "$ROOT/install.sh" "${@:2}" --json 2>"$home/json.err")" || JSON_STATUS=$?
  JSON_ERR="$(<"$home/json.err")"
  [[ "$(wc -l <<< "$JSON_OUT")" == 1 ]] || fail "--json did not print exactly one line: $JSON_OUT"
}

test_json_output() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  run_json "$tmp" --tool claude docker
  (( JSON_STATUS == 0 )) || fail "json install exited $JSON_STATUS: $JSON_ERR"
  json_check "$JSON_OUT" 'd["ok"] is True and d["errors"] == [] and d["command"] == "install" and d["link"] is False and d["failed"] == 0' "install keys"
  json_check "$JSON_OUT" 'd["destinations"][0]["tool"] == "claude" and d["destinations"][0]["kind"] == "copy" and d["destinations"][0]["installed"] == ["docker"]' "install destination"
  grep -q 'Done. Skills installed for claude' <<< "$JSON_ERR" || fail "human output not on stderr: $JSON_ERR"

  run_json "$tmp" --list --tool claude
  json_check "$JSON_OUT" 'd["ok"] is True and d["command"] == "list" and {"name": "docker", "status": "installed", "deprecated": False} in d["skills"]' "list keys"

  run_json "$tmp" --check --tool claude
  (( JSON_STATUS == 1 )) || fail "json check with missing skills exited $JSON_STATUS"
  json_check "$JSON_OUT" 'd["ok"] is False and d["command"] == "check" and d["summary"]["current"] == 1 and d["summary"]["not_installed"] > 0 and {"name": "docker", "state": "current"} in d["skills"] and d["legacy"] == [] and d["errors"]' "check keys"

  run_json "$tmp" --check --tool cursor
  (( JSON_STATUS == 1 )) || fail "json check without a lock exited $JSON_STATUS"
  json_check "$JSON_OUT" 'd["ok"] is False and d["errors"][0].startswith("no lock file found at ")' "check without lock"

  mkdir "$tmp/linked"
  run_json "$tmp/linked" --tool claude,cursor --link docker
  (( JSON_STATUS == 0 )) || fail "json link install exited $JSON_STATUS: $JSON_ERR"
  json_check "$JSON_OUT" 'd["link"] is True and [x["kind"] for x in d["destinations"]] == ["canonical", "link", "link"] and d["destinations"][0]["tool"] is None' "link destinations"

  run_json "$tmp" --migrate --tool claude
  (( JSON_STATUS == 0 )) || fail "json migrate preview exited $JSON_STATUS: $JSON_ERR"
  json_check "$JSON_OUT" 'd["ok"] is True and d["command"] == "migrate" and d["apply"] is False and d["tools"] == ["claude"] and all(set(r) == {"dest", "status", "text"} for r in d["records"]) and d["records"]' "migrate preview keys"

  run_json "$tmp" --doctor --tool claude
  json_check "$JSON_OUT" 'd["ok"] is True and d["command"] == "doctor" and d["blocking"] == 0 and d["tools"][0]["tool"] == "claude"' "doctor keys"

  run_json "$tmp" --bogus
  (( JSON_STATUS == 1 )) || fail "json usage error exited $JSON_STATUS"
  json_check "$JSON_OUT" 'd["ok"] is False and d["errors"][0].startswith("unknown option: --bogus") and d["command"] is None' "usage error"

  run_json "$tmp" --help
  json_check "$JSON_OUT" 'd["ok"] is True and d["command"] == "help"' "help"
  grep -q '^Environment:' <<< "$JSON_ERR" || fail "--help has no Environment section"
  grep -q '^Exit codes:' <<< "$JSON_ERR" || fail "--help has no Exit codes section"
}

test_harness_alias_matches_tool() {
  local tmp output status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  isolated "$tmp" "$ROOT/install.sh" --harness portable --dest "$tmp/via-harness" --no-backup docker >/dev/null
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$tmp/via-tool" --no-backup docker >/dev/null
  diff -r "$tmp/via-harness/docker" "$tmp/via-tool/docker" >/dev/null || fail "--harness installed different files than --tool"
  isolated "$tmp" "$ROOT/install.sh" --harness claude --harness cursor --no-backup docker >/dev/null
  [[ -d "$tmp/.claude/skills/docker" && -d "$tmp/.cursor/skills/docker" ]] || fail "repeated --harness did not install both tools"
  output="$(isolated "$tmp" "$ROOT/install.sh" --check --harness claude 2>&1)" || status=$?
  grep -q 'docker' <<< "$output" || fail "--check --harness did not report the installed skill: $output"
  status=0
  output="$(isolated "$tmp" "$ROOT/install.sh" --harness 2>&1)" || status=$?
  { (( status == 1 )) && grep -q 'error: --harness requires a value' <<< "$output"; } || fail "bare --harness: $status $output"
  status=0
  output="$(isolated "$tmp" "$ROOT/install.sh" --harness claude,,cursor 2>&1)" || status=$?
  { (( status == 1 )) && grep -q 'error: --harness requires non-empty tool names' <<< "$output"; } || fail "empty --harness name: $status $output"
  grep -q -- '--harness TOOL      Alias of --tool' < <("$ROOT/install.sh" --help) || fail "--help does not document --harness"
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
  local tmp canonical digest config src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"
  canonical="$tmp/.agents/skills"
  config="$tmp/.config/opencode/opencode.json"
  mkdir -p "$canonical" "$(dirname "$config")"
  write_legacy_notice "$canonical/anti-slop"
  digest="$(LC_ALL=C find "$canonical/anti-slop" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)"
  python3 - "$canonical/.skills-lock.json" "$src/skills" "$digest" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"version": 1, "source": sys.argv[2], "skills": {"anti-slop": {"hash": sys.argv[3], "provenance": "source-equal-v1"}}}, f)
PY
  printf '%s\n' '{"permission":{"skill":{"*":"deny"}}}' > "$config"
  HOME="$tmp" "$src/install.sh" --tool opencode --link --migrate --apply >/dev/null
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

test_embedded_python_ignores_cwd_modules() {
  local tmp module
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/cwd"
  for module in json os; do
    printf 'open("%s", "w").close()\n' "$tmp/pwned" > "$tmp/cwd/$module.py"
  done
  (cd "$tmp/cwd" && HOME="$tmp" "$ROOT/install.sh" --list >/dev/null)
  (cd "$tmp/cwd" && HOME="$tmp" "$ROOT/install.sh" --tool opencode --no-backup docker >/dev/null)
  [[ ! -e "$tmp/pwned" ]] || fail "embedded Python imported a module from cwd"
  ! grep -nE 'python3 -(c | |$)' "$ROOT/install.sh" || fail "embedded Python invocation is not isolated"
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
  grep -q 'blocking finding(s) across 1 tool(s)' <<< "$output" || fail "doctor did not finish on malformed escapes: $output"
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
  grep -qx '  \[i\] 1 finding(s) across ~/.claude/skills, ~/.agents/skills; opencode resolves these' <<< "$output" \
    || fail "doctor did not collapse the OpenCode compat overlap into one info line: $output"
  if grep -q 'docker' <<< "$(grep '\[i\]' <<< "$output")"; then fail "doctor listed info names without --verbose: $output"; fi

  make_legacy_commandcode "$tmp" git
  before="$(tree_hash "$tmp")"
  if output="$(HOME="$tmp" "$ROOT/install.sh" --doctor 2>&1)"; then
    fail "doctor passed with a planted duplicate"
  fi
  grep -qx "  \\[!\\] git: $tmp/.commandcode/skills/git, $tmp/.agents/skills/git" <<< "$output" || fail "doctor did not name the duplicate paths: $output"
  [[ "$(grep -c '\[!\]' <<< "$output")" == 1 ]] || fail "doctor reported the matching dir and name twice: $output"
  grep -qx '1 blocking finding(s) across 1 tool(s).' <<< "$output" || fail "doctor summary did not count one finding: $output"
  [[ "$(tree_hash "$tmp")" == "$before" ]] || fail "doctor changed files"
  if HOME="$tmp" "$ROOT/install.sh" --doctor --link >/dev/null 2>&1; then
    fail "doctor accepted --link"
  fi
  rm -rf "$tmp"
  trap - RETURN
}

doctor_skill() {
  mkdir -p "$1/$2"
  printf '%s\n' '---' "name: $3" 'description: x' '---' > "$1/$2/SKILL.md"
}

test_doctor_merges_only_equivalent_findings() {
  local tmp cc ag output status=0 expected
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  cc="$tmp/.commandcode/skills"
  ag="$tmp/.agents/skills"
  doctor_skill "$cc" alpha alpha; doctor_skill "$ag" alpha alpha
  doctor_skill "$cc" beta bravo; doctor_skill "$ag" beta bravo
  doctor_skill "$cc" gamma gamma; doctor_skill "$ag" gamma g2; doctor_skill "$ag" g3 gamma
  doctor_skill "$cc" delta d1; doctor_skill "$ag" delta d2; doctor_skill "$cc" x delta; doctor_skill "$ag" y delta
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode 2>&1)" || status=$?
  (( status == 1 )) || fail "doctor exited $status on blocking findings, want 1: $output"
  expected="$(printf '%s\n' \
    "  [!] alpha: $cc/alpha, $ag/alpha" \
    "  [!] dir beta: $cc/beta, $ag/beta" \
    "  [!] dir delta: $cc/delta, $ag/delta" \
    "  [!] dir gamma: $cc/gamma, $ag/gamma" \
    "  [!] name bravo: $cc/beta, $ag/beta" \
    "  [!] name delta: $cc/x, $ag/y" \
    "  [!] name gamma: $cc/gamma, $ag/g3")"
  [[ "$(grep -F '[!]' <<< "$output")" == "$expected" ]] || fail "doctor merged or split findings wrongly: $output"
  grep -qx '7 blocking finding(s) across 1 tool(s).' <<< "$output" || fail "doctor miscounted merged findings: $output"
  rm -rf "$tmp"
  trap - RETURN
}

test_doctor_groups_and_verbose() {
  local tmp output mode status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  doctor_skill "$tmp/.agents/skills" three three
  doctor_skill "$tmp/.claude/skills" three three
  doctor_skill "$tmp/.codex/skills" three three
  doctor_skill "$tmp/.agents/skills" two two
  doctor_skill "$tmp/.claude/skills" two two
  doctor_skill "$tmp/.agents/skills" foo foo
  doctor_skill "$tmp/.claude/skills" foo bar
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool omp)" || fail "doctor blocked on omp-resolved overlaps: $output"
  grep -qx '  \[i\] 2 finding(s) across ~/.agents/skills, ~/.claude/skills; omp resolves these' <<< "$output" \
    || fail "doctor did not bucket the two-root omp overlaps: $output"
  grep -qx '  \[i\] 1 finding(s) across ~/.agents/skills, ~/.claude/skills, ~/.codex/skills; omp resolves these' <<< "$output" \
    || fail "doctor did not bucket the three-root omp overlap: $output"
  if grep -qE '^      ' <<< "$output"; then fail "doctor listed names without --verbose: $output"; fi
  output="$(HOME="$tmp" "$ROOT/install.sh" --verbose --doctor --tool omp)" || fail "doctor --verbose blocked on omp overlaps: $output"
  grep -qx '      dir foo, two' <<< "$output" || fail "doctor --verbose did not list the two-root findings with labels: $output"
  grep -qx '      three' <<< "$output" || fail "doctor --verbose did not list the three-root finding: $output"

  mkdir -p "$tmp/.config/opencode/skills"
  doctor_skill "$tmp/.config/opencode/skills" three three
  for mode in "" --verbose; do
    status=0
    output="$(HOME="$tmp" "$ROOT/install.sh" --doctor ${mode:+"$mode"} --tool opencode 2>&1)" || status=$?
    (( status == 1 )) || fail "doctor $mode exited $status on a skill in all OpenCode roots, want 1: $output"
    grep -qx "  \\[!\\] three: $tmp/.config/opencode/skills/three, $tmp/.claude/skills/three, $tmp/.agents/skills/three" <<< "$output" \
      || fail "doctor $mode did not block the three-root OpenCode duplicate: $output"
    [[ "$(grep -c '\[!\]' <<< "$output")" == 1 ]] || fail "doctor $mode split the OpenCode duplicate: $output"
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_doctor_orders_blocking_first_across_tools() {
  local tmp output status=0 bang info
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  doctor_skill "$tmp/.agents/skills" shared shared
  doctor_skill "$tmp/.claude/skills" shared shared
  doctor_skill "$tmp/.agents/skills" clash clash
  doctor_skill "$tmp/.config/opencode/skills" clash clash
  doctor_skill "$tmp/.commandcode/skills" clash clash
  output="$(HOME="$tmp" "$ROOT/install.sh" --doctor --tool commandcode,opencode 2>&1)" || status=$?
  (( status == 1 )) || fail "doctor exited $status with blocking findings in two tools: $output"
  grep -qx '2 blocking finding(s) across 2 tool(s).' <<< "$output" || fail "doctor miscounted blocking findings across tools: $output"
  bang="$(grep -n '\[!\] clash:' <<< "$output" | tail -1 | cut -d: -f1)"
  info="$(grep -n '\[i\] .*opencode resolves these' <<< "$output" | head -1 | cut -d: -f1)"
  if [[ -z "$bang" || -z "$info" ]] || (( bang > info )); then
    fail "doctor did not list blocking findings before info in opencode: $output"
  fi
  rm -rf "$tmp"
  trap - RETURN
}

test_doctor_flag_rules_and_alias() {
  local tmp output mode
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if HOME="$tmp" "$ROOT/install.sh" --verbose --list >/dev/null 2>&1; then fail "--verbose accepted without --doctor"; fi
  if output="$(HOME="$tmp" "$ROOT/install.sh" --list --verbose 2>&1)"; then fail "--verbose accepted after --list without --doctor"; fi
  grep -q -- '--verbose requires --doctor' <<< "$output" || fail "--verbose rejection did not explain itself: $output"
  if HOME="$tmp" "$ROOT/install.sh" --doctor --include-internal >/dev/null 2>&1; then fail "doctor accepted --include-internal"; fi
  if HOME="$tmp" "$ROOT/install.sh" --include-internal --doctor >/dev/null 2>&1; then fail "doctor accepted a leading --include-internal"; fi

  doctor_skill "$tmp/.agents/skills" docker docker
  mkdir -p "$tmp/.commandcode"
  ln -s "$tmp/.agents/skills" "$tmp/.commandcode/skills"
  for mode in "" --verbose; do
    output="$(HOME="$tmp" "$ROOT/install.sh" --doctor ${mode:+"$mode"} --tool commandcode)" || fail "doctor $mode blocked on a root alias: $output"
    grep -q "$tmp/.agents/skills  (same directory as $tmp/.commandcode/skills)" <<< "$output" || fail "doctor $mode did not report the root alias: $output"
    if grep -q '\[[!i]\]' <<< "$output"; then fail "doctor $mode reported the aliased root as a duplicate: $output"; fi
  done
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
  write_fixture_skill "$repo" team $'---\nname: team\ndescription: tracked but internal\nmetadata:\n  internal: "true"\n---'
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
  HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/default" --check > "$tmp/check" \
    || fail "--check after a default install reported missing skills: $(cat "$tmp/check")"
  if grep -q 'team' "$tmp/check"; then fail "--check expected the opt-in skill after a default install"; fi
  if HOME="$tmp" "$repo/install.sh" --tool portable --dest "$tmp/default" --check --include-internal >/dev/null; then
    fail "--check --include-internal did not report the missing opt-in skill"
  fi

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
  grep -q 'cannot continue with invalid skill frontmatter' <<< "$output" || fail "installer did not stop on malformed frontmatter"
  [[ ! -e "$tmp/dest" ]] || fail "install wrote files despite malformed frontmatter"
  rm -rf "$tmp"
  trap - RETURN
}

# Replacement transaction tests run with an allowlisted environment.
SAFE_PATH="$(for cmd in python3 git sha256sum; do dirname "$(command -v "$cmd")"; done | awk '!seen[$0]++' | paste -sd:):/usr/bin:/bin"

isolated() {
  local home="$1"
  shift
  env -i HOME="$home" PATH="$SAFE_PATH" LANG=C "$@"
}

digest() {
  LC_ALL=C find "$1" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1
}

txn_area() {
  printf '%s/.skills-txn/%s\n' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")"
}

lock_entry() {
  python3 - "$1/.skills-lock.json" "$2" <<'PY'
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))["skills"].get(sys.argv[2])
print(record["hash"] if isinstance(record, dict) else record or "")
PY
}

record_phase() {
  sed -n 's/^phase=//p' "$1/record"
}

# Install docker, then change it so a replacement is observable.
seed_modified_docker() {
  local home="$1" dest="$2"
  isolated "$home" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  printf '%s\n' 'local edit' >> "$dest/docker/SKILL.md"
}

# A failure before promotion leaves the old copy, the lock, and no transaction behind.
assert_untouched_after_fault() {
  local label="$1" dest="$2" before="$3" lock_before="$4"
  [[ "$(tree_hash "$dest/docker")" == "$before" ]] || fail "$label: working copy changed"
  [[ "$(sha256sum < "$dest/.skills-lock.json")" == "$lock_before" ]] || fail "$label: lock changed"
  [[ ! -e "$(txn_area "$dest")" ]] || fail "$label: transaction area left behind: $(find "$(txn_area "$dest")")"
  if find "$dest" -maxdepth 1 -name '.skills-lock.json.*' | grep -q .; then fail "$label: lock temp left behind"; fi
}

assert_rerun_repairs() {
  local label="$1" home="$2" dest="$3"
  isolated "$home" "$ROOT/install.sh" --tool portable --dest "$dest" --force docker >/dev/null || fail "$label: clean rerun failed"
  [[ "$(digest "$dest/docker")" == "$(digest "$ROOT/skills/docker")" ]] || fail "$label: rerun did not install the source copy"
  [[ "$(lock_entry "$dest" docker)" == "$(digest "$ROOT/skills/docker")" ]] || fail "$label: rerun did not publish the lock"
  [[ ! -e "$(txn_area "$dest")" ]] || fail "$label: rerun left the transaction area"
}

test_fault_before_promotion_keeps_previous_install() {
  local tmp dest point before lock_before output status
  tmp="$(mktemp -d)"
  trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' RETURN
  for point in stage backup promote; do
    dest="$tmp/$point/skills"
    seed_modified_docker "$tmp" "$dest"
    before="$(tree_hash "$dest/docker")"
    lock_before="$(sha256sum < "$dest/.skills-lock.json")"
    status=0
    output="$(isolated "$tmp" SKILLS_INSTALL_FAULT="$point" "$ROOT/install.sh" --tool portable --dest "$dest" --force docker 2>&1)" || status=$?
    (( status == 1 )) || fail "$point fault exited $status, want 1: $output"
    grep -q "injected fault: $point" <<< "$output" || fail "$point fault was not injected: $output"
    grep -q 'Done with 1 error(s).' <<< "$output" || fail "$point fault did not report the error: $output"
    assert_untouched_after_fault "$point fault" "$dest" "$before" "$lock_before"
    assert_rerun_repairs "$point fault" "$tmp" "$dest"
  done
  [[ "$(grep -c 'previous copy restored' <<< "$output")" == 1 ]] || fail "promote fault did not restore: $output"

  dest="$tmp/backup-dir/skills"
  seed_modified_docker "$tmp" "$dest"
  before="$(tree_hash "$dest/docker")"
  lock_before="$(sha256sum < "$dest/.skills-lock.json")"
  mkdir "$tmp/readonly"
  chmod 555 "$tmp/readonly"
  if output="$(isolated "$tmp" SKILLS_BACKUP_DIR="$tmp/readonly/backups" "$ROOT/install.sh" --tool portable --dest "$dest" --force docker 2>&1)"; then
    fail "install succeeded although the backup could not be written"
  fi
  grep -q 'docker: backup failed' <<< "$output" || fail "backup failure was not reported: $output"
  assert_untouched_after_fault "unwritable backup" "$dest" "$before" "$lock_before"
  chmod -R u+w "$tmp"
  rm -rf "$tmp"
  trap - RETURN
}

test_restore_fault_keeps_evidence_and_stops_destination() {
  local tmp a b txn old_digest status output before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  a="$tmp/a/skills"
  b="$tmp/b/skills"
  seed_modified_docker "$tmp" "$a"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$a" --no-backup git >/dev/null
  old_digest="$(digest "$a/docker")"
  local git_before lock_before
  git_before="$(tree_hash "$a/git")"
  lock_before="$(sha256sum < "$a/.skills-lock.json")"

  status=0
  output="$(isolated "$tmp" CLAUDE_SKILLS_DIR="$a" CODEX_SKILLS_DIR="$b" SKILLS_INSTALL_FAULT=promote:docker,restore \
    "$ROOT/install.sh" --tool claude,codex --force --no-backup docker git 2>&1)" || status=$?
  (( status == 1 )) || fail "restore fault exited $status, want 1: $output"
  txn="$(txn_area "$a")/docker"
  [[ ! -e "$a/docker" ]] || fail "restore fault: working path should be missing until recovery"
  [[ "$(digest "$txn/prev")" == "$old_digest" ]] || fail "restore fault did not keep the previous copy"
  [[ "$(digest "$txn/staging")" == "$(digest "$ROOT/skills/docker")" ]] || fail "restore fault did not keep staging"
  [[ "$(record_phase "$txn")" == rollingback ]] || fail "restore fault record phase: $(record_phase "$txn")"
  grep -qx "target=$a/docker" "$txn/record" || fail "record does not name the working path"
  [[ "$(tree_hash "$a/git")" == "$git_before" ]] || fail "stopped destination still changed git"
  grep -q "git not attempted: $a needs recovery first" <<< "$output" || fail "stopped destination did not report skipped skills: $output"
  [[ "$(sha256sum < "$a/.skills-lock.json")" == "$lock_before" ]] || fail "stopped destination changed its lock"
  [[ ! -e "$b/docker" && ! -e "$(txn_area "$b")" ]] || fail "other destination kept a failed docker install"
  [[ "$(lock_entry "$b" git)" == "$(digest "$ROOT/skills/git")" ]] || fail "other destination did not proceed with git"

  # Failing recovery repeats without changing the evidence.
  before="$(tree_hash "$tmp/a")"
  if output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=restore "$ROOT/install.sh" --tool portable --dest "$a" docker git 2>&1)"; then
    fail "install succeeded although recovery failed: $output"
  fi
  grep -q 'docker: could not restore' <<< "$output" || fail "recovery failure was not reported: $output"
  [[ "$(tree_hash "$tmp/a")" == "$before" ]] || fail "failed recovery changed the destination"

  # A clean run restores the old copy and keeps the record: the lock was never published for it.
  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$a" docker git 2>&1)" || fail "recovery run failed: $output"
  grep -q 'docker: restored the previous copy, finished an interrupted rollback, removed leftover staging' <<< "$output" \
    || fail "recovery was not reported: $output"
  [[ "$(digest "$a/docker")" == "$old_digest" ]] || fail "recovery did not restore the previous copy"
  [[ ! -e "$txn/prev" && ! -e "$txn/staging" && "$(record_phase "$txn")" == recovered ]] || fail "recovery left the wrong evidence"
  before="$(tree_hash "$tmp/a")"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$a" docker git >/dev/null || fail "repeat recovery run failed"
  [[ "$(tree_hash "$tmp/a")" == "$before" ]] || fail "repeat recovery run changed files"

  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$a" --force --no-backup docker >/dev/null || fail "forced reinstall failed"
  [[ "$(lock_entry "$a" docker)" == "$(digest "$ROOT/skills/docker")" && ! -e "$(txn_area "$a")" ]] || fail "forced reinstall did not reconcile the record"
  rm -rf "$tmp"
  trap - RETURN
}

test_lock_fault_leaves_records_until_publication() {
  local tmp dest txn lock_before status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker git >/dev/null
  printf '%s\n' 'local edit' >> "$dest/docker/SKILL.md"
  printf '%s\n' 'local edit' >> "$dest/git/SKILL.md"
  # Stale records, so the forced install has a lock change to publish.
  python3 - "$dest/.skills-lock.json" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
for name in ("docker", "git"):
    lock["skills"][name] = {"hash": "0" * 64, "provenance": "source-equal-v1"}
json.dump(lock, open(sys.argv[1], "w", encoding="utf-8"))
PY
  lock_before="$(sha256sum < "$dest/.skills-lock.json")"
  status=0
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=lock "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker git 2>&1)" || status=$?
  (( status == 1 )) || fail "lock fault exited $status, want 1: $output"
  [[ "$(sha256sum < "$dest/.skills-lock.json")" == "$lock_before" ]] || fail "lock fault changed the lock"
  if find "$dest" -maxdepth 1 -name '.skills-lock.json.*' | grep -q .; then fail "lock fault left a temp file"; fi
  txn="$(txn_area "$dest")"
  for skill in docker git; do
    [[ "$(digest "$dest/$skill")" == "$(digest "$ROOT/skills/$skill")" ]] || fail "lock fault: $skill was not promoted"
    [[ "$(record_phase "$txn/$skill")" == promoted ]] || fail "lock fault: $skill record missing or wrong phase"
    [[ ! -e "$txn/$skill/prev" && ! -e "$txn/$skill/staging" ]] || fail "lock fault: $skill left transaction copies"
  done

  # Startup recovery keeps each record until that skill's lock entry is published.
  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)" || fail "rerun after lock fault failed: $output"
  grep -q 'git: install record kept until its lock entry is published' <<< "$output" || fail "pending record was not reported: $output"
  [[ ! -e "$txn/docker" && "$(record_phase "$txn/git")" == promoted ]] || fail "rerun reconciled the wrong records"
  [[ "$(lock_entry "$dest" docker)" == "$(digest "$ROOT/skills/docker")" ]] || fail "rerun did not publish docker"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" git >/dev/null || fail "git rerun failed"
  [[ ! -e "$txn" && "$(lock_entry "$dest" git)" == "$(digest "$ROOT/skills/git")" ]] || fail "git record was not reconciled"
  rm -rf "$tmp"
  trap - RETURN
}

test_opencode_fault_keeps_config_unchanged() {
  local tmp config target before status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  config="$tmp/.config/opencode/opencode.json"
  target="$tmp/dotfiles/opencode.json"
  mkdir -p "$(dirname "$config")" "$(dirname "$target")"
  printf '%s\n' '{"permission":{"skill":{"*":"deny"}}}' > "$target"
  ln -s "$target" "$config"
  before="$(sha256sum < "$target")"
  status=0
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=opencode "$ROOT/install.sh" --tool opencode --no-backup docker 2>&1)" || status=$?
  (( status == 1 )) || fail "opencode fault exited $status, want 1: $output"
  grep -q 'OpenCode permission sync failed' <<< "$output" || fail "opencode fault was not reported: $output"
  [[ "$(sha256sum < "$target")" == "$before" && -L "$config" ]] || fail "opencode fault changed the config"
  if find "$tmp/dotfiles" "$(dirname "$config")" -name '.opencode.*' | grep -q .; then fail "opencode fault left a temp file"; fi
  [[ "$(lock_entry "$tmp/.agents/skills" docker)" == "$(digest "$ROOT/skills/docker")" ]] || fail "opencode fault blocked the lock"

  isolated "$tmp" "$ROOT/install.sh" --tool opencode --no-backup docker >/dev/null || fail "opencode rerun failed"
  [[ -L "$config" ]] || fail "opencode sync replaced the config symlink"
  python3 - "$target" <<'PY'
import json
import sys

assert json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"] == {"*": "deny", "docker": "allow"}
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_link_fault_restores_previous_link() {
  local tmp claude status output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  claude="$tmp/.claude/skills"
  isolated "$tmp" "$ROOT/install.sh" --tool claude --link --no-backup docker >/dev/null
  ln -sfn "$tmp/elsewhere" "$claude/docker"
  status=0
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=promote "$ROOT/install.sh" --tool claude --link --force --no-backup docker 2>&1)" || status=$?
  (( status == 1 )) || fail "link promote fault exited $status, want 1: $output"
  [[ "$(readlink "$claude/docker")" == "$tmp/elsewhere" ]] || fail "link promote fault did not restore the previous link"
  [[ ! -e "$(txn_area "$claude")" ]] || fail "link promote fault left the transaction area"
  isolated "$tmp" "$ROOT/install.sh" --tool claude --link --force --no-backup docker >/dev/null || fail "link rerun failed"
  [[ "$(readlink "$claude/docker")" == "$tmp/.agents/skills/docker" ]] || fail "link rerun did not relink"
  rm -rf "$tmp"
  trap - RETURN
}

assert_lock_matches_installs() {
  local dest="$1" dir
  for dir in "$dest"/*/; do
    dir="${dir%/}"
    [[ "$(lock_entry "$dest" "${dir##*/}")" == "$(digest "$dir")" && "$(digest "$dir")" == "$(digest "$ROOT/skills/${dir##*/}")" ]] \
      || fail "${dir##*/} does not match its lock entry and source"
  done
}

test_concurrent_installs_serialize() {
  local tmp dest s1=0 s2=0 p1 p2
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup >/dev/null
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup > "$tmp/one" 2>&1 &
  p1=$!
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup > "$tmp/two" 2>&1 &
  p2=$!
  wait "$p1" || s1=$?
  wait "$p2" || s2=$?
  (( s1 == 0 && s2 == 0 )) || fail "concurrent installs exited $s1 and $s2: $(cat "$tmp/one" "$tmp/two")"
  if grep -q '\[[!r]\]' "$tmp/one" "$tmp/two"; then fail "concurrent installs interfered: $(cat "$tmp/one" "$tmp/two")"; fi
  [[ ! -e "$(txn_area "$dest")" ]] || fail "concurrent installs left the transaction area"
  assert_lock_matches_installs "$dest"
  rm -rf "$tmp"
  trap - RETURN
}

test_relative_xdg_state_home_is_ignored() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir "$tmp/cwd"
  (cd "$tmp/cwd" && isolated "$tmp" XDG_STATE_HOME=rel "$ROOT/install.sh" --tool portable --dest "$tmp/d" --no-backup docker >/dev/null)
  [[ -f "$tmp/.local/state/iuliandita-skills/install.lock" && ! -e "$tmp/cwd/rel" ]] \
    || fail "relative XDG_STATE_HOME was not ignored"
  rm -rf "$tmp"
  trap - RETURN
}

test_installer_lock_contention_and_missing_flock() {
  local tmp lock_dir holder status=0 output dir file
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  lock_dir="$tmp/.local/state/iuliandita-skills"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$tmp/first" --no-backup docker >/dev/null
  [[ "$(python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$lock_dir")" == 0o700 ]] \
    || fail "lock directory is not private"
  ( exec 8>>"$lock_dir/install.lock"; flock 8; touch "$tmp/held"; exec sleep 30 ) &
  holder=$!
  for _ in $(seq 100); do [[ -e "$tmp/held" ]] && break; sleep 0.1; done
  output="$(isolated "$tmp" SKILLS_LOCK_WAIT=1 "$ROOT/install.sh" --tool portable --dest "$tmp/second" docker 2>&1)" || status=$?
  kill "$holder"
  wait "$holder" 2>/dev/null || true
  (( status == 3 )) || fail "lock contention exited $status, want 3: $output"
  grep -q 'Another install.sh run holds' <<< "$output" || fail "lock contention was not explained: $output"
  [[ ! -e "$tmp/second" ]] || fail "installer changed files without the lock"

  mkdir "$tmp/no-flock"
  for dir in ${SAFE_PATH//:/ }; do
    for file in "$dir"/*; do
      [[ "${file##*/}" == flock || -e "$tmp/no-flock/${file##*/}" || -L "$tmp/no-flock/${file##*/}" ]] || ln -s "$file" "$tmp/no-flock/${file##*/}"
    done
  done
  output="$(env -i HOME="$tmp" PATH="$tmp/no-flock" LANG=C "$ROOT/install.sh" --tool portable --dest "$tmp/third" docker 2>&1)" \
    || fail "install without flock failed: $output"
  [[ "$(grep -c 'flock not found' <<< "$output")" == 1 ]] || fail "missing flock warning not printed once: $output"
  [[ -d "$tmp/third/docker" ]] || fail "install without flock did not proceed"
  rm -rf "$tmp"
  trap - RETURN
}

test_migration_recovers_before_apply() {
  local tmp dest txn custom output src
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="$tmp/src"
  make_legacy_source "$src"
  dest="$tmp/agent/skills"
  isolated "$tmp" "$src/install.sh" --tool portable --dest "$dest" --no-backup code-simplification anti-slop >/dev/null
  printf '%s\n' 'local edit' >> "$dest/code-simplification/SKILL.md"
  custom="$(digest "$dest/code-simplification")"
  if isolated "$tmp" SKILLS_INSTALL_FAULT=promote:code-simplification,restore "$src/install.sh" \
    --tool portable --dest "$dest" --force --no-backup code-simplification >/dev/null 2>&1; then
    fail "promote and restore faults did not fail the install"
  fi
  txn="$(txn_area "$dest")/code-simplification"
  [[ ! -e "$dest/code-simplification" && "$(digest "$txn/prev")" == "$custom" ]] || fail "fixture did not leave the copy in prev"

  if output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=restore "$src/install.sh" --tool portable --dest "$dest" --migrate --apply 2>&1)"; then
    fail "migration ran although recovery failed: $output"
  fi
  grep -q "refusing to migrate $dest until its install records are recovered" <<< "$output" || fail "migration refusal was unclear: $output"
  [[ ! -e "$dest/code-simplification" && "$(digest "$txn/prev")" == "$custom" && -d "$dest/anti-slop" ]] \
    || fail "refused migration changed the destination"

  if output="$(isolated "$tmp" "$src/install.sh" --tool portable --dest "$dest" --migrate --apply 2>&1)"; then
    fail "migration ran with an unpublished record for a replacement: $output"
  fi
  grep -q 'code-simplification has an unpublished install record' <<< "$output" || fail "record refusal was unclear: $output"
  [[ "$(digest "$dest/code-simplification")" == "$custom" && -d "$dest/anti-slop" ]] || fail "migration refusal lost the customized copy"

  isolated "$tmp" "$src/install.sh" --tool portable --dest "$dest" --force --no-backup code-simplification >/dev/null \
    || fail "forced reinstall failed"
  isolated "$tmp" "$src/install.sh" --tool portable --dest "$dest" --migrate --apply >/dev/null || fail "migration failed after reconciliation"
  [[ ! -e "$dest/anti-slop" && "$(digest "$dest/code-simplification")" == "$(digest "$src/skills/code-simplification")" ]] \
    || fail "migration did not complete after reconciliation"
  rm -rf "$tmp"
  trap - RETURN
}

stale_lock_entry() {
  python3 - "$1/.skills-lock.json" "$2" <<'PY'
import json
import sys

lock = json.load(open(sys.argv[1], encoding="utf-8"))
lock["skills"][sys.argv[2]] = {"hash": "0" * 64, "provenance": "source-equal-v1"}
json.dump(lock, open(sys.argv[1], "w", encoding="utf-8"))
PY
}

test_failed_retry_keeps_earlier_record() {
  local tmp dest txn record before output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup docker >/dev/null
  stale_lock_entry "$dest" docker
  if isolated "$tmp" SKILLS_INSTALL_FAULT=lock "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker >/dev/null 2>&1; then
    fail "lock fault did not fail"
  fi
  txn="$(txn_area "$dest")/docker"
  record="$(<"$txn/record")"
  before="$(tree_hash "$dest/docker")"
  if isolated "$tmp" SKILLS_INSTALL_FAULT=stage "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker >/dev/null 2>&1; then
    fail "stage fault did not fail"
  fi
  [[ "$(<"$txn/record")" == "$record" ]] || fail "failed retry replaced the earlier record"
  [[ "$(find "$txn" -mindepth 1 -printf '%f\n')" == record ]] || fail "failed retry left files: $(find "$txn")"
  [[ "$(tree_hash "$dest/docker")" == "$before" ]] || fail "failed retry changed the working copy"

  # An interruption right after setting the record aside is put back by recovery.
  mv "$txn/record" "$txn/record.prior"
  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)" || fail "recovery run failed: $output"
  grep -q 'docker: put back the earlier record' <<< "$output" || fail "earlier record was not put back: $output"
  [[ ! -e "$(txn_area "$dest")" && "$(lock_entry "$dest" docker)" == "$(digest "$ROOT/skills/docker")" ]] \
    || fail "earlier record was not reconciled"
  rm -rf "$tmp"
  trap - RETURN
}

test_cross_device_destination_is_refused() {
  local tmp dest before lock_before status=0 output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"
  seed_modified_docker "$tmp" "$dest"
  before="$(tree_hash "$dest/docker")"
  lock_before="$(sha256sum < "$dest/.skills-lock.json")"
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=xdev "$ROOT/install.sh" --tool portable --dest "$dest" --force docker 2>&1)" || status=$?
  (( status == 1 )) || fail "cross-device destination exited $status, want 1: $output"
  grep -q 'is on a different filesystem than' <<< "$output" || fail "cross-device refusal was unclear: $output"
  grep -q 'docker not attempted' <<< "$output" || fail "cross-device destination was not skipped: $output"
  assert_untouched_after_fault "cross-device" "$dest" "$before" "$lock_before"
  rm -rf "$tmp"
  trap - RETURN
}

test_post_promotion_failures_stop_and_reconcile() {
  local tmp dest txn old status output git_before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"

  # record: the phase write after promotion fails.
  seed_modified_docker "$tmp" "$dest"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" --no-backup git >/dev/null
  printf '%s\n' 'local edit' >> "$dest/git/SKILL.md"
  git_before="$(tree_hash "$dest/git")"
  old="$(digest "$dest/docker")"
  status=0
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=record:docker "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker git 2>&1)" || status=$?
  (( status == 1 )) || fail "record fault exited $status, want 1: $output"
  txn="$(txn_area "$dest")/docker"
  [[ "$(digest "$dest/docker")" == "$(digest "$ROOT/skills/docker")" && "$(digest "$txn/prev")" == "$old" ]] || fail "record fault lost evidence"
  [[ "$(record_phase "$txn")" == swapping && "$(sed -n 's/^staged=//p' "$txn/record")" == "$(digest "$ROOT/skills/docker")" ]] \
    || fail "record fault: record lacks the staged digest"
  grep -q 'git not attempted' <<< "$output" || fail "record fault did not stop the destination: $output"
  [[ "$(tree_hash "$dest/git")" == "$git_before" ]] || fail "record fault still changed git"
  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)" || fail "rerun after record fault failed: $output"
  grep -q 'docker: removed the replaced copy, confirmed the new copy' <<< "$output" || fail "record fault was not reconciled: $output"
  [[ ! -e "$txn" && "$(lock_entry "$dest" docker)" == "$(digest "$ROOT/skills/docker")" ]] || fail "record fault rerun left state behind"

  # record, then the working copy is edited: that edit is the user's. Recovery
  # keeps it and the evidence, refuses only that skill, and exits non-zero.
  printf '%s\n' 'local edit' >> "$dest/docker/SKILL.md"
  if isolated "$tmp" SKILLS_INSTALL_FAULT=record "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker >/dev/null 2>&1; then
    fail "record fault did not fail"
  fi
  printf '%s\n' 'my edit after the fault' >> "$dest/docker/SKILL.md"
  local edited evidence
  edited="$(tree_hash "$dest/docker")"
  evidence="$(tree_hash "$txn")"
  [[ -e "$txn/prev" && -f "$txn/record" ]] || fail "record fault left no evidence to keep"
  for _ in 1 2; do
    status=0
    output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker git 2>&1)" || status=$?
    (( status == 1 )) || fail "rerun after an edit exited $status, want 1: $output"
    grep -q 'docker: .* matches neither the new nor the previous copy; kept it as a local modification' <<< "$output" \
      || fail "edited copy not reported: $output"
    grep -q 'docker not installed: its copy was modified' <<< "$output" || fail "edited skill not refused: $output"
    ! grep -q 'git not attempted' <<< "$output" || fail "an edited skill stopped the whole destination: $output"
    [[ "$(tree_hash "$dest/docker")" == "$edited" ]] || fail "recovery changed the edited copy"
    [[ "$(tree_hash "$txn")" == "$evidence" ]] || fail "recovery changed the evidence"
  done
  # Keep the edit, as the message suggests.
  rm -rf "$txn"
  old="$(digest "$dest/docker")"

  # cleanup: removing the previous copy after promotion fails.
  status=0
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=cleanup "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker 2>&1)" || status=$?
  (( status == 1 )) || fail "cleanup fault exited $status, want 1: $output"
  [[ "$(digest "$txn/prev")" == "$old" && "$(record_phase "$txn")" == promoted ]] || fail "cleanup fault lost evidence"
  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)" || fail "rerun after cleanup fault failed: $output"
  grep -q 'docker: removed the replaced copy' <<< "$output" || fail "cleanup fault was not reconciled: $output"
  [[ ! -e "$(txn_area "$dest")" && "$(lock_entry "$dest" docker)" == "$(digest "$ROOT/skills/docker")" ]] || fail "cleanup rerun left state behind"
  rm -rf "$tmp"
  trap - RETURN
}

test_interrupted_rollback_keeps_previous_copy() {
  local tmp dest txn custom status=0 output before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  dest="$tmp/agent/skills"
  seed_modified_docker "$tmp" "$dest"
  custom="$(digest "$dest/docker")"
  output="$(isolated "$tmp" SKILLS_INSTALL_FAULT=promote:docker,rollback "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker 2>&1)" || status=$?
  (( status == 1 )) || fail "interrupted rollback exited $status, want 1: $output"
  txn="$(txn_area "$dest")/docker"
  [[ "$(digest "$dest/docker")" == "$custom" && "$(record_phase "$txn")" == rollingback ]] || fail "interrupted rollback state is wrong"
  [[ ! -e "$txn/prev" && ! -e "$txn/staging" ]] || fail "interrupted rollback left copies behind"

  output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)" || fail "rerun after interrupted rollback failed: $output"
  grep -q 'docker: finished an interrupted rollback' <<< "$output" || fail "interrupted rollback was not finished: $output"
  [[ "$(digest "$dest/docker")" == "$custom" && "$(record_phase "$txn")" == recovered ]] || fail "rerun lost the previous copy"
  before="$(tree_hash "$tmp/agent")"
  isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker >/dev/null || fail "repeat recovery failed"
  [[ "$(tree_hash "$tmp/agent")" == "$before" ]] || fail "repeat recovery changed files"
  rm -rf "$tmp"
  trap - RETURN
}

test_unverified_copy_without_verified_prev_is_refused() {
  local tmp dest txn case before output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  for case in missing tampered; do
    dest="$tmp/$case/skills"
    seed_modified_docker "$tmp" "$dest"
    if isolated "$tmp" SKILLS_INSTALL_FAULT=record "$ROOT/install.sh" --tool portable --dest "$dest" --force --no-backup docker >/dev/null 2>&1; then
      fail "$case: record fault did not fail"
    fi
    txn="$(txn_area "$dest")/docker"
    if [[ "$case" == missing ]]; then
      rm -rf "$txn/prev"
    else
      printf '%s\n' 'changed' >> "$txn/prev/SKILL.md"
    fi
    printf '%s\n' 'partial' >> "$dest/docker/SKILL.md"
    before="$(tree_hash "$tmp/$case")"
    for _ in 1 2; do
      if output="$(isolated "$tmp" "$ROOT/install.sh" --tool portable --dest "$dest" docker 2>&1)"; then
        fail "$case: recovery accepted an unverified working copy: $output"
      fi
      grep -q 'kept it as a local modification' <<< "$output" || fail "$case: refusal was unclear: $output"
      [[ "$(tree_hash "$tmp/$case")" == "$before" ]] || fail "$case: refused recovery changed files"
    done
  done
  rm -rf "$tmp"
  trap - RETURN
}

# Synthetic, clean upstream checkout: --update exercises its real fetch and
# handoff path without reading or installing the collection's skill content.
make_convergence_fixture() {
  local tmp="$1" name
  mkdir -p "$tmp/home" "$tmp/publisher/scripts"
  cp "$ROOT/install.sh" "$tmp/publisher/"
  cp "$ROOT/scripts/skill-lib.sh" "$ROOT/scripts/skill-frontmatter.py" "$ROOT/scripts/migrate-skills.py" "$tmp/publisher/scripts/"
  for name in keep prune edited renamed linked unverified hash-only internal old new removed user-old deny-old; do
    write_fixture_skill "$tmp/publisher" "$name" "$(printf '%s\n' --- "name: $name" 'description: synthetic fixture' ---)"
  done
  printf 'notes\n' > "$tmp/publisher/skills/renamed/notes-a"
  ln -s SKILL.md "$tmp/publisher/skills/linked/alias"
  cat > "$tmp/publisher/migrations.json" <<'JSON'
{"version":1,"transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1},"skills":{"old":{"action":"rename","replacement":"new","transition":{"release":null,"published_at":null,"minimum_days":7,"placeholder_releases":1}},"removed":{"action":"remove","replacement":null},"user-old":{"action":"remove","replacement":null},"deny-old":{"action":"remove","replacement":null}}}
JSON
  isolated "$tmp/home" git init -q -b develop "$tmp/publisher"
  isolated "$tmp/home" git -C "$tmp/publisher" add -A
  isolated "$tmp/home" git -C "$tmp/publisher" -c user.name="test" -c user.email="test@example.com" -c commit.gpgsign=false commit -qm fixture
  isolated "$tmp/home" git init -q --bare -b develop "$tmp/origin.git"
  isolated "$tmp/home" git -C "$tmp/publisher" remote add origin "$tmp/origin.git"
  isolated "$tmp/home" git -C "$tmp/publisher" push -qu origin develop
  isolated "$tmp/home" git clone -q "$tmp/origin.git" "$tmp/repo"
}

publish_convergence_fixture() {
  local tmp="$1"
  isolated "$tmp/home" git -C "$tmp/publisher" add -A
  isolated "$tmp/home" git -C "$tmp/publisher" -c user.name="test" -c user.email="test@example.com" -c commit.gpgsign=false commit -qm transition
  isolated "$tmp/home" git -C "$tmp/publisher" push -q origin develop
}

test_update_prunes_only_verified_owned_trees() {
  local tmp root name rc=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" --tool claude,codex >/dev/null
  for root in "$tmp/home/.claude/skills" "$tmp/home/.agents/skills"; do
    printf 'local edit\n' >> "$root/edited/SKILL.md"
    mv "$root/renamed/notes-a" "$root/renamed/notes-b"
    ln -sfn missing "$root/linked/alias"
    mkdir "$root/unowned"
    cp "$root/keep/SKILL.md" "$root/unowned/SKILL.md"
    python3 - "$root/.skills-lock.json" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
lock = json.loads(path.read_text())
lock["trees"].pop("unverified")
lock["skills"]["hash-only"] = lock["skills"]["hash-only"]["hash"]
path.write_text(json.dumps(lock))
PY
  done
  isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool claude,codex --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --update --json > "$tmp/result.json" 2> "$tmp/err" || rc=$?
  (( rc == 6 )) || fail "modified prune candidates did not make update partial: $rc $(cat "$tmp/err")"
  for root in "$tmp/home/.claude/skills" "$tmp/home/.agents/skills"; do
    for name in prune internal old new removed user-old deny-old; do
      [[ ! -e "$root/$name" ]] || fail "$root/$name was not pruned"
      [[ -d "$(dirname "$root")/.skills-backups/skills/.pruned/$name" ]] || fail "missing prune backup for $root/$name"
      [[ -z "$(lock_entry "$root" "$name")" ]] || fail "pruned lock entry remains for $name"
    done
    for name in keep edited renamed linked unowned unverified hash-only; do [[ -e "$root/$name" ]] || fail "lost $root/$name"; done
  done
  grep -q 'warning: kept unselected' "$tmp/err" || fail 'prune warning missing'
  python3 - "$tmp/result.json" <<'PY'
import json
import sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert len(result["prune_kept"]) == 8, result
assert {row["name"] for row in result["prune_kept"]} == {"edited", "renamed", "linked", "unverified"}
assert len(result["pruned"]) == 14
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool claude,codex --json > "$tmp/doctor.json" 2> "$tmp/doctor.err"
  python3 - "$tmp/doctor.json" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
outside = report["outside_selection"]
assert not any(row["prunable"] for row in outside), outside
assert len([row for row in outside if row["ownership"] == "other"]) == 4
assert {row["name"] for row in outside} == {"edited", "renamed", "linked", "unowned", "unverified", "hash-only"}
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_update_migrates_saved_names_and_filters_retired_skills() {
  local tmp before after
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" old --tool claude,codex --save >/dev/null
  write_fixture_skill "$tmp/publisher" old $'---\nname: old\ndescription: deprecated fixture\nmetadata:\n  deprecated: true\n---'
  publish_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  grep -qx 'skills=new' "$tmp/home/.config/iuliandita-skills/install.conf" || fail 'saved old name was not rewritten'
  [[ ! -e "$tmp/home/.claude/skills/old" && ! -e "$tmp/home/.agents/skills/old" ]] || fail 'old name survived update'
  [[ -f "$tmp/home/.claude/skills/new/SKILL.md" && -f "$tmp/home/.agents/skills/new/SKILL.md" ]] || fail 'replacement missing'
  before="$(tree_hash "$tmp/home")"
  isolated "$tmp/home" "$tmp/repo/install.sh" --update --json > "$tmp/result" 2> "$tmp/err"
  after="$(tree_hash "$tmp/home")"
  [[ "$before" == "$after" ]] || fail 'second migrated update changed the saved setup'
  python3 - "$tmp/result" <<'PY'
import json
import sys
result = json.load(open(sys.argv[1], encoding="utf-8"))
assert result["status"] == "current" and result["changed"] == 0, result
PY
  # A remove-only selection must stay empty on a second update and bare run.
  isolated "$tmp/home" "$tmp/repo/install.sh" removed --tool codex --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  grep -qx 'skills=' "$tmp/home/.config/iuliandita-skills/install.conf" || fail 'remove migration did not save an empty selection'
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" >/dev/null
  [[ -z "$(installed_dirs "$tmp/home/.agents/skills")" ]] || fail 'empty selection expanded to all skills'
  rm -rf "$tmp"
  trap - RETURN
}

test_update_prunes_internal_and_deprecated_from_all_selection() {
  local tmp root
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" --tool claude,codex --save >/dev/null
  write_fixture_skill "$tmp/publisher" internal $'---\nname: internal\ndescription: internal fixture\nmetadata:\n  internal: true\n---'
  write_fixture_skill "$tmp/publisher" prune $'---\nname: prune\ndescription: deprecated fixture\nmetadata:\n  deprecated: true\n---'
  rm -rf "$tmp/publisher/skills/removed"
  publish_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  for root in "$tmp/home/.claude/skills" "$tmp/home/.agents/skills"; do
    [[ ! -e "$root/internal" && ! -e "$root/prune" && ! -e "$root/removed" && ! -e "$root/old" ]] || fail 'all selection kept inactive skills'
  done
  isolated "$tmp/home" "$tmp/repo/install.sh" internal --tool codex --include-internal --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  [[ -d "$tmp/home/.agents/skills/internal" ]] || fail 'saved include-internal was ignored'
  rm -rf "$tmp"
  trap - RETURN
}

test_update_link_pruning_and_permission_provenance() {
  local tmp config root
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  config="$tmp/home/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$config")"
  printf '%s\n' '{"permission":{"skill":{"*":"deny","user-old":"allow","deny-old":"deny","custom":"allow"}}}' > "$config"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep prune old --tool claude,codex,opencode --link --save >/dev/null
  python3 - "$tmp/home/.agents/skills/.skills-lock.json" <<'PY'
import json
import sys
lock = json.load(open(sys.argv[1], encoding="utf-8"))
assert set(next(iter(lock["opencode_permissions"].values()))) == {"keep", "prune", "old"}, lock
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool claude,codex,opencode --link --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  [[ ! -L "$tmp/home/.claude/skills/prune" && ! -e "$tmp/home/.agents/skills/prune" ]] || fail 'link setup did not converge'
  python3 - "$config" "$tmp/home/.agents/skills/.skills-lock.json" <<'PY'
import json
import sys
permission = json.load(open(sys.argv[1], encoding="utf-8"))["permission"]["skill"]
assert permission == {"*": "deny", "user-old": "allow", "deny-old": "deny", "custom": "allow", "keep": "allow"}, permission
lock = json.load(open(sys.argv[2], encoding="utf-8"))
assert list(lock["opencode_permissions"].values()) == [["keep"]], lock
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/doctor" 2> "$tmp/err"
  python3 - "$tmp/doctor" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1], encoding="utf-8"))["legacy_permissions"] == ["user-old"]
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --tool opencode > "$tmp/preview"
  grep -q 'user-old' "$tmp/preview" || fail 'migration preview omitted legacy permission'
  isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --apply --tool opencode > "$tmp/apply"
  grep -q 'Legacy OpenCode allows.*user-old' "$tmp/apply" || fail 'apply did not print legacy permissions before removal'
  python3 - "$config" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
permission = json.loads(path.read_text())["permission"]["skill"]
assert "user-old" not in permission and permission["deny-old"] == "deny" and permission["custom"] == "allow"
backups = list(path.parent.glob("opencode.json.*.bak"))
assert len(backups) == 1 and json.loads(backups[0].read_text())["permission"]["skill"]["user-old"] == "allow"
PY
  # A canonical copy changed into a foreign link is never removed.
  isolated "$tmp/home" "$tmp/repo/install.sh" prune --tool claude,codex --link >/dev/null
  mkdir -p "$tmp/foreign"
  rm "$tmp/home/.claude/skills/prune"
  ln -s "$tmp/foreign" "$tmp/home/.claude/skills/prune"
  local rc=0
  isolated "$tmp/home" "$tmp/repo/install.sh" --update > "$tmp/out" 2> "$tmp/err" || rc=$?
  (( rc == 6 )) || fail "foreign link prune exited $rc"
  [[ "$(readlink "$tmp/home/.claude/skills/prune")" == "$tmp/foreign" ]] || fail 'foreign link was removed'
  rm -rf "$tmp"
  trap - RETURN
}

test_permission_provenance_on_install_migration_and_alternate_config() {
  local tmp dest config
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  dest="$tmp/installed"
  config="$tmp/home/.config/opencode/opencode.json"
  isolated "$tmp/home" "$tmp/repo/install.sh" old prune --tool opencode --dest "$dest" >/dev/null
  rm -rf "$dest/prune"
  isolated "$tmp/home" "$tmp/repo/install.sh" old --tool opencode --dest "$dest" >/dev/null
  python3 - "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"] == {"old": "allow"}
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --apply --tool opencode --dest "$dest" >/dev/null
  python3 - "$config" "$dest/.skills-lock.json" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"] == {"new": "allow"}
assert list(json.load(open(sys.argv[2]))["opencode_permissions"].values()) == [["new"]]
PY
  rm -rf "$dest/new"
  printf '%s\n' '{"permission":{"skill":{"new":"allow","old":"deny"}}}' > "$tmp/alternate.json"
  isolated "$tmp/home" OPENCODE_CONFIG_FILE="$tmp/alternate.json" "$tmp/repo/install.sh" keep --tool opencode --dest "$dest" >/dev/null
  python3 - "$tmp/alternate.json" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"] == {"new": "allow", "old": "deny", "keep": "allow"}
PY
  rm "$tmp/alternate.json"
  isolated "$tmp/home" OPENCODE_CONFIG_FILE="$tmp/alternate.json" "$tmp/repo/install.sh" --migrate --apply --tool opencode --dest "$dest" >/dev/null
  [[ ! -e "$tmp/alternate.json" ]] || fail 'permission cleanup recreated an absent config'
  python3 - "$dest/.skills-lock.json" <<'PY'
import json
import sys
assert sorted(json.load(open(sys.argv[1]))["opencode_permissions"].values()) == [[], ["new"]]
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_prune_guard_cases() {
  local tmp case dest kind backup rc output before
  for case in backup-inside backup-symlink backup-fault pending real-link-root foreign-source old-source no-v2 no-v2-link; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    make_convergence_fixture "$tmp"
    dest="$tmp/home/.agents/skills"
    isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool codex >/dev/null
    kind=copy
    backup="$tmp/backups"
    case "$case" in
      backup-inside) backup="$dest/backups" ;;
      backup-symlink)
        backup="$tmp/home/.agents/.skills-backups"
        mkdir -p "$backup/skills"
        ln -s "$dest" "$backup/skills/.pruned"
        backup=""
        ;;
      pending)
        printf 'new upstream content\n' > "$tmp/repo/skills/prune/new-file"
        isolated "$tmp/home" SKILLS_INSTALL_FAULT=lock "$tmp/repo/install.sh" prune --tool codex --force >/dev/null 2>&1 && fail 'lock fault did not fail'
        ;;
      real-link-root) kind="link" ;;
      foreign-source|old-source|no-v2|no-v2-link)
        python3 - "$dest/.skills-lock.json" "$case" "$tmp" <<'PY'
import json
from pathlib import Path
import sys
path, case, tmp = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
lock = json.loads(path.read_text())
if case.startswith("no-v2"):
    lock["trees"].pop("prune")
else:
    lock["source"] = str(tmp / ("publisher/skills" if case == "foreign-source" else "gone"))
path.write_text(json.dumps(lock))
PY
        if [[ "$case" == no-v2-link ]]; then kind="link"; fi
        ;;
    esac
    before="$(tree_hash "$dest/prune")"
    sed '$d' "$tmp/repo/install.sh" > "$tmp/repo/install-library.sh"
    cat >> "$tmp/repo/install-library.sh" <<'SH'
SAVED_SELECTION=(keep)
SAVED_LINK=true
txn_root "$1"
prune_updated_dest "$2" "$1"
printf 'counts:%s:%s\n' "$UPD_FAILED" "$UPD_SKIPPED"
SH
    rc=0
    output="$(isolated "$tmp/home" SKILLS_BACKUP_DIR="$backup" SKILLS_INSTALL_FAULT="$(if [[ "$case" == backup-fault ]]; then printf backup; fi)" \
      bash "$tmp/repo/install-library.sh" "$dest" "$kind" 2>&1)" || rc=$?
    (( rc == 0 )) || fail "$case: prune guard crashed: $output"
    [[ "$(tree_hash "$dest/prune")" == "$before" ]] || fail "$case: guarded copy changed"
    case "$case" in
      backup-inside|backup-symlink) grep -q 'backup directory is inside the install root' <<< "$output" || fail "$case: $output" ;;
      backup-fault) grep -q 'prune backup failed' <<< "$output" || fail "$case: $output" ;;
      pending)
        grep -q 'pending recovery' <<< "$output" || fail "$case: $output"
        grep -q 'counts:0:0' <<< "$output" || fail "$case: $output"
        ;;
      real-link-root) grep -q 'not a link to the canonical skill' <<< "$output" || fail "$case: $output" ;;
      no-v2|no-v2-link)
        grep -q 'select this skill and run install.sh --tool <tools> --link --force prune' <<< "$output" || fail "$case: $output"
        grep -q 'counts:0:0' <<< "$output" || fail "$case: $output"
        ;;
    esac
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_update_copy_mode_keeps_referenced_canonical() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool claude --link >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool codex --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool codex --json > "$tmp/doctor" 2> "$tmp/err"
  python3 - "$tmp/doctor" <<'PY'
import json
import sys
rows = json.load(open(sys.argv[1]))["outside_selection"]
assert any(row["name"] == "prune" and not row["prunable"] and row["reason"] == "still referenced by a tool link" for row in rows), rows
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --update --json > "$tmp/out" 2> "$tmp/err"
  [[ -L "$tmp/home/.claude/skills/prune" && -f "$tmp/home/.claude/skills/prune/SKILL.md" ]] || fail 'copy-mode update left a dangling tool link'
  python3 - "$tmp/out" <<'PY'
import json
import sys
result = json.load(open(sys.argv[1]))
assert result["pruned"] == [] and result["skipped"] == 0, result
assert any(row["name"] == "prune" and row["reason"] == "still referenced by a tool link" for row in result["prune_kept"]), result
PY
  rm -rf "$tmp"
  trap - RETURN
}

test_update_preserves_explicit_internal_selection() {
  local tmp before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  write_fixture_skill "$tmp/publisher" internal $'---\nname: internal\ndescription: internal fixture\nmetadata:\n  internal: true\n---'
  publish_convergence_fixture "$tmp"
  isolated "$tmp/home" git -C "$tmp/repo" pull -q --ff-only
  isolated "$tmp/home" "$tmp/repo/install.sh" keep internal --tool codex --save >/dev/null
  grep -qx 'include_internal=false' "$tmp/home/.config/iuliandita-skills/install.conf" || fail 'explicit internal fixture saved the flag'
  before="$(tree_hash "$tmp/home")"
  isolated "$tmp/home" "$tmp/repo/install.sh" --update --json > "$tmp/out" 2> "$tmp/err"
  [[ -f "$tmp/home/.agents/skills/internal/SKILL.md" ]] || fail 'update pruned an explicitly saved internal skill'
  [[ "$(tree_hash "$tmp/home")" == "$before" ]] || fail 'explicit internal update changed the installation'
  isolated "$tmp/home" "$tmp/repo/install.sh" >/dev/null
  [[ "$(tree_hash "$tmp/home")" == "$before" ]] || fail 'bare install disagrees with explicit internal update'
  rm -rf "$tmp"
  trap - RETURN
}

test_update_forgets_absent_unselected_record() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool codex >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool codex --save >/dev/null
  rm -rf "$tmp/home/.agents/skills/prune"
  isolated "$tmp/home" "$tmp/repo/install.sh" --update --json > "$tmp/out" 2> "$tmp/err"
  python3 - "$tmp/home/.agents/skills/.skills-lock.json" "$tmp/out" <<'PY'
import json
import sys
lock = json.load(open(sys.argv[1]))
assert "prune" not in lock["skills"] and "prune" not in lock["trees"], lock
result = json.load(open(sys.argv[2]))
assert result["status"] == "current" and result["skipped"] == 0 and result["prune_kept"] == [], result
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  rm -rf "$tmp"
  trap - RETURN
}

test_update_missing_saved_name_and_canonical_guards() {
  local tmp case rc root
  for case in missing-saved failed-tool referenced-canonical; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    make_convergence_fixture "$tmp"
    if [[ "$case" == missing-saved ]]; then
      isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool codex --save >/dev/null
      rm -rf "$tmp/publisher/skills/prune"
      publish_convergence_fixture "$tmp"
    else
      isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool claude,codex --link >/dev/null
      isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool claude,codex --link --save >/dev/null
      if [[ "$case" == failed-tool ]]; then
        root="$(txn_area "$tmp/home/.claude/skills")/keep"
        mkdir -p "$root"
        printf 'bad record\n' > "$root/record"
      else
        mkdir -p "$tmp/home/.cursor/skills"
        ln -s "$tmp/home/.agents/skills/prune" "$tmp/home/.cursor/skills/alias"
      fi
    fi
    rc=0
    isolated "$tmp/home" "$tmp/repo/install.sh" --update > "$tmp/out" 2> "$tmp/err" || rc=$?
    [[ -f "$tmp/home/.agents/skills/prune/SKILL.md" ]] || fail "$case: canonical or saved copy lost"
    if [[ "$case" == failed-tool ]]; then
      (( rc == 1 )) || fail "$case: expected failure, got $rc"
      [[ -f "$tmp/home/.claude/skills/prune/SKILL.md" ]] || fail 'failed tool has a dangling link'
    else
      if [[ "$case" == missing-saved ]]; then
        (( rc == 6 )) || fail "$case: expected partial, got $rc"
        grep -q 'no longer in the source; see MIGRATION.md' "$tmp/out" || fail 'missing saved name was silent'
        grep -qx 'skills=keep,prune' "$tmp/home/.config/iuliandita-skills/install.conf" || fail 'missing name was forgotten'
      else
        (( rc == 0 )) || fail "$case: expected advisory success, got $rc"
        grep -q 'still referenced by a tool link' "$tmp/err" || fail 'canonical reference not reported'
        [[ -f "$tmp/home/.cursor/skills/alias/SKILL.md" ]] || fail 'known tool link dangles'
        isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool codex --json > "$tmp/doctor" 2> "$tmp/doctor.err"
        python3 - "$tmp/doctor" <<'PY'
import json
import sys
rows = json.load(open(sys.argv[1]))["outside_selection"]
assert any(row["name"] == "prune" and not row["prunable"] and row["reason"] == "still referenced by a tool link" for row in rows), rows
PY
      fi
    fi
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_doctor_advisory_errors_continue_discovery() {
  local tmp case dest rc
  for case in unreadable-lock gone-source bad-config; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    make_convergence_fixture "$tmp"
    isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool opencode --save >/dev/null
    dest="$tmp/home/.agents/skills"
    case "$case" in
      unreadable-lock) rm "$dest/.skills-lock.json"; mkdir "$dest/.skills-lock.json" ;;
      gone-source) python3 - "$dest/.skills-lock.json" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
lock = json.loads(path.read_text())
lock["source"] += "/gone"
path.write_text(json.dumps(lock))
PY
        ;;
      bad-config) printf '{bad' > "$tmp/home/.config/opencode/opencode.json" ;;
    esac
    mkdir -p "$tmp/home/.config/opencode/skills"
    cp -r "$dest/keep" "$tmp/home/.config/opencode/skills/keep"
    rc=0
    isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/out" 2> "$tmp/err" || rc=$?
    (( rc == 1 )) || fail "$case: duplicate status lost: $rc $(cat "$tmp/err")"
    case "$case" in
      unreadable-lock|gone-source)
        grep -Fq "warning: cannot verify OpenCode lock $dest/.skills-lock.json;" "$tmp/err" || fail "$case: missing lock warning"
        grep -Fq "delete $dest/.skills-lock.json if its checkout is retired" "$tmp/err" || fail "$case: missing lock remedy"
        ;;
      bad-config)
        grep -Fq "warning: cannot read OpenCode config $tmp/home/.config/opencode/opencode.json:" "$tmp/err" || fail "$case: missing config warning"
        ;;
    esac
    ! grep -q Traceback "$tmp/err" || fail "$case: doctor printed a traceback"
    python3 - "$tmp/out" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["blocking"] > 0
PY
    rm -rf "$tmp/home/.config/opencode/skills/keep"
    isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/out" 2> "$tmp/err" || fail "$case: advisory alone failed doctor"
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_migrate_preview_malformed_opencode_config() {
  local tmp case before
  for case in malformed scalar permission skill-permission; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    make_convergence_fixture "$tmp"
    isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool opencode >/dev/null
    case "$case" in
      malformed) printf '{bad' ;;
      scalar) printf '1' ;;
      permission) printf '{"permission":1}' ;;
      skill-permission) printf '{"permission":{"skill":1}}' ;;
    esac > "$tmp/home/.config/opencode/opencode.json"
    before="$(tree_hash "$tmp/home")"
    isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --tool opencode > "$tmp/out" 2> "$tmp/err" || fail "$case: malformed-config preview failed"
    [[ "$(grep -c '^warning:' "$tmp/err")" == 1 ]] || fail "$case: expected one warning: $(cat "$tmp/err")"
    grep -q 'skipping permission preview:' "$tmp/err" || fail "$case: missing preview warning"
    ! grep -q Traceback "$tmp/err" || fail "$case: preview printed a traceback"
    ! grep -Eq 'permission preview complete|OpenCode permissions synced' "$tmp/out" || fail "$case: preview claimed completion"
    [[ "$(tree_hash "$tmp/home")" == "$before" ]] || fail "$case: preview changed the installation"
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_unverifiable_permission_lock_warns_once_and_doctor_remedy() {
  local tmp dest config lock
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  dest="$tmp/home/.agents/skills"
  config="$tmp/home/.config/opencode/opencode.json"
  lock="$tmp/home/.cursor/skills/.skills-lock.json"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool opencode --save >/dev/null
  mkdir -p "${lock%/*}"
  python3 - "$dest/.skills-lock.json" "$lock" "$tmp/gone/skills" <<'PY'
import json
from pathlib import Path
import sys
lock = json.loads(Path(sys.argv[1]).read_text())
lock["source"] = sys.argv[3]
Path(sys.argv[2]).write_text(json.dumps(lock))
PY
  rm -rf "$dest/prune"
  sed '$d' "$tmp/repo/install.sh" > "$tmp/repo/install-library.sh"
  cat >> "$tmp/repo/install-library.sh" <<'SH'
sync_opencode_permissions "$1" "$2" sync keep
sync_opencode_permissions "$1" "$2" sync keep
SH
  isolated "$tmp/home" bash "$tmp/repo/install-library.sh" "$config" "$dest" > "$tmp/out" 2> "$tmp/err"
  [[ "$(grep -Fc "warning: cannot verify OpenCode lock $lock;" "$tmp/err")" == 1 ]] || fail 'unverifiable lock warning repeated or missing'
  python3 - "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"]["prune"] == "allow"
PY
  isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/doctor" 2> "$tmp/err"
  [[ "$(grep -Fc "warning: cannot verify OpenCode lock $lock;" "$tmp/err")" == 1 ]] || fail 'doctor lock warning repeated or missing'
  python3 - "$tmp/doctor" "$lock" <<'PY'
import json
import sys
findings = json.load(open(sys.argv[1]))["unverifiable_locks"]
assert len(findings) == 1 and findings[0]["path"] == sys.argv[2], findings
assert f"delete {sys.argv[2]} if its checkout is retired" in findings[0]["remedy"], findings
assert "rerun install.sh --tool opencode" in findings[0]["remedy"], findings
PY
  rm "$config"
  isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/doctor" 2> "$tmp/err"
  grep -Fq "delete $lock if its checkout is retired" "$tmp/err" || fail 'doctor requires a config to diagnose an unverifiable lock'
  rm -rf "$tmp"
  trap - RETURN
}

test_permission_guard_cases() {
  local tmp case dest config rc
  for case in other-root other-lock env-mode config-fault fresh-lock-fault preview-bad-lock preview-scalar-lock failed-update; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    make_convergence_fixture "$tmp"
    dest="$tmp/home/.agents/skills"
    config="$tmp/home/.config/opencode/opencode.json"
    if [[ "$case" == fresh-lock-fault ]]; then
      rc=0
      isolated "$tmp/home" SKILLS_INSTALL_FAULT=lock "$tmp/repo/install.sh" prune --tool opencode --json > "$tmp/out" 2> "$tmp/err" || rc=$?
      (( rc == 1 )) || fail 'fresh lock fault succeeded'
      python3 - "$tmp/out" "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["failed"] == 1
assert json.load(open(sys.argv[2]))["permission"]["skill"]["prune"] == "allow"
PY
      [[ "$(grep -c 'allows added without provenance' "$tmp/err")" == 1 ]] || fail 'fresh lock failure warning repeated'
    elif [[ "$case" == config-fault ]]; then
      rc=0
      isolated "$tmp/home" SKILLS_INSTALL_FAULT=opencode "$tmp/repo/install.sh" prune --tool opencode > "$tmp/out" 2>&1 || rc=$?
      (( rc == 1 )) || fail 'config fault succeeded'
      [[ ! -e "$config" ]] || fail 'config fault wrote config'
      python3 - "$dest/.skills-lock.json" "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["opencode_permissions"][sys.argv[2]] == ["prune"]
PY
      isolated "$tmp/home" "$tmp/repo/install.sh" prune --tool opencode >/dev/null
    elif [[ "$case" == env-mode ]]; then
      isolated "$tmp/home" OPENCODE_PERMISSION_MODE=preview "$tmp/repo/install.sh" prune --tool opencode >/dev/null
      [[ -f "$config" ]] || fail 'exported permission mode affected install'
    else
      isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool opencode --save >/dev/null
      if [[ "$case" == preview-bad-lock || "$case" == preview-scalar-lock ]]; then
        if [[ "$case" == preview-bad-lock ]]; then printf '{bad'; else printf '1'; fi > "$dest/.skills-lock.json"
        isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --tool opencode > "$tmp/out" 2> "$tmp/err" || fail 'unverified preview failed'
        grep -q 'permission preview complete; no changes written' "$tmp/out" || fail 'preview omitted preview-specific line'
        ! grep -q 'OpenCode permissions synced' "$tmp/out" || fail 'preview claimed a sync'
      else
        if [[ "$case" == other-root ]]; then
          mkdir -p "$tmp/home/.claude/skills"
          cp -r "$dest/prune" "$tmp/home/.claude/skills/prune"
        elif [[ "$case" == other-lock ]]; then
          isolated "$tmp/home" "$tmp/repo/install.sh" prune --tool opencode --dest "$tmp/home/.cursor/skills" >/dev/null
        fi
        if [[ "$case" == failed-update ]]; then
          isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool opencode --save >/dev/null
        fi
        rm -rf "$dest/prune"
        if [[ "$case" == failed-update ]]; then
          mkdir -p "$(txn_area "$dest")/keep"
          printf 'bad record\n' > "$(txn_area "$dest")/keep/record"
          rc=0
          isolated "$tmp/home" "$tmp/repo/install.sh" --update > "$tmp/out" 2> "$tmp/err" || rc=$?
          (( rc == 1 )) || fail 'failed OpenCode update succeeded'
        else
          isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool opencode >/dev/null
        fi
        python3 - "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"]["prune"] == "allow"
PY
        if [[ "$case" == other-lock ]]; then
          isolated "$tmp/home" "$tmp/repo/install.sh" old --tool opencode --dest "$tmp/home/.cursor/skills" >/dev/null
          isolated "$tmp/home" "$tmp/repo/install.sh" --doctor --tool opencode --json > "$tmp/doctor" 2> "$tmp/doctor.err"
          python3 - "$tmp/doctor" <<'PY'
import json
import sys
assert "old" not in json.load(open(sys.argv[1]))["legacy_permissions"]
PY
          isolated "$tmp/home" "$tmp/repo/install.sh" --migrate --apply --tool opencode >/dev/null
          python3 - "$config" <<'PY'
import json
import sys
assert json.load(open(sys.argv[1]))["permission"]["skill"]["old"] == "allow"
PY
        fi
      fi
    fi
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_prune_backups_preserve_overwrite_history() {
  local tmp dest before
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_convergence_fixture "$tmp"
  dest="$tmp/home/.agents/skills"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep prune --tool codex >/dev/null
  printf 'user modification\n' >> "$dest/prune/SKILL.md"
  isolated "$tmp/home" "$tmp/repo/install.sh" prune --tool codex --force >/dev/null
  before="$(tree_hash "$tmp/home/.agents/.skills-backups/skills/prune")"
  isolated "$tmp/home" "$tmp/repo/install.sh" keep --tool codex --save >/dev/null
  isolated "$tmp/home" "$tmp/repo/install.sh" --update >/dev/null
  [[ "$(tree_hash "$tmp/home/.agents/.skills-backups/skills/prune")" == "$before" ]] || fail 'prune rotated overwrite history'
  [[ -d "$tmp/home/.agents/.skills-backups/skills/.pruned/prune" ]] || fail 'prune backup namespace missing'
  rm -rf "$tmp"
  trap - RETURN
}

test_prune_guard_cases
test_update_copy_mode_keeps_referenced_canonical
test_update_preserves_explicit_internal_selection
test_update_forgets_absent_unselected_record
test_update_missing_saved_name_and_canonical_guards
test_doctor_advisory_errors_continue_discovery
test_migrate_preview_malformed_opencode_config
test_unverifiable_permission_lock_warns_once_and_doctor_remedy
test_permission_guard_cases
test_prune_backups_preserve_overwrite_history
test_update_prunes_only_verified_owned_trees
test_update_migrates_saved_names_and_filters_retired_skills
test_update_prunes_internal_and_deprecated_from_all_selection
test_update_link_pruning_and_permission_provenance
test_permission_provenance_on_install_migration_and_alternate_config
test_backups_stay_outside_skill_root
test_backup_override_separates_destinations
test_unverified_lock_backups_are_unique
test_shared_destination_is_installed_once
test_backup_retention_keeps_three_unique
test_legacy_backups_are_migrated_outside_skill_root
test_legacy_backup_migration_keeps_layout_on_collision
test_opencode_install_allows_installed_skills
test_link_mode_never_links_canonical_onto_itself
test_link_mode_keeps_foreign_symlink_without_force
test_opencode_string_permissions_are_preserved
test_link_mode_writes_tool_lock
test_removed_gemini_tool_is_unknown
test_omp_default_path
test_omp_skills_dir_override
test_omp_link_mode_shares_canonical_dir
test_omp_repeat_install_is_idempotent
test_plain_install_reports_current_for_unchanged_copies
test_plain_install_reports_differs_for_locally_edited_copy
test_plain_install_leaves_unrecorded_differing_copy_unrecorded
test_plain_install_reports_rename_and_symlink_target_differences
test_plain_install_keeps_unverifiable_copy_unpublished
test_force_still_overwrites_a_differing_copy
test_omp_check_mode
test_omp_and_kimi_share_destination
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
test_harness_alias_matches_tool
test_json_output
test_legacy_cleanup_custom_canonical_needs_replacement
test_opencode_link_migration_on_canonical_allows_replacement
test_embedded_python_ignores_cwd_modules
test_doctor_frontmatter_identity
test_doctor_reports_duplicates_read_only
test_doctor_merges_only_equivalent_findings
test_doctor_groups_and_verbose
test_doctor_flag_rules_and_alias
test_doctor_orders_blocking_first_across_tools
test_frontmatter_cache_selects_skills
test_malformed_frontmatter_fails_install
test_fault_before_promotion_keeps_previous_install
test_restore_fault_keeps_evidence_and_stops_destination
test_lock_fault_leaves_records_until_publication
test_opencode_fault_keeps_config_unchanged
test_link_fault_restores_previous_link
test_concurrent_installs_serialize
test_relative_xdg_state_home_is_ignored
test_installer_lock_contention_and_missing_flock
test_migration_recovers_before_apply
test_failed_retry_keeps_earlier_record
test_cross_device_destination_is_refused
test_post_promotion_failures_stop_and_reconcile
test_interrupted_rollback_keeps_previous_copy
test_unverified_copy_without_verified_prev_is_refused
printf 'install tests passed\n'
