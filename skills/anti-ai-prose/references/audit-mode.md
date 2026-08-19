# Audit mode: workflow and report format

Everything here applies to **audit mode** only - a file, paste, diff, or directory handed over
for review. Inline mode (filtering your own conversational output) runs none of it: no scoping,
no severity, no report.

## Workflow

### Step 1: Scope the audit

Default scope based on context:
- If invoked on a specific file or paste - audit that text
- If invoked with no target and there are uncommitted changes to `.md` / `.txt` / doc files - audit those
- If invoked in a code repo with recent commits - audit the docstrings and comments in changed files
- Otherwise - ask the user for a target

Available scopes:
- **Single file** - one doc, README, draft, or source file
- **Directory** - all `.md` / `.rst` / `.txt` under a path
- **Pasted text** - inline block the user supplies
- **Recent changes** - git diff against a base
- **Comments and docstrings only** - scan code files but audit only prose regions

### Step 2: Detect text kind

Different text types have different conventions. Before flagging, identify which applies:
- **Technical docs** - formal is OK, but vocabulary bans still apply
- **README / PR / commit** - concise is expected, significance padding is especially jarring
- **Marketing / product copy** - tonal tells (`boast`, `showcase`) may be intentional but still weaken the writing
- **Creative fiction** - many tells (tricolons, elegant variation) are legitimate devices; flag only when they read as mechanical
- **Wiki article** - neutral voice required, promotional language is always a finding
- **Email** - conversational is expected, formality inflation is a tell
- **Slides / presentation** - fragments are fine, but vocabulary and tonal tells still apply

### Step 3: Scan for patterns

Apply the four categories (see below). For each match, read the surrounding context - a single instance of an AI word in a 5000-word document is probably noise, but three instances in three paragraphs is a pattern.

**Density heuristic** (rough guide, not a hard rule):
- **Under 1 flagged item per 500 words** - noise, usually do not flag
- **2-3 per 500 words** - a pattern, flag the cluster as P2
- **4+ per 500 words** - dominant voice, P1 severity, recommend structural rewrite

**Short text scaling:** for text under 100 words, any 2+ tells in a single paragraph is P1 severity regardless of the per-500-words threshold. A single sentence crammed with AI vocabulary is worse than a long doc with scattered instances.

Density only applies to vocabulary and syntax tells. A single travel-guide paragraph is enough to flag on its own. One fabricated citation is always P1.

Classify each finding by category, action, and severity:

**Action:**
- **Fix** - clearly a tell, should change
- **Consider** - judgment call, present it and let the user decide
- **Fine** - matches the pattern but is justified (note why, move on)

**Severity:**
- **P1** - cluster of tells that makes the piece sound unmistakably AI-written; vague attribution passing opinion as fact; fabricated citations or broken references
- **P2** - vocabulary or syntax tells that dull the voice without breaking trust; formulaic structures ("Despite its X, faces challenges..."); travel-guide voice in non-travel writing
- **P3** - single instances of banned vocabulary; formatting nits (em-dash usage, unnecessary bold); tricolon overuse

### Step 4: Report and fix

Present findings grouped by category. For each Fix-level item, show the concrete rewrite. Rewrites should be **shorter** or **more specific** - never longer.

**Plan first, apply that plan only.** Produce the audit report as the improvement plan before any
rewrites are merged. If the user then asks for the fixes to be applied, change only what the plan
flagged. Do not freelance edits outside the plan, do not "while we're here" rewrite adjacent
prose, and do not chain a second pass of new fixes on top of the applied ones in the same step.
This keeps the work auditable and prevents a cheap model from re-drafting the piece worse than
the original. If new findings emerge while applying, surface them as a second audit, not as
silent edits.

---

````markdown
## Anti-AI-Prose Audit: [scope]

### Findings

#### [Category Name] ([count] items)

**[action]** ([severity]) `path/to/file:line` - [description]

> before: [quoted text from the source]

> after: [suggested rewrite]

### Summary
- X findings across Y files / sections
- [overall read: does the piece sound human?]
- [top-level observation: e.g., "vocabulary is mostly fine but the structure is formulaic"]
````

Rules for the report itself:
- **Omit empty categories.** If there are no formatting tells, do not write an empty "Formatting Tells (0 items)" heading
- **Order within a category** P1 > P2 > P3
- **Deletion fixes have no "after"** - write `> after: (cut)` or just state the delete in the description
- **Apply these rules to your own audit.** Run the Self-Check on the report before returning it - an audit written in AI-slop voice is not credible

Keep it concise. Show the before/after pair. Do not lecture about why AI writing is bad - the user already knows.

### Worked example (anchor the format)

Input (README snippet, 48 words):

> In today's fast-paced world, our platform empowers developers to seamlessly navigate the complex landscape of modern APIs. Built with a commitment to excellence, it boasts robust features and fosters innovation. Whether you're a beginner or expert, this tool serves as a pivotal resource for your journey toward better software.

Report:

```
## Anti-AI-Prose Audit: README snippet (48 words)

### Findings

#### Vocabulary Tells (9 items)

**Fix** (P1) line 1 - cluster of 9 flagged words in 48 words: far above 4/500 threshold
> before: empowers / seamlessly / navigate / landscape / commitment to / boasts / fosters / pivotal / journey toward
> after: (rewrite, see below)

#### Tonal Tells (2 items)

**Fix** (P1) line 1 - scaffolding padding and significance padding
> before: "In today's fast-paced world"
> after: (cut)

**Fix** (P2) line 1 - promotional tone
> before: "Built with a commitment to excellence"
> after: (cut)

### Summary
- 11 findings, one paragraph, dominant AI voice
- Rewrite: "An HTTP API client for Python. Handles auth, retries, and pagination. Works with any OpenAPI 3.x spec."
- Down from 48 words to 22, with concrete claims instead of posture
```

