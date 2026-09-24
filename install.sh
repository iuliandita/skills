#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/skill-lib.sh
source "$SCRIPT_DIR/scripts/skill-lib.sh"

SKILLS_SRC="$SCRIPT_DIR/skills"
CANONICAL_DIR="${SKILLS_CANONICAL_DIR:-$HOME/.agents/skills}"
MIGRATIONS_FILE="${SKILLS_MIGRATIONS_FILE:-$SCRIPT_DIR/migrations.json}"
MIGRATOR="${SKILLS_MIGRATOR:-$SCRIPT_DIR/scripts/migrate-skills.py}"

# Discover skills dynamically: scan skills/ for dirs with SKILL.md.
# Gitignored skills are excluded unless --include-internal is active and the
# skill declares metadata.internal: true.
discover_skills() {
  local include_internal="${1:-false}"
  local skills=()
  for dir in "$SKILLS_SRC"/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    local name
    name="$(basename "$dir")"
    # Skip gitignored skills - if not in a git repo, include everything.
    if git -C "$SKILLS_SRC" rev-parse --git-dir &>/dev/null; then
      if git -C "$SKILLS_SRC" check-ignore -q "$name" 2>/dev/null; then
        if [[ "$include_internal" != "true" ]] || ! is_internal "$dir"; then
          continue
        fi
      fi
    fi
    skills+=("$name")
  done
  # Sort for stable ordering
  IFS=$'\n' read -r -d '' -a skills < <(printf '%s\n' "${skills[@]}" | sort; printf '\0') || true
  printf '%s\n' "${skills[@]}"
}

ALL_SKILLS=()

SUPPORTED_TOOLS=(
  claude codex cursor windsurf opencode commandcode
  copilot gemini roo goose amp continue kiro cline warp
  openclaw hermes qwen crush antigravity augment openhands trae qoder kimi omp
  portable
)

declare -A TOOL_PATHS=(
  [claude]="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  [codex]="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  [cursor]="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
  [windsurf]="${WINDSURF_SKILLS_DIR:-$HOME/.codeium/windsurf/skills}"
  [opencode]="${OPENCODE_SKILLS_DIR:-$HOME/.agents/skills}"
  [copilot]="${COPILOT_SKILLS_DIR:-$HOME/.copilot/skills}"
  # Legacy: Gemini CLI consumer accounts moved to antigravity.
  [gemini]="${GEMINI_SKILLS_DIR:-$HOME/.agents/skills}"
  [roo]="${ROO_SKILLS_DIR:-$HOME/.roo/skills}"
  [goose]="${GOOSE_SKILLS_DIR:-$HOME/.config/goose/skills}"
  [amp]="${AMP_SKILLS_DIR:-$HOME/.config/agents/skills}"
  [continue]="${CONTINUE_SKILLS_DIR:-$HOME/.continue/skills}"
  [kiro]="${KIRO_SKILLS_DIR:-$HOME/.kiro/skills}"
  [cline]="${CLINE_SKILLS_DIR:-$HOME/.agents/skills}"
  [warp]="${WARP_SKILLS_DIR:-$HOME/.agents/skills}"
  [openclaw]="${OPENCLAW_SKILLS_DIR:-$HOME/.openclaw/skills}"
  [hermes]="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
  [qwen]="${QWEN_SKILLS_DIR:-$HOME/.qwen/skills}"
  [crush]="${CRUSH_SKILLS_DIR:-$HOME/.config/crush/skills}"
  [antigravity]="${ANTIGRAVITY_SKILLS_DIR:-$HOME/.gemini/config/skills}"
  [commandcode]="${COMMANDCODE_SKILLS_DIR:-$HOME/.agents/skills}"
  [augment]="${AUGMENT_SKILLS_DIR:-$HOME/.augment/skills}"
  [openhands]="${OPENHANDS_SKILLS_DIR:-$HOME/.openhands/skills}"
  [trae]="${TRAE_SKILLS_DIR:-$HOME/.trae/skills}"
  [qoder]="${QODER_SKILLS_DIR:-$HOME/.qoder/skills}"
  [kimi]="${KIMI_SKILLS_DIR:-$HOME/.agents/skills}"
  # OMP_SKILLS_DIR is installer-only; omp discovers ~/.agents/skills natively.
  [omp]="${OMP_SKILLS_DIR:-$HOME/.agents/skills}"
  [portable]="${PORTABLE_SKILLS_DIR:-$HOME/.skills}"
)

# Earlier default dirs for tools that now install into ~/.agents/skills, which
# they also read; --migrate cleans our old links there unless the override is set.
declare -A LEGACY_TOOL_PATHS=(
  [codex]="$HOME/.codex/skills"
  [commandcode]="$HOME/.commandcode/skills"
  [opencode]="$HOME/.config/opencode/skills"
)
declare -A LEGACY_TOOL_ENV=(
  [codex]=CODEX_SKILLS_DIR
  [commandcode]=COMMANDCODE_SKILLS_DIR
  [opencode]=OPENCODE_SKILLS_DIR
)

# Global dirs each harness reads, for --doctor. Static; harness config is not read.
# Row: tool|dir|dedupe group|evidence. Duplicates confined to roots of one group
# are resolved by the harness itself and reported as info.
DOCTOR_ROOTS=(
  "claude|$HOME/.claude/skills||verified: Claude Code docs"
  "codex|$HOME/.agents/skills||verified: Codex skills docs (0.156.1)"
  "commandcode|$HOME/.commandcode/skills||verified: Command Code dist/cli.mjs user root"
  "commandcode|$HOME/.agents/skills||verified: Command Code dist/cli.mjs compat root"
  "opencode|$HOME/.config/opencode/skills||verified: OpenCode 2.0.14 config skill plugin"
  "opencode|$HOME/.claude/skills|compat|verified: OpenCode 2.0.14 compatibility plugin, one skill per id"
  "opencode|$HOME/.agents/skills|compat|verified: OpenCode 2.0.14 compatibility plugin, one skill per id"
  "omp|$HOME/.agents/skills|omp|verified: Oh My Pi native discovery"
  "omp|$HOME/.claude/skills|omp|inferred: Oh My Pi claude compat provider"
  "omp|$HOME/.codex/skills|omp|inferred: Oh My Pi codex compat provider"
  "antigravity|$HOME/.gemini/config/skills||verified: single global dir"
  "hermes|$HOME/.hermes/skills||verified: single global dir"
)

OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_FILE:-$HOME/.config/opencode/opencode.json}"

declare -A TOOL_ALIASES=(
  [claude-code]=claude
  [openai-codex]=codex
  [github-copilot]=copilot
  [gemini-cli]=gemini
  [kiro-cli]=kiro
  [qwen-code]=qwen
  [kimi-cli]=kimi
  [agy]=antigravity
  [command-code]=commandcode
  [cmdc]=commandcode
  [oh-my-pi]=omp
)

supported_tools_text() {
  local tool
  local text=""
  for tool in "${SUPPORTED_TOOLS[@]}"; do
    if [[ -n "$text" ]]; then
      text+=", "
    fi
    text+="$tool"
  done
  printf '%s' "$text"
}

# ── Agent path resolution ─────────────────────────────────────────────
resolve_tool_path() {
  local tool="$1"
  tool="${TOOL_ALIASES[$tool]:-$tool}"
  local path="${TOOL_PATHS[$tool]:-}"

  if [[ -z "$path" ]]; then
    printf 'Unknown tool: %s\n' "$tool" >&2
    printf 'Supported: %s\n' "$(supported_tools_text)" >&2
    exit 1
  fi

  printf '%s\n' "$path"
}

canonical_tool_name() {
  local tool="$1"
  printf '%s\n' "${TOOL_ALIASES[$tool]:-$tool}"
}

# ── Usage ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: install.sh [OPTIONS] [SKILL...]

Install skills for AI coding agents.

Options:
  --tool TOOL         Target tool (repeatable, comma-separated)
                      Supported: $(supported_tools_text)
  --dest PATH         Override destination directory (single-tool mode only)
  --link              Symlink mode: install once to canonical dir, symlink per tool
  --list              List available skills and install status
  --check             Compare installed skills against source via lock file
  --migrate           Preview recorded legacy-skill migrations and old tool-dir
                      link cleanup (use --apply to run)
  --apply             Apply a migration preview; requires --migrate
  --force             Overwrite existing skills without prompting
  --no-backup         Skip backup of existing skills
  --include-internal  Include skills marked metadata.internal: true
  --doctor            Report skill names a harness can reach through more than
                      one directory (read-only; all known tools unless --tool)
  --help              Show this help

Symlink mode (--link):
  Copies skills to a single canonical directory (~/.agents/skills/ by default)
  and creates symlinks from each tool's skill directory. Update once, all
  tools see the change. Override canonical path with SKILLS_CANONICAL_DIR.

Lock file:
  Each install writes .skills-lock.json with content hashes. Use --check
  to compare installed hashes against the source and detect updates.

Examples:
  install.sh                                    # All skills for Claude (default)
  install.sh --tool codex                       # All skills for Codex
  install.sh --tool cursor kubernetes docker    # Specific skills for Cursor
  install.sh --tool claude,gemini,roo --link    # Canonical + symlinks
  install.sh --tool claude,codex,opencode --link --include-internal
  install.sh --check                            # Check Claude install for updates
  install.sh --check --tool cursor              # Check Cursor install
  install.sh --migrate                          # Preview legacy-skill migration
  install.sh --migrate --apply --tool codex     # Apply owned Codex migration
  install.sh --doctor --tool commandcode,opencode
  install.sh --tool portable --dest ~/.skills
  install.sh --list
EOF
}

# ── Hashing ───────────────────────────────────────────────────────────
hash_tool() {
  if command -v sha256sum &>/dev/null; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum &>/dev/null; then
    shasum -a 256 | cut -d' ' -f1
  else
    printf 'No SHA-256 tool found\n' >&2
    return 1
  fi
}

skill_hash() {
  local dir="$1"
  # No -L: symlinks under skills/ are listed but not followed, so a malicious
  # symlink committed to a skill dir cannot leak external file contents into
  # the lock-file hash or into install reads. See SECURITY-AUDIT.md SEC-007.
  LC_ALL=C find "$dir" -type f -print0 | LC_ALL=C sort -z | xargs -0 cat 2>/dev/null | hash_tool
}

# ── Internal skill detection ──────────────────────────────────────────
is_internal() {
  local skill_dir="$1"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  frontmatter_has "$skill_dir/SKILL.md" "metadata.internal" \
    && [[ "$(frontmatter_get "$skill_dir/SKILL.md" "metadata.internal")" == "true" ]]
}

is_deprecated() {
  local skill_dir="$1"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  frontmatter_has "$skill_dir/SKILL.md" "metadata.deprecated" \
    && [[ "$(frontmatter_get "$skill_dir/SKILL.md" "metadata.deprecated")" == "true" ]]
}

declare -A MIGRATION_ACTIONS=()
declare -A MIGRATION_REPLACEMENTS=()

