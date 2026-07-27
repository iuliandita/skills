---
name: deep-grill
description: >
  · Grill a plan before building: clarify the decision tree, then attack it. Triggers: 'grill me', 'deep grill', 'stress-test this plan', 'poke holes', 'what did I miss'. Not for existing code (code-review) or decision red-team (jekyll-hyde).
license: MIT
compatibility: "None - works on any plan or design. Optional: a codebase to explore for code/infra domains."
metadata:
  source: iuliandita/skills
  date_added: "2026-06-13"
  effort: high
  argument_hint: "<plan-or-design>"
---

# Deep Grill: Two-Phase Plan Interrogator

Deep-grill ends with a written decision record, so a resolved requirement stays settled instead of getting relitigated in a later session.

Most build failures are not the model failing to write code - they are requirements that were
never specified. Deep-grill kills that failure before anything exists, in two phases:

1. **Clarify** - walk the decision tree, resolve every upstream choice before its downstream
   ones, until no unspecified requirement would change what gets built.
2. **Adversary** - once the plan is resolved, attack it: assumptions, failure modes, weak
   premises, unstated risks. Break it on paper before reality breaks it for real.

It is domain-adaptive: it detects whether you are grilling a feature plan, an infrastructure
change, a fiction draft, or a strategic decision, and grills on what actually matters for that
domain. It ends by writing a single decision record - the design, the spec, and the surviving
risks in one file.

## When to use

- Before building a feature or system from a rough plan or design
- Before a risky infrastructure change (migration, cutover, schema change, rollout)
- Before committing to an architecture or design decision that is expensive to undo
- Pressure-testing a fiction outline, plot, or draft direction before drafting pages
- When the user says "grill me", "deep grill", "stress-test this plan", "poke holes",
  "pressure-test this", "interrogate my design", or "what did I miss"

## When NOT to use

- Reviewing existing code for bugs, edge cases, or regressions - use **code-review**
- AI-generated code quality, over-abstraction, or test theater - use **anti-slop**
- Security vulnerabilities, auth flaws, secrets, or OWASP issues - use **security-audit**
- A full repository audit or merge gate over code that exists - use **deep-audit** or **full-review**
- A standalone adversarial decision review with no build plan or existing plan/spec artifact to
  stress-test - use **jekyll-hyde**. Pure Phase-2 audit of an existing plan/spec remains a deep-grill mode
- Capturing or prioritizing ideas in a backlog - use **roadmap**
- Turning notes into a reusable LLM prompt - use **prompt-generator**
- Writing the plan or implementation plan *for* the user. Deep-grill interrogates a plan; it
  does not author one. If the harness has a brainstorming or planning skill, brainstorm to
  produce the plan, then deep-grill to interrogate it.

---

## AI Self-Check

This skill runs a multi-turn interview and writes a structured decision-record file. Before and
during a grill, verify. Two items are tagged **(interactive only)**: in headless / non-interactive
mode (see Step 1) they do not apply, because there is no conversation - emit the tree in one pass
and fold both phases into the record. Everything else still holds.

- [ ] **One question at a time** *(interactive only)*: never batch questions into a single message.
- [ ] **Recommended answer every time**: each question carries your own recommended answer and a one-line why.
- [ ] **Explored before asking**: anything answerable from the codebase, files, or docs was looked up, not asked.
- [ ] **Tree walked top-down**: upstream decisions resolved before the downstream ones that depend on them.
- [ ] **Phase switch announced** *(interactive only)*: Phase 2 starts only after the tree is resolved, and the switch is stated out loud.
- [ ] **Phase 2 attacks, not restates**: adversarial questions hit assumptions, failure modes, and premises - they do not re-ask Phase 1.
- [ ] **Fuzzy terms pinned**: overloaded words were challenged and disambiguated before the plan built on them.
- [ ] **Vague answers forced concrete**: every hand-wave resolved to a decision, a sharp open question, a flagged fog patch, or a do-first prerequisite - never a silent gap.
- [ ] **Decision record written**: resolved decisions, surviving risks, open questions, fog, prerequisites, and a next step land in the deliverable file.
- [ ] **Domain detected and routed**: correct lens applied; if the real task is code review, security, or a repo audit, routed to the right skill instead.
- [ ] **Hidden state identified**: existing code, config, prior decisions, and constraints are surfaced before grilling, not assumed.
- [ ] **Routing overlap checked**: overlap with jekyll-hyde and code-review handled per "When NOT to use" before proceeding.

---

## Workflow

### Step 1: Detect the target and domain

Identify what is being grilled and pick the lens. Ask at most one classifying question if it is
genuinely ambiguous; otherwise state your read and proceed.

