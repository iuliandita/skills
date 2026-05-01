#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTECTED_DIR="$ROOT/skills/cluster-health/protected"
PATTERN_FILE="$PROTECTED_DIR/private-patterns.txt"

if [[ ! -f "$PATTERN_FILE" ]]; then
  echo "No protected cluster-health overlay found; skipping private leak check."
  exit 0
fi

mapfile -t candidate_files < <(
  git -C "$ROOT" ls-files --cached --others --exclude-standard \
    | grep -v '^skills/cluster-health/protected/' || true
)

if (( ${#candidate_files[@]} == 0 )); then
  echo "No public files found to scan."
  exit 0
fi

tmp_patterns="$(mktemp)"
tmp_matches="$(mktemp)"
trap 'rm -f "$tmp_patterns" "$tmp_matches"' EXIT

grep -vE '^[[:space:]]*(#|$)' "$PATTERN_FILE" > "$tmp_patterns"
if [[ ! -s "$tmp_patterns" ]]; then
  echo "No private cluster-health patterns configured."
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
  echo "ERROR: private cluster-health patterns found in public files:"
  sort -u "$tmp_matches" | sed 's/^/  /'
  exit 1
fi

echo "No private cluster-health patterns found in public files."
