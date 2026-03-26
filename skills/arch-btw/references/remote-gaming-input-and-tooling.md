# Remote Gaming and Input

This reference covers two practical buckets that often travel together on Arch desktops:

1. remote gaming
2. controllers and input devices

It is intentionally pragmatic, not a generic Linux encyclopedia. For general CLI recommendations,
use `references/base-linux-and-cli.md`.

## Remote gaming

Common paths:

- Steam Remote Play
- Moonlight client
- Sunshine-style self-hosted streaming

Operational stance:

- Network quality still matters, but many "remote gaming" bugs are actually encoder, GPU, or input problems
- Wayland capture rules still matter if the host is doing screen capture or desktop streaming
- On Arch, treat host and client package source separately; some tools are in official repos, some live in the AUR

Useful checks:

```bash
pacman -Q moonlight-qt steam 2>/dev/null
journalctl -b | grep -Ei 'gamescope|nvrm|nvidia|amdgpu|i915|xe|drm'
command -v ffmpeg >/dev/null 2>&1 && ffmpeg -hide_banner -encoders | grep -E 'nvenc|vaapi|amf|qsv'
```

If remote streaming stutters, split the problem:

- local game performance
- encoder path
- network path
- client decode path

Do not jump straight to launch-option cargo culting.

## Controllers and input

Controller bugs are frequently misdiagnosed as graphics bugs.

Check:

- whether the device is visible at all
- whether it is wired or Bluetooth
- whether the issue is only inside Steam, only outside Steam, or system-wide

Useful checks:

```bash
lsusb
bluetoothctl devices
journalctl -b | grep -Ei 'bluez|hid|xpad|controller|input'
```

If Bluetooth audio is already broken, controller pairing may be broken for the same lower-level reason.

## What NOT to do

- Do not diagnose controller issues as GPU issues without proving that input is actually reaching the game.
- Do not assume remote-gaming stutter is always network; bad hardware encoding or capture can look similar.
