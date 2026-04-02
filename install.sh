#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
CANONICAL_DIR="${SKILLS_CANONICAL_DIR:-$HOME/.agents/skills}"

# Discover skills dynamically: scan skills/ for dirs with SKILL.md,
# exclude gitignored entries (e.g., cluster-health).
discover_skills() {
  local skills=()
  for dir in "$SKILLS_SRC"/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    local name
    name="$(basename "$dir")"
    # Skip gitignored skills -- if not in a git repo, include everything
    if git -C "$SKILLS_SRC" rev-parse --git-dir &>/dev/null; then
      if git -C "$SKILLS_SRC" check-ignore -q "$name" 2>/dev/null; then
        continue
      fi
    fi
    skills+=("$name")
  done
  # Sort for stable ordering
  IFS=$'\n' read -r -d '' -a skills < <(printf '%s\n' "${skills[@]}" | sort; printf '\0') || true
  printf '%s\n' "${skills[@]}"
}

mapfile -t ALL_SKILLS < <(discover_skills)

SUPPORTED_TOOLS=(
  claude codex cursor windsurf opencode
  copilot gemini roo goose amp continue kiro cline warp
  portable
)

# ── Agent path resolution ─────────────────────────────────────────────
resolve_tool_path() {
  case "$1" in
    claude)   printf '%s\n' "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" ;;
    codex)    printf '%s\n' "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}" ;;
    cursor)   printf '%s\n' "${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}" ;;
    windsurf) printf '%s\n' "${WINDSURF_SKILLS_DIR:-$HOME/.windsurf/skills}" ;;
    opencode) printf '%s\n' "${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}" ;;
    copilot)  printf '%s\n' "$HOME/.copilot/skills" ;;
    gemini)   printf '%s\n' "$HOME/.gemini/skills" ;;
    roo)      printf '%s\n' "$HOME/.roo/skills" ;;
    goose)    printf '%s\n' "$HOME/.config/goose/skills" ;;
    amp)      printf '%s\n' "$HOME/.amp/skills" ;;
    continue) printf '%s\n' "$HOME/.continue/skills" ;;
    kiro)     printf '%s\n' "$HOME/.kiro/skills" ;;
    cline)    printf '%s\n' "$HOME/.cline/skills" ;;
    warp)     printf '%s\n' "$HOME/.warp/skills" ;;
    portable) printf '%s\n' "${PORTABLE_SKILLS_DIR:-$HOME/.skills}" ;;
    *)
      printf 'Unknown tool: %s\n' "$1" >&2
      printf 'Supported: %s\n' "${SUPPORTED_TOOLS[*]}" >&2
      exit 1
      ;;
  esac
}

# ── Usage ─────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS] [SKILL...]

Install skills for AI coding agents.

Options:
  --tool TOOL         Target tool (repeatable, comma-separated)
                      Supported: claude, codex, cursor, windsurf, opencode,
                      copilot, gemini, roo, goose, amp, continue, kiro,
                      cline, warp, portable
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
  find -L "$dir" -type f -print0 | sort -z | xargs -0 cat 2>/dev/null | hash_tool
}

# ── Internal skill detection ──────────────────────────────────────────
is_internal() {
  local skill_dir="$1"
  [[ -f "$skill_dir/SKILL.md" ]] || return 1
  sed -n '2,/^---$/{ /^---$/d; p; }' "$skill_dir/SKILL.md" \
    | grep -qE '^\s+internal:\s*(true|yes)$'
}

# ── Backup ────────────────────────────────────────────────────────────
backup_skill() {
  local skill="$1" dest_dir="$2"
  local backup_base="$dest_dir/.backups"
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
      # Symlink to wrong target -- repoint it
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

  # Validate tool names
  for tool in "${tools[@]}"; do
    resolve_tool_path "$tool" > /dev/null
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
      if [[ ! -d "$CANONICAL_DIR/$skill" ]] || [[ "$force" == "true" ]]; then
        mkdir -p "$CANONICAL_DIR/$skill"
        cp -r "$SKILLS_SRC/$skill/." "$CANONICAL_DIR/$skill/"
      fi
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
    local dest
    if [[ -n "$dest_override" ]]; then
      dest="$dest_override"
    else
      dest="$(resolve_tool_path "${tools[0]}")"
    fi
    mkdir -p "$dest"

    printf 'Installing %d skill(s) for %s to %s\n\n' "${#skills[@]}" "${tools[0]}" "$dest"

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
      install_copy "$skill" "$dest" "$force" "$no_backup" || (( failed++ )) || true
    done

    write_lock "$dest" "${skills[@]}"

    printf '\n'
    if (( failed > 0 )); then
      printf 'Done with %d error(s).\n' "$failed"
      exit 1
    else
      printf 'Done. Skills installed for %s.\n' "${tools[0]}"
    fi
  fi
}

main "$@"
