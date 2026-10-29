#!/usr/bin/env bash
set -euo pipefail

# Prints the CHANGELOG.md section for one version, without its heading or the
# trailing reference links. Exits 1 when the version has no section or the
# section is empty. Usage: changelog-notes.sh X.Y.Z [CHANGELOG.md]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if (( $# < 1 || $# > 2 )); then
  echo "error: usage: changelog-notes.sh X.Y.Z [CHANGELOG.md]" >&2
  exit 2
fi
version="${1#v}"
file="${2:-$ROOT/CHANGELOG.md}"

notes="$(awk -v v="$version" '
  index($0, "## [" v "]") == 1 { on = 1; next }
  on && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  on { print }
' "$file" | sed '/./,$!d')"

if [[ -z "$notes" ]]; then
  echo "error: $file has no section for $version; add a '## [$version] - YYYY-MM-DD' entry" >&2
  exit 1
fi
printf '%s\n' "$notes"
