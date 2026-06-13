# Deep-Grill Domain Lenses

Per-domain question banks. Each lens lists Phase 1 clarify questions (ordered upstream to
downstream - resolve the top groups before the lower ones) and Phase 2 adversarial angles.

These are prompts for *your* questioning, not a script to read aloud. Skip what the plan already
answers, explore the codebase for anything checkable, and always offer a recommended answer.

---

## Code / design

**Phase 1 - clarify (upstream to downstream):**

- **Problem and scope**: what user-visible behavior must exist when done? What is explicitly out of scope?
- **Boundaries and interfaces**: what are the inputs, outputs, and contracts? Who calls this, and what do they expect?
- **Data and state**: what is the source of truth? Where does state live, and who owns mutation? What is the shape of the core data model?
- **Control flow**: synchronous or async? Sequential, concurrent, or event-driven? What ordering guarantees matter?
- **Edge cases**: empty, huge, malformed, duplicate, and concurrent inputs - what is the defined behavior for each?
- **Error handling**: what fails, how does it surface, and who recovers? Retry, fail loud, or degrade?
- **Persistence and migration**: schema changes? Backward compatibility? Data backfill?
- **Testing**: what proves it works? Unit, integration, or end-to-end? What is the one test that would catch the scariest regression?
- **Rollout and rollback**: feature flag, gradual rollout, kill switch? How is it reverted if wrong?

**Phase 2 - attack:**

- Which assumption about the input data, the caller, or the runtime is load-bearing and unverified?
- Where is the race condition you have not named? What happens under retries or duplicate delivery?
- What breaks at 100x the expected volume? What breaks at zero?
- What is the blast radius of a bug here - one request, one user, or the whole system?
- What did you decide not to test, and why is that the thing that will break?

---

## Infra change

**Phase 1 - clarify (upstream to downstream):**

- **Goal and trigger**: what outcome forces this change now? What breaks if it is not done?
- **Consistency contract**: for caching, replication, async, or CDC changes, what staleness or
  correctness guarantee must the data keep - read-your-writes, bounded staleness, or eventual?
  This is load-bearing: it decides whether the chosen pattern (cache-aside, TTL, write-invalidate)
  is even valid, and every downstream knob hangs off it. Resolve it before TTLs or invalidation.
- **Blast radius**: exactly which systems, services, and users are in scope? What is explicitly untouched?
- **Current state and drift**: does live state match the declared config? Is there drift to reconcile first?
- **Idempotency**: can the change be applied twice safely? Is it declarative, or a one-shot imperative step?
- **Secrets and access**: if secrets or access controls move, what is the chain from source of truth through delivery into the runtime? Is the change additive and contract-preserving?
- **Dependencies and ordering**: what must change first? What depends on this completing?
- **Verification gate**: what dry-run, diff, or plan proves the change is bounded before apply? What is the expected diff, and what diff would be a red flag?
- **Rollback**: what is the exact revert path? How long does it take, and what state is lost?

**Phase 2 - attack:**

- What does the plan assume is already true about the environment that nobody verified?
- What is the unexpected destroy or replace hiding in the diff?
- If the apply fails halfway, what state are you left in, and is it recoverable?
- Who is paged when this breaks at 3am, and do they have the runbook?
- What downstream consumer breaks on a change you think is internal?

---

## Fiction draft

**Phase 1 - clarify (upstream to downstream):**

- **Contract**: what genre, length, and audience? What promise does the opening make to the reader?
- **Voice**: whose voice carries this, and what makes it distinct? First or third, tense, distance from the POV character?
- **POV discipline**: single or multiple POV? What are the rules, and where might they slip?
- **Stakes**: what does the protagonist want, what stands in the way, and what is the cost of failure?
- **Structure**: what is the shape - the turn, the escalation, the ending the opening pays off?
- **Character differentiation**: how do the main characters differ in want, voice, and behavior under pressure?
- **Grounding**: where is the sensory and concrete detail anchored, versus abstract summary?

**Phase 2 - attack:**

- Where does the voice flatten into generic competent prose with no fingerprint?
- Which character could be swapped for another with no change to their lines?
- Where is the stakes claim told rather than felt on the page?
- What does the ending promise that the opening never set up, or vice versa?
- Where does the draft explain an emotion the scene should have made the reader feel?

---

## Decision / strategy

**Phase 1 - clarify (upstream to downstream):**

- **Decision**: what is the actual choice, stated as options, not a vague direction?
- **Owner and timing**: who decides, by when, and what forces the timing?
- **Reversibility**: is this a one-way or two-way door? What becomes hard to undo?
- **Success metric**: what observable outcome means this was the right call? When is it measured?
- **Constraints**: budget, time, compliance, team skill, dependency, reputation - which bind hardest?
- **Stakeholders and cost bearers**: who benefits, who pays, who is not in the room?
- **Evidence**: what is known from data versus assumed? What is the strongest piece of disconfirming evidence?

**Phase 2 - attack:**

- What would have to be true for this to be the wrong call, and how likely is that?
- What is the second-order effect nobody is pricing in?
- Who is harmed by this decision, and is that acceptable or just out of sight?
- What is the cheapest experiment that would change your mind before you commit?
- If this is irreversible, what reversible version gets you 80 percent of the value?

---

## Generic

When no specialized lens fits, walk the universal decision tree:

**Phase 1**: goal -> constraints -> options -> the load-bearing choice -> its dependents ->
success criteria -> what is out of scope.

**Phase 2**: the riskiest assumption -> the failure mode -> who pays -> the pre-mortem cause ->
the cheapest way to de-risk before committing.

---

## Adding a domain lens

To extend deep-grill for your own field (legal, data pipeline, game design, hardware, etc.):

1. Add a section here with the same two-part shape: **Phase 1 - clarify** (question groups ordered
   upstream to downstream) and **Phase 2 - attack** (adversarial angles).
2. Order Phase 1 groups so each group's answers constrain the next. The first group should be the
   decision that, if it flips, invalidates everything below it.
3. Phase 2 angles should target what is *specific* to the domain - the failure modes a generic
   review would miss. If an angle applies to every domain, it belongs in Generic, not here.
4. Add a one-row entry to the lens table in `SKILL.md` Step 1 so the new domain is detectable.

Keep each lens to question prompts, not prose. The skill supplies the method; the lens supplies
the domain-specific targets.
