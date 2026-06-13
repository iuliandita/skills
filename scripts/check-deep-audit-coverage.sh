#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mapfile -t public_skills < <(
  git -C "$ROOT" ls-files 'skills/*/SKILL.md' \
    | sed 's#^skills/##; s#/SKILL.md$##' \
    | sort
)

wave_skills=(
  ai-ml
  ansible
  anti-ai-prose
  anti-slop
  arch-btw
  backend-api
  ci-cd
  code-review
  code-slimming
  command-prompt
  databases
  debian-ubuntu
  docker
  firewall-appliance
  frontend-design
  git
  kubernetes
  localize
  mcp
  networking
  nixos-btw
  rhel-fedora
  roadmap
  security-audit
  terraform
  testing
  update-docs
  virtualization
  zero-day
)

# Single source of truth: the exclusion table in deep-audit's references.
# Each excluded skill is the first column of a table row, wrapped in **bold**.
# Add a skill there (and nowhere else) to exclude it from deep-audit coverage.
exclusions_file="$ROOT/skills/deep-audit/references/exclusions.md"
if [[ ! -f "$exclusions_file" ]]; then
  echo "ERROR: exclusions file not found: $exclusions_file" >&2
  exit 1
fi

mapfile -t excluded_skills < <(
  grep -oE '^\| \*\*[a-z0-9-]+\*\* \|' "$exclusions_file" \
    | sed -E 's/^\| \*\*([a-z0-9-]+)\*\* \|/\1/' \
    | sort
)

if (( ${#excluded_skills[@]} == 0 )); then
  echo "ERROR: parsed no excluded skills from $exclusions_file (table format changed?)" >&2
  exit 1
fi

errors=0

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

for skill in "${public_skills[@]}"; do
  if ! contains "$skill" "${wave_skills[@]}" && ! contains "$skill" "${excluded_skills[@]}"; then
    echo "ERROR: deep-audit does not cover public skill: $skill"
    errors=$((errors + 1))
  fi
done

for skill in "${wave_skills[@]}" "${excluded_skills[@]}"; do
  if ! contains "$skill" "${public_skills[@]}"; then
    echo "ERROR: deep-audit references missing public skill: $skill"
    errors=$((errors + 1))
  fi
done

if (( errors > 0 )); then
  exit 1
fi

printf 'Deep-audit coverage accounts for %d public skills (%d wave, %d excluded).\n' \
  "${#public_skills[@]}" "${#wave_skills[@]}" "${#excluded_skills[@]}"
