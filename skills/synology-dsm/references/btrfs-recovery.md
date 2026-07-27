# Synology btrfs: Divergences and Recovery

Everything here was verified on hardware during a real recovery (DS415+, DSM 7.1.1-42962,
avoton platform, btrfs on mdraid5). Where something is inferred rather than observed, it says so.
Kernel line references are to Synology's published GPL source for that build.

Read this when a Synology volume will not mount, has gone read-only, or when stock btrfs tools
report corruption on a volume that otherwise behaves.

**Build sensitivity.** The mechanisms here (usrquota walking every subvolume, private trees being
derived data, mainline's tree-checker rejecting private flags) hold across Synology builds. The
exact numbers do not necessarily: flag bit positions, tree objectids, the set of accepted mount
options, and the userspace `btrfs` version were read from one build's GPL source
(DSM 7.1.1-42962, avoton, 3.10 kernel). Newer platforms ship a 4.4 kernel line. Before acting on
a specific constant, confirm it in the GPL source for the target build (section 8) - that is
cheap and it is the whole reason to download the source.

## Contents

1. Why stock tools lie
2. Private root flags
3. Private trees
4. Private mount options
5. The usrquota mount trap
6. Free space tree
7. Superblock
8. GPL source: the highest-value move
9. The dm-snapshot overlay
10. Mount escalation ladder
11. Tool matrix and patched builds
12. btrfs-progs bugs on damaged filesystems
13. Setting Synology subvolume flags from userspace
14. Damage surveying

---

## 1. Why stock tools lie

Synology's on-disk format is **newer than their own userspace tools** and diverges from
mainline's version of the same features. That single sentence explains nearly every tool failure:

- DSM's `/sbin/btrfs` (v4.0 on DSM 7.1) refuses to open the filesystem read-write:
  `unsupported option features (3)`
- Mainline btrfs-progs opens it read-write but its tree-checker rejects Synology's private root
  flags as corruption, so a healthy volume is reported as damaged

Neither verdict is trustworthy on its own. Confirm against the DSM kernel's own behavior.

## 2. Private root flags (`btrfs_root_item.flags`)

```
BTRFS_ROOT_SUBVOL_RDONLY            (1ULL << 0)
BTRFS_ROOT_SUBVOL_HIDE              (1ULL << 32)   0x100000000
BTRFS_ROOT_SUBVOL_NOLOAD_USRQUOTA   (1ULL << 33)   0x200000000
BTRFS_ROOT_SUBVOL_CMPR_RATIO        (1ULL << 34)   0x400000000
BTRFS_ROOT_SUBVOL_DISABLE_QUOTA     (1ULL << 35)   0x800000000
BTRFS_ROOT_SUBVOL_DEAD              (1ULL << 48)
```

Mainline's tree-checker (Linux 5.4+ and matching btrfs-progs) rejects these as corruption. A
volume carrying them is reported as damaged by stock tools even when perfectly healthy.

Patch for offline tools:

```c
// kernel-shared/tree-checker.c
const u64 valid_root_flags = ... | BTRFS_ROOT_SUBVOL_DEAD | 0xFFFFFFF00000000ULL;
```

Userspace-visible equivalents live in `include/uapi/linux/btrfs.h` at the same bit positions:
`BTRFS_SUBVOL_HIDE`, `BTRFS_SUBVOL_NOLOAD_USRQUOTA`, `BTRFS_SUBVOL_CMPR_RATIO`,
`BTRFS_SUBVOL_DISABLE_QUOTA`.

## 3. Private trees

```
 200  BTRFS_USRQUOTA_TREE_OBJECTID
 201  BTRFS_QUOTA_TREE_OBJECTID
 202  BTRFS_BLOCK_GROUP_HINT_TREE_OBJECTID
 203  BTRFS_BLOCK_GROUP_CACHE_TREE_OBJECTID
 205  BTRFS_SYNO_USAGE_TREE_OBJECTID
 206  BTRFS_SYNO_EXTENT_USAGE_TREE_OBJECTID
-206  BTRFS_SYNO_SUBVOL_USAGE_OBJECTID
key type 165 = SYNO_BTRFS_EXTENT_USAGE_KEY
```

**202, 203, 205, and 206 hold derived data** - caches and usage accounting, all reconstructible.
Damage there is not authoritative data loss. Mainline tools emit
`Invalid key type(BLOCK_GROUP_ITEM) found in root(203)` and `ignoring invalid key`; that is
correct, harmless behavior, not a symptom of the real problem.

A broken tree 203 is explicitly non-fatal at mount (`disk-io.c`):

```c
ret = btrfs_check_syno_block_group_cache_tree(fs_info);
if (ret) { fs_info->block_group_cache_tree_broken = 1; WARN_ON_ONCE(1); }
```

## 4. Private mount options (`fs/btrfs/super.c`)

```
no_quota_tree                    forces quota_root/usrquota_root to -ENOENT
block_group_cache_tree
clear_block_group_cache_tree
no_block_group_hint
syno_allocator / clear_syno_allocator
synoacl, synoumounthang=%d
```

`no_quota_tree` cannot be applied on remount, only on a fresh mount.

**`no_quota_tree` is the single most useful recovery option on Synology btrfs.** See section 5
for why.

## 5. The usrquota mount trap

`usrquota_subtree_load_one()` in `fs/btrfs/usrquota.c` walks **every** subvolume at `open_ctree`
time to build accounting. For each subvolume it enumerates `ROOT_REF` children and calls
`btrfs_read_fs_root_no_name()` on each.

If **any single subvolume root node is unreadable**, that call fails, the error propagates, and
`open_ctree` fails. **The entire filesystem becomes unmountable because of one damaged
subvolume.** The kernel tries to degrade (`usrquota disabled due to faield to load tree` - the
typo is upstream) but still fails the mount.

The control flow detail that matters: the per-subvolume skip flag is checked when a subvolume is
*dequeued*:

```c
update_queue:
    if (btrfs_root_noload_usrquota(subvol_root))
        goto out;
```

but a child's root is read inside the **parent's** enumeration loop, before anything checks the
child's flags. Therefore:

- Setting `NOLOAD_USRQUOTA` on the damaged subvolume does **not** help
- Setting it on the **parent** does, because the parent returns before enumerating children

On DSM the top-level container is subvolume **256** (`@syno`), and DSM mounts it as the volume
root. So `/volume1` is subvolume 256's root and is a valid target for the ioctl in section 13.

Cost: usrquota accounting is disabled for everything beneath, so per-share quotas and DSM usage
reporting stop working. Reversible.

## 6. Free space tree

`compat_ro_flags` bit 0 = `FREE_SPACE_TREE`, bit 1 = `FREE_SPACE_TREE_VALID`, so a normal
Synology volume shows `0x3`.

Mount-time behavior:

```c
if (CLEAR_CACHE && compat_ro(FREE_SPACE_TREE))        clear_free_space_tree = 1;
else if (compat_ro(FREE_SPACE_TREE) && !compat_ro(FREE_SPACE_TREE_VALID)) {
    btrfs_warn("free space tree is invalid");         clear_free_space_tree = 1;
}
```

Note the second branch: the kernel self-heals an *invalid* free space tree with no mount option
at all. If `FREE_SPACE_TREE_VALID` is set, it trusts the tree.

**Clearing the valid bit is not a safe alternative to `clear_cache`.** Both branches set the same
`clear_free_space_tree = 1` and converge on one call to `btrfs_clear_free_space_tree()`, so
clearing the bit reaches the exact code path that hard refusal 2 bans, with the same failure mode
(freeing the tree's own blocks through the damage). Treat it as covered by that refusal. The
useful part of this section is diagnostic: `compat_ro_flags` tells you whether the kernel already
considers the tree invalid and is trying to rebuild it on its own.

## 7. Superblock

Standard btrfs layout. Field offsets used in practice:

```
0    csum[32]        (crc32c, little-endian, in the first 4 bytes)
64   magic  "_BHRfS_M" (0x4D5F53665248425F)
180  compat_ro_flags
188  incompat_flags
196  csum_type
```

Primary at 0x10000 (64 KiB); mirrors at 0x4000000 (64 MiB) and 0x4000000000 (256 GiB), and only
those that fall within the device - btrfs keeps at most three copies (`BTRFS_SUPER_MIRROR_MAX`).
Checksum is CRC32C (Castagnoli, poly 0x82F63B78, init 0xFFFFFFFF, final xor 0xFFFFFFFF) over
bytes `[32:4096]`.

Any tool that rewrites a superblock should first **recompute the existing checksum and confirm it
matches on-disk** before trusting itself to write a new one. Cheap, and it catches an incorrect
implementation immediately.

## 8. GPL source: the highest-value move

Synology publishes occasional `<version>-<build>` source drops, not one per build. The whole
archive is nine entries: `7.3-86009`, `7.2-72806`, `7.2-64570`, `7.1.1-42962`, `7.0-41890`,
`6.2-25556`, `6.1-15284`, `6.1-15152`, `1.3-9346` - and as of July 2026 there is no 7.4 drop. If the target build has no matching entry, read the closest
lower family and treat every constant taken from it as provisional (see the build-sensitivity
note at the top of this file).

```
https://archive.synology.com/download/ToolChain/Synology%20NAS%20GPL%20Source/<VER>-<BUILD>/
https://global.synologydownload.com/download/ToolChain/Synology%20NAS%20GPL%20Source/<VER>-<BUILD>/<platform>/linux-3.10.x.txz
```

Find version and platform:

```sh
cat /etc.defaults/VERSION                       # productversion, buildnumber
grep unique /etc.defaults/synoinfo.conf         # e.g. synology_avoton_415+
```

The kernel driver is the authoritative documentation of the on-disk format. `btrfs-progs` source
is absent from the older drops (7.1.1-42962, 7.2-72806); newer drops may carry a
`btrfs-progs-*.txz` alongside the kernel, which would be a better base for a format-aware build
than patched mainline. List the platform directory before assuming you have to patch. Extract
only what is needed:

```sh
tar xf linux-3.10.x.txz --wildcards '*/fs/btrfs/*'
tar xf linux-3.10.x.txz --wildcards '*/include/uapi/linux/btrfs.h'
```

Reading `fs/btrfs/{ctree.h,disk-io.c,super.c,usrquota.c}` for twenty minutes produced more than
hours of black-box probing. **Do this early, not late.**

Newer platforms ship a 4.4.x kernel rather than 3.10.x; the archive path lists what exists for
that build. Verify the kernel line with `uname -r` before guessing the filename.

## 9. The dm-snapshot overlay

Always work on an overlay. Reads pass through to the origin, writes divert to a COW file.

Confirm the device first - `cachedev_0` is volume 1 on a single-volume unit, not a universal
name. Check `lvs` and `btrfs filesystem show` before substituting it into anything.

Unmounting the origin is a prerequisite and it is not a one-liner:

```sh
cd /                                    # your shell sits in /volume1/homes/<user>
synopkg list --name                     # stop every running package first
sudo synopkg stop <Pkg>                 # one by one; no syno_poweroff_task on DSM 7
sudo systemctl stop nfs-server nfs-mountd synoindexd synoelasticd   # then services holding it
sudo ls -l /proc/*/cwd /proc/*/root /proc/*/fd/* 2>&1 | grep volume1   # who holds it (no lsof)
sudo umount /volume1
```

The COW file must live somewhere that is not the volume being recovered, on a filesystem that
supports sparse files and large files. A USB volume (`/volumeUSB1/usbshare`) is the usual choice
but DSM commonly mounts those as exFAT or FAT32, where FAT32 caps a file at 4 GiB and neither
gives you sparseness - `truncate -s 300G` then fails or preallocates. Check first:

```sh
df -T /volumeUSB1/usbshare                     # ext4 or btrfs, not vfat/exfat
truncate -s 300G /volumeUSB1/usbshare/overlay.img
du -h --apparent-size /volumeUSB1/usbshare/overlay.img   # 300G apparent
du -h /volumeUSB1/usbshare/overlay.img                   # ~0 if truly sparse
```

A second internal volume works. An NFS or iSCSI target is possible but adds a failure mode
mid-repair. There is no valid option that stores the COW file on the origin.

```sh
ORIGIN=/dev/mapper/cachedev_0           # verify this name first
LOOP=$(sudo losetup -f --show /volumeUSB1/usbshare/overlay.img)
sudo dmsetup create ovl --table "0 $(sudo blockdev --getsz $ORIGIN) snapshot $ORIGIN $LOOP P 8"
```

Tear down with `umount`, then `dmsetup remove ovl`, then `losetup -d "$LOOP"`.

Pair it with an origin fingerprint taken before any work and re-verified after:

```sh
for off in 0 67108864 1073741824 274877906944; do          # byte offsets: 0, 64 MiB, 1 GiB, 256 GiB
  sz=$(sudo blockdev --getsize64 "$ORIGIN")
  [ "$off" -lt "$sz" ] || { echo "skip $off: past end of device"; continue; }
  sudo dd if="$ORIGIN" iflag=skip_bytes,count_bytes skip=$off count=8388608 | md5sum
done
```

Use byte offsets with `skip_bytes`, not `bs=1M skip=N` - with a 1 MiB block size, `skip=10485760`
means 10 TiB, and on any smaller device `dd` reads nothing, prints the md5 of empty input, and
still exits 0. Never send that `dd` to `2>/dev/null`: a short read is exactly the failure this
check exists to catch.

Constraints:

- The origin must not be mounted; dm-snapshot needs to open it. The overlay and a mounted
  `/volume1` are mutually exclusive
- The overlay carries the same fsid as the array, so never mount both at once - btrfs identifies
  filesystems by UUID
- COW usage shows in `dmsetup status ovl` as `used/total`. Watch it to confirm whether a tool is
  actually writing
- Size the COW file for the worst case, not the expected case. A repair that rewrites metadata
  can consume far more than intuition suggests, and a full COW device fails the overlay

In the recovery this document comes from, the overlay absorbed three separate
filesystem-destroying outcomes. It is not optional.

## 10. Mount escalation ladder

**A read-only mount is not a read-free mount.** btrfs replays the log tree even with `-o ro`, and
performs delayed transactions during mount. Suppressing that needs an explicit option, and on
DSM you probably do not have one: the `rescue=nologreplay` namespace and its `norecovery` alias
are modern mainline, while DSM ships 3.10 and 4.4 kernels that predate them. Worse, those
kernels do accept `recovery`, which means *use the backup root* (later renamed `usebackuproot`)
and does not skip log replay. An unrecognized btrfs option fails the mount outright rather than
being ignored, so testing is cheap and unambiguous - try it, read `dmesg`, and plan on the
baseline that log replay cannot be suppressed.

Consequence: on a damaged volume, run the ladder against the overlay unless the kernel accepts a
log-replay-suppressing option. Rung 1 on the bare origin is a write.

Set the target once, and mount somewhere neutral so DSM does not act on the result:

```sh
TARGET=/dev/mapper/ovl          # the overlay. Only ever the origin under the named exception
mkdir -p /mnt/vol1              # not /volume1
```

Then try in order, cheapest and least invasive first, reading `dmesg` after each failure:

```sh
mount -o ro                                                  $TARGET /mnt/vol1   # rung 1
mount -o ro,no_quota_tree                                    $TARGET /mnt/vol1   # rung 2
mount -o ro,no_quota_tree,no_block_group_hint                $TARGET /mnt/vol1   # rung 3
mount -o rw,no_quota_tree,clear_block_group_cache_tree       $TARGET /mnt/vol1   # rung 4
```

Rung 2 fixes the usrquota trap in section 5 and is the one that recovers a common class of
Synology mount failure. Rung 4 is **an unconditional write**: overlay mandatory, no exemption -
the log-replay discussion above applies only to the read-only rungs.

Rung 5 does not exist. `clear_cache` is on the hard-refusal list unconditionally, because
establishing that the free space tree is *not* the damaged structure is exactly what a damaged
filesystem prevents you from doing. If the ladder ends at rung 4, the next step is offline tools
against the overlay, not a fifth mount option.

Always read `dmesg` after a failed mount. Capture it by diffing full snapshots rather than
tracking line offsets, because the ring buffer wraps.

Stopping DSM services is a prerequisite for unmounting `/volume1`. `syno_poweroff_task` does not
exist on DSM 7.1+, so stop packages and services individually, and `cd /` first.

## 11. Tool matrix and patched builds

| Tool | Opens RW? | Synology-aware? | Verdict |
|---|---|---|---|
| DSM `/sbin/btrfs` v4.0 | No (`unsupported option features (3)`) | Yes | read-only inspection, `restore`, `subvolume list` |
| mainline btrfs-progs | Yes | No, rejects root flags | unusable unpatched |
| mainline + root-flag patch | Yes | Partially | best available offline tool |

Build guidance for the patched binary:

- Static, `--disable-backtrace`, `--with-crypto=builtin`
- Build on a glibc-based image (Debian stable). Alpine's static libblkid pulls libeconf, which
  has no static package
- Build **unstripped with `-g`** so a fault address resolves via `addr2line`. A stripped binary
  turns every crash into a dead end
- Deploy to `/root/`, not `/tmp` (`noexec`)

## 12. btrfs-progs bugs on damaged filesystems

Observed on v6.15 (June 2025; current is v7.x, so line numbers have drifted - grep the function
name, not the line). All are only reachable on a damaged filesystem, and all are worth guarding
in any recovery build:

1. `kernel-shared/extent-tree.c:2062` - `btrfs_print_leaf(path->nodes[0])` on a path that was
   never populated. NULL dereference **while reporting an error**.
2. `check/main.c:6394` - `calc_extent_flag()` dereferences `ri`, but `run_next_block()` is called
   with `ri = NULL` (line 8781). Only unconditional under `--init-extent-tree`. The naive fix
   (`if (!ri) return -ENOENT;`) is **harmful**: the caller responds to an error by setting
   `BTRFS_BLOCK_FLAG_FULL_BACKREF`, silently poisoning the rebuilt tree. The correct fix skips
   only the `ri`-dependent shortcuts.
3. `check/main.c:7527` - `delete_duplicate_records()` calls `abort()` on overlapping **metadata**
   extents. It cannot simply proceed, because the key it built is wrong: with `SKINNY_METADATA`
   the item is keyed `(start, METADATA_ITEM_KEY, info_level)`, not `(start, EXTENT_ITEM_KEY, nr)`.

Also: `btrfs check --repair` prompts
`repair mode will force to clear out log tree, are you sure? [y/N]` and blocks forever with no
stdin. Pipe `yes` into it or it will look like a hang.

## 13. Setting Synology subvolume flags from userspace

```
BTRFS_IOCTL_MAGIC          0x94
BTRFS_IOC_SUBVOL_GETFLAGS  _IOR(0x94, 25, __u64)   = 0x80089419
BTRFS_IOC_SUBVOL_SETFLAGS  _IOW(0x94, 26, __u64)   = 0x4008941A
```

The fd must be a subvolume root (`btrfs_ino == BTRFS_FIRST_FREE_OBJECTID`), otherwise the ioctl
returns `-EINVAL`.

**This needs a writable mount, so it is not the thing that gets you mounted.** `SETFLAGS` takes
write access and returns `-EROFS` on a read-only mount. Two legitimate uses: as a prophylactic on
a healthy volume, or as the permanent replacement for the mount option once
`-o rw,no_quota_tree` has the volume up. The mount option is what recovers a volume; the flag is
what keeps it mounting without the option afterwards.

The kernel handler is a **read-modify-write across all the private flags**, so always GET, OR in
the desired bit, then SET. A blind SET clears `HIDE`, `CMPR_RATIO`, and `DISABLE_QUOTA`.

Python is enough (`fcntl.ioctl`, `struct.pack("=Q", ...)`) and DSM ships python3, so no compiled
helper is needed:

```python
import fcntl, os, struct
GET, SET = 0x80089419, 0x4008941A
NOLOAD_USRQUOTA = 1 << 33
fd = os.open("/volume1", os.O_RDONLY)             # subvolume 256 root on DSM; open(), not open("rb")
cur = struct.unpack("=Q", fcntl.ioctl(fd, GET, struct.pack("=Q", 0)))[0]
fcntl.ioctl(fd, SET, struct.pack("=Q", cur | NOLOAD_USRQUOTA))
```

Read the flags back and confirm before relying on the change.

## 14. Damage surveying

```sh
find <dir> -size +0         # stats every entry, surfaces EIO
find <dir> -printf '%s\n'   # same effect, prints the size it had to stat for
find <dir> -type f          # NO stat: -type is answered from readdir's d_type
find <dir>                  # readdir only, reads NO inodes
```

**A survey without an inode-reading predicate reports a corrupt filesystem as clean.** That
mistake produced a false "0.00% damaged" result across 44 TB. Precisely: bare `find` still has to
`opendir` each directory, so it does surface unreadable *directories*; the blind spot is
unreadable *file* inodes. Note also that `-size +0` stats every file but does not print zero-byte
ones, so do not compute a damage percentage from its stdout - use `-printf '%s\n'` for that. `-type f` looks like it should
help and does not: `find` uses the `d_type` field `readdir` already returned and skips the
`stat` call, so the inode is never touched. Predicates that need inode data (`-size`, `-printf
'%s'`, `-newer`, `-perm`) are the ones that surface EIO.

Distinguish two classes of damage:

- unreadable **files**: the inode is unreadable, the name is still listed
- unreadable **directories**: contents cannot be enumerated at all, so what is inside is unknown
  and uncountable

Prefer re-detecting damage in-process (`os.lstat`, catch `EIO`) over replaying a recorded path
list. `find` stderr contains shell-escaped names, and media trees are full of spaces, quotes,
and unicode.

For extracting data off a filesystem that will not mount read-write, DSM's own `btrfs restore`
works read-only and understands the Synology format, which mainline `restore` may not.
