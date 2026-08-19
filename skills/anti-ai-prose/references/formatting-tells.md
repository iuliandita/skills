# Formatting tells: the long tail

Deep-dive reference for category 4 in `SKILL.md`. The four highest-frequency formatting
tells (em dashes, title-case headings, excessive bold, bullet salad) stay in `SKILL.md`
because they fire on almost every draft. The rest live here.

**Fix, for all of them:** match the surrounding project's conventions. With no convention,
default to plain ASCII, sentence case, minimal bold, paragraph prose.

---

## Punctuation and character artifacts

- **Curly quotes** (U+201C/U+201D and U+2018/U+2019) in technical writing that should use
  ASCII `"` and `'`. Named by codepoint here because this collection is ASCII-only
- **Emoji** in professional prose where decoration is the only purpose
- **Markdown artifacts in rendered text** - `**bold**` appearing as literal characters
  because the paste lost its formatting

## Layout habits

- **Three-bullet-happy layouts** - suspicious when every list has exactly three items.
  Overlaps forced tricolons in category 2; count it once, under whichever cluster is denser
- **Decorative thematic breaks** - `---` before every `##`. Dividers that mark a real phase
  change are fine; decoration is not

## LLM output bugs

Residue from the generating tool that no human would type: `turn0search0`,
`contentReference`, `oaicite`, `attached_file`, hallucinated wiki-style shortcuts.
(`+1` is ordinary human writing - do not flag it.)

**Fix:** delete. These are P0 in published text - they prove it was pasted from a chat window
unread, which is a trust breach rather than a voice problem.

---

## Colon as a mid-sentence connector

A colon whose right side is a full clause that would read the same as its own sentence,
adding a beat of false setup: `If you're coming from traditional automation: instead of
registering event handlers, you describe conditions.`

**Fix:** End the sentence, or rewrite so the point stands without the comparison framing.

**Exception:** colons before lists, definitions, quotes, and code blocks are correct, as is
one introducing a real specification (`One rule: never force-push shared branches`).

---

## Inline-header lists that restate themselves

A bold label followed by a colon whose text repeats the label:
`**Performance:** Performance improved by 12%.`

**Fix:** Convert to prose, or drop the label. `Performance improved by 12%.`

**Exception:** a bold lead-in ending in a period that names the item and is followed by new
detail is a definition list, not a tell: `**Schema in TypeScript.** Tables live in one file.`

---

## What NOT to flag from this reference

- **Bold where it signals a term or path** - bolding a defined term on first use is standard
- **Colons before lists, definitions, quotes, or code blocks** - that is what colons are for.
  Only the mid-sentence clause joint is a tell
- **Definition-list bold lead-ins** - `**Term.** New detail follows.` is a real pattern. The
  tell is only the label that restates itself
- **Emoji in projects that use them by convention** - changelogs and READMEs that already
  carry a consistent emoji legend
