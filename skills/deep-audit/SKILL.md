---
name: deep-audit
description: >
  · Orchestrate a comprehensive repo audit across up to 21 custom skills. Detects
  repo tech stack via file patterns, runs applicable skills in 5 sequential waves
  (recon, code quality, domain-specific, security, docs & hygiene), presents results
  progressively. Triggers: 'deep audit', 'full audit', 'comprehensive review',
  'audit everything', 'mega review', 'deep review'. Not for quick 4-skill sweeps
  (use full-review) or single-dimension audits (use the individual skill).
license: MIT
compatibility: "Requires iuliandita/skills collection installed. Subagent support strongly recommended."
metadata:
  source: iuliandita/skills
  date_added: "2026-04-14"
  effort: high
  argument_hint: "[scope]"
---

# Deep Audit: Wave-Based Repo Orchestrator

Run up to 21 custom skills against a repo in 5 sequential waves, presenting results
progressively. Wave 1 detects the tech stack. Waves 2-5 dispatch only the skills that
match. Each wave completes and reports before the next begins.

The five waves:

1. **Reconnaissance** - detect languages, frameworks, infra, file structure
2. **Code Quality** (parallel) - code-review, anti-slop, anti-ai-prose
3. **Domain-Specific** (parallel, conditional) - up to 13 skills based on detection
4. **Security** (sequential) - security-audit, then zero-day
5. **Docs & Hygiene** (parallel) - update-docs, roadmap, git

For a quick 4-skill sweep, use **full-review** instead.

## When to use

- Major pre-release quality gate where you want every applicable audit lens
- First audit of an unfamiliar codebase - understand what's there and what needs fixing
- Periodic deep health check on a repo you maintain
- Onboarding to a new project - the wave reports build a mental model fast

## When NOT to use

- Quick quality check on a PR or recent changes - use **full-review** (4 skills, parallel)
- Single-dimension audit (e.g., only security or only code quality) - use the individual skill directly (**security-audit**, **code-review**, etc.)
- Auditing the skill collection itself - use **skill-creator** (Mode 3)
- Offensive security engagement or CTF - use **lockpick** directly
- OS-level administration - use **arch-btw** directly

---

## AI Self-Check

Run after all waves complete, before presenting the final summary.

- [ ] All agents dispatched as `general-purpose` type (not `feature-dev:*`, `code-simplifier:*`, or other restricted types - these lack Skill tool access)
- [ ] Each agent invoked its assigned custom skill via the Skill tool as its first action
- [ ] Recon summary (Wave 1) was presented to the user before Wave 2 agents were dispatched
- [ ] Wave 2 (code quality) ran all 3 skills regardless of repo type
- [ ] Wave 3 (domain) ran only skills whose detection patterns matched - no false activations
- [ ] Wave 3 skills that were skipped are listed by name in the recon summary
- [ ] Wave 4 ran sequentially: security-audit completed before zero-day started
- [ ] Zero-day agent received a summary of security-audit findings as input context
- [ ] Each wave's results were presented before the next wave started
- [ ] Each skill's native report format was preserved - no normalization across reports
- [ ] Failed or timed-out agents noted with reason, not silently dropped
- [ ] SECURITY-AUDIT.md gitignore reminder included after Wave 4
- [ ] When user specified a scope, all agents received that scope constraint and detection was filtered to the scoped file tree
- [ ] Only skills from the iuliandita/skills collection were used - no built-in reviewers or platform audit modes

---

## Workflow

### Step 0: Preflight

Gather context. Run in parallel (guard each with `; true`):

1. **Repo state**: `git rev-parse --show-toplevel` and `git rev-parse --short HEAD`
2. **Branch**: `git branch --show-current`
3. **File count**: `git ls-files | wc -l`

**If not a git repo**: stop. The audits rely on git context.

Record preflight values. Default `{scope}` to "full codebase" unless the user specifies
a narrower target.

### Step 1: Reconnaissance (Wave 1)

Detect which Wave 3 skills apply by scanning for file patterns. Use the detection table
and script in `references/detection-patterns.md`.

Run the detection script from the repo root. It outputs matched skill names, one per line.
If the user specified a scope, pass it as the script's first argument to filter detection
to that subtree (`git ls-files -- path/to/scope` instead of the full repo).

After detection, present the recon summary before proceeding. Compute
`{unmatched_skills}` as the 13 Wave 3 candidates minus the matched set.
Compute `{count}` by summing: 3 (Wave 2) + matched Wave 3 skills + 2 (Wave 4) +
3 (Wave 5). Example: if 6 Wave 3 skills match, count = 3 + 6 + 2 + 3 = 14.

In scoped mode, separate Wave 3 matches into two lines: skills matched by files
within the scoped subtree, and skills matched only by repo-root manifests
(potential false activations from workspace-root deps). Dispatch both sets - the
invoked skill will report zero findings if its domain isn't actually in scope.
The `[root-manifest]` separation is for user transparency, not gating.

