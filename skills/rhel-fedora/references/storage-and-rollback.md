# Storage and Rollback

Use this reference for XFS, ext4, Btrfs, LUKS, LVM, Stratis, TRIM, hibernation, and rollback
boundaries.

## Gather facts

```bash
lsblk -f
findmnt -t xfs,ext4,btrfs
pvs 2>&1 || true
vgs 2>&1 || true
lvs 2>&1 || true
cryptsetup status luks-root 2>&1 || true
systemctl status fstrim.timer 2>&1 || true
```

## Notes

- XFS is common on enterprise installs. It is not Btrfs; rollback assumptions differ.
- LVM and LUKS layering matters for hibernation and recovery.
- Stratis is its own management layer. Do not improvise Btrfs advice onto it.
- Snapshot presence is not backup presence.
