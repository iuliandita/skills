# skills.

**Hand-built [Agent Skills](https://agentskills.io) with automated quality gates.**

<div align="center">

```bash
npx skills add iuliandita/skills
```

41 skills for DevOps, security, infra, and software engineering, maintained with lint/spec checks, behavioral test coverage, and a [Karpathy-style autoresearch loop](https://github.com/karpathy/autoresearch).

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-open_standard-blue.svg)](https://agentskills.io)

</div>

---

## The story

AI coding tools used to mean prompts. Prompts don't compose, don't carry between tools, and don't improve unless you rewrite them by hand. Agent Skills replaced that: a directory of markdown plus a description, portable across every conformant tool. Drop a skill folder anywhere the spec is read and the agent gets a new capability.

Then Karpathy pointed an agent at a 630-line training script overnight. It edited the code, ran a 5-minute training, kept changes that improved the score, discarded the rest. 700 runs, 20 wins, on one GPU. The pattern works on anything you can score.

This repo applies that pattern conservatively to 41 hand-built skills. The loop helps find weak spots and propose improvements; the gates and review discipline decide what survives.

## The autoresearch loop

`skill-refiner` ports Karpathy's pattern to a skill collection. It loads every skill, scores it across structural and behavioral checks, targets the weakest areas, and keeps changes only when the measured result improves without failing review.

The cycle:

> **Score → Improve → Verify → Keep or Revert → Repeat.**

- **Structural gates.** `lint-skills.sh` and `validate-spec.sh` enforce the collection shape, YAML frontmatter, routing conventions, reference links, and size limits.
- **Behavioral checks.** Synthetic tasks test whether the skill produces useful output in context. These are useful signals, not proof of universal behavior across every model.
- **Adaptive focus.** First pass scores everything. Subsequent iterations target the lowest-scoring skills until they're brought up.
- **Cross-model peer review.** If a second AI harness is available (Claude alongside Codex, for example), the second model reviews every change the first one makes. Single-model blind spots get caught.
- **The Karpathy gate.** Only changes that measurably improve the score survive. Changes that score worse, remove important content, or fail peer review are reverted or revised.
- **Self-improvement.** `skill-refiner` improves its own evaluation infrastructure (including itself) in a separate meta-phase, with human review checkpoints.

The goal is not magic self-repair. The goal is a repeatable maintenance loop with evidence, review points, and a bias toward reverting weak changes.

## Quality evidence

Current repository gates pass for all 41 public skills:

```bash
./scripts/lint-skills.sh
./scripts/validate-spec.sh
```

The latest tracked refiner run in [`.refiner-runs.json`](.refiner-runs.json) is dated 2026-04-23. It ended with lint/spec warnings cleared, behavioral test groups present for 37/37 public non-internal skills in that run, and cross-harness peer review returning no flags after a major regression was caught and fixed.

That evidence is a maintenance signal, not a permanent guarantee. Skill behavior still depends on the consuming agent, model, tool limits, and whether the task matches the skill's intended scope.

## Why it matters

- **The collection is easier to improve safely.** New skills inherit the current lint, spec, routing, and behavioral standards. The bar moves through explicit checks instead of memory.
- **One folder, every tool.** Built on the [Agent Skills open standard](https://agentskills.io/specification). Any conformant tool reads them. No conversion, no per-tool forks.
- **Maintained outside model weights.** Skills can carry recent tool changes, CVEs, deprecations, and local practices without waiting for a model retrain.
- **Skills know about each other.** Routing hints (`Not for X (use Y)`) reduce collisions and help agents choose the right instruction set.

## Quick install

```bash
npx skills add iuliandita/skills
```

That's it. For specific skills, alternative tools, the bundled installer, or symlink mode across multiple agents, see [INSTALL.md](INSTALL.md).

## What's in here

41 skills covering infra (Kubernetes, Terraform, Docker, Ansible), cluster health diagnostics, distros (Arch, Debian, Fedora, Kali, NixOS), networking and firewalls, security and pentesting, code review and prose audits, frontend and UI design, AI/ML and MCP server work, virtualization, dev workflow tooling, and meta-tooling (the skill creator, refiner, router, and full-review orchestrator).

Browse [`skills/`](skills/) for the full list, or query it:

```bash
npx skills add iuliandita/skills --list
```

Each skill description is in its own `SKILL.md` frontmatter. The trigger keywords and routing hints there tell the agent when to load it.

## Compatibility

Built on the [Agent Skills open standard](https://agentskills.io/specification). Any conformant tool can read the skill structure directly. The bundled installer ships paths for 25 specific targets (Claude Code, Codex, Cursor, Gemini, Copilot, Windsurf, OpenCode, and others); see [INSTALL.md](INSTALL.md) for the full table and overrides.

Installer support means the repo knows where to copy or symlink the skills. It is not a certification that every target handles activation, trigger matching, context loading, or subagent workflows identically. Smoke-test important skills in the agent you plan to use.

## Contributing

Issues and PRs welcome. Skills must pass `./scripts/lint-skills.sh` and follow the [Agent Skills specification](https://agentskills.io/specification).

## License

[MIT](LICENSE)

---

`kubernetes` `terraform` `docker` `ansible` `archlinux` `cachyos` `pacman` `paru` `aur` `systemd` `nixos` `nix` `flakes` `home-manager` `nix-darwin` `helm` `argocd` `ci-cd` `github-actions` `gitlab-ci` `postgresql` `mongodb` `mysql` `networking` `dns` `wireguard` `tailscale` `vpn` `nftables` `opnsense` `pfsense` `mcp` `model-context-protocol` `security-audit` `owasp` `pentesting` `privilege-escalation` `ctf` `code-review` `git` `shell` `zsh` `bash` `prompt-engineering` `pci-dss` `compliance` `devops` `infrastructure-as-code` `iac` `containers` `podman` `buildah` `sealed-secrets` `haproxy` `caddy` `traefik` `nginx` `autoresearch` `self-improving` `llm` `rag` `embedding` `vector-store` `langchain` `langgraph` `openai-sdk` `anthropic-sdk` `agents` `fine-tuning` `ollama` `vllm` `promptfoo` `vitest` `jest` `playwright` `pytest` `tdd` `e2e` `accessibility` `axe-core` `load-testing` `k6` `proxmox` `qemu` `kvm` `libvirt` `packer` `cloud-init` `gpu-passthrough` `virtualization` `hypervisor`
