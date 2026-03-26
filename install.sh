#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
TOOL="${SKILLS_TOOL:-claude}"
SKILLS_DST=""
BACKUP_DIR=""

ALL_SKILLS=(
  ansible arch-btw anti-slop ci-cd code-review command-prompt databases docker
  full-review git kubernetes lockpick networking opnsense
  prompt-generator security-audit skill-creator terraform update-docs
)

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS] [SKILL...]

Install skills for Claude, Codex, Cursor, Opencode, or a generic portable directory.

Options:
  --tool TOOL  Target tool: claude | codex | cursor | opencode | portable
  --dest PATH  Override destination directory
  --list       List available skills
  --force      Overwrite existing skills without prompting
  --no-backup  Skip backup of existing skills
  --help       Show this help

Examples:
  install.sh                               # Install all skills for Claude
  install.sh --tool codex                  # Install all skills for Codex
  install.sh --tool cursor                 # Install all skills for Cursor
  install.sh --tool opencode kubernetes    # Install one skill for Opencode
  install.sh --tool portable --dest ~/.skills
  install.sh --list
EOF
}

resolve_destination() {
  case "$TOOL" in
    claude)   printf '%s\n' "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" ;;
    codex)    printf '%s\n' "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}" ;;
    cursor)   printf '%s\n' "${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}" ;;
    opencode) printf '%s\n' "${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skill}" ;;
    portable) printf '%s\n' "${PORTABLE_SKILLS_DIR:-$HOME/.skills}" ;;
    *)
      echo "Unknown tool: $TOOL" >&2
      echo "Valid tools: claude, codex, cursor, opencode, portable" >&2
      exit 1
      ;;
  esac
}

list_skills() {
  printf "\nAvailable skills (%d):\n\n" "${#ALL_SKILLS[@]}"
  for skill in "${ALL_SKILLS[@]}"; do
    if [[ -d "$SKILLS_DST/$skill" ]]; then
      printf "  %-20s [installed]\n" "$skill"
    else
      printf "  %-20s\n" "$skill"
    fi
  done
  echo
}

post_install_tool_adjustments() {
  local skill="$1"

  if [[ "$TOOL" == "opencode" ]]; then
    local skill_dir="$SKILLS_DST/$skill"
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      mv "$skill_dir/SKILL.md" "$skill_dir/SKILLS.MD"
    fi
  fi
}

backup_skill() {
  local skill="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local dest="$BACKUP_DIR/$skill/$ts"
  mkdir -p "$dest"
  cp -r "$SKILLS_DST/$skill/." "$dest/"
  # prune old backups, keep last 3
  local count
  count=$(ls -1d "$BACKUP_DIR/$skill"/*/ 2>/dev/null | wc -l)
  if (( count > 3 )); then
    ls -1d "$BACKUP_DIR/$skill"/*/ | head -n "$(( count - 3 ))" | xargs rm -rf
  fi
}

install_skill() {
  local skill="$1"
  local force="${2:-false}"
  local no_backup="${3:-false}"

  if [[ ! -d "$SKILLS_SRC/$skill" ]]; then
    echo "  [!] Unknown skill: $skill"
    return 1
  fi

  if [[ -d "$SKILLS_DST/$skill" ]]; then
    if [[ "$force" != "true" ]]; then
      echo "  [~] $skill already exists (use --force to overwrite)"
      return 0
    fi
    if [[ "$no_backup" != "true" ]]; then
      backup_skill "$skill"
      echo "  [>] $skill backed up"
    fi
  fi

  mkdir -p "$SKILLS_DST/$skill"
  cp -r "$SKILLS_SRC/$skill/." "$SKILLS_DST/$skill/"
  post_install_tool_adjustments "$skill"
  echo "  [+] $skill installed"
}

main() {
  local force=false
  local no_backup=false
  local dest_override=""
  local show_list=false
  local skills=()

  while (( $# > 0 )); do
    case "$1" in
      --tool)
        [[ $# -ge 2 ]] || { echo "--tool requires a value"; exit 1; }
        TOOL="$2"
        shift
        ;;
      --dest)
        [[ $# -ge 2 ]] || { echo "--dest requires a value"; exit 1; }
        dest_override="$2"
        shift
        ;;
      --list)    show_list=true ;;
      --force)   force=true ;;
      --no-backup) no_backup=true ;;
      --help|-h) usage; exit 0 ;;
      -*)        echo "Unknown option: $1"; usage; exit 1 ;;
      *)         skills+=("$1") ;;
    esac
    shift
  done

  # default to all skills if none specified
  if (( ${#skills[@]} == 0 )); then
    skills=("${ALL_SKILLS[@]}")
  fi

  if [[ -n "$dest_override" ]]; then
    SKILLS_DST="$dest_override"
  else
    SKILLS_DST="$(resolve_destination)"
  fi
  BACKUP_DIR="$SKILLS_DST/.backups"

  if [[ "$show_list" == "true" ]]; then
    list_skills
    exit 0
  fi

  mkdir -p "$SKILLS_DST"

  echo "Installing ${#skills[@]} skill(s) for $TOOL to $SKILLS_DST"
  echo

  local failed=0
  for skill in "${skills[@]}"; do
    install_skill "$skill" "$force" "$no_backup" || (( failed++ )) || true
  done

  echo
  if (( failed > 0 )); then
    echo "Done with $failed error(s)."
    exit 1
  else
    echo "Done. Skills are installed for $TOOL."
  fi
}

main "$@"
