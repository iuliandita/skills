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

## Detect and save a setup

`--detect` lists harnesses that look installed. It is read-only, runs nothing it finds,
and ignores the saved config, skill metadata, and migrations:

```bash
./install.sh --detect
```

Output is one line per supported tool, tab-separated, then a suggestion:

```text
candidate	claude	binary:/home/me/.local/bin/claude;config:/home/me/.claude/settings.json
nomarker	cursor
suggested: claude
```

- `candidate<TAB><tool><TAB><evidence>`: at least one marker was found. Evidence items are
  `binary:<path>` (first executable regular file of that name on `PATH`) or
  `config:<path>`, joined by `;`. Backslash, tab, newline, `;`, other control characters,
  and undecodable bytes are written as `\\`, `\t`, `\n`, `\x3b`, and `\xNN`.
- `nomarker<TAB><tool>`: the installer knows no marker it trusts for this tool. Supported
  tools whose markers are all absent print nothing.
- `suggested: a,b` or `suggested: none`: the candidates, ready for `--tool`.

A candidate is a hint, not proof: check it before installing. Only harness-owned markers
count. Skill directories and shared roots such as `~/.agents/skills` never do, and bare
`cmd` is ignored because the name is too generic. Notes about skipped `PATH` entries go to
stderr. `--detect` exits 0 and rejects every other option and skill name.

| Tool | Binary on `PATH` | Config file under `~` |
|------|------------------|-----------------------|
| claude | `claude` | `.claude/settings.json` |
| codex | `codex` | `.codex/config.toml` |
| opencode | `opencode` | `.config/opencode/opencode.json` |
| commandcode | `commandcode` | `.commandcode/settings.json` |
| gemini | `gemini` | `.gemini/settings.json` |
| antigravity | `agy` | `.gemini/antigravity-cli/settings.json` |
| hermes | `hermes` | `.hermes/config.yaml` |
| kimi | `kimi` | none |
| omp | `omp` | `.omp/agent/config.yml` |

`--save` runs a normal install and, only if it succeeds, records the selection:

```bash
./install.sh --save --tool claude,codex --link
./install.sh            # later: repeats the saved selection
```

A bare `./install.sh` with no arguments at all uses the saved config and prints its path
first. Any argument, including `--force` alone, ignores the saved config completely; there is
no merging. `--check`, `--list`, `--migrate`, `--doctor`, and `--detect` never read it.
Without a saved config, a bare run keeps its old default (all skills for `SKILLS_TOOL`, or
Claude).

`--save` covers default paths only. It is refused with `--dest` (exit 1) and when any of
`*_SKILLS_DIR`, `SKILLS_CANONICAL_DIR`, `SKILLS_BACKUP_DIR`, `OPENCODE_CONFIG_FILE`, or
`SKILLS_TOOL` is set (exit 2). A bare run that finds a saved config also exits 2 while any
of those variables is set. `--save` requires `flock` and takes the installer lock before it
touches the config, holding it through the install and the save.

The config is `${XDG_CONFIG_HOME:-~/.config}/iuliandita-skills/install.conf`, directory mode
700, file mode 600. The directory is opened without following a symlink and checked
through that descriptor; the temporary file, its permissions, and the rename into place all
go through the same descriptor. If the path is swapped for another directory meanwhile, the
save exits 2 and nothing is written outside the checked directory:

```text
# Written by install.sh --save. Plain key=value; see INSTALL.md.
version=1
tools=codex,claude
link=true
include_internal=false
skills=all
source_repo=/home/me/src/skills
source_branch=main
source_remote=origin
source_remote_url=git@github.com:iuliandita/skills.git
source_upstream=refs/heads/main
```

`tools` holds canonical tool names; `skills` is `all` or a comma list. The `source_*` keys
identify the checkout that ran `--save`. A checkout without an upstream branch saves the
upstream keys empty and prints a note; a later `--update` refuses to run from such a config.
A bare run from a different checkout prints a note and installs from the checkout it runs in.

The file is parsed, never sourced. Each line is `key=value`, split at the first `=`; lines
starting with `#` and blank lines are skipped. All ten keys are required, unknown or repeated
keys are errors, `link` and `include_internal` must be exactly `true` or `false`, tool names
must be supported tools or aliases, and control characters are rejected anywhere. The file
must be a regular file, not a symlink, and it and its directory must be owned by you and not
group- or world-writable.

