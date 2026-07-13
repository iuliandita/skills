# Decision Record Template

The deliverable deep-grill writes at the end of a grill. One file per session at
`docs/local/deliverables/deep-grill/<YYYY-MM-DD>-<slug>.md`. Pure markdown - renders in GitHub,
GitLab, VS Code, and Obsidian.

It is both the design (the resolved choices) and the spec (what to build and what to watch). Keep
it tight: a record someone can act on, not a transcript of the interview.

---

## Template

```markdown
# Deep-Grill: <topic> - <YYYY-MM-DD>

- **Domain:** <code | infra | fiction | decision | generic>
- **Plan grilled:** <one line on what was interrogated>
- **Decisions:** <N resolved>  ·  **Surviving risks:** <N>  ·  **Open questions:** <N>  ·  **Fog:** <N>  ·  **Prerequisites:** <N>

> _Headless one-pass grill (omit this line when interactive):_ no user answered in real time.
> The tree below was emitted in one pass with a recommended answer per node; items that could
> not be verified from the codebase or files are flagged inline as **assumptions**, not facts.

---

## Context

<2-4 sentences: what is being built or decided, and why now. The problem, not the solution.>

## Resolved decisions

The design and the spec. Each decision is a choice that is now settled, with its reasoning.

- [ ] **D1 <decision title>**
  - **Chosen:** <what was decided>
  - **Why:** <the reasoning that settled it>
  - **Alternatives rejected:** <what was considered and dropped, briefly>

- [ ] **D2 <decision title>**
  - **Chosen:** <...>
  - **Why:** <...>
  - **Alternatives rejected:** <...>

## Surviving risks

What Phase 2 surfaced and the plan now carries. Each risk is accepted or mitigated, not ignored.

- [ ] **R1 <risk title>** (P0 | P1 | P2 | P3)
  - **Risk:** <the failure mode and its trigger>
  - **Who pays:** <who bears the cost if it fires>
  - **Disposition:** accepted | mitigated
  - **Mitigation / rationale:** <how it is mitigated, or why it is acceptable to carry>

- [ ] **R2 <risk title>** (P1)
  - **Risk:** <...>
  - **Who pays:** <...>
  - **Disposition:** <...>
  - **Mitigation / rationale:** <...>

## Open questions

Sharp questions with no answer yet - you can *state* each precisely, you just have not settled it.
Each needs an owner or a trigger for when it must be answered.

- [ ] **Q1 <question>** - owner <who answers> / trigger <when or what forces the answer>
- [ ] **Q2 <question>** - <...>

## Not yet specified

Fog: areas you can tell are coming but cannot phrase as a sharp question yet, because they hang on
an open decision or an undone prerequisite above. Recorded so they cannot hide as false resolution;
each sharpens into an open question or a decision once what it waits on lands. (Test: you cannot
state the question precisely now - if you can, even while blocked, it belongs in Open questions.)

- [ ] **F1 <area to revisit>** - sharpens once <the decision resolves or the prerequisite lands>
- [ ] **F2 <...>**

## Prerequisites

Do-first actions that must happen before a decision can be made - nothing to decide, but the
decision is blocked until the work lands (provision access, move data so its shape is visible, sign
up so an API can be judged, build a throwaway prototype to settle a feel question).

- [ ] **PR1 <action>** - unblocks <which decision>
- [ ] **PR2 <...>**

## Recommended next step

<The single concrete first action. What to do Monday morning.>
```

---

## Notes

- **Decisions and risks use checkboxes** so the implementer can flip `- [ ]` to `- [x]` as each is
  built or each mitigation lands - the same convention as audit deliverables in
  `references/output-contract.md`.
- **Numbering is monotonic** within each section (D1, D2...; R1, R2...; Q1, Q2...; F1, F2...; PR1, PR2...).
- **Risk priorities** use the shared `P0 | P1 | P2 | P3` scale.
- **Keep alternatives brief.** One line on what was rejected is enough; the record captures the
  decision, not the full debate.
- **Open questions are not failures.** A grill that ends with three honest open questions and an
  owner for each beats one that pretends everything is resolved.
- **Fog is not an open question.** An open question is sharp and unanswered; a fog patch cannot even
  be phrased sharply yet. If you can write the question, move it up to Open questions. A do-first
  action that unblocks any of these is a **prerequisite** - log the action there, and log what it
  unblocks (a decision, an open question, or fog) separately.
- **If a Phase 2 risk reopened a decision**, the record shows the *final* resolved decision, not
  the intermediate one that was overturned.
- **Headless one-pass grills** keep the blockquote note under the header and tag each unverified
  node as an assumption. Interactive grills delete the note - every node was answered live.
