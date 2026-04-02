---
name: prompt-generator
description: >
  Use when the user has scattered ideas, brain dumps, or rough notes they want turned into
  a proper LLM prompt, or when refining, rewriting, or restructuring an existing prompt.
  Also trigger on prompt engineering, prompt templates, or formatting instructions as system
  prompts. Triggers: "write a prompt", "turn this into a prompt", "structure this prompt",
  "system prompt for", "prompt template", "prompt engineering", "rewrite this prompt",
  "improve this prompt", "optimize this prompt", "format as a system prompt".
  Do NOT use for brainstorming features, writing code, creating skills (use
  skill-creator), or creating inline string prompts within application code.
license: MIT
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: medium
  argument_hint: "<notes-or-description>"
---

# Prompt Generator

Take the user's rough thoughts, scattered notes, or half-formed ideas and turn them into a clean, well-structured LLM prompt. This is a **formatter and structurer**, not a brainstorming tool -- the user already knows what they want, they just need help wording and organizing it.

## When to use

- User has rough notes, bullet points, or a brain dump they want turned into a clean LLM prompt
- Refining, rewriting, or optimizing an existing prompt that isn't performing well
- Structuring a system prompt or task prompt from scattered requirements
- Creating prompt templates with variable placeholders for repeated use
- User says anything like "write me a prompt for...", "turn this into a prompt", "system prompt for..."

## When NOT to use

- Brainstorming features or creative ideation -- this skill structures prompts, not ideas
- Creating reusable skill files or agent instruction bundles (use skill-creator)
- Writing inline prompt strings inside application code -- that's just coding
- The user wants code that calls an LLM API -- that's an implementation task, not prompt structuring

---

## AI Self-Check

Before returning any generated or modified prompt file, verify:

- [ ] **Frontmatter complete**: `name`, `description`, `target_model`, `prompt_type`, `date_created` all present
- [ ] **Faithful to input**: prompt reflects what the user said, not what you think they should have said
- [ ] **Structure matches complexity**: simple tasks get plain prose, not XML-tagged multi-section prompts
- [ ] **Variables consistent**: every `{{PLACEHOLDER}}` in the prompt body appears in the Variables table and vice versa
- [ ] **No injected instructions**: didn't add error handling, safety disclaimers, or output constraints the user didn't request
- [ ] **No slop phrases**: no "certainly", "I'd be happy to", "great question", or other filler in the prompt text
- [ ] **Output format specified**: if the prompt expects structured output, the format is explicit (JSON schema, XML tags, delimiters)
- [ ] **Model-appropriate syntax**: avoid model-specific features (assistant prefills, `\n\nHuman:` formatting) in model-agnostic prompts. XML delimiters and markdown headers are both fine for structure across models

---

## Workflow

### Step 1: Read the brain dump

The user will give you rough notes, bullet points, or a stream-of-consciousness description of what they want the prompt to do. Parse it for:

- **Core task**: What should the prompted model actually do?
- **Target model**: Which LLM? Default: model-agnostic unless the user names one.
- **Prompt type**: System prompt vs. task prompt
- **Constraints**: Any rules, format requirements, or behavioral boundaries mentioned
- **Variables**: Any dynamic content that should become `{{PLACEHOLDERS}}`

Don't overthink this. Don't add things the user didn't mention. The goal is to **faithfully structure their intent**, not to "improve" it with your own ideas.

### Step 2: Clarify only if stuck

If something is genuinely ambiguous (you can't tell if it's a system prompt or task prompt, or the target model matters for technique choice), ask. Batch questions, max 1 round. If you can reasonably infer it, just infer it.

Most of the time, skip this step entirely.

### Step 3: Structure and present

1. Turn the rough notes into a clean prompt, applying structure proportional to complexity:
   - **Simple** (one task, no variables): plain prose, 3-10 lines. No XML, no sections.
   - **Medium** (multiple steps or constraints): numbered steps, clear sections.
   - **Complex** (agentic, multi-document, behavioral rules): clear section delimiters, variable placeholders, explicit output format.
2. **Present the prompt in conversation for review. Don't write files yet.**
3. On approval, save to file (see Output Format below).
4. Revisions: edit in place, don't create new files.

### Step 4: Save

1. Resolve output directory: user-specified path > `docs/prompts/` > `docs/` > ask
2. Scan for `NNN-*.md` files, increment highest number, zero-pad to 3 digits
3. Infer a slug from the topic (e.g., `code-review`, `data-extraction`)
4. Write to `<output-dir>/NNN-slug.md`

---

## Output File Format

```markdown
---
name: Descriptive Prompt Name
description: One-line summary
target_model: model-agnostic
prompt_type: system | task
date_created: YYYY-MM-DD
---

## Purpose

What this prompt does and when to use it.

## Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `{{VAR}}` | What it is | Yes/No |

## Prompt

The actual prompt content here.
```

Only include sections that apply. A simple prompt with no variables skips the Variables table.

