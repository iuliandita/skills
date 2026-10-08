#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)

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

1. Run the lint fixture. Fixture references, when present: details.md, shared.md, test-cases.md.

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
test_overlay_only_skill_dir_is_skipped
test_non_ascii_character_fails
test_skill_over_hard_max_lines_fails
test_unlinked_reference_fails
test_long_reference_needs_contents
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
printf 'lint tests passed\n'
