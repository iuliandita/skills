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
- **Technical docs** - formal language and terms of art are fine; flag only wording that obscures the explanation
- **README / PR / commit** - concise is expected, significance padding is especially jarring
- **Marketing / product copy** - assess tone against the brief and audience; unsupported claims matter more than a preferred word list
- **Creative fiction** - many tells (tricolons, elegant variation) are legitimate devices; flag only when they read as mechanical
- **Wiki article** - neutral voice required, promotional language is always a finding
- **Email** - conversational is expected, formality inflation is a tell
- **Slides / presentation** - fragments are fine; check whether the audience can understand the point at presentation speed

### Step 3: Scan for patterns

Apply the four categories from `SKILL.md`. These are editing heuristics, not reliable authorship tests. Establish reader impact before applying the density guide. For each match, read the surrounding context - a single instance of an AI word in a 5000-word document is probably noise, but three instances in three paragraphs is a pattern.

**Density heuristic** (rough guide, not a hard rule):
- **Under 1 flagged item per 500 words** - noise. Do not flag, unless the instance sits in a
  high-visibility position (title, opening sentence, summary, callout), where a single tell
  still shapes the reader's impression. Those isolated flags are P3, never higher
- **1 to under 2 per 500 words** - borderline. Flag only what a reader would notice, at P3
- **2 to under 4 per 500 words** - a pattern, flag the cluster as P2
- **4+ per 500 words** - inspect the passage as a whole; P1 only if the cluster obscures its main point

**Short text scaling:** under 100 words, a cluster that obscures the main point may warrant P1. Count substantive clarity problems, not word matches. A single sentence crammed with AI vocabulary is worse than a long doc with scattered instances. Formatting nits do not count toward the cluster, and never escalate past P3 on their own: two curly quotes in a short paragraph is P3, not P1.

**What density gates.** One list, authoritative:

- **Gated** (need a cluster before they are findings): every check in category 1 (vocabulary)
  and category 2 (syntax, which includes participle tails, false ranges, unnamed-actor
  passives, and dense sentence stacking), plus the sentence-level checks in category 3 -
  hedging and qualifier stacking, scaffolding padding, confident filler, vague attribution,
  significance padding, feeling-instead-of-mechanism. One instance is noise; the pattern is
  the finding. Character names require a setting or continuity problem; see `references/fiction-tells.md`.
- **Not gated** (one instance is the finding): whole-passage register tells, meaning
  travel-guide voice and promotional tone, at P2; the formulaic article shape, which is a
  document-level structure occurring once, at P2; chat artifacts, where one is one too many in
  either mode, at P2 in delivered text; and trust breaches at P0. Cutoff disclaimers are a
  trust breach, not a chat artifact: they assert a limit the named author does not have, so
  they are P0 in anything shipped under a human byline.

Formatting tells sit outside the ratio entirely: they do not count toward the per-500-word
denominator, isolated nits are P3, and they never escalate on density alone. The exception is
the LLM output bugs, which are trust breaches at P0.

Classify each finding by category, action, and severity:

**Action:**
- **Fix** - a concrete clarity, accuracy, or audience-fit problem with a supported correction
- **Consider** - judgment call, present it and let the user decide
- **Fine** - matches the pattern but is justified (note why, move on)

