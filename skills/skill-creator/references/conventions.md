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
8. Trigger Description Patterns
9. Skill Inventory (March 2026)

---

## 1. Design Principles

Two principles that should guide every decision when writing or reviewing skills.

### Context budget

The context window is a shared resource. Every token a skill consumes is a token unavailable for
conversation history, other skills' metadata, tool results, and the actual user request. Treat
skill content like code in a hot loop -- every line should justify its presence.

**The test:** for each paragraph, ask "does this tell the agent something it doesn't already know?"
If the answer is no, cut it. Models are smart. They don't need explanations of what YAML is or
how to run `kubectl apply`. They need the non-obvious stuff: your team's naming conventions, the
gotcha with that specific Helm chart version, the compliance requirement that isn't in any docs.

**Quantitative limits** (these exist to enforce the principle, not replace it):

| Component | Budget | Why |
|-----------|--------|-----|
| Frontmatter (`name` + `description`) | ~100 tokens | always loaded for all skills at startup |
| SKILL.md body | <500 lines, <5k tokens recommended | loaded when the skill activates |
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
- **High freedom**: code-review workflow -- "check these ten buckets" gives categories but lets the
  agent decide what matters for each codebase
- **Medium freedom**: docker AI Self-Check -- specific checklist items but the agent decides how to
  apply them to the user's Dockerfile
- **Low freedom**: firewall-appliance pfctl commands -- exact syntax because a wrong flag can lock
  you out of a remote appliance

When in doubt, start with higher freedom and tighten only where you've seen the agent consistently
get it wrong. Over-constraining a skill makes it brittle and harder to maintain.

---

## 2. Frontmatter

### Required fields (custom skills)

```yaml
---
name: skill-name              # lowercase a-z, 0-9, hyphens; no leading/trailing/consecutive hyphens; max 64 chars; must match directory name; no reserved words (anthropic, claude)
description: >                # max 1024 chars, trigger-optimized
  Use when... Also use for... Triggers: '...', '...'.
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
allowed-tools: Read, Bash, Grep, Glob  # restrict which tools the skill can use
paths:                                  # activate only when matching files exist (YAML list of globs)
  - "Dockerfile*"
  - "compose*.yml"
```

### `paths:` frontmatter

Some tools (Claude Code v2.1.84+ (March 2026)) support `paths:` as a YAML list of globs in
skill frontmatter to activate the skill only when matching files exist in the project. This is
useful for domain-specific skills (e.g., `docker` only when `Dockerfile` exists). The `paths:`
field existed for rules since v2.0.64 but v2.1.84 extended it to skills and upgraded from
single-glob to YAML list. It's optional and ignored by tools that don't support it -- safe to
include for progressive enhancement.

### Headless / scripted execution

Skills may run in headless contexts where no interactive user is available:
- Claude Code `--bare` flag (no hooks, no skill directory walk)
- Cursor Automations (event-triggered, no user prompt)
- Codex `exec` mode (non-interactive)

Skills should not assume interactive prompting is always available. If a skill needs user input
at a decision point, provide a sensible default or document the assumption. Avoid blocking on
user confirmation in steps that could run unattended.

### Field definitions

| Field | Values | Purpose |
|-------|--------|---------|
| `name` | `a-z`, `0-9`, hyphens; no leading/trailing/consecutive hyphens; max 64 chars; no reserved words (`anthropic`, `claude`) | identifier, must match directory name |
| `description` | free text, <1024 chars, no XML tags | primary trigger mechanism -- the agent scans this |
| `license` | license name (e.g., `MIT`) | Agent Skills spec field |
| `compatibility` | free text, <500 chars | environment requirements (optional) |
| `metadata.source` | `custom` | identifies locally maintained skills |
| `metadata.date_added` | ISO date string | staleness detection |
| `metadata.effort` | `low`, `medium`, `high` | signals expected token usage and complexity |

### Effort tiers

| Tier | Token usage | Typical skills | Structure depth |
|------|-------------|---------------|-----------------|
| **low** | <5k tokens | update-docs | Minimal workflow, few rules |
| **medium** | 5-15k tokens | anti-slop, prompt-generator, command-prompt | Moderate workflow, reference files |
| **high** | 15k+ tokens | ansible, docker, kubernetes, terraform, etc. (see Skill Inventory) | Full workflow, AI self-check, checklists, multiple references |

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
## Rules                         # non-negotiable constraints
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

---

## 4. Style Rules

### Text

- **Imperative form**: "Check the config", not "You should check the config"
- **Plain ASCII**: no em-dashes (use `--`), no curly quotes, no ligatures
- **Explain why**: "Pin images to SHA256 digests because mutable tags are a proven attack vector
  (Trivy March 2026, tj-actions March 2025)" beats "Always pin images"
- **Calm directives**: "Do X" outperforms "YOU MUST ALWAYS DO X" on most modern coding agents. Use ALL CAPS
  only for genuinely critical safety constraints, not for emphasis.
