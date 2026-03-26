# Boot, Kernel, and Recovery

Kernel and boot work on Arch is one subsystem: package manager, initramfs generator, bootloader,
microcode, and optional UKI signing all have to agree.

## First questions

- Which kernel package is installed?
- Which initramfs generator is in play: `mkinitcpio` or `dracut`?
- Which bootloader is in charge: systemd-boot, GRUB, direct UEFI, something else?
- Where is the ESP mounted: `/efi`, `/boot`, or `/boot/efi`?
- Is Secure Boot in scope?

## Fast fact-gathering

```bash
uname -r
pacman -Q mkinitcpio dracut systemd sbctl
findmnt /boot
findmnt /efi
bootctl status
```

If `bootctl status` makes no sense, you may not be on systemd-boot at all. Confirm before acting.

## Initramfs generator rules

- On vanilla Arch, `mkinitcpio` is still the default path.
- `dracut` is a supported alternative, not something to mix casually with `mkinitcpio`.
- UKIs can be generated with mkinitcpio, dracut, or ukify-backed flows. Pick one pipeline and keep it coherent.

Common regenerate commands:

```bash
sudo mkinitcpio -P
sudo dracut --regenerate-all --force
```

Do not run both "just in case" unless you know the host is configured for both and both outputs are actually used.

## systemd-boot basics

Useful commands:

```bash
bootctl status
sudo bootctl install
sudo bootctl update
bootctl list
```

Key facts:

- systemd-boot comes from the `systemd` package.
- It looks for the ESP at `/efi`, `/boot`, or `/boot/efi` unless told otherwise.
- It automatically detects unified kernel images placed under `EFI/Linux/`.

If you change loader entries or UKIs, make sure the ESP is mounted where you think it is before copying or updating anything.

## GRUB basics

If the system uses GRUB, update its config after kernel or menu changes:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Do not mix systemd-boot instructions into a GRUB system because both use very different artifact and config paths.

## Unified kernel images

UKIs are valid on Arch, but they add one more layer to keep straight.

- A UKI can be built with mkinitcpio, dracut, kernel-install flows, or ukify.
- `ukify` does not create an initramfs by itself; it needs one from mkinitcpio, dracut, or another generator.
- If you use external microcode images, they must stay ordered correctly before the main initramfs payload.
- With Secure Boot, signing and update hooks must stay aligned with the chosen UKI path.

## Secure Boot

`sbctl` is the common Arch-native helper for key management and signing. Use it only after you know:

- the firmware mode is UEFI
- the bootloader path
- whether you are signing bootloader binaries, UKIs, or both
- where the signed artifacts live

Do not treat Secure Boot signing as a final cosmetic step. It is part of the boot artifact pipeline.

## Live ISO recovery

When the installed system will not boot, drop back to the boring recovery path:

```bash
arch-chroot /mnt
```

From there:

1. confirm the root and ESP mounts
2. reinstall or verify the kernel package
3. rebuild initramfs with the correct generator
4. repair the bootloader or regenerate loader config
5. check journal and package state before rebooting

If the system broke after a package interruption, also inspect package integrity and whether the boot artifacts were fully written.

## What NOT to do

- Do not remove the only kernel package on a remote system.
- Do not rebuild initramfs before confirming which generator actually owns the boot path.
- Do not write to the ESP until you know it is mounted correctly.
- Do not assume a broken boot is only a bootloader issue; package state and initramfs contents are frequent root causes.
