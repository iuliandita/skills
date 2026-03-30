# skills.

**Hand-crafted AI skills for DevOps, security, infrastructure, and software engineering.**

<div align="center">

```bash
npx skills add iuliandita/skills
```

**20 production-tested skills** -- Kubernetes, Terraform, Docker, Ansible, CI/CD, databases, Arch Linux, networking, MCP servers, security audits, pentesting, code review, and more.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

`kubernetes` `terraform` `docker` `ansible` `archlinux` `cachyos` `pacman` `paru` `aur` `systemd` `helm` `argocd` `ci-cd` `github-actions` `gitlab-ci` `postgresql` `mongodb` `mysql` `networking` `dns` `wireguard` `tailscale` `vpn` `nftables` `opnsense` `pfsense` `mcp` `model-context-protocol` `security-audit` `owasp` `pentesting` `privilege-escalation` `ctf` `code-review` `git` `shell` `zsh` `bash` `prompt-engineering` `pci-dss` `compliance` `devops` `infrastructure-as-code` `iac` `containers` `podman` `buildah` `sealed-secrets` `haproxy` `caddy` `traefik` `nginx`

---

These aren't generic prompts copy-pasted from a blog post. Every skill in this collection has been built iteratively, analyzed against real-world usage, cross-checked with official documentation, and refined through multiple passes until it actually works the way you'd expect. Each one is structured with a compact core that triggers fast and loads clean, plus dedicated reference files that get pulled in only when the agent needs the deep stuff -- compliance checklists, manifest templates, pattern libraries. No bloat in the main body, no missing context when it matters.

Every skill is researched well beyond any model's training cutoff. We're talking current CVEs, recent breaking changes, deprecation notices, and gotchas from *this week* -- not whatever the model last saw during pre-training. When Kubernetes drops a beta API, when Terraform changes provider behavior, when Docker deprecates a build flag -- these skills already know about it. Models are smart, but their knowledge has a shelf life. These skills keep it current.

This is a growing collection. New skills get added as they're built, tested, and proven useful. If you're using an AI coding tool without custom skills, you're leaving a lot of capability on the table.

## What's in the box

20 production-tested skills covering:

### Infrastructure & Operations

| Skill | What it does |
|-------|-------------|
| **ansible** | Playbooks, roles, collections, Molecule testing, Ansible Vault, CIS benchmarks, compliance hardening |
| **arch-btw** | Arch Linux and CachyOS administration -- pacman, paru, AUR, systemd, bootloader and kernel recovery |
| **docker** | Dockerfiles, Compose, Podman, Buildah, multi-stage builds, image signing, container hardening |
| **kubernetes** | Manifests, Helm charts, Gateway API, Kustomize, ArgoCD, sealed secrets, PCI-DSS compliance |
| **terraform** | Terraform/OpenTofu -- HCL patterns, module design, state management, policy-as-code, compliance |
| **databases** | PostgreSQL, MongoDB, MySQL/MariaDB, MSSQL -- tuning, schemas, migrations, replication, connection pooling |
| **ci-cd** | GitHub Actions, GitLab CI/CD, Forgejo workflows, supply chain security, SHA pinning, SBOM generation |

### Networking & Firewalls

| Skill | What it does |
|-------|-------------|
| **networking** | DNS, reverse proxies, VPNs, VLANs, load balancers, WireGuard, Tailscale, nftables, BGP/OSPF |
| **firewall-appliance** | OPNsense/pfSense firewall management via SSH -- pfctl, CrowdSec, pfBlockerNG, CARP failover, hardening |

### Security & Pentesting

| Skill | What it does |
|-------|-------------|
| **security-audit** | Vulnerability scanning, credential detection, auth review, OWASP checks, supply chain security |
| **lockpick** | Authorized privilege escalation assessments, CTF challenges, post-exploitation, container escape |

### Development & Code Quality

| Skill | What it does |
|-------|-------------|
| **code-review** | Bug hunting, logic errors, edge cases, race conditions, resource leaks, convention violations |
| **anti-slop** | Detects and fixes AI-generated code patterns -- over-abstraction, redundant comments, verbose defensive code |
| **git** | Commits, branches, hooks, signing, multi-forge workflows (GitHub, GitLab, Forgejo), release management |
| **command-prompt** | Shell scripting across zsh, bash, POSIX sh, fish, nushell -- dotfiles, completions, one-liners |
| **mcp** | MCP server development -- protocol patterns, transport, auth, input validation, injection prevention |
| **full-review** | Orchestrates code-review + anti-slop + security-audit + update-docs in one pass |

### Tooling & Meta

| Skill | What it does |
|-------|-------------|
| **prompt-generator** | Turn scattered ideas into structured LLM prompts -- system prompts, templates, prompt engineering |
| **skill-creator** | Create, review, audit, and optimize AI tool skills -- consistency checks, overlap detection |
| **update-docs** | Post-session documentation sweep -- captures gotchas, syncs instruction files, trims bloat |

## How they're built

Each skill follows a specific architecture:

- **Compact SKILL.md body** -- the core instructions that load into every conversation. Kept lean so it doesn't eat your context window.
- **Reference files** (`references/` directory) -- detailed pattern libraries, compliance checklists, manifest templates. The agent reads these on-demand when the task requires depth. You get expert-level detail without paying the token cost upfront.
- **Precise trigger descriptions** -- optimized so the right tool activates the right skill at the right time. Every trigger keyword is tested and tuned to minimize false positives and missed activations.
- **Cross-skill awareness** -- skills know about each other. The security-audit skill knows not to step on lockpick's territory. Docker knows to defer to Kubernetes for cluster networking. No overlapping, no conflicts.

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
# All skills for Claude
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh
rm -rf /tmp/skills-install

# Install for Codex
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool codex
rm -rf /tmp/skills-install

# Install for Cursor
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool cursor
rm -rf /tmp/skills-install

# Install for Windsurf
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool windsurf
rm -rf /tmp/skills-install

# Pick and choose
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh --tool claude kubernetes docker terraform ansible
/tmp/skills-install/install.sh --tool cursor prompt-generator
/tmp/skills-install/install.sh --tool opencode prompt-generator
/tmp/skills-install/install.sh --list  # see what's available
```

### Manual

```bash
cp -r skills/kubernetes ~/.claude/skills/kubernetes
cp -r skills/kubernetes ~/.codex/skills/kubernetes
cp -r skills/kubernetes ~/.cursor/skills/kubernetes
cp -r skills/kubernetes ~/.windsurf/skills/kubernetes
```

Claude, Codex, Cursor, and Windsurf can use the same `SKILL.md` directory structure for personal skills. The bundled installer supports `--tool claude`, `--tool codex`, `--tool cursor`, `--tool windsurf`, and `--tool opencode`.

## Requirements

- Claude Code
- Codex CLI
- Cursor
- Windsurf
- OpenCode
- Other tools that can consume skill directories or Markdown-based agent instructions

## Updating

Pull the latest and re-run the installer:

```bash
cd /path/to/skills
git pull
./install.sh
```

The installer backs up existing skills before overwriting, so you won't lose local customizations.

## Structure

```
skills/
  ansible/
    SKILL.md              # Core skill instructions
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
install.sh                # Installer script
publish.sh                # Maintainer sync script
```

## Contributing

Found a bug in a skill? Have a suggestion? Open an issue or PR. If you've built skills of your own and want to share, let's talk.

## License

[MIT](LICENSE)
