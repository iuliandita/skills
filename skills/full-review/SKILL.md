---
name: full-review
description: "Use when the user wants a full repo review, complete audit, quality gate, or asks for /full-review. Also trigger on 'review everything', 'audit this repo', 'full check', 'run all checks', or any request to run multiple review skills together."
license: MIT
metadata:
  source: iuliandita/skills
  date_added: "2026-03-22"
  effort: high
  argument_hint: "[scope]"
---

# Full Review: Quad Audit Orchestrator

Run four independent audits in parallel and present each report separately. One command that catches bugs, slop, security issues, and stale docs across the entire codebase without invoking each skill manually.

The four audits:

1. **Code Review** (`code-review` skill) -- bugs, logic errors, edge cases, race conditions, resource leaks, convention violations. Uses confidence-based filtering (>= 80%), adversarial self-check, and evidence-based verification.
2. **Slop Check** (`anti-slop` skill) -- machine-generated patterns, over-abstraction, verbose code, stale idioms
3. **Security Audit** (`security-audit` skill) -- vulnerabilities, secrets, dependency risks, OWASP mapping
4. **Docs Sweep** (`update-docs` skill) -- stale docs, bloated instruction files, missing gotchas, broken links, companion-file drift

Each audit runs in its own parallel agent/subprocess with a fresh context window, so they don't compete for tokens or bias each other's findings.

## When to use

- Running a repo-wide quality gate before merge, release, or handoff
- Auditing an unfamiliar codebase across correctness, security, slop, and docs in one pass
- Getting a broad review when the user explicitly wants multiple audit lenses at once

## When NOT to use

- A targeted correctness review on specific files -- use **code-review**
- Style/slop cleanup without the other audit passes -- use **anti-slop**
- A dedicated security review only -- use **security-audit**
- A documentation-only maintenance sweep -- use **update-docs**
- Auditing the skill collection for consistency or quality -- use **skill-creator**

## AI Self-Check

Before presenting the combined report, verify:

