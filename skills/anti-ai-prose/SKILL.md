---
name: anti-ai-prose
description: >
  · Strip AI tells from prose in docs, PRs, emails, and your own replies. Apply to every response by default; full audit on request. Triggers: 'unslop', 'ai writing', 'sounds like chatgpt', 'llm voice'. Not for code (use anti-slop).
license: MIT
compatibility: "None - works on any prose or text input"
metadata:
  source: iuliandita/skills
  date_added: "2026-04-09"
  effort: medium
  argument_hint: "<file-or-text>"
---

# Anti-AI-Prose: Audit Writing for Machine-Generated Patterns

Detect and fix the linguistic tells that make written English read as machine-generated. The goal is prose that sounds like a specific, thoughtful human wrote it.

This skill applies to any text: **documentation**, **READMEs**, **wikis** (Confluence, Notion, internal), **pull request descriptions**, **commit messages**, **release notes**, **blog posts**, **emails**, **slide copy**, **creative writing**, and **code comments / docstrings**. The vocabulary, syntax, tone, and formatting checks are language-domain, not platform-domain.

Based in part on [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) - a field guide compiled by editors who have read enormous volumes of LLM-generated text and know what it actually looks like - on [stop-slop](https://github.com/hardikpandya/stop-slop) (MIT), which contributed the confident-filler check: emphasis crutches, rhetorical setups, and the faux-profundity fragment - and on [poteto/plugins](https://github.com/poteto/plugins) `pstack/skills/unslop` (MIT), which contributed the plain-speech checks, the abstract-metaphor-noun list, chat artifacts, and the voice-restoration guidance.

## When to use

- Auditing a README, doc page, or wiki article that feels machine-written
- Reviewing a PR body, commit message, or release note draft before publishing
- Polishing a blog post, email, or presentation script you wrote with LLM help
- Checking creative writing (fiction, essays) for AI tells after an LLM-assisted pass
- Reviewing docstrings and code comments for the same prose patterns
- Any time someone says "this sounds like ChatGPT wrote it"
- Self-check after a heavy LLM-drafting session
- Filtering your own replies, explanations, and drafts as you write them (inline mode, see below)

## When NOT to use

- Code quality, over-abstraction, dependency creep, stale idioms - use **anti-slop**
- Doc drift after a feature change, API rename, or config update - use **update-docs**
- Generating or restructuring a prompt from rough notes - use **prompt-generator**
- Correctness bugs, logic errors, edge cases - use **code-review**
- Security review of auth, secrets, or attack surface - use **security-audit**
- Full multi-dimensional repo audit - use **full-review**

---

## Two modes

This skill runs in one of two modes. Pick the mode from the trigger, not from the content.

### Inline mode (default, always on)

Applies to your own conversational output: chat replies, explanations, summaries, commit bodies,
PR descriptions, and any prose you draft for the user. Runs on every response without being asked.

- Apply the pattern rules silently while writing. This filters drafting, it does not review a
  finished draft.
- Emit **no report, no findings, no severity ratings, no deliverable file**, and no note that the
  skill ran.
- Do not restructure the user's own words when quoting them back.
- Density thresholds do not apply. Fix every tell you catch in your own output.
- Ask before sending: "what in this reply reads as machine generated?" Fix what that surfaces.

### Audit mode (explicit)

Applies to text the user hands over: a file, a paste, a diff, a directory. Triggered by an
explicit request ("audit this", "does this sound like AI", "unslop this doc") or by invoking the
skill against a target. Run the full Workflow below, emit the full output contract, and apply the
density thresholds so isolated instances in long documents are not flagged.

### Precedence

When rules conflict, later entries lose:

1. The user's explicit instruction in this conversation
2. Project instruction files (`CLAUDE.md`, `AGENTS.md`, repo style guide)
3. Genre convention of the text being written (see "What NOT to Flag")
4. This skill's pattern rules

A house style that mandates em dashes, title-case headings, or a formal register is not a finding.
Inline mode adapts to it rather than overriding it.

---

## AI Self-Check

Before returning any audit, verify:

- [ ] **Findings are patterns, not taste**: the issue is a demonstrable AI tell (from the Wikipedia guide or observed LLM output), not personal writing preference
- [ ] **Context respected**: academic and technical prose can look formal without being AI-generated. Journalism, marketing, and tourism writing have legitimate conventions that overlap with AI tells. Do not flag genre conventions as AI tells
- [ ] **Direct quotes preserved**: do not edit quoted material from other authors, even if it contains banned vocabulary
- [ ] **Domain terms kept**: `pivotal` in hinge hardware specs, `landscape` in horticulture, `foster` as a verb in child welfare, `realm` in fantasy fiction - these are not tells in context
- [ ] **Code blocks untouched**: do not flag identifiers, strings, or code comments that contain banned words as part of functional code
- [ ] **Rewrites are real improvements**: every "after" is shorter, clearer, or more specific than the "before". No lateral rewrites that just swap synonyms
- [ ] **Severity is honest**: do not inflate P3 findings to P2 to pad the report
- [ ] **Density and short-text rule applied**: density heuristic applied before assigning severity; for text under 100 words, 2+ tells in one paragraph = P1 regardless of per-500-word threshold
- [ ] **Audit output itself uses no AI-prose tells** (apply these rules to your own output)
- [ ] **AI fallback names checked (fiction)**: protagonist and major-character names compared against the documented fallback set (Elara, Lyra, Aurora, Kael, Vale, Cassius, etc.) and the phonetic tell (2 soft syllables, A/L/R/N consonants, no demographic anchor); fallback-set names allowed only when the setting and population organically produce them
- [ ] **Adverb stacking checked**: `-ly` adverb density scanned; passages with multiple adverb-modified speech tags or adjacent adverb clusters flagged at the same density threshold as vocabulary tells
- [ ] **Confident filler checked**: emphasis crutches, rhetorical setups, and faux-profundity fragments flagged by pattern/density, not on isolated earned uses
- [ ] **Mode picked correctly**: inline mode emitted no report, no findings list, and no deliverable file; audit mode emitted the full contract. The two were not mixed in one response
- [ ] **House style respected**: project instruction files and explicit user instructions took precedence over this skill's pattern rules; a mandated em dash or title-case convention was not reported as a finding
- [ ] **Plain-speech checks run**: participle tails, false ranges, unnamed-actor passives, dense sentence stacking, and feeling-instead-of-mechanism scanned alongside the vocabulary tells
- [ ] **Chat artifacts cleared**: no `Great question!`, `I hope this helps!`, `Certainly!`, or cutoff disclaimer survived into the output, in either mode
- [ ] **Voice restored, not imposed**: rewrites carry a position, varied rhythm, and specifics; voice suggestions are marked `Consider`, never `Fix`
- [ ] **Overflagging avoided**: plain but valid technical prose is not labeled AI-written without concrete evidence
- [ ] **Audience preserved**: edits keep the author's domain vocabulary, intent, and required formality
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

---

## Performance

- Review a representative sample first, then expand only if the same pattern repeats across the document.
- Group repeated prose issues by pattern instead of leaving near-duplicate comments on every paragraph.
- Prioritize high-visibility text: titles, summaries, intros, conclusions, and user-facing docs.

---

## Best Practices

- Flag exact phrases and structural patterns, not vibes.
- Offer replacement copy when the fix is obvious; otherwise describe the problem and let the author decide.
- Do not erase necessary caveats, compliance language, or domain-specific precision to make prose sound casual.

## Workflow

Audit mode only. Full detail in `references/audit-mode.md`: scoping rules, the text-kind table,
the density heuristic, the action and severity scales, and the report template with a worked
example.

1. **Scope.** Audit the file or paste given. With no target, fall back to uncommitted doc changes,
   then to docstrings in changed files, then ask.
2. **Detect text kind.** Technical docs, README/PR/commit, marketing, fiction, wiki, email, and
   slides each carry conventions that change what counts as a tell.
3. **Scan.** Apply the four categories below. Read surrounding context before flagging: one AI word
   in 5000 words is noise, three in three paragraphs is a pattern. Density sets severity, and text
   under 100 words with 2+ tells in a paragraph is P1 regardless.
4. **Report and fix.** Group by category, show the concrete rewrite, keep every rewrite shorter or
   more specific than the original. **Plan first, apply that plan only:** when the user asks for
   fixes, change only what the report flagged. New findings during application become a second
   audit, never silent edits.

---

## The Four Categories of AI Prose Slop

### 1. Vocabulary Tells (Noise)

Specific words that LLMs overuse far beyond their natural English frequency.

**Flagged vocabulary** (context-sensitive - see exceptions below):

| AI word | Natural alternatives |
|---|---|
| delve | look at, examine, dig into, cover |
| tapestry | mix, range, variety (or just drop the metaphor) |
| testament | proof, evidence, example |
| pivotal | key, important, central (or drop if padding) |
| crucial | important, needed (or drop if padding) |
| realm | area, field, world |
| landscape | scene, field, mix |
| showcase | show, display, feature |
| empower | help, enable, let (or rewrite with a specific claim) |
| foster | build, grow, support, encourage |
| navigate | handle, work through, manage |
| nestled | set, located, built |
| vibrant | lively, active, busy (or drop) |
| underscore | show, highlight, confirm |
| garner | get, earn, attract |
| enduring | lasting, long-running |
| boast | have (just "has") |
| leverage | use |
| utilize | use |
| facilitate | help, enable |
| seamless | smooth (or drop) |
| robust | reliable, solid (or drop if padding) |
| commitment to | cares about, focuses on |
| dive deep into | look at, cover |
| embark on | start, begin |
| nuanced | subtle, careful, specific (or drop - almost always padding) |
| multifaceted | has many sides, covers a lot (or drop) |
| holistic | whole, end-to-end, full (or drop) |
| synergy | fit, overlap, how X and Y work together (or drop) |
| innovative | new, novel (or name what is new) |
| commence | start, begin |
| journey toward | work toward, move toward, aim for (or drop) |
| moving forward | from now on, next, going forward (or drop) |
| additionally | also, and (or start the sentence with the content) |
| enhance | improve, speed up, extend (or name the change) |
| interplay | how X and Y interact (or drop) |
| intricate | detailed, complex (or drop - usually padding) |
| numerous | many |
| ensure | make sure, guarantee (or name the mechanism) |

**Detect:**
- Multiple flagged words in the same paragraph
- Flagged word used metaphorically (`tapestry of experiences`, `realm of possibility`)
- Flagged word in a context where a plain verb would work (`showcase the features` -> `show the features`)

**Fix:** Replace with the plain alternative. If the sentence gets weaker after replacement, the original was padding - cut the whole phrase.

See "What NOT to Flag" below for domain exceptions (horticulture `landscape`, child welfare `foster`, networking `realm`, etc.).

#### AI fallback character names (fiction)

Generated fiction often converges on soft, no-baggage names such as `Elara`, `Kael`, or
`Voss`. If a prose audit includes invented character names, read
`references/fiction-name-tells.md` for the fallback-name pattern, exceptions, and fix guidance.

#### Abstract metaphor nouns

Nouns that read as technical but stand in for a plainer word: `substrate`, `wedge`, `vector`,
`locus`, `vantage`, `nexus`, `primitive` (as noun), `harness` (as metaphor), `surface` (as in
"API surface"), `bedrock`, `scaffolding` (as metaphor), `modality`, `paradigm`, `gold-plating`.

**Detect:** the noun carries no measurement, no referent, and no consequence.

**Fix:** name the concrete thing. `substrate` -> `base`, `wedge in` -> `add`, `vector` -> `way`.

**Exception:** each is a term of art somewhere (`vector` in linear algebra, `locus` in
genetics). Full table and per-term exceptions in `references/plain-speech.md`.

### 2. Syntax Tells (Noise + Soul)

Sentence structures LLMs reach for to sound balanced or significant.

#### Negative parallelism

LLMs overuse `not X but Y` and `not just X, but also Y` constructions to signal balance and sophistication. In moderation this is fine English. In quantity it is a clear tell.

**Detect:**
- Three or more `not X but Y` / `not just X, but Y` / `it's not about X, it's about Y` structures in a single piece
- Used where a direct claim would work: `this isn't just a tool, it's a platform` -> `this is a platform`

**Fix:** State the positive claim directly. If the contrast matters, keep one instance and rewrite the rest.

#### Forced tricolons (rule of three)

`X, Y, and Z` lists used for rhythm rather than enumeration. LLMs default to three items even when two or four would be more accurate.

**Detect:**
- Adjective triplets where one adjective would carry the meaning: `a fast, reliable, and scalable system`
- Noun triplets that are really the same concept: `clarity, precision, and accuracy`
- Three-item lists where the third item is obviously padded to hit the count

**Fix:** Drop the weakest item. Use two items when the point is a contrast, four or more when it is an actual list.

#### Copula avoidance

LLMs avoid plain `is` / `are` / `has` / `have` in favor of elaborate constructions: `serves as`, `marks`, `represents`, `features`, `offers`, `boasts`, `stands as`.

**Detect:**
- `serves as` where `is` works: `it serves as a backup` -> `it is a backup`
- `represents` used as a replacement for `is`: `this represents a shift` -> `this is a shift`
- `boasts` used for `has`: `the app boasts 50 features` -> `the app has 50 features`
- `marks` used to inflate: `this marks the first time` -> `this is the first time`

**Fix:** Use the plain copula. Elaborate verbs should carry weight - do not spend them on simple identity claims.

#### Adverb crutch (-ly modifiers)

LLMs reach for `-ly` adverbs to inflate description and dodge precise verb choice: `said softly`, `ran quickly`, `smiled warmly`, `walked slowly`, `whispered quietly`. Each one in isolation is acceptable English. Density is the tell. The classical fiction-editing test (Stephen King and most line editors): if dropping the adverb does not change the meaning, the verb is the problem.

**Detect:**
- `-ly` adverbs modifying speech tags: `said softly`, `whispered quietly`, `shouted loudly`, `replied curtly`
- Adverbs that restate the verb: `whispered quietly`, `shouted loudly`, `ran quickly`, `mumbled under his breath`
- Multiple `-ly` adverbs in adjacent sentences (a passage sprinkled with them rather than one used for emphasis)
- Stacking with hedges: `gently`, `slightly`, `rather`, `somewhat` modifying the same verb or following each other across a paragraph (cross-references "Hedging and qualifier stacking" in Tonal Tells)

**Fix:** Prefer a stronger verb. `said softly` -> `whispered`. `ran quickly` -> `sprinted`. `smiled warmly` -> `beamed`. `looked carefully at` -> `studied`. Delete adverbs that restate the verb outright.

**Exception:** Keep the adverb when it carries information the verb cannot. `said reluctantly`, `answered honestly`, `arrived late`, `she nodded slowly` (when the slowness is the point) all earn their place. The test: drop the adverb. If meaning shifts, keep it. If only rhythm shifts, the verb was weak.

#### Elegant variation

LLMs avoid repeating a noun within a paragraph, substituting increasingly strained synonyms. A character named Alice becomes `the protagonist`, `the main character`, `the young woman`, `the eponymous heroine` in four consecutive sentences.

**Detect:**
- The same entity referred to by 3+ different nouns in close proximity
- Strained synonyms where a pronoun or name repetition would be natural
- Different technical terms for the same concept within one document

**Fix:** Use the name, or a pronoun. Repetition is fine. Forced variation is worse than repetition.

#### Superficial participle tails

A sentence ending in a comma plus an `-ing` clause that restates what the sentence already
said. Implies consequence without asserting one.

**Detect:** `..., highlighting the need for X`, `..., ensuring reliability`, `..., reflecting
a broader shift`, `..., showcasing the team's expertise`, `..., underscoring its importance`.
Test: cut the clause. If nothing is lost, it was decoration.

**Fix:** Delete the tail. If the consequence is real, promote it to its own sentence with a
stated mechanism: `..., ensuring reliability` -> `Retries cover the transient failures.`

#### False ranges

`from X to Y` where X and Y do not sit on a shared scale, used to imply comprehensive coverage
of what is really two examples.

**Detect:** `everything from authentication to deployment`, `from startups to enterprises` with
no middle named. Test for a meaningful midpoint: `from 10ms to 2s` is a real range, `from CI to
observability` is not.

**Fix:** List the items directly. `covers authentication and deployment`.

#### Passive voice with an unnamed actor

`is/are/was/were + past participle` that drops the actor: `queries are validated`, `errors are
logged`. Ask who does it; if the answer is in the document but not the sentence, name it.

**Fix:** Promote the actor to subject. `the compiler validates queries`.

**Exception:** correct when the actor is unknown, irrelevant, or withheld on purpose (incident
writeups, scientific method sections). See `references/plain-speech.md`.

#### Dense sentence stacking

Three or more clauses chained with commas, `and`, `which`, and `while`. Length is not the tell,
backtracking is: flag sentences needing a second pass to locate the verb.

**Fix:** Split at the clause boundary, or drop the clause carrying the least. One idea per
sentence. Worked before/after in `references/plain-speech.md`.

### 3. Tonal Tells (Soul)

The voice of the text gives away the author even when the words are individually defensible.

#### Travel-guide voice

`Nestled between rolling hills, this vibrant city boasts a rich cultural heritage and a thriving arts scene`. LLMs default to this register for any geographic or cultural topic.

**Detect:** `nestled`, `rolling hills`, `vibrant`, `thriving`, `rich heritage`, `bustling`, `charming`, `picturesque`

**Fix:** State facts. `The city has 300,000 people, two universities, and a jazz festival in August.`

#### Promotional tone

`Our commitment to excellence ensures we foster innovation and empower our customers to succeed.` LLMs reach for press-release cadence when asked to describe any organization or product.

**Detect:** `commitment to`, `empower`, `foster`, `ensure`, `strive`, `dedicated to`, `passionate about`, `industry-leading`, `cutting-edge`, `next-generation`

**Fix:** Replace with specific claims. `We help X customers do Y` beats `We empower customers to succeed`.

#### Vague attribution

`Experts say`, `industry reports indicate`, `observers have noted`, `many believe`. LLMs use these when they want to assert something without a source. Real writers either cite or own the claim.

**Detect:**
- `experts say` / `experts agree` without naming experts
- `industry reports` / `studies show` without a study
- `observers have noted` / `critics argue` without names
- Plural `sources say` pointing to at most one source

**Fix:** Cite the source. Or own the claim. Or cut it - most of the time the surrounding sentence works without the attribution.

#### Significance padding

`This marks a pivotal moment, underscoring broader trends in the industry.` LLMs inflate the weight of routine events to pad word count.

**Detect:**
- `marks a pivotal moment`
- `underscoring broader trends`
- `highlighting the importance of`
- `serves as a reminder that`
- `in an era where`
- `in today's fast-paced world`

**Fix:** Delete the whole sentence. If what follows does not make sense without the padding, rewrite the surrounding paragraph.

#### Hedging and qualifier stacking

LLMs stack hedges and qualifiers to sound cautious or balanced. Each hedge by itself is fine English; stacking them makes every claim feel tentative.

**Detect:**
- Frequent `generally`, `typically`, `often`, `usually`, `in many cases`, `for the most part`
- Weak modal stacking: `may`, `can`, `might`, `could potentially`, `arguably`, `relatively`
- Two or more hedges in the same clause: `can generally be considered to be relatively reliable`
- Hedges on claims that the author clearly knows are true: `this may help with performance` (when benchmarks are already in the paragraph)

**Fix:** Delete the hedge and state the claim. If the claim really does need a caveat, state it concretely: `on Linux only`, `for connections over 1000 RPS` - not `generally speaking`.

#### Scaffolding padding

Phrases that wrap around the actual content without adding information. LLMs lean on these to sound organized or conversational.

**Detect:**
- `it's worth noting that`, `it's important to note`, `it's worth mentioning`
- `in this article, we'll explore` / `in this guide, we'll cover` (meta-commentary about the piece itself)
- `let's dive into` / `let's explore` / `let's take a look at`
- `here's the thing:` / `the fact is:` / `the truth is:`
- `at the end of the day` / `when all is said and done`
- `as we've seen` / `as mentioned earlier` / `as previously discussed` (when the reader just read it)
- Wordy connectives with a one-word equivalent: `in order to` -> `to`, `due to the fact that` -> `because`, `in the event that` -> `if`, `for the purpose of` -> `to`, `with regard to` -> `about`, `a large number of` -> `many`, `at this point in time` -> `now`

**Fix:** Cut the wrapper and keep the content. `It's worth noting that X` becomes `X`. `In this article, we'll explore Y` becomes a first sentence that is about Y.

#### Confident filler and false emphasis

LLMs punctuate with manufactured confidence and rhetorical scaffolding that announces insight instead of delivering it.

**Detect:**
- Emphasis crutches: `Full stop.`, `Period.` (as standalone emphasis), `let that sink in`, `make no mistake`, `here's why that matters`
- Rhetorical setups: `What if...`, `Imagine...`, `Think about it:`, `Picture this`
- Faux-profundity fragment: a curt closer that asserts depth instead of earning it - `<short sentence>. That's it.`, `Simple as that.`, `Nothing more.`

**Fix:** Cut the wrapper; make the claim carry its own weight. Density is the tell: one earned `that's it` is voice, three is a tic. Overlaps significance padding (`serves as a reminder that`) and scaffolding padding (`let's dive into`); when a phrase fits more than one bucket, count it once under the densest cluster, not in every bucket it touches.

#### "Despite its X, faces challenges"

LLMs reach for a formula when asked to describe any organization or project: positives first, then a "however" paragraph listing challenges, often ending with a "future outlook" paragraph.

**Detect:** the shape of the article more than specific words. Three-paragraph structure where paragraph 1 is positive, paragraph 2 starts with `Despite` or `However`, and paragraph 3 starts with `Looking ahead` or `The future`.

**Fix:** Reorganize around the actual story. If there is no story, the piece probably should not exist.

#### Chat artifacts and sycophancy

Assistant-voice residue that survives a copy-paste out of a chat window into a doc, PR, or
email. Also the highest-value check in inline mode, where it applies to the reply itself.

**Detect:** openers (`Great question!`, `Certainly!`, `You're absolutely right!`), closers
(`I hope this helps!`, `Let me know if you have any questions`), progress theater (`Found the
smoking gun!`, `Perfect!` as a standalone reaction), and restating the request before answering it.

**Fix:** Delete. Open with the answer, close when the answer ends. In inline mode this is a hard
rule with no density threshold: one `Great question!` is one too many.

#### Cutoff and knowledge disclaimers

Hedges about the model's own limits, left in text a human is supposed to have written:
`While specific details are limited`, `As of my last update`, `I don't have access to
real-time data`, `Based on available information`.

**Fix:** Find the fact and state it, or cut the sentence. If the uncertainty is real, name what
is unknown and why: `The 2026 figures are not published yet`.

#### Feeling instead of mechanism

Prose naming an impression rather than a fact the reader can act on. Ask what the sentence tells
the reader to do or know: `the database stays close at hand`, `SQL you can read`, `types that
follow your schema` all fail that test.

**Fix:** Replace with the mechanism, a number, or an instruction. `.toSQL() returns the exact
string sent to the database.` If no concrete restatement exists, cut the sentence. Table and
exceptions in `references/plain-speech.md`.

#### Generic forward-looking conclusions

A closing paragraph gesturing at the future without committing: `The future looks bright`,
`Only time will tell`, `As the space continues to evolve`, `The possibilities are endless`.

**Fix:** State a specific plan, date, or fact, or end on the last real point. A piece does not
need a conclusion paragraph to be finished.

### 4. Formatting Tells (Noise)

Layout and punctuation patterns that LLMs default to.

**Detect:**
- **Em dashes** (Unicode U+2014, or the `--` double-dash substitute) used as sentence breaks. LLMs overuse them to imitate journalistic cadence. Replace with single `-` or restructure the sentence. Do not swap in parentheses or en dashes instead: that trades one tell for another. If the thought needs separation, end the sentence or use a comma.
- **Title Case in section headings** (`Understanding the Core Concepts` vs `Understanding the core concepts`). AI defaults to title case even in sentence-case conventions. Match the project's style.
- **Excessive bold** - every third noun bolded for no reason. Bold earns its use by signaling a term or path.
- **Bullet salad** - prose turned into bullets when a paragraph would read better. Lists are for enumerations, not for every idea.
- **Three-bullet-happy layouts** - suspicious when every list has exactly three items
- **Curly quotes** (`"`, `'`) in technical writing that should use ASCII
- **Emoji** in professional prose where decoration is the only purpose
- **Decorative thematic breaks** - `---` before every `##`. Dividers that mark a real phase change are fine; decoration is not
- **Markdown artifacts in rendered text** - `**bold**` appearing as literal characters because the paste lost its format
- **LLM output bugs** - `turn0search0`, `contentReference`, `oaicite`, `+1`, `attached_file`, hallucinated wiki-style shortcuts

**Fix:** Match the surrounding project's conventions. If there is no convention, default to plain ASCII, sentence case, minimal bold, paragraph prose.

#### Colon as a mid-sentence connector

A colon whose right side is a full clause that would read the same as its own sentence, adding
a beat of false setup: `If you're coming from traditional automation: instead of registering
event handlers, you describe conditions.`

**Fix:** End the sentence, or rewrite so the point stands without the comparison framing.

**Exception:** colons before lists, definitions, quotes, and code blocks are correct, as is one
introducing a real specification (`One rule: never force-push shared branches`).

#### Inline-header lists that restate themselves

A bold label followed by a colon whose text repeats the label:
`**Performance:** Performance improved by 12%.`

**Fix:** Convert to prose, or drop the label. `Performance improved by 12%.`

**Exception:** a bold lead-in ending in a period that names the item and is followed by new
detail is a definition list, not a tell: `**Schema in TypeScript.** Tables live in one file.`

---

## Restoring Voice

Removing tells is half the work. Prose stripped of every pattern and given nothing back reads as
sterile, which is its own tell. Rewrites should carry a position, varied rhythm, acknowledged
complexity, first person where it fits, and specifics. Long form in `references/plain-speech.md`.

In **audit mode**, voice notes are `Consider`-level, never `Fix`. Voice belongs to the author.
Never rewrite a piece into your own voice under the banner of removing AI tells. In **inline
mode**, apply this to your own drafting rather than reporting on it.

---

## What NOT to Flag

These look like AI tells but are not:

- **Direct quotations** - do not edit words written by someone else, even if they contain banned vocabulary
- **Genre conventions** - travel writing uses travel-guide voice because that is what travel writing sounds like. Marketing copy uses promotional tone. Journalism uses em-dashes. Fiction uses elegant variation and tricolons intentionally. Respect the genre.
- **Technical terms of art** - `pivotal` in mechanical engineering, `realm` in networking or identity (Kerberos, OIDC), `foster` in child welfare, `landscape` in horticulture or graphic design, `crucial experiment` in philosophy of science
- `landscape` in ML/AI contexts (optimization landscape, loss landscape, feature landscape)
- `robust` in statistics/ML (robust estimation, robust optimization, robust regression)
- **Deliberate register play** - satire, parody, pastiche, and stylistic experiments
- **Direct speech / dialog** in fiction - characters can sound however they sound
- **Lists that are actually lists** - a three-item list is only suspicious if the items are padded. An enumeration of three real things is fine
- **Bold where it signals a term or path** - bolding a defined term on first use is standard
- **Em dashes in publications that require them** - some style guides (Chicago, AP) allow or require em dashes. The rule applies to your project's conventions
- **Deliberate passive voice** - when the actor is unknown, irrelevant, or withheld on purpose. Incident writeups keep blame off individuals by design. Scientific method sections use passive by convention
- **Colons before lists, definitions, quotes, or code blocks** - that is what colons are for. Only the mid-sentence clause joint is a tell
- **Definition-list bold lead-ins** - `**Term.** New detail follows.` is a real pattern. The tell is only the label that restates itself: `**Performance:** Performance improved...`
- **Real ranges** - `from 10ms to 2s`, `from v1 to v4` sit on a shared scale. Only ranges with no meaningful midpoint are false ranges
- **Long sentences that parse on first read** - length is not the tell, backtracking is
- **Terms of art among the abstract metaphor nouns** - `vector` in linear algebra, `primitive` in cryptography, `locus` in genetics, `harness` in test tooling
- **A genuine rhetorical question or single hard fragment** - one "What if X?" that the piece actually answers, or one deliberate "That's it." landing a point, is voice. Flag the pattern (stacked setups, repeated faux-profundity fragments), not the isolated use. An earned single use is not a tell, so it does not count toward the short-text density threshold or escalate to P1 on its own - it is the stacking that carries the severity.

### Counter-example (prose that looks AI but is fine)

> Nestled in the loss landscape near a sharp minimum, the model's robust features fail to generalize. This underscores a pivotal result from Keskar et al. (2017): flat minima tend to foster better test accuracy than sharp ones.

Looks flagged at a glance: `nestled`, `landscape`, `robust`, `underscores`, `pivotal`, `foster`. But every term is a term of art (ML optimization, statistics), `underscores` has a real referent, and the citation is real. Verdict: **Fine**. Do not flag. Domain context overrides vocabulary match.

---

## Output Format

Audit mode only. See `references/audit-mode.md` for the report template, the rules for the
report itself, and a worked example anchoring the format.

Inline mode has no output format: the cleaned prose is the output.

## Reference Files

- `references/audit-mode.md` - audit-mode workflow, scoping, density and severity scales, the
  report template, and a worked example
- `references/plain-speech.md` - abstract metaphor nouns, the concreteness test, the actor
  test, sentence splitting, and voice restoration in long form with worked examples
- `references/fiction-name-tells.md` - AI fallback character names, the phonetic pattern, and
  when a fallback-set name is legitimate
- `references/agent-hygiene.md` - cross-cutting agent hygiene checks shared across the collection
- `references/output-contract.md` - the shared output contract

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** ANTI-AI-PROSE
- **Deliverable bucket:** `audits`
- **Mode:** conditional, split on the two modes above. **Audit mode** (a file, paste, diff, or directory handed over for review) emits the full contract - boxed inline header, body summary inline plus per-finding detail in the deliverable file, boxed conclusion, conclusion table. **Inline mode** (filtering your own conversational output as you write it) emits nothing: no header, no findings, no deliverable, no announcement that the skill ran.
- **Deliverable path:** `docs/local/audits/anti-ai-prose/<YYYY-MM-DD>-<slug>.md`
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract).

