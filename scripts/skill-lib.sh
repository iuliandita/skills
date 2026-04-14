#!/usr/bin/env bash

SKILL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTMATTER_PY="$SKILL_LIB_DIR/skill-frontmatter.py"

frontmatter_valid() {
  local file="$1"
  python3 "$FRONTMATTER_PY" valid "$file"
}

frontmatter_get() {
  local file="$1" path="$2"
  python3 "$FRONTMATTER_PY" get "$file" "$path"
}

frontmatter_has() {
  local file="$1" path="$2"
  python3 "$FRONTMATTER_PY" has "$file" "$path"
}
