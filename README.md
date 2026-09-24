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
`./install.sh --detect` suggests which harnesses to target, and `--save` records a selection that a bare `./install.sh` repeats ([details](INSTALL.md#detect-and-save-a-setup)). `./install.sh --update` keeps a saved setup current from cron or a systemd timer ([details](INSTALL.md#scheduled-updates)).

## Collection

43 active skills, grouped by the work they cover:

| Area | Skills |
|------|--------|
| Infrastructure and operations | [ansible](skills/ansible/SKILL.md), [ci-cd](skills/ci-cd/SKILL.md), [kubernetes-health](skills/kubernetes-health/SKILL.md), [databases](skills/databases/SKILL.md), [message-queues](skills/message-queues/SKILL.md), [debug-triage](skills/debug-triage/SKILL.md), [docker](skills/docker/SKILL.md), [opnsense-pfsense](skills/opnsense-pfsense/SKILL.md), [kubernetes](skills/kubernetes/SKILL.md), [networking](skills/networking/SKILL.md), [observability](skills/observability/SKILL.md), [synology-dsm](skills/synology-dsm/SKILL.md), [terraform](skills/terraform/SKILL.md), [virtualization](skills/virtualization/SKILL.md) |
| Linux systems | [arch-linux](skills/arch-linux/SKILL.md), [debian-ubuntu](skills/debian-ubuntu/SKILL.md), [kali-linux](skills/kali-linux/SKILL.md), [nixos](skills/nixos/SKILL.md), [rhel-fedora](skills/rhel-fedora/SKILL.md) |
| Software development | [llm-app-development](skills/llm-app-development/SKILL.md), [backend-api](skills/backend-api/SKILL.md), [shell-scripting](skills/shell-scripting/SKILL.md), [frontend-design](skills/frontend-design/SKILL.md), [i18n-localization](skills/i18n-localization/SKILL.md), [mcp](skills/mcp/SKILL.md), [testing](skills/testing/SKILL.md), [performance-debugging](skills/performance-debugging/SKILL.md) |
| Review and security | [anti-ai-prose](skills/anti-ai-prose/SKILL.md), [code-simplification](skills/code-simplification/SKILL.md), [code-review](skills/code-review/SKILL.md), [repo-audit](skills/repo-audit/SKILL.md), [privilege-escalation](skills/privilege-escalation/SKILL.md), [security-audit](skills/security-audit/SKILL.md), [vulnerability-research](skills/vulnerability-research/SKILL.md) |
| Development workflows | [plan-review](skills/plan-review/SKILL.md), [dev-cycle](skills/dev-cycle/SKILL.md), [git](skills/git/SKILL.md), [session-handoff](skills/session-handoff/SKILL.md), [prompt-generator](skills/prompt-generator/SKILL.md), [roadmap](skills/roadmap/SKILL.md), [update-docs](skills/update-docs/SKILL.md) |
| Skill maintenance | [skill-creator](skills/skill-creator/SKILL.md), [skill-refiner](skills/skill-refiner/SKILL.md) |

Nineteen temporary old-name notices are excluded from this active catalog and from default
bundled installs. See [migration steps and the one-release, seven-day window](MIGRATION.md).

### Install a focused selection

Choose skills for your actual work; there is no need to install the whole collection.

```bash
# Application development
npx skills add iuliandita/skills --skill backend-api --skill frontend-design --skill testing

# Infrastructure
npx skills add iuliandita/skills --skill terraform --skill kubernetes --skill observability

# Skill maintenance
npx skills add iuliandita/skills --skill skill-creator --skill skill-refiner
```

## Using a skill

Ask your agent to use a skill by name, or describe a task that matches its trigger description. For example: "Use code-review to review this diff" or "Use kubernetes-health to check the current cluster."

Each `SKILL.md` defines when to use the skill, when to route elsewhere, and how to perform the work. Supporting references ship inside the same directory. Skills are instructions; they do not install the tools, credentials, or services a task requires.

Audit and review skills share a report format. Small reviews use compact chat output; larger audits include findings and evidence in a saved report. Reports default to `docs/local/`, with the user's requested output format and location taking precedence. Keep that directory ignored when reports contain private project details.

## Compatibility

Skills follow the [Agent Skills specification](https://agentskills.io/specification). The bundled installer provides paths for 27 targets, including Claude Code, Codex, Cursor, Copilot, OpenCode, Command Code, and Oh My Pi. See the [target table](INSTALL.md#supported-targets).

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

New skills must also be registered in the repository-audit coverage check or its [exclusions table](skills/repo-audit/references/exclusions.md). Run the repository's `scripts/check-*.sh` gates before pushing.

## License

[MIT](LICENSE)