If the user stated a priority (e.g., "security is top priority"), acknowledge it
in the recon summary: "Security is prioritized - it runs in Wave 4 as designed;
wave order is fixed because earlier waves feed context into security analysis."
Do not reorder waves.

```markdown
## Wave 1: Reconnaissance

Repo: {repo_name} @ {short_sha} ({branch})
Files: {file_count}
Scope: {scope}
Languages: {detected}

Skills that will run:
  Wave 2 (always): code-review, anti-slop, anti-ai-prose
  Wave 3 (detected): {scoped_matched_skills}
  Wave 3 (root-manifest only): {root_manifest_only_skills}    # scoped mode only; omit line if empty
  Wave 3 (skipped): {unmatched_skills}
  Wave 4 (always): security-audit, zero-day
  Wave 5 (always): update-docs, roadmap, git

Total agents: {count}
```

### Step 2: Code Quality (Wave 2)

Dispatch 3 agents in parallel. All three run on every repo.

**Agent type (critical for all waves):** every agent MUST be dispatched as `general-purpose`
(or equivalent full-access type). Do NOT use `feature-dev:*`, `code-simplifier:*`, or other
restricted agent types - they lack Skill tool access and cannot invoke custom skills. The
agent type controls tool access, not the audit topic.

**Context block** (passed to every agent in every wave - substitute all `{placeholders}`
with actual preflight values before dispatching):

```
Context:
- Repo: {repo_root}
- Commit: {short_sha}
- Branch: {branch}
- Languages: {detected_languages}
- File count: {file_count}
- Scope: {scope}
- Audit: deep-audit wave {N}
```

Replace `{N}` with the current wave number (2, 3, 4, or 5).

**Agents:**

| # | Skill | Prompt |
|---|-------|--------|
| 1 | `code-review` | Invoke the `code-review` skill via the Skill tool. Run a full code review on the codebase. Scope: {scope}. Return the complete report. |
| 2 | `anti-slop` | Invoke the `anti-slop` skill via the Skill tool. Audit the codebase for machine-generated patterns, over-abstraction, and code quality issues. Scope: {scope}. Return the complete report. |
| 3 | `anti-ai-prose` | Invoke the `anti-ai-prose` skill via the Skill tool. Audit all prose (docs, README, comments, docstrings, commit messages) for AI tells. Scope: {scope}. Return the complete report. |

Present Wave 2 results under:

```markdown
## Wave 2: Code Quality

### Code Review
{agent 1 report verbatim}

### Slop Check
{agent 2 report verbatim}

### Prose Check
{agent 3 report verbatim}
```

### Step 3: Domain-Specific (Wave 3)

Dispatch only the skills whose detection patterns matched in Wave 1. All matched skills
run in parallel.

**Generic prompt template** (used for most skills):

```
{context_block}

Invoke the `{skill_name}` skill via the Skill tool, then audit the codebase.
Scope: {scope}. Return the complete report.
```

**Skill-specific overrides** (use instead of the generic prompt):

| Skill | Override |
|-------|---------|
| `testing` | Audit test quality, coverage gaps, flaky test patterns, and missing test scenarios. Do not write new tests - report only. |
| `command-prompt` | Audit shell scripts, dotfile config, and .env patterns for correctness, portability, and security. |
| `localize` | Audit i18n completeness. Find hardcoded user-facing strings, validate locale catalogs, check for missing translations. |
| `ci-cd` | Audit pipeline config for security (SHA pinning, secret exposure), efficiency, and correctness. |

All other skills use the generic prompt.

Present results:

```markdown
## Wave 3: Domain-Specific [{N} of 13 skills matched]

### {Skill Display Name}
{report verbatim}
...
```

If zero skills matched, skip Wave 3:
"Wave 3: skipped - no domain-specific patterns detected."

### Step 4: Security (Wave 4)

Run sequentially. Security-audit first, zero-day second.

**Agent 1: Security Audit**

```
{context_block}

Invoke the `security-audit` skill via the Skill tool. Run a full security audit.
Scope: {scope}. Return the complete report including SECURITY-AUDIT.md content.
```

Wait for Agent 1 to complete. Extract the top findings (up to 10, one line each,
highest severity first) for Agent 2's context. Include: severity, affected file/area,
and a one-sentence description. Do not pass the full verbatim report. If
security-audit returned zero findings, pass the string "No critical findings from
security-audit - hunt broadly" so the zero-day agent has non-empty context.

**Agent 2: Zero-Day Hunt**

```
{context_block}

Invoke the `zero-day` skill via the Skill tool. Hunt for novel vulnerabilities
in the source code. Scope: {scope}.

Prior security-audit findings (for context, avoid duplicating these):
{security_audit_key_findings_summary}

Focus on what the standard audit missed: variant analysis on flagged patterns,
attack surface mapping, deeper inspection of auth/crypto/parsing/deserialization code.
Return the complete report.
```

