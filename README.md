# skills.sh

**Hand-crafted Claude Code skills for DevOps, security, infrastructure, and software engineering.**

These aren't generic prompts copy-pasted from a blog post. Every skill in this collection has been built iteratively, analyzed against real-world usage, cross-checked with official documentation, and refined through multiple passes until it actually works the way you'd expect. Each one is structured with a compact core that triggers fast and loads clean, plus dedicated reference files that get pulled in only when Claude needs the deep stuff -- compliance checklists, manifest templates, pattern libraries. No bloat in the main body, no missing context when it matters.

Every skill is researched well beyond Claude's training cutoff. We're talking current CVEs, recent breaking changes, deprecation notices, and gotchas from *this week* -- not whatever the model last saw during pre-training. When Kubernetes drops a beta API, when Terraform changes provider behavior, when Docker deprecates a build flag -- these skills already know about it. Claude is smart, but its knowledge has a shelf life. These skills keep it current.

This is a growing collection. New skills get added as they're built, tested, and proven useful. If you're using Claude Code without custom skills, you're leaving a lot of capability on the table.

## What's in the box

19 production-tested skills covering:

### Infrastructure & Operations

| Skill | What it does |
|-------|-------------|
| **ansible** | Playbooks, roles, collections, Molecule testing, Ansible Vault, CIS benchmarks, compliance hardening |
| **docker** | Dockerfiles, Compose, Podman, Buildah, multi-stage builds, image signing, container hardening |
| **kubernetes** | Manifests, Helm charts, Gateway API, Kustomize, ArgoCD, sealed secrets, PCI-DSS compliance |
| **terraform** | Terraform/OpenTofu -- HCL patterns, module design, state management, policy-as-code, compliance |
| **databases** | PostgreSQL, MongoDB, MySQL/MariaDB, MSSQL -- tuning, schemas, migrations, replication, connection pooling |
| **ci-cd** | GitHub Actions, GitLab CI/CD, Forgejo workflows, supply chain security, SHA pinning, SBOM generation |

### Networking & Firewalls

| Skill | What it does |
|-------|-------------|
| **networking** | DNS, reverse proxies, VPNs, VLANs, load balancers, WireGuard, Tailscale, nftables, BGP/OSPF |
| **opnsense** | OPNsense/pfSense firewall management via SSH -- pfctl, CrowdSec, CARP failover, hardening |

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
| **full-review** | Orchestrates code-review + anti-slop + security-audit + update-docs in one pass |

### Tooling & Meta

| Skill | What it does |
|-------|-------------|
| **prompt-generator** | Turn scattered ideas into structured LLM prompts -- system prompts, templates, prompt engineering |
| **skill-creator** | Create, review, audit, and optimize Claude Code skills -- consistency checks, overlap detection |
| **lightpanda** | Headless browser for JS-heavy pages via MCP -- scrape SPAs, extract data from dynamic sites |
| **update-docs** | Post-session documentation sweep -- captures gotchas, syncs CLAUDE.md/AGENTS.md, trims bloat |

## How they're built

Each skill follows a specific architecture:

- **Compact SKILL.md body** -- the core instructions that load into every conversation. Kept lean so it doesn't eat your context window.
- **Reference files** (`references/` directory) -- detailed pattern libraries, compliance checklists, manifest templates. Claude reads these on-demand when the task requires depth. You get expert-level detail without paying the token cost upfront.
- **Precise trigger descriptions** -- optimized so Claude activates the right skill at the right time. Every trigger keyword is tested and tuned to minimize false positives and missed activations.
- **Cross-skill awareness** -- skills know about each other. The security-audit skill knows not to step on lockpick's territory. Docker knows to defer to Kubernetes for cluster networking. No overlapping, no conflicts.

## Install

### All skills at once

```bash
# Clone and install everything
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh
rm -rf /tmp/skills-install
```

### Pick and choose

```bash
# Install specific skills
git clone https://github.com/iuliandita/skills.git /tmp/skills-install
/tmp/skills-install/install.sh kubernetes docker terraform ansible

# See what's available
/tmp/skills-install/install.sh --list
```

### Manual install

Just copy the skill directory into `~/.claude/skills/`:

```bash
cp -r skills/kubernetes ~/.claude/skills/kubernetes
```

That's it. Claude Code picks them up automatically on the next conversation.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) (CLI, desktop app, or IDE extension)
- Skills support (available in all current Claude Code versions)

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
