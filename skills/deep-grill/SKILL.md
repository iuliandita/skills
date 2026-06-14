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
- A standalone adversarial decision review or dark-pattern lens, with no plan to resolve - use **jekyll-hyde**
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
- [ ] **Vague answers forced concrete**: "we'll handle it later" is pushed to a real decision or logged as an explicit open question.
- [ ] **Decision record written**: resolved decisions, surviving risks, open questions, and a next step land in the deliverable file.
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
- Ask **one question at a time**.
- For **every** question, provide your own recommended answer and a one-line reason. You are a
  collaborator with opinions, not a form.
- If a question can be answered by **exploring the codebase, files, or docs, go look** instead of
  asking the user. If the plan was handed to you inline with no codebase to explore, say what you
  would normally have checked, then ask - or, in headless mode where no one can answer, record it
  as a flagged assumption instead of asking.
- Pull domain-specific questions from `references/domains.md`.
- Force vague answers into concrete ones. "We'll figure out caching later" becomes a decision now
  or an explicit logged open question - never a silent gap.

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
re-resolve that branch, and return.

Timebox it. Stop when new attacks stop changing the plan. Do not grind out risks that no longer
move the decision.

### Step 4: Write the decision record

Write one file to `docs/local/deliverables/deep-grill/<YYYY-MM-DD>-<slug>.md` using the template in
`references/decision-record.md`. It contains:

- **Context** - what is being built and why.
- **Resolved decisions** - the design and the spec: what to build, with the reasoning for each choice.
- **Surviving risks** - what Phase 2 surfaced and you accepted, each with its mitigation or acceptance rationale.
- **Open questions** - anything deferred, stated explicitly so it cannot hide.
- **Recommended next step** - the concrete first action.

This file is the deliverable. It is both the design (resolved choices) and the spec (what to
build and what to watch).

---

## Interrogation rules

The mechanics are not optional - they are what separates a real grill from a chat:

- **One question at a time.** Batching collapses the decision tree into a survey and loses the dependency order.
- **Recommend an answer to everything.** Your recommendation gives the user something to push against; silence makes them do all the work.
- **Explore, do not ask, when the answer is in the repo.** Asking what you could have checked wastes the user and erodes trust.
- **Upstream before downstream.** Always.
- **Phase discipline.** Clarify fully, then attack. Announce the transition.
- **Opinions, not "it depends."** If it depends, say on what, then give your default.
- **No vague survivors.** Every hand-wave becomes a decision or a logged open question.
- **Timebox the adversary.** Diminishing returns are real; stop when the plan stops moving.

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
- **Mode:** conditional. The primary path is the two-phase grill of a forming plan: respond
  conversationally during the interview (no boxed contract mid-interview), and at the end always
  write the decision record to the deliverable path using `references/decision-record.md`.
  Headless / non-interactive runs follow this same primary path - the one-pass decision record at
  the deliverable path, no boxed contract. When
  invoked instead to **stress-test an existing artifact** as a pure audit (Phase 2 only, surfacing
  a findings list against a spec or design doc that already exists), emit the full boxed contract -
  inline header, per-finding detail in the deliverable, boxed conclusion, conclusion table.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; used only in the audit path).

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
2. Every question carries your recommended answer and a one-line reason.
3. Explore the codebase, files, and docs for anything answerable there; do not ask what you can check.
4. Resolve upstream decisions before the downstream ones that depend on them.
5. Do not start Phase 2 until the tree is resolved, and announce the switch.
6. Phase 2 attacks the plan; it does not restate Phase 1.
7. Force vague answers into a concrete decision or a logged open question before moving on.
8. Always write the decision record. It is the design and the spec.
9. Timebox the adversarial phase; stop when attacks stop changing the plan.
10. Route out if the real task is code review, security, or a repo audit.
