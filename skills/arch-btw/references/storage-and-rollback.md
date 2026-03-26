# Storage and Rollback

Arch storage advice gets dangerous when people collapse Btrfs, LUKS, TRIM, hibernation, and boot
artifacts into one vague "recovery" story. Keep them separate.

## First checks

```bash
lsblk -f
findmnt -t btrfs
findmnt /boot
findmnt /efi
systemctl status fstrim.timer 2>/dev/null || true
```

If Btrfs is involved, these help:

```bash
sudo btrfs subvolume list /
command -v snapper >/dev/null 2>&1 && sudo snapper list
```

If encryption is involved:

```bash
sudo cryptsetup status mapper_name
```

## Btrfs basics

Btrfs is useful on Arch because it supports:

- cheap snapshots
- subvolume-based layout
- rollback-friendly workflows

That does not mean every install has a good rollback design.

Check:

- which subvolumes exist
- whether `/boot` lives inside or outside the rollback scope
- whether snapshots are integrated into the bootloader path

## Snapper and rollback

Snapper is common on CachyOS-friendly Btrfs installs.

- Good for package-operation snapshots
- Good for fast rollback experiments
- Not a backup system
- Not a guarantee that bootloader or kernel artifacts roll back the way the user imagines

If the system rolled back root but not boot artifacts, the machine can still fail to boot cleanly.

## TRIM

TRIM is operational, not glamorous, but it matters on SSD-backed systems.

Useful check:

```bash
systemctl status fstrim.timer
```

Do not start rewriting mount options or crypto settings before checking whether the basic TRIM timer story is already fine.

## LUKS and encrypted-root realities

LUKS affects:

- boot hooks
- resume path
- initramfs contents
- key handling expectations

Useful checks:

```bash
lsblk -f
sudo cryptsetup status mapper_name
journalctl -b | grep -Ei 'crypt|luks|resume'
```

If encryption is in play, recovery steps have to line up with the actual mapper names and boot hooks.

## Hibernation and resume

Hibernation is not the same as suspend, and resume is not the same as boot.

When resume is broken, check:

- swap path or swapfile path
- kernel command line
- initramfs hooks
- encrypted-root layout

If the user cannot state where resume is configured, do not hand-wave a fix.

## Common failure splits

| Symptom | First suspicion |
|--------|-----------------|
| Rollback ran but system still fails to boot | `/boot` or UKI path not rolled back with root |
| Snapshots exist but boot menu does not expose them | bootloader integration missing |
| Resume hangs before desktop | swap or initramfs resume path |
| Disk is healthy but performance is odd | TRIM or mount-option assumptions |
| Encrypted-root recovery commands fail | wrong mapper name or wrong boot-hook assumptions |

## What NOT to do

- Do not sell snapshots as backups.
- Do not assume Btrfs rollback also fixed the bootloader or kernel artifacts.
- Do not prescribe hibernation changes without confirming swap, initramfs, and bootloader details.
- Do not treat encrypted-root recovery as generic "reinstall the bootloader" work.
