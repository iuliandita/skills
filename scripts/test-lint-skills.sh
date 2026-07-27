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

# Full canonical item text - must match scripts/lint-skills.sh's
# GENERIC_SELF_CHECK_ITEMS exactly, since the lint rule matches on the
# complete item, not the bold label.
CANONICAL_GENERIC_ITEMS=(
  '- [ ] **Current source checked**: dated versions, CLI flags, API names, and support windows are verified against primary docs before repeating them'
  '- [ ] **Hidden state identified**: local config, credentials, caches, contexts, branches, cluster targets, or previous runs are made explicit before acting'
  '- [ ] **Verification is real**: final checks exercise the actual runtime, parser, service, or integration point instead of only linting prose or happy paths'
  '- [ ] **Routing overlap checked**: overlapping skills, trigger terms, and "When NOT to use" boundaries are checked before returning guidance'
  '- [ ] **Spec claims verified**: claims about tool behavior, output contracts, or repo conventions are checked against current docs, scripts, or skill files'
)

# Bold labels reused with a skill-specific, non-canonical body - must NOT be
# flagged as generic even though the label matches.
CUSTOM_BODY_LABELED_ITEMS=(
  '- [ ] **Current source checked**: fixture-specific CLI flags are verified against the fixture docs'
  '- [ ] **Hidden state identified**: fixture caches and prior fixture runs are made explicit'
  '- [ ] **Verification is real**: fixture checks exercise the actual fixture runtime'
  '- [ ] **Routing overlap checked**: overlap with other fixture skills is checked'
  '- [ ] **Spec claims verified**: fixture claims are checked against the fixture spec'
)

append_self_check_section() {
  local skill_file="$1" generic_count="$2" total_count="$3"
  local i
  {
    printf '\n## AI Self-Check\n\n'
    for ((i = 1; i <= generic_count; i++)); do
      printf -- '%s\n' "${CANONICAL_GENERIC_ITEMS[$((i - 1))]}"
    done
    for ((i = generic_count + 1; i <= total_count; i++)); do
      printf -- '- [ ] Skill-specific check item %d\n' "$i"
    done
  } >> "$skill_file"
}

test_generic_self_check_ratio_within_cap_passes() {
  local tmp skill_dir
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  append_self_check_section "$skill_dir/SKILL.md" 1 10

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_generic_self_check_ratio_over_cap_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  append_self_check_section "$skill_dir/SKILL.md" 5 10

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a 50% generic AI Self-Check section"
  fi
  if [[ "$output" != *"lint-fixture"* || "$output" != *"50%"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not name the skill and ratio for the generic self-check overage"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_generic_self_check_ratio_ignores_custom_body_with_generic_label() {
  local tmp skill_dir
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  {
    printf '\n## AI Self-Check\n\n'
    printf '%s\n' "${CUSTOM_BODY_LABELED_ITEMS[@]}"
  } >> "$skill_dir/SKILL.md"

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_generic_self_check_ratio_exempts_skill_creator() {
  local tmp skill_dir
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/skill-creator"
  write_minimal_skill "$skill_dir" "skill-creator"
  append_self_check_section "$skill_dir/SKILL.md" 5 5

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_reference_files_are_scanned
test_reference_examples_are_ignored
test_unrelated_bold_does_not_mask_missing_reference
test_real_cross_skill_reference_is_accepted
test_generic_self_check_ratio_within_cap_passes
test_generic_self_check_ratio_over_cap_fails
test_generic_self_check_ratio_ignores_custom_body_with_generic_label
test_generic_self_check_ratio_exempts_skill_creator
printf 'lint tests passed\n'
