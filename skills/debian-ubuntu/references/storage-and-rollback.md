# Storage and Rollback

Use this for ext4, Btrfs, LUKS, LVM, TRIM, hibernation/resume, and snapshot-based rollback on
Debian/Ubuntu. Snapshots are not backups: a snapshot on the same disk dies with the disk.

## Inspect first

```bash
lsblk -f                       # tree of block devices with FSTYPE, LABEL, UUID, mountpoints
findmnt --real                 # real (non-pseudo) mounts with source and options
findmnt -t btrfs
blkid                          # UUIDs and types, useful for fstab/crypttab cross-check
df -hT                         # filesystem usage by type
cat /etc/fstab
```

- `lsblk -f` and `blkid` give the UUIDs that `/etc/fstab` and `/etc/crypttab` reference. A boot
  hang after disk changes is often a stale UUID in `fstab` or `crypttab`.
- `findmnt --real` filters out `proc`/`sys`/`tmpfs` noise so the actual storage layout is visible.

## LUKS (encrypted volumes)

```bash
lsblk -f | grep -i crypt
sudo cryptsetup status <mapper-name>           # e.g. /dev/mapper/cryptroot
sudo cryptsetup luksDump /dev/sdXn             # header info, key slots (no passphrase needed)
cat /etc/crypttab
```

- The boot-time unlock comes from `/etc/crypttab` plus the `cryptsetup-initramfs` hook; if you add
  or move an encrypted volume, run `update-initramfs -u` so the initramfs knows how to unlock root.
- `luksDump` shows key slots; keep at least one known passphrase slot before rotating keys.

## LVM

```bash
sudo pvs        # physical volumes
sudo vgs        # volume groups, free space (VFree)
sudo lvs        # logical volumes
sudo lvs -a     # includes hidden/thin-pool volumes
```

- For thin pools, `lvs -a` shows `Data%` and `Meta%`. `Data%` is blocks ever written to the pool,
  not live filesystem usage and not freed by deletes inside a thin volume - a thin pool can hit
  100% even though the filesystems look half-empty. Pool or metadata exhaustion takes volumes
  read-only, so watch both `Data%` and `Meta%`.
- Grow with `lvextend -r -L +<size> /dev/vg/lv` (the `-r` resizes the filesystem too on ext4/Btrfs).

## ext4 and Btrfs

```bash
sudo tune2fs -l /dev/sdXn 2>&1 | head -30      # ext4 superblock info (read-only)
sudo btrfs filesystem df /mnt                  # Btrfs allocation by type
sudo btrfs filesystem usage /mnt               # accurate Btrfs free space
sudo btrfs subvolume list /mnt
```

- Btrfs free space is not what `df` shows; use `btrfs filesystem usage`. `df` can report space that
  Btrfs cannot actually allocate due to metadata/data chunk layout.
- Do not run `fsck`/`btrfs check --repair` on a mounted filesystem; unmount or use recovery media.

## TRIM (SSD)

```bash
systemctl status fstrim.timer
systemctl list-timers fstrim.timer
sudo fstrim -av                                # manual trim of all eligible mounts, verbose
```

- Debian/Ubuntu run periodic TRIM via the `fstrim.timer` (weekly), not continuous `discard` mount
  options. The timer is the supported approach; continuous `discard` is usually unnecessary and can
  hurt performance on some drives.
- TRIM on LUKS needs `discard` allowed in `/etc/crypttab`, which has a minor security tradeoff
  (exposes allocated-block patterns). Decide deliberately.

## Hibernation and resume

```bash
swapon --show
cat /proc/swaps
grep -i resume /etc/initramfs-tools/conf.d/resume 2>&1 || true
cat /sys/power/state
```

Hibernation writes RAM to swap and depends on three things lining up: enough swap to hold used RAM,
a correct `resume=` (UUID of the swap device, or swapfile offset) wired into the initramfs resume
hook, and Secure Boot/lockdown not blocking it. On a swapfile, the resume offset is extra work and
fragile. Do not promise hibernation works without confirming the swap layout and the resume
configuration; a wrong `resume=` causes a fresh boot that loses the session instead of resuming.

## Snapshot rollback (Timeshift)

```bash
timeshift --list 2>&1 || true
```

- Timeshift is the common Debian/Ubuntu rollback tool; it supports rsync-mode (any filesystem) and
  Btrfs-mode (using `@`/`@home` subvolume snapshots, the Ubuntu/Mint default layout when installed
  on Btrfs). Mint ships and recommends it.
- A Timeshift snapshot rolls back the system, not necessarily `/home` (by default `@home` is often
  excluded). Confirm what is in scope before trusting a rollback.
- Snapshots protect against bad upgrades and config breakage; they do not protect against drive
  failure. Keep a real off-disk backup separately.

## Notes

- Snapshots help with rollback but are not backups; keep an independent off-disk copy.
- Hibernation depends on swap size, the initramfs resume hook, and Secure Boot state - verify all
  three before relying on it.
- A boot hang after disk changes is often a stale UUID in `fstab` or `crypttab`; cross-check with
  `blkid`.
- Thin-pool `Data%` is allocated blocks, not live usage; a pool can fill while filesystems look free.
