# Storage and Rollback

Use this reference for XFS, ext4, Btrfs, LUKS, LVM, Stratis, TRIM, hibernation, and snapshot
rollback on Btrfs and LVM with the limits of each.

## Contents

- Gather facts
- Notes
- Which lane has what
- Btrfs: inspect
- Btrfs: snapshot before a risky change
- Btrfs: roll back
- LVM: inspect
- LVM: snapshot before a risky change
- LVM: roll back

## Gather facts

```bash
lsblk -f
findmnt -t xfs,ext4,btrfs
findmnt /boot
pvs 2>&1 || true
vgs 2>&1 || true
lvs -a 2>&1 || true
cryptsetup status luks-root 2>&1 || true
systemctl status fstrim.timer 2>&1 || true
```

## Notes

- XFS is common on enterprise installs. It is not Btrfs; rollback assumptions differ.
- LVM and LUKS layering matters for hibernation and recovery.
- Stratis is its own management layer. Do not improvise Btrfs advice onto it.
- Snapshot presence is not backup presence. A snapshot lives on the same device as its origin and
  is lost with it.
- A rollback only helps when a snapshot was taken before the change. Check that first; do not
  describe a rollback path on a host that has no snapshot.

## Which lane has what

- Fedora desktop variants install on Btrfs by default with two subvolumes, `root` mounted at `/`
  and `home` at `/home`, and a separate ext4 `/boot`. Fedora sets up no automatic snapshots and no
  rollback tooling; a snapshot exists only if someone or some added tool took it. Confirm the
  layout on the host, since custom partitioning is common.
- RHEL removed Btrfs in RHEL 8: it cannot be created, mounted, or installed on there. RHEL and
  its rebuilds use LVM snapshots. Do not suggest Btrfs commands on that lane.

## Btrfs: inspect

```bash
sudo btrfs subvolume list /
sudo btrfs subvolume get-default /
findmnt -no SOURCE,OPTIONS /
cat /proc/cmdline                       # look for rootflags=subvol= or subvolid=
grep -E 'btrfs' /etc/fstab
```

Root is selected by a `subvol=` name, a `subvolid=` number, or neither (the filesystem's default
subvolume). The rollback method depends on which, so establish it first.

## Btrfs: snapshot before a risky change

Subvolumes named in the listing sit under the top-level subvolume (ID 5), which is usually not
mounted. Mount it somewhere to reach them:

```bash
sudo mkdir -p /mnt/btrfs-top
sudo mount -o subvolid=5 /dev/mapper/DEVICE /mnt/btrfs-top      # device from findmnt above
sudo btrfs subvolume snapshot -r /mnt/btrfs-top/root /mnt/btrfs-top/root-pre-change
```

`-r` makes the snapshot read-only. It uses space only as the origin changes.

## Btrfs: roll back

Consequential: everything written to the root subvolume since the snapshot is discarded. Show the
subvolume list, the snapshot chosen, and the commands, and get confirmation. Prefer doing this
from rescue or live media so the root subvolume is not in use.

When root is mounted by `subvol=` name, replace what that name points to:

```bash
sudo mv /mnt/btrfs-top/root /mnt/btrfs-top/root-broken           # subvolumes can be renamed
sudo btrfs subvolume snapshot /mnt/btrfs-top/root-pre-change /mnt/btrfs-top/root   # writable copy
```

When root is the default subvolume, point the default at a writable copy of the snapshot instead;
it takes effect at the next mount:

```bash
sudo btrfs subvolume snapshot /mnt/btrfs-top/root-pre-change /mnt/btrfs-top/root-restored
sudo btrfs subvolume list /mnt/btrfs-top                         # read the new subvolume's ID
sudo btrfs subvolume set-default <ID> /mnt/btrfs-top
```

Reboot, then confirm with `findmnt -no SOURCE,OPTIONS /` and `btrfs subvolume get-default /`. Keep
`root-broken` until the system is confirmed good, then delete it deliberately.

Limits:

- `/boot` is ext4 and is not rolled back. Kernels, initramfs images, and boot entries stay at
  their newer state while `/usr/lib/modules` goes back, so a rollback across a kernel update can
  leave a boot entry with no matching modules. Boot an entry whose kernel exists in the restored
  root, or reinstall the kernel afterwards.
- Snapshots are not recursive. A nested subvolume appears in the snapshot as an empty stub and
  keeps its current contents; the subvolume list shows any that exist.
- `/home` is a separate subvolume and is untouched; so is anything on another filesystem.
- `set-default` changes nothing when the kernel command line or `/etc/fstab` names a `subvol=` or
  `subvolid=` explicitly; the explicit option wins.
- Do not flip a read-only snapshot to read-write to boot from it; take a writable snapshot of it
  and keep the original.

## LVM: inspect

```bash
sudo lvs -a          # Origin and Data% columns; attr starts with s (COW snapshot) or V (thin)
sudo vgs             # VFree: a classic snapshot needs free space in the VG
```

## LVM: snapshot before a risky change

```bash
sudo lvcreate -s -n root_pre -L 5G vg/root      # COW: -L is VG space for changed blocks
sudo lvcreate -s -n root_pre vg/thin_root       # thin LV origin: no size, shares the pool
```

Size a COW snapshot for the writes expected while it exists; the manual suggests about 20% of the
origin as often enough. Watch `Data%` and grow it with `lvextend` before it fills. A COW snapshot
that fills becomes invalid (`I` in the `lvs` attributes) and is no use for a rollback.

## LVM: roll back

Consequential: the origin returns to the snapshot's content, every later write to it is lost, and
the snapshot is consumed by the merge. Show `lvs -a`, name the origin and snapshot, and get
confirmation.

```bash
sudo lvconvert --merge vg/root_pre
```

- With both volumes closed the merge starts at once. For a mounted origin such as the root
  filesystem it is deferred until the origin is next activated, which in practice means a reboot.
- To inspect a snapshot first, mount it read-only. An XFS snapshot carries the origin's UUID, so
  it needs `mount -o ro,nouuid` (add `norecovery` for a read-only snapshot).
- Thin snapshots are created with the activation-skip flag; activate one with
  `sudo lvchange -ay -K vg/root_pre` before mounting it.

Limits:

- `/boot` and the EFI System Partition are normally outside LVM and are not rolled back; the same
  kernel and boot-entry mismatch as on Btrfs applies.
- Only the snapshotted LV goes back. Separate LVs such as `/var` or `/home` need their own
  snapshot taken at the same time, or the result is a mix of old and new state.
- A thin pool that fills up affects every volume in it. Check the pool's `Data%` and `Meta%`
  before adding snapshots.
- A snapshot of a running database is only crash-consistent. Stop or quiesce it first.