load_migrations() {
  [[ -f "$MIGRATIONS_FILE" ]] || return 0
  local rows old action replacement
  if ! rows="$(python3 - "$MIGRATIONS_FILE" <<'PY'
import json
import re
import sys

name = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
try:
    payload = json.load(open(sys.argv[1], encoding="utf-8"))
    skills = payload["skills"]
    transition = payload["transition"]
    expected_transition = {"release", "published_at", "minimum_days", "placeholder_releases"}
    if payload.get("version") != 1 or not isinstance(skills, dict) or not isinstance(transition, dict):
        raise ValueError("expected version 1, transition object, and skills object")
    if set(transition) != expected_transition:
        raise ValueError("unexpected transition fields")
    for old, entry in sorted(skills.items()):
        action = entry["action"]
        replacement = entry["replacement"]
        if not isinstance(old, str) or not name.fullmatch(old):
            raise ValueError(f"invalid skill name: {old!r}")
        if action not in {"rename", "merge", "remove"}:
            raise ValueError(f"invalid action for {old}")
        if action == "remove":
            if replacement is not None:
                raise ValueError(f"remove action has replacement for {old}")
            replacement = ""
        elif not isinstance(replacement, str) or not name.fullmatch(replacement):
            raise ValueError(f"invalid replacement for {old}")
        print(f"{old}\t{action}\t{replacement}")
except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
    print(f"Invalid migrations manifest: {error}", file=sys.stderr)
    sys.exit(1)
PY
  )"; then
    return 1
  fi
  while IFS=$'\t' read -r old action replacement; do
    [[ -n "$old" ]] || continue
    MIGRATION_ACTIONS["$old"]="$action"
    MIGRATION_REPLACEMENTS["$old"]="$replacement"
  done <<< "$rows"
}

