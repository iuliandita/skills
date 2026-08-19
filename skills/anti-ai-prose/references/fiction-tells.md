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

## AI fallback character names

A documented tell across Claude, ChatGPT, Gemini, DeepSeek, and most open-source models:
when asked to invent character names without strong setting constraints, models converge on a
small "no-baggage" set. The 2025 Name of the Year (per Namerology) is **Elara** specifically
because of AI saturation. The phenomenon is documented well enough that a name from the
fallback set is itself the tell.

**The fallback set** (incomplete; the phonetic pattern below is more reliable than the list):

| Slot | Common picks |
|---|---|
| Female / femme-coded | Elara, Elena, Elana, Lena, Lyra, Aria, Aurora, Nova, Luna, Selene, Althea, Anya, Mira, Clara, Evelyn, Isabella, Seraphina, Isolde, Lily |
| Male / masc-coded | Kael, Kaelan, Kaleb, Vale, Vance, Cassius, Caspian, Adrian, Orion, Atlas, Phoenix, Rylan, Theron, Damon, Silas, Ezra, Malachi, Jax, Dax, Rook |
| Surnames | Voss, Vasquez, Thorne, Vale, Vance, Black, Hart, Cross, Reed, Knox, Stone, Hawk, Rourke |
| Composite sci-fi | Elara Voss (DeepSeek), Elena Vasquez / Elana Vasquez (Claude Opus 4), Dr. Thorne / Dr. Aris Thorne (Gemini 2.5 Pro; 204 instances across 26 books in the 10,000-title Kaggle sci-fi corpus) |

**The phonetic tell** (more reliable than memorizing the list):

- 2 syllables, soft, vowel-heavy
- A / L / R / N consonants, often clustered
- no cultural, class, regional, ethnic, religious, or period anchor
- one-syllable curt variants (`Jax`, `Rook`) for "tough" types
- Latin / Greek roots (`Cassius`, `Orion`, `Aurora`) for "noble" types
- biblical roots (`Silas`, `Malachi`, `Ezra`) for "serious" types
- `Dr. <single-syllable>` for sci-fi authority figures

**Why it happens:** models filter names with demographic baggage to avoid offense or
distraction. Brittany sounds millennial; Karen carries political residue; Mohammed signals
Muslim; Mihai signals Romanian. What's left is the no-baggage set - names so unfamiliar that
they cannot insult anyone, which is exactly why they keep recurring. Per the ChuckMcSneed
HuggingFace experiment, instruct models showed up to 77% skew toward their top 10 names while
base models stayed near 4% - the phenomenon is an artifact of alignment, not raw capability.

**Detect:**

- generated character names that match the fallback set OR the phonetic pattern
- multiple invented characters in the same piece with names from the same phonological family
- proper names that resist being placed in any real demographic, period, region, or culture
- the composite sci-fi patterns (`<female fallback> <sharp surname>`, `Dr. <single-syllable>`)

**Fix:** anchor names to the setting's actual population - culture, class, region, period,
religion, ethnicity. For invented worlds, build a coherent in-world linguistic system
(consistent phonetic rules, prefix/suffix patterns) rather than grabbing soft phonemes. For
sci-fi authority figures, let the role carry the slot (`the medic`, `the supervisor`) rather
than reaching for `Dr. Thorne`.

**Exception:** these names are not banned, only suspect. A setting whose population organically
produces Aurora or Cassius can use them. The failure is the model reaching for these names
because it had no other ideas, not the names themselves. For prior-draft characters whose names
were chosen deliberately, do not rename without explicit permission.

Sources: Namerology (2025 Name of the Year is Elara); ChuckMcSneed, "Name Diversity in LLMs
Experiment" (HuggingFace); Guillaume Laforge, "The Sci-Fi Naming Problem" (glaforge.dev, 2025).
