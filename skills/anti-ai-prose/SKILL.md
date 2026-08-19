---
name: anti-ai-prose
description: >
  · Strip AI tells from prose in docs, PRs, emails, and your own replies. Filters every response once loaded; full audit on request. Triggers: 'unslop', 'ai writing', 'sounds like chatgpt', 'llm voice'. Not for code (use anti-slop).
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

- Auditing a README, doc page, or wiki article that feels machine-written, or a PR body, commit message, or release note draft before publishing
- Polishing a blog post, email, script, or creative writing drafted with LLM help, or reviewing docstrings and code comments for the same patterns
- Any time someone says "this sounds like ChatGPT wrote it", or self-checking after heavy LLM drafting
- Filtering your own replies, explanations, and drafts as you write them (inline mode, see below)

## When NOT to use

- Code quality, over-abstraction, dependency creep, stale idioms - use **anti-slop**
- Doc drift after a feature change, API rename, or config update - use **update-docs**
- Generating or restructuring a prompt from rough notes - use **prompt-generator**
- Correctness bugs, logic errors, edge cases - use **code-review**
- Security review of auth, secrets, or attack surface - use **security-audit**, or **full-review** for a full multi-dimensional repo audit

---

## Two modes

This skill runs in one of two modes. Pick the mode from the trigger, not from the content.

### Inline mode (default)

Applies to your own conversational output: chat replies, explanations, summaries, commit
bodies, PR descriptions, and any prose you draft for the user. Apply it to every response for
as long as this skill is in context, without being asked again. It cannot clean replies drafted
before it loaded, so load it early when prose quality matters.

- Apply the pattern rules silently while writing. This filters drafting, it does not review a finished draft.
- Emit **no report, no findings, no severity ratings, no deliverable file**, and no note that the skill ran.
- Do not restructure the user's own words when quoting them back.
- Density thresholds do not apply. Fix every tell you catch in your own output.
- Before sending, ask: "what in this reply reads as machine generated?" Fix what that surfaces.

### Audit mode (explicit)

Applies to text the user hands over: a file, a paste, a diff, a directory. Triggered by an
explicit request ("audit this", "does this sound like AI", "unslop this doc") or by invoking
the skill against a target. Run the full Workflow below, emit the full output contract, and
apply the density thresholds so isolated instances in long documents are not flagged.

### Precedence

When rules conflict, later entries lose: (1) the user's explicit instruction in this
conversation, (2) project instruction files (`CLAUDE.md`, `AGENTS.md`, repo style guide),
(3) genre convention of the text being written, (4) this skill's pattern rules. A house style
that mandates em dashes, title-case headings, or a formal register is not a finding. Inline
mode adapts to it rather than overriding it.

---

## AI Self-Check

Always, in both modes:

- [ ] **Mode picked correctly**: inline mode emitted no report, no findings list, and no deliverable file; audit mode emitted the full contract. The two were not mixed in one response
- [ ] **Chat artifacts cleared**: no `Great question!`, `I hope this helps!`, `Certainly!`, or cutoff disclaimer survived into the output, in either mode

Audit only:

- [ ] **Findings are patterns, not taste**: every finding is a demonstrable AI tell, not a writing preference, and plain-but-valid technical prose was not labeled AI-written without concrete evidence
- [ ] **Context respected**: genre conventions (academic, journalism, marketing, tourism) and domain terms of art were not flagged - `pivotal` in hinge hardware, `landscape` in horticulture, `foster` in child welfare, `realm` in Kerberos
- [ ] **Direct quotes preserved**: quoted material from other authors was not edited, even when it contains banned vocabulary
- [ ] **Code untouched, prose audited**: identifiers, string literals, and API names were not flagged for containing a banned word. Prose *inside* comments and docstrings is a valid target; the code around it is not
- [ ] **All four categories scanned**, including the checks that are easy to skip: adverb stacking, confident filler, the plain-speech set (participle tails, false ranges, unnamed-actor passives, dense sentence stacking, feeling-instead-of-mechanism), and fiction fallback names
- [ ] **Density and short-text rule applied**: density set severity, and text under 100 words with 2+ tells in one paragraph was rated P1 regardless of the per-500-word threshold
- [ ] **Severity is honest**: no P3 inflated to P2 to pad the report, and no finding count padded
- [ ] **Rewrites are real improvements**: every "after" is shorter, clearer, or more specific than the "before", carries a position and specifics, and invents no fact the source did not have. No lateral synonym swaps, and voice suggestions are marked `Consider`, never `Fix`
- [ ] **Audience preserved**: edits keep the author's domain vocabulary, intent, and required formality
- [ ] **House style respected**: explicit user instructions and project instruction files outranked this skill's pattern rules; a mandated em dash or title-case convention was not reported as a finding
- [ ] **Audit output itself uses no AI-prose tells** (apply these rules to your own output)
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