# ── Backup ────────────────────────────────────────────────────────────
backup_skill() {
  local skill="$1" dest_dir="$2"
  local backup_parent backup_name backup_base
  backup_parent="$(dirname "$dest_dir")"
  backup_name="$(basename "$dest_dir")"
  backup_base="${SKILLS_BACKUP_DIR:-$backup_parent/.skills-backups/$backup_name}"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local dest="$backup_base/$skill/$ts"
  mkdir -p "$dest"

  if [[ -L "$dest_dir/$skill" ]]; then
    cp -P "$dest_dir/$skill" "$dest/"
  else
    cp -r "$dest_dir/$skill/." "$dest/"
  fi

  # Prune old backups, keep last 3
  local count
  count=$(find "$backup_base/$skill" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
  if (( count > 3 )); then
    find "$backup_base/$skill" -maxdepth 1 -mindepth 1 -type d -print0 \
      | sort -z | head -z -n "$(( count - 3 ))" | xargs -0 rm -rf
  fi
}

migrate_legacy_backups() {
  local dest_dir="$1"
  local legacy_dir="$dest_dir/.backups"
  [[ -d "$legacy_dir" || -L "$legacy_dir" ]] || return 0

  local backup_parent backup_name backup_base ts dest
  backup_parent="$(dirname "$dest_dir")"
  backup_name="$(basename "$dest_dir")"
  backup_base="${SKILLS_BACKUP_DIR:-$backup_parent/.skills-backups/$backup_name}"
  ts="$(date +%Y%m%d-%H%M%S)"
  dest="$backup_base/.legacy/$ts"

  mkdir -p "$(dirname "$dest")"
  mv "$legacy_dir" "$dest"
  printf '  [>] legacy .backups moved to %s\n' "$dest"
}

# ── Lock file ─────────────────────────────────────────────────────────
backup_unverified_lock() {
  local lock_dir="$1"
  local lock_file="$lock_dir/.skills-lock.json"
  local backup_parent backup_name backup_base
  backup_parent="$(dirname "$lock_dir")"
  backup_name="$(basename "$lock_dir")"
  backup_base="${SKILLS_BACKUP_DIR:-$backup_parent/.skills-backups/$backup_name}"

  python3 - "$lock_file" "$lock_dir" "$backup_base" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import shutil
import sys

lock_file = Path(sys.argv[1])
destination = Path(sys.argv[2]).resolve(strict=True)
backup_base = Path(sys.argv[3]).resolve(strict=False)
try:
    backup_base.relative_to(destination)
except ValueError:
    pass
else:
    raise SystemExit("Refusing to back up a lock inside the destination")
stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
backup = backup_base / ".unverified-locks" / f"{stamp}.skills-lock.json"
suffix = 1
while backup.exists():
    suffix += 1
    backup = backup_base / ".unverified-locks" / f"{stamp}-{suffix}.skills-lock.json"
backup.parent.mkdir(parents=True)
shutil.copy2(lock_file, backup)
lock_file.unlink()
print(backup)
PY
}

ensure_lock_source() {
  local lock_dir="$1"
  local lock_file="$lock_dir/.skills-lock.json"
  [[ -f "$lock_file" ]] || return 0
  if python3 - "$lock_file" "$SKILLS_SRC" <<'PY'
import json
from pathlib import Path
import sys

lock_path = Path(sys.argv[1])
source = Path(sys.argv[2]).resolve(strict=True)
try:
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    lock_source = Path(lock["source"]).resolve(strict=True)
    if lock.get("version") != 1 or not isinstance(lock.get("skills"), dict) or lock_source != source:
        raise ValueError("version, source, or skills is incompatible")
except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
    sys.exit(1)
PY
  then
    return 0
  fi
  local backup
  backup="$(backup_unverified_lock "$lock_dir")"
  printf '  [>] unverified lock backed up to %s; creating a fresh lock\n' "$backup"
}

write_lock() {
  local lock_dir="$1"
  shift
  local skills=("$@")
  local lock_file="$lock_dir/.skills-lock.json"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local updates=()
  for skill in "${skills[@]}"; do
    local target="$lock_dir/$skill"
    [[ -L "$target" ]] && target="$(readlink -f "$target" 2>/dev/null || true)"
    [[ -d "$target" ]] || continue
    local source_target="$SKILLS_SRC/$skill"
    [[ -d "$source_target" ]] || continue
    local target_hash source_hash
    target_hash="$(skill_hash "$target")"
    source_hash="$(skill_hash "$source_target")"
    [[ "$target_hash" == "$source_hash" ]] || continue
    updates+=("$skill=$target_hash")
  done

  python3 - "$lock_file" "$SKILLS_SRC" "$now" "${updates[@]}" <<'PY'
import json
import pathlib
import re
import sys

lock_path = pathlib.Path(sys.argv[1])
source = pathlib.Path(sys.argv[2]).resolve(strict=True)
updated_at = sys.argv[3]
name = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
skills = {}
if lock_path.exists():
    try:
        existing = json.loads(lock_path.read_text(encoding="utf-8"))
        existing_source = pathlib.Path(existing["source"]).resolve(strict=True)
        if existing.get("version") != 1 or not isinstance(existing.get("skills"), dict) or existing_source != source:
            raise ValueError("version, source, or skills is incompatible")
        skills = dict(existing["skills"])
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise SystemExit(f"Refusing to update unverified lock {lock_path}: {error}")
for item in sys.argv[4:]:
    skill, digest = item.split("=", 1)
    if name.fullmatch(skill):
        previous = skills.get(skill)
        if previous is None:
            skills[skill] = {"hash": digest, "provenance": "source-equal-v1"}
        elif isinstance(previous, dict) and previous.get("provenance") == "source-equal-v1":
            skills[skill] = {"hash": digest, "provenance": "source-equal-v1"}
        elif isinstance(previous, str):
            skills[skill] = digest
payload = {
    "version": 1,
    "updated_at": updated_at,
    "source": str(source),
    "skills": dict(sorted(skills.items())),
}
temp = lock_path.with_name(f".{lock_path.name}.tmp")
temp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
temp.replace(lock_path)
PY
}

read_lock_hash() {
  local lock_file="$1" skill="$2"
  [[ -f "$lock_file" ]] || return 0
  python3 - "$lock_file" "$skill" <<'PY'
import json
import sys

try:
    value = json.load(open(sys.argv[1], encoding="utf-8"))["skills"].get(sys.argv[2])
    if isinstance(value, str):
        print(value)
    elif isinstance(value, dict) and isinstance(value.get("hash"), str):
        print(value["hash"])
except (OSError, ValueError, TypeError, json.JSONDecodeError):
    pass
PY
}

# ── Install helpers ───────────────────────────────────────────────────
validate_skill_name() {
  [[ "$1" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]
}

install_copy() {
  local skill="$1" dest_dir="$2" force="$3" no_backup="$4"

  if [[ -d "$dest_dir/$skill" || -L "$dest_dir/$skill" ]]; then
    if [[ "$force" != "true" ]]; then
      printf '  [~] %s already exists (use --force to overwrite)\n' "$skill"
      return 0
    fi
    if [[ "$no_backup" != "true" ]]; then
      backup_skill "$skill" "$dest_dir"
      printf '  [>] %s backed up\n' "$skill"
    fi
    rm -rf "${dest_dir:?}/${skill:?}"
  fi

  mkdir -p "$dest_dir/$skill"
  cp -r "$SKILLS_SRC/$skill/." "$dest_dir/$skill/"
  printf '  [+] %s installed\n' "$skill"
}

create_link() {
  local skill="$1" tool_dir="$2" force="$3" no_backup="$4"

  if [[ -e "$tool_dir/$skill" || -L "$tool_dir/$skill" ]]; then
    if [[ -L "$tool_dir/$skill" ]]; then
      local current_target
      current_target="$(readlink "$tool_dir/$skill")"
      if [[ "$current_target" == "$CANONICAL_DIR/$skill" ]]; then
        printf '  [=] %s already linked\n' "$skill"
        return 0
      fi
      # Symlink to wrong target - repoint it
      ln -sfn "$CANONICAL_DIR/$skill" "$tool_dir/$skill"
      printf '  [+] %s relinked\n' "$skill"
      return 0
    fi
    # Real directory from a previous copy install
    if [[ "$force" != "true" ]]; then
      printf '  [~] %s exists as copy (use --force to convert to symlink)\n' "$skill"
      return 0
    fi
    if [[ "$no_backup" != "true" ]]; then
      backup_skill "$skill" "$tool_dir"
      printf '  [>] %s backed up\n' "$skill"
    fi
    rm -rf "${tool_dir:?}/${skill:?}"
  fi

  ln -sfn "$CANONICAL_DIR/$skill" "$tool_dir/$skill"
  printf '  [+] %s linked\n' "$skill"
}

sync_opencode_permissions() {
  local config_file="$1"
  shift
  local skills=("$@")
  local synced_skills=()

  for skill in "${skills[@]}"; do
    validate_skill_name "$skill" || continue
    [[ -d "$SKILLS_SRC/$skill" ]] || continue
    synced_skills+=("$skill")
  done

  (( ${#synced_skills[@]} > 0 )) || return 0

  if ! command -v python3 &>/dev/null; then
    printf '  [!] OpenCode permission sync skipped: python3 not found\n'
    return 0
  fi

  mkdir -p "$(dirname "$config_file")"

  if ! python3 - "$config_file" "${synced_skills[@]}" <<'PY'
import json
import os
import sys

config_path = sys.argv[1]
skills = sys.argv[2:]

if os.path.exists(config_path) and os.path.getsize(config_path) > 0:
    with open(config_path, encoding="utf-8") as f:
        config = json.load(f)
else:
    config = {}

if not isinstance(config, dict):
    raise ValueError("OpenCode config root must be a JSON object")

permission = config.get("permission")
if not isinstance(permission, dict):
    permission = {}
    config["permission"] = permission

skill_permission = permission.get("skill")
if not isinstance(skill_permission, dict):
    skill_permission = {}
    permission["skill"] = skill_permission

changed = False
for skill in skills:
    if skill_permission.get(skill) == "deny":
        continue
    if skill_permission.get(skill) != "allow":
        skill_permission[skill] = "allow"
        changed = True

if changed or not os.path.exists(config_path):
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
PY
  then
    printf '  [!] OpenCode permission sync skipped: could not parse %s as JSON\n' "$config_file"
    return 0
  fi

  printf '  [=] OpenCode permissions synced\n'
}

sync_migrated_opencode_permissions() {
  local dest_dir="$1" applied_file="$2"
  local lock_file="$dest_dir/.skills-lock.json"
  local replacements=() replacement target target_hash source_hash lock_hash
  declare -A seen=()
  while IFS= read -r replacement; do
    validate_skill_name "$replacement" || continue
    [[ -e "$dest_dir/$replacement" || -L "$dest_dir/$replacement" ]] || continue
    target="$dest_dir/$replacement"
    [[ -L "$target" ]] && target="$(readlink -f "$target")"
    [[ -d "$target" ]] || continue
    target_hash="$(skill_hash "$target")"
    source_hash="$(skill_hash "$SKILLS_SRC/$replacement")"
    [[ "$target_hash" == "$source_hash" ]] || continue
    lock_hash="$(python3 - "$lock_file" "$replacement" "$SKILLS_SRC" <<'PY'
import json
from pathlib import Path
import sys

try:
    lock = json.load(open(sys.argv[1], encoding="utf-8"))
    record = lock["skills"].get(sys.argv[2])
    if Path(lock["source"]).resolve(strict=True) != Path(sys.argv[3]).resolve(strict=True):
        raise ValueError("foreign lock source")
    if isinstance(record, dict) and record.get("provenance") == "source-equal-v1" and isinstance(record.get("hash"), str):
        print(record["hash"])
except (OSError, ValueError, TypeError, json.JSONDecodeError):
    pass
PY
)"
    [[ "$target_hash" == "$lock_hash" ]] || continue
    [[ -n "${seen[$replacement]:-}" ]] && continue
    seen["$replacement"]=true
    replacements+=("$replacement")
  done < "$applied_file"
  (( ${#replacements[@]} > 0 )) || return 0
  sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${replacements[@]}"
}

paths_match() {
  [[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]
}

# ── Legacy tool dirs ──────────────────────────────────────────────────
legacy_cleanup_dir() {
  local tool="$1"
  local legacy="${LEGACY_TOOL_PATHS[$tool]:-}"
  [[ -n "$legacy" && -d "$legacy" ]] || return 1
  local env_name="${LEGACY_TOOL_ENV[$tool]}"
  [[ -z "${!env_name:-}" ]] || return 1
  printf '%s\n' "$legacy"
}

run_legacy_cleanup() {
  local tool="$1" legacy="$2"
  shift 2
  python3 "$MIGRATOR" --source "$SKILLS_SRC" --legacy-dir "$legacy" \
    --new-dir "$(resolve_tool_path "$tool")" --link-root "$CANONICAL_DIR" \
    --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$legacy")/.skills-backups/$(basename "$legacy")}" "$@"
}

legacy_cleanup_hint() {
  local tool="$1" legacy output count
  legacy="$(legacy_cleanup_dir "$tool")" || return 0
  output="$(run_legacy_cleanup "$tool" "$legacy")" || return 0
  count="$(grep -c '^DRY-RUN unlink ' <<< "$output" || true)"
  (( count > 0 )) || return 0
  printf '  [i] %d old link(s) in %s duplicate this install; preview cleanup with: install.sh --migrate --tool %s\n' "$count" "$legacy" "$tool"
}

# ── Doctor ────────────────────────────────────────────────────────────
run_doctor() {
  local tool row rows=()
  for tool in "$@"; do
    for row in "${DOCTOR_ROOTS[@]}"; do
      [[ "${row%%|*}" == "$tool" ]] && rows+=("$row")
    done
  done
  python3 - "$(IFS=,; printf '%s' "$*")" "${rows[@]}" <<'PY'
from pathlib import Path
import re
import sys

tools = sys.argv[1].split(",")
table = [row.split("|", 3) for row in sys.argv[2:]]


def yaml_scalar(raw):
    raw = raw.strip()
    if raw[:1] == "'":
        match = re.match(r"'((?:[^']|'')*)'\s*(?:#.*)?$", raw)
        return match.group(1).replace("''", "'") if match else None
    if raw[:1] == '"':
        match = re.match(r'"((?:[^"\\]|\\.)*)"\s*(?:#.*)?$', raw)
        return re.sub(r"\\(.)", r"\1", match.group(1)) if match else None
    return re.split(r"(?:^|\s)#", raw, maxsplit=1)[0].strip() or None


def frontmatter_name(skill_md):
    try:
        lines = skill_md.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        if line.strip() == "---":
            return None
        if line.startswith("name:"):
            return yaml_scalar(line[len("name:"):])
    return None


print("Checking the static root table; harness config toggles are not read.")
blocking = 0
for tool in tools:
    print(f"\n[{tool}]")
    roots = []
    seen = {}
    for _, path, group, evidence in (row for row in table if row[0] == tool):
        real = Path(path).resolve(strict=False)
        if real in seen:
            print(f"  {path}  (same directory as {seen[real]})")
            continue
        seen[real] = path
        roots.append((path, group))
        print(f"  {path}  ({evidence})")
    if not roots:
        print("  not in the static root table; nothing to compare")
        continue
    if len(roots) < 2:
        print("  single root; nothing to compare")
        continue
    found = {}
    for index, (path, _) in enumerate(roots):
        root = Path(path)
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if entry.name.startswith(".") or not (entry / "SKILL.md").is_file():
                continue
            identities = [("dir", entry.name), ("name", frontmatter_name(entry / "SKILL.md"))]
            for key in identities:
                if key[1] is not None:
                    found.setdefault(key, {}).setdefault(index, str(entry))
    clean = True
    for key in sorted(found):
        where = found[key]
        if len(where) < 2:
            continue
        clean = False
        groups = {roots[index][1] for index in where}
        paths = ", ".join(where[index] for index in sorted(where))
        if len(groups) == 1 and "" not in groups:
            print(f"  [i] {key[0]} {key[1]}: {paths} (resolved by the harness)")
        else:
            blocking += 1
            print(f"  [!] {key[0]} {key[1]}: {paths}")
    if clean:
        print("  no duplicates")

print()
if blocking:
    print(f"{blocking} duplicate skill name(s) reachable through more than one directory.")
    sys.exit(1)
print("No blocking duplicates.")
PY
}

# ── Check mode ────────────────────────────────────────────────────────
check_updates() {
  local dest_dir="$1"
  local lock_file="$dest_dir/.skills-lock.json"

  if [[ ! -f "$lock_file" ]]; then
    printf 'No lock file found at %s\n' "$lock_file"
    printf 'Run install.sh first to generate one.\n'
    exit 1
  fi

  printf 'Checking for updates...\n\n'

  local outdated=0 current=0 missing=0 legacy=0
  for skill in "${ALL_SKILLS[@]}"; do
    [[ -d "$SKILLS_SRC/$skill" ]] || continue
    is_deprecated "$SKILLS_SRC/$skill" && continue

    local src_hash installed_hash
    src_hash="$(skill_hash "$SKILLS_SRC/$skill")"
    installed_hash="$(read_lock_hash "$lock_file" "$skill")"

    if [[ -z "$installed_hash" ]]; then
      printf '  [?] %-24s not installed\n' "$skill"
      (( missing++ )) || true
    elif [[ "$src_hash" != "$installed_hash" ]]; then
      printf '  [!] %-24s outdated\n' "$skill"
      (( outdated++ )) || true
    else
      printf '  [=] %-24s current\n' "$skill"
      (( current++ )) || true
    fi
  done

  local old
  for old in "${!MIGRATION_ACTIONS[@]}"; do
    if [[ -d "$dest_dir/$old" || -L "$dest_dir/$old" ]]; then
      local replacement="${MIGRATION_REPLACEMENTS[$old]}"
      if [[ -n "$replacement" ]]; then
        printf '  [!] %-24s legacy installed (%s -> %s)\n' "$old" "${MIGRATION_ACTIONS[$old]}" "$replacement"
      else
        printf '  [!] %-24s legacy installed (%s)\n' "$old" "${MIGRATION_ACTIONS[$old]}"
      fi
      (( legacy++ )) || true
    fi
  done

  printf '\n%d current, %d outdated, %d not installed, %d legacy\n' "$current" "$outdated" "$missing" "$legacy"
  if (( outdated > 0 || missing > 0 || legacy > 0 )); then
    exit 1
  fi
}

# ── List mode ─────────────────────────────────────────────────────────
list_skills() {
  local dest_dir="$1"
  printf '\nAvailable skills (%d):\n\n' "${#ALL_SKILLS[@]}"
  for skill in "${ALL_SKILLS[@]}"; do
    local status=""
    if [[ -L "$dest_dir/$skill" ]]; then
      status="linked"
    elif [[ -d "$dest_dir/$skill" ]]; then
      status="installed"
    fi
    if is_deprecated "$SKILLS_SRC/$skill"; then
      if [[ -n "$status" ]]; then
        printf '  %-24s [deprecated, %s]\n' "$skill" "$status"
      else
        printf '  %-24s [deprecated]\n' "$skill"
      fi
    elif [[ -n "$status" ]]; then
      printf '  %-24s [%s]\n' "$skill" "$status"
    else
      printf '  %-24s\n' "$skill"
    fi
  done
  printf '\n'
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
  local force=false no_backup=false link_mode=false
  local check_mode=false show_list=false include_internal=false migrate_mode=false apply_migration=false
  local doctor_mode=false
  local dest_override=""
  local tools=() skills=()

  while (( $# > 0 )); do
    case "$1" in
      --tool)
        [[ $# -ge 2 ]] || { printf '%s\n' "--tool requires a value" >&2; exit 1; }
        IFS=',' read -ra _parsed <<< "$2"
        tools+=("${_parsed[@]}")
        shift
        ;;
      --dest)
        [[ $# -ge 2 ]] || { printf '%s\n' "--dest requires a value" >&2; exit 1; }
        dest_override="$2"
        shift
        ;;
      --link)             link_mode=true ;;
      --list)             show_list=true ;;
      --check)            check_mode=true ;;
      --migrate)          migrate_mode=true ;;
      --apply)            apply_migration=true ;;
      --force)            force=true ;;
      --no-backup)        no_backup=true ;;
      --include-internal) include_internal=true ;;
      --doctor)           doctor_mode=true ;;
      --help|-h)          usage; exit 0 ;;
      -*)                 printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
      *)                  skills+=("$1") ;;
    esac
    shift
  done

  local tools_given="${#tools[@]}"
  if [[ "$doctor_mode" == "true" && "$tools_given" -eq 0 ]]; then
    local row
    for row in "${DOCTOR_ROOTS[@]}"; do
      [[ " ${tools[*]} " == *" ${row%%|*} "* ]] || tools+=("${row%%|*}")
    done
  fi

  # Default tool
  if (( ${#tools[@]} == 0 )); then
    tools=("${SKILLS_TOOL:-claude}")
  fi

  mapfile -t ALL_SKILLS < <(discover_skills "$include_internal")
  load_migrations || { printf '%s\n' "Cannot continue with an invalid migrations.json" >&2; exit 1; }

  # Validate tool names
  for i in "${!tools[@]}"; do
    tools[i]="$(canonical_tool_name "${tools[i]}")"
    resolve_tool_path "${tools[i]}" > /dev/null
  done

  # Build skill list (filter internal unless --include-internal)
  local requested_skill_count="${#skills[@]}"
  if (( ${#skills[@]} == 0 )); then
    for skill in "${ALL_SKILLS[@]}"; do
      if [[ "$include_internal" != "true" ]] && is_internal "$SKILLS_SRC/$skill"; then
        continue
      fi
      if is_deprecated "$SKILLS_SRC/$skill"; then
        continue
      fi
      skills+=("$skill")
    done
  fi

  # Validate flag combinations
  if [[ -n "$dest_override" && ${#tools[@]} -gt 1 ]]; then
    printf '%s\n' "--dest cannot be used with multiple tools" >&2; exit 1
  fi
  if [[ "$link_mode" == "true" && -n "$dest_override" ]]; then
    printf '%s\n' "--link and --dest cannot be used together" >&2; exit 1
  fi
  if [[ "$apply_migration" == "true" && "$migrate_mode" != "true" ]]; then
    printf '%s\n' "--apply requires --migrate" >&2; exit 1
  fi
  if [[ "$migrate_mode" == "true" && "$requested_skill_count" -gt 0 ]]; then
    printf '%s\n' "--migrate does not accept skill names; it uses migrations.json" >&2; exit 1
  fi
  if [[ "$migrate_mode" == "true" && ( "$force" == "true" || "$no_backup" == "true" ) ]]; then
    printf '%s\n' "--force and --no-backup cannot be used with --migrate" >&2; exit 1
  fi
  if [[ "$doctor_mode" == "true" ]]; then
    if [[ "$link_mode$show_list$check_mode$migrate_mode$apply_migration$force$no_backup" == *true* \
      || -n "$dest_override" || "$requested_skill_count" -gt 0 ]]; then
      printf '%s\n' "--doctor is read-only and accepts only --tool" >&2; exit 1
    fi
    run_doctor "${tools[@]}"
    exit 0
  fi

  # Resolve primary destination (for --list, --check)
  local primary_dest
  if [[ -n "$dest_override" ]]; then
    primary_dest="$dest_override"
  elif [[ "$link_mode" == "true" ]]; then
    primary_dest="$CANONICAL_DIR"
  else
    primary_dest="$(resolve_tool_path "${tools[0]}")"
  fi

  # ── List ────────────────────────────────────────────────────────────
  if [[ "$show_list" == "true" ]]; then
    list_skills "$primary_dest"
    exit 0
  fi

  # ── Check ───────────────────────────────────────────────────────────
  if [[ "$check_mode" == "true" ]]; then
    check_updates "$primary_dest"
    exit 0
  fi

  # ── Migration ──────────────────────────────────────────────────────
  if [[ "$migrate_mode" == "true" ]]; then
    command -v python3 >/dev/null || { printf '%s\n' "Migration requires python3" >&2; exit 1; }
    [[ -f "$MIGRATOR" ]] || { printf 'Migration helper is unavailable: %s\n' "$MIGRATOR" >&2; exit 1; }
    local migration_args=(--manifest "$MIGRATIONS_FILE" --source "$SKILLS_SRC")
    if [[ "$apply_migration" == "true" ]]; then
      migration_args+=(--apply)
      printf 'Applying recorded legacy-skill migration. Backups are always retained.\n\n'
    else
      printf 'Previewing recorded legacy-skill migration. Re-run with --apply to change files.\n\n'
    fi
    if [[ "$link_mode" == "true" ]]; then
      local canonical_applied="" canonical_args=()
      if [[ "$apply_migration" == "true" && " ${tools[*]} " == *" opencode "* ]] \
        && paths_match "$(resolve_tool_path opencode)" "$CANONICAL_DIR"; then
        canonical_applied="$(mktemp)"
        canonical_args=(--applied-file "$canonical_applied")
      fi
      python3 "$MIGRATOR" "${migration_args[@]}" --dest "$CANONICAL_DIR" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$CANONICAL_DIR")/.skills-backups/$(basename "$CANONICAL_DIR")}" --protected-root "$CANONICAL_DIR" --preserve-shared-canonical "${canonical_args[@]}"
      if [[ -n "$canonical_applied" ]]; then
        sync_migrated_opencode_permissions "$CANONICAL_DIR" "$canonical_applied"
        rm -f "$canonical_applied"
      fi
      local -A migrated_destinations=()
      for tool in "${tools[@]}"; do
        local tool_dir
        tool_dir="$(resolve_tool_path "$tool")"
        paths_match "$tool_dir" "$CANONICAL_DIR" && continue
        [[ -n "${migrated_destinations[$tool_dir]:-}" ]] && continue
        migrated_destinations["$tool_dir"]=true
        local applied_file=""
        local applied_args=()
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          applied_file="$(mktemp)"
          applied_args=(--applied-file "$applied_file")
        fi
        python3 "$MIGRATOR" "${migration_args[@]}" --dest "$tool_dir" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$tool_dir")/.skills-backups/$(basename "$tool_dir")}" --protected-root "$CANONICAL_DIR" --link-root "$CANONICAL_DIR" "${applied_args[@]}"
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          sync_migrated_opencode_permissions "$tool_dir" "$applied_file"
          rm -f "$applied_file"
        fi
      done
    else
      local -A migrated_destinations=()
      for tool in "${tools[@]}"; do
        local tool_dir
        if [[ -n "$dest_override" ]]; then
          tool_dir="$dest_override"
        else
          tool_dir="$(resolve_tool_path "$tool")"
        fi
        [[ -n "${migrated_destinations[$tool_dir]:-}" ]] && continue
        migrated_destinations["$tool_dir"]=true
        local applied_file=""
        local applied_args=()
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          applied_file="$(mktemp)"
          applied_args=(--applied-file "$applied_file")
        fi
        if paths_match "$tool_dir" "$CANONICAL_DIR"; then
          python3 "$MIGRATOR" "${migration_args[@]}" --dest "$tool_dir" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$tool_dir")/.skills-backups/$(basename "$tool_dir")}" --protected-root "$CANONICAL_DIR" --preserve-shared-canonical "${applied_args[@]}"
        else
          python3 "$MIGRATOR" "${migration_args[@]}" --dest "$tool_dir" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$tool_dir")/.skills-backups/$(basename "$tool_dir")}" --protected-root "$CANONICAL_DIR" "${applied_args[@]}"
        fi
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          sync_migrated_opencode_permissions "$tool_dir" "$applied_file"
          rm -f "$applied_file"
        fi
      done
    fi
    if [[ -z "$dest_override" ]]; then
      local cleanup_failed=0 legacy cleanup_args=()
      local -A cleaned_dirs=()
      [[ "$apply_migration" == "true" ]] && cleanup_args=(--apply)
      for tool in "${tools[@]}"; do
        legacy="$(legacy_cleanup_dir "$tool")" || continue
        [[ -n "${cleaned_dirs[$legacy]:-}" ]] && continue
        cleaned_dirs["$legacy"]=true
        printf '\n[%s] old directory %s\n' "$tool" "$legacy"
        if ! run_legacy_cleanup "$tool" "$legacy" "${cleanup_args[@]}"; then
          printf '  [!] cleanup of %s failed\n' "$legacy" >&2
          cleanup_failed=1
        fi
      done
      (( cleanup_failed == 0 )) || exit 1
    fi
    exit 0
  fi

  # ── Install: link mode ──────────────────────────────────────────────
  if [[ "$link_mode" == "true" ]]; then
    printf 'Installing %d skill(s) via symlink\n' "${#skills[@]}"
    printf 'Canonical: %s\n\n' "$CANONICAL_DIR"
    mkdir -p "$CANONICAL_DIR"
    ensure_lock_source "$CANONICAL_DIR"
    migrate_legacy_backups "$CANONICAL_DIR"

    # Copy all skills to canonical dir first
    local failed=0
    for skill in "${skills[@]}"; do
      if ! validate_skill_name "$skill"; then
        printf '  [!] Invalid skill name: %s\n' "$skill"
        (( failed++ )) || true
        continue
      fi
      if [[ ! -d "$SKILLS_SRC/$skill" ]]; then
        printf '  [!] Unknown skill: %s\n' "$skill"
        (( failed++ )) || true
        continue
      fi
      if is_deprecated "$SKILLS_SRC/$skill"; then
        local replacement="${MIGRATION_REPLACEMENTS[$skill]:-}"
        if [[ -n "$replacement" ]]; then
          printf '  [!] %s is deprecated; use %s\n' "$skill" "$replacement"
        else
          printf '  [!] %s is deprecated and scheduled for removal\n' "$skill"
        fi
      fi
      install_copy "$skill" "$CANONICAL_DIR" "$force" "$no_backup" || (( failed++ )) || true
    done

    # Create symlinks per tool
    for tool in "${tools[@]}"; do
      local tool_dir
      tool_dir="$(resolve_tool_path "$tool")"
      if [[ "$tool_dir" == "$CANONICAL_DIR" ]]; then
        printf '[%s] -> %s (matches canonical, skipping links)\n' "$tool" "$tool_dir"
      else
        mkdir -p "$tool_dir"
        ensure_lock_source "$tool_dir"
        migrate_legacy_backups "$tool_dir"
        printf '[%s] -> %s\n' "$tool" "$tool_dir"
        for skill in "${skills[@]}"; do
          validate_skill_name "$skill" || continue
          [[ -d "$SKILLS_SRC/$skill" ]] || continue
          create_link "$skill" "$tool_dir" "$force" "$no_backup"
        done
        write_lock "$tool_dir" "${skills[@]}"
      fi
      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${skills[@]}"
      fi
      legacy_cleanup_hint "$tool"
      printf '\n'
    done

    write_lock "$CANONICAL_DIR" "${skills[@]}"

    if (( failed > 0 )); then
      printf 'Done with %d error(s).\n' "$failed"
      exit 1
    fi
    printf 'Done. %d skills linked for %s.\n' "${#skills[@]}" "${tools[*]}"

  # ── Install: copy mode ──────────────────────────────────────────────
  else
    local failed=0

    for tool in "${tools[@]}"; do
      local dest
      if [[ -n "$dest_override" ]]; then
        dest="$dest_override"
      else
        dest="$(resolve_tool_path "$tool")"
      fi
      mkdir -p "$dest"
      ensure_lock_source "$dest"
      migrate_legacy_backups "$dest"

      printf '[%s] -> %s\n' "$tool" "$dest"
      for skill in "${skills[@]}"; do
        if ! validate_skill_name "$skill"; then
          printf '  [!] Invalid skill name: %s\n' "$skill"
          (( failed++ )) || true
          continue
        fi
        if [[ ! -d "$SKILLS_SRC/$skill" ]]; then
          printf '  [!] Unknown skill: %s\n' "$skill"
          (( failed++ )) || true
          continue
        fi
        if is_deprecated "$SKILLS_SRC/$skill"; then
          local replacement="${MIGRATION_REPLACEMENTS[$skill]:-}"
          if [[ -n "$replacement" ]]; then
            printf '  [!] %s is deprecated; use %s\n' "$skill" "$replacement"
          else
            printf '  [!] %s is deprecated and scheduled for removal\n' "$skill"
          fi
        fi
        install_copy "$skill" "$dest" "$force" "$no_backup" || (( failed++ )) || true
      done

      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${skills[@]}"
      fi

      write_lock "$dest" "${skills[@]}"
      [[ -n "$dest_override" ]] || legacy_cleanup_hint "$tool"
      printf '\n'
    done

    if (( failed > 0 )); then
      printf 'Done with %d error(s).\n' "$failed"
      exit 1
    else
      printf 'Done. Skills installed for %s.\n' "${tools[*]}"
    fi
  fi
}

main "$@"