| Domain | Lens grills on |
|---|---|
| **Code / design** | data flow, interfaces, state, concurrency, edge cases, error handling, rollback, test strategy |
| **Infra change** | blast radius, idempotency, rollback path, secret handling as a chain, drift, verification gate before apply |
| **Fiction draft** | voice contract, POV consistency, stakes, character differentiation, genre conventions, sensory grounding |
| **Decision / strategy** | options and reversibility, second-order effects, who decides, success metric, what would change your mind |
| **Generic** | fallback decision-tree walk when none of the above fit |

**Lenses are not exclusive.** Many plans straddle two - caching, queues, rate limiters, and
migrations are both code and infra. When two fire, pick the lens of the dominant *risk* (usually
infra when there is a blast radius, a rollback path, or a live-data consistency concern) and pull
the relevant question groups from the second lens too.

Read `references/domains.md` for the full per-domain question banks once the domain is known.

If the request is actually about code that already exists ("is this function correct", "is this
exploitable", "audit this repo"), route out per "When NOT to use" instead of grilling.

**Headless / non-interactive mode**: if no interactive user is available (a `--bare` or `exec`
run, or any invoking context that tells you no user is there to answer), do not block on
one-at-a-time prompting. Emit the full decision tree with your
recommended answer for every node in one pass, flag the assumptions you made, run the adversarial
pass against those assumptions, and still write the decision record.

### Step 2: Phase 1 - Clarify (resolve the decision tree)

Run the core grill mechanics. They are the load-bearing part, and apply in every domain:

- Build the decision tree for the plan. **Resolve upstream choices before downstream ones** -
  a downstream answer is worthless if its parent decision flips.
- Ask **one question at a time**. Batching collapses the decision tree into a survey and loses the dependency order.
- For **every** question, provide your own recommended answer and a one-line reason. You are a
  collaborator with opinions, not a form.
- If a question can be answered by **exploring the codebase, files, or docs, go look** instead of
  asking the user. If the plan was handed to you inline with no codebase to explore, say what you
  would normally have checked, then ask - or, in headless mode where no one can answer, record it
  as a flagged assumption instead of asking.
- Pull domain-specific questions from `references/domains.md`.
- **Challenge fuzzy terms on the spot.** When an overloaded word carries weight, pin it before
  building on it: "You said 'account' - the Customer or the User? Those are different things." A
  plan resolved on an ambiguous term resolves the wrong tree.
- **When a branch is a feel question, prototype - do not grind.** "How should this state model
  behave?" or "what should it look like?" does not resolve by more questions. Recommend a cheap,
  throwaway prototype to react to; concrete fidelity settles taste faster than abstract debate. If
  it cannot be settled in the conversation, the prototype becomes the **prerequisite** that unblocks
  the decision - log it as one, and log the feel decision it gates as an **open question** so the
  decision itself is tracked, not just the prototype. Do not build the prototype here.
- Force every vague answer to one of four outcomes - never a silent gap:
  - **Decision** - settle it now.
  - **Open question** - a sharp question with no answer yet; log it with an owner or a trigger.
  - **Not yet specified (fog)** - you cannot even phrase the question sharply yet, because it hangs
    on an open decision or an undone prerequisite above. Phraseability is the only test: if you can
    *state* the question precisely now - even while it stays blocked - it is an **Open question**,
    not fog. Record the area to revisit; do not fake-resolve it.
  - **Prerequisite** - nothing to decide: a do-first action must happen before the decision can be
    made (provision access, move data so its shape is visible, sign up so an API can be judged).

End Phase 1 when no unresolved upstream decision remains and no unspecified requirement would
change what gets built.

### Step 3: Phase 2 - Adversary (stress-test the resolved plan)

Announce the switch plainly, e.g. "Plan's resolved. Switching to adversarial mode now." The user
should feel the gloves change. (In headless one-pass mode there is no conversation to announce
in - just fold the adversarial pass into the record as its own section.)

Attack the *finished* plan:

- Name the load-bearing assumptions. Which one, if wrong, collapses the plan?
- Hunt failure modes: where does this break under load, at the edges, under concurrency, on the unhappy path?
- Find the weakest premise and pull on it.
- Surface unstated risks - operational, security-shaped, reputational, maintenance debt.
- Run a pre-mortem: "It is three months later and this failed. What was the cause?"
- Ask what you are *not* building that bites later, and what second-order effects the plan triggers.

For each surfaced risk, resolve it one of three ways: **accept** it (and record why), **mitigate**
it (and record how), or recognize it **reopens a Phase 1 decision** - in which case go back,
re-resolve that branch, and return. If what Phase 2 surfaces is not a risk to carry but an unknown -
something to decide, investigate, or do first - route it through the four-outcome model (open
question / fog / prerequisite) instead of forcing it into accept or mitigate.

Timebox it. Stop when new attacks stop changing the plan. Do not grind out risks that no longer
move the decision.

### Step 4: Write the decision record

Write one file to `docs/local/deliverables/deep-grill/<YYYY-MM-DD>-<slug>.md` using the template in
`references/decision-record.md`. It contains:

- **Context** - what is being built and why.
- **Resolved decisions** - the design and the spec: what to build, with the reasoning for each choice.
- **Surviving risks** - what Phase 2 surfaced and you accepted, each with its mitigation or acceptance rationale.
- **Open questions** - sharp questions deferred, each stated explicitly with an owner or a trigger.
- **Not yet specified** - fog: areas you can tell are coming but cannot phrase sharply yet, recorded
  so they cannot hide as false resolution.
- **Prerequisites** - do-first actions that unblock a decision (access, data, signup), each naming
  the decision it blocks.
- **Recommended next step** - the concrete first action.

**Sort every deferred item into its bucket - do not collapse everything into Open questions.** The
three deferral sections (Open questions, Not yet specified, Prerequisites) use the four-outcome model
from Step 2; emit each whenever it has any entry. Headless one-pass grills are the most likely to
collapse them - do not. A decision of the form "inspect X before deciding Y" is not one resolved
decision: it is a **prerequisite** (inspect X) plus **fog** (the shape of Y, unphraseable until X is
known).

This file is the deliverable. It is both the design (resolved choices) and the spec (what to
build and what to watch).

---

## Reference Files

- `references/domains.md` - per-domain question banks (code, infra, fiction, decision, generic) and a short guide to adding your own lens.
- `references/decision-record.md` - the decision-record artifact template.

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** DEEP-GRILL
- **Deliverable bucket:** `deliverables`
- **Deliverable path:** `docs/local/deliverables/deep-grill/<YYYY-MM-DD>-<slug>.md`. The `<slug>`
  is short kebab-case derived from the plan's subject (e.g. `redis-read-through-cache`), so two
  different plans on the same day get two different slugs - the shared contract's `-N` suffix is
  only for re-grilling the same subject twice.
- **Mode:** conditional. Primary path (interactive and headless alike): no boxed contract - respond
  conversationally (headless: one pass), always ending with the decision record written to the
  deliverable path using `references/decision-record.md`. Only when invoked to **stress-test an
  existing artifact** as a pure Phase-2 audit (a findings list against a spec or design doc that
  already exists) do you emit the full boxed contract - inline header, per-finding detail in the
  deliverable, boxed conclusion, conclusion table.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract). The decision record uses the `P0-P3` subset for risk priority; the full scale with `info` is used only in the audit path.

