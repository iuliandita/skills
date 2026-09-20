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
  Test fixture skill for lint behavior. Triggers: 'lint fixture'. Not for production use.
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

# One canonical test-catalog section with a single case. The lint rule now
# requires both a '**Test ' entry and a 'Prompt:' line per '### <skill>'.
write_catalog_section() {
  local name="$1"
  printf '### %s\n\n**Test 1: fixture**\nPrompt: "fixture prompt"\n\n' "$name"
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

test_report_severity_markers_are_allowed() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nP0 🔴  P1 🟠  P2 🟡  P3 🔵  info ⚪\n' >> "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    if [[ "$output" != *"non-ASCII character"* ]]; then
      printf '%s\n' "$output" >&2
      fail "severity marker fixture failed for an unrelated reason"
    fi
    printf '%s\n' "$output" >&2
    fail "functional report severity markers were rejected"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_complete_canonical_test_catalog_passes() {
  local tmp catalog
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/beta" "beta"
  write_minimal_skill "$tmp/skills/skill-refiner" "skill-refiner"
  catalog="$tmp/skills/skill-refiner/references/test-cases.md"
  {
    printf '%s\n' '## Test Cases' '### <skill-name>'
    write_catalog_section alpha
    write_catalog_section beta
    write_catalog_section skill-refiner
  } > "$catalog"

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_incomplete_canonical_test_catalog_fails() {
  local tmp catalog output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/beta" "beta"
  write_minimal_skill "$tmp/skills/skill-refiner" "skill-refiner"
  catalog="$tmp/skills/skill-refiner/references/test-cases.md"
  {
    printf '%s\n' '## Test Cases' '### <skill-name>'
    write_catalog_section alpha
    write_catalog_section alpha
    write_catalog_section orphan
  } > "$catalog"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed an incomplete canonical test catalog"
  fi
  for expected in \
    "missing section for 'beta'" \
    "duplicate section for 'alpha'" \
    "orphan section for 'orphan'"; do
    if [[ "$output" != *"$expected"* ]]; then
      printf '%s\n' "$output" >&2
      fail "lint-skills.sh did not report canonical catalog error: $expected"
    fi
  done

  rm -rf "$tmp"
  trap - RETURN
}

test_canonical_test_catalog_ignores_private_skills() {
  local tmp catalog
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  git -C "$tmp" init -q
  printf '%s\n' 'skills/private-skill/' > "$tmp/.gitignore"
  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/private-skill" "private-skill"
  write_minimal_skill "$tmp/skills/skill-refiner" "skill-refiner"
  catalog="$tmp/skills/skill-refiner/references/test-cases.md"
  {
    printf '%s\n' '## Test Cases' '### <skill-name>'
    write_catalog_section alpha
    write_catalog_section skill-refiner
  } > "$catalog"

  (cd "$tmp" && "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null)

  rm -rf "$tmp"
  trap - RETURN
}

test_canonical_test_catalog_ignores_headings_outside_cases_and_fences() {
  local tmp catalog
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/beta" "beta"
  write_minimal_skill "$tmp/skills/skill-refiner" "skill-refiner"
  catalog="$tmp/skills/skill-refiner/references/test-cases.md"
  cat > "$catalog" <<'EOF'
### Introduction

## Test Cases

### alpha

**Test 1: alpha fixture**
Prompt: "alpha prompt"

```markdown
### Example
```

````markdown
```markdown
### Nested Example
```
### Still Example
````

### beta

**Test 1: beta fixture**
Prompt: "beta prompt"

### skill-refiner

**Test 1: refiner fixture**
Prompt: "refiner prompt"

## Scoring

### Notes
EOF

  "$ROOT/scripts/lint-skills.sh" "$tmp/skills" >/dev/null

  rm -rf "$tmp"
  trap - RETURN
}

test_missing_rules_section_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  sed -i '/^## Rules$/d' "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a missing '## Rules' section"
  fi
  if [[ "$output" != *"missing '## Rules' section"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the missing '## Rules' section"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_missing_frontmatter_field_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  sed -i '/^license: MIT$/d' "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a missing frontmatter field"
  fi
  if [[ "$output" != *"missing frontmatter field 'license'"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the missing frontmatter field"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_non_ascii_character_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\ncaf\xc3\xa9 latte\n' >> "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a non-ASCII character"
  fi
  if [[ "$output" != *"non-ASCII character"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the non-ASCII character"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_skill_over_hard_max_lines_fails() {
  local tmp skill_dir output status i
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  for ((i = 0; i < 600; i++)); do
    printf '\n' >> "$skill_dir/SKILL.md"
  done

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite SKILL.md over the hard max of 600 lines"
  fi
  if [[ "$output" != *"hard max 600"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the SKILL.md hard-max violation"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

# Banned words are warning-only by design, so the mutation cannot force a
# non-zero exit without also making every existing warning an error. The test
# asserts the check fires and names the word, which is the failure signal.
test_banned_word_is_reported() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nWe delve into the fixture details.\n' >> "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "banned-word fixture failed for an unrelated lint error"
  fi
  if [[ "$output" != *"banned word 'delve'"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the banned word 'delve'"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_canonical_section_without_test_case_fails() {
  local tmp catalog output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/beta" "beta"
  write_minimal_skill "$tmp/skills/skill-refiner" "skill-refiner"
  catalog="$tmp/skills/skill-refiner/references/test-cases.md"
  {
    printf '%s\n' '## Test Cases' '### <skill-name>'
    write_catalog_section alpha
    printf '%s\n' '### beta'
    write_catalog_section skill-refiner
  } > "$catalog"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed a canonical section with a heading but no test case"
  fi
  if [[ "$output" != *"section for 'beta' has no test case"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the canonical section without a test case"
  fi

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
test_report_severity_markers_are_allowed
test_complete_canonical_test_catalog_passes
test_incomplete_canonical_test_catalog_fails
test_canonical_test_catalog_ignores_private_skills
test_canonical_test_catalog_ignores_headings_outside_cases_and_fences
test_missing_rules_section_fails
test_missing_frontmatter_field_fails
test_non_ascii_character_fails
test_skill_over_hard_max_lines_fails
test_banned_word_is_reported
test_canonical_section_without_test_case_fails
printf 'lint tests passed\n'
