# Install & maintain

Full install, update, and structure docs for the skills repo. For a quick start, see the [README](README.md).

## Install

### Quick install via skills.sh

```bash
# Select skills interactively (prefer active names; see MIGRATION.md)
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

# All active skills, Claude (default)
/tmp/skills-install/install.sh

# All active skills, a specific tool
/tmp/skills-install/install.sh --tool codex

# Selected skills
/tmp/skills-install/install.sh --tool claude kubernetes docker terraform ansible

# What's available
/tmp/skills-install/install.sh --list

rm -rf /tmp/skills-install
```

For OpenCode, the installer also updates `~/.config/opencode/opencode.json` so every installed
skill has `permission.skill.<name>: "allow"`. This keeps installs visible when the user's config
uses a deny-by-default policy such as `"permission": { "skill": { "*": "deny" } }`. Existing
explicit `deny` entries are left alone. Each named `allow` entry overrides a wildcard `deny`
for that skill, the same as adding it by hand; remove the entry or set it to `deny` to hide
the skill again. Only skills that installed successfully are added. The file is rewritten
through a temporary file and a rename, following a symlinked config to its target; if the
update fails, the file is left unchanged and the install exits non-zero.

### Multi-tool with symlinks

Install once to a canonical directory, symlink everywhere. Update the canonical copy and every tool sees the change.

```bash
git clone https://github.com/iuliandita/skills.git /tmp/skills-install

# Install for Claude, Cursor, and Gemini in one shot
/tmp/skills-install/install.sh --tool claude,cursor,gemini --link

# Check for updates later
/tmp/skills-install/install.sh --check --link

# Or check one linked tool directory directly
/tmp/skills-install/install.sh --check --tool codex

rm -rf /tmp/skills-install
```

Override the canonical directory with `SKILLS_CANONICAL_DIR`:

```bash
SKILLS_CANONICAL_DIR=~/my-skills ./install.sh --tool claude,roo --link
```

### Local private overlays

Skills declaring `metadata.internal: true` and gitignored locally are skipped by default. Pass `--include-internal` to install them too.

```bash
./install.sh --tool claude,codex,opencode --link --include-internal --force
```

The public `kubernetes-health` skill can also have a local protected overlay at `skills/kubernetes-health/protected/`. That directory is gitignored and must stay untracked. Use it for private lab, homelab, work, or customer cluster aliases, kube contexts, CWD mappings, namespaces, dashboards, runbooks, and local thresholds. You can ask an agent to create or update files there, typically `registry.md`, `private-patterns.txt`, and one `<cluster-or-env>.md` profile per environment.

When present in a local checkout, normal copy installs and `--link` installs copy the overlay into the installed `kubernetes-health` skill. In symlink mode, tool-specific skill directories point at the canonical copy, so Claude, Codex, OpenCode, and other linked tools all see the same protected overlay. Public GitHub installs do not include the overlay because it is not tracked.

Before using `--force`, copy any overlay that exists only in the installed skill back into
`skills/kubernetes-health/protected/` in the source checkout. Forced installs replace the whole
skill directory; they do not preserve or merge installed-only files into the new copy.

`kubernetes-health` is public, so it no longer needs `--include-internal`; that flag is only for separate gitignored skills with `metadata.internal: true`.

`scripts/check-private-skill-leaks.sh` scans public files for private markers, additively drawn from the `protected/private-patterns.txt` overlays above, a gitignored `private-patterns.txt` at the repo root (see `private-patterns.example.txt`), and a file path in `SKILLS_PRIVATE_PATTERNS`. CI never sees your local overlay or root file; it only sees markers you explicitly supply it, typically by writing a repository secret to a file and pointing `SKILLS_PRIVATE_PATTERNS` at it.

Before committing local changes, install the repository hooks with either `prek` or `pre-commit`:

```bash
prek install --hook-type pre-commit --hook-type pre-push
# or:
pre-commit install --hook-type pre-commit --hook-type pre-push
```

The hooks enforce that `skills/kubernetes-health/protected/` remains ignored and untracked, and they scan public files for protected private patterns when the local overlay is present.

They also check freshness markers in public skills. Lines that claim currentness, such as `Target versions`, `Reviewed`, `Updated for`, `verified <month year>`, `recheck`, `snapshot`, or `as of <month year>`, must use the current collection label. Override the expected label during a refresh with `SKILLS_FRESHNESS_LABEL="July 2026" ./scripts/check-freshness-dates.sh`.

