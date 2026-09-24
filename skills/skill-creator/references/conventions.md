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
8. Trigger Description Patterns
9. Skill Inventory (September 2026)

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
| Frontmatter (`name` + `description`) | description usually 80-120 characters | catalog entries share the host's context budget |
| SKILL.md body | 150-250 lines preferred, 600 hard max, <5k tokens recommended | loaded when the skill activates |
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
description: >                # aim for 80-120 chars; advisory warning above 120
  Write and debug shell scripts, commands, and dotfiles for bash, zsh, sh, and fish.
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
- Antigravity CLI `agy -p`/`--print` (replaced Gemini CLI, deprecated 2026-06-18)
- OpenCode `opencode run`, Command Code `cmd -p`, Oh My Pi `omp -p`, Hermes `hermes chat -q`

Skills should not assume interactive prompting is always available. If a skill needs user input
at a decision point, provide a sensible default or document the assumption. Avoid blocking on
user confirmation in steps that could run unattended.

### Field definitions

| Field | Values | Purpose |
|-------|--------|---------|
| `name` | `a-z`, `0-9`, hyphens; no leading/trailing/consecutive hyphens; max 64 chars. `anthropic`/`claude` are Anthropic platform-reserved, not barred by the portable spec - avoid them | identifier, must match directory name |
| `description` | free text, usually 80-120 chars, warn above 120, 1024 spec max, no XML tags | primary trigger mechanism - the agent scans this |
| `license` | license name (e.g., `MIT`) | Agent Skills spec field |
| `compatibility` | free text, <500 chars | environment requirements (optional) |
| `metadata.source` | `owner/repo` or `custom` | identifies the publishing collection or an unpublished local skill |
| `metadata.date_added` | ISO date string | staleness detection |
| `metadata.effort` | `low`, `medium`, `high` | signals expected token usage and complexity |

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
count. The SKILL.md body targets 150-250 lines where practical (600 hard max); references carry the
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
- **Approved non-ASCII**: output-contract/status emoji markers the linter permits (U+1F534, U+1F7E0, U+1F7E2,
  U+1F7E1, U+1F535, U+26AA, U+26A1, U+1F3AF, U+1F480). `scripts/lint-skills.sh`
  (`check_ascii`) is the single authority on this set; this list mirrors it and changes only
  when the linter does, never the reverse.
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

- Move lengthy examples and conditional domain detail to references; prefer 150-250 core lines (hard max 600)
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

### Reference file headers

Reference files don't need frontmatter. Start with a `#` title and optionally a table of
contents for files over 300 lines.

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

## 8. Trigger Description Patterns

Put the task and distinguishing domain first. Use a few meaningful terms once in natural
prose; repeated keyword lists spend catalog space without adding scope. The first clause
should help choose the skill even when a host shortens the description.

```text
Review code and diffs for correctness: bugs, regressions, edge cases, races, and resource leaks.
Write or improve one-off LLM prompts, system prompts, and prompt templates from rough notes.
Check live Kubernetes cluster health with read-only diagnostics for nodes, pods, and storage.
```

Aim for 80-120 characters with useful task terms first. The 120-character warning is advisory;
a useful boundary can justify extra text. The 1024-character spec ceiling is a validation
limit, not a guarantee that a host will display or load the whole description. Hosts may
shorten descriptions or omit entries to fit the combined catalog budget.

Test natural requests, aliases, and adjacent tasks against the active catalog. Test explicit
legacy invocations separately against notices; do not optimize notices into ordinary triggers.
Put detailed examples and exclusions in the body; retain a short exclusion in the description when it
prevents a likely wrong match. Describe the skill's actual scope without adding unsupported
capabilities to attract more requests.

Avoid vague descriptions ("Docker stuff"), exact-phrase-only triggers, generic words such as
"cleanup" without a domain, and duplicated `Triggers:` lists. Character counts measure
brevity; routing trials provide evidence about selection quality.

---

## 9. Skill Inventory (September 2026)

### Active skills (43)