**Severity** (the shared contract's `P0 | P1 | P2 | P3 | info` scale, mapped to prose):
- **P0** - the text misleads or exposes the author: a fabricated citation, a factual claim invented to fill a gap, an unredacted secret or private hostname, or raw generator residue (`turn0search0`, `oaicite`, `As of my last update`) left in published text. P0 is about trust, not voice
- **P1** - a cluster that obscures the main point; vague attribution passing opinion as fact; broken references
- **P2** - vocabulary or syntax tells that dull the voice without breaking trust; formulaic article shape; travel-guide voice in non-travel writing
- **P3** - small clarity or house-style problems with reader impact; justified domain vocabulary and deliberate voice are not findings
- **info** - a pattern match you checked and cleared (a domain term of art, a genre convention), worth recording so the next reader does not re-litigate it. Never an action item

### Step 4: Report and fix

Present findings grouped by category. For each Fix-level item, show the concrete rewrite. Prefer shorter, clearer, or more specific rewrites. Added detail is justified when it improves understanding without inventing facts.

For report-only requests, show the proposed changes without applying them. When fixes are
already authorized, apply them and record the result. Include newly discovered issues within
the same scope; avoid unrelated rewrites. Ask only if the next change would alter the author's
intent or needs authority the user has not supplied.

---

## Report template

The expanded two-surface template below applies once a report exceeds the shared contract's
small-report threshold (`references/output-contract.md`: more than three focused findings). At
or under that threshold, skip the deliverable file and report inline per the contract - concise
prose with priority, location, and suggested action, and say directly when there are no findings.

Above the threshold, audit mode produces two surfaces, and they are shaped differently. Do not
try to nest one inside the other.

1. **In the transcript:** the monospace contract header, the category-grouped summary templated
   below, then the concise monospace conclusion. This is where before/after pairs go, because that
   is what the reader is scanning.
2. **In the deliverable file** (`docs/local/audits/anti-ai-prose/<date>-<slug>.md`): the shared
   contract's own shape - findings grouped by priority under `## P0 - Must fix` style headings,
   each a `- [ ]` checkbox with `File` / `Description` / `Suggested action` / `Fix applied`.
   Number findings `#1`, `#2`, ... monotonically across the whole file; the conclusion table's
   `#` column refers to those numbers. See `references/output-contract.md` for the exact shape.

Same findings, same numbering, two renderings. **Assign `#N` in priority order** - all P0s
first, then P1, P2, P3, info - and carry that number into both surfaces and the conclusion
table. Numbering by priority rather than by category is what keeps the deliverable file
monotonic when it regroups under `## P0 - Must fix` style headings; the transcript then shows
the same numbers out of order within its category grouping, which is expected. A finding is one record with one
number, however many individual flagged items it covers: a cluster of nine vocabulary hits
reported as one cluster is one finding, not nine. The template below is surface 1.

````markdown
## Anti-AI-Prose Audit: [scope]

### Findings

#### [Category Name] ([count] items)

**#[N] [action]** ([severity]) `path/to/file:line` - [description]

> before: [quoted text from the source]

> after: [suggested rewrite]

### Summary
- X findings across Y files / sections
- [overall read: does the piece sound human?]
- [top-level observation: e.g., "vocabulary is mostly fine but the structure is formulaic"]
````

Rules for the report itself:
- **Omit empty categories.** If there are no formatting tells, do not write an empty "Formatting Tells (0 items)" heading
- **Order within a category** P0 > P1 > P2 > P3 > info
- **Deletion fixes have no "after"** - write `> after: (cut)` or just state the delete in the description
- **Apply these rules to your own audit.** Run the Self-Check on the report before returning it - an audit written in AI-slop voice is not credible

Keep it concise. Show the before/after pair. Do not lecture about why AI writing is bad - the user already knows.

### Worked example (anchors the body format; the contract still wraps it)

Input (README snippet, 49 words):

> In today's fast-paced world, our platform empowers developers to seamlessly navigate the complex landscape of modern APIs. Built with a commitment to excellence, it boasts robust features and fosters innovation. Whether you're a beginner or expert, this tool serves as a pivotal resource for your journey toward better software.

Report:

```
## Anti-AI-Prose Audit: README snippet (49 words)

### Findings

#### Clarity (1 finding)

**#1 Fix** (P1) `README.md:1` - generic promotion obscures what the product does
> before: "empowers developers to seamlessly navigate" and "serves as a pivotal resource"
> after: (rewrite, see below)

Scaffolding, vague benefits, and copula avoidance reinforce this one problem. Count the
cluster once instead of producing separate findings for every phrase or category.

### Summary
- 1 clarity finding: the paragraph supplies almost no concrete product information
- Rewrite, using only what the source actually claims: "A tool for working with modern APIs.
  Usable by beginners and experts." 49 words down to 12.
- Note what the rewrite cannot do: the source never says what the product *is*, so no honest
  rewrite can add that. `platform` and `tool` are the only self-descriptions available, and
  neither says more than the rewrite already does. Ask the author for the missing specifics;
  inventing them would be a P0 trust breach, whoever writes it.
```
