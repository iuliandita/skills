---
name: skill-creator
description: >
  Create new skills, review and improve existing skills, audit the skill collection for consistency,
  check for overlaps and contradictions, validate versions and security references, and optimize
  skill descriptions for better triggering. Use when the user asks to create a skill, check a skill,
  analyze skills, test a skill, optimize a skill, improve a skill, audit skills, review skills, fix
  a skill, update skill metadata, validate skills, or anything involving skill files in a shared skill collection.
  Also trigger on: 'skill', 'SKILL.md', 'skill creator', 'new skill', 'check skill', 'skill audit',
  'skill review', 'skill test', 'skill quality', 'frontmatter', 'trigger description', 'skill overlap'.
  Prefer this skill for dedicated skill-file work instead of generic brainstorming or planning workflows.
license: MIT
metadata:
  source: custom
  date_added: "2026-03-25"
  effort: high
---

# Skill Creator: Meta Skill for Skill Lifecycle Management

Create, review, improve, audit, and maintain AI tool skills. Covers the full lifecycle from
initial draft through quality validation, cross-skill consistency checks, and trigger optimization.

This skill enforces the conventions established across the custom skill collection. It exists
because consistency is what makes skills predictable -- a skill that follows the established
patterns activates reliably, reads clearly, and plays well with the rest of the collection.

## When to use

- Creating a new custom skill from scratch
- Reviewing or improving an existing skill
- Auditing the skill collection for consistency, overlaps, or contradictions
- Validating versions, security references, or CVE mentions in skills
- Optimizing a skill's description for better triggering accuracy
- Checking cross-skill references and "Related Skills" sections
- Troubleshooting why a skill isn't triggering or is triggering incorrectly

## When NOT to use

- Syncing or refreshing third-party skills from upstream -- handle that directly in the repo workflow
- Writing application code, even if the code is for a tool a skill might use
- Creating inline prompts within application code (use prompt-generator)

---

## AI Self-Check

Before returning any generated or modified skill, verify against this list:

- [ ] **Frontmatter complete**: `name`, `description`, `source: custom`, `date_added` (ISO), `effort` (low/medium/high)
- [ ] **Description is trigger-optimized**: starts with action verbs, includes trigger keywords, mentions related contexts, stays under 1024 chars
- [ ] **"When to use" section present**: concrete scenarios, not abstract descriptions
- [ ] **"When NOT to use" section present**: cross-references related skills by name
- [ ] **Workflow section with numbered steps**: clear, sequential, actionable
- [ ] **Rules section at the end**: non-negotiable constraints in imperative form
- [ ] **No banned words** from the collection's instruction file (`AGENTS.md` or equivalent)
- [ ] **Plain ASCII only**: no em-dashes, curly quotes, ligatures -- use `--` for dashes
- [ ] **Under 500 lines**: if approaching limit, extract to `references/` with clear pointers
- [ ] **Reference files use `references/` relative paths**: not hardcoded or tool-specific paths
- [ ] **Tools verified as real**: every tool, CLI, library, or platform named in the skill was
  confirmed to exist via web search or registry check -- not assumed from training data