| Skill | Effort | Date Added | Scope |
|---|---|---|---|
| ansible | high | 2026-03-24 | Write, review, and debug Ansible playbooks, roles, inventories, Ansible Vault, Molecule tests, and AWX/AAP. |
| anti-ai-prose | medium | 2026-04-09 | Edit prose that sounds AI-written: remove filler and canned phrasing in docs, emails, and replies. |
| arch-linux | high | 2026-03-26 | Administer Arch Linux, CachyOS, EndeavourOS, and Manjaro: pacman, AUR, upgrades, boot, GPU, and desktop issues. |
| backend-api | high | 2026-04-06 | Design and review REST/HTTP APIs, with bounded GraphQL and gRPC contract guidance: OpenAPI, auth, pagination, compatibility, and retries. |
| ci-cd | high | 2026-03-24 | Build, review, and debug CI/CD pipelines and runners: GitHub Actions, GitLab CI, Forgejo/Gitea, and Woodpecker. |
| code-review | high | 2026-03-25 | Review code and diffs for correctness: bugs, regressions, edge cases, races, and resource leaks. |
| code-simplification | medium | 2026-09-20 | Review code for dead code, duplication, overengineering, invented APIs, and weak tests. Report safe reductions; no edits. |
| databases | high | 2026-03-24 | Design schemas, tune queries, migrate, and administer PostgreSQL, MySQL/MariaDB, MongoDB, MSSQL, Redis, and Valkey. |
| debian-ubuntu | high | 2026-04-22 | Administer Debian, Ubuntu, Mint, and Pop!_OS: apt, dpkg, upgrades, boot, drivers, and desktop issues. |
| debug-triage | high | 2026-06-14 | Triage live outages when the failing component is unknown; localize the fault and route further debugging. |
| dev-cycle | high | 2026-04-14 | Run a requested full development workflow: branch, implement, check, review, PR, merge, and release. |
| docker | high | 2026-03-24 | Build and debug Dockerfiles, Compose, Docker/Podman containers, and BuildKit images; review container security. |
| frontend-design | high | 2026-04-26 | Design, build, and critique frontend UI/UX: layouts, CSS, Tailwind, landing pages, and visual polish. |
| git | high | 2026-03-24 | Manage git commits, branches, conflicts, rebases, PRs/MRs, tags, releases, and GitHub/GitLab/Forgejo/Gitea workflows. |
| i18n-localization | high | 2026-04-12 | App i18n only, not standalone translation: localize UI catalogs, validate placeholders, and audit missing locale keys. |
| kali-linux | high | 2026-04-22 | Administer Kali Linux: packages, metapackages, rolling upgrades, live USB persistence, and NetHunter. |
| kubernetes | high | 2026-03-24 | Build and review Kubernetes/K8s manifests, Helm charts, Kustomize overlays, Gateway API, and ArgoCD deployments. |
| kubernetes-health | high | 2026-03-30 | Check live Kubernetes cluster health with read-only diagnostics: nodes, pods, storage, networking, and GitOps. |
| llm-app-development | high | 2026-04-02 | Build LLM applications: RAG, embeddings, agents, structured outputs, evaluations, fine-tuning, and local inference. |
| mcp | high | 2026-03-30 | Build and debug Model Context Protocol (MCP) servers, clients, tools, resources, and OAuth integrations. |
| message-queues | high | 2026-09-20 | Design, diagnose, and safely operate brokered delivery with Kafka, RabbitMQ, and compatible queues: acknowledgements, retries, dead letters, ordering, lag, and replay. |
| networking | high | 2026-03-25 | Configure and debug Linux networking: DNS, reverse proxies, VPNs, WireGuard, VLANs, nftables, and routing. |
| nixos | high | 2026-04-23 | Administer NixOS and Nix: flakes, Home Manager, nix-darwin, generations, overlays, and declarative configuration. |
| observability | high | 2026-06-14 | Instrument, audit, and debug telemetry: metrics, traces, logs, alerts, SLOs, Prometheus, OpenTelemetry, Grafana. |
| opnsense-pfsense | high | 2026-03-30 | Administer OPNsense and pfSense firewalls: pf rules, VPNs, CARP failover, upgrades, and SSH diagnostics. |
| performance-debugging | high | 2026-09-20 | Diagnose a known application's CPU, heap, allocation, lock, and latency regressions with profiles, reproducible baselines, and measured verification. |
| plan-review | high | 2026-09-20 | Review product, business, and engineering decisions and plans: clarify requirements, challenge assumptions, and assess risks. |
| privilege-escalation | high | 2026-03-25 | Assess authorized Linux privilege escalation, container escapes, and post-exploitation paths in pentests and CTFs. |
| prompt-generator | medium | 2026-03-25 | Write or improve one-off LLM prompts, system prompts, and prompt templates from rough notes. |
| repo-audit | high | 2026-09-20 | Audit repositories or PRs for bugs, security, code quality, and docs: quick review or exhaustive domain coverage. |
| rhel-fedora | high | 2026-04-22 | Administer Fedora/RHEL, Rocky, AlmaLinux, CentOS, and Amazon Linux: dnf, SELinux, boot, and desktop issues. |
| roadmap | medium | 2026-04-05 | Capture and prioritize feature ideas and competitor findings in a private ROADMAP.md backlog. |
| security-audit | high | 2026-03-25 | Audit code for vulnerabilities: auth flaws, exposed secrets, OWASP risks, and dependency/supply-chain threats. |
| session-handoff | medium | 2026-06-13 | Write an agent session handoff with current state, decisions, unfinished work, verification, and next steps. |
| shell-scripting | medium | 2026-03-25 | Write and debug Bash, Zsh, POSIX sh, and Fish scripts, commands, quoting, dotfiles, and shell completions. |
| skill-creator | high | 2026-03-25 | Create or review skills; fix descriptions, triggers, frontmatter, references, and collection overlaps. |
| skill-refiner | high | 2026-03-31 | Improve skills through repeated scoring, behavioral tests, and peer review toward a requested quality target. |
| synology-dsm | high | 2026-07-27 | Administer Synology DSM NAS over SSH: shares, packages, storage pools, crashed volumes, and btrfs recovery. |
| terraform | high | 2026-03-24 | Write and review Terraform/OpenTofu infrastructure: HCL, modules, state, providers, and policy checks. |
| testing | high | 2026-04-02 | Write unit, integration, E2E, load, and accessibility tests; debug fixtures, mocks, coverage, and flaky suites. |
| update-docs | medium | 2026-03-25 | Update README, changelogs, API docs, and runbooks after changes; find and fix documentation drift. |
| virtualization | high | 2026-04-02 | Manage VMs: Proxmox, QEMU/KVM, libvirt, XCP-ng, VMware/ESXi; debug hypervisors, storage, and GPU passthrough. |
| vulnerability-research | high | 2026-04-03 | Research vulnerabilities in authorized targets through code analysis, reverse engineering, patch diffing, and fuzzing. |

Deprecated notices are migration aids, excluded from the active inventory above but included
in published totals and migration-test coverage. Derive all counts from the live collection.

This inventory is a snapshot of the upstream iuliandita/skills collection. Treat it as a
reference example for convention compliance, not as an authoritative list for other repos.
When auditing a different collection, build the inventory from that collection's actual contents.
`date_added` reflects local creation date, which may predate or postdate the first commit
to a public repo depending on the maintainer's sync workflow.
