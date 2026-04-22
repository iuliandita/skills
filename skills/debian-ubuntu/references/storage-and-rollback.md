# Storage and Rollback

Use this for ext4, Btrfs, LUKS, LVM, TRIM, hibernation, and rollback work.

## Checks
- `lsblk -f`
- `findmnt -t btrfs`
- `systemctl status fstrim.timer`
- `blkid`

## Notes
- Snapshots help with rollback but are not backups.
- Hibernation depends on swap layout and resume configuration.
