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
  --verbose           With --doctor, list each overlap the harness resolves
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

# Source digests are computed once per run and shared by staging checks and locks.
declare -A SOURCE_DIGESTS=()

cache_source_digest() {
  [[ -n "${SOURCE_DIGESTS[$1]:-}" ]] && return 0
  SOURCE_DIGESTS[$1]="$(skill_hash "$SKILLS_SRC/$1")" && [[ -n "${SOURCE_DIGESTS[$1]}" ]]
}

# ── Internal skill detection ──────────────────────────────────────────
# Frontmatter is parsed once per run; per-skill python forks made installs slow.
declare -A SKILL_INTERNAL=()
declare -A SKILL_DEPRECATED=()

load_skill_metadata() {
  local rows line dir
  rows="$(python3 "$FRONTMATTER_PY" batch "$SKILLS_SRC")" || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    dir="${line%%$'\t'*}"
    SKILL_DEPRECATED[$dir]="${line##*$'\t'}"
    line="${line%$'\t'*}"
    SKILL_INTERNAL[$dir]="${line##*$'\t'}"
  done <<< "$rows"
}

is_internal() {
  local skill_dir="${1%/}"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  [[ "${SKILL_INTERNAL[${skill_dir##*/}]:-}" == "true" ]]
}

is_deprecated() {
  local skill_dir="${1%/}"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  [[ "${SKILL_DEPRECATED[${skill_dir##*/}]:-}" == "true" ]]
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
  mkdir -p "$dest" || return 1

  if [[ -L "$dest_dir/$skill" ]]; then
    cp -P "$dest_dir/$skill" "$dest/" || return 1
  else
    cp -r "$dest_dir/$skill/." "$dest/" || return 1
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

# Skills whose lock records the last successful write_lock published.
LOCK_PUBLISHED=()

write_lock() {
  local lock_dir="$1"
  shift
  local skills=("$@")
  local lock_file="$lock_dir/.skills-lock.json"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  LOCK_PUBLISHED=()

  local updates=() published=()
  for skill in "${skills[@]}"; do
    local target="$lock_dir/$skill"
    [[ -L "$target" ]] && target="$(readlink -f "$target" 2>/dev/null || true)"
    [[ -d "$target" ]] || continue
    local source_target="$SKILLS_SRC/$skill"
    [[ -d "$source_target" ]] || continue
    local target_hash
    target_hash="$(skill_hash "$target")"
    cache_source_digest "$skill" || continue
    [[ -n "$target_hash" && "$target_hash" == "${SOURCE_DIGESTS[$skill]}" ]] || continue
    updates+=("$skill=$target_hash")
    published+=("$skill")
  done

  python3 - "$lock_file" "$SKILLS_SRC" "$now" "${updates[@]}" <<'PY' || return 1
import json
import os
import pathlib
import re
import sys
import tempfile

lock_path = pathlib.Path(sys.argv[1])
source = pathlib.Path(sys.argv[2]).resolve(strict=True)
updated_at = sys.argv[3]
name = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
skills = {}
existing = None
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
skills = dict(sorted(skills.items()))
if existing is not None and existing.get("source") == str(source) and existing["skills"] == skills:
    sys.exit(0)
payload = {
    "version": 1,
    "updated_at": updated_at,
    "source": str(source),
    "skills": skills,
}
# Unique temp name: concurrent runs must not share one.
fd, temp = tempfile.mkstemp(dir=lock_path.parent, prefix=f".{lock_path.name}.", suffix=".tmp")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(json.dumps(payload, indent=2) + "\n")
    mask = os.umask(0)
    os.umask(mask)
    os.chmod(temp, 0o666 & ~mask)
    if "lock" in os.environ.get("SKILLS_INSTALL_FAULT", "").split(","):
        raise OSError("injected fault: lock")
    os.replace(temp, lock_path)
except BaseException as error:
    try:
        os.unlink(temp)
    except OSError:
        pass
    raise SystemExit(f"Could not write {lock_path}: {error}")
PY
  LOCK_PUBLISHED=("${published[@]}")
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

# ── Installer lock ────────────────────────────────────────────────────
# Runs that change files hold an exclusive flock on fd 9 until the process
# exits; an exec'd child inherits the descriptor and with it the lock.
INSTALL_LOCK_FD=9

acquire_install_lock() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/iuliandita-skills" wait="${SKILLS_LOCK_WAIT:-30}"
  if ! command -v flock >/dev/null 2>&1; then
    printf '[!] flock not found; concurrent installer runs are not excluded\n' >&2
    return 0
  fi
  if [[ ! "$wait" =~ ^[0-9]+$ ]]; then
    printf 'SKILLS_LOCK_WAIT must be a whole number of seconds: %s\n' "$wait" >&2
    exit 1
  fi
  if ! mkdir -p "$dir" || ! chmod 700 "$dir" || ! exec 9>>"$dir/install.lock"; then
    printf 'Cannot open the installer lock in %s\n' "$dir" >&2
    exit 1
  fi
  if ! flock -w "$wait" "$INSTALL_LOCK_FD"; then
    printf 'Another install.sh run holds %s; gave up after %ss (set SKILLS_LOCK_WAIT to wait longer)\n' \
      "$dir/install.lock" "$wait" >&2
    exit 3
  fi
}

# ── Replacement transactions ──────────────────────────────────────────
# Each replacement of <dest>/<skill> runs under
# <dest parent>/.skills-txn/<dest name>/<skill>/ holding `record`, `staging`
# (the new entry) and `prev` (the old entry moved aside). The area sits outside
# the discovery root and must be on the destination's filesystem: every move is
# a rename, never a copy. The record is key=value lines (phase, and before any
# move the staged digest); unknown keys survive updates. A record found when a
# new attempt starts is kept as `record.prior` and put back if the attempt does
# not land. Records are removed only after the skill's lock record is published,
# or when a rollback leaves nothing an earlier attempt wrote.
#
# Return codes of replace_entry and recover_dest: 0 ok, 1 failed and rolled
# back, 2 unresolved: evidence is kept and the caller stops using that
# destination for the rest of the run.

# Test-only fault injection. SKILLS_INSTALL_FAULT is a comma list of
# stage|backup|promote|record|cleanup|restore|rollback|lock|opencode|xdev, each
# optionally suffixed with :<skill>, that makes that step fail.
fault_hit() {
  local point="$1" skill="${2:-}" item
  local -a items=()
  [[ -n "${SKILLS_INSTALL_FAULT:-}" ]] || return 1
  IFS=',' read -ra items <<< "$SKILLS_INSTALL_FAULT"
  for item in "${items[@]}"; do
    if [[ "$item" == "$point" || ( -n "$skill" && "$item" == "$point:$skill" ) ]]; then
      printf '  [!] injected fault: %s\n' "$item" >&2
      return 0
    fi
  done
  return 1
}

present() {
  [[ -e "$1" || -L "$1" ]]
}

MV_NO_COPY=""

# Rename only: a move across filesystems must fail, not become copy and delete.
rename_path() {
  if [[ -z "$MV_NO_COPY" ]]; then
    MV_NO_COPY=no
    mv --help 2>/dev/null | grep -q -- '--no-copy' && MV_NO_COPY=yes
  fi
  if [[ "$MV_NO_COPY" == "yes" ]]; then
    mv --no-copy -T -- "$1" "$2"
  else
    python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$1" "$2"
  fi
}

declare -A TXN_ROOTS=()
TXN_ROOT=""

# Set TXN_ROOT for a destination; cached for the run. A destination whose
# transaction area would be on another filesystem (a mount point) is refused.
txn_root() {
  local dest_abs root
  if [[ -z "${TXN_ROOTS[$1]:-}" ]]; then
    dest_abs="$(cd "$1" && pwd -P)" || { printf '  [!] cannot resolve %s\n' "$1"; return 1; }
    root="${dest_abs%/*}/.skills-txn/${dest_abs##*/}"
    if fault_hit xdev || ! python3 - "$dest_abs" "$root" <<'PY'
import os
import sys

dest, path = sys.argv[1], sys.argv[2]
while not os.path.exists(path):
    path = os.path.dirname(path)
sys.exit(0 if os.stat(path).st_dev == os.stat(dest).st_dev else 1)
PY
    then
      printf '  [!] %s is on a different filesystem than %s; refusing to replace skills there\n' "$root" "$dest_abs"
      return 1
    fi
    TXN_ROOTS[$1]="$root"
  fi
  TXN_ROOT="${TXN_ROOTS[$1]}"
}

txn_write() {
  local record="$1" tmp="$1.$$"
  shift
  if printf '%s\n' "$@" > "$tmp" && mv -f "$tmp" "$record"; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

txn_field() {
  local key value
  while IFS='=' read -r key value; do
    if [[ "$key" == "$2" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done < "$1"
  return 1
}

# Set key=value fields in a record, keeping every other line.
txn_set() {
  local record="$1" line pair done_keys=" "
  local -a lines=() out=()
  shift
  mapfile -t lines < "$record" || return 1
  for line in "${lines[@]}"; do
    for pair in "$@"; do
      if [[ "${line%%=*}" == "${pair%%=*}" ]]; then
        line="$pair"
        done_keys+="${pair%%=*} "
      fi
    done
    out+=("$line")
  done
  for pair in "$@"; do
    [[ "$done_keys" == *" ${pair%%=*} "* ]] || out+=("$pair")
  done
  txn_write "$record" "${out[@]}"
}

entry_digest() {
  if [[ -L "$1" ]]; then
    printf 'link:%s\n' "$(readlink "$1")"
  else
    skill_hash "$1"
  fi
}

txn_finalize() {
  local root txn
  txn_root "$1" || return 1
  root="$TXN_ROOT"
  txn="$root/$2"
  present "$txn" || return 0
  rm -rf "$txn/prev" "$txn/staging" && rm -f "$txn/record" "$txn/record.prior" && rm -rf "$txn" || return 1
  rmdir "$root" "${root%/*}" 2>/dev/null || true
}

STAGED_DIGEST=""

stage_entry() {
  local kind="$1" skill="$2" stage="$3"
  STAGED_DIGEST=""
  if [[ "$kind" == "link" ]]; then
    ln -s "$CANONICAL_DIR/$skill" "$stage" && ! fault_hit stage "$skill" \
      && [[ "$(readlink "$stage")" == "$CANONICAL_DIR/$skill" ]] || return 1
    STAGED_DIGEST="link:$CANONICAL_DIR/$skill"
    return 0
  fi
  mkdir "$stage" && ! fault_hit stage "$skill" && cp -r "$SKILLS_SRC/$skill/." "$stage/" || return 1
  STAGED_DIGEST="$(skill_hash "$stage")" || return 1
  cache_source_digest "$skill" || return 1
  [[ -n "$STAGED_DIGEST" && "$STAGED_DIGEST" == "${SOURCE_DIGESTS[$skill]}" ]]
}

# Put back what an attempt displaced: the previous entry, then an earlier record.
txn_rollback() {
  local skill="$1" work="$2" txn="$3"
  # Mark the rollback first: recovery must then treat the working copy as the old one.
  if [[ -f "$txn/record" ]] && ! txn_set "$txn/record" phase=rollingback; then
    printf '  [!] %s: could not mark record %s for rollback; left everything in place\n' "$skill" "$txn/record"
    return 2
  fi
  if present "$txn/prev"; then
    if present "$work"; then
      printf '  [!] %s: both %s and %s exist; kept both and the record\n' "$skill" "$work" "$txn/prev"
      return 2
    fi
    if fault_hit restore "$skill" || ! rename_path "$txn/prev" "$work"; then
      printf '  [!] %s: could not restore the previous copy; kept it at %s with record %s\n' \
        "$skill" "$txn/prev" "$txn/record"
      return 2
    fi
    printf '  [<] %s previous copy restored\n' "$skill"
  fi
  if present "$txn/staging" && ! rm -rf "$txn/staging"; then
    printf '  [!] %s: could not remove staging %s; kept record %s\n' "$skill" "$txn/staging" "$txn/record"
    return 2
  fi
  if fault_hit rollback "$skill"; then
    printf '  [!] %s: rollback interrupted; rerun the installer to finish it\n' "$skill"
    return 2
  fi
  if [[ -f "$txn/record.prior" ]]; then
    if ! rename_path "$txn/record.prior" "$txn/record"; then
      printf '  [!] %s: could not put back the earlier record %s\n' "$skill" "$txn/record.prior"
      return 2
    fi
    return 1
  fi
  rm -rf "$txn" || printf '  [!] %s: could not remove record %s\n' "$skill" "$txn/record"
  rmdir "${txn%/*}" "${txn%/*/*}" 2>/dev/null || true
  return 1
}

# Stage the new entry, move the old one aside, rename the new one into place.
replace_entry() {
  local kind="$1" skill="$2" dest="$3" backup="$4"
  local work="$dest/$skill" txn
  txn_root "$dest" || return 2
  txn="$TXN_ROOT/$skill"

  if present "$txn/staging" || present "$txn/prev"; then
    printf '  [!] %s: %s holds an unfinished replacement; rerun the installer to recover it\n' "$skill" "$txn"
    return 2
  fi
  if ! mkdir -p "$txn"; then
    printf '  [!] %s: could not create %s\n' "$skill" "$txn"
    return 1
  fi
  if [[ -f "$txn/record" ]] && ! rename_path "$txn/record" "$txn/record.prior"; then
    printf '  [!] %s: could not set aside the earlier record in %s\n' "$skill" "$txn"
    return 1
  fi
  if ! txn_write "$txn/record" version=1 "skill=$skill" "target=$work" \
    "staging=$txn/staging" "backup=$txn/prev" phase=staging; then
    printf '  [!] %s: could not write install record in %s\n' "$skill" "$txn"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi

  if ! stage_entry "$kind" "$skill" "$txn/staging"; then
    printf '  [!] %s: staging failed; existing install left in place\n' "$skill"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi
  if present "$work" && [[ "$backup" == "true" ]]; then
    if ! backup_skill "$skill" "$dest"; then
      printf '  [!] %s: backup failed; existing install left in place\n' "$skill"
      txn_rollback "$skill" "$work" "$txn"
      return
    fi
    printf '  [>] %s backed up\n' "$skill"
  fi
  local previous=""
  if present "$work" && ! previous="$(entry_digest "$work")"; then
    printf '  [!] %s: could not hash the existing install\n' "$skill"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi
  if ! txn_set "$txn/record" phase=swapping "staged=$STAGED_DIGEST" "previous=$previous"; then
    printf '  [!] %s: could not update record %s\n' "$skill" "$txn/record"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi
  if present "$work" && { fault_hit backup "$skill" || ! rename_path "$work" "$txn/prev"; }; then
    printf '  [!] %s: could not move the existing install aside\n' "$skill"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi
  if present "$work" || fault_hit promote "$skill" || ! rename_path "$txn/staging" "$work"; then
    printf '  [!] %s: could not move the new copy into place\n' "$skill"
    txn_rollback "$skill" "$work" "$txn"
    return
  fi
  if fault_hit record "$skill" || ! txn_set "$txn/record" phase=promoted; then
    printf '  [!] %s: new copy is in place, but record %s could not be updated; rerun to reconcile\n' "$skill" "$txn/record"
    return 2
  fi
  if present "$txn/prev" && { fault_hit cleanup "$skill" || ! rm -rf "$txn/prev"; }; then
    printf '  [!] %s: new copy is in place, but %s could not be removed; rerun to reconcile\n' "$skill" "$txn/prev"
    return 2
  fi
  return 0
}

# Settle one transaction folder. Sets RECOVERY_NOTE; returns 0 or 2.
RECOVERY_NOTE=""

note() {
  RECOVERY_NOTE="${RECOVERY_NOTE:+$RECOVERY_NOTE, }$1"
}

prev_verified() {
  present "$1" && [[ -n "$2" && "$(entry_digest "$1")" == "$2" ]]
}

# Move a verified previous copy back to a missing working path.
recover_prev() {
  local skill="$1" work="$2" entry="$3" previous="$4"
  present "$entry/prev" || return 0
  if present "$work"; then
    printf '  [!] %s: both %s and %s exist; left in place\n' "$skill" "$work" "$entry/prev"
    return 1
  fi
  if ! prev_verified "$entry/prev" "$previous"; then
    printf '  [!] %s: %s does not match the digest recorded before it was moved; left in place\n' "$skill" "$entry/prev"
    return 1
  fi
  if fault_hit restore "$skill" || ! rename_path "$entry/prev" "$work"; then
    printf '  [!] %s: could not restore %s; kept it with record %s\n' "$skill" "$entry/prev" "$entry/record"
    return 1
  fi
  note "restored the previous copy"
}

recover_entry() {
  local skill="$1" work="$2" entry="$3" phase staged previous rolled_back=false verified=false
  local record="$entry/record"
  RECOVERY_NOTE=""

  if [[ ! -f "$record" ]]; then
    if [[ -f "$entry/record.prior" ]]; then
      rename_path "$entry/record.prior" "$record" || { printf '  [!] %s: could not put back %s\n' "$skill" "$entry/record.prior"; return 2; }
      note "put back the earlier record"
    elif present "$entry/prev"; then
      printf '  [!] %s: %s has no record; left in place\n' "$skill" "$entry/prev"
      return 2
    else
      rm -rf "$entry" || { printf '  [!] %s: could not remove %s\n' "$skill" "$entry"; return 2; }
      return 0
    fi
  fi
  if [[ "$(txn_field "$record" skill)" != "$skill" ]]; then
    printf '  [!] %s: record %s names another skill; left in place\n' "$skill" "$record"
    return 2
  fi
  phase="$(txn_field "$record" phase)" || phase=""
  staged="$(txn_field "$record" staged)" || staged=""
  previous="$(txn_field "$record" previous)" || previous=""

  case "$phase" in
    staging)
      # Nothing was moved yet; the working copy is the original.
      rolled_back=true
      ;;
    swapping)
      if present "$work" && ! present "$entry/staging"; then
        # The promotion rename ran; keep its result only if it is what was staged.
        if [[ -n "$staged" && "$(entry_digest "$work")" == "$staged" ]]; then
          verified=true
        elif ! prev_verified "$entry/prev" "$previous"; then
          printf '  [!] %s: %s does not match the staged copy and no verified previous copy can replace it; left in place\n' \
            "$skill" "$work"
          return 2
        elif ! rename_path "$work" "$entry/staging"; then
          printf '  [!] %s: %s does not match the staged copy and could not be moved aside\n' "$skill" "$work"
          return 2
        else
          note "moved an unverified copy aside"
        fi
      fi
      if [[ "$verified" != "true" ]]; then
        rolled_back=true
        recover_prev "$skill" "$work" "$entry" "$previous" || return 2
      fi
      ;;
    rollingback)
      # The working copy, if present, is the restored previous copy: keep it.
      rolled_back=true
      recover_prev "$skill" "$work" "$entry" "$previous" || return 2
      note "finished an interrupted rollback"
      ;;
    promoted|recovered)
      ;;
    *)
      printf '  [!] %s: record %s has unknown phase %s; left in place\n' "$skill" "$record" "$phase"
      return 2
      ;;
  esac

  if present "$entry/staging"; then
    rm -rf "$entry/staging" || { printf '  [!] %s: could not remove %s; kept record %s\n' "$skill" "$entry/staging" "$record"; return 2; }
    note "removed leftover staging"
  fi
  if present "$entry/prev"; then
    # Only a finished promotion may drop the replaced copy.
    if [[ "$verified" != "true" && "$phase" != "promoted" ]] || ! present "$work"; then
      printf '  [!] %s: %s is still needed; left in place\n' "$skill" "$entry/prev"
      return 2
    fi
    if fault_hit cleanup "$skill" || ! rm -rf "$entry/prev"; then
      printf '  [!] %s: could not remove %s; kept record %s\n' "$skill" "$entry/prev" "$record"
      return 2
    fi
    note "removed the replaced copy"
  fi

  if [[ "$rolled_back" == "true" && -f "$entry/record.prior" ]]; then
    rename_path "$entry/record.prior" "$record" || { printf '  [!] %s: could not put back %s\n' "$skill" "$entry/record.prior"; return 2; }
    note "put back the earlier record"
  elif [[ "$rolled_back" == "true" ]]; then
    txn_set "$record" phase=recovered || { printf '  [!] %s: could not update %s\n' "$skill" "$record"; return 2; }
  elif [[ "$verified" == "true" ]]; then
    txn_set "$record" phase=promoted || { printf '  [!] %s: could not update %s\n' "$skill" "$record"; return 2; }
    note "confirmed the new copy"
  fi
  return 0
}