---

## Performance

- Read the whole piece before flagging - density is a per-500-word ratio and a sample cannot produce it. Sampling decides whether a *directory* is worth auditing, not how a document scores.
- Group repeated issues by pattern instead of near-duplicate comments on every paragraph, and prioritize high-visibility text: titles, summaries, intros, conclusions, user-facing docs.

---

## Best Practices

- Flag exact phrases and structural patterns, not vibes.
- Offer replacement copy when the fix is obvious; otherwise describe the problem and let the author decide.
- Do not erase necessary caveats, compliance language, or domain-specific precision to make prose sound casual.

## Workflow

Audit mode only. Full detail in `references/audit-mode.md`: scoping rules, the text-kind list,
the density heuristic, the action and severity scales, and the report template with a worked
example.

1. **Scope.** Audit the file or paste given. With no target, fall back to uncommitted doc changes,
   then to docstrings in changed files, then ask.
2. **Detect text kind.** Technical docs, README/PR/commit, marketing, fiction, wiki, email, and
   slides each carry conventions that change what counts as a tell.
3. **Scan.** Apply the four categories below. Read surrounding context before flagging: one AI
   word in 5000 words is noise, three in three paragraphs is a pattern. Density sets severity;
   text under 100 words with 2+ tells in a paragraph is P1 regardless. Some checks skip density
   because one instance is already the finding: travel-guide voice, promotional tone, the
   formulaic article shape, chat artifacts, and an AI fallback character name. Trust breaches
   skip it too, at P0 in text meant to ship - a fabricated citation, an invented fact, a leaked
   secret, generator residue, or a cutoff disclaimer under a human byline.
   `references/audit-mode.md` holds the authoritative gated/not-gated list.
4. **Report and fix.** Group by category, show the concrete rewrite, keep every rewrite shorter or
   more specific than the original. **Plan first, apply that plan only:** when the user asks for
   fixes, change only what the report flagged. New findings during application become a second
   audit, never silent edits.

---

## The Four Categories of AI Prose Slop

### 1. Vocabulary Tells

Specific words that LLMs overuse far beyond their natural English frequency.

**Flagged vocabulary** (context-sensitive - see exceptions below):

Grouped by the fix. `(or cut)` marks the words that are usually padding, where the phrase
should go rather than get a substitute.

**Say "use":** leverage, utilize -> use. facilitate -> help, enable.

**Use a plain verb:** delve / dive deep into -> look at, examine, dig into, cover. showcase ->
show, display, feature. navigate -> handle, work through, manage. garner -> get, earn, attract.
underscore -> show, highlight, confirm. enhance -> improve, speed up, extend (or name the
change). ensure -> make sure, guarantee (or name the mechanism). empower -> help, enable, let.
foster -> build, grow, support, encourage. boast -> has. commence / embark on -> start, begin.

**Use a plain noun:** realm -> area, field, world. landscape -> scene, field, mix. tapestry ->
mix, range, variety (or cut the metaphor). testament -> proof, evidence, example. interplay ->
how X and Y interact (or cut). synergy -> fit, overlap, how X and Y work together (or cut).

**Use a plainer adjective:** enduring -> lasting, long-running. numerous -> many. nestled ->
set, located, built. innovative -> new, novel (or name what is new).

**Padding adjectives**, all `(or cut)` by default - substitute only when the adjective does
real work: pivotal / crucial -> key, important, central, needed. nuanced -> subtle, careful,
specific. intricate -> detailed, complex. multifaceted -> has many sides, covers a lot.
holistic -> whole, end-to-end, full. seamless -> smooth. robust -> reliable, solid. vibrant ->
lively, active, busy.

**Padding phrases**, same rule: commitment to -> cares about, focuses on. journey toward ->
work toward, move toward, aim for. moving forward -> from now on, next. additionally -> also,
and (or start the sentence with the content).

**Detect:**
- Multiple flagged words in the same paragraph
- Flagged word used metaphorically (`tapestry of experiences`, `realm of possibility`)
- Flagged word in a context where a plain verb would work (`showcase the features` -> `show the features`)