Present results:

```markdown
## Wave 4: Security

### Security Audit
{agent 1 report verbatim}

### Zero-Day Hunt
{agent 2 report verbatim}

> Check that `SECURITY-AUDIT.md` is in `.gitignore` - it contains vulnerability details.
```

### Step 5: Docs & Hygiene (Wave 5)

Dispatch 3 agents in parallel.

| # | Skill | Prompt |
|---|-------|--------|
| 1 | `update-docs` | Invoke the `update-docs` skill via the Skill tool. Run a read-only audit. Find stale docs, instruction-file bloat, broken links, companion-file drift. Do NOT make changes or commit anything. |
| 2 | `roadmap` | Invoke the `roadmap` skill via the Skill tool. Audit ROADMAP.md (or equivalent) for drift, stale items, shipped-but-unchecked features, and completeness. If no roadmap exists, note the gap. Do NOT create one. |
| 3 | `git` | Invoke the `git` skill via the Skill tool. Audit git configuration, hooks, branch hygiene, signing setup, and commit message conventions. Do NOT make changes. |

Present results:

```markdown
## Wave 5: Documentation & Hygiene

### Docs Sweep
{agent 1 report verbatim}

### Roadmap Check
{agent 2 report verbatim}

### Git Hygiene
{agent 3 report verbatim}
```

### Step 6: Final Summary

After all waves complete, present a brief priority-ordered summary:

```markdown
---

## Summary

**Critical** (act now):
- {highest severity findings across all waves}

**Important** (act soon):
- {medium severity findings}

**Minor** (when convenient):
- {low severity findings}

Waves completed: {N}/5 | Skills run: {N}/{total_matched} | Failed: {N}
```

Priority order: security fixes > correctness bugs > test gaps > slop/prose cleanup >
domain-specific issues > doc updates > hygiene.

### Step 7: Handle Failures

- Note which agent failed and why (timeout, skill not found, permission denied)
- Present everything that completed successfully
- Do not re-run failed agents unless asked
- If a skill is not installed, skip it and note the gap in the wave report header.
  Do not substitute with a manual review - the value of this audit is in the custom
  skills themselves

**If parallel execution is unavailable**: run agents sequentially within each wave. Keep
the wave order. Priority within a wave: security-related skills first, then by specificity
(more targeted before more general).

**If agent dispatch is unavailable**: run each skill sequentially in the main conversation,
one at a time. Present each result before invoking the next skill. This uses more context
but preserves the wave ordering.

## Reference Files

- `references/detection-patterns.md` - file-pattern matching table and bash detection
  script for Wave 3 skill activation. Read this before running Step 1 (Reconnaissance).
  Contains the full pattern table, the runnable script, and edge case documentation.

## Related Skills

- **full-review** - the quick 4-skill version (code-review, anti-slop, security-audit, update-docs). Use when speed matters more than depth.
- **code-review**, **anti-slop**, **anti-ai-prose** - Wave 2 participants.
- **security-audit**, **zero-day** - Wave 4 participants.
- **update-docs**, **roadmap**, **git** - Wave 5 participants.
- **testing**, **command-prompt**, **databases**, **backend-api**, **localize**, **ai-ml**, **mcp**, **docker**, **kubernetes**, **terraform**, **ansible**, **ci-cd**, **networking** - Wave 3 candidates (conditional).
- **skill-creator** - audits the skill collection. This skill audits application repos.

---

## Rules

1. **General-purpose agents only.** Every subagent MUST be `general-purpose`. Restricted agent types cannot invoke custom skills via the Skill tool.
2. **Custom skills only.** Only invoke skills from the iuliandita/skills collection. No built-in reviewers, platform audit modes, or third-party skills. If a skill is unavailable, skip it rather than substituting a manual review.
3. **Wave order is sacred.** Execute waves 1-2-3-4-5 in sequence. Never reorder, skip, or merge waves. Within a wave, agents run in parallel (except Wave 4 which is sequential).
4. **Present before proceeding.** Each wave's results are shown to the user before the next wave starts. No buffering all results to the end.
5. **Detection gates Wave 3.** Only dispatch Wave 3 skills whose file patterns matched in the recon sweep. Do not run terraform on a repo with no .tf files.
6. **Security is sequential.** security-audit completes before zero-day starts. Zero-day receives security-audit findings as input context.
7. **Read-only audit.** No agent makes changes, commits, or modifies the repo. Every agent audits and reports only. The sole exception is security-audit's SECURITY-AUDIT.md output file.
8. **Preserve native formats.** Each skill produces its own report format. Do not normalize, merge, or editorialize across reports. Cross-wave synthesis happens only in the final summary (Step 6).
9. **Don't stack with full-review.** This skill supersedes full-review's coverage. If the user asked for deep-audit, do not also invoke full-review.
10. **Respect scope.** When the user specifies a scope, pass it to every agent and filter detection patterns to that scope's file tree.
