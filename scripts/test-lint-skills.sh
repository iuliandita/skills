#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_minimal_skill() {
  local skill_dir="$1" name="$2"
  mkdir -p "$skill_dir/references"
  cat > "$skill_dir/SKILL.md" <<EOF
---
name: $name
description: >
  · Test fixture skill for lint behavior. Triggers: 'lint fixture'. Not for production use.
license: MIT
metadata:
  source: custom
  date_added: "2026-05-19"
  effort: low
---

# Test Fixture

## When to use

- Testing lint behavior.

## When NOT to use

- Real work.

## Workflow

1. Run the lint fixture.

## Rules

1. Keep the fixture minimal.
EOF
}

test_reference_files_are_scanned() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '%s\n' 'Read `references/missing.md` for missing details.' > "$skill_dir/references/details.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a missing reference from references/details.md"
  fi
  if [[ "$output" != *"referenced file 'references/missing.md' does not exist"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the missing reference file"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_reference_examples_are_ignored() {
  local tmp skill_dir
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  cat > "$skill_dir/references/details.md" <<'EOF'
```markdown
Read `references/example.md` for detailed patterns.
```
EOF

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_unrelated_bold_does_not_mask_missing_reference() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '%s\n' 'Run **anti-slop**, then read `references/missing.md`.' >> "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a missing reference masked by an unrelated bold word"
  fi
  if [[ "$output" != *"referenced file 'references/missing.md' does not exist"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the masked missing reference"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_real_cross_skill_reference_is_accepted() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_minimal_skill "$tmp/skills/other-skill" "other-skill"
  printf '%s\n' 'shared patterns' > "$tmp/skills/other-skill/references/shared.md"

  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"
  printf '%s\n' 'Use **other-skill**'\''s `references/shared.md`.' >> "$tmp/skills/lint-fixture/SKILL.md"

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_reference_files_are_scanned
test_reference_examples_are_ignored
test_unrelated_bold_does_not_mask_missing_reference
test_real_cross_skill_reference_is_accepted
printf 'lint tests passed\n'
