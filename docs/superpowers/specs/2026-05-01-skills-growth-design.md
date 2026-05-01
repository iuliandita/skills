# Skills Growth Design

Date: 2026-05-01
Repository: `/home/id/priv/code/gh.id/skills`

## Purpose

Use the observed skills.sh download signal to grow the collection in areas with clear demand:
skill discovery, frontend design, browser automation, prompt generation, and Kubernetes cluster
health diagnostics.

This is one umbrella design for five related workstreams. Implementation should be staged so
lower-risk public skill updates can move independently from the more sensitive `cluster-health`
public/private migration.

## Scope

In scope:

- Add a new public `skill-router` skill.
- Expand the existing public `frontend-design`, `browse`, and `prompt-generator` skills.
- Convert `cluster-health` from private-only to a public generic skill with protected local overlays.
- Update repo tooling and docs where needed so protected overlays stay out of public commits.
- Validate with `scripts/lint-skills.sh`, `scripts/validate-spec.sh`, targeted privacy checks, and
  focused diff review.

Out of scope:

- Implementing the skill edits as part of this design step.
- Rewriting the whole collection.
- Publishing current private cluster names, kube contexts, domains, namespaces, service names,
  commands, node names, employer-specific architecture, or private thresholds.
- Importing third-party skills from skills.sh directly.
- Changing the installer model beyond what `cluster-health` needs.

## Current Repository Facts

- Public skills live under `skills/`.
- Canonical local skills live under `/home/id/.agents/skills/`.
- `skill-router` does not currently exist.
- `frontend-design`, `browse`, and `prompt-generator` already exist and should be expanded in place.
- `cluster-health` currently exists locally under `skills/cluster-health/`, is gitignored, and has
  `metadata.internal: true`.
- `.gitignore` currently ignores the entire `skills/cluster-health/` directory.
- `scripts/lint-skills.sh` currently treats `cluster-health` as a private skill that public skills
  must not reference.
- Public `SKILL.md` files should stay below the 600-line hard max, with a target below 500 lines.

## Approach

Use a staged public-growth plan:

1. Create `skill-router` first, because it improves discovery across the full collection.
2. Expand `frontend-design`, `browse`, and `prompt-generator` with demand-backed guidance while
   preserving their current boundaries.
3. Migrate `cluster-health` last, because it requires privacy review, `.gitignore` changes, and
   linter policy updates.

The design is one spec for coherence. The implementation plan should split the work into focused
commits or PR sections.

## Workstream 1: `skill-router`

Create a new public skill for choosing the right skill from an installed collection.

### Goal

Help agents route a user request to the smallest useful skill set, explain the choice, and avoid
loading adjacent skills unnecessarily.

### Expected behavior

- Read the user request and available skill metadata.
- Select one primary skill when possible.
- Return a short ranked set when the request genuinely spans multiple skills.
- Name near misses when useful, with a concise reason they were not selected.
- Hand off creation, review, and batch improvement work to `skill-creator` or `skill-refiner`.

### Boundaries

`skill-router` should not:

- Rewrite skills.
- Audit the whole collection.
- Perform competitive research.
- Replace `skill-creator`, `skill-refiner`, `roadmap`, or domain-specific skills.

### Likely structure

- Frontmatter: public, medium effort, source `iuliandita/skills`.
- `When to use`: skill selection, routing conflicts, "which skill should I use", trigger tuning.
- `When NOT to use`: creating skills, reviewing skills, full collection audits, implementation work.
- Workflow:
  1. Parse user intent.
  2. Identify hard triggers and exclusions.
  3. Check adjacent skills for overlap.
  4. Pick one primary skill or a minimal ordered set.
  5. Explain the routing decision and next action.
- References:
  - Optional `references/routing-patterns.md` if examples would make `SKILL.md` too long.

## Workstream 2: `frontend-design`

Expand the existing opinionated UI skill without diluting its identity.

### Goal

Make `frontend-design` better aligned with visible skills.sh demand for frontend, React, web design,
shadcn, and UI/UX guidance.

