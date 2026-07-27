# DSM Footguns and Diagnostic Hygiene

Read before any repair attempt or any change to a production unit. Most entries here come from a
real recovery; the rest are DSM behaviors that reliably mislead.

## Never do these on a damaged Synology btrfs volume

- **`btrfs check --repair --init-extent-tree`.** Observed: completes a full scan, then writes a
  zero-entry node into the **chunk tree**, hits `BUG_ON` in `btrfs_try_chunk_alloc`, and leaves
  the filesystem permanently unmountable (`open_ctree failed`). This destroys the volume.
- **`mount -o clear_cache`, unconditionally.** Establishing that the free space tree is not the
  damaged structure is exactly what a damaged filesystem prevents. Clearing the tree
  requires freeing its own blocks, which requires the damaged block. The transaction aborts
  *during mount*, after which the filesystem fails `open_ctree` entirely. Strictly worse than
  before.
- **Any repair at all without a dm-snapshot overlay in place.**
- **`mdadm --assemble --force` or `--create` as an opening move.** Event counts diverge on a
  broken array; force-assembly picks a generation silently, and `--create` overwrites superblocks.

## The circularity, stated once

Every "remove the damaged derived tree" operation must **free the blocks that tree occupies**,
and freeing extents requires reading extent-tree and free-space metadata. If the damage sits in
that path, every removal route fails through the damage.

Approaches that *ignore* the damaged structure - feature bits, mount options, skip flags - can
succeed where approaches that *remove* it cannot. Reach for the ignoring lever first.

## Diagnostic hygiene

- **When a diagnostic returns nothing, suspect the diagnostic first.** Empty output on a system
  you know is broken is a broken check far more often than a clean result.
- **`dmesg` ring buffers wrap.** A flood of one message hides everything else. Diff full
  snapshots rather than tracking line offsets.
- **Grepping one error pattern that has stopped does not mean the problem stopped.** Grep the
  actual failing message, not the one you first noticed.
- **A cascade of identical errors is usually one root cause plus N consequences.** Find the first
  occurrence and read what preceded it.
- **A survey without an inode-reading predicate reports a corrupt filesystem as clean.**
  `find <dir>` does readdir only and reads no inodes, and `find <dir> -type f` does not help -
  `-type` is answered from `readdir`'s `d_type` with no `stat`. Use `-size +0` or
  `-printf '%s\n'`. That mistake produced a false "0.00% damaged" result across 44 TB.
- **DSM's health banners are derived state.** Verify the mount, the array, and the filesystem
  directly rather than trusting the UI's summary.
- **Distinguish "unreachable" from "not present".** A permission error, a stopped service, and a
  missing resource all look alike if stderr is discarded. Never `2>/dev/null` a diagnostic whose
  failure reason matters.

## Shell traps on DSM

- `/bin/sh` is ash. No process substitution `<(...)`, no bash arrays, no `[[ ]]` in scripts DSM
  invokes.
- `sh -euxc '...'` is terminated by any apostrophe inside it, including one in an English
  comment. Match text with a regex (`Shouldn.t`) or avoid the word.
- Redirections in `sudo cmd 2>file` are performed by the *calling* shell, so a root-owned
  leftover file makes the whole command fail before `sudo` even runs. Wrap it: `sudo sh -c '...'`.
- `grep -c pattern file || echo 0` emits `0` twice when there are no matches.
- `/tmp` is `noexec`. A copied binary fails with "Permission denied" that looks like an
  ownership problem.
- `scp` without `-O` fails with `subsystem request failed` because the sftp subsystem is disabled.
- Never `pkill -f <pattern>` where the pattern appears in your own command line. Put the logic in
  a script file so the pattern is not in a live cmdline.
- SSH sessions land in `/volume1/homes/<user>`, so `umount /volume1` reports "target is busy"
  against your own shell. `cd /` first.

## Behavior of a damaged volume

- **`remount,rw` is refused once btrfs has forced read-only.** A full unmount and fresh mount is
  required, which means stopping packages and services.
- **btrfs forcing read-only is protective**, not additional damage. Treat it as the filesystem
  doing its job.
- **Ordinary create/fsync/delete and idle time are safe** even with `auto_reclaim_space` enabled;
  only touching the damaged inodes aborts. Verify such hypotheses before recommending them -
  `auto_reclaim_space` was a plausible culprit in the source recovery and was innocent.
- **Stock-tool corruption reports are not evidence.** Mainline's tree-checker rejects Synology's
  private root flags, and mainline `check` complains about private trees 202/203/205/206, which
  hold reconstructible derived data. Both are expected noise on a healthy Synology volume.

## DSM behaviors that mislead

- **`/etc/fstab` is regenerated at boot.** Hand-edited mount options vanish silently.
- **`syno_poweroff_task` exists on DSM 6 but not DSM 7.1+.** Scripts and forum posts that use it
  fail confusingly on modern DSM.
- **Package dependencies resurrect disabled packages.** `grep -h install_dep_packages
  /var/packages/*/INFO` before assuming a `synopkg disable` held.
- **DSM 7 disallows direct root SSH.** Guides written for DSM 6 fail at the first step; use
  `sudo -i`.
- **Home directories live on the data volume.** When `/volume1` is down, key-based SSH auth
  breaks because `authorized_keys` is unreadable. Have a password-capable admin account and, on
  a unit you may need to recover, console or serial access.
- **DSM's firewall and network config are owned by DSM.** Direct iptables edits do not persist.
- **`btrfs check --repair` prompts for confirmation and blocks forever with no stdin.** It looks
  like a hang. Pipe `yes` into it if you have already decided to run it.

## Remote work discipline

- Detach anything long-running: `setsid nohup <cmd> > log 2>&1 < /dev/null &`. An SSH drop kills
  an attached job, and a 40-minute repair interrupted halfway is worse than one not started.
- Take the origin fingerprint before starting and re-verify it after (see the overlay procedure
  in `btrfs-recovery.md`). It is the only proof the origin was untouched.
- Log to a file on persistent storage, not to the terminal. The terminal is the least durable
  place the output can live.
