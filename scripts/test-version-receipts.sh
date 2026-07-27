#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_receipt() {
  local file="$1" body="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s' "$body" > "$file"
}

run_checker() {
  local skills_root="$1"
  SKILLS_ROOT="$skills_root" "$ROOT/scripts/check-version-receipts.sh"
}

test_valid_recent_receipt_passes() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" '---
checked_at: "2026-07-27"
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
    source: "https://example.com"
---
'

  run_checker "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_stale_checked_at_fails() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" '---
checked_at: "2020-01-01"
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
    source: "https://example.com"
---
'

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a checked_at older than the budget"
  fi
  if [[ "$output" != *"fixture"* || "$output" != *"2020-01-01"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not name the skill and stale date"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_missing_checked_at_fails() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" '---
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
    source: "https://example.com"
---
'

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a missing checked_at"
  fi
  if [[ "$output" != *"missing checked_at"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the missing checked_at"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_pin_missing_source_fails() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" '---
checked_at: "2026-07-27"
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
---
'

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a pin missing source"
  fi
  if [[ "$output" != *"missing tool, version, or source"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the pin missing source"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_http_source_fails() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" '---
checked_at: "2026-07-27"
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
    source: "http://example.com"
---
'

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite an http:// (non-https) source"
  fi
  if [[ "$output" != *"not an https:// URL"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the non-https source"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_no_versions_md_anywhere_passes() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/skills/fixture"
  printf 'no receipts here\n' > "$tmp/skills/fixture/SKILL.md"

  run_checker "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_valid_recent_receipt_passes
test_stale_checked_at_fails
test_missing_checked_at_fails
test_pin_missing_source_fails
test_http_source_fails
test_no_versions_md_anywhere_passes
printf 'version receipt tests passed (6 cases)\n'
