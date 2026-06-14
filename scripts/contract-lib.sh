#!/usr/bin/env bash
# Shared helpers for the per-skill output contract.
#
# The source of truth is skills/_shared/output-contract.md. Everything above the
# `maintainer-notes:not-shipped` marker is the portable contract that ships into
# each skill's references/output-contract.md; the marker and everything below it
# are maintainer/build notes that must never reach an installed skill.

CONTRACT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACT_ROOT="$(cd "$CONTRACT_LIB_DIR/.." && pwd)"
CONTRACT_SRC="$CONTRACT_ROOT/skills/_shared/output-contract.md"
CONTRACT_MARKER='<!-- maintainer-notes:not-shipped'

# Emit the portable contract: every line before the marker, with trailing blank
# lines trimmed so the shipped copy ends in exactly one newline.
render_shipped_contract() {
  awk -v marker="$CONTRACT_MARKER" '
    index($0, marker) == 1 { exit }
    { lines[n++] = $0 }
    END {
      while (n > 0 && lines[n-1] == "") n--
      for (i = 0; i < n; i++) print lines[i]
    }
  ' "$CONTRACT_SRC"
}
