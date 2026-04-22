# Kali Images, Live Media, Persistence, and Recovery

Kali ships in several shapes. The recovery path depends on which shape the user is actually using.

## Official image types

Kali 2026.1 image directories include:
- installer ISOs
- netinst ISOs
- prebuilt VM images
- checksums and GPG signatures
- Purple installer image on amd64

## ARM and SBC images

Kali also ships ARM images for boards such as Raspberry Pi and other SBCs. Treat these as a
separate lane: boot firmware, storage media, peripherals, and image choice are board-specific and
should not be debugged like generic amd64 installs.

Use the image type as part of the diagnosis, not just the distro name.

## Installed system vs live media

| Mode | What changes |
|------|--------------|
| Installed root filesystem | normal package and boot recovery rules apply |
| Live ISO | ephemeral by default; changes vanish unless persistence exists |
| Live USB with persistence | overlay and persistence partition become first-class suspects |
| VM image | hypervisor, guest additions, USB passthrough, and display stack matter |

## Persistence questions

When a user says Kali forgot changes after reboot, check:
- was it live media?
- was persistence created at all?
- is the persistence partition mounting?
- is the wrong boot entry being used?
- did the overlay get corrupted?

Useful checks:
```bash
findmnt /
findmnt /run/live/medium 2>&1 || true
findmnt | grep -Ei 'persistence|overlay|live' 2>&1 || true
lsblk -f
```

## Verification discipline

Kali publishes `SHA256SUMS` and GPG signatures for release images. Prefer those over SHA1 and
prefer verified official images over mystery USB media.

## Recovery pattern

1. Confirm image type.
2. Confirm whether the system is installed or live.
3. Confirm persistence layout if live.
4. Verify storage and mountpoints.
5. Only then chase package or desktop issues.

## Purple and specialized images

Kali Purple images are still Kali, but the image choice changes expectations about what should be
preinstalled and what kind of workflow the user expects. Do not assume the default red-team image
set when they explicitly chose Purple.

## VM notes

VM image pain often comes from the hypervisor, not Kali itself:
- broken USB passthrough hides Wi-Fi adapters and SDR gear
- weak display acceleration makes desktop tools feel broken
- NAT or host-only mode changes how scanners and sniffers behave
- shared clipboard and drag-and-drop issues are guest-tooling issues, not pentest-tool bugs

## What not to do

- Do not debug live persistence like a normal installed root filesystem.
- Do not recommend reinstalling the whole image before checking mount and overlay state.
- Do not trust an ISO that was never checksum-verified.
