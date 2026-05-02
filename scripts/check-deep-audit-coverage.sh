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

excluded_skills=(
  browse
  cluster-health
  deep-audit
  dev-cycle
  full-review
  jekyll-hyde
  kali-linux
  lockpick
  prompt-generator
  routine-writer
  skill-creator
  skill-refiner
  skill-router
)

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