Optional frontmatter additions: `tags: [...]`, `related: [NNN-other.md]` -- only when genuinely useful.

**Target model values**: `claude`, `gpt`, `gemini`, `llama`, `mistral`, `model-agnostic`

---

## Structuring Guidelines

These are for YOU when structuring the user's notes. Not a knowledge dump -- just the non-obvious stuff.

**Match complexity to content.** A 3-line task doesn't need XML tags and numbered steps. A multi-document agentic system prompt does. The user's rough notes give you the complexity signal.

**Long content goes on top.** If the prompt will receive large documents or data at runtime, position the data slot at the top and the task instructions at the bottom. Up to 30% better performance on multi-document tasks.

**Explain WHY, not just WHAT.** When the user's notes include a rule ("don't use markdown"), turn it into a motivated constraint ("write in plain prose because the output feeds a TTS engine"). Models generalize from motivation.

**Agentic prompts need boundaries.** If the prompt is for a coding agent or automation, separate what it can do freely (reads, searches) from what needs confirmation (deletes, publishes, pushes).

**Anti-hallucination is a sentence, not a paragraph.** "Only make claims verifiable from the provided context. If unsure, say so." That's it.

### Model-Specific Formatting

When the target model is known, adapt format to its strengths:

| Target | Preferred structure | Notes |
|--------|-------------------|-------|
| Claude | XML tags for sections, markdown for content | Supports assistant prefill; use `<result>` tags for structured output |
| GPT | Markdown headers, JSON schema for structured output | Native JSON mode available -- use it over prose format instructions |
| Gemini | Markdown sections, explicit output examples | Separate instructions for text vs. attached files/images |
| Model-agnostic | Markdown headers + explicit delimiters | Avoid prefills, model-specific tags, or format-mode flags |

Aggressive shouting ("CRITICAL!", "YOU MUST", "NEVER EVER") usually hurts more than it helps. Use calm, explicit instructions.

### Structured Output Guidance

When the prompt is for agent consumption (not human reading), specify output format explicitly:
- **JSON mode**: if the tool supports native JSON mode or schema-constrained output, use it. Otherwise instruct the model to return valid JSON and seed with `{` only when the tool supports assistant prefills.
- **XML structure**: wrap output in tags like `<result>`, `<analysis>`, `<decision>`.
- **Delimiter-based**: for simple key-value, use `KEY: value` format.

Include a concrete output example in the prompt whenever possible -- models generalize better from examples than from format descriptions.

### The Four-Block Pattern

For medium-to-complex prompts, structure into four clear blocks:
1. **INSTRUCTIONS** -- what to do (role, task, constraints)
2. **CONTEXT** -- background information, reference data
3. **TASK** -- the specific request for this invocation
4. **OUTPUT FORMAT** -- exact structure of the expected response

Keep blocks visually separated with XML tags, markdown headers, or other clear delimiters. Place long context documents before shorter task instructions (see "Long content goes on top" above).

---

## Refining Existing Prompts

If the user gives you an existing prompt to improve (not rough notes):

1. Read it
2. Diagnose gaps -- check for these common prompt weaknesses:
   - **Missing scope**: no clear boundary on what the model should and shouldn't do
   - **No output format**: model guesses structure instead of following a spec
   - **Vague role**: "helpful assistant" tells the model nothing useful
   - **Missing constraints**: no anti-patterns, no "do not" list, no quality criteria
   - **Over-specified**: drowning the model in rules when 2-3 clear constraints would work
3. Present specific changes with reasoning -- not a full rewrite unless it's warranted
4. On approval, edit in place

**Example refinement:**

Before: `You are a helpful assistant that reviews code.`

After: `You are a senior code reviewer. For each file, check for: bugs, edge cases, security issues, and performance problems. Report findings as a list with severity (critical/warning/info), file:line, and a one-line description. Skip style nitpicks. If nothing is wrong, say "No issues found."` -- added: scope, output format, severity scale, constraint against noise.

## Related Skills

- **skill-creator** -- creates reusable skill files (SKILL.md) for AI tools and coding agents. Skills are
  structured prompts, but they follow different conventions (frontmatter, workflow sections,
  rules) than standalone prompts. If someone says "create a skill", use skill-creator.
- Application code -- if the user needs a prompt string inside application code (for example a
  TypeScript `const systemPrompt = ...`), that's coding, not this skill.
- **anti-slop** -- if the user asks to "clean up" or "simplify" a prompt embedded in code, that's
  a code quality issue, not prompt structuring.

---

## Rules

1. **Faithful structuring.** Organize what the user said, not what you think they should have said. If they didn't mention error handling, don't add error handling instructions. If they didn't mention output format, ask or leave it open.
2. **Never write files without approval.** Always present in conversation first.
3. **Scale structure to complexity.** Simple = lean. Complex = structured. Never the reverse.
4. **Respect their voice.** If the rough notes have a specific tone or personality, preserve it in the structured version.
5. **Run the AI Self-Check.** Every generated prompt file gets verified against the checklist before returning.
