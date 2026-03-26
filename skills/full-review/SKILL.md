---
name: full-review
description: "Use when the user wants a full repo review, complete audit, quality gate, or asks for /full-review. Also trigger on 'review everything', 'audit this repo', 'full check', 'run all checks', or any request to run multiple review skills together."
source: custom
date_added: "2026-03-22"
effort: high
---

# Full Review: Quad Audit Orchestrator

Run four independent audits in parallel and present each report separately. One command that catches bugs, slop, security issues, and stale docs across the entire codebase without invoking each skill manually.

The four audits:

1. **Code Review** (`code-review` skill) -- bugs, logic errors, edge cases, race conditions, resource leaks, convention violations. Uses confidence-based filtering (>= 80%), adversarial self-check, and evidence-based verification.
2. **Slop Check** (`anti-slop` skill) -- machine-generated patterns, over-abstraction, verbose code, stale idioms
3. **Security Audit** (`security-audit` skill) -- vulnerabilities, secrets, dependency risks, OWASP mapping
4. **Docs Sweep** (`update-docs` skill) -- stale docs, bloated instruction files, missing gotchas, broken links, companion-file drift

Each audit runs in its own subagent with a fresh context window, so they don't compete for tokens or bias each other's findings.

## When NOT to use

- A targeted correctness review on specific files -- use code-review
- Style/slop cleanup without the other audit passes -- use anti-slop
- A dedicated security review only -- use security-audit
- A documentation-only maintenance sweep -- use update-docs

## When Invoked

### Step 0: Preflight

