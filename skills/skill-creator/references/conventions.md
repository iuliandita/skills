# Skill Convention Reference

Complete reference for the conventions established across the custom skill collection. Use this
when creating or reviewing skills to ensure consistency.

---

## Table of Contents

1. Design Principles
2. Frontmatter
3. Structural Patterns
4. Style Rules
5. Reference File Organization
6. Cross-Skill Patterns
7. AI Self-Check Patterns
7.5. Diagnostic Skill Pitfalls
7.6. Workflow Reliability Patterns
7.7. Scripts and Dependencies
7.8. Model Portability
8. Trigger Description Patterns
9. Skill Inventory (November 2026)

---

## 1. Design Principles

Two principles that should guide every decision when writing or reviewing skills.

### Context budget

The context window is a shared resource. Every token a skill consumes is a token unavailable for
conversation history, other skills' metadata, tool results, and the actual user request. Treat
skill content like code in a hot loop - every line should justify its presence.

**The test:** for each paragraph, ask "does this tell the agent something it doesn't already know?"
If the answer is no, cut it. Models are smart. They don't need explanations of what YAML is or
how to run `kubectl apply`. They need the non-obvious stuff: your team's naming conventions, the
gotcha with that specific Helm chart version, the compliance requirement that isn't in any docs.

**Quantitative limits** (these exist to enforce the principle, not replace it):

| Component | Budget | Why |
|-----------|--------|-----|
| Frontmatter (`name` + `description`) | description 80-170 characters | catalog entries share the host's context budget |
| SKILL.md body | 150-250 lines preferred, 500 hard max, <5k tokens recommended | loaded when the skill activates |
| Reference files | unlimited per file, but keep individual files focused | loaded on demand |

Prefer concise examples over verbose explanations. A 5-line code block that shows the pattern
beats a 20-line paragraph describing it.

### Degrees of freedom

Match how prescriptive the skill is to how fragile the task is:

| Freedom level | Format | Use when |
|---------------|--------|----------|
| **High** | Prose instructions, heuristics | Multiple valid approaches; decisions depend on context |
| **Medium** | Pseudocode, parameterized templates | A preferred pattern exists but variation is acceptable |
| **Low** | Concrete scripts, exact commands | Operations are fragile, error-prone, or must be exact |

Think of the agent walking a path: a narrow bridge with cliffs needs guardrails (low freedom),
an open field allows many routes (high freedom).

Set freedom **per step**, not per skill. One skill can draft prose with high freedom and then
create an invoice or delete a resource with low freedom. For each step ask "what breaks if the
agent does this differently?" Nothing much: keep it heuristic. Something consequential (money,
deletion, production state, a strict output format): give the exact command and say "run exactly
this; do not add flags", or ship a script. Low freedom usually means a script or exact command,
not more prose.

