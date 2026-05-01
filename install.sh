#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/skill-lib.sh
source "$SCRIPT_DIR/scripts/skill-lib.sh"

SKILLS_SRC="$SCRIPT_DIR/skills"
CANONICAL_DIR="${SKILLS_CANONICAL_DIR:-$HOME/.agents/skills}"

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
  claude codex cursor windsurf opencode
  copilot gemini roo goose amp continue kiro cline warp
  openclaw hermes qwen crush antigravity augment openhands trae qoder kimi
  portable
)

declare -A TOOL_PATHS=(
  [claude]="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  [codex]="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
  [cursor]="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
  [windsurf]="${WINDSURF_SKILLS_DIR:-$HOME/.codeium/windsurf/skills}"
  [opencode]="${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
  [copilot]="${COPILOT_SKILLS_DIR:-$HOME/.copilot/skills}"
  [gemini]="${GEMINI_SKILLS_DIR:-$HOME/.gemini/skills}"
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
  [antigravity]="${ANTIGRAVITY_SKILLS_DIR:-$HOME/.gemini/antigravity/skills}"
  [augment]="${AUGMENT_SKILLS_DIR:-$HOME/.augment/skills}"
  [openhands]="${OPENHANDS_SKILLS_DIR:-$HOME/.openhands/skills}"
  [trae]="${TRAE_SKILLS_DIR:-$HOME/.trae/skills}"
  [qoder]="${QODER_SKILLS_DIR:-$HOME/.qoder/skills}"
  [kimi]="${KIMI_SKILLS_DIR:-$HOME/.config/agents/skills}"
  [portable]="${PORTABLE_SKILLS_DIR:-$HOME/.skills}"
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
  --force             Overwrite existing skills without prompting
  --no-backup         Skip backup of existing skills
  --include-internal  Include skills marked metadata.internal: true
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
  find "$dir" -type f -print0 | sort -z | xargs -0 cat 2>/dev/null | hash_tool
}

# ── Internal skill detection ──────────────────────────────────────────
is_internal() {
  local skill_dir="$1"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  frontmatter_has "$skill_dir/SKILL.md" "metadata.internal" \
    && [[ "$(frontmatter_get "$skill_dir/SKILL.md" "metadata.internal")" == "true" ]]
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
    cp -rL "$dest_dir/$skill/." "$dest/"
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

# ── Lock file ─────────────────────────────────────────────────────────
write_lock() {
  local lock_dir="$1"
  shift
  local skills=("$@")
  local lock_file="$lock_dir/.skills-lock.json"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf '{\n'
    printf '  "version": 1,\n'
    printf '  "updated_at": "%s",\n' "$now"
    printf '  "source": "%s",\n' "$SKILLS_SRC"
    printf '  "skills": {\n'
    local first=true
    for skill in "${skills[@]}"; do
      local target="$lock_dir/$skill"
      [[ -L "$target" ]] && target="$(readlink "$target")"
      [[ -d "$target" ]] || continue
      local h
      h="$(skill_hash "$target")"
      if [[ "$first" == "true" ]]; then
        first=false
      else
        printf ',\n'
      fi
      printf '    "%s": "%s"' "$skill" "$h"
    done
    printf '\n  }\n'
    printf '}\n'
  } > "$lock_file"
}

read_lock_hash() {
  local lock_file="$1" skill="$2"
  [[ -f "$lock_file" ]] || return 0
  sed -n "s/.*\"${skill}\": *\"\\([^\"]*\\)\".*/\\1/p" "$lock_file"
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

  local outdated=0 current=0 missing=0
  for skill in "${ALL_SKILLS[@]}"; do
    [[ -d "$SKILLS_SRC/$skill" ]] || continue

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

  printf '\n%d current, %d outdated, %d not installed\n' "$current" "$outdated" "$missing"
  if (( outdated > 0 || missing > 0 )); then
    exit 1
  fi
}

# ── List mode ─────────────────────────────────────────────────────────
list_skills() {
  local dest_dir="$1"
  printf '\nAvailable skills (%d):\n\n' "${#ALL_SKILLS[@]}"
  for skill in "${ALL_SKILLS[@]}"; do
    if [[ -L "$dest_dir/$skill" ]]; then
      printf '  %-24s [linked]\n' "$skill"
    elif [[ -d "$dest_dir/$skill" ]]; then
      printf '  %-24s [installed]\n' "$skill"
    else
      printf '  %-24s\n' "$skill"
    fi
  done
  printf '\n'
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
  local force=false no_backup=false link_mode=false
  local check_mode=false show_list=false include_internal=false
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
      --force)            force=true ;;
      --no-backup)        no_backup=true ;;
      --include-internal) include_internal=true ;;
      --help|-h)          usage; exit 0 ;;
      -*)                 printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
      *)                  skills+=("$1") ;;
    esac
    shift
  done

  # Default tool
  if (( ${#tools[@]} == 0 )); then
    tools=("${SKILLS_TOOL:-claude}")
  fi

  mapfile -t ALL_SKILLS < <(discover_skills "$include_internal")

  # Validate tool names
  for i in "${!tools[@]}"; do
    tools[i]="$(canonical_tool_name "${tools[i]}")"
    resolve_tool_path "${tools[i]}" > /dev/null
  done

  # Build skill list (filter internal unless --include-internal)
  if (( ${#skills[@]} == 0 )); then
    for skill in "${ALL_SKILLS[@]}"; do
      if [[ "$include_internal" != "true" ]] && is_internal "$SKILLS_SRC/$skill"; then
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

  # ── Install: link mode ──────────────────────────────────────────────
  if [[ "$link_mode" == "true" ]]; then
    printf 'Installing %d skill(s) via symlink\n' "${#skills[@]}"
    printf 'Canonical: %s\n\n' "$CANONICAL_DIR"
    mkdir -p "$CANONICAL_DIR"

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
      install_copy "$skill" "$CANONICAL_DIR" "$force" "$no_backup" || (( failed++ )) || true
    done

    # Create symlinks per tool
    for tool in "${tools[@]}"; do
      local tool_dir
      tool_dir="$(resolve_tool_path "$tool")"
      mkdir -p "$tool_dir"
      printf '[%s] -> %s\n' "$tool" "$tool_dir"
      for skill in "${skills[@]}"; do
        validate_skill_name "$skill" || continue
        [[ -d "$SKILLS_SRC/$skill" ]] || continue
        create_link "$skill" "$tool_dir" "$force" "$no_backup"
      done
      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${skills[@]}"
      fi
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
        install_copy "$skill" "$dest" "$force" "$no_backup" || (( failed++ )) || true
      done

      if [[ "$tool" == "opencode" ]]; then
        sync_opencode_permissions "$OPENCODE_CONFIG_FILE" "${skills[@]}"
      fi

      write_lock "$dest" "${skills[@]}"
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
