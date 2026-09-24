#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATTERN_FILES=()
for skill in cluster-health kubernetes-health; do
  file="$ROOT/skills/$skill/protected/private-patterns.txt"
  [[ ! -f "$file" ]] || PATTERN_FILES+=("$file")
done

root_patterns="$ROOT/private-patterns.txt"
[[ ! -f "$root_patterns" ]] || PATTERN_FILES+=("$root_patterns")

if [[ -n "${SKILLS_PRIVATE_PATTERNS:-}" ]]; then
  if [[ ! -f "$SKILLS_PRIVATE_PATTERNS" || ! -r "$SKILLS_PRIVATE_PATTERNS" ]]; then
    echo "ERROR: SKILLS_PRIVATE_PATTERNS is set to '$SKILLS_PRIVATE_PATTERNS' but that file does not exist or is not readable." >&2
    exit 1
  fi
  PATTERN_FILES+=("$SKILLS_PRIVATE_PATTERNS")
fi

if (( ${#PATTERN_FILES[@]} == 0 )); then
  echo "No private pattern sources configured; skipping private leak check."
  exit 0
fi

mapfile -t candidate_files < <(
  git -C "$ROOT" ls-files --cached --others --exclude-standard \
    | grep -vE '^skills/(cluster-health|kubernetes-health)/protected/' \
    | grep -vxF -e 'private-patterns.txt' -e 'private-patterns.example.txt' || true
)

if (( ${#candidate_files[@]} == 0 )); then
  echo "No public files found to scan."
  exit 0
fi

tmp_patterns="$(mktemp)"
tmp_matches="$(mktemp)"
trap 'rm -f "$tmp_patterns" "$tmp_matches"' EXIT

grep -vE '^[[:space:]]*(#|$)' "${PATTERN_FILES[@]}" -h > "$tmp_patterns" || [[ $? == 1 ]]
if [[ ! -s "$tmp_patterns" ]]; then
  echo "No private patterns configured."
  exit 0
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
      [[ -f "$file" ]] || continue
      if grep -qiF -- "$pattern" "$file"; then
        printf '%s\n' "$file" >> "$tmp_matches"
      fi
    done < <(printf '%s\n' "${candidate_files[@]}")
  done < "$tmp_patterns"
fi

if [[ -s "$tmp_matches" ]]; then
  echo "ERROR: private patterns found in public files:"
  sort -u "$tmp_matches" | sed 's/^/  /'
  exit 1
fi

echo "No private patterns found in public files."
