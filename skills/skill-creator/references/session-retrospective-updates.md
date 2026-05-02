# Session Retrospective Skill Updates

Use this reference when the user asks to review the conversation and update the skill library.

## Decision flow

1. Identify the class of work that just happened in one sentence.
2. Prefer a skill already loaded or consulted in the session.
3. If no loaded skill fits, use the existing class-level umbrella skill that governs the work.
4. Patch SKILL.md for reusable workflow, routing, preference, or pitfall changes.
5. Add `references/` detail only when the lesson is too session-specific or bulky for SKILL.md.
6. Create a new skill only when no class-level umbrella exists.

## What counts as worth updating

- User corrected style, format, verbosity, sequencing, or tooling.
- A loaded skill was missing a step, had stale paths, or gave incomplete guidance.
- A non-obvious repo workflow emerged, especially around canonical vs published copies.
- Validation exposed a reusable pitfall, such as ignored instruction files or unrelated dirty work.

## Repo skill-library gotchas

- In the public skills repo, `AGENTS.md` may be local-only and gitignored. Read it and follow it, but do not force-add it unless the user explicitly asks.
- When changing public skill files, stage only the intended paths. Leave unrelated dirty skill edits untouched.
- If a skill exists both in canonical local skills and the repo, verify they match before declaring deployment done.
- After public skill edits, run the repo validation scripts and redeploy linked tool skill dirs when the repo workflow calls for it.

## Final report

Keep it short:

- what skill or reference changed
- why it was updated
- validation run
- any overlaps noticed
