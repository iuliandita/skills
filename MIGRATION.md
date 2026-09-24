# Catalog migration

The collection now has 43 active skills. Nineteen old names remain temporarily as small
deprecation notices. Updated notices explain the replacement or removal; they do not run
the former workflow or silently install another skill.

## Old names and replacements

| Old name | Replacement |
|---|---|
| anti-slop, code-slimming | code-simplification |
| full-review, deep-audit | repo-audit |
| deep-grill, jekyll-hyde | plan-review |
| command-prompt | shell-scripting |
| arch-btw | arch-linux |
| nixos-btw | nixos |
| ai-ml | llm-app-development |
| firewall-appliance | opnsense-pfsense |
| cluster-health | kubernetes-health |
| lockpick | privilege-escalation |
| zero-day | vulnerability-research |
| localize | i18n-localization |
| handoff | session-handoff |
| routine-writer, browse, skill-router | Removed without a replacement skill |

Use the host's browsing, scheduling, and normal skill-selection capabilities for the
removed entries. New specialist entries are `message-queues` and `performance-debugging`.
`databases` now includes Redis/Valkey; `backend-api` includes GraphQL/gRPC.

## Transition window

Notices ship for one transition release and remain for at least seven full days after
that release is published. Remove them in the following release once both conditions
hold. A fast follow-up release must retain them if seven days have not elapsed; the
minimum time takes precedence. The window does not start at merge time.

The release tag and actual publication time are recorded in [migrations.json](migrations.json).
Null values mean the transition release has not been recorded and retirement is blocked.
The manifest and this guide remain after the notices are removed.

An upstream change cannot rewrite an old copied installation. Users must update during
the window to receive the notice, or migrate explicitly afterward. Old tags still contain
the old skills. A direct symlink into a checkout changes when that checkout is updated and
can become dangling after retirement; migrate its target before then.

## Users of npx skills

Use the same global/project scope and agent selection used for the original installation.
Inspect the installed names, back up local customizations outside the skill discovery
root, install replacements, verify they load, then remove the old names. For example:

```bash
npx skills list
npx skills add iuliandita/skills --skill shell-scripting
npx skills remove command-prompt
```

For a many-to-one merge, install the replacement once and remove both old entries. For
removed skills, back up and remove the old entry without installing a replacement.
Check `npx skills --help` for the installed CLI's scope and agent options.

The published skills CLI 1.7.0 was checked for this migration: update does not associate a
changed skill name with its replacement, and noninteractive updates can retain removed
entries. Do not rely on `update` alone to prune old names. Its remove operation does not
provide the bundled installer's backup policy. The two installers' lock files are separate;
do not edit one to impersonate the other. See the [upstream CLI source](https://github.com/vercel-labs/skills/tree/7407f3893ad4dceab546ac002c3ef806e4000c73/src).

skills.sh may list temporary notices and retain historical pages or statistics. This
repository cannot promise redirects, ranking, install-count transfer, or reindexing dates.
Prefer explicit active skill selection over installing the whole transitional catalog.

## Users of the bundled installer

Default installs select active skills; an explicitly named deprecated skill installs its
notice. Normal updates do not remove old names. See `./install.sh --help` for migration
options, then preview migration against the same destinations and copy/link mode used
for the original installation:

```bash
./install.sh --tool codex --migrate
./install.sh --tool codex --migrate --apply
```

The helper only migrates entries with a verified source-content marker. This proves the
recorded content matched the source, including byte-identical directories a normal install
skipped; it does not prove which installer originally created the directory. Older
locks lack that marker and require manual migration: older installers could record a
directory they skipped without installing it. Do not add the marker yourself or force an
update over customizations to bypass this check. The lock's source path must still resolve
to the current checkout's skills directory. A deleted or
moved source checkout requires manual review rather than claiming ownership from a name. It checks
current files against recorded hashes, installs and verifies the replacement first, and
backs up old entries outside discovery before retiring them. Modified skills, protected
overlays, unowned installations, and conflicting replacements require manual review.

Apply stages each missing replacement under `<destination parent>/.skills-migrate-staging/`,
verifies it, and renames it into place only if nothing exists there yet; an entry that appears
in the meantime is reported as a conflicting replacement and left alone. Systems without an
atomic no-replace rename (Linux `renameat2`, macOS `renamex_np`) skip that skill and exit
non-zero instead of risking an overwrite. The lock file is replaced atomically, first to record
the replacements and again after old entries have moved into the backup. An interrupted apply is
finished by running it again: installed replacements are reused, and records of old entries
already moved to the backup are pruned. Apply holds the installer lock itself, even when
`flock` is missing or the helper runs directly, and exits 3 when another run holds it.
A dry run is not a reservation: apply checks the filesystem again. All current and historical
lock hashes cover file bytes but not filenames; a pure filename change can go undetected, so back up
and manually review renamed local files.

Migration honors `SKILLS_BACKUP_DIR`, but the backup location must stay outside source,
skill discovery directories, and the `.skills-migrate-staging` area. `--force` and `--no-backup` are not migration options.

In link mode, replacements are installed in the canonical directory and selected owned
tool links are migrated. Old canonical directories remain because unselected tools may
still link to them. Include all tools you want migrated, then inspect remaining links and
back up/remove old canonical entries manually once nothing needs them. A canonical directory
that a harness discovers directly can still expose those old names until that cleanup.
Copy-mode migration into the shared canonical directory also retains old targets to avoid
breaking other tools' links. Applied OpenCode migrations synchronize replacement permissions
while preserving explicit denials; previews do not change permissions.

## Manual copies, links, and private overlays

Back up the whole old directory and record symlink targets outside all skill discovery
roots. Install the replacement as a separate directory, compare custom changes, verify
activation, then remove the old discoverable entry. Do not merge unrelated directories
or delete a symlink target just because an old skill name points to it.

For `cluster-health`, preserve `protected/` separately and review it before moving it to
`kubernetes-health/protected/`. Both source paths remain ignored. Never publish the overlay
or use a forced install as an overlay migration. Repeat the check for every harness and
for both project-local and global installs.

## Maintainer retirement checklist

1. Publish the transition release with the mapping and migration steps in its notes.
2. Retrieve its actual `published_at` from GitHub, and record that timestamp and tag in
   `migrations.json` through a PR. Do not use the planned publication date.
3. Before the following release, run `./scripts/check-migrations.sh --retire-check`.
   It fails until the recorded timestamp is at least seven days old. Confirm the tag is
   published and contains all notices; the local checker cannot authenticate a release.
4. Remove only the old public notice files through a PR. Preserve ignored private overlays,
   the manifest, this guide, and migration tooling. Update tests and the catalog count.
5. Run all collection and installer checks. Release notes must state that updating upstream
   does not remove stale local copies and link back to this guide.
