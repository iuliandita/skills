#!/usr/bin/env bash
set -euo pipefail

# Print a stable sha256 over the skill-refiner evaluator inputs.
#
# The composite only measures change while the rubric is fixed. Changing any
# input below invalidates comparisons to prior runs, so skill-refiner records
# this hash in .refiner-runs.json and starts a fresh baseline when it moves.
#
# Hash file contents, not paths: a rename with no content change must not
# invalidate history. Inputs are concatenated in the fixed order below.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [[ ! -d "$ROOT" ]]; then
  echo "ERROR: rubric root is not a directory: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

SELF_CHECK_FILE="skills/skill-creator/SKILL.md"
FILES=(
  "skills/skill-refiner/references/evaluation-criteria.md"
  "skills/skill-refiner/references/test-cases.md"
  "skills/skill-creator/references/conventions.md"
  "$SELF_CHECK_FILE"
  "scripts/lint-skills.sh"
  "scripts/validate-spec.sh"
)

for rel in "${FILES[@]}"; do
  if [[ ! -f "$ROOT/$rel" ]]; then
    echo "ERROR: missing rubric input under $ROOT: $rel" >&2
    exit 1
  fi
done

ai_self_check_section() {
  awk '
    /^## AI Self-Check$/ { in_section = 1 }
    in_section && /^## / && !/^## AI Self-Check$/ { exit }
    in_section { print }
  ' "$ROOT/$SELF_CHECK_FILE"
}

{
  cat "$ROOT/skills/skill-refiner/references/evaluation-criteria.md"
  cat "$ROOT/skills/skill-refiner/references/test-cases.md"
  cat "$ROOT/skills/skill-creator/references/conventions.md"
  ai_self_check_section
  cat "$ROOT/scripts/lint-skills.sh"
  cat "$ROOT/scripts/validate-spec.sh"
} | sha256sum | awk '{ print $1 }'