**Fix:** Replace with the plain alternative. If the sentence gets weaker after replacement, the original was padding - cut the whole phrase.

See "What NOT to Flag" below for domain exceptions (horticulture `landscape`, child welfare `foster`, networking `realm`, etc.).

#### AI fallback character names (fiction)

Generated fiction converges on soft, no-baggage names such as `Elara`, `Kael`, or `Voss`. Not
density-gated: one such protagonist name is the finding. See `references/fiction-tells.md` for
the phonetic test and the exceptions.

#### Abstract metaphor nouns

Nouns that read as technical but stand in for a plainer word: `substrate`, `wedge`, `vector`,
`locus`, `vantage`, `nexus`, `primitive` (as noun), `harness` (as metaphor), `surface` (as in
"API surface"), `bedrock`, `scaffolding` (as metaphor), `modality`, `paradigm`, `gold-plating`.

**Detect:** the noun carries no measurement, no referent, and no consequence. **Fix:** name the
concrete thing - `substrate` -> `base`, `wedge in` -> `add`, `vector` -> `way`. **Exception:** each
is a term of art somewhere (`vector` in linear algebra, `locus` in genetics); full table in
`references/plain-speech.md`.

### 2. Syntax Tells

Sentence structures LLMs reach for to sound balanced or significant.

#### Negative parallelism

`not X but Y` and `not just X, but also Y`, used to signal balance. Fine English in moderation, a clear tell in quantity.

**Detect:** three or more `not X but Y` / `it's not about X, it's about Y` structures in one piece, or one used where a direct claim would work: `this isn't just a tool, it's a platform` -> `this is a platform`.

**Fix:** State the positive claim directly. If the contrast matters, keep one instance and rewrite the rest.

#### Forced tricolons (rule of three)

`X, Y, and Z` lists used for rhythm rather than enumeration. LLMs default to three items even when two or four would be more accurate.

**Detect:**
- Adjective triplets where one adjective carries the meaning (`a fast, reliable, and scalable system`), or noun triplets that are really one concept (`clarity, precision, and accuracy`)
- Three-item lists where the third item is obviously padded to hit the count

**Fix:** Drop the weakest item. Use two items when the point is a contrast, four or more when it is an actual list.

#### Copula avoidance

LLMs avoid plain `is` / `are` / `has` / `have` in favor of elaborate constructions: `serves as`, `marks`, `represents`, `features`, `offers`, `boasts`, `stands as`.

**Detect:** `it serves as a backup` -> `it is a backup`. `this represents a shift` -> `this is
a shift`. `the app boasts 50 features` -> `the app has 50 features`. `this marks the first
time` -> `this is the first time`.

**Fix:** Use the plain copula. Elaborate verbs should carry weight - do not spend them on simple identity claims.

#### Adverb crutch and elegant variation

Two line-editing tells. **Adverb crutch:** `-ly` adverbs inflating description in place of a
precise verb (`said softly`, `ran quickly`, `whispered quietly`). Density is the tell, not any
single use. Test: drop the adverb. If only rhythm shifts, the verb was weak - `said softly` ->
`whispered`. Keep adverbs carrying information the verb cannot (`answered honestly`).

**Elegant variation:** the same entity named by 3+ strained synonyms in close proximity -
Alice becomes `the protagonist`, `the young woman`, `the eponymous heroine`. Fix: use the name
or a pronoun. Repetition beats forced variation.

Detect lists, worked fixes, and exceptions for both: `references/fiction-tells.md`.


#### Superficial participle tails

A sentence ending in a comma plus an `-ing` clause that restates what the sentence already
said, implying consequence without asserting one: `..., highlighting the need for X`, `...,
ensuring reliability`, `..., reflecting a broader shift`, `..., showcasing the team's
expertise`, `..., underscoring its importance`.

**Detect:** cut the clause. If nothing is lost, it was decoration. **Fix:** delete the tail; if
the consequence is real, promote it to its own sentence with a stated mechanism - `..., ensuring
reliability` -> `Retries cover the transient failures.`

#### False ranges

`from X to Y` where X and Y do not sit on a shared scale, implying comprehensive coverage of
what is really two examples: `everything from authentication to deployment`, `from startups to
enterprises` with no middle named.

**Detect:** test for a meaningful midpoint. `from 10ms to 2s` is a real range, `from CI to
observability` is not. **Fix:** list the items directly - `covers authentication and deployment`.

#### Passive voice with an unnamed actor