### Manual

```bash
cp -r skills/kubernetes ~/.claude/skills/kubernetes
cp -r skills/kubernetes ~/.agents/skills/kubernetes
cp -r skills/kubernetes ~/.cursor/skills/kubernetes
```

## Supported targets

The installer ships paths for 27 targets. All paths are overridable via `--dest` (single-tool mode) or per-tool environment variables (e.g., `CLAUDE_SKILLS_DIR`).

Support in this table means **path support**: the installer knows where to copy or symlink the skill folders for that target. Runtime behavior is owned by the consuming tool. Activation rules, trigger matching, context limits, subagent support, and reference-file loading can differ between agents, even when they all read the same skill directory.

For important workflows, smoke-test the target tool after install:

```bash
# Example: install one skill, then ask the target agent to use it on a small task
./install.sh --tool codex kubernetes
```

| Tool | Flag | Default path |
|------|------|-------------|
| Claude Code | `claude` | `~/.claude/skills` |
| OpenAI Codex | `codex` | `~/.agents/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| Windsurf | `windsurf` | `~/.codeium/windsurf/skills` |
| OpenCode | `opencode` | `~/.agents/skills` |
| Command Code | `commandcode` | `~/.agents/skills` |
| GitHub Copilot | `copilot` | `~/.copilot/skills` |
| Gemini CLI (legacy; consumer accounts moved to Antigravity) | `gemini` | `~/.agents/skills` |
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
| Google Antigravity | `antigravity` (alias `agy`) | `~/.gemini/config/skills` |
| Augment | `augment` | `~/.augment/skills` |
| OpenHands | `openhands` | `~/.openhands/skills` |
| Trae | `trae` | `~/.trae/skills` |
| Qoder | `qoder` | `~/.qoder/skills` |
| Kimi Code CLI | `kimi` | `~/.agents/skills` |
| Oh My Pi | `omp` | `~/.agents/skills` |
| Portable | `portable` | `~/.skills` |

`OMP_SKILLS_DIR` only controls where the installer writes for `omp`; Oh My Pi itself
natively discovers `~/.agents/skills` (and also `~/.omp/agent/skills`) without reading
that variable.

### One copy per harness

Codex, Command Code, OpenCode, and Oh My Pi all read `~/.agents/skills` on their own, so the
installer puts their skills there and nowhere else. Installing into a second directory the
same harness also reads made every skill show up twice (Command Code reports each one as
shadowed). Older releases installed Codex into `~/.codex/skills`, Command Code into
`~/.commandcode/skills`, and OpenCode into `~/.config/opencode/skills`. Codex versions that
still read `~/.codex/skills` can keep that path with `CODEX_SKILLS_DIR=~/.codex/skills`.

OpenCode also reads `~/.claude/skills`, so a Claude install is visible to OpenCode as well.
OpenCode keeps one skill per name across `~/.claude/skills` and `~/.agents/skills`, so that
overlap is harmless.

To clean up after an older release, install first, then preview and apply the cleanup:

```bash
./install.sh --tool commandcode --link          # installs into ~/.agents/skills, hints at old links
./install.sh --tool commandcode --migrate        # preview only; changes nothing
./install.sh --tool commandcode --migrate --apply
```

The cleanup does not install anything. In the old directory it unlinks only entries that are
symlinks recorded in that directory's `.skills-lock.json` from this checkout, point at the
canonical copy of the same skill, and already have a replacement in `~/.agents/skills` that
resolves to that same copy. Real directories, broken or foreign links, and unrecorded names
stay and are reported. Before unlinking, it saves the links and the old lock under
`<old-dir-parent>/.skills-backups/<old-dir-name>/.legacy-dir-cleanup/` (or `SKILLS_BACKUP_DIR`);
if the backup fails, nothing is removed. The old lock is deleted once none of its entries remain.
The cleanup is skipped with `--dest` or when the tool's `*_SKILLS_DIR` override is set.

`--doctor` reports skill names a harness can reach through more than one directory. It checks
a static table of the global directories each harness reads, not the harness's own config
toggles, and changes nothing. It exits 1 on duplicates the harness does not resolve itself.

Blocking duplicates come first, one `[!]` line per skill. When a skill's directory name and
frontmatter name match across the same paths, it gets one line; otherwise the `dir` and `name`
findings stay separate and labeled. Overlaps the harness resolves itself are counted in one
`[i]` line per set of directories; add `--verbose` to list them.

```bash
./install.sh --doctor                            # all tools in the table
./install.sh --doctor --tool commandcode,opencode
./install.sh --doctor --verbose --tool opencode  # also list harness-resolved overlaps
```

Common aliases also work: `claude-code`, `openai-codex`, `github-copilot`, `gemini-cli`, `kiro-cli`, `qwen-code`, `kimi-cli`, `agy` (Antigravity CLI), `command-code`, `cmdc` (Command Code), and `oh-my-pi` (Oh My Pi).

For a target or project directory outside this table, use `--tool portable --dest /path/to/skills`.
Verify that the consuming tool discovers skills at that destination.

## Updating

Pull the latest and re-run the installer with the same tool selection, skill selection,
destination overrides, and copy or `--link` mode used for the original install:

```bash
cd /path/to/skills
git pull --ff-only
./install.sh --tool codex --force kubernetes docker
```

Or check what changed first:

```bash
./install.sh --check --link
./install.sh --tool claude,cursor,gemini --link --force
```

The first example updates two copied skills for Codex; the second checks and updates all
skills in the canonical directory and maintains links for the selected tools. Omitting skill
names installs all active skills. Explicit old names install deprecation notices. Omitting `--tool` uses `SKILLS_TOOL`, or Claude if unset.

The installer backs up existing skills before overwriting unless `--no-backup` is set.
It retains the last three backups per skill under
`<destination-parent>/.skills-backups/<destination-name>/`, outside the skill discovery root.
Override that backup base with `SKILLS_BACKUP_DIR`. Backups support manual recovery;
customizations are not merged into the replacement. Preserve edits in the source checkout
before reinstalling if they must remain active.

Each replacement is staged first and swapped in by rename, with a record under
`<destination-parent>/.skills-txn/<destination-name>/<skill>/`. If any step fails, the
installer puts the previous copy back, leaves that skill's lock entry unchanged, and exits
non-zero. If the run is interrupted or the previous copy cannot be put back, the record, the
previous copy, and the staged copy stay there; the next install run restores the previous
copy and removes the staged one before doing anything else in that destination. When that
recovery fails, the installer skips the rest of that destination, keeps the evidence, and
continues with other destinations. A record is removed once the skill's lock entry is
written, so an install that stopped before writing the lock is reconciled by the next run.

If a source checkout moved or an existing lock is incompatible, a normal install saves
that lock under the backup base's `.unverified-locks/` directory and starts a fresh lock.
It records only selected entries whose content matches the new source; it does not adopt
unselected entries from the old lock. Review the saved lock for any remaining manual updates.

## Renamed and removed skills

See [MIGRATION.md](MIGRATION.md) for the complete mapping, temporary deprecation notices,
copy/link migration, npx instructions, and private-overlay preservation. Normal updates
do not prune old names. Preview `./install.sh --tool codex --migrate`, then use `--apply`
only after reviewing the proposed changes. The helper verifies installer ownership and
current file-content hashes; detected modifications and ambiguous entries stay untouched
for manual review. Current and historical hashes do not detect pure filename changes. Link migration
retains old canonical targets until remaining links have been reviewed and cleaned up.

## Checking for updates

Each install writes a `.skills-lock.json` with content hashes. In `--link` mode, the installer
writes the lock file to both the canonical directory and each selected tool directory, so either
canonical or tool-specific checks work after install. `--check` compares current source hashes
with the hashes recorded in that lock file. It does not hash the installed files again, so it
does not detect edits or deletions made there after installation. It checks all discoverable
active source skills, even when skill names are passed, and separately reports legacy
names recorded in the lock. It exits with status 1 if an active skill is outdated or absent, or a legacy
entry remains. Deprecated notices are excluded from active update checks. With `--link`,
only the canonical lock is checked; tool-directory
links are not verified. Check a tool's lock separately without `--link`, which checks only
the first selected tool.

```bash
./install.sh --check                  # check default (Claude)
./install.sh --check --tool cursor    # check a specific tool
./install.sh --check --link           # check canonical dir
```

## Skill anatomy

Each skill follows the [Agent Skills specification](https://agentskills.io/specification):

- **`SKILL.md` with YAML frontmatter** - `name`, `description`, `license`, optional `compatibility` for environment requirements, and `metadata` for custom fields. The frontmatter is what agents read at startup to decide which skills to activate.
- **Compact body** - the core instructions loaded when the skill is activated. Prefer 150-250 lines where practical, 600 hard max. Kept lean so it doesn't eat the context window.
- **Reference files** in `references/` - detailed pattern libraries, compliance checklists, manifest templates. The agent reads these on-demand when the task requires depth. Expert-level detail without paying the token cost upfront.
- **Argument hints** (`metadata.argument_hint`) - tells agents what arguments a skill expects (e.g., `<file-or-pattern>`, `[iterations]`). Angle brackets for required, square brackets for optional.
- **Precise trigger descriptions** - usually 80-120 characters, with the task and distinctive terms first. The warning above 120 is advisory; hosts can still shorten entries to fit a shared catalog budget.
- **Cross-skill awareness** - skills know about each other. Routing hints (`Not for X (use Y)`) prevent collisions. The security-audit skill defers to privilege-escalation on offensive work; docker defers to kubernetes on cluster networking.

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
install.sh                # installer (27 targets, symlink mode, lock file)
scripts/
  lint-skills.sh          # collection linter
  validate-spec.sh        # Agent Skills spec validator
  test-install.sh         # installer regression tests
  check-*.sh              # repository-specific safety and freshness checks
  skill-frontmatter.py    # frontmatter parser used by linters
  skill-lib.sh            # shared shell helpers
.refiner-runs.json        # skill-refiner run history (repo root, single file)
.refiner-ledger.md        # skill-refiner score ledger
```

