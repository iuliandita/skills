# skills.

**Hand-built [Agent Skills](https://agentskills.io). The collection fixes itself.**

<div align="center">

```bash
npx skills add iuliandita/skills
```

39 skills for DevOps, security, infra, and software engineering, wired into a [Karpathy-style autoresearch loop](https://github.com/karpathy/autoresearch) that scores, improves, and verifies each one on every pass.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-open_standard-blue.svg)](https://agentskills.io)

</div>

---

## The story

AI coding tools used to mean prompts. Prompts don't compose, don't carry between tools, and don't improve unless you rewrite them by hand. Agent Skills replaced that: a directory of markdown plus a description, portable across every conformant tool. Drop a skill folder anywhere the spec is read and the agent gets a new capability.

Then Karpathy pointed an agent at a 630-line training script overnight. It edited the code, ran a 5-minute training, kept changes that improved the score, discarded the rest. 700 runs, 20 wins, on one GPU. The pattern works on anything you can score.

This repo is both. 39 hand-built skills, with the autoresearch loop wired up to refine them.

## The autoresearch loop

`skill-refiner` ports Karpathy's pattern to a skill collection. It loads every skill, scores it across three layers, picks the weakest, lets the agent rewrite it, then keeps the change only if the score moved.

The cycle:

> **Score → Improve → Verify → Keep or Revert → Repeat.**

- **Three-layer evaluation.** Lint validation (structural). AI self-check (quality). Behavioral testing against synthetic tasks (does the skill actually work in context?).
- **Adaptive focus.** First pass scores everything. Subsequent iterations target the lowest-scoring skills until they're brought up.
- **Cross-model peer review.** If a second AI harness is available (Claude alongside Codex, for example), the second model reviews every change the first one makes. Single-model blind spots get caught.
- **The Karpathy gate.** Only changes that measurably improve the score survive. Everything else reverts. No drift, no degeneration. Monotonic improvement.
- **Self-improvement.** `skill-refiner` improves its own evaluation infrastructure (including itself) in a separate meta-phase, with human review checkpoints.

Run it once and the collection sharpens. Run it ten times overnight and the bottom of the distribution catches up to the top.

## Why it matters

- **The collection improves itself.** New skills inherit whatever standard the loop currently enforces. The bar moves up; nothing has to be retrofitted by hand.
- **One folder, every tool.** Built on the [Agent Skills open standard](https://agentskills.io/specification). Any conformant tool reads them. No conversion, no per-tool forks.
- **Current beyond the training cutoff.** Skills carry this-week's CVEs, recent breaking changes, deprecation notices. Maintained, not stamped at one point in time.
- **Skills know about each other.** Routing hints (`Not for X (use Y)`) prevent collisions. The agent picks the right skill on the first call.

## Quick install

```bash
npx skills add iuliandita/skills
```

That's it. For specific skills, alternative tools, the bundled installer, or symlink mode across multiple agents, see [INSTALL.md](INSTALL.md).

## What's in here

39 skills covering infra (Kubernetes, Terraform, Docker, Ansible), distros (Arch, Debian, Fedora, Kali, NixOS), networking and firewalls, security and pentesting, code review and prose audits, frontend and UI design, AI/ML and MCP server work, virtualization, dev workflow tooling, and meta-tooling (the skill creator, refiner, and full-review orchestrator).

Browse [`skills/`](skills/) for the full list, or query it:

```bash
npx skills add iuliandita/skills --list
```

Each skill description is in its own `SKILL.md` frontmatter. The trigger keywords and routing hints there tell the agent when to load it.

## Compatibility

Built on the [Agent Skills open standard](https://agentskills.io/specification). Any conformant tool reads these directly. The bundled installer ships paths for 25 specific targets (Claude Code, Codex, Cursor, Gemini, Copilot, Windsurf, OpenCode, and others); see [INSTALL.md](INSTALL.md) for the full table and overrides.

## Contributing

Issues and PRs welcome. Skills must pass `./scripts/lint-skills.sh` and follow the [Agent Skills specification](https://agentskills.io/specification).

## License

[MIT](LICENSE)

---

`kubernetes` `terraform` `docker` `ansible` `archlinux` `cachyos` `pacman` `paru` `aur` `systemd` `nixos` `nix` `flakes` `home-manager` `nix-darwin` `helm` `argocd` `ci-cd` `github-actions` `gitlab-ci` `postgresql` `mongodb` `mysql` `networking` `dns` `wireguard` `tailscale` `vpn` `nftables` `opnsense` `pfsense` `mcp` `model-context-protocol` `security-audit` `owasp` `pentesting` `privilege-escalation` `ctf` `code-review` `git` `shell` `zsh` `bash` `prompt-engineering` `pci-dss` `compliance` `devops` `infrastructure-as-code` `iac` `containers` `podman` `buildah` `sealed-secrets` `haproxy` `caddy` `traefik` `nginx` `autoresearch` `self-improving` `llm` `rag` `embedding` `vector-store` `langchain` `langgraph` `openai-sdk` `anthropic-sdk` `agents` `fine-tuning` `ollama` `vllm` `promptfoo` `vitest` `jest` `playwright` `pytest` `tdd` `e2e` `accessibility` `axe-core` `load-testing` `k6` `proxmox` `qemu` `kvm` `libvirt` `packer` `cloud-init` `gpu-passthrough` `virtualization` `hypervisor`