### Additions

- React, Tailwind, and shadcn guidance as reference material, not a rewrite of the main skill.
- App shell and dashboard patterns for operational tools.
- Form, settings, onboarding, and empty-state guidance.
- Responsive QA workflow with desktop/mobile checks.
- Visual regression and screenshot review guidance.
- Stronger rules against common AI UI tells.

### Boundaries

Keep routing clear:

- Code correctness stays with `code-review`.
- Test authoring and E2E test debugging stay with `testing`.
- Localization stays with `localize`.
- Backend/API design stays with `backend-api`.

### Likely file changes

- Update `skills/frontend-design/SKILL.md` with compact routing and workflow refinements.
- Add or expand references, likely:
  - `references/frameworks.md`
  - `references/ai-tells.md`
  - new `references/app-ui-patterns.md`
  - new or expanded responsive/QA reference material

## Workstream 3: `browse`

Expand the browser automation skill around practical web tasks.

### Goal

Make `browse` useful for modern read, scrape, screenshot, authenticated, and interactive browsing
tasks while keeping token cost and source quality under control.

### Additions

- Task-mode routing:
  - static fetch
  - JavaScript-rendered read-only pages
  - interactive browsing
  - authenticated browsing
  - screenshots
  - structured extraction
- Clearer source attribution rules for facts likely to change.
- Rate-limit and politeness guidance.
- Session isolation and cookie/storage cleanup rules.
- Selector strategy for interaction: semantic roles first, brittle CSS last.
- Screenshot/DOM decision rules so agents do not overuse expensive browser output.

### Boundaries

Keep routing clear:

- E2E test automation stays with `testing`.
- MCP browser server development stays with `mcp`.
- Network/DNS/proxy debugging stays with `networking`.
- RAG ingestion pipelines stay with `ai-ml`.

### Likely file changes

- Update `skills/browse/SKILL.md`.
- Add or expand references:
  - `references/tool-setup.md`
  - new `references/extraction-patterns.md`
  - new `references/authenticated-browsing.md`

## Workstream 4: `prompt-generator`

Expand the prompt structuring skill into clearer prompt families.

### Goal

Strengthen an already popular skill by making it better at turning rough input into reusable,
model-agnostic prompts without becoming a brainstorming or skill-authoring workflow.

### Additions

- Prompt family patterns:
  - system prompts
  - one-off task prompts
  - reusable templates
  - evaluator prompts
  - code-review prompts
  - agent delegation prompts
- Injection-boundary guidance for untrusted source text.
- Variable naming and schema consistency rules.
- Model-specific adaptation rules only when the user names a provider.
- Examples that stay compact and avoid creating a giant prompt library.

### Boundaries

Keep routing clear:

- Creative ideation stays with brainstorming workflows.
- Skill creation stays with `skill-creator`.
- Routine prompts stay with `routine-writer`.
- LLM application code stays with `ai-ml`.
- Prompt injection security review stays with `security-audit`.

### Likely file changes

- Update `skills/prompt-generator/SKILL.md`.
- Consider adding:
  - `references/prompt-families.md`
  - `references/evaluator-prompts.md`

## Workstream 5: Public-Safe `cluster-health`

Convert the private `cluster-health` skill into a public generic Kubernetes health check skill while
moving private infrastructure details into protected local files.

### Goal

Publish a useful generic cluster diagnostics skill without exposing private infrastructure. Local
installs should still support the existing personalized registry and checks.

### Public skill model

Public tracked files should include:

- `skills/cluster-health/SKILL.md`
- generic references such as:
  - `references/kubernetes-core.md`
  - `references/helm-gitops.md`
  - `references/networking-ingress.md`
  - `references/storage.md`
  - `references/monitoring-logs.md`
  - `references/security.md`

The public skill should work with no overlay by asking for an explicit kube context or using the
current context only after confirmation. It should define read-only generic checks for nodes,
workloads, events, logs, Helm releases, GitOps state, certificates, ingress, storage, monitoring,
and security signals.