- [ ] **CLI flags and options verified**: every flag, subcommand, and option in example commands
  was confirmed against the tool's actual docs or `--help` output. AI models invent plausible
  but nonexistent flags constantly (e.g., `--output-format` vs `--format`, `--level` on tools
  that don't support it)
- [ ] **Version numbers verified and dated**: searched the web for latest stable version of each
  tool, pinned with date (e.g., "v29.3.0 (March 2026)") so staleness is detectable
- [ ] **No deprecated/renamed tools**: checked that referenced tools haven't been replaced or EOL'd
- [ ] **IaC resources and providers verified**: Terraform providers, resource types, and argument
  names confirmed against registry docs. Ansible module names, parameters, and return values
  checked against `ansible-doc` or Galaxy. Helm chart values confirmed against upstream
  `values.yaml`. K8s API fields confirmed against the target API version. AI hallucinates
  provider arguments, module parameters, and resource fields just as readily as CLI flags.
- [ ] **Example commands actually work**: spot-checked that example commands, config snippets,
  and API calls use correct syntax -- not just "looks right" but confirmed against docs
- [ ] **Cross-skill references are valid**: every mentioned skill name actually exists
- [ ] **AI-age awareness**: if the skill generates code or config, include an AI self-check section

---

## Workflow

### Mode 1: Create a New Skill

#### Step 1: Capture intent

Understand what the skill should do. Extract from conversation context:
- **Core task**: what should the skill enable?
- **Trigger scenarios**: what user phrases or contexts should activate it?
- **Output format**: what does success look like?
- **Related skills**: which existing skills overlap or complement this one?

If the user already described the workflow in the conversation (e.g., "turn what we just did into a
skill"), extract the steps, tools used, corrections made, and patterns observed.

#### Step 2: Research the domain

Before drafting, gather context:
1. **Check existing skills** for overlap -- read the "When to use" / "When NOT to use" of
   potentially related skills. Don't create a skill that duplicates existing coverage.
2. **Verify tools exist** -- for every tool, library, CLI, or platform the skill references,
   confirm it exists, is not deprecated or renamed, and is actively maintained. Search the web
   or check the project's GitHub/registry page. AI models hallucinate tool names, flag names,
   and API endpoints -- treat every claim as unverified until checked. If a tool was replaced
   (e.g., CDKTF -> HCL, Ingress -> Gateway API), reference the replacement.
3. **Check versions** -- search for the latest stable release of every tool mentioned. Don't
   guess or rely on training data -- versions go stale fast. Pin them with dates so staleness
   is detectable later (e.g., "Docker Engine 29.3.0 (March 2026)").
4. **Check security** -- search for recent CVEs, supply chain incidents, or known vulnerabilities
   relevant to the domain. The custom skill collection tracks these actively (e.g., Trivy
   CVE-2026-33634, runc CVE-2025-31133, MCP CVEs).
5. **Check compliance** -- if the domain touches infrastructure, containers, CI/CD, auth, or data
   handling, consider PCI-DSS 4.0 relevance. Many users work in regulated environments or run
   self-hosted infrastructure where compliance matters.

#### Step 3: Draft the skill

Follow the conventions in `references/conventions.md`. Key structural elements:

```markdown
---
name: skill-name
description: >
  Trigger-optimized description. Start with action verbs.
  Include specific trigger keywords. Under 1024 chars.
source: custom
date_added: "YYYY-MM-DD"
effort: low|medium|high
---

# Title: Domain Description

One-paragraph overview. What it does, what the goal is.

**Target versions** (Month Year):   <-- for tool/platform skills
- Tool: version

## When to use
## When NOT to use

---

## AI Self-Check                    <-- for skills that generate code/config

- [ ] Checklist items

---

## Workflow

### Step 1: ...
### Step 2: ...

---

## [Domain-specific sections]

---

## Reference Files                  <-- if references/ exist

- `references/<topic-file>` -- description

## Related Skills                   <-- cross-references

- **skill-name** -- how it relates

## Rules                            <-- non-negotiable constraints

1. Rule one.
2. Rule two.
```

**Writing guidelines:**
- Imperative form in instructions ("Check the config", not "You should check the config")
- Explain **why**, not just **what** -- models generalize from motivation
- Don't use ALL CAPS for emphasis unless it's genuinely critical. Calm, direct instructions
  outperform shouting across most modern models.
- Include "What NOT to flag" or "What NOT to do" sections where false positives are likely
- Use tables for reference data, prose for workflows, checklists for validation

#### Step 4: Validate the draft

Run through the AI Self-Check above. Then:

1. **Cross-reference check**: grep the skill collection for every skill name mentioned in the draft.
   Verify they exist and the characterization is accurate.
2. **Trigger overlap check**: compare the description against all other skill descriptions. Flag
   any that share >50% of trigger keywords.
3. **Convention check**: compare frontmatter, structure, and style against 2-3 existing custom
   skills in the same `effort` tier.

#### Step 5: Write the files

- Write `SKILL.md` to `skills/<skill-name>/SKILL.md` (or the collection's equivalent skill root)
- Write reference files (if any) to `skills/<skill-name>/references/`
- Update any installer, publish manifest, or registry file the collection uses to enumerate available skills

---

### Mode 2: Review / Improve an Existing Skill

#### Step 1: Read the skill thoroughly

Read the SKILL.md and all reference files. No skipping -- the whole point is catching issues.

#### Step 2: Run the quality checks

**Structural checks:**
- Frontmatter completeness (name, description, source, date_added, effort)
- Section presence (When to use, When NOT to use, Workflow, Rules)
- AI Self-Check section (required for skills that generate code/config)
- Reference file paths resolve (check `references/` directory)
- Under 500 lines (SKILL.md body)

**Content checks:**
- Tools exist? Every tool, CLI, library, or platform named in the skill must be verified as
  real, not deprecated, and not renamed. Search the web or check the project's GitHub/registry.
  AI hallucinates tool names, CLI flags, and API endpoints constantly -- treat every reference
  as unverified until confirmed. If a tool was replaced, the skill should reference the
  replacement (e.g., CDKTF -> HCL, Ingress -> Gateway API, lazy_static -> std::sync::LazyLock).
- CLI flags and IaC resources real? Verify flags/subcommands against actual `--help` or docs.
  For Terraform: confirm provider names and resource type arguments against the registry. For
  Ansible: confirm module names and parameters against `ansible-doc` or Galaxy. For Helm:
  confirm chart values against upstream `values.yaml`. For K8s: confirm API fields against
  the target API version. AI invents plausible-sounding arguments for all of these.
- Version numbers current? Search the web for latest stable versions of every tool mentioned.
  Don't rely on training data -- search. Flag versions more than one major release behind.
- Security references current? Check for new CVEs since the skill's `date_added`.
- Cross-skill references valid? Every skill name mentioned must exist in the collection.
- "When NOT to use" complete? Should reference all skills with overlapping trigger space.
- Related Skills section present and accurate?

**AI-age checks:**
- Does the skill generate code or config? If yes, does it have an AI Self-Check section?
- Does the AI Self-Check cover the domain's common AI mistakes? (e.g., unpinned versions,
  missing security contexts, over-abstraction)
- Are there patterns that would produce AI slop? (excessive MUSTs, over-defensive instructions,
  generic naming in examples)

**Compliance checks** (for infrastructure skills):
- PCI-DSS 4.0 mapping present where applicable?
- All future-dated requirements (mandatory since March 31, 2025) reflected?
- No hardcoded secrets in examples?

#### Step 3: Report findings

Use severity ratings:
- **Critical**: wrong information, security risk, broken cross-references
- **Important**: stale versions, missing sections, trigger overlap unhandled
- **Minor**: style inconsistency, missing "Related Skills", could-be-better wording

#### Step 4: Apply fixes

Edit the skill files to address findings. For version updates, always search the web first --
don't guess. Update `date_added` if the changes are substantial.

---

### Mode 3: Audit the Skill Collection

Run a health check across all skills. Useful periodically or after adding/removing skills.

#### Step 1: Inventory

```bash
# List all active skills with their source and date
for skill in skills/*/SKILL.md; do
  dir=$(dirname "$skill")
  name=$(basename "$dir")
  [[ "$name" == ".backups" || "$name" == ".cook" ]] && continue
  source=$(grep -m1 '^source:' "$skill" 2>/dev/null | sed 's/source: *//' || echo "unknown")
  date=$(grep -m1 '^date_added:' "$skill" 2>/dev/null | sed 's/date_added: *"//' | sed 's/"//' || echo "unknown")
  effort=$(grep -m1 '^effort:' "$skill" 2>/dev/null | sed 's/effort: *//' || echo "missing")
  printf "%-25s %-10s %-12s %s\n" "$name" "$source" "$date" "$effort"
done
```

#### Step 2: Cross-reference matrix

For each skill, check:
1. Every skill name mentioned in "When NOT to use" exists
2. Every skill name mentioned in "Related Skills" exists
3. Every declared reference file path has a corresponding file
4. Installer, publish, or registry files list the published skills correctly

#### Step 3: Trigger overlap analysis

Compare all skill descriptions pairwise. Flag pairs that share significant trigger keywords
without mutual disambiguation (no "When NOT to use" cross-reference).

#### Step 4: Freshness sweep

Flag skills where `date_added` is >30 days old AND the skill covers fast-moving domains:

**Fast-moving** (>30 days = stale risk): docker, kubernetes, ci-cd, terraform, ansible,
databases, git, security-audit, code-review (AI-age patterns section)

**Slow-moving** (>30 days = probably fine): firewall-appliance, command-prompt, prompt-generator,
update-docs, skill-creator, full-review

For each stale high-effort skill, search the web for:
- New major/minor releases of referenced tools
- New CVEs affecting referenced tools
- Deprecated or renamed tools/features since the skill was written
- New supply chain incidents (these move the fastest -- Trivy was 6 days old when we caught it)

#### Step 5: Report

Present findings grouped by severity. Include actionable fixes for each finding.

---

### Mode 4: Optimize Skill Description

The `description` field in frontmatter is the primary triggering mechanism. Optimize it for
accurate activation.

#### Step 1: Analyze current triggers

Read the skill's description and identify:
- Primary trigger keywords
- Secondary trigger contexts
- Potential false-positive triggers (keywords shared with other skills)
- Missing triggers (scenarios where the skill should activate but the description doesn't cover)

#### Step 2: Compare against the collection

Check which other skills share trigger keywords. Ensure the description differentiates clearly.

#### Step 3: Rewrite the description

Follow these patterns from high-performing custom skill descriptions:
- **Start with action verbs**: "Use when writing, reviewing, or architecting..."
- **Include specific trigger keywords**: list them inline, e.g., "Triggers: 'keyword1', 'keyword2'"
- **Mention adjacent skills to avoid**: "Not for X (use Y instead)"
- **Be slightly pushy**: many tools undertrigger skills by default. Include edge cases.
- **Stay under 1024 characters**: the system truncates beyond this

#### Step 4: Validate

After rewriting, mentally simulate 5 user prompts that should trigger the skill and 5 that
shouldn't. Check whether the new description would route correctly.

---

## Convention Reference

Read `references/conventions.md` for the complete convention guide including:
- Frontmatter field definitions and valid values
- Structural patterns by skill complexity (low/medium/high effort)
- Style rules (ASCII, banned words, imperative form)
- Reference file organization patterns
- Cross-skill reference patterns
- AI Self-Check patterns by domain

## Related Skills

- **anti-slop** -- the code quality audit skill. When reviewing a skill's example code or
  reference patterns, anti-slop patterns apply (comment noise, over-abstraction, stale idioms).
- **full-review** -- orchestrates four parallel audits. This skill audits the skill collection
  itself, not application code.
- **prompt-generator** -- structures prompts for LLM consumption. Skills ARE prompts, but
  prompt-generator targets one-off prompts saved to `docs/prompts/`, not reusable skill files.
- **code-review** -- reviews application code for correctness. This skill reviews skill files
  for convention compliance, not code correctness.

## Rules

1. **Read before edit.** Always read a skill's SKILL.md and reference files before modifying.
   No exceptions, no "I already know the content."
2. **Conventions are non-negotiable.** Every custom skill must have: `source: custom`,
   `date_added`, `effort`, "When to use", "When NOT to use", and a Workflow section. These
   aren't suggestions -- they're what makes the collection consistent and predictable.
3. **Verify everything, assume nothing.** AI models hallucinate tool names, CLI flags, version
   numbers, and API endpoints. Every tool, version, flag, and behavior claim in a skill must
   be verified via web search or registry check before writing it down. "I'm pretty sure" is
   not verification. If you can't confirm it, don't include it.
4. **Prefer dedicated skill workflows over generic helpers.** When a purpose-built skill and a
   generic planning or brainstorming helper both fit, prefer the purpose-built skill. Generic
   workflow skills are invoked manually when explicitly requested.
5. **Update the inventory.** After creating, removing, or renaming a skill, update any published
   inventory file the collection uses and re-run the cross-reference checks.
6. **No AI slop in skills.** Skills are meta-prompts -- they shape how the model works. Comment
   noise, over-abstraction, aggressive ALL CAPS directives, and "just in case" instructions
   degrade skill performance. Write like a competent human briefing a colleague.
7. **Plain ASCII only.** No em-dashes, curly quotes, or ligatures in skill files. Use `--` for
   dashes, straight quotes, plain punctuation. This matches the global instruction-file rule.
8. **Run the AI Self-Check.** Every generated or modified skill gets verified against the
   checklist before returning to the user.