**Defaults over menus.** Name one default and an escape hatch ("use pdfplumber; for scanned PDFs
use OCR instead"), not a list of equivalent tools. Option lists push the choice back onto the
agent and vary across models.

**Examples from this collection:**
- **High freedom**: code-review workflow - "check these ten buckets" gives categories but lets the
  agent decide what matters for each codebase
- **Medium freedom**: docker AI Self-Check - specific checklist items but the agent decides how to
  apply them to the user's Dockerfile
- **Low freedom**: opnsense-pfsense pfctl commands - exact syntax because a wrong flag can lock
  you out of a remote appliance

When in doubt, start with higher freedom and tighten only where you've seen the agent consistently
get it wrong. Over-constraining a skill makes it brittle and harder to maintain.

**Exception: diagnostic and monitoring skills.** These should default to **low freedom**. Diagnostic
tasks are fragile - a missing flag, a misinterpreted metric, or an improvised check can silently
report the wrong result. Define the exact commands to run, not the goal. "Verify the backup
succeeded" invites the agent to invent checks with wrong paths and service names. "Run
`velero backup describe $LATEST --details` and check Phase is Completed" does not.

---

## 2. Frontmatter

### Required fields (custom skills)

```yaml
---
name: skill-name              # lowercase a-z, 0-9, hyphens; no leading/trailing/consecutive hyphens; max 64 chars; must match directory name. (anthropic, claude) are Anthropic platform-reserved, not barred by the portable spec - avoid for compatibility
description: >                # 80-170 chars: capability clause + "Use for/when" clause; advisory warning outside
  Write and debug Bash, Zsh, POSIX sh, and Fish scripts, one-liners, functions, dotfiles, and shell completions. Use for quoting, globbing, or expansion bugs, porting a script between shells, shellcheck warnings, or .zshrc and .bashrc setup.
license: MIT                  # Agent Skills spec field
metadata:
  source: iuliandita/skills   # collection identifier (owner/repo); use "custom" for unpublished skills
  date_added: "YYYY-MM-DD"   # ISO date, quoted
  effort: low|medium|high     # determines expected complexity/token usage
---
```

### Optional fields

```yaml
compatibility: "Requires kubectl. Optional: helm, kustomize"  # env requirements, max 500 chars, MUST quote if value contains colons
allowed-tools: Read Bash(git:*) Grep  # space-separated per the Agent Skills spec; experimental, not a sandbox
```

### `paths:` frontmatter is a non-portable extension

Some tools (Claude Code v2.1.84+ (March 2026)) support `paths:` as a YAML list of globs in
skill frontmatter to activate the skill only when matching files exist in the project. This is
useful for domain-specific skills (e.g., `docker` only when `Dockerfile` exists). The `paths:`
field existed for rules since v2.0.64 but v2.1.84 extended it to skills and upgraded from
single-glob to YAML list.

This field is not part of the portable Agent Skills frontmatter. It is not universally ignored:
claude.ai uploads and Skills API packaging reject unknown top-level keys. Do not put `paths:` in a
portable source skill. Keep routing patterns in the description and scope prose, or inject the
extension only into a harness-specific installed copy.

```yaml
# Claude Code-local installed copy only
paths:
  - "Dockerfile*"
  - "compose*.yml"
```

### Headless / scripted execution

Skills may run in headless contexts where no interactive user is available:
- Claude Code `--bare` flag (no hooks, no skill directory walk)
- Cursor Automations (event-triggered, no user prompt)
- Codex `exec` mode (non-interactive)
- Antigravity CLI `agy -p`/`--print`
- OpenCode `opencode run`, Command Code `cmd -p`, Oh My Pi `omp -p`, Hermes `hermes chat -q`

Skills should not assume interactive prompting is always available. If a skill needs user input
at a decision point, provide a sensible default or document the assumption. Avoid blocking on
user confirmation in steps that could run unattended.

### Field definitions

| Field | Values | Purpose |
|-------|--------|---------|
| `name` | `a-z`, `0-9`, hyphens; no leading/trailing/consecutive hyphens; max 64 chars. `anthropic`/`claude` are Anthropic platform-reserved, not barred by the portable spec - avoid them | identifier, must match directory name |
| `description` | one paragraph, 80-170 chars, warn outside that window, 1024 spec max, no XML tags | primary trigger mechanism - the agent scans this |
| `license` | license name (e.g., `MIT`) | Agent Skills spec field |
| `compatibility` | free text, <500 chars | environment requirements (optional) |
| `metadata.source` | `owner/repo` or `custom` | identifies the publishing collection or an unpublished local skill |
| `metadata.date_added` | ISO date string | staleness detection |
| `metadata.effort` | `low`, `medium`, `high` | signals expected token usage and complexity |
| `metadata.internal` | `"true"` or `"false"` (quoted: metadata values are strings) | marks a local skill the installer skips unless `--include-internal` |
| `metadata.deprecated` | `"true"` or `"false"` (quoted) | marks a deprecated notice kept for migration |

### Lifecycle status

Parse YAML frontmatter and read `metadata.deprecated`: boolean `true` or a string that
trims and case-folds to `true` marks a deprecated notice, including quoted values. Missing
or false means active; malformed frontmatter is an error, not an active default. Do not use
string truthiness (the string `"false"` is not deprecated) or matches in the body.

Published inventory includes both active skills and notices; report their counts separately.
Notices preserve migration guidance and explicit legacy invocation behavior. Check them against
the target repository's notice and removal policy, not active-skill depth or trigger criteria.
Keep their canonical test coverage and installer integrity checks through the required lifetime.

### Effort tiers

| Tier | Complexity signal | Typical skills | Structure depth |
|------|-------------------|---------------|-----------------|
| **low** | single-purpose wrapper, minimal context | temporary deprecation notices | Minimal workflow, few rules |
| **medium** | one domain, moderate workflow | code-simplification, prompt-generator, shell-scripting, update-docs | Moderate workflow, reference files |
| **high** | multi-step domain with on-demand references | ansible, docker, kubernetes, terraform, etc. (see Skill Inventory) | Full workflow, AI self-check, checklists, multiple references |

`effort` is a qualitative signal of a skill's depth and expected complexity, not a measured token
count. The SKILL.md body targets 150-250 lines where practical (500 hard max); references carry the
rest and load on demand, so a high-effort skill's larger total footprint lives mostly outside the
always-loaded body.

### Upstream skills (for reference)

Skills mirrored directly from upstream may use their own metadata or structure. Don't rewrite
those to match the custom frontmatter unless the collection explicitly maintains a fork.

---

## 3. Structural Patterns

### High-effort skills (the infrastructure pattern)

All high-effort custom skills follow this pattern:

```
# Title: Domain Description

Overview paragraph. Goal statement.

**Target versions** (Month Year):   # optional, for tool/platform skills
- Tool: version

## When to use
## When NOT to use

---

## AI Self-Check
- [ ] Checklist items

---

## Workflow
### Step 1: Identify/Determine
### Step 2: Gather requirements
### Step 3: Build/Execute
### Step 4: Validate

---

## [Domain sections]            # domain-specific content
## [Subsections]

---

## Production Checklist          # optional, for infra skills
## PCI-DSS 4.0 Mapping          # optional, for compliance-relevant skills

---

## Reference Files               # if references/ exist
## Related Skills                # cross-references
## Rules                         # only constraints this skill genuinely needs; do not pad
```

### Medium-effort skills

```
# Title

Overview.

## When to use
## When NOT to use (or "When Invoked")

## Workflow
### Step 1-N

## [Domain sections]

## Rules
```

### Low-effort skills

```
# Title

Overview.

## When to use
## When NOT to use

## Workflow
### Step 1-N

## Rules
```

The Rules section is required by the collection linter, but its length is not. List the
constraints a skill genuinely has; a short, honest list beats invented rules added to look
thorough.

---

## 4. Style Rules

### Text

- **Imperative form**: "Check the config", not "You should check the config"
- **ASCII by default**: skill prose should stay ASCII except the single approved non-ASCII
  set below. No em-dashes, no `--` double-dash substitute, no curly quotes, no ligatures.
  Use a single `-` where you would reach for an em dash. **This is a prose rule only: never
  rewrite `--` inside code, command examples, or fenced blocks** - `--` is real syntax there
  (SQL/Lua comments, CLI long-flag separators like `npm test -- --filter`, `git ... --`),
  and stripping it to `-` produces broken, non-runnable examples.
- **Approved non-ASCII**: the middle dot (U+00B7) and the output-contract/status emoji markers the
  linter permits (U+1F534, U+1F7E0, U+1F7E2, U+1F7E1, U+1F535, U+26AA, U+26A1, U+1F3AF, U+1F480).
  `scripts/lint-skills.sh` (`check_ascii`) is the single authority on this set; this list mirrors
  it and changes only when the linter does, never the reverse.
- **Explain why**: "Pin images to SHA256 digests because mutable tags are a proven attack vector
  (Trivy March 2026, tj-actions March 2025)" beats "Always pin images"
- **Calm directives**: "Do X" outperforms "YOU MUST ALWAYS DO X" on most modern coding agents. Use ALL CAPS
  only for genuinely critical safety constraints, not for emphasis.
- **Banned words**: the authoritative list lives in `scripts/lint-skills.sh`
  (`BANNED_WORDS`); this reference mirrors it exactly: "delve", "tapestry", "nuanced",
  "multifaceted", "utilize", "commence", "facilitate", "synergy", "leverage", "holistic",
  "empower", "seamless", "innovative". The linter is authoritative; update this mirror when
  it changes, never the reverse. ("best practices" is allowed - it is standard IT
  terminology.)
- **Anti-hallucination**: every tool name, CLI flag, version number, and API endpoint must be
  verified via web search or registry check before including in a skill. AI models hallucinate
  these constantly. "I'm pretty sure" is not verification - search or don't include it.
- **One term per concept**: pick "finding" or "issue", "reference" or "doc", and keep it across
  SKILL.md and references. Mixed terms read as different things to some models.
- **No time-conditional instructions**: never "before June 2026 use X, after use Y". State the
  current method; move legacy behavior to an "Old patterns" section, collapsed with
  `<details>` where the host renders it. Dated `Target versions` pins are fine: they record when
  a fact was verified, they do not branch behavior on the calendar.
- **Portable paths and tool names**: forward slashes only (`references/<topic>.md`), relative to
  the skill directory. Name MCP tools fully qualified (`server:tool`, e.g. `github:create_issue`)
  because unqualified names fail when several servers are connected.

### Tables

Use for reference data, version comparisons, and quick-lookup information:

```markdown
| Feature | Tool A | Tool B |
|---------|--------|--------|
| Speed   | Fast   | Slow   |
```

### Checklists

Use for validation steps and production readiness:

```markdown
- [ ] Item to verify
- [ ] Another item
```

### Code examples

Use fenced code blocks with language hints. Keep examples minimal and correct:

```yaml
# Good: minimal, correct, with context comments
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production   # always explicit
```

---

## 5. Reference File Organization

### When to create reference files

- Move lengthy examples and conditional domain detail to references; prefer 150-250 core lines (hard max 500)
- Multiple variants of the same pattern (e.g., GitHub Actions vs GitLab CI)
- Large checklists or template libraries
- Supplementary content that's only needed in specific scenarios

### Directory structure

```
skill-name/
+-- SKILL.md                    # main skill (required, 150-250 lines preferred)
+-- references/                 # deep-dive content (loaded on demand)
|   +-- foo.md                  # domain-specific reference
|   +-- bar.md                  # another reference
```

### Referencing from SKILL.md

```markdown
Read `references/foo.md` for detailed patterns.
```

Always include guidance on WHEN to read the reference, not just that it exists:

```markdown
Read `references/github-actions.md` for GitHub Actions patterns,
templates, and security hardening.
```

### One level deep

Name every reference file directly in SKILL.md. An agent that reaches a file through another
reference (`SKILL.md -> advanced.md -> details.md`) often previews it partially, for example with
`head -100`, and misses what sits lower down. Cross-links between references are fine as long as
SKILL.md also names the target. `scripts/lint-skills.sh` enforces this in this collection.

Organize by domain or variant (one `references/<platform>.md` per CI platform, say) so a
question about one never loads the other, and name files for their content, not `doc2.md`.

### Reference file headers

Reference files don't need frontmatter. Start with a `#` title. Files over 100 lines open with a
`## Contents` list of their sections so a partial read still sees the whole scope. Generate and
refresh it with `scripts/gen-ref-toc.py` rather than by hand; lint fails on a missing or stale
list. A hand-written `## Table of Contents` near the top is also accepted.

---

## 6. Cross-Skill Patterns

### "When NOT to use" section

Every custom skill should list adjacent skills that handle related but distinct tasks:

```markdown
## When NOT to use

- Kubernetes manifests, Helm charts - use **kubernetes**
- CI/CD pipeline design - use **ci-cd**
- Security audits of application code - use **security-audit**
```

Bold the skill name in each cross-reference (`**skill-name**`) so agents can parse them
as structured links. Use a single `-` before the skill reference, not parentheses.

### "Related Skills" section

For skills with complex relationships, add an explicit section explaining HOW skills relate:

```markdown
## Related Skills

- **ci-cd** - pipeline design that triggers on git events. This skill handles the
  git operations; ci-cd handles the pipeline that reacts to them.
- **code-review** - reviews code quality. This skill creates the PR/MR; code-review
  evaluates the code in it.
```

### Cross-skill reference rules

1. Ordinary routing targets must be active published (non-gitignored) skills. Explicit
   migration references may name deprecated notices. Use `git check-ignore -q` to filter
   private skills when git is available; existence alone does not establish active status.
2. Characterize the relationship: "use X for Y" (routing) vs "X does Y while this does Z" (explanation)
3. Compare only active skills for trigger overlap. If two active skills share trigger keywords,
   both must have "When NOT to use" entries pointing at each other

---

## 7. AI Self-Check Patterns

### When to include

Required for skills that generate code, config, manifests, infrastructure, or structured files
(including skill files). Not required for skills that only analyze or review existing content.

### Pattern

```markdown
## AI Self-Check

AI tools consistently produce the same [domain] mistakes. **Before returning any generated
[output type], verify against this list:**

- [ ] Check item 1
- [ ] Check item 2
```

### Common check categories by domain

| Domain | Key checks |
|--------|-----------|
| **Containers** | non-root user, no :latest, secrets not in layers, multi-stage build |
| **Kubernetes** | security context, resource limits, namespace explicit, no :latest |
| **CI/CD** | SHA-pinned actions, explicit permissions, no secrets in logs |
| **Git** | authorship correct, no secrets staged, no AI attribution, no --no-verify |
| **Databases** | no plaintext secrets, encryption at rest, audit logging, backup strategy |
| **General code** | no hardcoded secrets, input validation at boundaries, error propagation |

---

## 7.5 Diagnostic Skill Pitfalls

Skills that run commands, check health, or interpret system output have failure modes that
don't apply to code-review or config-generation skills. These patterns come from real false
positives in production health checks.

### Silent failure masking

Never use `2>/dev/null` on diagnostic commands. A permission error or SSH failure must surface
clearly, not be masked as "resource not found." The agent can't fix what it can't see.

**Bad:** `ssh node "ls /var/lib/snapshots" 2>/dev/null || echo "no snapshots"`
**Good:** `ssh node "ls /var/lib/snapshots" 2>&1` (then parse the error)

Acceptable uses of `2>/dev/null`: cleanup operations, cosmetic output trimming, optional tool
detection (`command -v foo 2>/dev/null`). Not acceptable: any command whose failure reason
matters for the diagnosis.

### Failure mode differentiation

When a check fails, report WHY, not just THAT it failed. "Unreachable" and "not present" are
different findings with different remediation paths.

| Failure | Looks like | Actually means |
|---------|-----------|----------------|
| SSH timeout | "resource missing" | network/firewall issue |
| Permission denied | "resource missing" | sudo needed, agent ran as wrong user |
| Empty output | "all clear" | command failed silently |
| Tool not found | "feature unavailable" | missing dependency |

### Metric misinterpretation

Document what each metric actually measures. Common traps:

- **LVM thin `data_percent`** = pool blocks currently allocated (reclaimable via discard/TRIM), not live filesystem usage and not a lifetime count of every block ever written
- **K8s HPA `targetCPU`** = percentage of CPU *request*, not actual CPU
- **Docker image size** = virtual size including shared layers, not disk footprint
- **`df` vs `du`** = filesystem allocation vs actual content size

When a skill uses a metric for status (GREEN/YELLOW/RED), state what the metric represents
and what it does NOT represent. Agents will misinterpret ambiguous metrics.

### Schedule-aware staleness

If a resource has a defined schedule (daily backups, weekly rotations, cron jobs), compare
recency against that schedule, not a fixed threshold. A 3-day-old backup is overdue for a
daily schedule but current for a weekly one. Skills should instruct the agent to read the
schedule before judging freshness.

### Agent improvisation in diagnostics

Agents improvise. They see a monitoring context and add their own checks - using wrong
service names, wrong paths, or wrong assumptions. The fix is twofold:

1. **Make the reference file comprehensive** so the agent doesn't feel compelled to freelance
2. **Add an explicit rule**: "Run ONLY the commands listed. Note missing coverage as a
   suggestion, don't execute it."

Negative constraints ("don't do X") are weak for LLMs. Comprehensive positive definitions
("do exactly these things") are the real defense.

---

## 7.6 Workflow Reliability Patterns

Use these where step order or output quality matters. Skip them for open-ended advice; a
checklist on order-independent work only adds tokens.

**Progress checklist.** For multi-step workflows where order matters, give a checklist the agent
copies into its reply and ticks off. Keep each item a goal, not a script, and add a short paragraph
per step below it:

```markdown
Copy this checklist and track progress:
- [ ] Step 1: Inventory the inputs
- [ ] Step 2: Draft the change
- [ ] Step 3: Validate (run the check; fix and repeat until it passes)
- [ ] Step 4: Verify the result against the original request
```

**Explicit loop-back.** A failing check must name where to go: "If validation fails, fix the
reported fields and return to Step 3." Without it, agents tick a failed step and move on.

**Validate-fix-repeat.** Pair generated output with a validator and loop until it passes. The
validator can be a script (`python scripts/validate.py out/`) or a reference the agent checks
against (a style guide, a voice document, a checklist). Proceed only when it passes.

**Plan-validate-execute.** For batch, destructive, or high-stakes operations, have the agent write
the intended changes to a structured file (`changes.json`), validate that plan, then apply and
verify. Make validator errors specific ("field 'signature_date' not found; available: ...").

**Templates and examples.** Say whether a template is strict ("use exactly this structure") or a
default ("adapt sections as needed"). When style matters more than structure, give 2-3
input/output pairs instead of describing the style.

**Conditional workflow.** At a decision point, route explicitly: "Creating new content? Follow
the creation workflow. Editing? Follow the editing workflow."

**Learning loop.** When a run fails for a reason the skill does not cover yet, the agent proposes
the missing rule at the end of the run; it lands only after the user approves (Mode 5).

## 7.7 Scripts and Dependencies

- **Prefer a script for deterministic or fragile operations.** It behaves the same on every model,
  costs no context to run (only its output is read), and saves regenerating code each time.
- **Say execute or read.** "Run `scripts/check.sh <dir>`" (execute) versus "see
  `scripts/check.sh` for the algorithm" (read). Execution is the default.
- **Solve, don't defer.** Scripts handle expected errors with a clear message or a safe default
  instead of crashing and leaving the agent to guess. Fail loud on real errors.
- **No unexplained constants.** Comment why a timeout, retry count, or threshold has its value.
- **Do not assume tools are installed.** List required tools in `compatibility` and put a detect
  or install line beside the step that needs it (`command -v jq || echo "install jq"`,
  `pip install pypdf`). An agent skips the install when the tool is present; a fresh machine
  works on day one.
- **Portable invocation.** Relative forward-slash paths from the skill directory; no
  harness-specific install paths.

## 7.8 Model Portability

Skills here run on several harnesses and model families, from small fast models to flagship
reasoning models. A skill's effect depends on the model reading it.

- **Name the tiers you target and test each one.** Small or fast tier: does the skill give enough
  guidance? Flagship tier: does it over-explain, or does output get worse than without the skill?
- **Fix the right way.** A step the small tier misses needs clearer wording or a script. An
  instruction the flagship does better without gets cut. Instructions written to force older
  models through steps (numbered micro-steps, ALL CAPS) often hurt current flagship models.
- **Compare against a no-skill baseline.** Content that does not beat the baseline on any test is
  a cut candidate.
- **Do not add a model field to frontmatter.** It is not part of the Agent Skills spec and unknown
  keys break some uploads. Record tested tiers in the review or refiner run report; use
  `compatibility` only for a real capability requirement (e.g., vision or a large context window).

---

## 8. Trigger Description Patterns

Write one paragraph of 80-170 characters: the task and distinguishing domain first, then the
requests, symptoms, or error text a user would actually type, then a short exclusion only where a
neighbor is easy to confuse. A terse list of distinctive terms beats full sentences; do not
restate the body, which the agent reads once the skill is chosen. Every entry shares the host's
catalog budget (Claude Code: about 1% of the context window, dropping whole descriptions when
over), so length costs every session. The opening should still choose the skill when a host
shortens the description.

```text
Review code and diffs for bugs, regressions, edge cases, races, and leaks. Use for "review this diff" or a pre-merge check. Not security.
Dockerfiles, Compose, Podman, BuildKit: build failures, networking, volumes, image size, multi-arch, signing, SBOMs, hardening. Not Kubernetes.
```

`validate-spec.sh` warns outside 80-170; the warning is advisory. The 1024-character spec
ceiling is a validation limit, not a guarantee that a host will display or load the whole
description. Hosts may shorten descriptions or omit entries to fit the combined catalog budget.

Test natural requests, aliases, and adjacent tasks against the active catalog. Test explicit
legacy invocations separately against notices; do not optimize notices into ordinary triggers.
Put detailed examples and exclusions in the body; retain a short exclusion in the description when it
prevents a likely wrong match. Describe the skill's actual scope without adding unsupported
capabilities to attract more requests.

Avoid vague descriptions ("Docker stuff"), exact-phrase-only triggers, generic words such as
"cleanup" without a domain, and duplicated `Triggers:` lists. Character counts measure
brevity; routing trials provide evidence about selection quality.

---

## 9. Skill Inventory (November 2026)

### Active skills (40)

| Skill | Effort | Date Added | Scope |
|---|---|---|---|
| ansible | high | 2026-03-24 | Ansible playbooks, roles, inventories, Vault, Molecule, AWX/AAP. Use for server config after provisioning, OS hardening, idempotency bugs, ansible-lint. |
| anti-ai-prose | medium | 2026-04-09 | Strip AI-sounding filler, hedging, and canned phrasing from docs, READMEs, emails, and PR bodies. Use when text sounds like ChatGPT. |
| arch-linux | high | 2026-03-26 | Arch, CachyOS, EndeavourOS, Manjaro admin: pacman, paru/AUR, keyrings, broken upgrades, .pacnew, boot, NVIDIA, Hyprland. |
| backend-api | high | 2026-04-06 | REST/HTTP API design and review, plus GraphQL, gRPC, and broker contracts: OpenAPI, errors, pagination, versioning, auth, retries, acks, DLQs. |
| ci-cd | high | 2026-03-24 | CI/CD pipelines and runners: GitHub Actions, GitLab CI, Forgejo/Gitea Actions, Woodpecker. Use for failing or flaky jobs, caching, SHA pinning. |
| code-review | high | 2026-03-25 | Review code and diffs for bugs, regressions, edge cases, races, and leaks. Use for "review this diff" or a pre-merge check. Not security. |
| code-simplification | medium | 2026-09-20 | Find dead code, duplication, overengineering, invented APIs, weak tests; report safe reductions, no edits. Use for "simplify this" or a refactor that lost behavior. |
| databases | high | 2026-03-24 | PostgreSQL, MySQL/MariaDB, MongoDB, MSSQL, Redis, Valkey: schemas, slow queries, EXPLAIN, indexes, migrations, replication, backups, upgrades. |
| debian-ubuntu | high | 2026-04-22 | Debian, Ubuntu, Mint, Pop!_OS, Kali admin: apt/dpkg errors, held packages, release upgrades, PPAs, kernels, drivers, systemd. |
| debug-triage | high | 2026-06-14 | Find the failing layer in an outage or post-deploy break, debug to root cause, profile slow code. Use for "it's down", 502s, timeouts, latency spikes. |
| dev-cycle | high | 2026-04-14 | Full feature workflow: branch, implement, check, review, PR, merge, release. Use for "let's add X" or "ship this". Single git steps go to git. |
| docker | high | 2026-03-24 | Dockerfiles, Compose, Podman, BuildKit: build failures, networking, volumes, image size, multi-arch, signing, SBOMs, hardening. Not Kubernetes. |
| ui-build | high | 2026-04-26 | Frontend UI: accessible components, responsive layouts, CSS, Tailwind, themes, interaction states. Use for building a page, dashboard, form, or dark mode. |
| git | high | 2026-03-24 | Git commits, branches, rebases, conflicts, reflog recovery, tags, releases, PRs/MRs on GitHub, GitLab, Forgejo, Gitea. Not code review. |
| i18n-localization | high | 2026-04-12 | App i18n: extract UI strings, locale catalogs, placeholders, missing keys, translation quality. Use for "add Spanish to the app". Not document translation. |
| kubernetes | high | 2026-03-24 | Kubernetes manifests, Helm, Kustomize, Gateway API, ArgoCD: probes, limits, RBAC, network policies, ingress, GitOps. Live health: kubernetes-health. |
| kubernetes-health | high | 2026-03-30 | Read-only live cluster health check: nodes, pods, events, storage, networking, GitOps sync. Use for "is the cluster healthy" or post-upgrade checks. |
| llm-app-development | high | 2026-04-02 | LLM apps: API calls, RAG, embeddings, vector stores, agents, tool calling, structured output, evals, fine-tuning, Ollama/vLLM. Use when adding AI features. |
| mcp | high | 2026-03-30 | Model Context Protocol servers and clients: tools, resources, prompts, stdio/HTTP transport, OAuth, tool poisoning. Use for writing a server or fixing a client. |
| networking | high | 2026-03-25 | Linux networking: DNS, reverse proxies, load balancers, WireGuard/VPNs, VLANs, nftables, routing, TLS, MTU, packet captures. Not firewall appliances. |
| nixos | high | 2026-04-23 | NixOS and Nix: configuration.nix, flakes, nixos-rebuild, Home Manager, nix-darwin, overlays, dev shells, sops-nix. Use for failing rebuilds, rollbacks. |
| observability | high | 2026-06-14 | Metrics, traces, logs, alerts, SLOs, dashboards: Prometheus, OpenTelemetry, Grafana. Use for instrumentation, noisy alerts, cardinality. Not live incidents. |
| opnsense-pfsense | high | 2026-03-30 | OPNsense and pfSense firewalls over SSH: pf rules, NAT, VLANs, Unbound, WireGuard, CARP failover, upgrades. Not plain Linux hosts. |
| plan-review | high | 2026-09-20 | Pressure-test a plan or decision before building: requirements, assumptions, risks. Use for "review my plan", "is this a good idea", architecture choices. |
| privilege-escalation | high | 2026-03-25 | Assess authorized Linux privilege escalation, container escapes, and post-exploitation paths in pentests and CTFs. |
| prompt-generator | medium | 2026-03-25 | Write or improve LLM prompts, system prompts, and prompt templates from rough notes. Use for "write me a prompt". Not skill files or SDK code. |
| repo-audit | high | 2026-09-20 | Whole-repo or PR audit across bugs, security, code quality, and docs, quick or exhaustive. Use for "audit this repo" or a pre-release check. |
| rhel-fedora | high | 2026-04-22 | Fedora, RHEL, Rocky, AlmaLinux, CentOS Stream, Amazon Linux: dnf/rpm, EPEL, SELinux AVC denials, firewalld, system-upgrade, dracut, GRUB, akmods. |
| roadmap | medium | 2026-04-05 | Private ROADMAP.md backlog: capture and rank feature ideas and competitor findings, mark shipped items. Use for "add to roadmap" or "what next". |
| security-audit | high | 2026-03-25 | Find vulnerabilities: auth flaws, injection, exposed secrets, OWASP, dependency and supply-chain risk. Use for a security review, secret scan, or release gate. |
| session-handoff | medium | 2026-06-13 | Write an agent session handoff: state, decisions, unfinished work, checks, next steps. Use for "hand this off" or a context window running out. |
| shell-scripting | medium | 2026-03-25 | Bash, Zsh, POSIX sh, Fish scripts, one-liners, dotfiles, completions. Use for quoting or globbing bugs, shellcheck warnings, porting between shells. |
| skill-creator | high | 2026-03-25 | Create or review agent skills: SKILL.md, frontmatter, references, trigger descriptions, overlaps. Use for "make a skill" or a skill that never triggers. |
| skill-refiner | high | 2026-03-31 | Improve skills over several rounds of scoring, behavioral tests, and cross-model review until a target score. Use for a pre-release polish sweep. |
| synology-dsm | high | 2026-07-27 | Synology DSM NAS over SSH: shares, packages, users, storage pools, RAID, crashed or read-only volumes, btrfs recovery, Container Manager. |
| terraform | high | 2026-03-24 | Terraform and OpenTofu: HCL, modules, providers, state moves, imports, backends, drift, policy. Use for a plan that replaces resources. Proxmox VMs: virtualization. |
| testing | high | 2026-04-02 | Unit, integration, E2E, load, and a11y tests: pytest, vitest/jest, Playwright, fixtures, mocks, coverage. Use for adding tests or fixing flaky suites. |
| update-docs | medium | 2026-03-25 | Update READMEs, changelogs, API docs, runbooks, and instruction files after changes; fix doc drift. Use for "update the docs" or a release sweep. |
| virtualization | high | 2026-04-02 | VMs and hypervisors: Proxmox, QEMU/KVM, libvirt, XCP-ng, VMware/ESXi; templates, cloud-init, storage, clustering, backups, GPU passthrough. |
| vulnerability-research | high | 2026-04-03 | Research vulnerabilities in authorized targets through code analysis, reverse engineering, patch diffing, and fuzzing. |

Deprecated notices are migration aids, excluded from the active inventory above but included
in published totals and migration-test coverage. Derive all counts from the live collection.

This inventory is a snapshot of the upstream iuliandita/skills collection. Treat it as a
reference example for convention compliance, not as an authoritative list for other repos.
When auditing a different collection, build the inventory from that collection's actual contents.
`date_added` reflects local creation date, which may predate or postdate the first commit
to a public repo depending on the maintainer's sync workflow.
