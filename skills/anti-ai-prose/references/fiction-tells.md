# Fiction and line-editing tells

Deep-dive reference for the checks in `SKILL.md` that matter most in fiction and other
long-form prose: invented character names, adverb density, and forced synonym variation.
The first is fiction-only; the last two apply to any prose but earn their detail here
because line editors hit them hardest in narrative text.

---

## Adverb crutch (-ly modifiers)

LLMs reach for `-ly` adverbs to inflate description and dodge precise verb choice: `said
softly`, `ran quickly`, `smiled warmly`, `walked slowly`, `whispered quietly`. Each one in
isolation is acceptable English. Density is the tell. The classical fiction-editing test
(Stephen King and most line editors): if dropping the adverb does not change the meaning,
the verb is the problem.

**Detect:**
- `-ly` adverbs modifying speech tags: `said softly`, `whispered quietly`, `shouted loudly`,
  `replied curtly`
- Adverbs that restate the verb: `whispered quietly`, `shouted loudly`, `ran quickly`,
  `mumbled under his breath`
- Multiple `-ly` adverbs in adjacent sentences - a passage sprinkled with them rather than
  one used for emphasis
- Stacking with hedges: `gently`, `slightly`, `rather`, `somewhat` modifying the same verb or
  following each other across a paragraph. Overlaps "Hedging and qualifier stacking" in
  category 3; count it once, under the denser cluster

**Fix:** Prefer a stronger verb. `said softly` -> `whispered`. `ran quickly` -> `sprinted`.
`smiled warmly` -> `beamed`. `looked carefully at` -> `studied`. Delete adverbs that restate
the verb outright.

**Exception:** Keep the adverb when it carries information the verb cannot. `said
reluctantly`, `answered honestly`, `arrived late`, `she nodded slowly` (when the slowness is
the point) all earn their place. The test: drop the adverb. If meaning shifts, keep it. If
only rhythm shifts, the verb was weak.

---

## Elegant variation

LLMs avoid repeating a noun within a paragraph, substituting increasingly strained synonyms.
A character named Alice becomes `the protagonist`, `the main character`, `the young woman`,
`the eponymous heroine` in four consecutive sentences.

**Detect:** the same entity referred to by 3+ different nouns in close proximity; strained
synonyms where a pronoun or name repetition would be natural; different technical terms for
the same concept within one document.

**Fix:** Use the name, or a pronoun. Repetition is fine. Forced variation is worse than
repetition.

**Exception:** deliberate variation that carries information - `the witness` versus `the
defendant` for the same person at different points in a trial narrative - is craft, not a
tell. Flag only variation that adds nothing but novelty.

---

## Character names and the setting

A name is not an authorship detector. Common names, uncommon names, and invented names can
all work. Flag a naming problem only when it affects the story: readers confuse two central
characters, an unexplained name clashes with an established setting, or every character
sounds interchangeable despite distinct backgrounds.

Prefer names that fit the author's world and are easy to follow. An invented world does not
need a linguistic system unless the story benefits from one. Repeating a name is usually
clearer than cycling through ornate epithets.

Treat naming suggestions as `Consider` unless the text contains a concrete continuity error.
Preserve names the author deliberately chose. A name such as Elara, Luna, or Vasquez needs
no defense merely because it appears in generated fiction elsewhere.
