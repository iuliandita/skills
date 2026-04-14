# CI Quality Gates - Design Spec

**Date:** 2026-04-14
**Status:** Draft
**Author:** iuliandita + Codex

Expand the existing GitHub Actions workflow into a fuller but still practical PR gate for a Markdown-heavy repo. The repo already has useful shell and security checks. The goal is to add the missing "big boys" checks without turning a small skills repo into a slow, noisy enterprise parody.

---

## 1. Goals

- Keep the existing shell, security, and collection-validation coverage
- Add first-class Markdown and workflow validation
- Catch broken links and low-grade git hygiene issues early
- Keep the workflow understandable from the YAML alone
- Avoid adding tools that require a long tuning phase before they become useful

## 2. Non-Goals

- No prose-style enforcement with Vale, cSpell, or grammar bots in this pass
- No package-manager-based build setup for the empty `package.json`
- No broad Semgrep scan over the Markdown corpus
- No separate release workflow in this pass

---

## 3. Current State

The repo already has one GitHub Actions workflow at `.github/workflows/lint.yml` with two jobs:

- `lint`
  - `./scripts/lint-skills.sh`
  - `./scripts/validate-spec.sh`
  - `bash -n install.sh`
  - `shellcheck scripts/lint-skills.sh scripts/validate-spec.sh install.sh`
- `security`
  - `gitleaks`
  - `semgrep` over `install.sh`, `scripts`, and `.github/workflows`

This is a good base, but it is missing:

- Markdown linting for the repo's main content surface
- Broken-link checks
- GitHub Actions workflow validation
- Verification for the new Python helper under `scripts/`
- A low-cost git hygiene check for whitespace and merge-marker junk

---

## 4. Proposed Architecture

Keep a single workflow file, but split it into focused jobs so failures are readable:

1. `collection`
2. `shell-and-python`
3. `markdown`
4. `links`
5. `workflow`
6. `security`

All jobs run on:

- `pull_request`
- `push` to `main`

All jobs use path filtering so unrelated pushes do not trigger them. The workflow should include:

- `skills/**`
- `scripts/**`
- `install.sh`
- `README.md`
- `SECURITY.md`
- `.github/workflows/**`
- `docs/**`

The existing security job remains independent so doc-only failures do not hide security results.

---

## 5. Job Design

### 5.1 `collection`

Purpose: keep the existing repo-specific contract checks.

Steps:

- checkout
- `./scripts/lint-skills.sh`
- `./scripts/validate-spec.sh`
- `git diff --check`

Rationale:

- These are the highest-signal checks in the repo
- `git diff --check` is a cheap way to catch whitespace breakage and conflict markers

### 5.2 `shell-and-python`

Purpose: validate executable repo tooling.

Steps:

- checkout
- `bash -n install.sh`
- `bash -n scripts/lint-skills.sh`
- `bash -n scripts/validate-spec.sh`
- `shellcheck install.sh scripts/lint-skills.sh scripts/validate-spec.sh scripts/skill-lib.sh`
- `python3 -m py_compile scripts/skill-frontmatter.py`

Rationale:

- The repo now has a small Python helper and it should be treated as first-class executable code
- This keeps the CI signal grounded in the repo's actual non-Markdown surface

### 5.3 `markdown`

Purpose: enforce consistent Markdown structure and catch sloppy formatting drift.

Tool:

- `markdownlint-cli2`

Scope:

- `README.md`
- `SECURITY.md`
- `skills/**/*.md`
- `docs/**/*.md`

Configuration:

- Prefer a repo-level `.markdownlint-cli2.jsonc`
- Start with pragmatic rules only
- Disable any rule that creates high churn for deliberate collection style

Initial expected adjustments:

- Heading increment/order
- Blank lines around lists/code blocks
- Line-length policy should be explicit instead of relying on defaults

### 5.4 `links`

Purpose: catch stale external links and broken internal anchors.

Tool:

- `lychee`

Scope:

- `README.md`
- `SECURITY.md`
- `skills/**/*.md`
- `docs/**/*.md`

Configuration:

- Add a repo-level `lychee.toml`
- Ignore obvious non-resolvable examples when justified
- Keep retries and timeout sane to avoid flaky runs

Expected ignores:

- Example domains that are intentionally non-live
- Possibly local-only paths or anchors if the tool cannot resolve them correctly

### 5.5 `workflow`

Purpose: validate GitHub Actions YAML and workflow usage.

Tool:

- `actionlint`

Scope:

- `.github/workflows/*.yml`

Rationale:

- The repo is adding more CI surface; the workflow itself should be linted like code

### 5.6 `security`

Purpose: preserve the current security signal.

Keep:

- `gitleaks`
- `semgrep`

Change:

- No major scope expansion in this pass

Rationale:

- Current scope is sane for a Markdown-heavy repo
- Expanding security scanning over doc content will mostly buy false positives

---

## 6. Configuration Files

Add:

- `.markdownlint-cli2.jsonc`
- `lychee.toml`

Do not add:

- `vale.ini`
- `.cspell.json`
- package-manager tool config that implies a JS toolchain commitment

Configuration should live in-repo so the rules are obvious to contributors and easy to tweak.

---

## 7. Failure Philosophy

The workflow should be strict on structure and correctness, but conservative on style noise.

Fail hard on:

- invalid skill collection structure
- invalid workflow YAML
- shell/python syntax issues
- broken links
- security findings
- merge markers / whitespace errors

Be pragmatic on:

- Markdown line length
- style rules that fight the collection's intentional format

If a rule creates broad churn without improving review quality, disable it instead of training contributors to ignore CI.

---

## 8. Implementation Plan

1. Fix the in-flight frontmatter helper so it is dependency-free and CI-safe
2. Add `.markdownlint-cli2.jsonc` with pragmatic defaults for this repo
3. Add `lychee.toml` with minimal justified ignores
4. Expand `.github/workflows/lint.yml` into the six-job layout
5. Run the local equivalents of the new checks where possible
6. Review the resulting CI runtime and trim any noisy or redundant rule

---

## 9. Risks and Mitigations

### Risk: Markdown lint churn is too high

Mitigation:

- start with narrow scope and pragmatic rule config
- disable rules that fight the repo's established style

### Risk: Link checking is flaky

Mitigation:

- use conservative timeout/retry settings
- explicitly ignore known example-only targets

### Risk: New CI breaks because the Python helper adds hidden dependencies

Mitigation:

- keep the helper stdlib-only
- compile-check it explicitly in CI

### Risk: Workflow becomes hard to read

Mitigation:

- keep one workflow file
- split by job responsibility, not by tool novelty

---

## 10. Success Criteria

The design is successful if:

- CI still feels lightweight relative to the repo size
- Markdown regressions are caught automatically
- broken links are surfaced in PRs
- GitHub Actions changes are linted before merge
- the Python helper is checked in CI without adding a package bootstrap step
- contributors can understand the workflow without reading external docs
