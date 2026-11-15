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

  write_receipt "$tmp/skills/fixture/references/versions.md" "---
checked_at: \"$(date -u +%F)\"
checked_by: \"manual\"
pins:
  - tool: \"X\"
    version: \"1.0.0\"
    source: \"https://example.com\"
---
"

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

test_pin_starting_with_other_key_is_separate() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_receipt "$tmp/skills/fixture/references/versions.md" "---
checked_at: \"$(date -u +%F)\"
checked_by: \"manual\"
pins:
  - tool: \"X\"
    version: \"1.0.0\"
    source: \"https://example.com\"
  - version: \"2.0.0\"
    source: \"http://example.org\"
---
"

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a pin without tool"
  fi
  if [[ "$output" != *"pins[2] is missing tool, version, or source"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the second pin as missing tool"
  fi
  if [[ "$output" == *"pins[1]"* ]]; then
    printf '%s\n' "$output" >&2
    fail "second pin's fields leaked into the first pin"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

# UTC date N days from today, as YYYY-MM-DD.
utc_date_plus() {
  python3 -c 'import datetime, sys
now = datetime.datetime.now(datetime.timezone.utc)
print((now + datetime.timedelta(days=int(sys.argv[1]))).date())' "$1"
}

receipt_dated() {
  printf -- '---\nchecked_at: "%s"\nchecked_by: "manual"\npins:\n  - tool: "X"\n    version: "1.0.0"\n    source: "https://example.com"\n---\n' "$1"
}

test_future_checked_at_allows_one_day_only() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Keep both dates and the checker on the same UTC day.
  (( 86400 - $(date -u +%s) % 86400 > 20 )) || sleep 21

  write_receipt "$tmp/skills/fixture/references/versions.md" "$(receipt_dated "$(utc_date_plus 1)")"
  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker rejected a checked_at one day ahead (allowed timezone skew)"
  fi

  write_receipt "$tmp/skills/fixture/references/versions.md" "$(receipt_dated "$(utc_date_plus 2)")"
  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"more than one day in the future"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker passed a checked_at two days in the future"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_environment_does_not_fill_missing_checked_at() {
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
  output="$(CHECKED_AT="$(date -u +%F)" run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"missing checked_at"* ]]; then
    printf '%s\n' "$output" >&2
    fail "an inherited CHECKED_AT stood in for a missing checked_at"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_failed_receipt_does_not_leak_into_next() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # "a" fails early with a complete pin; "b" lacks a source for its own pin.
  write_receipt "$tmp/skills/a/references/versions.md" '---
checked_by: "manual"
pins:
  - tool: "X"
    version: "1.0.0"
    source: "https://example.com"
---
'
  write_receipt "$tmp/skills/b/references/versions.md" "---
checked_at: \"$(date -u +%F)\"
checked_by: \"manual\"
pins:
  - tool: \"Y\"
    version: \"2.0.0\"
---
"

  status=0
  output="$(run_checker "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"b: pins[1] is missing tool, version, or source"* ]]; then
    printf '%s\n' "$output" >&2
    fail "a pin field from a failed receipt filled the next receipt's missing field"
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
test_pin_starting_with_other_key_is_separate
test_future_checked_at_allows_one_day_only
test_environment_does_not_fill_missing_checked_at
test_failed_receipt_does_not_leak_into_next
test_no_versions_md_anywhere_passes
printf 'version receipt tests passed (10 cases)\n'