| Exit | Meaning |
|------|---------|
| 0 | Success |
| 1 | Install failed (nothing saved), an invalid option combination, or an empty `--tool` or `--dest` value |
| 2 | Saved config invalid or unsafe, or an override variable is set |
| 3 | Another installer run holds the lock |
| 7 | The config directory or file cannot be created or opened |
| 10 | `flock` is missing (`--save` only) |

## Scheduled updates

`--update` keeps a saved setup current without supervision. Save once from a checkout whose
branch tracks a remote, then schedule the update:

```bash
./install.sh --save --tool claude,codex --link
./install.sh --update
```

`--update` takes no other options or skill names. It needs `git`, `flock`, `timeout`, and
`python3`. Each run:

1. Takes the installer lock without waiting, before it reads the saved config or touches
   the checkout. Another run holding it means exit 3; set `SKILLS_LOCK_WAIT` to wait that
   many seconds instead.
2. Loads the saved config under the same rules as a bare install. A missing or invalid
   config, or any override variable (`*_SKILLS_DIR`, `SKILLS_CANONICAL_DIR`,
   `SKILLS_BACKUP_DIR`, `OPENCODE_CONFIG_FILE`, `SKILLS_TOOL`), means exit 2.
3. Checks the source: the checkout is the saved `source_repo`, it is on the saved branch,
   the branch's remote, that remote's URL, and the upstream ref match the saved values, and
   `git status --porcelain` is empty (untracked files count).
4. Fetches the saved upstream ref under `timeout -k 10 ${SKILLS_UPDATE_TIMEOUT:-300}`, with
   hooks disabled, and pins the result to a commit SHA. HEAD must be an ancestor of that
   commit; local commits or a rewritten upstream mean exit 4.
5. Fast-forwards with `git merge --ff-only <sha>` (hooks disabled) and checks HEAD is that
   SHA. If the fast-forward fails partway and leaves the working tree changed, the run exits
   1 instead of 5; restore the checkout to HEAD before the next run.
6. Replaces itself with the checkout's own, now updated `install.sh`, which inherits the
   lock and applies the saved selection. New installer code therefore runs in the same
   locked run that fetched it.

The apply step never overwrites something it cannot prove it installed. For each selected
skill in each destination it compares tree digests, which cover file names, types, the
owner exec bit, contents, and symlink targets:

- missing: installed.
- equal to the source: current; its lock entry is refreshed if needed.
- equal to the digest in its lock entry, or to the copy an earlier interrupted run was
  installing: replaced, with a backup and the same staged, recoverable replacement as a
  normal install.
- anything else: skipped and reported, and the run exits 6. That covers local edits, an
  entry with no lock record, and entries recorded before tree digests existed that differ
  from the source; the message names the `install.sh --force` command that reconciles one.
  An older entry that already matches the source is upgraded silently.

In `--link` mode the canonical copies are handled that way; tool directories only get
missing links created, and anything other than a link to the canonical copy is skipped.
Skills added upstream are installed when the saved selection is `all`. OpenCode permissions
are synced for the installed skills exactly as a manual install does, so a new skill gets a
named `allow` entry that overrides a wildcard `deny`. Migrations are never applied; the
usual `--migrate` hint is printed when old links remain.

Progress goes to stdout as timestamped lines, errors to stderr. The last stdout line of a
completed run is one of:

```text
update: ok current
update: ok 1a2b3c4d5e6f..7a8b9c0d1e2f changed=3 skipped=0
update: partial 1a2b3c4d5e6f..7a8b9c0d1e2f changed=2 skipped=1
```

| Exit | Meaning |
|------|---------|
| 0 | Everything selected is current |
| 1 | HEAD moved but the install did not finish; the message names the HEAD commit, and a rerun completes it |
| 2 | No saved config, an invalid one, an override variable, a bad `SKILLS_UPDATE_TIMEOUT` or `SKILLS_LOCK_WAIT`, or extra options |
| 3 | Another installer run holds the lock |
| 4 | Source check failed: other checkout, branch, remote, URL, or upstream; detached HEAD; no saved upstream; uncommitted or untracked changes; local commits or divergence |
| 5 | Fetch failed or timed out, or the fast-forward failed |
| 6 | Finished, but some skills were skipped (see above) |
| 7 | The lock or config directory cannot be created or opened |
| 8 | The updated installer could not be started; HEAD is at the new commit, rerun |
| 10 | `flock`, `timeout`, `git`, or `python3` is missing |
| 130, 143 | Interrupted by SIGINT or SIGTERM |