## Related Skills

- **anti-slop** - code quality audit. When auditing a repo, run anti-slop for code and anti-ai-prose for docs. The two are deliberately complementary.
- **update-docs** - keeps docs accurate and trimmed after feature changes. Anti-ai-prose focuses on voice; update-docs focuses on factual drift.
- **prompt-generator** - structures a rough draft into an LLM prompt. If the user wants to generate cleaner prose next time, this helps shape the prompt.
- **full-review** - orchestrates code-review, anti-slop, security-audit, and update-docs. Not wired into full-review by default - invoke anti-ai-prose separately when the repo has substantial prose worth auditing.
- **code-review** - catches logic and correctness issues. Anti-ai-prose only touches prose; code-review handles the code itself.

---

## Rules

1. **Read the full piece before flagging.** A single `delve` in a 10,000-word book is not a pattern. Three in a paragraph is. Context determines severity.
2. **Never edit quoted material.** Original words from other authors stay as written.
3. **Respect genre conventions.** Travel writing, marketing, fiction, and academic prose have legitimate conventions that overlap with AI tells. Flag only when the writing is worse for the device, not because it matches a pattern.
4. **Every rewrite must be shorter or more specific.** Lateral synonym swaps are not improvements. If the rewrite is longer, the original was fine.
5. **Plan first, apply that plan only.** When applying fixes after the audit, change only what the report flagged. Do not freelance edits, do not rewrite adjacent prose, and do not chain a second pass of new fixes on top of the applied ones. New findings during application become a follow-up audit, not silent edits.
6. **Keep the voice of the author.** The goal is prose that sounds like a specific human, not a generic "good writing" rewrite. If you do not know the author's voice, leave stylistic calls alone and only flag the mechanical tells.
7. **Do not pad the report.** If there are three findings, list three. Not five. Not one inflated to three.
8. **Run the AI Self-Check** before returning any audit.
9. **Inline mode is silent.** Applying these rules to your own output produces cleaner prose and nothing else. No report, no findings, no deliverable, no note that the skill ran. A user who wanted an audit will ask for one.
10. **The user's style outranks these rules.** Explicit instructions, then project instruction files, then genre convention, then this skill. A house style that mandates em dashes or title case is not a finding.
11. **In your own output, drop the density thresholds.** They exist to stop overflagging someone else's long document. One chat artifact in your own reply is one too many.