# Settle interrupted or failed replacements left under a destination.
recover_dest() {
  local dest="$1" root entry skill
  txn_root "$dest" || return 2
  root="$TXN_ROOT"
  [[ -d "$root" ]] || return 0
  for entry in "$root"/*; do
    [[ -d "$entry" && ! -L "$entry" ]] || continue
    skill="${entry##*/}"
    if ! validate_skill_name "$skill"; then
      printf '  [!] unexpected entry %s left in place\n' "$entry"
      continue
    fi
    recover_entry "$skill" "$dest/$skill" "$entry" || return 2
    present "$entry" || continue
    if [[ -n "$RECOVERY_NOTE" ]]; then
      printf '  [r] %s: %s\n' "$skill" "$RECOVERY_NOTE"
    else
      printf '  [r] %s: install record kept until its lock entry is published\n' "$skill"
    fi
  done
  return 0
}

# Before a migration changes a destination: recover it, and refuse while a
# skill the migration would touch still has an install record.
guard_migration_dest() {
  local dest="$1" entry skill old
  [[ -d "$dest" ]] || return 0
  if ! recover_dest "$dest"; then
    printf '  [!] refusing to migrate %s until its install records are recovered\n' "$dest"
    return 1
  fi
  for entry in "$TXN_ROOT"/*; do
    [[ -f "$entry/record" ]] || continue
    skill="${entry##*/}"
    for old in "${!MIGRATION_ACTIONS[@]}"; do
      if [[ "$skill" == "$old" || "$skill" == "${MIGRATION_REPLACEMENTS[$old]}" ]]; then
        printf '  [!] refusing to migrate %s: %s has an unpublished install record in %s; reinstall it with --force first\n' \
          "$dest" "$skill" "$entry"
        return 1
      fi
    done
  done
}