Exits 2, 3, 4, 5, 7, and 10 leave HEAD, the index, and the working tree unchanged (a fetch may
still update remote-tracking refs). After HEAD moves there is no such guarantee; rerun
`--update` and it picks up where the last run stopped.

### Unattended authentication

Updates run with `GIT_TERMINAL_PROMPT=0`, `GIT_ASKPASS` and `SSH_ASKPASS` set to `false`,
and `SSH_ASKPASS_REQUIRE=never`, so a credential prompt fails the fetch (exit 5) instead of
hanging. Unless `GIT_SSH_COMMAND`, `GIT_SSH`, or `core.sshCommand` is set, ssh runs as
`ssh -o BatchMode=yes`; a command you set is used as is and must not prompt. Supported:

- SSH with a running agent (export `SSH_AUTH_SOCK` in the job) or a key without a
  passphrase.
- HTTPS with a credential helper that answers without prompting, such as `store`, or
  `libsecret` with an unlocked keyring. A public HTTPS remote needs no credentials.

### Threat model

The checkout, the saved config, and the state directory belong to your user; any process
running as you can already run code as you, so other same-user writers are trusted. The
update source is the remote URL and branch recorded by `--save`: enabling `--update`
authorizes running whatever future commits that branch receives, because each run executes
the fetched `install.sh`. Editing the checkout while an update runs is unsupported.

Runs exclude each other only when every participating run has `flock`. `--update` and
`--save` require it; ordinary installs warn and proceed without it.

### Scheduling

Use absolute paths, an explicit `PATH`, and a log file. Cron and systemd do not read your
shell profile: if you set `XDG_CONFIG_HOME` or `XDG_STATE_HOME` there, set the same values
in the job, or it will not find the saved config (exit 2) and will lock a different file
than your manual installs. Crontab (`crontab -e`):

```cron
PATH=/usr/local/bin:/usr/bin:/bin
17 4 * * * /home/me/src/skills/install.sh --update >>/home/me/.local/state/iuliandita-skills/update.log 2>&1
```

systemd user units, `~/.config/systemd/user/skills-update.service`:

```ini
[Unit]
Description=Update agent skills

[Service]
Type=oneshot
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/home/me/src/skills/install.sh --update
```

and `~/.config/systemd/user/skills-update.timer`:

```ini
[Unit]
Description=Update agent skills daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

Enable it with `systemctl --user enable --now skills-update.timer`; the journal keeps the
output (`journalctl --user -u skills-update`). For an SSH remote with an agent, also pass
the agent socket, for example `Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket`.

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
non-zero. If the run is interrupted, or a step after the swap fails, the record, the
previous copy, and the staged copy stay there. The next install run settles them before
doing anything else in that destination: it keeps a swapped-in copy only if it matches the
digest recorded before the swap, and otherwise puts the previous copy back. When that fails,
the installer skips the rest of that destination, keeps the evidence, and continues with
other destinations. A record is removed once the skill's lock entry is written, so an
install that stopped before writing the lock is reconciled by the next run. A failed retry
keeps the earlier record.

Moves are renames only. A destination that is itself a mount point, so its `.skills-txn`
area would be on another filesystem, is refused with an error instead of being copied into.

These guarantees cover installs done by `install.sh`. `--migrate --apply` runs the same
recovery first and refuses a destination while recovery fails or a skill it would touch
still has an install record; reinstall that skill with `--force` to clear it. The migration
helper's own copy of a replacement skill is not staged.

Runs that change files (installs, `--update`, and `--migrate --apply`) take an exclusive lock on
`${XDG_STATE_HOME:-~/.local/state}/iuliandita-skills/install.lock` with `flock`, waiting up
to `SKILLS_LOCK_WAIT` seconds (default 30, or 0 for `--update`) and exiting with status 3 if another run still
holds it. Without `flock` the installer prints a warning and proceeds; runs exclude each
other only when every one of them has `flock`.

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

Next to those content hashes, the lock keeps a `trees` map with a version 2 tree digest per
skill (`hash_version: 2`), which also covers file names, exec bits, and symlink targets.
`--update` uses it to tell its own installs from local edits; `--check` and `--migrate` keep
using the content hashes.

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
