# Install & maintain

Full install, update, and structure docs for the skills repo. For a quick start, see the [README](README.md).

## Install

### Quick install via skills.sh

```bash
# All skills
npx skills add iuliandita/skills

# Pick specific ones
npx skills add iuliandita/skills --skill kubernetes --skill docker --skill terraform

# See what's available
npx skills add iuliandita/skills --list
```

### Bundled installer

Clone, run, clean up:

```bash
git clone https://github.com/iuliandita/skills.git /tmp/skills-install

# All skills, Claude (default)
/tmp/skills-install/install.sh

# All skills, a specific tool
/tmp/skills-install/install.sh --tool codex

# Selected skills
/tmp/skills-install/install.sh --tool claude kubernetes docker terraform ansible

# What's available
/tmp/skills-install/install.sh --list

rm -rf /tmp/skills-install
```

### Multi-tool with symlinks

Install once to a canonical directory, symlink everywhere. Update the canonical copy and every tool sees the change.

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

### Local private skills

Skills declaring `metadata.internal: true` and gitignored locally are skipped by default. Pass `--include-internal` to install them too.

```bash
./install.sh --tool claude,codex,opencode --link --include-internal --force
```

### Manual

```bash
cp -r skills/kubernetes ~/.claude/skills/kubernetes
cp -r skills/kubernetes ~/.codex/skills/kubernetes
cp -r skills/kubernetes ~/.cursor/skills/kubernetes
```

## Supported targets

The installer ships paths for 25 targets. All paths are overridable via `--dest` (single-tool mode) or per-tool environment variables (e.g., `CLAUDE_SKILLS_DIR`).

Support in this table means **path support**: the installer knows where to copy or symlink the skill folders for that target. Runtime behavior is owned by the consuming tool. Activation rules, trigger matching, context limits, subagent support, and reference-file loading can differ between agents, even when they all read the same skill directory.

For important workflows, smoke-test the target tool after install:

```bash
# Example: install one skill, then ask the target agent to use it on a small task
./install.sh --tool codex kubernetes
```

| Tool | Flag | Default path |
|------|------|-------------|
| Claude Code | `claude` | `~/.claude/skills` |
| OpenAI Codex | `codex` | `~/.codex/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| Windsurf | `windsurf` | `~/.codeium/windsurf/skills` |
| OpenCode | `opencode` | `~/.config/opencode/skills` |
| GitHub Copilot | `copilot` | `~/.copilot/skills` |
| Gemini CLI | `gemini` | `~/.gemini/skills` |
| Roo Code | `roo` | `~/.roo/skills` |
| Goose | `goose` | `~/.config/goose/skills` |
| Amp | `amp` | `~/.config/agents/skills` |
| Continue | `continue` | `~/.continue/skills` |
| Kiro CLI | `kiro` | `~/.kiro/skills` |
| Cline | `cline` | `~/.agents/skills` |
| Warp | `warp` | `~/.agents/skills` |
| OpenClaw | `openclaw` | `~/.openclaw/skills` |
| Hermes Agent | `hermes` | `~/.hermes/skills` |
| Qwen Code | `qwen` | `~/.qwen/skills` |
| Crush | `crush` | `~/.config/crush/skills` |
| Google Antigravity | `antigravity` | `~/.gemini/antigravity/skills` |
| Augment | `augment` | `~/.augment/skills` |
| OpenHands | `openhands` | `~/.openhands/skills` |
| Trae | `trae` | `~/.trae/skills` |
| Qoder | `qoder` | `~/.qoder/skills` |
| Kimi Code CLI | `kimi` | `~/.config/agents/skills` |
| Portable | `portable` | `~/.skills` |

Common aliases also work: `claude-code`, `openai-codex`, `github-copilot`, `gemini-cli`, `kiro-cli`, `qwen-code`, `kimi-cli`.

Some agent ecosystems prefer shared or project-local skill directories. OpenClaw also scans `~/.agents/skills`; Hermes can be configured to scan external directories such as `~/.agents/skills`. NanoClaw is intentionally not a normal global target because its docs use project-local `.claude/skills` and `container/skills`; install to a NanoClaw checkout with `--tool portable --dest /path/to/NanoClaw/.claude/skills` or `--dest /path/to/NanoClaw/container/skills` as appropriate.

## Updating

Pull the latest and re-run the installer:

```bash
cd /path/to/skills
git pull
./install.sh --force      # update everything
```

Or check what changed first:

```bash
./install.sh --check       # list outdated skills
./install.sh --force       # apply
```

The installer backs up existing skills before overwriting (unless `--no-backup`), so local customizations are preserved.

## Checking for updates

Each install writes a `.skills-lock.json` with content hashes. Compare against the source:

```bash
./install.sh --check                  # check default (Claude)
./install.sh --check --tool cursor    # check a specific tool
./install.sh --check --link           # check canonical dir
```

## Skill anatomy

Each skill follows the [Agent Skills specification](https://agentskills.io/specification):

- **`SKILL.md` with YAML frontmatter** - `name`, `description`, `license`, optional `compatibility` for environment requirements, and `metadata` for custom fields. The frontmatter is what agents read at startup to decide which skills to activate.
- **Compact body** - the core instructions that load into every conversation. Target under 500 lines, 600 hard max. Kept lean so it doesn't eat the context window.
- **Reference files** in `references/` - detailed pattern libraries, compliance checklists, manifest templates. The agent reads these on-demand when the task requires depth. Expert-level detail without paying the token cost upfront.
- **Argument hints** (`metadata.argument_hint`) - tells agents what arguments a skill expects (e.g., `<file-or-pattern>`, `[iterations]`). Angle brackets for required, square brackets for optional.
- **Precise trigger descriptions** - target around 200 characters (warn above 240) so startup skill lists stay compact in tools with tight context budgets.
- **Cross-skill awareness** - skills know about each other. Routing hints (`Not for X (use Y)`) prevent collisions. The security-audit skill defers to lockpick on offensive work; docker defers to kubernetes on cluster networking.

## Structure

```
skills/
  ansible/
    SKILL.md              # core skill instructions (Agent Skills spec)
    references/           # deep-dive reference files
      compliance.md
      playbook-patterns.md
      ...
  docker/
    SKILL.md
    references/
      dockerfile-patterns.md
      ...
  ...
install.sh                # installer (25 targets, symlink mode, lock file)
scripts/
  lint-skills.sh          # collection linter
  validate-spec.sh        # Agent Skills spec validator
  skill-frontmatter.py    # frontmatter parser used by linters
  skill-lib.sh            # shared shell helpers
```

## Releases

Releases use [release-please](https://github.com/googleapis/release-please) in PR mode. Releasable commits merged to `main` open or update a release PR; merging that release PR creates the tag and GitHub Release.

- `feat:` - minor release
- `fix:` - patch release
- `deps:` - patch release
- Any releasable type marked with `!` or containing `BREAKING CHANGE:` - major release
- `docs:`, `chore:`, `ci:`, `test:`, `style:` - no release on their own

If a refactor or perf change should cut a release, use a squash-merge title that reflects the user-facing impact, usually `fix:`.

## Requirements

Any AI coding tool that supports the [Agent Skills standard](https://agentskills.io). See [Supported targets](#supported-targets) for installer path targets. Treat new or less common agents as path-supported until you verify that the tool activates and applies the skills as expected.
