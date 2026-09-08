# skills

Agent skills for infrastructure, security, software engineering, and agent workflows. Each skill provides task instructions, routing hints, and supporting references that can be installed individually.

## Install

```bash
# Browse the collection
npx skills add iuliandita/skills --list

# Install selected skills
npx skills add iuliandita/skills --skill kubernetes --skill docker
```

The bundled installer also supports copying skills or sharing one canonical copy across tools with symlinks:

```bash
git clone https://github.com/iuliandita/skills.git
cd skills
./install.sh --tool codex kubernetes docker
```

See [installation and updates](INSTALL.md) for target paths, symlink mode, backups, and private overlays.

## Collection

47 skills, grouped by the work they cover:

| Area | Skills |
|------|--------|
| Infrastructure and operations | [ansible](skills/ansible/SKILL.md), [ci-cd](skills/ci-cd/SKILL.md), [cluster-health](skills/cluster-health/SKILL.md), [databases](skills/databases/SKILL.md), [debug-triage](skills/debug-triage/SKILL.md), [docker](skills/docker/SKILL.md), [firewall-appliance](skills/firewall-appliance/SKILL.md), [kubernetes](skills/kubernetes/SKILL.md), [networking](skills/networking/SKILL.md), [observability](skills/observability/SKILL.md), [synology-dsm](skills/synology-dsm/SKILL.md), [terraform](skills/terraform/SKILL.md), [virtualization](skills/virtualization/SKILL.md) |
| Linux systems | [arch-btw](skills/arch-btw/SKILL.md), [debian-ubuntu](skills/debian-ubuntu/SKILL.md), [kali-linux](skills/kali-linux/SKILL.md), [nixos-btw](skills/nixos-btw/SKILL.md), [rhel-fedora](skills/rhel-fedora/SKILL.md) |
| Software development | [ai-ml](skills/ai-ml/SKILL.md), [backend-api](skills/backend-api/SKILL.md), [browse](skills/browse/SKILL.md), [command-prompt](skills/command-prompt/SKILL.md), [frontend-design](skills/frontend-design/SKILL.md), [localize](skills/localize/SKILL.md), [mcp](skills/mcp/SKILL.md), [testing](skills/testing/SKILL.md) |
| Review and security | [anti-ai-prose](skills/anti-ai-prose/SKILL.md), [anti-slop](skills/anti-slop/SKILL.md), [code-review](skills/code-review/SKILL.md), [code-slimming](skills/code-slimming/SKILL.md), [deep-audit](skills/deep-audit/SKILL.md), [full-review](skills/full-review/SKILL.md), [jekyll-hyde](skills/jekyll-hyde/SKILL.md), [lockpick](skills/lockpick/SKILL.md), [security-audit](skills/security-audit/SKILL.md), [zero-day](skills/zero-day/SKILL.md) |
| Development workflows | [deep-grill](skills/deep-grill/SKILL.md), [dev-cycle](skills/dev-cycle/SKILL.md), [git](skills/git/SKILL.md), [handoff](skills/handoff/SKILL.md), [prompt-generator](skills/prompt-generator/SKILL.md), [roadmap](skills/roadmap/SKILL.md), [routine-writer](skills/routine-writer/SKILL.md), [update-docs](skills/update-docs/SKILL.md) |
| Skill maintenance | [skill-creator](skills/skill-creator/SKILL.md), [skill-refiner](skills/skill-refiner/SKILL.md), [skill-router](skills/skill-router/SKILL.md) |

## Using a skill

Ask your agent to use a skill by name, or describe a task that matches its trigger description. For example: "Use code-review to review this diff" or "Use cluster-health to check the current cluster."

Each `SKILL.md` defines when to use the skill, when to route elsewhere, and how to perform the work. Supporting references ship inside the same directory. Skills are instructions; they do not install the tools, credentials, or services a task requires.

Audit and review skills share a report format. Small reviews use compact chat output; larger audits include findings and evidence in a saved report. Reports default to `docs/local/`, with the user's requested output format and location taking precedence. Keep that directory ignored when reports contain private project details.

## Compatibility

Skills follow the [Agent Skills specification](https://agentskills.io/specification). The bundled installer provides paths for 25 targets, including Claude Code, Codex, Cursor, Gemini CLI, Copilot, and OpenCode. See the [target table](INSTALL.md#supported-targets).

Path support does not establish equivalent runtime behavior. Activation, reference loading, tool access, and delegation depend on the consuming agent and model. Smoke-test important workflows after installing skills or changing models.

## Quality and maintenance

Repository checks cover frontmatter, routing conventions, reference links, size limits, generated-file consistency, and installer behavior. Run the collection's structural checks locally:

```bash
./scripts/lint-skills.sh
./scripts/validate-spec.sh
```

[skill-refiner](skills/skill-refiner/SKILL.md) adds iterative scoring, synthetic behavioral tasks, and peer review. Changes are kept only after the required checks and review pass and the composite score improves. Review weight depends on verified model identity; a fresh session alone does not establish cross-model review.

The [run history](.refiner-runs.json) and [score ledger](.refiner-ledger.md) record past evaluations. Scores describe those runs, not a guarantee of correctness or performance on another model or task. Tool-version checks also need source verification; see [version pin receipts](docs/version-pins.md).

## Contributing

Use a branch and pull request, with green CI before squash merge. See [skill authoring](docs/skill-authoring.md) for opening summaries and [INSTALL.md](INSTALL.md#releases) for the release workflow. Report vulnerabilities using [SECURITY.md](SECURITY.md).

Every skill must work when installed alone: runtime file references stay inside its own directory. Shared output and agent-hygiene instructions originate in `skills/_shared/`; edit those sources and regenerate the shipped copies:

```bash
./scripts/gen-contract-refs.sh
./scripts/check-contract-sync.sh
```

New skills must also be registered in the deep-audit coverage check or its [exclusions table](skills/deep-audit/references/exclusions.md). Run the repository's `scripts/check-*.sh` gates before pushing.

## License

[MIT](LICENSE)