- **Banned words**: per the collection's instruction file -- "delve", "navigate" (metaphorical), "landscape"
  (metaphorical), "tapestry", "nuanced", "multifaceted", "utilize", "robust", "innovative",
  "cutting-edge", "certainly!", "absolutely", etc. ("best practices" is allowed -- it's
  standard IT terminology.)
- **Anti-hallucination**: every tool name, CLI flag, version number, and API endpoint must be
  verified via web search or registry check before including in a skill. AI models hallucinate
  these constantly. "I'm pretty sure" is not verification -- search or don't include it.

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

- SKILL.md approaching 500 lines -> extract domain-specific content to references
- Multiple variants of the same pattern (e.g., GitHub Actions vs GitLab CI)
- Large checklists or template libraries
- Supplementary content that's only needed in specific scenarios

### Directory structure

```
skill-name/
+-- SKILL.md                    # main skill (required, <500 lines)
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

- Kubernetes manifests, Helm charts (use kubernetes)
- CI/CD pipeline design (use ci-cd)
- Security audits of application code (use security-audit)
```

### "Related Skills" section

For skills with complex relationships, add an explicit section explaining HOW skills relate:

```markdown
## Related Skills

- **ci-cd** -- pipeline design that triggers on git events. This skill handles the
  git operations; ci-cd handles the pipeline that reacts to them.
- **code-review** -- reviews code quality. This skill creates the PR/MR; code-review
  evaluates the code in it.
```

### Cross-skill reference rules

1. Every skill name you mention must correspond to a published (non-gitignored) skill in the
   collection. Use `git check-ignore -q` to filter private skills when git is available.
2. Characterize the relationship: "use X for Y" (routing) vs "X does Y while this does Z" (explanation)
3. If two skills share trigger keywords, both must have "When NOT to use" entries pointing at each other

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

## 8. Trigger Description Patterns

### High-performing patterns (from the custom collection)

**Start with action verbs:**
```
Use when writing, reviewing, or architecting...
```

**Include specific trigger keywords:**
```
Triggers: 'docker', 'dockerfile', 'compose', 'container', 'podman'...
```

**Mention adjacent contexts:**
```
Also use for Podman, Buildah, Skopeo, containerd, BuildKit, image signing, SBOM generation...
```

**Include negative routing:**
```
Not for style/slop audits (use anti-slop).
```

**Be pushy on edge cases:**
```
Use this skill even when the user doesn't explicitly say "git" but is clearly doing git work
(e.g., "push this", "cut a release", "create a PR").
```

### Anti-patterns

- **Too vague**: "Use for Docker stuff" -- no specific triggers
- **Too narrow**: "Use only when the user says 'write a Dockerfile'" -- misses most use cases
- **No differentiation**: shares all keywords with another skill, no routing guidance
- **Over 1024 chars**: gets truncated by the system

---

## 9. Skill Inventory (March 2026)

### Published skills (21)

| Skill | Effort | Date Added | Domain |
|-------|--------|-----------|--------|
| ansible | high | 2026-03-24 | Configuration management |
| anti-slop | medium | 2026-03-25 | Code quality audit |
| arch-btw | high | 2026-03-26 | Arch Linux / CachyOS administration |
| ci-cd | high | 2026-03-24 | CI/CD pipelines |
| code-review | high | 2026-03-25 | Correctness audit |
| command-prompt | medium | 2026-03-25 | Shell scripting and config |
| databases | high | 2026-03-24 | Database operations |
| docker | high | 2026-03-24 | Containers |
| firewall-appliance | high | 2026-03-30 | OPNsense/pfSense firewall management |
| full-review | high | 2026-03-22 | Orchestrator (4 parallel audits) |
| git | high | 2026-03-24 | Version control, multi-forge |
| kubernetes | high | 2026-03-24 | K8s manifests, Helm, architecture |
| lockpick | high | 2026-03-25 | Post-exploitation, CTF, pivoting |
| mcp | high | 2026-03-30 | MCP server development |
| networking | high | 2026-03-25 | DNS, reverse proxies, VPNs, nftables, HA |
| prompt-generator | medium | 2026-03-25 | LLM prompt structuring |
| security-audit | high | 2026-03-25 | Application security review |
| skill-refiner | high | 2026-03-31 | Iterative self-improvement loop |
| skill-creator | high | 2026-03-25 | Skill lifecycle management |
| terraform | high | 2026-03-24 | Infrastructure-as-code |
| update-docs | low | 2026-03-25 | Documentation sweep |

This inventory is a snapshot of the upstream iuliandita/skills collection. It serves as a
reference example for convention compliance, not as an authoritative list for other repos.
When auditing a different collection, build the inventory from that collection's actual contents.
`date_added` reflects local creation date, which may predate or postdate the first commit
to a public repo depending on the maintainer's sync workflow.