## Related Skills

- **jekyll-hyde** - red-teams a decision and surfaces dark patterns standalone. Deep-grill resolves
  a plan into a buildable spec first, *then* red-teams it, and writes the record. Use jekyll-hyde
  for a one-shot decision review; use deep-grill to take a vague plan all the way to buildable.
- **code-review** - finds bugs in code that exists. Deep-grill interrogates a plan that does not exist yet.
- **deep-audit** - wave-based audit of an existing repo. Deep-grill operates before code, on the plan.
- **security-audit** - reviews exploitable vulnerabilities in code. Deep-grill may flag security-shaped
  risk during Phase 2 but does not replace a security audit.
- **roadmap** - captures and prioritizes ideas. Deep-grill interrogates one idea before you build it.
- **prompt-generator** - formats notes into a reusable prompt. Deep-grill produces a decision record, not a prompt.

## Rules

1. One question at a time. Never batch. Exception: headless / non-interactive mode emits the whole tree in one pass (Step 1).
2. Every question carries your recommended answer and a one-line reason - an opinion, not "it depends" without a default.
3. Explore the codebase, files, and docs for anything answerable there; do not ask what you can check.
4. Resolve upstream decisions before the downstream ones that depend on them.
5. Challenge overloaded terms before building on them; a wrong term resolves the wrong tree.
6. Do not start Phase 2 until the tree is resolved, and announce the switch (the announcement is interactive-only; headless folds Phase 2 into the record).
7. Phase 2 attacks the plan; it does not restate Phase 1.
8. Force vague answers to one of four outcomes - decision, open question, fog (not yet specifiable), or prerequisite (do-first action) - before moving on.
9. Always write the decision record. It is the design and the spec.
10. Timebox the adversarial phase; stop when attacks stop changing the plan.
11. Route out if the real task is code review, security, or a repo audit.
