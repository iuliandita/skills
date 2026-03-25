#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
BACKUP_DIR="$SKILLS_DST/.backups"

ALL_SKILLS=(
  ansible anti-slop ci-cd code-review command-prompt databases docker
  full-review git kubernetes lightpanda lockpick networking opnsense
  prompt-generator security-audit skill-creator terraform update-docs
)

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS] [SKILL...]

Install Claude Code skills into ~/.claude/skills/

Options:
  --list       List available skills
  --force      Overwrite existing skills without prompting
  --no-backup  Skip backup of existing skills
  --help       Show this help

Examples:
  install.sh                     # Install all skills
  install.sh kubernetes docker   # Install specific skills
  install.sh --list              # List available skills
EOF
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
  echo "  [+] $skill installed"
}

main() {
  local force=false
  local no_backup=false
  local skills=()

  while (( $# > 0 )); do
    case "$1" in
      --list)    list_skills; exit 0 ;;
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

  mkdir -p "$SKILLS_DST"

  echo "Installing ${#skills[@]} skill(s) to $SKILLS_DST"
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
    echo "Done. Skills are available in your next Claude Code conversation."
  fi
}

main "$@"
