# Plain speech: concreteness, actor, sentence load, voice

Deep-dive reference for the plain-speech checks in `SKILL.md`. These four patterns
are structural rather than lexical: no wordlist catches them, and each one needs a
rewrite rather than a substitution.

Folded in from [poteto/plugins](https://github.com/poteto/plugins) `pstack/skills/unslop`
(MIT), which contributed the concreteness test, the actor test, and the voice-restoration
guidance.

---

## 1. Abstract metaphor nouns

Words that read as technical but usually stand in for a plainer, concrete one. LLMs
reach for them when the text needs to sound like systems thinking.

| Metaphor noun | Plain replacement |
|---|---|
| substrate | base, layer, foundation |
| wedge | opening, first step, add |
| vector | way, method, path |
| locus | place, point, center |
| vantage | view, position |
| nexus | link, junction, hub |
| primitive (as noun) | building block, basic type, operation |
| harness (as metaphor) | setup, runner, wrapper |
| surface (as in "API surface") | the API itself, the exposed calls |
| bedrock | base, foundation |
| scaffolding (as metaphor) | setup, structure, boilerplate |
| modality | mode, kind, channel |
| paradigm | model, approach, style |
| gold-plating | more than the job needs |

**Detect:** the noun carries no measurement, no referent, and no consequence. `We
wedged the check into the auth vector` names nothing that exists in the codebase.

**Fix:** name the concrete thing. `We added the check to the login handler.`

**Exception:** these are terms of art in their home domains. `Substrate` in materials
science and biology, `vector` in linear algebra, epidemiology, and graphics, `primitive`
in graphics and cryptography, `harness` in test tooling, `locus` in genetics. Domain
context overrides the flag, same as the vocabulary table in `SKILL.md`.

---

## 2. Say the concrete thing

The tell is prose that names a feeling instead of a mechanism, or wraps a simple point
in abstract framing. It reads well and tells the reader nothing they can act on.

**Detect:** ask what the sentence tells the reader to do or know. If it cannot be
restated as a concrete instruction, a fact, or a number, it is padding.

| Names a feeling | Names the mechanism |
|---|---|
| the database stays close at hand | `db.query()` runs in-process, no network hop |
| SQL you can read | `.toSQL()` returns the exact string sent to the database |
| types that follow your schema | a column rename fails the build |
| a smooth developer experience | one command, no config file |
| the system scales gracefully | tested to 12k concurrent connections |

**Fix:** replace with the mechanism, a number, or an instruction. If none exists, cut
the sentence. A sentence that survives only as atmosphere is not carrying weight.

**Exception:** genuine motivation paragraphs in a README or a design doc can state a
goal before the mechanism. `We wanted queries to fail at compile time` is a stated
intent, not a feeling substituted for a fact. Flag when the abstract sentence is the
only thing on offer.

---

## 3. Passive voice with an unnamed actor

LLMs default to `is/are/was/were + past participle`, which drops the actor. The reader
then cannot tell what component is responsible.

**Detect:** scan for the auxiliary plus participle, then ask who does it. If the answer
is in the text but not in the sentence, the sentence is weaker than it needs to be.

| Passive | Actor named |
|---|---|
| queries are validated | the compiler validates queries |
| the file is parsed by the loader | the loader parses the file |
| errors are logged | the middleware logs errors |
| the token is refreshed automatically | the SDK refreshes the token before each call |

**Fix:** promote the actor to subject.

**Exception:** passive is correct when the actor is unknown, irrelevant, or deliberately
withheld. `The record was deleted in 2019` is fine when nobody knows by whom. Incident
writeups often use passive on purpose to keep blame off individuals. Scientific method
sections use it by convention. Do not flag those.

---

## 4. Dense sentence stacking

One idea per sentence. If the reader has to backtrack to parse a sentence, it is doing
too much.

**Detect:**
- Three or more clauses chained with commas, `and`, `which`, and `while`
- A sentence that needs a second read to find its subject
- Nested qualifiers that push the verb far from its subject

**Fix:** split at the clause boundary, or drop the clause that carries the least. Two
plain sentences beat one balanced one.

> before: The loader, which reads from the cache when a valid entry exists and otherwise
> falls back to the network, parses the manifest before handing it to the resolver, which
> then walks the dependency graph.

> after: The loader reads from the cache, falling back to the network on a miss. It parses
> the manifest and hands it to the resolver. The resolver walks the dependency graph.

---

## 5. Restoring voice

Removing tells is half the work. Prose stripped of every pattern and given nothing back
reads as sterile, which is its own tell. When the audit recommends a rewrite, the
replacement should carry these:

- **Have a position.** React to the facts rather than listing balanced pros and cons.
  A recommendation with a reason beats a neutral survey.
- **Vary rhythm.** Short sentences. Then a longer one that takes its time and earns the
  extra clauses. Uniform sentence length is a machine signature.
- **Acknowledge complexity.** "Fast, but it drops the connection under load" beats "fast".
- **Use first person when it fits.** `I would not ship this` is not unprofessional.
- **Allow some asymmetry.** Perfectly parallel structure across every section reads as
  generated. A section that is longer because it needed to be is fine.
- **Be specific.** Not "there are concerns about the schedule" but "the migration lands
  the same week as the audit".

**Applying this in an audit:** voice notes are `Consider`-level, never `Fix`. Voice is
the author's call. Flag mechanical tells as findings; offer voice suggestions as options
and say so explicitly. Do not rewrite a piece into your own voice under the banner of
removing AI tells.

---

## What NOT to flag from this reference

- **Domain terms of art** for the metaphor nouns above, per each entry's exception
- **Deliberate passive** where the actor is unknown, irrelevant, or withheld on purpose
- **Long sentences that parse on first read.** Length is not the tell; backtracking is
- **Stated intent** in a motivation paragraph, when the mechanism follows it
- **A single abstract sentence** in an otherwise concrete piece. All four patterns here
  are density findings, subject to the same thresholds as the vocabulary tells
