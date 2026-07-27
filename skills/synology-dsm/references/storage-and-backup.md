# Storage, Disks, Snapshots, Backups

Read this when the task touches disks, storage pools, RAID repair, snapshots, or backups.
Recovery of an unmountable volume is a different document: `btrfs-recovery.md`.

## Contents

1. The layer stack, and why it matters
2. SHR
3. Reading array health
4. "Volume Crashed" triage
5. Disk replacement and repair
6. Drive compatibility database
7. btrfs metadata headroom
8. Snapshots
9. Backups
10. Migration between units

---

## 1. The layer stack

```
/dev/sdX3  ->  mdN (RAID)  ->  vgN/volume_N (LVM)  ->  cachedev_N (flashcache shim)  ->  btrfs
```

Four layers, four independent failure modes. DSM's UI collapses them into one health indicator,
which is why its warnings are ambiguous. Diagnose bottom-up: disks, then array, then LVM, then
filesystem. A filesystem symptom with a healthy array is a filesystem problem; a filesystem
symptom with a degraded array is usually the array.

`md0` (system, ~8 GB) and `md1` (swap, ~2 GB) are RAID1 across **all** disks in the unit, not
just the pool members. They degrade quietly and stay degraded for months because DSM does not
surface them the way it surfaces data volumes. Check them every time.

## 2. SHR

Synology Hybrid RAID is not a distinct RAID level. It is md arrays layered so that mixed-size
disks contribute their full capacity: the disks are partitioned into matched chunks and each
chunk group becomes its own md array, joined by LVM. SHR-1 tolerates one disk failure, SHR-2
tolerates two.

Consequences:

- A single unit can show several `mdN` devices for one apparent volume. Read all of `/proc/mdstat`,
  not just the first array
- Capacity expansion only materializes when enough disks are large enough for a new chunk group.
  Replacing one disk in a mixed set often adds nothing until the second one is replaced
- Not every model supports SHR; some enterprise models ship with it disabled

## 3. Reading array health

```sh
cat /proc/mdstat
sudo mdadm --detail /dev/md2
sudo mdadm --examine /dev/sda3        # per-device superblock, event count
```

What to look at:

- `[UUU_]` style maps: an underscore is a missing member
- `recovery`/`resync` lines with a percentage and speed: the array is rebuilding. Do not
  benchmark, do not power down, do not start a second repair
- Event counts across members in `--examine`. Divergent counts are why force-assembly is
  dangerous: it picks a generation for you, silently

## 4. "Volume Crashed" triage

DSM's banner does not say which layer failed. It can mean the md array went inactive, or that
btrfs went read-only after metadata trouble. Establish the layer before touching anything:

```sh
cat /proc/mdstat                       # array active and complete?
sudo lvs                               # LV present?
mount | grep volume                    # mounted, and rw or ro?
sudo dmesg | grep -iE 'btrfs|md/raid|I/O error' | tail -40
```

Then:

| Finding | Layer | Next step |
|---|---|---|
| Array inactive or missing members | mdadm | Identify the failed disks first. Do not force-assemble |
| Array clean, LV present, btrfs mounted read-only | btrfs | `btrfs-recovery.md` |
| Array clean, mount fails with `open_ctree failed` | btrfs | `btrfs-recovery.md`, mount ladder |
| I/O errors on one disk in `dmesg` | disk | Replace the disk, then repair the array |

Do not click "Repair" in DSM before this triage. Repair at the wrong layer writes to every disk
in the pool and can turn a recoverable filesystem problem into a data-loss event.

btrfs forcing itself read-only is **protective**, not additional damage. `remount,rw` is refused
once that has happened; a full unmount and fresh mount is required, which means stopping services.

## 5. Disk replacement and repair

Order of operations:

1. Confirm which physical bay maps to the failed device (`smartctl -a`, DSM's Storage Manager
   bay view, drive serial numbers). Pulling the wrong disk from a degraded array destroys it
2. Verify the backup is current and restorable **before** starting a rebuild. A rebuild reads
   every sector of every surviving disk, which is exactly when a second marginal disk fails
3. Replace, then let DSM repair the pool, or `mdadm --add` for the system/swap arrays
4. Watch `/proc/mdstat` to completion. Expect hours to days for large data arrays; RAID1 on the
   8 GB system array finishes in under a minute

