# Skill Convention Reference

Complete reference for the conventions established across the custom skill collection. Use this
when creating or reviewing skills to ensure consistency.

---

## Table of Contents

1. Frontmatter
2. Structural Patterns
3. Style Rules
4. Reference File Organization
5. Cross-Skill Patterns
6. AI Self-Check Patterns
7. Trigger Description Patterns
8. Skill Inventory (March 2026)

---

## 1. Frontmatter

### Required fields (custom skills)

```yaml
---
name: skill-name              # lowercase, hyphens, max 64 chars
description: >                # max 1024 chars, trigger-optimized
  Use when... Also use for... Triggers: '...', '...'.
source: custom                # always "custom" for local skills
date_added: "YYYY-MM-DD"     # ISO date, quoted
effort: low|medium|high       # determines expected complexity/token usage
---
```

### Optional fields

```yaml
allowed-tools: Read, Bash, Grep, Glob  # restrict which tools the skill can use
```

### Field definitions

| Field | Values | Purpose |
|-------|--------|---------|
| `name` | lowercase + hyphens | identifier, directory name, display name |
| `description` | free text, <1024 chars | primary trigger mechanism -- Claude scans this |
| `source` | `custom` | identifies locally maintained skills |
| `date_added` | ISO date string | staleness detection |
| `effort` | `low`, `medium`, `high` | signals expected token usage and complexity |

### Effort tiers

| Tier | Token usage | Typical skills | Structure depth |
|------|-------------|---------------|-----------------|
| **low** | <5k tokens | lightpanda, update-docs, update-skills | Minimal workflow, few rules |
| **medium** | 5-15k tokens | anti-slop, prompt-generator, zsh | Moderate workflow, reference files |
| **high** | 15k+ tokens | ansible, ci-cd, code-review, databases, docker, full-review, git, kubernetes, opnsense, security-audit, skill-creator, terraform | Full workflow, AI self-check, checklists, multiple references |

### Plugin skills (for reference)

Anthropic plugin skills (pdf, docx, pptx, xlsx) use `license:` instead of source/effort fields.
Don't enforce custom conventions on these -- they follow their own upstream standards.

---

## 2. Structural Patterns

### High-effort skills (the infrastructure pattern)

All high-effort custom skills follow this pattern:

```
# Title: Domain Description

Overview paragraph. Goal statement.

**Target versions** (Month Year):
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

## Rules (optional)
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

## 3. Style Rules

### Text

- **Imperative form**: "Check the config", not "You should check the config"
- **Plain ASCII**: no em-dashes (use `--`), no curly quotes, no ligatures
- **Explain why**: "Pin images to SHA256 digests because mutable tags are a proven attack vector
  (Trivy March 2026, tj-actions March 2025)" beats "Always pin images"
- **Calm directives**: "Do X" outperforms "YOU MUST ALWAYS DO X" on Claude 4.x. Use ALL CAPS
  only for genuinely critical safety constraints, not for emphasis.
- **Banned words**: per global CLAUDE.md -- "delve", "navigate" (metaphorical), "landscape"
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

## 4. Reference File Organization

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
Read `${CLAUDE_SKILL_DIR}/references/foo.md` for detailed patterns.
```

Always include guidance on WHEN to read the reference, not just that it exists:

```markdown
Read `${CLAUDE_SKILL_DIR}/references/github-actions.md` for GitHub Actions patterns,
templates, and security hardening.
```

### Reference file headers

Reference files don't need frontmatter. Start with a `#` title and optionally a table of
contents for files over 300 lines.

---

## 5. Cross-Skill Patterns

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

1. Every skill name you mention must correspond to an actual directory in `~/.claude/skills/`
2. Characterize the relationship: "use X for Y" (routing) vs "X does Y while this does Z" (explanation)
3. If two skills share trigger keywords, both must have "When NOT to use" entries pointing at each other

---

## 6. AI Self-Check Patterns

### When to include

Required for skills that generate code, config, manifests, or infrastructure. Not required for
skills that only analyze, review, or transform existing content.

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

## 7. Trigger Description Patterns

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

## 8. Skill Inventory (March 2026)

### Custom skills (22)

| Skill | Effort | Date Added | Domain |
|-------|--------|-----------|--------|
| ansible | high | 2026-03-24 | Configuration management |
| anti-slop | medium | 2026-03-25 | Code quality audit |
| ci-cd | high | 2026-03-24 | CI/CD pipelines |
| cluster-health | high | 2026-03-25 | K8s cluster diagnostics |
| code-review | high | 2026-03-25 | Correctness audit |
| command-prompt | medium | 2026-03-25 | Shell scripting and config |
| databases | high | 2026-03-24 | Database operations |
| docker | high | 2026-03-24 | Containers |
| full-review | high | 2026-03-22 | Orchestrator (4 parallel audits) |
| git | high | 2026-03-24 | Version control, multi-forge |
| kubernetes | high | 2026-03-24 | K8s manifests, Helm, architecture |
| lightpanda | low | 2026-03-22 | Headless browser via MCP |
| linux-privilege-escalation | high | 2026-02-27 | Privilege escalation assessment |
| lockpick | high | 2026-03-25 | Post-exploitation, CTF, pivoting |
| networking | high | 2026-03-25 | DNS, reverse proxies, VPNs, nftables, HA |
| opnsense | high | 2026-03-19 | Firewall management (FreeBSD) |
| prompt-generator | medium | 2026-03-25 | LLM prompt structuring |
| security-audit | high | 2026-03-25 | Application security review |
| skill-creator | high | 2026-03-25 | Skill lifecycle management |
| terraform | high | 2026-03-24 | Infrastructure-as-code |
| update-docs | low | 2026-03-25 | Documentation sweep |
| update-skills | low | 2026-03-18 | Skill update management |

### Plugin skills (4)

| Skill | Source | Domain |
|-------|--------|--------|
| docx | Anthropic plugin | Word documents |
| pdf | Anthropic plugin | PDF processing |
| pptx | Anthropic plugin | PowerPoint presentations |
| xlsx | Anthropic plugin | Spreadsheets |

### Superpowers skills (reference only)

These are installed but should NOT be auto-triggered when a custom skill covers the same domain:

| Superpowers Skill | Custom Equivalent | When to use superpowers instead |
|-------------------|-------------------|-------------------------------|
| skill-creator | **skill-creator (this skill)** | Only if user explicitly asks for benchmark evaluation with parallel test agents |
| code-reviewer | code-review, full-review | Only if user explicitly asks for superpowers review |
| brainstorming | -- (no custom equivalent) | Creative feature design, always manual |
| writing-plans | -- (no custom equivalent) | Multi-step implementation planning, always manual |
| executing-plans | -- (no custom equivalent) | Plan execution with review checkpoints, always manual |
| test-driven-development | -- (no custom equivalent) | TDD workflow, always manual |
| verification-before-completion | -- (no custom equivalent) | Pre-completion verification, always manual |

Custom skills are preferred because they encode domain-specific conventions, PCI-DSS awareness,
version currency, and the user's established patterns. Superpowers skills are generic and don't
know about this collection's conventions.
