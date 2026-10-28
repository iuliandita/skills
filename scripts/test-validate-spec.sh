#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_description() {
  local length="$1" value
  printf -v value '%*s' "$length" ''
  printf '%s' "${value// /a}"
}

write_skill() {
  local skills_root="$1" name="$2" description="$3" include_license="$4" body_lines="$5" i
  mkdir -p "$skills_root/$name"
  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$description"
    if [[ "$include_license" == yes ]]; then
      printf '%s\n' 'license: MIT'
    fi
    printf '%s\n\n' '---'
    printf '%s\n\n' '# Fixture Skill'
    for ((i = 1; i <= body_lines; i++)); do
      printf 'Fixture body line %d.\n' "$i"
    done
  } > "$skills_root/$name/SKILL.md"
}

run_validator() {
  local skills_root="$1" output_var="$2" status_var="$3" captured_value status_value
  status_value=0
  captured_value="$("$ROOT/scripts/validate-spec.sh" "$skills_root" 2>&1)" || status_value=$?
  printf -v "$output_var" '%s' "$captured_value"
  printf -v "$status_var" '%s' "$status_value"
}

test_license_is_optional() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  write_skill "$tmp/skills" license-optional 'A valid skill without optional license metadata.' no 3

  run_validator "$tmp/skills" output status
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator rejected a skill without optional license metadata"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_description_advisory_boundary() {
  local tmp output status length
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  for length in 120 121; do
    write_skill "$tmp/skills" description-boundary "$(make_description "$length")" yes 3
    run_validator "$tmp/skills" output status
    if (( status != 0 )); then
      fail "advisory description target rejected $length characters"
    fi
    if (( length == 120 )) && [[ "$output" == *"advisory 120 character target"* ]]; then
      fail "validator warned at the inclusive 120-character target"
    fi
    if (( length == 121 )) && [[ "$output" != *"advisory 120 character target"* ]]; then
      fail "validator did not warn above the description target"
    fi
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_description_through_1024_passes() {
  local tmp output status description
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  description="$(make_description 700)"
  write_skill "$tmp/skills" long-description "$description" yes 3

  run_validator "$tmp/skills" output status
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator rejected a 700-character description"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_description_over_1024_fails() {
  local tmp output status description
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  description="$(make_description 1025)"
  write_skill "$tmp/skills" excessive-description "$description" yes 3

  run_validator "$tmp/skills" output status
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator accepted a 1025-character description"
  fi
  if [[ "$output" != *"exceeds 1024 characters (1025)"* ]]; then
    printf '%s\n' "$output" >&2
    fail "validator did not report the 1024-character limit"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_long_body_warns_without_failing() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  write_skill "$tmp/skills" long-body 'A valid skill whose body exceeds the recommended length.' yes 501

  run_validator "$tmp/skills" output status
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator failed a skill solely because its body exceeded 500 lines"
  fi
  if [[ "$output" != *"spec recommends < 500"* ]]; then
    printf '%s\n' "$output" >&2
    fail "validator did not warn about the body-length recommendation"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_very_long_body_remains_a_warning() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  write_skill "$tmp/skills" very-long-body 'A valid skill well beyond the recommended body length.' yes 650

  run_validator "$tmp/skills" output status
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator treated the body-length recommendation as a hard limit"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_zero_skills_fails_loudly() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  write_skill "$tmp/skills" staged-skill 'A valid skill used to prove a zero-skill target fails.' yes 3

  run_validator "$tmp/skills/staged-skill" output status
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "validator passed when it validated zero skills"
  fi
  if [[ "$output" != *"no skills found"* ]]; then
    printf '%s\n' "$output" >&2
    fail "validator did not report that no skills were found"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

write_frontmatter() {
  local skills_root="$1" name="$2" frontmatter="$3"
  mkdir -p "$skills_root/$name"
  printf -- '---\n%s\n---\n\n# Fixture Skill\n' "$frontmatter" > "$skills_root/$name/SKILL.md"
}

test_frontmatter_parsing() {
  local tmp output status label frontmatter row
  local -a invalid=(
    'unquoted colon|name: fixture
description: Configure widgets: install, run'
    'duplicate key|name: fixture
name: fixture
description: A fixture skill.'
    'flow sequence|name: fixture
description: [a fixture skill]'
  )
  local -a deprecated=(
    'trailing comment|true # TODO'
    'padded uppercase|" TRUE "'
  )
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  for row in "${invalid[@]}"; do
    label="${row%%|*}"
    frontmatter="${row#*|}"
    rm -rf "$tmp/skills"
    write_frontmatter "$tmp/skills" fixture "$frontmatter"
    run_validator "$tmp/skills" output status
    if (( status == 0 )) || [[ "$output" != *"invalid YAML frontmatter"* ]]; then
      printf '%s\n' "$output" >&2
      fail "validator accepted frontmatter with $label"
    fi
  done
  for row in "${deprecated[@]}"; do
    label="${row%%|*}"
    rm -rf "$tmp/skills"
    write_frontmatter "$tmp/skills" fixture "name: fixture
description: A fixture skill.
metadata:
  deprecated: ${row#*|}"
    output="$(python3 "$ROOT/scripts/skill-frontmatter.py" batch "$tmp/skills")"
    if [[ "$output" != $'fixture\tfixture\tfalse\ttrue' ]]; then
      printf '%s\n' "$output" >&2
      fail "batch did not treat deprecated ($label) as true"
    fi
  done
  rm -rf "$tmp"
  trap - RETURN
}

test_license_is_optional
test_frontmatter_parsing
test_description_advisory_boundary
test_description_through_1024_passes
test_description_over_1024_fails
test_long_body_warns_without_failing
test_very_long_body_remains_a_warning
test_zero_skills_fails_loudly
printf 'All validate-spec tests passed.\n'