One disk at a time. Never remove a second disk from a degraded SHR-1 or RAID5 pool.

## 6. Drive compatibility database

DSM keeps a local compatible-drive database (files under `/var/lib/disk-compatibility/`) and
gates warnings, and on some 2025 models gated functionality, on it.

Policy timeline worth knowing, because it determines what a user's unit does:

- April 2025: Synology announced that 2025 Plus-series models would require Synology-branded
  drives for full functionality
- October 2025, with DSM 7.3: Synology reversed it. Third-party 3.5" HDDs and 2.5" SATA SSDs are
  supported again on 2025 Plus units. M.2 SSDs remained restricted at that point

`support_disk_compatibility` in `/etc.defaults/synoinfo.conf` toggles the check. Changing it, or
running a community script that injects drive models into the local database, silences warnings
but also silences a real signal and can be reverted by any DSM update. Treat it as the user's
decision, state the tradeoff, and never apply it unprompted.

## 7. btrfs metadata headroom

```sh
sudo btrfs filesystem usage /volume1
```

A btrfs filesystem with free data space but exhausted metadata behaves like failing hardware:
writes fail, the volume may go read-only, and every disk reports healthy. Check metadata before
investigating disks. Small-file-heavy shares and long snapshot chains are the usual causes.

DSM does not expose `btrfs balance` in the UI for this. Handle it deliberately: free space by
deleting old snapshots first, since snapshot deletion returns metadata, and treat any manual
balance as a change with a stated blast radius (heavy I/O, long duration, interruptible but not
free to interrupt).

## 8. Snapshots

Snapshot Replication requires btrfs volumes. Snapshots are per shared folder (and per LUN), stored
in a hidden system directory on the same volume (`/volume1/@sharesnap/...` on units observed;
confirm the path on the target unit before scripting against it).

Facts that change decisions:

- A snapshot on the same volume protects against deletion and ransomware encryption of files,
  not against volume loss. It is not a backup
- **Immutable snapshots (WORM)**, introduced in DSM 7.2 alongside WriteOnce shared folders,
  cannot be deleted by anyone, including
  an administrator or a compromised admin account, until the protection period expires. Enabling
  immutability requires it set on both the replication task and the snapshot schedule
- A protection period of 7 to 14 days is the common recommendation. Longer periods consume space
  that cannot be reclaimed early, by design
- Long snapshot chains consume metadata (section 7). Retention policy is a storage decision, not
  only a recovery one
- Restore paths: whole-share restore from Snapshot Replication, or per-file browse of the
  read-only snapshot directory

## 9. Backups

| Tool | Covers | Restore requirement |
|---|---|---|
| Hyper Backup | NAS data and DSM config to another NAS, USB, rsync target, or cloud | Hyper Backup Explorer or a Hyper Backup Vault on the target |
| Snapshot Replication | Shared folders and LUNs to a second Synology | A second Synology with a compatible DSM |
| Active Backup for Business | Endpoints, servers, VMs, Microsoft 365 backing up **to** the NAS | The NAS itself must be alive |
| USB Copy / rsync | Ad-hoc file-level copies | Any host |

Hyper Backup writes a proprietary `.hbk` container. Plain file copies are not what it produces,
so restoring without a Synology or Hyper Backup Explorer is not a five-minute job. Test it.

Verification rules:

- A backup job reporting success is not a verified backup. Restore something, at a defined
  interval, and record when it was last done
- Keep at least one copy off the unit and one copy that the NAS's own admin credentials cannot
  delete. Active Backup for Business stores its data on the NAS, which means it protects
  endpoints, not the NAS
- Check backup integrity before any storage repair, not after. The repair is when you find out

## 10. Migration between units

DSM supports moving a disk set into another Synology and preserving data (Synology calls this
disk migration), subject to model family and DSM version constraints. Two properties matter:

- Reinstalling DSM does not by itself wipe data volumes; DSM lives on the `md0` system partition
  replicated across all disks, separately from the data pool
- Migration compatibility depends on the target model's platform and DSM version. Check
  Synology's migration compatibility table for the specific source and target models rather than
  assuming

Before any migration, take a full backup. Migration touches the system partition on every disk.