`is/are/was/were + past participle` that drops the actor: `queries are validated`, `errors are
logged`. Ask who does it; if the answer is in the document but not the sentence, name it.

**Fix:** promote the actor to subject - `the compiler validates queries`. **Exception:** passive
is correct when the actor is unknown, irrelevant, or withheld on purpose (incident writeups,
scientific method sections). See `references/plain-speech.md`.

#### Dense sentence stacking

Three or more clauses chained with commas, `and`, `which`, and `while`. Length is not the tell,
backtracking is: flag sentences needing a second pass to locate the verb.

**Fix:** Split at the clause boundary, or drop the clause carrying the least. One idea per
sentence. Worked before/after in `references/plain-speech.md`.

### 3. Tonal Tells

The voice gives away the author even when the words are individually defensible. Travel-guide
voice, promotional tone, the formulaic shape, chat artifacts, and cutoff disclaimers are not
density-gated: one instance is the finding. The sentence-level tells here - vague attribution,
significance padding, hedging, scaffolding, confident filler, feeling-instead-of-mechanism -
are gated like the vocabulary tells.

#### Travel-guide voice

`Nestled between rolling hills, this vibrant city boasts a rich cultural heritage and a thriving arts scene`. The default register for any geographic or cultural topic.

**Detect:** `nestled`, `rolling hills`, `vibrant`, `thriving`, `rich heritage`, `bustling`, `charming`, `picturesque`. **Fix:** state facts - `The city has 300,000 people, two universities, and a jazz festival in August.`

#### Promotional tone

`Our commitment to excellence ensures we foster innovation and empower our customers to succeed.` Press-release cadence, reached for when describing any organization or product.

**Detect:** `commitment to`, `empower`, `foster`, `ensure`, `strive`, `dedicated to`, `passionate about`, `industry-leading`, `cutting-edge`, `next-generation`. **Fix:** replace with specific claims - `We help X customers do Y` beats `We empower customers to succeed`.

#### Vague attribution

`Experts say`, `industry reports indicate`, `observers have noted`, `many believe`. LLMs use these when they want to assert something without a source. Real writers either cite or own the claim.

**Detect:** `experts say` / `experts agree` with no expert named, `industry reports` /
`studies show` with no study, `observers have noted` / `critics argue` with no names, plural
`sources say` pointing to at most one source.

**Fix:** Cite the source. Or own the claim. Or cut it - most of the time the surrounding sentence works without the attribution.

#### Significance padding

`This marks a pivotal moment, underscoring broader trends in the industry.` LLMs inflate the weight of routine events to pad word count.

**Detect:** `marks a pivotal moment`, `underscoring broader trends`, `highlighting the
importance of`, `serves as a reminder that`, `in an era where`, `in today's fast-paced world`.

**Fix:** Delete the whole sentence. If what follows does not make sense without the padding, rewrite the surrounding paragraph.

#### Hedging and qualifier stacking

LLMs stack hedges and qualifiers to sound cautious or balanced. Each hedge by itself is fine English; stacking them makes every claim feel tentative.

**Detect:**
- Frequent `generally`, `typically`, `often`, `usually`, `in many cases`, `for the most part`, or weak modal stacking: `may`, `can`, `might`, `could potentially`, `arguably`, `relatively`
- Two or more hedges in the same clause: `can generally be considered to be relatively reliable`
- Hedges on claims the author clearly knows are true: `this may help with performance`, when benchmarks are already in the paragraph

**Fix:** Delete the hedge and state the claim. If the claim really does need a caveat, state it concretely: `on Linux only`, `for connections over 1000 RPS` - not `generally speaking`.

#### Scaffolding padding

Phrases that wrap around the actual content without adding information. LLMs lean on these to sound organized or conversational.

**Detect:**
- `it's worth noting that`, `it's important to note`, `it's worth mentioning`, `here's the thing:`, `the fact is:`, `the truth is:`, `at the end of the day`, `when all is said and done`
- Meta-commentary about the piece itself: `in this article, we'll explore`, `in this guide, we'll cover`, `let's dive into`, `let's explore`, `let's take a look at`
- `as we've seen` / `as mentioned earlier` / `as previously discussed`, when the reader just read it
- Wordy connectives with a one-word equivalent: `in order to` -> `to`, `due to the fact that` -> `because`, `in the event that` -> `if`, `for the purpose of` -> `to`, `with regard to` -> `about`, `a large number of` -> `many`, `at this point in time` -> `now`