### Protected local overlay model

Protected local files should live under:

- `skills/cluster-health/protected/registry.md`
- optional `skills/cluster-health/protected/<cluster>.md`

Protected files may contain:

- cluster aliases
- kube contexts
- CWD detection patterns
- domains
- namespaces
- app names
- node names
- SSH hosts
- private thresholds
- custom commands
- organization-specific architecture

The public skill should say:

1. If `protected/registry.md` exists, load it.
2. If the registry maps the request or CWD to a cluster, use that protected profile.
3. If no protected overlay exists, ask for the kube context or run the generic read-only sweep
   against an explicitly confirmed context.
4. Never guess a cluster target.

### Git and tooling changes

Required changes:

- Replace `.gitignore` entry `skills/cluster-health/` with `skills/cluster-health/protected/`.
- Remove or revise the hardcoded private-skill rule for `cluster-health` in `scripts/lint-skills.sh`.
- Add a privacy-check script that prevents tracked files from referencing protected cluster details.
- Update docs that describe excluded skills, since `cluster-health` would no longer be excluded as
  a whole skill.
- Remove `metadata.internal: true` from public `cluster-health` frontmatter.
- Change `metadata.source` from `custom` to `iuliandita/skills` when public.

### Privacy migration

Before publishing:

- Move every current private alias, kube context, domain, namespace, service name, node name, SSH
  host, CWD pattern, and organization-specific command into `protected/`.
- Replace current cluster-specific references with generic examples.
- Review tracked files with a private-term grep before committing.
- Confirm `git status --short` does not show protected files.

## Verification

Implementation should run:

```bash
rtk scripts/lint-skills.sh
rtk scripts/validate-spec.sh
rtk git diff --check
rtk git check-ignore -v skills/cluster-health/protected/registry.md
```

Implementation should also run a targeted privacy check against tracked files. The exact patterns
should come from the current private `cluster-health` files before migration. At minimum, check for
known private aliases, kube contexts, domains, namespaces, app/service names, node names, SSH hosts,
and organization names.

Before PR, review:

```bash
rtk git diff -- skills/cluster-health .gitignore scripts README.md
rtk git status --short --ignored=matching skills/cluster-health
```

Acceptance criteria:

- `skill-router` exists and validates as a public skill.
- `frontend-design`, `browse`, and `prompt-generator` have stronger demand-aligned guidance without
  trigger overlap regressions.
- `cluster-health` is public, generic, and useful without protected files.
- Protected cluster overlays are ignored by git.
- Public tracked files contain no private infrastructure details.
- Existing install behavior still works for public skills.
- Local protected overlays remain usable from the repo working tree with `./install.sh --tool
  claude,codex,opencode --link --force`; `--include-internal` should no longer be required for
  `cluster-health` after it becomes public.

## Implementation Order

1. Branch from current `main`.
2. Add `skill-router`.
3. Expand `prompt-generator`.
4. Expand `browse`.
5. Expand `frontend-design`.
6. Migrate `cluster-health` into public generic files plus protected local overlays.
7. Update `.gitignore`, linter policy, and docs.
8. Run validation and privacy checks.
9. Review focused diffs.
10. Commit in logical chunks and prepare PR text.

## Risks

- `cluster-health` can leak private information if migration is incomplete.
- `skill-router` can overlap too much with `skill-creator` or `skill-refiner` if its boundary is
  not explicit.
- `frontend-design` can grow beyond the line target if all examples are placed in `SKILL.md`.
- `browse` can encourage expensive browser usage if the cheapest-tool-first rule is weakened.
- `prompt-generator` can become a brainstorming workflow unless its "structure existing intent"
  boundary stays clear.

## Decisions For Implementation Planning

- The new discovery skill is named `skill-router`.
- `cluster-health` protected overlays remain under `skills/cluster-health/protected/` in the repo
  working tree, ignored by git.
- Privacy checking should be implemented as a script, not an ad hoc command.
- The work should land as one PR with logical commits unless the `cluster-health` migration becomes
  risky enough to split.
