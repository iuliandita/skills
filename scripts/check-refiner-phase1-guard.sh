#!/usr/bin/env bash
set -euo pipefail

# Enforce skill-refiner phase-1 immutability from CI instead of the skill itself.
#
# Phase 1 iteration commits must not touch the set that defines or checks the
# refiner's own quality (evaluation criteria, canonical test cases, the lint and
# spec validators and the helpers they run, the rubric hash, this guard,
# lint.yml, skill-creator, skill-refiner). Without this, a run could weaken the
# gate it is being scored against. The list is the union of this copy and the
# base revision's copy, so a commit cannot drop an entry and edit it at once. Phase 2 (meta-improvement) is
# allowed to edit those files, so only commits whose subject matches the phase-1
# iteration marker are checked.
#
# Base resolution: optional first argument, else BASE_REF, else BASE_SHA (the
# push event's previous tip; all zeros means unset, a missing commit exits 1),
# else the merge base with develop, origin/develop, main, or origin/main. The script only reads refs and
# never mutates the repository. It exits 0 with an explicit message when no base
# ref resolves at all, or running on the base branch itself: the check is a diff
# guard and cannot run without a commit range. If a base ref resolves but no
# merge-base with HEAD can be computed (shallow clone, unrelated history), it
# exits 1 instead of silently falling back to a non-ancestor tip.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMMUTABLE_PATHS=(
  "skills/skill-refiner/references/evaluation-criteria.md"
  "skills/skill-refiner/references/test-cases.md"
  "scripts/lint-skills.sh"
  "scripts/validate-spec.sh"
  "scripts/skill-lib.sh"
  "scripts/skill-frontmatter.py"
  "scripts/gen-ref-toc.py"
  "scripts/contract-lib.sh"
  "scripts/refiner-rubric-hash.sh"
  "scripts/check-refiner-phase1-guard.sh"
  ".github/workflows/lint.yml"
  "skills/skill-creator"
  "skills/skill-refiner"
)

PHASE1_SUBJECT='^refactor\(skill-refiner\): iteration'

BASE_REF="${1:-${BASE_REF:-}}"
BASE_SHA="${BASE_SHA:-}"
if [[ "$BASE_SHA" =~ ^0+$ ]]; then
  # A push that creates a ref reports an all-zero "before" sha.
  BASE_SHA=""
fi
if [[ -z "$BASE_REF" && -n "$BASE_SHA" ]] && ! git rev-parse --verify --quiet "${BASE_SHA}^{commit}" >/dev/null; then
  echo "error: BASE_SHA '${BASE_SHA}' is not a commit in this clone" >&2
  exit 1
fi

ref_exists() {
  git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1
}

resolve_base() {
  local candidate
  for candidate in "$@"; do
    if ref_exists "$candidate"; then
      if base="$(git merge-base HEAD "$candidate" 2>/dev/null)"; then
        return 0
      fi
      echo "error: base ref '${candidate}' exists but no merge-base with HEAD could be computed" >&2
      echo "(shallow clone or unrelated history); refusing to fall back to a non-ancestor tip." >&2
      exit 1
    fi
  done
  base=""
}

base=""
if [[ -n "$BASE_REF" ]]; then
  resolve_base "$BASE_REF" "origin/$BASE_REF"
elif [[ -n "$BASE_SHA" ]]; then
  resolve_base "$BASE_SHA"
else
  resolve_base develop origin/develop main origin/main
fi

head_sha="$(git rev-parse HEAD)"
if [[ -z "$base" || "$base" == "$head_sha" ]]; then
  echo "No comparable base (base=${base:-none}); skill-refiner phase-1 guard skipped."
  exit 0
fi

while IFS= read -r path; do
  [[ -n "$path" ]] && IMMUTABLE_PATHS+=("$path")
done < <(git show "$base:scripts/check-refiner-phase1-guard.sh" 2>/dev/null |
  awk '/^IMMUTABLE_PATHS=\(/ { in_list = 1; next } in_list && /^\)/ { exit }
    in_list { gsub(/[" ]/, ""); print }')

matches_immutable() {
  local file="$1" path
  for path in "${IMMUTABLE_PATHS[@]}"; do
    if [[ "$file" == "$path" || "$file" == "$path/"* ]]; then
      return 0
    fi
  done
  return 1
}

errors=0
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  subject="$(git log -1 --format=%s "$sha")"
  [[ "$subject" =~ $PHASE1_SUBJECT ]] || continue

  offending=()
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if matches_immutable "$file"; then
      offending+=("$file")
    fi
  done < <(git diff-tree --no-commit-id --name-only -r "$sha")

  if (( ${#offending[@]} > 0 )); then
    echo "error: phase-1 iteration commit touches the immutable set:" >&2
    echo "  $(git rev-parse --short "$sha") $subject" >&2
    printf '    %s\n' "${offending[@]}" >&2
    errors=$((errors + 1))
  fi
done < <(git rev-list --reverse "$base..HEAD")

if (( errors > 0 )); then
  echo
  echo "Phase-1 refiner commits must not modify evaluation criteria, canonical tests,"
  echo "lint/validate scripts and the helpers they run, the rubric hash, this guard,"
  echo "lint.yml, skill-creator, or skill-refiner. Move the change to phase 2."
  exit 1
fi

echo "skill-refiner phase-1 immutability guard clean ($base..HEAD)."
