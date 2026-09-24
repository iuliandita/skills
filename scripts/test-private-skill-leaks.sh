#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Builds a throwaway git repo fixture with the checker script installed at
# scripts/check-private-skill-leaks.sh, so ROOT resolution inside the
# checker matches the fixture root rather than this repo.
make_fixture() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts" "$tmp/skills/cluster-health/protected" "$tmp/skills/kubernetes-health/protected"
  cp "$ROOT/scripts/check-private-skill-leaks.sh" "$tmp/scripts/check-private-skill-leaks.sh"
  chmod +x "$tmp/scripts/check-private-skill-leaks.sh"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "test@example.com"
  git -C "$tmp" config user.name "test"
  printf '%s\n' "$tmp"
}

run_checker() {
  local tmp="$1"
  shift
  (cd "$tmp" && "$@" ./scripts/check-private-skill-leaks.sh)
}

test_no_sources_passes() {
  local tmp
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  printf 'hello world\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  run_checker "$tmp" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_root_file_only_detects_leak() {
  local tmp output status
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  printf 'topsecretmarker\n' > "$tmp/private-patterns.txt"
  printf 'contains topsecretmarker here\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  status=0
  output="$(run_checker "$tmp" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a leak from the root patterns file"
  fi
  if [[ "$output" != *"public.txt"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the leaking file"
  fi
  if [[ "$output" == *"topsecretmarker"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker printed the matched pattern instead of only the filename"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_env_file_only_detects_leak() {
  local tmp envfile output status
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  envfile="$(mktemp)"
  printf 'envmarker\n' > "$envfile"
  printf 'contains envmarker here\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  status=0
  output="$(run_checker "$tmp" env "SKILLS_PRIVATE_PATTERNS=$envfile" 2>&1)" || status=$?
  rm -f "$envfile"
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a leak from SKILLS_PRIVATE_PATTERNS"
  fi
  if [[ "$output" != *"public.txt"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the leaking file"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_combined_sources_detect_both() {
  local tmp envfile output status
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  envfile="$(mktemp)"
  printf 'envmarker\n' > "$envfile"
  printf 'rootmarker\n' > "$tmp/private-patterns.txt"
  printf 'contains rootmarker here\n' > "$tmp/from-root.txt"
  printf 'contains envmarker here\n' > "$tmp/from-env.txt"
  git -C "$tmp" add -A

  status=0
  output="$(run_checker "$tmp" env "SKILLS_PRIVATE_PATTERNS=$envfile" 2>&1)" || status=$?
  rm -f "$envfile"
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite leaks from both sources"
  fi
  if [[ "$output" != *"from-root.txt"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the root-sourced leak"
  fi
  if [[ "$output" != *"from-env.txt"* ]]; then
    printf '%s\n' "$output" >&2
    fail "checker did not report the env-sourced leak"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_env_missing_path_fails() {
  local tmp output status
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  printf 'hello world\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  status=0
  output="$(run_checker "$tmp" env "SKILLS_PRIVATE_PATTERNS=$tmp/does-not-exist.txt" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker passed despite a missing SKILLS_PRIVATE_PATTERNS file"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_comments_and_blank_lines_ignored() {
  local tmp
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  printf '# a comment\n\nignored-comment-marker\n' > "$tmp/private-patterns.txt"
  # Real content that only matches the commented-out line, not the active one.
  printf 'this file only mentions # a comment literally\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  status=0
  output="$(run_checker "$tmp" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "checker failed on a file matching only a commented-out pattern line"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_clean_repo_with_patterns_passes() {
  local tmp
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  printf 'somemarker\n' > "$tmp/private-patterns.txt"
  printf 'nothing sensitive here\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  run_checker "$tmp" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_rg_path_detects_leak() {
  if ! command -v rg >/dev/null 2>&1; then
    printf 'SKIP: rg not installed, skipping rg-path test\n'
    return
  fi
  test_root_file_only_detects_leak
}

test_grep_fallback_detects_leak() {
  local tmp fakebin output status dir bin name
  tmp="$(make_fixture)"
  trap 'rm -rf "$tmp"' RETURN

  # Build a PATH that mirrors every real command except rg, so the checker
  # falls through to its grep fallback branch instead of skipping rg by luck.
  fakebin="$(mktemp -d)"
  IFS=':' read -ra path_dirs <<< "$PATH"
  for dir in "${path_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for bin in "$dir"/*; do
      [[ -x "$bin" ]] || continue
      name="$(basename "$bin")"
      [[ "$name" == "rg" ]] && continue
      [[ -e "$fakebin/$name" ]] && continue
      ln -s "$bin" "$fakebin/$name" 2>/dev/null || true
    done
  done

  printf 'fallbackmarker\n' > "$tmp/private-patterns.txt"
  printf 'contains fallbackmarker here\n' > "$tmp/public.txt"
  git -C "$tmp" add -A

  status=0
  output="$(cd "$tmp" && PATH="$fakebin" ./scripts/check-private-skill-leaks.sh 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "grep-fallback checker passed despite a leak"
  fi
  if [[ "$output" != *"public.txt"* ]]; then
    printf '%s\n' "$output" >&2
    fail "grep-fallback checker did not report the leaking file"
  fi

  rm -rf "$tmp" "$fakebin"
  trap - RETURN
}

test_no_sources_passes
test_root_file_only_detects_leak
test_env_file_only_detects_leak
test_combined_sources_detect_both
test_env_missing_path_fails
test_comments_and_blank_lines_ignored
test_clean_repo_with_patterns_passes
test_rg_path_detects_leak
test_grep_fallback_detects_leak
printf 'private leak marker tests passed (9 cases)\n'
