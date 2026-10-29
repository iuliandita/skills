#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/changelog-notes.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

## [1.1.0] - 2026-02-01

### Features

* second release note.

## [1.0.0] - 2026-01-01

### Features

* first release note.

[Unreleased]: https://example.com/compare/v1.1.0...HEAD
[1.1.0]: https://example.com/compare/v1.0.0...v1.1.0
[1.0.0]: https://example.com/releases/tag/v1.0.0
EOF

out="$("$SCRIPT" 1.1.0 "$tmp/CHANGELOG.md")"
grep -q 'second release note' <<<"$out" || fail "middle section missing"
! grep -q 'first release note' <<<"$out" || fail "middle section leaked the next version"

out="$("$SCRIPT" v1.0.0 "$tmp/CHANGELOG.md")"
grep -q 'first release note' <<<"$out" || fail "last section missing"
! grep -q '^\[' <<<"$out" || fail "last section includes the reference links"

if "$SCRIPT" 9.9.9 "$tmp/CHANGELOG.md" 2>"$tmp/err"; then fail "missing version passed"; fi
grep -q '^error: ' "$tmp/err" || fail "missing version error has no prefix"

if "$SCRIPT" Unreleased "$tmp/CHANGELOG.md" 2>/dev/null; then fail "empty section passed"; fi

"$SCRIPT" 2.7.1 "$ROOT/CHANGELOG.md" >/dev/null || fail "repository changelog has no 2.7.1 section"

printf 'changelog-notes tests passed\n'
