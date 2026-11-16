# Quick Triage Checklist

Symptom to first-checks table for Arch-family problems.

## Quick Triage Checklist

| Symptom | First checks |
|---------|-------------|
| Package weirdness after install | Partial upgrade? `pacman -Syu` first. For a conflict, run `pacman -Qo /exact/path` first. Fix or remove an unowned manual file; report an owned-file conflict. Use `--overwrite exact/path` (package-archive path without the leading `/`) only when that verified file is intentionally being replaced; never use `'*'` or an inferred glob. |
| Service fails after update | `.pacnew` merge needed? `pacdiff` (from `pacman-contrib`), or `DIFFPROG='nvim -d' pacdiff`. Check unit overrides and `journalctl -b` |
| Won't boot after kernel work | Confirm root/subvolume, separate boot and ESP mounts, installed kernel, active initramfs generator and bootloader. Inspect available snapshots before changing boot artifacts. Follow `references/boot-kernel-and-recovery.md`; use the confirmed generator/loader for CachyOS too. |
| CachyOS unstable after repo tuning | CPU capability, repo tier, forked `pacman` |
| AUR build failure | `PKGBUILD`, keys, pinned deps, repo conflicts |
| Hyprland desktop weirdness | `XDG_SESSION_TYPE`, portal, Xwayland, user services |
| Hyprland lock/wallpaper/idle | Separate compositor from `hyprpaper`/`hypridle`/`hyprlock` |
| Bluetooth audio issues | BlueZ pairing, PipeWire nodes, card profile |
| Game blackscreen/crash | GPU stack, Vulkan, Steam multilib, Gamescope/MangoHud |
| Screen share broken | Wayland vs X11, portal backend, PipeWire user units |
| Suspend/resume breaks desktop | Sleep state, GPU logs, lock-screen, display manager |
| Snapshot rollback failed | Subvolume layout, bootloader path, encryption scope |
| NVIDIA/module vanished after kernel change | DKMS drift: `dkms status`, confirm module built for `uname -r`, rebuild if missing |
| Nothing makes sense | Check gotchas reference - partial upgrades, stale portals, DKMS drift explain most chaos |
