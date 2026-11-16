# Tonal Tells

Examples, detect lists, and fixes for each tonal tell. The gating rule (which tells are density-gated) is in SKILL.md.

## Contents

- Travel-guide voice
- Promotional tone
- Vague attribution
- Significance padding
- Hedging and qualifier stacking
- Scaffolding padding
- Confident filler and false emphasis
- Formulaic article shape
- Chat artifacts and sycophancy
- Cutoff and knowledge disclaimers
- Feeling instead of mechanism

## Travel-guide voice

`Nestled between rolling hills, this vibrant city boasts a rich cultural heritage and a thriving arts scene`. The default register for any geographic or cultural topic.

**Detect:** `nestled`, `rolling hills`, `vibrant`, `thriving`, `rich heritage`, `bustling`, `charming`, `picturesque`. **Fix:** state facts - `The city has 300,000 people, two universities, and a jazz festival in August.`

## Promotional tone

`Our commitment to excellence ensures we foster innovation and empower our customers to succeed.` Press-release cadence, reached for when describing any organization or product.

**Detect:** `commitment to`, `empower`, `foster`, `ensure`, `strive`, `dedicated to`, `passionate about`, `industry-leading`, `cutting-edge`, `next-generation`. **Fix:** replace with specific claims - `We help X customers do Y` beats `We empower customers to succeed`.

## Vague attribution

`Experts say`, `industry reports indicate`, `observers have noted`, `many believe`. LLMs use these when they want to assert something without a source. Real writers either cite or own the claim.

**Detect:** `experts say` / `experts agree` with no expert named, `industry reports` /
`studies show` with no study, `observers have noted` / `critics argue` with no names, plural
`sources say` pointing to at most one source.

**Fix:** Cite the source. Or own the claim. Or cut it - most of the time the surrounding sentence works without the attribution.

## Significance padding

`This marks a pivotal moment, underscoring broader trends in the industry.` LLMs inflate the weight of routine events to pad word count.

**Detect:** `marks a pivotal moment`, `underscoring broader trends`, `highlighting the
importance of`, `serves as a reminder that`, `in an era where`, `in today's fast-paced world`.

**Fix:** Delete the whole sentence. If what follows does not make sense without the padding, rewrite the surrounding paragraph.

## Hedging and qualifier stacking

LLMs stack hedges and qualifiers to sound cautious or balanced. Each hedge by itself is fine English; stacking them makes every claim feel tentative.

**Detect:**
- Frequent `generally`, `typically`, `often`, `usually`, `in many cases`, `for the most part`, or weak modal stacking: `may`, `can`, `might`, `could potentially`, `arguably`, `relatively`
- Two or more hedges in the same clause: `can generally be considered to be relatively reliable`
- Hedges on claims the author clearly knows are true: `this may help with performance`, when benchmarks are already in the paragraph

**Fix:** Delete the hedge and state the claim. If the claim really does need a caveat, state it concretely: `on Linux only`, `for connections over 1000 RPS` - not `generally speaking`.

## Scaffolding padding

Phrases that wrap around the actual content without adding information. LLMs lean on these to sound organized or conversational.

**Detect:**
- `it's worth noting that`, `it's important to note`, `it's worth mentioning`, `here's the thing:`, `the fact is:`, `the truth is:`, `at the end of the day`, `when all is said and done`
- Meta-commentary about the piece itself: `in this article, we'll explore`, `in this guide, we'll cover`, `let's dive into`, `let's explore`, `let's take a look at`
- `as we've seen` / `as mentioned earlier` / `as previously discussed`, when the reader just read it
- Wordy connectives with a one-word equivalent: `in order to` -> `to`, `due to the fact that` -> `because`, `in the event that` -> `if`, `for the purpose of` -> `to`, `with regard to` -> `about`, `a large number of` -> `many`, `at this point in time` -> `now`

**Fix:** Cut the wrapper and keep the content. `It's worth noting that X` becomes `X`. `In this article, we'll explore Y` becomes a first sentence that is about Y.

## Confident filler and false emphasis

LLMs punctuate with manufactured confidence and rhetorical scaffolding that announces insight instead of delivering it.

**Detect:**
- Emphasis crutches: `Full stop.`, `Period.` (as standalone emphasis), `let that sink in`, `make no mistake`, `here's why that matters`
- Rhetorical setups: `What if...`, `Imagine...`, `Think about it:`, `Picture this`
- Faux-profundity fragment: a curt closer that asserts depth instead of earning it - `<short sentence>. That's it.`, `Simple as that.`, `Nothing more.`

**Fix:** Cut the wrapper; make the claim carry its own weight. Density is the tell: one earned `that's it` is voice, three is a tic. Overlaps significance padding (`serves as a reminder that`) and scaffolding padding (`let's dive into`); when a phrase fits more than one bucket, count it once under the densest cluster, not in every bucket it touches.

## Formulaic article shape

The default structure LLMs reach for when describing any organization or project: paragraph 1
positive, paragraph 2 opening with `Despite` or `However` to list challenges, paragraph 3
opening with `Looking ahead` or `The future`. The shape is the tell, not the words. Its closing
move also stands alone: a paragraph gesturing at the future without committing - `The future
looks bright`, `Only time will tell`, `As the space continues to evolve`, `The possibilities
are endless`.

**Fix:** Reorganize around the actual story; if there is no story, the piece should not exist.
For the closer specifically, state a plan, a date, or a fact, or end on the last real point. A
piece does not need a conclusion paragraph to be finished.

## Chat artifacts and sycophancy

Assistant-voice residue that survives a copy-paste out of a chat window into a doc, PR, or
email. Also the highest-value check in inline mode, where it applies to the reply itself.

**Detect:** openers (`Great question!`, `Certainly!`, `You're absolutely right!`), closers
(`I hope this helps!`, `Let me know if you have any questions`), progress theater (`Found the
smoking gun!`, `Perfect!` as a standalone reaction), and restating the request before answering it.

**Fix:** Delete. Open with the answer, close when the answer ends. In inline mode this is a hard
rule with no density threshold: one `Great question!` is one too many.

## Cutoff and knowledge disclaimers

Hedges about the model's own limits, left in text a human is supposed to have written:
`While specific details are limited`, `As of my last update`, `I don't have access to
real-time data`, `Based on available information`.

**Fix:** Find the fact and state it, or cut the sentence. If the uncertainty is real, name what
is unknown and why: `The 2026 figures are not published yet`.

## Feeling instead of mechanism

Prose naming an impression rather than a fact the reader can act on (`SQL you can read`).
Replace with the mechanism, a number, or an instruction, or cut the sentence. Table and
exceptions in `references/plain-speech.md` section 2.
