#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=./scripts/skill-lib.sh
source "$ROOT/scripts/skill-lib.sh"

mapfile -t public_skills < <(
  git -C "$ROOT" ls-files 'skills/*/SKILL.md' \
    | sed 's#^skills/##; s#/SKILL.md$##' \
    | sort \
    | while IFS= read -r name; do
        frontmatter_flag "$ROOT/skills/$name/SKILL.md" metadata.deprecated || printf '%s\n' "$name"
      done
)

# Wave lanes are derived from repo-audit itself: conditional lanes from the
# shipped detector, always-run lanes from the workflow's Related Skills list.
detect_file="$ROOT/skills/repo-audit/references/detect.sh"
workflow_file="$ROOT/skills/repo-audit/references/exhaustive-workflow.md"
for f in "$detect_file" "$workflow_file"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: repo-audit file not found: $f" >&2
    exit 1
  fi
done

mapfile -t detect_skills < <(
  grep -oE 'matched\+=\([a-z0-9-]+\)|^[[:space:]]*check_manifest [a-z][a-z0-9-]*' "$detect_file" \
    | sed -E 's/^matched\+=\(([a-z0-9-]+)\)$/\1/; s/^[[:space:]]*check_manifest //' \
    | sort -u
)
mapfile -t always_skills < <(
  grep -E '^- .* - Wave [245] participants\.$' "$workflow_file" \
    | grep -oE '\*\*[a-z0-9-]+\*\*' | tr -d '*' | sort -u
)
mapfile -t candidate_skills < <(
  grep -E '^- .* - Wave 3 candidates' "$workflow_file" \
    | grep -oE '\*\*[a-z0-9-]+\*\*' | tr -d '*' | sort -u
)

require_parsed() {
  if (( $2 == 0 )); then
    echo "ERROR: parsed no $1 (format changed?)" >&2
    exit 1
  fi
}
require_parsed "detected lanes from $detect_file" "${#detect_skills[@]}"
require_parsed "Wave 2/4/5 participants from $workflow_file" "${#always_skills[@]}"
require_parsed "Wave 3 candidates from $workflow_file" "${#candidate_skills[@]}"

wave_skills=("${always_skills[@]}" "${detect_skills[@]}")

# Single source of truth: the exclusion table in repo-audit's references.
# Each excluded skill is the first column of a table row, wrapped in **bold**.
# Add a skill there (and nowhere else) to exclude it from repo-audit coverage.
exclusions_file="$ROOT/skills/repo-audit/references/exclusions.md"
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

for skill in "${detect_skills[@]}"; do
  if ! contains "$skill" "${candidate_skills[@]}"; then
    echo "ERROR: detect.sh matches $skill but exhaustive-workflow.md does not list it as a Wave 3 candidate"
    errors=$((errors + 1))
  fi
done
for skill in "${candidate_skills[@]}"; do
  if ! contains "$skill" "${detect_skills[@]}"; then
    echo "ERROR: exhaustive-workflow.md lists Wave 3 candidate $skill but detect.sh never matches it"
    errors=$((errors + 1))
  fi
done

for skill in "${public_skills[@]}"; do
  if ! contains "$skill" "${wave_skills[@]}" && ! contains "$skill" "${excluded_skills[@]}"; then
    echo "ERROR: repo-audit does not cover public skill: $skill"
    errors=$((errors + 1))
  fi
done

for skill in "${wave_skills[@]}" "${excluded_skills[@]}"; do
  if ! contains "$skill" "${public_skills[@]}"; then
    echo "ERROR: repo-audit references missing public skill: $skill"
    errors=$((errors + 1))
  fi
done

if (( errors > 0 )); then
  exit 1
fi

printf 'Deep-audit coverage accounts for %d public skills (%d wave, %d excluded).\n' \
  "${#public_skills[@]}" "${#wave_skills[@]}" "${#excluded_skills[@]}"