**Fix:** Cut the wrapper and keep the content. `It's worth noting that X` becomes `X`. `In this article, we'll explore Y` becomes a first sentence that is about Y.

#### Confident filler and false emphasis

LLMs punctuate with manufactured confidence and rhetorical scaffolding that announces insight instead of delivering it.

**Detect:**
- Emphasis crutches: `Full stop.`, `Period.` (as standalone emphasis), `let that sink in`, `make no mistake`, `here's why that matters`
- Rhetorical setups: `What if...`, `Imagine...`, `Think about it:`, `Picture this`
- Faux-profundity fragment: a curt closer that asserts depth instead of earning it - `<short sentence>. That's it.`, `Simple as that.`, `Nothing more.`

**Fix:** Cut the wrapper; make the claim carry its own weight. Density is the tell: one earned `that's it` is voice, three is a tic. Overlaps significance padding (`serves as a reminder that`) and scaffolding padding (`let's dive into`); when a phrase fits more than one bucket, count it once under the densest cluster, not in every bucket it touches.

#### Formulaic article shape

The default structure LLMs reach for when describing any organization or project: paragraph 1
positive, paragraph 2 opening with `Despite` or `However` to list challenges, paragraph 3
opening with `Looking ahead` or `The future`. The shape is the tell, not the words. Its closing
move also stands alone: a paragraph gesturing at the future without committing - `The future
looks bright`, `Only time will tell`, `As the space continues to evolve`, `The possibilities
are endless`.

**Fix:** Reorganize around the actual story; if there is no story, the piece should not exist.
For the closer specifically, state a plan, a date, or a fact, or end on the last real point. A
piece does not need a conclusion paragraph to be finished.

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

### 4. Formatting Tells

Layout and punctuation patterns that LLMs default to. The four below fire on almost every
draft. The long tail - curly quotes, emoji, decorative `---` breaks, three-bullet-happy
layouts, markdown artifacts, LLM output bugs (`turn0search0`, `oaicite`), the mid-sentence
colon connector, and self-restating inline headers - is in `references/formatting-tells.md`.

**Detect:**
- **Em dashes** (U+2014, or the `--` substitute) as sentence breaks in prose. Replace with a
  single `-` or restructure; parentheses and en dashes just trade one tell for another. Never
  rewrite `--` inside code or fenced blocks - there it is real syntax.
- **Title Case in section headings** (`Understanding the Core Concepts`) where the project uses sentence case.
- **Excessive bold** - every third noun bolded. Bold signals a term or path, nothing else.
- **Bullet salad** - prose bulleted when a paragraph would read better.

**Fix:** Match project conventions. With none, default to plain ASCII, sentence case, minimal bold, paragraph prose.

---

## Restoring Voice

Removing tells is half the work. Prose stripped of every pattern and given nothing back reads
as sterile, which is its own tell. Rewrites should carry a position, varied rhythm,
acknowledged complexity, first person where it fits, and specifics. Long form in
`references/plain-speech.md`. In **audit mode** voice notes are `Consider`-level, never `Fix`:
voice belongs to the author, so never rewrite a piece into your own under the banner of
removing AI tells. In **inline mode** apply this to your own drafting instead of reporting it.

---

## What NOT to Flag

These look like AI tells but are not:

- **Direct quotations** - do not edit words written by someone else, even if they contain banned vocabulary
- **Genre conventions** - travel writing uses travel-guide voice because that is what travel writing sounds like. Marketing copy uses promotional tone. Journalism uses em-dashes. Fiction uses elegant variation and tricolons intentionally. Respect the genre.
- **Technical terms of art** - `pivotal` in mechanical engineering, `realm` in networking or identity (Kerberos, OIDC) and in fantasy fiction, `foster` in child welfare, `landscape` in horticulture, graphic design, or ML (loss landscape), `robust` in statistics and ML (robust estimation), `crucial experiment` in philosophy of science. Each per-check `Exception:` block above applies here too - domain context always overrides a pattern match
- **Deliberate register play** - satire, parody, pastiche, and stylistic experiments
- **Direct speech / dialog** in fiction - characters can sound however they sound
- **Lists that are actually lists** - a three-item list is only suspicious if the items are padded. An enumeration of three real things is fine
- **Em dashes in publications that require them** - some style guides (Chicago, AP) allow or require em dashes. The rule applies to your project's conventions
- **Real ranges** - `from 10ms to 2s`, `from v1 to v4` sit on a shared scale. Only ranges with no meaningful midpoint are false ranges
- **A genuine rhetorical question or single hard fragment** - one "What if X?" that the piece actually answers, or one deliberate "That's it." landing a point, is voice. Flag the pattern (stacked setups, repeated faux-profundity fragments), not the isolated use. An earned single use is not a tell, so it does not count toward the short-text density threshold or escalate to P1 on its own - it is the stacking that carries the severity.