# Write the lock, then drop the records of skills it published.
publish_lock() {
  local dest="$1" skill status=0
  shift
  if ! write_lock "$dest" "$@"; then
    printf '  [!] could not write %s/.skills-lock.json; install records kept for the next run\n' "$dest"
    return 1
  fi
  for skill in "${LOCK_PUBLISHED[@]}"; do
    if ! txn_finalize "$dest" "$skill"; then
      printf '  [!] %s: could not remove its install record\n' "$skill"
      status=1
    fi
  done
  return "$status"
}

install_copy() {
  local skill="$1" dest_dir="$2" force="$3" no_backup="$4" backup=true

  if present "$dest_dir/$skill"; then
    if [[ "$force" != "true" ]]; then
      printf '  [~] %s already exists (use --force to overwrite)\n' "$skill"
      return 0
    fi
  fi
  [[ "$no_backup" != "true" ]] || backup=false
  replace_entry copy "$skill" "$dest_dir" "$backup" || return
  printf '  [+] %s installed\n' "$skill"
}

create_link() {
  local skill="$1" tool_dir="$2" force="$3" no_backup="$4" backup=false
  local work="$tool_dir/$skill"

  if [[ -L "$work" ]]; then
    if [[ "$(readlink "$work")" == "$CANONICAL_DIR/$skill" ]]; then
      printf '  [=] %s already linked\n' "$skill"
      return 0
    fi
    replace_entry link "$skill" "$tool_dir" false || return
    printf '  [+] %s relinked\n' "$skill"
    return 0
  fi
  if [[ -e "$work" ]]; then
    # Real directory from a previous copy install
    if [[ "$force" != "true" ]]; then
      printf '  [~] %s exists as copy (use --force to convert to symlink)\n' "$skill"
      return 0
    fi
    [[ "$no_backup" == "true" ]] || backup=true
  fi
  replace_entry link "$skill" "$tool_dir" "$backup" || return
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
    printf '  [!] OpenCode permission sync failed: python3 not found\n'
    return 1
  fi

  if ! mkdir -p "$(dirname "$config_file")"; then
    printf '  [!] OpenCode permission sync failed: cannot create %s\n' "$(dirname "$config_file")"
    return 1
  fi

  if ! python3 - "$config_file" "${synced_skills[@]}" <<'PY'
import json
import os
import sys
import tempfile

# Write through a symlinked config (dotfile managers) instead of replacing the link.
config_path = os.path.realpath(sys.argv[1])
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
    if os.path.exists(config_path):
        mode = os.stat(config_path).st_mode & 0o7777
    else:
        mask = os.umask(0)
        os.umask(mask)
        mode = 0o666 & ~mask
    fd, temp = tempfile.mkstemp(dir=os.path.dirname(config_path), prefix=".opencode.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
            f.write("\n")
        os.chmod(temp, mode)
        if "opencode" in os.environ.get("SKILLS_INSTALL_FAULT", "").split(","):
            print("  [!] injected fault: opencode", file=sys.stderr)
            raise OSError("injected fault")
        os.replace(temp, config_path)
    except BaseException:
        try:
            os.unlink(temp)
        except OSError:
            pass
        raise
PY
  then
    printf '  [!] OpenCode permission sync failed: could not update %s; it was left unchanged\n' "$config_file"
    return 1
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

# Install skills into one destination after settling leftover records. Sets
# INSTALLED to the skills now in place (new or kept) and counts failures in
# INSTALL_FAILURES. A failed rollback or recovery stops that destination only.
INSTALLED=()
INSTALL_FAILURES=0

install_into() {
  local kind="$1" dest="$2" force="$3" no_backup="$4" skill replacement rc stopped=false
  shift 4
  INSTALLED=()
  if ! recover_dest "$dest"; then
    stopped=true
    (( INSTALL_FAILURES++ )) || true
  fi
  for skill in "$@"; do
    if ! validate_skill_name "$skill"; then
      printf '  [!] Invalid skill name: %s\n' "$skill"
      (( INSTALL_FAILURES++ )) || true
      continue
    fi
    if [[ ! -d "$SKILLS_SRC/$skill" ]]; then
      printf '  [!] Unknown skill: %s\n' "$skill"
      (( INSTALL_FAILURES++ )) || true
      continue
    fi
    if [[ "$stopped" == "true" ]]; then
      printf '  [!] %s not attempted: %s needs recovery first\n' "$skill" "$dest"
      (( INSTALL_FAILURES++ )) || true
      continue
    fi
    if [[ "$kind" == "copy" ]] && is_deprecated "$SKILLS_SRC/$skill"; then
      replacement="${MIGRATION_REPLACEMENTS[$skill]:-}"
      if [[ -n "$replacement" ]]; then
        printf '  [!] %s is deprecated; use %s\n' "$skill" "$replacement"
      else
        printf '  [!] %s is deprecated and scheduled for removal\n' "$skill"
      fi
    fi
    rc=0
    if [[ "$kind" == "link" ]]; then
      create_link "$skill" "$dest" "$force" "$no_backup" || rc=$?
    else
      install_copy "$skill" "$dest" "$force" "$no_backup" || rc=$?
    fi
    case "$rc" in
      0) INSTALLED+=("$skill") ;;
      2) stopped=true; (( INSTALL_FAILURES++ )) || true ;;
      *) (( INSTALL_FAILURES++ )) || true ;;
    esac
  done
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
  local verbose="$1" tool row rows=()
  shift
  for tool in "$@"; do
    for row in "${DOCTOR_ROOTS[@]}"; do
      [[ "${row%%|*}" == "$tool" ]] && rows+=("$row")
    done
  done
  python3 - "$verbose" "$(IFS=,; printf '%s' "$*")" "${rows[@]}" <<'PY'
