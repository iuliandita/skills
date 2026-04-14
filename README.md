# skills.

**Hand-crafted [Agent Skills](https://agentskills.io) for DevOps, security, infrastructure, and software engineering.**

<div align="center">

```bash
npx skills add iuliandita/skills
```

**33 production-tested skills** - Kubernetes, Terraform, Docker, Ansible, CI/CD, HTTP APIs, databases, AI/ML, testing, virtualization, Arch Linux, networking, MCP servers, security audits, pentesting, code review, prose audits, dev workflow orchestration, and more.

Built on the [Agent Skills open standard](https://agentskills.io/specification). Works with any tool that supports it.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-open_standard-blue.svg)](https://agentskills.io)

</div>

---

`kubernetes` `terraform` `docker` `ansible` `archlinux` `cachyos` `pacman` `paru` `aur` `systemd` `helm` `argocd` `ci-cd` `github-actions` `gitlab-ci` `postgresql` `mongodb` `mysql` `networking` `dns` `wireguard` `tailscale` `vpn` `nftables` `opnsense` `pfsense` `mcp` `model-context-protocol` `security-audit` `owasp` `pentesting` `privilege-escalation` `ctf` `code-review` `git` `shell` `zsh` `bash` `prompt-engineering` `pci-dss` `compliance` `devops` `infrastructure-as-code` `iac` `containers` `podman` `buildah` `sealed-secrets` `haproxy` `caddy` `traefik` `nginx` `autoresearch` `self-improving` `llm` `rag` `embedding` `vector-store` `langchain` `langgraph` `openai-sdk` `anthropic-sdk` `agents` `fine-tuning` `ollama` `vllm` `promptfoo` `vitest` `jest` `playwright` `pytest` `tdd` `e2e` `accessibility` `axe-core` `load-testing` `k6` `proxmox` `qemu` `kvm` `libvirt` `packer` `cloud-init` `gpu-passthrough` `virtualization` `hypervisor`

---

## Compatibility

These skills follow the [Agent Skills open standard](https://agentskills.io/specification) - the cross-vendor format for portable AI agent capabilities. Any tool that reads `SKILL.md` files can use them directly:

- **Claude Code** - native support
- **OpenAI Codex CLI** - native support
- **Gemini CLI** - native support
- **Cursor** - native support
- **VS Code GitHub Copilot** - native support
- **Windsurf** - native support
- **OpenCode** - native support
- **Cline** - native support
- **Roo Code** - native support
- **Goose** - native support
- **Amp** - native support
- **Continue** - native support
- **Kiro CLI** - native support
- **Warp** - native support
- Any other tool that implements the Agent Skills spec

No conversion, no adapters. Drop the skill folder in your tool's skills directory and it works.

## Why these skills

These aren't generic prompts copy-pasted from a blog post. Every skill in this collection has been built iteratively, analyzed against real-world usage, cross-checked with official documentation, and refined through multiple passes until it actually works the way you'd expect. Each one is structured with a compact core that triggers fast and loads clean, plus dedicated reference files that get pulled in only when the agent needs the deep stuff - compliance checklists, manifest templates, pattern libraries. No bloat in the main body, no missing context when it matters.

Every skill is researched well beyond any model's training cutoff. We're talking current CVEs, recent breaking changes, deprecation notices, and gotchas from *this week* - not whatever the model last saw during pre-training. When Kubernetes drops a beta API, when Terraform changes provider behavior, when Docker deprecates a build flag - these skills already know about it. Models are smart, but their knowledge has a shelf life. These skills keep it current.

This is a growing collection. New skills get added as they're built, tested, and proven useful. If you're using an AI coding tool without custom skills, you're leaving a lot of capability on the table.

## NEW: Self-Improving Skills

**skill-refiner** brings [Karpathy's AutoResearch](https://github.com/karpathy/autoresearch) pattern to AI skill collections. Instead of manually reviewing and improving skills one by one, skill-refiner runs an automated loop that scores, improves, and validates every skill in the collection - then does it again.

The loop: **Score -> Improve -> Verify -> Keep or Revert -> Repeat.**

- **Adaptive focus** - first pass scores everything, then subsequent iterations zero in on the weakest skills until they're brought up to standard
- **Three-layer evaluation** - lint validation (structural), AI self-check (quality), and behavioral testing against synthetic tasks (does the skill actually work?)
- **Cross-model peer review** - if you have multiple AI harnesses installed (Claude + Codex, for example), the secondary model reviews every improvement the primary makes. Adversarial evaluation catches single-model blind spots.
- **Karpathy gate** - only changes that measurably improve a skill's score survive. Everything else gets reverted. No drift, no degeneration, monotonic improvement.
- **Self-improvement** - skill-refiner improves its own evaluation infrastructure (including itself) in a separate meta-phase with human review checkpoints

10 iterations. 29 skills. One command.

## What's in the box

29 production-tested skills covering:

### Infrastructure & Operations

| Skill | What it does |
|-------|-------------|
| **ansible** | Playbooks, roles, collections, Molecule testing, Ansible Vault, CIS benchmarks, compliance hardening |
| **arch-btw** | Arch Linux and CachyOS administration - pacman, paru, AUR, systemd, bootloader and kernel recovery |
| **docker** | Dockerfiles, Compose, Podman, Buildah, multi-stage builds, image signing, container hardening |
| **kubernetes** | Manifests, Helm charts, Gateway API, Kustomize, ArgoCD, sealed secrets, PCI-DSS compliance |
| **terraform** | Terraform/OpenTofu - HCL patterns, module design, state management, policy-as-code, compliance |
| **databases** | PostgreSQL, MongoDB, MySQL/MariaDB, MSSQL - tuning, schemas, migrations, replication, connection pooling |
| **ci-cd** | GitHub Actions, GitLab CI/CD, Forgejo workflows, supply chain security, SHA pinning, SBOM generation |
| **virtualization** | Proxmox VE, libvirt/QEMU/KVM, XCP-ng, VMware - Terraform provisioning, Packer templates, cloud-init, GPU passthrough, storage backends, clustering, live migration |

### Networking & Firewalls

| Skill | What it does |
|-------|-------------|
| **networking** | DNS, reverse proxies, VPNs, VLANs, load balancers, WireGuard, Tailscale, nftables, BGP/OSPF |
| **firewall-appliance** | OPNsense/pfSense firewall management via SSH - pfctl, CrowdSec, pfBlockerNG, CARP failover, hardening |

### Security & Pentesting

| Skill | What it does |
|-------|-------------|
| **security-audit** | Vulnerability scanning, credential detection, auth review, OWASP checks, supply chain security |
| **lockpick** | Authorized privilege escalation assessments, CTF challenges, post-exploitation, container escape |
| **zero-day** | Vulnerability research - deep code analysis, binary reverse engineering, patch diffing, fuzzing, variant analysis, PoC development |

### Development & Code Quality

| Skill | What it does |
|-------|-------------|
| **code-review** | Bug hunting, logic errors, edge cases, race conditions, resource leaks, convention violations |
| **anti-slop** | Detects and fixes AI-generated code patterns - hallucinated APIs/flags/resources, duplicate code, test theater, over-abstraction, redundant comments, verbose defensive code |
| **anti-ai-prose** | Audits writing for AI tells - vocabulary (delve, tapestry), syntax (negative parallelism, tricolons), tone (travel-guide voice, vague attribution), formatting (em-dash abuse). Covers docs, READMEs, wikis, PRs, emails, slides, creative writing |
| **backend-api** | HTTP backend APIs - FastAPI, Express, NestJS, REST/OpenAPI contracts, auth flows, versioning, pagination, idempotency |
| **testing** | Unit, integration, E2E, accessibility, and performance tests - Vitest, Jest, Playwright, pytest, Go testing, cargo test, TDD workflows, mocking strategies, CI test infrastructure |
| **git** | Commits, branches, hooks, signing, multi-forge workflows (GitHub, GitLab, Forgejo), release management |
| **command-prompt** | Shell scripting across zsh, bash, POSIX sh, fish, nushell - dotfiles, completions, one-liners |
| **mcp** | MCP server development - protocol patterns, transport, auth, input validation, injection prevention |
| **ai-ml** | LLM integrations, RAG pipelines, agent systems, embeddings, evaluation harnesses, local inference, fine-tuning, structured output, tool use, cost optimization, safety guardrails |
| **full-review** | Orchestrates code-review + anti-slop + security-audit + update-docs in one pass |

### Tooling & Meta

| Skill | What it does |
|-------|-------------|
| **prompt-generator** | Turn scattered ideas into structured LLM prompts - system prompts, templates, prompt engineering |
| **roadmap** | Keep a gitignored `ROADMAP.md` current - capture ideas, shipped work, priorities, and competitor signals |
| **routine-writer** | Write Claude Code routine prompts - self-contained tasks that run unattended on Anthropic cloud via schedule, API, or GitHub triggers. Emits `/schedule` CLI commands and `/fire` curl templates |
| **skill-creator** | Create, review, audit, and optimize AI tool skills - consistency checks, overlap detection |
| **skill-refiner** | Self-improving loop - iterative quality sweeps with cross-model review, inspired by Karpathy's AutoResearch |
| **update-docs** | Post-session documentation sweep - captures gotchas, syncs instruction files, trims bloat |

## How they're built

Each skill follows the [Agent Skills specification](https://agentskills.io/specification):

- **`SKILL.md` with YAML frontmatter** - `name`, `description`, `license`, optional `compatibility` for environment requirements, and `metadata` for custom fields. The frontmatter is what agents read at startup to decide which skills to activate.
- **Compact body** (target under 500 lines, 600 hard max) - the core instructions that load into every conversation. Kept lean so it doesn't eat your context window.
- **Reference files** (`references/` directory) - detailed pattern libraries, compliance checklists, manifest templates. The agent reads these on-demand when the task requires depth. You get expert-level detail without paying the token cost upfront.
- **Argument hints** (`metadata.argument_hint`) - tells agents what arguments a skill expects when invoked (e.g., `<file-or-pattern>`, `[iterations]`). Angle brackets for required, square brackets for optional.
- **Precise trigger descriptions** - optimized so the right tool activates the right skill at the right time. Every trigger keyword is tested and tuned to minimize false positives and missed activations.
- **Cross-skill awareness** - skills know about each other. The security-audit skill knows not to step on lockpick's territory. Docker knows to defer to Kubernetes for cluster networking. No overlapping, no conflicts.

## Install

### Quick install (via [skills.sh](https://skills.sh))

```bash
# All skills
npx skills add iuliandita/skills

# Pick specific ones
npx skills add iuliandita/skills --skill kubernetes --skill docker --skill terraform

# See what's available
npx skills add iuliandita/skills --list
```

### Using the bundled installer

```bash
# All skills for Claude (default)
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh
rm -rf /tmp/skills-install

# Install for a specific tool
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool codex
rm -rf /tmp/skills-install

# Pick and choose
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool claude kubernetes docker terraform ansible
/tmp/skills-install/install.sh --list  # see what's available
rm -rf /tmp/skills-install
```

### Multi-tool install with symlinks

Install once, symlink everywhere. Skills go to a single canonical directory (`~/.agents/skills/`), and each tool gets symlinks. Update the canonical copy and all tools see the change.

```bash
git clone https://github.com/iuliandita/skills.git /tmp/skills-install

# Install for Claude, Cursor, and Gemini in one shot
/tmp/skills-install/install.sh --tool claude,cursor,gemini --link

# Check for updates later
/tmp/skills-install/install.sh --check --link

rm -rf /tmp/skills-install
```

Override the canonical directory with `SKILLS_CANONICAL_DIR`:

```bash
SKILLS_CANONICAL_DIR=~/my-skills ./install.sh --tool claude,roo --link
```

### Checking for updates

Each install writes a `.skills-lock.json` with content hashes. Compare against the source to see what changed:

```bash
./install.sh --check                # check default (Claude)
./install.sh --check --tool cursor  # check a specific tool
./install.sh --check --link         # check canonical dir
```

### Manual

```bash
cp -r skills/kubernetes ~/.claude/skills/kubernetes
cp -r skills/kubernetes ~/.codex/skills/kubernetes
cp -r skills/kubernetes ~/.cursor/skills/kubernetes
```

### Supported tools

The installer supports 15 targets:

| Tool | Flag | Default path |
|------|------|-------------|
| Claude Code | `claude` | `~/.claude/skills` |
| OpenAI Codex | `codex` | `~/.codex/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| Windsurf | `windsurf` | `~/.windsurf/skills` |
| OpenCode | `opencode` | `~/.config/opencode/skills` |
| GitHub Copilot | `copilot` | `~/.copilot/skills` |
| Gemini CLI | `gemini` | `~/.gemini/skills` |
| Roo Code | `roo` | `~/.roo/skills` |
| Goose | `goose` | `~/.config/goose/skills` |
| Amp | `amp` | `~/.amp/skills` |
| Continue | `continue` | `~/.continue/skills` |
| Kiro CLI | `kiro` | `~/.kiro/skills` |
| Cline | `cline` | `~/.cline/skills` |
| Warp | `warp` | `~/.warp/skills` |
| Portable | `portable` | `~/.skills` |

All paths are overridable via `--dest` (single-tool mode) or environment variables (e.g., `CLAUDE_SKILLS_DIR`).

## Requirements

Any AI coding tool that supports the [Agent Skills standard](https://agentskills.io). See the [supported tools table](#supported-tools) above for the full list of tested targets.

## Releases

Releases use release-please in PR mode. Releasable commits merged to `main` open or
update a release PR, and merging that release PR creates the tag and GitHub Release.

- `feat:` creates a minor release
- `fix:` creates a patch release
- `deps:` creates a patch release
- `feat!:` / `fix!:` / `BREAKING CHANGE:` creates a major release
- `docs:`, `chore:`, `ci:`, `test:`, and `style:` do not trigger a release on their own

This repo uses release-please, which only treats `feat`, `fix`, and `deps` as releasable
units. If a refactor or performance change should cut a release, use a squash-merge title
that reflects the user-facing impact, usually `fix:`.

## Updating

Pull the latest and re-run the installer:

```bash
cd /path/to/skills
git pull
./install.sh --force
```

Or check what changed first:

```bash
cd /path/to/skills
git pull
./install.sh --check   # see what's outdated
./install.sh --force   # update everything
```

The installer backs up existing skills before overwriting (unless `--no-backup`), so you won't lose local customizations.

## Structure

```
skills/
  ansible/
    SKILL.md              # Core skill instructions (Agent Skills spec)
    references/           # Deep-dive reference files
      compliance.md
      playbook-patterns.md
      ...
  docker/
    SKILL.md
    references/
      dockerfile-patterns.md
      ...
  ...
install.sh                # Installer (15 agents, symlink mode, lock file)
scripts/
  lint-skills.sh          # Collection linter
  validate-spec.sh        # Agent Skills spec validator
```

## Contributing

Found a bug in a skill? Have a suggestion? Open an issue or PR. If you've built skills of your own and want to share, let's talk.

Skills must pass `./scripts/lint-skills.sh` and follow the [Agent Skills specification](https://agentskills.io/specification).

## License

[MIT](LICENSE)
