#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Fixture repos must not pick up the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=./scripts/gate-test-lib.sh
source "$ROOT/scripts/gate-test-lib.sh"

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

1. Run the lint fixture. Fixture references, when present: references/details.md, references/shared.md, references/test-cases.md.

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

test_overlay_only_skill_dir_is_skipped() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  git -C "$tmp" init -q
  printf '%s\n' 'skills/retired/protected/' > "$tmp/.gitignore"
  write_minimal_skill "$tmp/skills/alpha" "alpha"
  mkdir -p "$tmp/skills/retired/protected" "$tmp/skills/draft"
  printf '%s\n' 'private' > "$tmp/skills/retired/protected/notes.md"
  printf '%s\n' 'draft' > "$tmp/skills/draft/notes.md"

  status=0
  output="$(cd "$tmp" && "$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if [[ "$output" == *"retired: no SKILL.md"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh flagged a directory holding only an ignored overlay"
  fi
  if (( status == 0 )) || [[ "$output" != *"draft: no SKILL.md"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not flag a non-ignored directory without SKILL.md"
  fi

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
    fail "lint-skills.sh passed despite SKILL.md over the hard max of 500 lines"
  fi
  if [[ "$output" != *"hard max 500"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the SKILL.md hard-max violation"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_skill_over_token_guidance_warns() {
  local tmp skill_dir output status i
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  for ((i = 0; i < 250; i++)); do
    printf '%099d\n' 0 >> "$skill_dir/SKILL.md"
  done

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh failed on a SKILL.md body over the token guidance"
  fi
  if [[ "$output" != *"SKILL.md body is ~"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not warn about the SKILL.md body token estimate"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_repeated_version_floor_warns() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # One statement per floor, plus a repeat inside a fenced block: no warning.
  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '%s\n' '- Use Trivy v0.72.0+ from official releases.' '- Needs runc >= 1.4.0.' \
    '```sh' '# Trivy v0.72.0+' '```' >> "$skill_dir/SKILL.md"
  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )) || [[ "$output" == *"repeats the version floor"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh flagged version floors that are each stated once"
  fi

  # The same floor on a second line, spelled differently: advisory warning.
  printf '%s\n' '- Scan with trivy >= 0.72.0 in CI.' >> "$skill_dir/SKILL.md"
  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh failed on a repeated version floor (it is advisory)"
  fi
  if [[ "$output" != *"repeats the version floor 'trivy 0.72.0+' on 2 lines"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not warn about a repeated version floor"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_unlinked_reference_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '# Orphan\n\nOnly reachable through another reference.\n' > "$skill_dir/references/orphan.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a reference not linked from SKILL.md"
  fi
  if [[ "$output" != *"references/orphan.md is not linked from SKILL.md"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the unlinked reference"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_long_reference_needs_contents() {
  local tmp skill_dir ref output status i
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nRead `references/long.md` for details.\n' >> "$skill_dir/SKILL.md"
  ref="$skill_dir/references/long.md"
  printf '# Long\n\n' > "$ref"
  for i in 1 2 3; do
    printf '## Section %s\n\n' "$i" >> "$ref"
    for ((j = 0; j < 40; j++)); do printf 'line\n' >> "$ref"; done
  done

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a long reference without a contents list"
  fi
  if [[ "$output" != *"missing or stale '## Contents' list"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the missing contents list"
  fi

  python3 "$ROOT/scripts/gen-ref-toc.py" "$skill_dir" > /dev/null
  if ! grep -q '^- Section 3$' "$ref"; then
    fail "gen-ref-toc.py did not list the reference headings"
  fi
  cp "$ref" "$tmp/once.md"
  python3 "$ROOT/scripts/gen-ref-toc.py" "$skill_dir" > /dev/null
  if ! cmp -s "$ref" "$tmp/once.md"; then
    fail "gen-ref-toc.py is not idempotent"
  fi
  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh still failed after gen-ref-toc.py added the contents list"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_toc_goes_below_frontmatter() {
  local tmp skill_dir ref i j
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  ref="$skill_dir/references/versions.md"
  printf -- '---\nchecked_at: "2026-10-01"\npins:\n' > "$ref"
  for ((j = 0; j < 50; j++)); do printf '  - tool: "t%s"\n' "$j" >> "$ref"; done
  printf -- '---\n\n# Versions\n\n' >> "$ref"
  for i in 1 2 3; do
    printf '## Section %s\n\n' "$i" >> "$ref"
    for ((j = 0; j < 40; j++)); do printf 'line\n' >> "$ref"; done
  done

  python3 "$ROOT/scripts/gen-ref-toc.py" "$skill_dir" > /dev/null
  if [[ "$(head -n 1 "$ref")" != "---" ]] || ! grep -q '^- Section 3$' "$ref"; then
    fail "gen-ref-toc.py did not keep frontmatter first and add the list below it"
  fi
  if ! python3 "$ROOT/scripts/gen-ref-toc.py" --check "$skill_dir" > /dev/null; then
    fail "gen-ref-toc.py --check reported drift after writing below frontmatter"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_unreadable_reference_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nRead `references/bad.md` for details.\n' >> "$skill_dir/SKILL.md"
  printf '# Bad\n\n\xff\xfe not utf-8\n' > "$skill_dir/references/bad.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite a non-UTF-8 reference"
  fi
  if [[ "$output" != *"references/bad.md: unreadable reference"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report the unreadable reference"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_reference_link_needs_exact_path() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nRead `references/anti-patterns.md` for details.\n' >> "$skill_dir/SKILL.md"
  printf '# Anti-patterns\n' > "$skill_dir/references/anti-patterns.md"
  printf '# Patterns\n' > "$skill_dir/references/patterns.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"references/patterns.md is not linked from SKILL.md"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh treated references/patterns.md as linked by references/anti-patterns.md"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_author_contents_section_survives() {
  local tmp skill_dir ref i j
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  ref="$skill_dir/references/long.md"
  printf '# Long\n\n' > "$ref"
  for i in 1 2 3; do
    printf '## Section %s\n\n' "$i" >> "$ref"
    for ((j = 0; j < 40; j++)); do printf 'line\n' >> "$ref"; done
  done
  printf '## Contents\n\n- author item one\n- author item two\n' >> "$ref"

  python3 "$ROOT/scripts/gen-ref-toc.py" "$skill_dir" > /dev/null
  if ! grep -q '^- author item two$' "$ref"; then
    fail "gen-ref-toc.py removed an author's '## Contents' section deep in the file"
  fi
  if ! python3 "$ROOT/scripts/gen-ref-toc.py" --check "$skill_dir" > /dev/null; then
    fail "gen-ref-toc.py --check reported drift right after writing"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_reference_non_ascii_outside_code_fails() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\nRead `references/details.md` for details.\n' >> "$skill_dir/SKILL.md"
  printf '# Details\n\n```text\n\xe2\x9c\x93 fenced\n```\n\nInline `\xc3\xbc` code.\n' > "$skill_dir/references/details.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh rejected non-ASCII inside a reference fence or code span"
  fi

  printf '\n\xe2\x9c\x93 done\n' >> "$skill_dir/references/details.md"
  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"non-ASCII character at references/details.md:"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed despite non-ASCII in reference prose"
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

# Full docs-drift fixture: git repo with README, INSTALL, MIGRATION, install.sh,
# migrations.json and two active skills (alpha, beta). Callers mutate it after.
# Fixture for the shared skill-folder loop: a public skill, a tracked opt-in
# (internal) skill, a gitignored internal skill, two deprecated notices, a
# folder without SKILL.md, a folder holding only an ignored overlay, and the
# underscore and dot build directories.
make_loop_fixture() {
  local tmp="$1"
  git init -q "$tmp"
  printf '%s\n' 'skills/private/' 'skills/retired/protected/' > "$tmp/.gitignore"
  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/team" "team"
  sed -i.bak 's/^  effort: low$/  effort: low\n  internal: true/' "$tmp/skills/team/SKILL.md"
  write_minimal_skill "$tmp/skills/private" "private"
  sed -i.bak 's/^  effort: low$/  effort: low\n  internal: true/' "$tmp/skills/private/SKILL.md"
  write_minimal_skill "$tmp/skills/old" "old"
  sed -i.bak 's/^  effort: low$/  effort: low\n  deprecated: true/' "$tmp/skills/old/SKILL.md"
  write_minimal_skill "$tmp/skills/older" "older"
  sed -i.bak 's/^  effort: low$/  effort: low\n  deprecated: " TRUE "/' "$tmp/skills/older/SKILL.md"
  rm -f "$tmp"/skills/*/SKILL.md.bak
  write_minimal_skill "$tmp/skills/_shared" "_shared"
  write_minimal_skill "$tmp/skills/.cook" ".cook"
  mkdir -p "$tmp/skills/draft" "$tmp/skills/retired/protected"
  printf '%s\n' 'draft' > "$tmp/skills/draft/notes.md"
  printf '%s\n' 'private' > "$tmp/skills/retired/protected/notes.md"
}

# skill_lib <function> [args...]: call a skill-lib.sh function in a fresh
# shell started in /, so the answer cannot depend on the caller's directory.
skill_lib() {
  (cd / && bash -c 'source "$1"; shift; "$@"' _ "$ROOT/scripts/skill-lib.sh" "$@")
}

# The same for list_public_skills with the frontmatter cache loaded first.
# Args: <skills_dir> [switch...]
skill_lib_cached_list() {
  (cd / && bash -c '
    source "$1"; shift
    frontmatter_cache_load "$1" flag:metadata.deprecated 2>/dev/null || true
    list_public_skills "$@"' _ "$ROOT/scripts/skill-lib.sh" "$@")
}

# expect_loop <label> <expected names, space separated> <skills_dir> [switch...]
# Checked once without and once with the frontmatter cache.
expect_loop() {
  local label="$1" expected="$2" got
  shift 2
  got="$(skill_lib list_public_skills "$@" | paste -sd' ' -)"
  [[ "$got" == "$expected" ]] || fail "$label: expected '$expected', got '$got'"
  got="$(skill_lib_cached_list "$@" | paste -sd' ' -)"
  [[ "$got" == "$expected" ]] || fail "$label (cached): expected '$expected', got '$got'"
}

test_list_public_skills_modes() {
  local tmp status=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_loop_fixture "$tmp"

  expect_loop "public" "alpha team" "$tmp/skills"
  expect_loop "include-deprecated" "alpha old older team" "$tmp/skills" --include-deprecated
  expect_loop "include-gitignored" "alpha private team" "$tmp/skills" --include-gitignored
  expect_loop "include-missing" "alpha draft team" "$tmp/skills" --include-missing
  expect_loop "all switches" "alpha draft old older private retired team" "$tmp/skills" \
    --include-missing --include-gitignored --include-deprecated
  expect_loop "missing skills dir" "" "$tmp/absent"

  skill_lib list_public_skills "$tmp/skills" --include-everything >/dev/null 2>&1 || status=$?
  (( status == 2 )) || fail "unknown switch: expected exit 2, got $status"

  rm -rf "$tmp"
  trap - RETURN
}

# The gates that take the public set agree with it: an internal tracked skill
# is linted, a gitignored one is not, a deprecated notice is linted but not
# counted as active, and a folder without SKILL.md is an error.
test_lint_uses_the_shared_loop() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_loop_fixture "$tmp"

  run_gate bash -c 'cd "$1" && "$2/scripts/lint-skills.sh" "$1/skills"' _ "$tmp" "$ROOT"
  expect_fail "folder without SKILL.md" "draft: no SKILL.md found"
  [[ "$OUT" == *"[team]"* && "$OUT" == *"[old]"* && "$OUT" == *"[older]"* ]] \
    || fail "lint skipped a tracked internal skill or a deprecated notice"
  [[ "$OUT" != *"[private]"* && "$OUT" != *"retired"* && "$OUT" != *"[_shared]"* ]] \
    || fail "lint visited a gitignored, overlay-only or underscore directory"
  [[ "$OUT" == *"Skills checked: 4"* ]] || fail "lint did not check exactly alpha, old, older and team"

  rm -rf "$tmp"
  trap - RETURN
}

# One parser for install.sh's SUPPORTED_TOOLS: tokens on the opening line and
# a closing parenthesis that ends a token line are both read, from a file or
# from stdin.
test_supported_tools_parser_reads_reflowed_array() {
  local tmp got text
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  text=$'#!/usr/bin/env bash\nSUPPORTED_TOOLS=(one two # lead\n  three\n  four) # tail\nOTHER=(five)\n'
  printf '%s' "$text" > "$tmp/install.sh"

  got="$(skill_lib list_supported_tools "$tmp/install.sh" | paste -sd' ' -)"
  [[ "$got" == "one two three four" ]] || fail "reflowed array from a file: got '$got'"
  got="$(skill_lib list_supported_tools <<< "$text" | paste -sd' ' -)"
  [[ "$got" == "one two three four" ]] || fail "reflowed array from stdin: got '$got'"
  got="$(printf 'SUPPORTED_TOOLS=(solo)\nX=(no)\n' | skill_lib list_supported_tools | paste -sd' ' -)"
  [[ "$got" == "solo" ]] || fail "one-line array: got '$got'"

  rm -rf "$tmp"
  trap - RETURN
}

# The deprecated rule lives in skill-frontmatter.py flag(); the shell helper
# and the cache both ask it.
test_frontmatter_flag_asks_the_python_rule() {
  local tmp value
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills"
  for value in 'true' '"true"' '" True "' 'yes'; do
    printf -- '---\nname: s\ndescription: d\nmetadata:\n  deprecated: %s\n---\n' "$value" > "$tmp/SKILL.md"
    python3 "$ROOT/scripts/skill-frontmatter.py" flag "$tmp/SKILL.md" metadata.deprecated \
      || fail "flag command rejected deprecated: $value"
  done
  for value in 'false' '"no"' '"truthy"' '2026'; do
    printf -- '---\nname: s\ndescription: d\nmetadata:\n  deprecated: %s\n---\n' "$value" > "$tmp/SKILL.md"
    if python3 "$ROOT/scripts/skill-frontmatter.py" flag "$tmp/SKILL.md" metadata.deprecated; then
      fail "flag command accepted deprecated: $value"
    fi
  done
  printf -- '---\nname: s\ndescription: d\n---\n' > "$tmp/SKILL.md"
  if python3 "$ROOT/scripts/skill-frontmatter.py" flag "$tmp/SKILL.md" metadata.deprecated; then
    fail "flag command accepted a missing key"
  fi
  printf 'no frontmatter\n' > "$tmp/SKILL.md"
  if python3 "$ROOT/scripts/skill-frontmatter.py" flag "$tmp/SKILL.md" metadata.deprecated; then
    fail "flag command accepted a file without frontmatter"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

make_docs_fixture() {
  local tmp="$1"
  git init -q "$tmp"
  write_minimal_skill "$tmp/skills/alpha" "alpha"
  write_minimal_skill "$tmp/skills/beta" "beta"
  printf '2 active skills.\n[a](skills/alpha/SKILL.md) [b](skills/beta/SKILL.md)\nPaths for 2 targets.\n' > "$tmp/README.md"
  printf 'The installer ships paths for 2 targets.\n\n## Supported targets\n\n| Tool | Flag | Default path |\n|------|------|----|\n| One | `one` | `~/.one` |\n| Two | `two` (alias `t`) | `~/.two` |\n\n## Next\n' > "$tmp/INSTALL.md"
  printf 'The collection now has 2 active skills.\n' > "$tmp/MIGRATION.md"
  printf '#!/usr/bin/env bash\nSUPPORTED_TOOLS=(\n  one # first\n  two\n)\n' > "$tmp/install.sh"
  printf '{"skills": {"gone": {"action": "remove", "replacement": null}}}\n' > "$tmp/migrations.json"
}

# Run lint on a docs fixture; expect failure containing $2, or success when $2 is empty.
expect_docs_lint() {
  local tmp="$1" expected="$2" label="$3" output status=0
  output="$(cd "$tmp" && "$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if [[ -z "$expected" ]]; then
    if (( status != 0 )); then
      printf '%s\n' "$output" >&2
      fail "lint-skills.sh failed: $label"
    fi
    return 0
  fi
  if (( status == 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed: $label"
  fi
  if [[ "$output" != *"$expected"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh did not report '$expected': $label"
  fi
}

test_docs_fixture_passes() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  expect_docs_lint "$tmp" "" "complete docs fixture"
  rm -rf "$tmp"; trap - RETURN
}

test_docs_skipped_without_readme_and_installer() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  printf '99 active skills.\n' > "$tmp/README.md"
  rm "$tmp/install.sh"
  expect_docs_lint "$tmp" "" "collection docs check should be skipped without install.sh"
  rm -rf "$tmp"; trap - RETURN
}

test_readme_active_count_mismatch_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i 's/^2 active skills/3 active skills/' "$tmp/README.md"
  expect_docs_lint "$tmp" "README.md says 3 active skills but 2 are active" "README count"
  rm -rf "$tmp"; trap - RETURN
}

test_migration_active_count_mismatch_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i 's/has 2 active/has 5 active/' "$tmp/MIGRATION.md"
  expect_docs_lint "$tmp" "MIGRATION.md says 5 active skills" "MIGRATION count"
  rm -rf "$tmp"; trap - RETURN
}

test_readme_missing_skill_link_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i 's# \[b\](skills/beta/SKILL.md)##' "$tmp/README.md"
  expect_docs_lint "$tmp" "README.md does not link active skill 'beta'" "missing link"
  rm -rf "$tmp"; trap - RETURN
}

test_readme_unknown_skill_link_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  printf '[x](skills/ghost/SKILL.md)\n' >> "$tmp/README.md"
  expect_docs_lint "$tmp" "README.md links unknown or inactive skill 'ghost'" "unknown link"
  rm -rf "$tmp"; trap - RETURN
}

test_targets_count_mismatch_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i 's/for 2 targets/for 3 targets/' "$tmp/INSTALL.md"
  expect_docs_lint "$tmp" "INSTALL.md says 3 targets but install.sh supports 2" "INSTALL targets count"
  rm -rf "$tmp"; trap - RETURN
}

test_readme_targets_count_mismatch_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i 's/for 2 targets/for 4 targets/' "$tmp/README.md"
  expect_docs_lint "$tmp" "README.md says 4 targets but install.sh supports 2" "README targets count"
  rm -rf "$tmp"; trap - RETURN
}

test_install_table_missing_tool_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  sed -i '/^| Two /d' "$tmp/INSTALL.md"
  expect_docs_lint "$tmp" "supported-targets table is missing tool 'two'" "missing table row"
  rm -rf "$tmp"; trap - RETURN
}

test_bold_old_skill_name_fails() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  printf '\nSee **gone** for details.\n' >> "$tmp/skills/alpha/SKILL.md"
  expect_docs_lint "$tmp" "alpha: SKILL.md mentions retired skill name '**gone**'" "bold old name"
  rm -rf "$tmp"; trap - RETURN
}

test_gitignored_skill_not_counted() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  write_minimal_skill "$tmp/skills/private" "private"
  printf 'skills/private/\n' > "$tmp/.gitignore"
  expect_docs_lint "$tmp" "" "gitignored skill must not count as active"
  rm -rf "$tmp"; trap - RETURN
}

test_deprecated_skill_not_counted() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  make_docs_fixture "$tmp"
  write_minimal_skill "$tmp/skills/gone" "gone"
  sed -i 's/^  effort: low/  effort: low\n  deprecated: "true"/' "$tmp/skills/gone/SKILL.md"
  expect_docs_lint "$tmp" "" "deprecated skill must not count as active"
  rm -rf "$tmp"; trap - RETURN
}

# lint_fenced <file in the skill>: appends stdin (a fenced block) to that file
# of a minimal fixture skill and lints the fixture into STATUS and OUT.
lint_fenced() {
  local tmp
  tmp="$(mktemp -d)"
  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"
  cat >> "$tmp/skills/lint-fixture/$1"
  run_gate "$ROOT/scripts/lint-skills.sh" "$tmp/skills"
  rm -rf "$tmp"
}

test_ere_literal_pipe_is_flagged() {
  local count
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

  ```bash
  grep -E 'a\|b' f
  grep -i -E 'a\|b' f
  grep --extended-regexp 'a\|b' f
  egrep 'a\|b' f
  rg 'a\|b' .
  pgrep -f 'a\|b'
  pkill -f 'a\|b'
  grep -E -e 'a\|b' f
  ```
EOF
  expect_fail "lint-skills.sh passed despite literal-pipe patterns in ERE commands"
  count="$(grep -c 'inside an ERE pattern' <<< "$OUT" || true)"
  [[ "$count" == "8" ]] || fail "lint-skills.sh reported $count of 8 literal-pipe patterns"
}

test_ere_alternation_is_allowed() {
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

```bash
grep -iE 'http://|https://' access.log
rg 'nginx|apache' .
pgrep -f 'nginx|apache'
grep -E a\|b f
grep -E 'a\\|b' f
grep -E 'a|b' f | grep 'c\|d'
grep -E 'a' f; grep 'c\|d' f
rg -F 'a\|b' .
echo 'rg'; echo 'a\|b'
```
EOF
  expect_pass "lint-skills.sh flagged valid ERE alternation, BRE, fixed strings, or an unrelated command"
}

test_bre_alternation_is_allowed() {
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

```bash
grep 'password\|secret' config
grep -e 'a\|b' f
```
EOF
  expect_pass "lint-skills.sh flagged '\\|' in a BRE pattern"
}

test_table_pipe_escape_is_allowed() {
  local tmp skill_dir output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  skill_dir="$tmp/skills/lint-fixture"
  write_minimal_skill "$skill_dir" "lint-fixture"
  printf '\n| Vector | `grep -E docker\\|kube` |\n\nProse mentioning `grep -E a\\|b` outside a fence.\n' >> "$skill_dir/SKILL.md"

  status=0
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh flagged a Markdown table escape or prose outside a fence"
  fi

  rm -rf "$tmp"
  trap - RETURN
}

test_ere_literal_pipe_in_reference_is_flagged() {
  local STATUS OUT
  lint_fenced references/details.md <<'EOF'

```bash
grep -E 'a\|b' f
```
EOF
  expect_fail "lint-skills.sh did not scan a reference file for literal-pipe patterns"
  [[ "$OUT" == *"details.md"* && "$OUT" == *"inside an ERE pattern"* ]] \
    || fail "lint-skills.sh did not report the reference file literal-pipe match"
}

test_ere_multiline_command_is_flagged() {
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

```bash
grep -E 'a' \
  'x\|y'
```
EOF
  expect_fail "lint-skills.sh missed a literal pipe on a continuation line"
}

test_ere_shell_wrappers_are_flagged() {
  local count
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

```bash
if grep -qE "a\|b" f; then echo y; fi
FOO=1 grep -E "a\|b" f
x=$(grep -E "a\|b" f)
while ! grep -E "a\|b" f; do :; done
```
EOF
  expect_fail "lint-skills.sh missed a literal pipe behind a shell keyword, assignment, or substitution"
  count="$(grep -c 'inside an ERE pattern' <<< "$OUT" || true)"
  [[ "$count" == "4" ]] || fail "lint-skills.sh reported $count of 4 wrapped literal-pipe patterns"
}

test_ere_fence_variants_are_scanned() {
  local count
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

  ~~~
  grep -E 'a\|b' f
  ~~~

````
grep -E 'c\|d' f
```
grep -E 'e\|f' f
````
EOF
  expect_fail "lint-skills.sh skipped a literal pipe in a tilde, indented, or long fence"
  count="$(grep -c 'inside an ERE pattern' <<< "$OUT" || true)"
  [[ "$count" == "3" ]] || fail "lint-skills.sh reported $count of 3 fence-variant literal-pipe patterns"
}

test_ere_backslash_parity_and_matcher_order() {
  local count
  local STATUS OUT
  lint_fenced SKILL.md <<'EOF'

```bash
grep -E 'a\\\|b' f
grep -F -E 'a\|b' f
grep -E -F 'a\|b' f
rg -F 'a\|b' .
grep -E 'a\\|b' f
```
EOF
  expect_fail "lint-skills.sh missed an odd backslash run or a later -E matcher"
  count="$(grep -c 'inside an ERE pattern' <<< "$OUT" || true)"
  [[ "$count" == "2" ]] || fail "lint-skills.sh reported $count of 2 backslash-parity/option-order patterns"
}

test_self_check_variant_heading_is_capped() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"
  append_self_check_section "$tmp/skills/lint-fixture/SKILL.md" 5 10
  sed -i 's/^## AI Self-Check$/## Output Self-Check/' "$tmp/skills/lint-fixture/SKILL.md"
  expect_docs_lint "$tmp" "50% generic boilerplate" "generic items under a variant self-check heading"
  rm -rf "$tmp"; trap - RETURN
}

test_section_heading_must_match_exactly() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"
  sed -i 's/^## Rules$/## Notes on old Rules/' "$tmp/skills/lint-fixture/SKILL.md"
  expect_docs_lint "$tmp" "missing '## Rules' section" "a heading that only contains the section name"
  rm -rf "$tmp"; trap - RETURN
}

# The scanner decides lint results, so it is a rubric input: editing it must
# move the refiner rubric hash.
test_rubric_hash_covers_ere_scanner() {
  local tmp before after
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/skills"
  cp -r "$ROOT/scripts" "$tmp/scripts"
  cp -r "$ROOT/skills/skill-refiner" "$ROOT/skills/skill-creator" "$tmp/skills/"

  before="$("$ROOT/scripts/refiner-rubric-hash.sh" "$tmp")"
  printf '# edited\n' >> "$tmp/scripts/check-ere-pipe.py"
  after="$("$ROOT/scripts/refiner-rubric-hash.sh" "$tmp")"
  [[ -n "$before" && "$before" != "$after" ]] \
    || fail "refiner-rubric-hash.sh did not change after an edit to check-ere-pipe.py"
  rm -rf "$tmp"; trap - RETURN
}

# A scanner that cannot run must be an error, not an empty result.
test_failed_scanners_are_errors() {
  local tmp stub real_python output status
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  stub="$tmp/stub"
  mkdir -p "$stub"
  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"

  printf '#!/usr/bin/env bash\nexit 1\n' > "$stub/perl"
  chmod +x "$stub/perl"
  printf '# Details\n\n\xe2\x9c\x93 done\n' > "$tmp/skills/lint-fixture/references/details.md"
  status=0
  output="$(PATH="$stub:$PATH" "$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"non-ASCII scan of references/ did not run"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed a reference scan whose perl failed"
  fi
  rm -f "$stub/perl" "$tmp/skills/lint-fixture/references/details.md"

  real_python="$(command -v python3)"
  printf '#!/usr/bin/env bash\n[[ "${1:-}" != */check-ere-pipe.py ]] || exit 1\nexec "%s" "$@"\n' "$real_python" > "$stub/python3"
  chmod +x "$stub/python3"
  status=0
  output="$(PATH="$stub:$PATH" "$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
  if (( status == 0 )) || [[ "$output" != *"ERE literal-pipe scan of SKILL.md did not run"* ]]; then
    printf '%s\n' "$output" >&2
    fail "lint-skills.sh passed an ERE scan whose python3 failed"
  fi
  rm -f "$stub/python3"

  printf '{ not json\n' > "$tmp/migrations.json"
  expect_docs_lint "$tmp" "migrations.json could not be read" "unparseable migrations.json"
  rm -rf "$tmp"; trap - RETURN
}

test_size_reporting() {
  local tmp output expected_chars
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  write_minimal_skill "$tmp/skills/lint-fixture" "lint-fixture"
  printf '%020001d\n' 0 >> "$tmp/skills/lint-fixture/SKILL.md"
  output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)"
  # The Size line and the warning report the same body estimate.
  expected_chars=$(awk 'n>=2; /^---$/ && n<2 {n++}' "$tmp/skills/lint-fixture/SKILL.md" | wc -m)
  [[ "$output" == *"Size: ~$(( expected_chars / 4 )) tokens (above 5000)"* ]] || fail "missing size advisory"
  [[ "$output" == *"SKILL.md body is ~$(( expected_chars / 4 )) tokens"* ]] || fail "size warning disagrees with the Size line"
  [[ "$output" == *"Descriptions:   87 characters (~21 tokens)"* ]] || fail "missing description budget"
  rm -rf "$tmp"
  trap - RETURN
}

test_skill_inventory() {
  local tmp case file output status expected
  for case in valid missing-heading wrong-count duplicate missing extra empty; do
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    write_minimal_skill "$tmp/skills/lint-fixture" lint-fixture
    write_minimal_skill "$tmp/skills/skill-creator" skill-creator
    printf '\nSee [conventions](references/conventions.md).\n' >> "$tmp/skills/skill-creator/SKILL.md"
    file="$tmp/skills/skill-creator/references/conventions.md"
    printf '### Active skills (2)\n\n| Skill | Purpose |\n|---|---|\n| skill-creator | Fixture |\n| lint-fixture | Fixture |\n' > "$file"
    case "$case" in
      missing-heading)
        sed -i 's/### Active skills (2)/### Inventory/' "$file"
        expected="has no '### Active skills (N)' inventory heading"
        ;;
      wrong-count)
        sed -i 's/Active skills (2)/Active skills (3)/' "$file"
        expected='inventory says Active skills (3) but 2 are active'
        ;;
      duplicate)
        printf '| lint-fixture | Duplicate |\n' >> "$file"
        expected='inventory lists a skill more than once'
        ;;
      missing)
        sed -i '/^| lint-fixture |/d' "$file"
        expected="inventory is missing active skill 'lint-fixture'"
        ;;
      extra)
        printf '| extra | Unknown |\n' >> "$file"
        expected="inventory lists 'extra', which is not an active skill"
        ;;
      empty)
        sed -i '/^|/d' "$file"
        expected="inventory is missing active skill 'skill-creator'"
        ;;
    esac
    status=0
    output="$("$ROOT/scripts/lint-skills.sh" "$tmp/skills" 2>&1)" || status=$?
    if [[ "$case" == valid ]]; then
      (( status == 0 )) || fail "$case: $output"
    else
      (( status == 1 )) || fail "$case: expected lint failure, got $status"
      grep -Fq "$expected" <<< "$output" || fail "$case: $output"
      if [[ "$case" == duplicate ]]; then
        ! grep -q 'which is not an active skill' <<< "$output" || fail 'duplicate active skill was called inactive'
      fi
    fi
    rm -rf "$tmp"
    trap - RETURN
  done
}

test_skill_inventory
test_size_reporting
test_self_check_variant_heading_is_capped
test_section_heading_must_match_exactly
test_failed_scanners_are_errors
test_reference_files_are_scanned
test_reference_examples_are_ignored
test_ere_literal_pipe_is_flagged
test_ere_alternation_is_allowed
test_bre_alternation_is_allowed
test_table_pipe_escape_is_allowed
test_ere_literal_pipe_in_reference_is_flagged
test_ere_multiline_command_is_flagged
test_ere_shell_wrappers_are_flagged
test_ere_fence_variants_are_scanned
test_ere_backslash_parity_and_matcher_order
test_rubric_hash_covers_ere_scanner
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
test_overlay_only_skill_dir_is_skipped
test_non_ascii_character_fails
test_skill_over_hard_max_lines_fails
test_skill_over_token_guidance_warns
test_repeated_version_floor_warns
test_unlinked_reference_fails
test_long_reference_needs_contents
test_unreadable_reference_fails
test_reference_link_needs_exact_path
test_author_contents_section_survives
test_toc_goes_below_frontmatter
test_reference_non_ascii_outside_code_fails
test_banned_word_is_reported
test_canonical_section_without_test_case_fails
test_docs_fixture_passes
test_docs_skipped_without_readme_and_installer
test_readme_active_count_mismatch_fails
test_migration_active_count_mismatch_fails
test_readme_missing_skill_link_fails
test_readme_unknown_skill_link_fails
test_targets_count_mismatch_fails
test_readme_targets_count_mismatch_fails
test_install_table_missing_tool_fails
test_bold_old_skill_name_fails
test_gitignored_skill_not_counted
test_deprecated_skill_not_counted
test_list_public_skills_modes
test_lint_uses_the_shared_loop
test_supported_tools_parser_reads_reflowed_array
test_frontmatter_flag_asks_the_python_rule
printf 'lint tests passed\n'
