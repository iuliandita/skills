---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "systemd"
    version: "262"
    source: "https://github.com/systemd/systemd/releases"
  - tool: "mkinitcpio"
    version: "42.2"
    source: "https://github.com/archlinux/mkinitcpio/releases"
  - tool: "dracut"
    version: "111 (Arch; upstream 112)"
    source: "https://github.com/dracut-ng/dracut-ng/releases"
  - tool: "Hyprland"
    version: "0.56.2"
    source: "https://github.com/hyprwm/Hyprland/releases"
  - tool: "xdg-desktop-portal-hyprland"
    version: "1.4.1"
    source: "https://github.com/hyprwm/xdg-desktop-portal-hyprland/releases"
  - tool: "PipeWire"
    version: "1.6.9"
    source: "https://gitlab.freedesktop.org/pipewire/pipewire/-/releases"
  - tool: "WirePlumber"
    version: "0.5.18 (Arch; check derivative repo)"
    source: "https://gitlab.freedesktop.org/pipewire/wireplumber/-/releases"
  - tool: "nvidia-utils"
    version: "615.71.09"
    source: "https://archlinux.org/packages/extra/x86_64/nvidia-utils/"
---

# Arch Linux target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Only pin versions here when they materially affect compatibility or troubleshooting shape. For
ordinary rolling packages, prefer the current repo state over stale version tables.
Versions below are upstream component versions; distro package release suffixes and epochs
are repository-specific. Check the enabled Arch or CachyOS repository before comparing builds.
Reverify before use if the receipt exceeds 120 days.

| Component | Version | Why it matters |
|-----------|---------|----------------|
| systemd | 262 | boot and session behavior |
| mkinitcpio | 42.2 | initramfs pipeline changed enough to matter |
| dracut | 111 (Arch; upstream 112) | alternative initramfs pipeline with different expectations |
| linux-cachyos | verify enabled CachyOS repo | kernel and module compatibility |
| linux-cachyos-eevdf | verify enabled CachyOS repo | alternate kernel lane with different behavior surface |
| Hyprland | 0.56.2 | old 0.4x and early 0.5x guidance is frequently stale here |
| xdg-desktop-portal-hyprland | 1.4.1 | Wayland portal behavior depends on this layer |
| PipeWire | 1.6.9 | audio and capture stack anchor |
| WirePlumber | 0.5.18 (Arch; check derivative repo) | policy layer paired with PipeWire behavior |
| nvidia-utils | 615.71.09 | driver branch matters for gaming and Wayland breakage |