### Counter-example (prose that looks AI but is fine)

> Nestled in the loss landscape near a sharp minimum, the model's robust features fail to generalize. This underscores a pivotal result from Keskar et al. (2017): flat minima tend to foster better test accuracy than sharp ones.

Looks flagged at a glance: `nestled`, `landscape`, `robust`, `underscores`, `pivotal`, `foster`. But `loss landscape` and `robust` are terms of art in ML and statistics, `underscores` has a real referent, `pivotal` and `foster` describe a checkable cited result rather than inflating a routine one, and `nestled` is doing literal spatial work. Six matches, one real cluster's worth of suspicion, zero tells. Verdict: **Fine**. Do not flag. Note the reasoning: domain context and a real referent each override a vocabulary match, and they are different arguments.

---

## Output Format

Audit mode only. See `references/audit-mode.md` for the report template, the rules for the
report itself, and a worked example anchoring the format.

Inline mode has no output format: the cleaned prose is the output.

## Reference Files

- `references/audit-mode.md` - audit workflow, scoping, density and severity scales, report template, worked example
- `references/plain-speech.md` - abstract metaphor nouns, the concreteness and actor tests, sentence splitting, voice restoration
- `references/fiction-tells.md` - AI fallback character names, adverb crutch, elegant variation
- `references/formatting-tells.md` - the formatting long tail
- `references/agent-hygiene.md` - cross-cutting agent hygiene shared across the collection
- `references/output-contract.md` - the shared output contract

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** ANTI-AI-PROSE
- **Deliverable bucket:** `audits`
- **Mode:** conditional, split on the two modes above. **Audit mode** (a file, paste, diff, or directory handed over for review) emits the full contract - boxed inline header, body summary inline plus per-finding detail in the deliverable file, boxed conclusion, conclusion table. **Inline mode** (filtering your own conversational output as you write it) emits nothing: no header, no findings, no deliverable, no announcement that the skill ran.
- **Deliverable path:** `docs/local/audits/anti-ai-prose/<YYYY-MM-DD>-<slug>.md`
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract).

## Related Skills

- **anti-slop** - code quality audit. When auditing a repo, run anti-slop for code and anti-ai-prose for docs. Deliberately complementary.
- **update-docs** - keeps docs accurate after feature changes. Anti-ai-prose covers voice, update-docs covers factual drift.
- **prompt-generator** - structures a rough draft into an LLM prompt, for generating cleaner prose next time.
- **full-review** - orchestrates code-review, anti-slop, security-audit, and update-docs. Anti-ai-prose is not wired in by default; invoke it separately when the repo has substantial prose.
- **code-review** - logic and correctness. Anti-ai-prose only touches prose.

---

## Rules

1. **Read the full piece before flagging.** A single `delve` in a 10,000-word book is not a pattern. Three in a paragraph is. Context determines severity.
2. **Never edit quoted material.** Original words from other authors stay as written.
3. **Respect genre conventions.** Travel writing, marketing, fiction, and academic prose have legitimate conventions that overlap with AI tells. Flag only when the writing is worse for the device, not because it matches a pattern.
4. **Every rewrite must be shorter or more specific.** Lateral synonym swaps are not improvements. If the rewrite is longer, the original was fine.
5. **Plan first, apply that plan only.** When applying fixes after the audit, change only what the report flagged. New findings during application become a follow-up audit, not silent edits.
6. **Keep the voice of the author.** The goal is prose that sounds like a specific human, not a generic "good writing" rewrite. If you do not know the author's voice, flag only the mechanical tells.
7. **Do not pad the report.** If there are three findings, list three. Not five. Not one inflated to three.
8. **Inline mode is silent.** Applying these rules to your own output produces cleaner prose and nothing else: no report, no findings, no deliverable, no note that the skill ran. A user who wanted an audit will ask for one.
9. **In your own output, drop the density thresholds.** They exist to stop overflagging someone else's long document. One chat artifact in your own reply is one too many.
10. **Run the AI Self-Check.** The two mode items apply to every response; the rest before returning an audit.