from pathlib import Path
import os
import re
import sys

verbose = sys.argv[1] == "true"
tools = sys.argv[2].split(",")
table = [row.split("|", 3) for row in sys.argv[3:]]


YAML_ESCAPES = {"0": "\0", "a": "\a", "b": "\b", "t": "\t", "\t": "\t", "n": "\n",
                "v": "\v", "f": "\f", "r": "\r", "e": "\x1b", " ": " ", '"': '"',
                "/": "/", "\\": "\\", "N": "\x85", "_": "\xa0", "L": "\u2028",
                "P": "\u2029"}
HEX_LEN = {"x": 2, "u": 4, "U": 8}


def yaml_unescape(body):
    out, i = [], 0
    while i < len(body):
        ch = body[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        code = body[i + 1]
        if code in HEX_LEN:
            digits = body[i + 2:i + 2 + HEX_LEN[code]]
            if len(digits) != HEX_LEN[code] or not re.fullmatch(r"[0-9A-Fa-f]+", digits):
                return None
            point = int(digits, 16)
            if point > 0x10FFFF or 0xD800 <= point <= 0xDFFF:
                return None
            out.append(chr(point))
            i += 2 + HEX_LEN[code]
        elif code in YAML_ESCAPES:
            out.append(YAML_ESCAPES[code])
            i += 2
        else:
            return None
    return "".join(out)


def yaml_scalar(raw):
    raw = raw.strip()
    if raw[:1] == "'":
        match = re.match(r"'((?:[^']|'')*)'\s*(?:#.*)?$", raw)
        return match.group(1).replace("''", "'") if match else None
    if raw[:1] == '"':
        match = re.match(r'"((?:[^"\\]|\\.)*)"\s*(?:#.*)?$', raw)
        return yaml_unescape(match.group(1)) if match else None
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


HOME = os.environ.get("HOME", "")


def tilde(path):
    return "~" + path[len(HOME):] if HOME and path.startswith(HOME + "/") else path


def merge(findings):
    # A dir and a name finding describe one skill only when both the identifier
    # and the full set of paths match; anything else keeps its label.
    by_key = {}
    for kind, ident, where in findings:
        by_key.setdefault((ident, tuple(sorted(where.items()))), []).append((kind, ident, where))
    merged = []
    for group in by_key.values():
        if len(group) == 2:
            merged.append((group[0][1], group[0][2]))
        else:
            merged.extend((f"{kind} {ident}", where) for kind, ident, where in group)
    return sorted(merged, key=lambda item: (item[0], sorted(item[1].values())))


print("Checking the static root table; harness config toggles are not read.")
blocking = 0
blocking_tools = 0
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
    hard, soft = [], {}
    for key in sorted(found):
        where = found[key]
        if len(where) < 2:
            continue
        groups = {roots[index][1] for index in where}
        if len(groups) == 1 and "" not in groups:
            soft.setdefault(tuple(sorted(where)), []).append((*key, where))
        else:
            hard.append((*key, where))
    if not hard and not soft:
        print("  no duplicates")
        continue
    hard = merge(hard)
    if hard:
        blocking += len(hard)
        blocking_tools += 1
    for label, where in hard:
        print(f"  [!] {label}: {', '.join(where[index] for index in sorted(where))}")
    for indexes in sorted(soft):
        items = merge(soft[indexes])
        where = ", ".join(tilde(roots[index][0]) for index in indexes)
        print(f"  [i] {len(items)} finding(s) across {where}; {tool} resolves these")
        if verbose:
            line = ""
            for label, _ in items:
                if line and len(line) + len(label) > 90:
                    print(f"      {line},")
                    line = ""
                line += f", {label}" if line else label
            print(f"      {line}")

print()
if blocking:
    print(f"{blocking} blocking finding(s) across {blocking_tools} tool(s).")
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
  local doctor_mode=false doctor_verbose=false
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
      --verbose)          doctor_verbose=true ;;
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

  load_skill_metadata || { printf '%s\n' "Cannot continue with invalid skill frontmatter" >&2; exit 1; }
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
  if [[ "$doctor_verbose" == "true" && "$doctor_mode" != "true" ]]; then
    printf '%s\n' "--verbose requires --doctor" >&2; exit 1
  fi
  if [[ "$doctor_mode" == "true" ]]; then
    if [[ "$link_mode$show_list$check_mode$migrate_mode$apply_migration$force$no_backup$include_internal" == *true* \
      || -n "$dest_override" || "$requested_skill_count" -gt 0 ]]; then
      printf '%s\n' "--doctor is read-only and accepts only --tool and --verbose" >&2; exit 1
    fi
    run_doctor "$doctor_verbose" "${tools[@]}"
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

  if [[ "$migrate_mode" != "true" || "$apply_migration" == "true" ]]; then
    acquire_install_lock
  fi

  # ── Migration ──────────────────────────────────────────────────────
  if [[ "$migrate_mode" == "true" ]]; then
    command -v python3 >/dev/null || { printf '%s\n' "Migration requires python3" >&2; exit 1; }
    [[ -f "$MIGRATOR" ]] || { printf 'Migration helper is unavailable: %s\n' "$MIGRATOR" >&2; exit 1; }
    local migration_args=(--manifest "$MIGRATIONS_FILE" --source "$SKILLS_SRC") sync_failed=0 refused=0
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
      if [[ "$apply_migration" == "true" ]] && ! guard_migration_dest "$CANONICAL_DIR"; then
        refused=1
      else
        python3 "$MIGRATOR" "${migration_args[@]}" --dest "$CANONICAL_DIR" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$CANONICAL_DIR")/.skills-backups/$(basename "$CANONICAL_DIR")}" --protected-root "$CANONICAL_DIR" --preserve-shared-canonical "${canonical_args[@]}"
      fi
      if [[ -n "$canonical_applied" && "$refused" == 0 ]]; then
        sync_migrated_opencode_permissions "$CANONICAL_DIR" "$canonical_applied" || sync_failed=1
      fi
      [[ -z "$canonical_applied" ]] || rm -f "$canonical_applied"
      local -A migrated_destinations=()
      for tool in "${tools[@]}"; do
        local tool_dir
        tool_dir="$(resolve_tool_path "$tool")"
        paths_match "$tool_dir" "$CANONICAL_DIR" && continue
        [[ -n "${migrated_destinations[$tool_dir]:-}" ]] && continue
        migrated_destinations["$tool_dir"]=true
        if [[ "$apply_migration" == "true" ]] && ! guard_migration_dest "$tool_dir"; then
          refused=1
          continue
        fi
        local applied_file=""
        local applied_args=()
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          applied_file="$(mktemp)"
          applied_args=(--applied-file "$applied_file")
        fi
        python3 "$MIGRATOR" "${migration_args[@]}" --dest "$tool_dir" --backup-dir "${SKILLS_BACKUP_DIR:-$(dirname "$tool_dir")/.skills-backups/$(basename "$tool_dir")}" --protected-root "$CANONICAL_DIR" --link-root "$CANONICAL_DIR" "${applied_args[@]}"
        if [[ "$apply_migration" == "true" && "$tool" == "opencode" ]]; then
          sync_migrated_opencode_permissions "$tool_dir" "$applied_file" || sync_failed=1
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
        if [[ "$apply_migration" == "true" ]] && ! guard_migration_dest "$tool_dir"; then
          refused=1
          continue
        fi
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
          sync_migrated_opencode_permissions "$tool_dir" "$applied_file" || sync_failed=1
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
    (( sync_failed == 0 && refused == 0 )) || exit 1
    exit 0
  fi

  # ── Install: link mode ──────────────────────────────────────────────
  local failed=0
  if [[ "$link_mode" == "true" ]]; then
    printf 'Installing %d skill(s) via symlink\n' "${#skills[@]}"
    printf 'Canonical: %s\n\n' "$CANONICAL_DIR"
    mkdir -p "$CANONICAL_DIR"
    ensure_lock_source "$CANONICAL_DIR"
    migrate_legacy_backups "$CANONICAL_DIR"

    # Copy all skills to canonical dir first
    install_into copy "$CANONICAL_DIR" "$force" "$no_backup" "${skills[@]}"
    local canonical_ok=("${INSTALLED[@]}")

    # Create symlinks per tool
    for tool in "${tools[@]}"; do
      local tool_dir linked=()
      tool_dir="$(resolve_tool_path "$tool")"
      if [[ "$tool_dir" == "$CANONICAL_DIR" ]]; then
        printf '[%s] -> %s (matches canonical, skipping links)\n' "$tool" "$tool_dir"
        linked=("${canonical_ok[@]}")
      else
        mkdir -p "$tool_dir"
        ensure_lock_source "$tool_dir"
        migrate_legacy_backups "$tool_dir"
        printf '[%s] -> %s\n' "$tool" "$tool_dir"
        install_into link "$tool_dir" "$force" "$no_backup" "${canonical_ok[@]}"
        linked=("${INSTALLED[@]}")
        publish_lock "$tool_dir" "${linked[@]}" || (( failed++ )) || true
      fi
      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${linked[@]}" || (( failed++ )) || true
      fi
      legacy_cleanup_hint "$tool"
      printf '\n'
    done

    publish_lock "$CANONICAL_DIR" "${canonical_ok[@]}" || (( failed++ )) || true
    (( failed += INSTALL_FAILURES )) || true

    if (( failed > 0 )); then
      printf 'Done with %d error(s).\n' "$failed"
      exit 1
    fi
    printf 'Done. %d skills linked for %s.\n' "${#skills[@]}" "${tools[*]}"

  # ── Install: copy mode ──────────────────────────────────────────────
  else
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
      install_into copy "$dest" "$force" "$no_backup" "${skills[@]}"

      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${INSTALLED[@]}" || (( failed++ )) || true
      fi

      publish_lock "$dest" "${INSTALLED[@]}" || (( failed++ )) || true
      [[ -n "$dest_override" ]] || legacy_cleanup_hint "$tool"
      printf '\n'
    done
    (( failed += INSTALL_FAILURES )) || true

    if (( failed > 0 )); then
      printf 'Done with %d error(s).\n' "$failed"
      exit 1
    else
      printf 'Done. Skills installed for %s.\n' "${tools[*]}"
    fi
  fi
}

main "$@"