Gather context before dispatching agents. Run these in parallel (guard each with `; true` so one failure doesn't cancel siblings):

1. **Repo state**: `git rev-parse --show-toplevel ; true` and `git rev-parse --short HEAD ; true`
2. **Branch**: `git branch --show-current ; true`
3. **Language detection**: use Glob to check for manifest files (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `composer.json`, `Gemfile`, `*.tf`, `helmfile.yaml`)
4. **Repo size estimate**: `git ls-files | wc -l ; true`

**If not a git repo** (step 1 fails): stop and tell the user. The audits rely on git context (history, blame, diff). Running without it produces low-quality results.

Record preflight values -- each subagent prompt uses them. Substitute `{placeholders}` in the agent prompts below with the actual values from preflight (e.g., replace `{repo_root}` with the output of `git rev-parse --show-toplevel`).

### Step 1: Determine Scope

The default is a **full codebase audit** since the user is running this as a quality gate. Adapt if context suggests otherwise:

- **Uncommitted changes present** -> mention this to the user, but still audit the full repo (uncommitted files are included in the working tree).
- **Detached HEAD / bare repo** -> warn the user, proceed with what's available.
- **User specified a narrower scope** (specific files, a directory) -> pass that scope to all four agents.

### Step 2: Dispatch Four Parallel Agents

Spawn all four agents in a **single message** so they run concurrently.

#### Agent 1: Code Review

Uses a general-purpose agent that invokes the custom `code-review` skill via the Skill tool. This is our thorough correctness audit with 10 universal pattern categories, language-specific references, confidence scoring, adversarial self-check, and evidence-based verification.

```
prompt: |
  You are performing a code review. Context:
  - Repo: {repo_root}
  - Commit: {short_sha}
  - Languages: {detected_languages}
  - File count: {file_count}

  Use the Skill tool to invoke the "code-review" skill.

  Important: the code-review skill will try to determine scope from context.
  Since you're in a fresh subagent with no prior code-writing session, it will
  fall through to "ask the user." Preempt this: the scope is a full codebase
  review of the entire repository. Scan everything.

  Return the complete review report.
subagent_type: general-purpose
```

#### Agent 2: Slop Check

Uses a general-purpose agent that invokes the `anti-slop` skill via the Skill tool.

```
prompt: |
  You are auditing a codebase for code quality. Context:
  - Repo: {repo_root}
  - Commit: {short_sha}
  - Languages: {detected_languages}
  - File count: {file_count}

  Use the Skill tool to invoke the "anti-slop" skill.

  Important: the anti-slop skill will try to determine scope from context.
  Since you're in a fresh subagent with no prior code-writing session, it will
  fall through to "ask the user." Preempt this: the scope is a full codebase
  audit of the entire repository. Scan everything.

  Return the complete audit report.
subagent_type: general-purpose
```

#### Agent 3: Security Audit

Uses a general-purpose agent that invokes the `security-audit` skill via the Skill tool.

```
prompt: |
  You are performing a security audit. Context:
  - Repo: {repo_root}
  - Commit: {short_sha}
  - Languages: {detected_languages}
  - File count: {file_count}

  Use the Skill tool to invoke the "security-audit" skill.

  Important: the security-audit skill determines scope in its Step 0 preflight.
  Preempt the scope question: this is a full repository audit. Scan everything.

  Return the complete audit report, including the SECURITY-AUDIT.md content.
subagent_type: general-purpose
```

#### Agent 4: Docs Sweep

Uses a general-purpose agent that invokes the `update-docs` skill via the Skill tool.

```
prompt: |
  You are performing a documentation audit. Context:
  - Repo: {repo_root}
  - Commit: {short_sha}
  - Branch: {branch}
  - Languages: {detected_languages}
  - File count: {file_count}

  Use the Skill tool to invoke the "update-docs" skill.

  Important: the update-docs skill normally runs post-session after making changes.
  In this context, you're running it as a standalone audit. Focus on:
  - Identifying stale or outdated documentation (instruction files, README.md, docs/)
  - Checking instruction-file size (must stay under 40,000 chars) and bloat
  - Verifying shared and tool-specific instruction files are in sync
  - Finding broken internal links
  - Flagging orphaned gotchas or completed migration steps still documented
  - Checking for missing docs on recent changes (use git log)

  Do NOT make changes or commit anything. Report what needs updating.
  Return the complete audit report.
subagent_type: general-purpose
```

### Step 3: Present Results

After all four agents return, present each report under its own header. Do not merge, summarize, or editorialize across reports -- each stands alone. The user reads the skill's native output, not a reinterpretation.

Use this structure:

```markdown
# Full Review: {repo_name} @ {short_sha}

Languages: {detected_languages} | Files: {file_count} | Branch: {branch}

---

## 1. Code Review

{agent 1 output verbatim}

---

## 2. Slop Check

{agent 2 output verbatim}

---

## 3. Security Audit

{agent 3 output verbatim}

---

## 4. Docs Sweep

{agent 4 output verbatim}

---
```

### Step 4: Handle Failures

If an agent fails or times out:
- Note which audit failed and why (timeout, skill not found, tool permission denied)
- Present whatever completed successfully
- Do not re-run failed agents unless the user asks

If a skill isn't available (e.g., `code-review`, `anti-slop`, `security-audit`, or `update-docs` not installed), note it in the output header and run the remaining audits. Partial results are still useful.

## Related Skills

- **code-review** -- one of the four parallel audits. Finds bugs, logic errors, correctness issues.
- **anti-slop** -- one of the four parallel audits. Finds quality/style issues and AI-generated patterns.
- **security-audit** -- one of the four parallel audits. Finds vulnerabilities, secrets, dependency risks.
- **update-docs** -- one of the four parallel audits. Finds stale docs, bloated instruction files, and missing gotchas.
- **skill-creator** -- audits the skill collection itself. Full-review audits application code.

---

## Rules

- **Parallel dispatch is mandatory.** All four agents must be spawned in a single message. Sequential execution defeats the purpose.
- **Don't editorialize.** Present each report as the skill produced it. No "based on these four reports, I recommend..." unless the user asks for synthesis. If they do ask, prioritize: security fixes > correctness bugs > slop cleanup > doc updates.
- **Respect each skill's output format.** The anti-slop skill has its own format. The security audit writes SECURITY-AUDIT.md. The code reviewer and docs sweep have their formats. Don't normalize them into a single style.
- **Don't duplicate work.** If a finding appears in multiple reports (e.g., dead code in both slop check and code review), that's fine -- independent auditors catching the same thing is signal, not noise.
- **Preflight is fast.** The parallel git commands in Step 0 should take under 2 seconds. Don't skip them -- the agent prompts are much better with context.
- **Large repos.** If file count exceeds 1000, mention to the user that this will take a while. Don't reduce scope unless asked.
- **SECURITY-AUDIT.md gitignore.** The security audit writes a report file containing vulnerability details to the repo root. After presenting results, remind the user to check that `SECURITY-AUDIT.md` is in `.gitignore` -- the sub-skill warns too, but it's easy to miss buried in output.
- **Docs sweep is read-only.** The update-docs agent must not make changes or commit anything during a full review. It reports what needs updating; the user decides when to act on it.
