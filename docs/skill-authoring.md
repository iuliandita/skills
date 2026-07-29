# Skill authoring: the first body paragraph is storefront copy

This collection is published at `https://skills.sh/iuliandita/skills`. On a
skill's page there, the rendered summary comes from the **first paragraph of
the SKILL.md body** - not from the YAML `description` frontmatter. That
paragraph is the only copy a stranger reads before deciding whether to
install.

## Constraints

The first paragraph after the `# Title: Subtitle` H1 must:

- be a single paragraph, 110-350 characters
- not start with a bold block (`**...**`) - version tables, warnings, and
  other bold-led content go below it, never above it
- not contain a version number (`\d+\.\d+\.\d+`)
- not end in a colon (a truncated preview of an unfinished sentence reads as
  broken copy, even when the colon correctly introduces a bullet list below)

`scripts/check-first-paragraph.sh` enforces these mechanically and runs in CI.

## Exemplar

`skills/code-review/SKILL.md`:

```markdown
# Code Review: Deep Correctness Audit

Find bugs that actually break things. Not style, not slop - correctness, reliability, and logic errors that will bite in production.
```

One sentence. Says what it does, who it is for, what it is not. 132
characters.

## Fixing a paragraph that fails the check

`scripts/check-first-paragraph.sh` is a proxy for the goal, not the goal
itself. Passing its character window by prepending a sentence that restates
the paragraph right below it makes the page worse, not better - a reader
hits the same claim twice. Apply these moves in order, and stop at the first
one that works:

1. **Split at a sentence boundary.** If the paragraph is too long but its
   existing first sentence already summarizes the skill, break the paragraph
   after that sentence: paragraph one is the existing sentence, the rest
   becomes paragraph two. Zero new words. If paragraph one then lands under
   110 characters, pull the next existing sentence up instead of writing new
   copy. This is the correct fix for most TOO-LONG cases -
   `debian-ubuntu`, `handoff`, `nixos-btw`, `rhel-fedora`, `routine-writer`,
   and `observability` are all plain sentence-boundary splits.
2. **Reorder.** If a bold block (version pins, warnings) sits above the
   prose, move the prose above it without editing either block's content.
   `localize` is this case. A variant applies when no split lands inside the
   110-350 window: `kali-linux` moved an existing later sentence to open the
   paragraph instead, again with no words added or removed.
3. **Write new copy - last resort.** Only when the paragraph is genuinely
   too short or ends in a colon with nothing reusable above it. The new
   sentence must state something the paragraph below it does not, must name
   its subject rather than opening with an unbound pronoun like "it", and
   must avoid the `X rather than Y` / `instead of` contrast construction -
   a documented AI tell that `skills/anti-ai-prose/SKILL.md` audits for.
   Allow at most one contrast construction across the whole collection's
   leads; prefer none.

Rewriting existing prose outright is not one of these moves. If none of the
three apply, treat that as a judgment call worth flagging to a reviewer, not
something to default into.

## Not the same thing as the frontmatter `description`

The YAML `description` field serves a different job: agent trigger matching,
governed by the middle-dot prefix rule in `scripts/lint-skills.sh`. It is
read by agents deciding whether to invoke a skill, not by humans browsing
skills.sh.
Fixing the first body paragraph never means editing `description`, and vice
versa.