`.refiner-runs.json` and `.refiner-ledger.md` live at the repository root and nowhere
else. `scripts/check-refiner-state.sh` fails the build if a second run-history file
appears under `skills/`, which is how the log silently split before.

## Releases

Releases are cut manually from `main`. Version bump follows the squash-merge titles since the
last tag:

- `feat:` - minor release
- `fix:` - patch release
- `deps:` - patch release
- Any releasable type marked with `!` or containing `BREAKING CHANGE:` - major release
- `docs:`, `chore:`, `ci:`, `test:`, `style:` - no release on their own

If a refactor or perf change should cut a release, use a squash-merge title that reflects the
user-facing impact, usually `fix:`.

For the catalog transition, follow the [publication and retirement checklist](MIGRATION.md#maintainer-retirement-checklist). Record the actual publication timestamp after publishing; notices cannot be retired before seven full days have elapsed.

Release steps (start with a clean checkout and update `main` with `git pull --ff-only`):

1. Create a release preparation branch from `main`, such as `release/X.Y.Z`.
   Prepend a `## [X.Y.Z](https://github.com/iuliandita/skills/compare/vPREV...vX.Y.Z) (YYYY-MM-DD)`
   section to `CHANGELOG.md` listing the releasable squash commits since `vPREV`, grouped under
   `### Features`, `### Bug Fixes`, `### Refactoring`, `### Performance Improvements`, and
   `### Dependencies` as applicable.
2. Commit the changelog on that branch with `chore(main): release X.Y.Z`, push the branch,
   and open a PR targeting `main`. Require green CI and squash merge the PR.
3. Switch to `main`, run `git pull --ff-only`, and verify that `HEAD` is the merged release
   preparation commit and that its checks passed. If `main` advanced, reconcile the notes
   through another PR before tagging. Do not commit or push directly to `main`.
4. Save the merged changelog section to a notes file outside the checkout, such as
   `/tmp/skills-release-notes.md`. Review it against the commits since `vPREV`.
5. Tag the verified commit with `git tag -a vX.Y.Z -m "vX.Y.Z"`, then push only that tag with
   `git push origin vX.Y.Z`.
6. Publish with `gh release create vX.Y.Z --verify-tag --title "vX.Y.Z" --notes-file /tmp/skills-release-notes.md`.

## Requirements

Any AI coding tool that supports the [Agent Skills standard](https://agentskills.io). See [Supported targets](#supported-targets) for installer path targets. Treat new or less common agents as path-supported until you verify that the tool activates and applies the skills as expected.
