# Boot, Kernel, and Recovery

Use this for GRUB, initramfs, EFI, kernel packages, and boot recovery.

## Checks
- `findmnt /boot`
- `findmnt /boot/efi`
- `grub-install --version`
- `update-grub`
- `update-initramfs -u` or `update-initramfs -u -k all`
- `uname -r`

## Notes
- Know the kernel metapackage before changing anything.
- Keep one known-good kernel entry around.
- On EFI systems, verify the ESP mount before reinstalling GRUB.
