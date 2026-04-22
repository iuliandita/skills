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
dracut -f --kver "$TARGET_KVER" 2>&1 || true
grubby --default-kernel 2>&1 || true
```

If the issue is a newly installed kernel, inspect all entries before setting defaults.

## Recovery stance

- Prefer booting the previous kernel before editing blind.
- From rescue media, mount root and EFI correctly before chrooting.
- Verify the initramfs and boot entry for the exact kernel you expect.
- Do not erase older kernels until the new one actually boots.

## Secure Boot note

NVIDIA, akmods, DKMS, and custom modules often fail at Secure Boot boundaries. Check signing and
MOK state before blaming the GPU stack itself.
