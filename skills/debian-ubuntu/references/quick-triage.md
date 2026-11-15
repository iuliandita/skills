# Quick Triage Checklist

Symptom to first-checks table for Debian-family problems.

## Quick Triage Checklist

| Symptom | First checks |
|---------|-------------|
| Package weirdness after install | `apt update` first. Broken dependencies? `apt -f install`. Held packages? `apt-mark showhold`. Mixed releases? `apt-cache policy` |
| Service fails after update | Config merge needed? `ucf` or `dpkg --configure -a`. Check unit overrides and `journalctl -b` |
| Won't boot after kernel work | GRUB menu, fallback kernel, initramfs. From live media, mount root and the ESP, then bind-mount `/dev`, `/proc`, `/sys`, and `/run` before `chroot`; use the boot recovery reference instead of a one-line chroot recipe. |
| PPA broke the system | `ppa-purge` if available, or manual downgrade + remove after checking package origin with `apt-cache policy` |
| Snap app misbehaves | `snap connections`, `snap info`, confinement level, interfaces |
| Desktop weirdness after update | `XDG_SESSION_TYPE`, portal, Xwayland, user services. On Ubuntu 26.04, verify the user is not expecting the old Ubuntu Xorg session to exist by default. |
| Bluetooth audio issues | BlueZ pairing, PipeWire nodes, card profile |
| Game blackscreen/crash | GPU driver (proprietary vs Mesa), Vulkan, Steam `i386` libs, Gamescope/MangoHud |
| Screen share broken | Wayland vs X11, portal backend, PipeWire user units |
| Suspend/resume breaks desktop | Sleep state, GPU logs, lock-screen, display manager |
| NVIDIA/module vanished after kernel change | DKMS drift: `dkms status`, confirm module built for `uname -r`, check HWE transition |
| Nothing makes sense | Check gotchas reference - mixed repos, stale PPAs, DKMS drift, AppArmor denials, HWE metapackage mismatch |
