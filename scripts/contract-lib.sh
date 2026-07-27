#!/usr/bin/env bash
# Shared helpers for the per-skill shared references (output contract, agent
# hygiene, ...).
#
# Each source of truth lives in skills/_shared/<name>.md. Everything above the
# `maintainer-notes:not-shipped` marker is the portable content that ships into
# each skill's references/<name>.md; the marker and everything below it are
# maintainer/build notes that must never reach an installed skill.

CONTRACT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACT_ROOT="$(cd "$CONTRACT_LIB_DIR/.." && pwd)"
CONTRACT_MARKER='<!-- maintainer-notes:not-shipped'

# Every shared file that gets copied into each skill's references/ dir.
# shellcheck disable=SC2034  # consumed by scripts that source this lib
SHARED_FILE_NAMES=(
  "output-contract.md"
  "agent-hygiene.md"
)

# Back-compat single-file variables, still used by callers that only care
# about the output contract.
CONTRACT_SRC="$CONTRACT_ROOT/skills/_shared/output-contract.md"

# Emit the portable content of a shared file: every line before the marker,
# with trailing blank lines trimmed so the shipped copy ends in exactly one
# newline. Takes the source file path as $1.
render_shipped_file() {
  local src="$1"
  awk -v marker="$CONTRACT_MARKER" '
    index($0, marker) == 1 { exit }
    { lines[n++] = $0 }
    END {
      while (n > 0 && lines[n-1] == "") n--
      for (i = 0; i < n; i++) print lines[i]
    }
  ' "$src"
}

# Back-compat wrapper: render the output contract specifically.
render_shipped_contract() {
  render_shipped_file "$CONTRACT_SRC"
}
