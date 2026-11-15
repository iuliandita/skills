#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A run that scans nothing must not look like a clean scan: say so, as an
# annotation in GitHub Actions, and still exit 0 (forks and fresh clones have no patterns).
skip_unscanned() {
  local message="private leak check did not scan: $1. Supply markers through a private-patterns.txt file or SKILLS_PRIVATE_PATTERNS."
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::warning title=Private leak check skipped::$message"
  else
    echo "warning: $message" >&2
  fi
  exit 0
}

PATTERN_FILES=()
for skill in cluster-health kubernetes-health; do
  file="$ROOT/skills/$skill/protected/private-patterns.txt"
  [[ ! -f "$file" ]] || PATTERN_FILES+=("$file")
done

root_patterns="$ROOT/private-patterns.txt"
[[ ! -f "$root_patterns" ]] || PATTERN_FILES+=("$root_patterns")

if [[ -n "${SKILLS_PRIVATE_PATTERNS:-}" ]]; then
  if [[ ! -f "$SKILLS_PRIVATE_PATTERNS" || ! -r "$SKILLS_PRIVATE_PATTERNS" ]]; then
    echo "error: SKILLS_PRIVATE_PATTERNS is set to '$SKILLS_PRIVATE_PATTERNS' but that file does not exist or is not readable." >&2
    exit 1
  fi
  PATTERN_FILES+=("$SKILLS_PRIVATE_PATTERNS")
fi

if (( ${#PATTERN_FILES[@]} == 0 )); then
  skip_unscanned "no private pattern source is configured"
fi

if ! listed_files="$(git -C "$ROOT" ls-files --cached --others --exclude-standard)"; then
  echo "error: git ls-files failed in '$ROOT'; cannot list public files to scan." >&2
  exit 1
fi

# Tracked files deleted from the working tree are skipped: there is nothing to scan.
candidate_files=()
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  [[ ! "$file" =~ ^skills/(cluster-health|kubernetes-health)/protected/ ]] || continue
  [[ -f "$ROOT/$file" ]] || continue
  candidate_files+=("$file")
done <<< "$listed_files"

if (( ${#candidate_files[@]} == 0 )); then
  echo "No public files found to scan."
  exit 0
fi

tmp_patterns="$(mktemp)"
tmp_matches="$(mktemp)"
trap 'rm -f "$tmp_patterns" "$tmp_matches"' EXIT

grep -vE '^[[:space:]]*(#|$)' "${PATTERN_FILES[@]}" -h > "$tmp_patterns" || [[ $? == 1 ]]
if [[ ! -s "$tmp_patterns" ]]; then
  skip_unscanned "the configured pattern sources hold no patterns"
fi

cd "$ROOT"
if command -v rg >/dev/null 2>&1; then
  if rg --files-with-matches --ignore-case --fixed-strings \
    -f "$tmp_patterns" -- "${candidate_files[@]}" > "$tmp_matches"; then
    :
  else
    status=$?
    if (( status > 1 )); then
      exit "$status"
    fi
  fi
else
  while IFS= read -r pattern; do
    while IFS= read -r file; do
      status=0
      grep -qiF -- "$pattern" "$file" || status=$?
      if (( status == 0 )); then
        printf '%s\n' "$file" >> "$tmp_matches"
      elif (( status > 1 )); then
        exit "$status"
      fi
    done < <(printf '%s\n' "${candidate_files[@]}")
  done < "$tmp_patterns"
fi

if [[ -s "$tmp_matches" ]]; then
  echo "error: private patterns found in public files:" >&2
  sort -u "$tmp_matches" | sed 's/^/  /' >&2
  exit 1
fi

echo "No private patterns found in public files."