- [ ] All 4 audits dispatched by invoking the installed custom skills (`code-review`, `anti-slop`, `security-audit`, `update-docs`) before falling back to generic reviewers
- [ ] Each report presented under its own header, unedited
- [ ] No cross-report merging or editorializing (findings from different audits stay separate)
- [ ] SECURITY-AUDIT.md gitignore reminder included
- [ ] Failed agents noted with reason (don't silently drop a missing audit)
- [ ] Preflight context block was passed to all agents

---

## Workflow

### Step 0: Preflight

Gather context before dispatching agents. Run these in parallel (guard each with `; true` so one failure doesn't cancel siblings):

1. **Repo state**: `git rev-parse --show-toplevel ; true` and `git rev-parse --short HEAD ; true`
2. **Branch**: `git branch --show-current ; true`
3. **Language detection**: check for manifest files (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `composer.json`, `Gemfile`, `*.tf`, `helmfile.yaml`)
4. **Repo size estimate**: `git ls-files | wc -l ; true`

**If not a git repo** (step 1 fails): stop and tell the user. The audits rely on git context (history, blame, diff). Running without it produces low-quality results.

Record preflight values -- each subagent prompt uses them. Substitute `{placeholders}` in the agent prompts below with the actual values from preflight (e.g., replace `{repo_root}` with the output of `git rev-parse --show-toplevel`).

### Step 1: Determine Scope

Default is **full codebase** since the user is running this as a quality gate. Adapt if context suggests otherwise:

- **Uncommitted changes present** -> mention this, but still audit the full repo.
- **Detached HEAD / bare repo** -> warn the user, proceed with what's available.
- **User specified a narrower scope** (specific files, directory, module) -> pass that scope constraint to all four agents. Each agent only audits within the specified scope. This is the key to scoped reviews: narrowing the target, not the audit dimensions.

### Step 2: Dispatch Four Parallel Agents

Spawn all four agents concurrently. Use whatever parallel execution mechanism your tool
provides (subagents, background tasks, threads). Each agent invokes one of the four skills
and runs a full codebase audit.

**Skill invocation priority:** Each agent MUST invoke the named installed custom skill first. The exact mechanism depends on the harness: slash command, skill picker, explicit skill-loading tool, or equivalent. Custom skills from the user's installed collection take priority over built-in agent types, generic reviewers, or platform-provided audit modes. Specifically:
- Invoke `code-review`, not a generic code-review helper, when the custom skill is available
- Invoke `anti-slop`, not a generic code simplifier, when the custom skill is available
- Invoke `security-audit`, not a generic security scanner, when the custom skill is available
- Invoke `update-docs`, not a generic documentation reviewer, when the custom skill is available

**Fallback:** If a custom skill is not available (skill lookup/load returns "not found" or similar), THEN fall back to the best available alternative (built-in agent type, manual review, etc.) and note which skill was unavailable in the output header.

**If parallel execution is unavailable** (restricted sandbox, no subagent support): run
sequentially in this order: Security Audit, Code Review, Slop Check, Docs Sweep. Security
first because those findings are most time-sensitive.

Pass this context block to every agent, substituting the `{placeholders}` from preflight:

```
Context:
- Repo: {repo_root}
- Commit: {short_sha}
- Branch: {branch}
- Languages: {detected_languages}
- File count: {file_count}
- Scope: full codebase review -- scan everything
```

#### Agent 1: Code Review

Invoke `code-review`. Scope: full codebase (or user-specified scope). Return the complete report.

#### Agent 2: Slop Check

Invoke `anti-slop`. Scope: full codebase (or user-specified scope). Return the complete report.

#### Agent 3: Security Audit

Invoke `security-audit`. Scope: full codebase (or user-specified scope). Return the complete report including SECURITY-AUDIT.md content.

#### Agent 4: Docs Sweep

Invoke `update-docs` as a standalone read-only audit. Focus on: stale docs, instruction-file
bloat (40,000 char limit), companion-file drift, broken links, orphaned gotchas, missing docs
on recent changes. Do NOT make changes or commit anything.

### Step 3: Present Results

After all four agents return, present each report under its own header. Do not merge, summarize, or editorialize across reports -- each stands alone. The user reads the skill's native output, not a reinterpretation.

**Scoped reviews**: when the user specified a narrower scope, each report focuses on that scope. Use this routing table to emphasize domain-relevant checks:

| Scope | code-review focus | security-audit focus | anti-slop focus | update-docs focus |
|-------|-------------------|---------------------|-----------------|-------------------|
| Auth/session | Auth logic paths, token lifecycle | Session handling, token validation, credential storage | Auth middleware over-abstraction | Auth-related docs current |
| API endpoints | Request/response handling, error paths | Input validation, injection, rate limiting | Handler boilerplate, verbose error wrapping | API docs, OpenAPI spec |
| Data layer | Query correctness, race conditions | SQL injection, data exposure, access control | ORM abstraction, unnecessary wrappers | Schema docs, migration notes |
| Infrastructure | Config correctness, resource handling | Secrets exposure, misconfiguration | Over-engineered deploy scripts | Infra docs, runbook accuracy |

For scopes not in the table, apply each skill's standard checklist narrowed to the specified files/module.

**User requests synthesis**: if the user asks for a combined summary after seeing the reports, prioritize: security fixes > correctness bugs > slop cleanup > doc updates. Keep synthesis brief -- the individual reports are the source of truth.

After presenting results, remind the user: "Check that `SECURITY-AUDIT.md` is in `.gitignore` -- it contains vulnerability details that shouldn't be committed."

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

If a skill isn't available: try the best built-in alternative (for example, the harness's native code-review, security, or docs mode). Note the substitution in the output header so the user knows a fallback was used. Partial results are still useful.

## Related Skills

- **code-review** -- one of the four parallel audits. Finds bugs, logic errors, correctness issues.
- **anti-slop** -- one of the four parallel audits. Finds quality/style issues and AI-generated patterns.
- **security-audit** -- one of the four parallel audits. Finds vulnerabilities, secrets, dependency risks.
- **update-docs** -- one of the four parallel audits. Finds stale docs, bloated instruction files, and missing gotchas.
- **skill-creator** -- audits the skill collection itself. Full-review audits application code.

---

## Rules

- **Custom skills first.** Always invoke the installed custom skills (`code-review`, `anti-slop`, `security-audit`, `update-docs`) before falling back to generic reviewers or built-in audit modes. Fall back only if the harness cannot load the custom skill.
- **Parallel dispatch is strongly preferred.** Run all four agents concurrently when the environment supports it. If parallel execution is unavailable, run sequentially (security first -- see Step 2).
- **Don't editorialize.** Present each report as the skill produced it. No unsolicited synthesis across reports.
- **Respect each skill's output format.** The anti-slop skill has its own format. The security audit writes SECURITY-AUDIT.md. The code reviewer and docs sweep have their formats. Don't normalize them into a single style.
- **Don't duplicate work.** If a finding appears in multiple reports (e.g., dead code in both slop check and code review), that's fine -- independent auditors catching the same thing is signal, not noise.
- **Preflight is fast.** The parallel git commands in Step 0 should take under 2 seconds. Don't skip them -- the agent prompts are much better with context.
- **Large repos.** If file count exceeds 1000, mention to the user that this will take a while. Don't reduce scope unless asked.
- **SECURITY-AUDIT.md gitignore.** The security audit writes a report file containing vulnerability details to the repo root. After presenting results, remind the user to check that `SECURITY-AUDIT.md` is in `.gitignore` -- the sub-skill warns too, but it's easy to miss buried in output.
- **Docs sweep is read-only.** The update-docs agent must not make changes or commit anything during a full review. It reports what needs updating; the user decides when to act on it.
