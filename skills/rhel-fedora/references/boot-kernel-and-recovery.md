# Boot, Kernel, and Recovery

Use this reference for GRUB, EFI, kernel installs, `dracut`, `grubby`, Secure Boot, and broken
post-update boots.

## Gather boot facts first

```bash
findmnt /boot
findmnt /boot/efi
lsblk -f
grubby --default-kernel 2>&1 || true
grubby --info=ALL 2>&1 || true
rpm -qa | grep '^kernel' | sort
dracut --version 2>&1 || true
mokutil --sb-state 2>&1 || true
```

## Principles

- Kernel package, initramfs, bootloader entry, and Secure Boot state are one subsystem.
- Keep at least one known-good kernel entry until the new path is verified.
- On Oracle Linux, confirm UEK vs RHCK before rebuilding or pruning kernels.
- On cloud images, bootloader assumptions may differ from full-metal installs.

## Rebuild flow

Only rebuild after mountpoints and target kernel are known.

```bash
uname -r
rpm -qa | grep '^kernel' | sort
TARGET_KVER='set-the-kernel-version-you-actually-need'
dracut -f --kver "$TARGET_KVER"
grubby --default-kernel 2>&1 || true
```

If the issue is a newly installed kernel, inspect all entries before setting defaults.

## Removing a kernel

`installonly_limit` in `/etc/dnf/dnf.conf` controls how many kernels DNF keeps. To remove one
specific old kernel, confirm it is not the running one and read the transaction before answering
yes:

```bash
uname -r
rpm -q kernel-core
sudo dnf remove kernel-core-<old-version>
```

## Recovery stance

- Prefer booting the previous kernel before editing blind.
- From rescue media, mount root and EFI correctly before chrooting. The installer's rescue mode
  can mount the system under `/mnt/sysimage` for `chroot /mnt/sysimage`; by hand, open LUKS
  (`cryptsetup open`) and activate LVM (`vgchange -ay`) first:

  ```bash
  sudo mount /dev/<root> /mnt
  sudo mount /dev/<boot> /mnt/boot          # only if /boot is separate in fstab
  sudo mount /dev/<esp> /mnt/boot/efi       # EFI systems
  for d in /dev /dev/pts /proc /sys /run; do sudo mount --bind "$d" "/mnt$d"; done
  sudo chroot /mnt
  # inside: dracut -f --kver "$TARGET_KVER"; grubby --info=ALL
  ```

- Verify the initramfs and boot entry for the exact kernel you expect.
- Do not erase older kernels until the new one actually boots.

## Secure Boot note

NVIDIA, akmods, DKMS, and custom modules often fail at Secure Boot boundaries. Check signing and
MOK state before blaming the GPU stack itself.
