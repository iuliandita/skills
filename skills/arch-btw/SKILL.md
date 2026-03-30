---
name: arch-btw
description: >
  Use when administering Arch Linux, CachyOS, or Arch-based distros. Covers pacman, paru, AUR,
  makepkg, keyring and pacnew issues, systemd, mkinitcpio or dracut, bootctl, systemd-boot,
  UKIs, Secure Boot, Hyprland, GNOME, KDE Plasma, PipeWire, Bluetooth, GPU drivers, Steam,
  Proton, OBS, WebRTC screen sharing, Discord or Teams quirks, virtual cameras, and Linux
  gaming. Also use for EndeavourOS or Manjaro when the task is still Arch-style package, boot,
  desktop, graphics, media, or service management. Triggers: 'arch linux', 'cachyos', 'pacman',
  'paru', 'aur', 'systemd', 'mkinitcpio', 'bootctl', 'wayland', 'hyprland', 'gnome', 'kde',
  'pipewire', 'bluetooth', 'mesa', 'vulkan', 'nvidia', 'amdgpu', 'steam', 'proton',
  'gamescope', 'mangohud', 'gamemode', 'obs', 'screen share', 'webrtc', 'discord', 'teams',
  'v4l2loopback', 'pacnew', 'arch-chroot'. Not for shell syntax (use command-prompt), network
  design (use networking), config management at scale (use ansible), or security testing (use
  security-audit or lockpick).
source: custom
date_added: "2026-03-26"
effort: high
---

# Arch BTW: Arch Linux and CachyOS Administration

Administer Arch Linux and Arch-style systems without falling into rolling-release footguns.
Focus on vanilla Arch first, then layer in CachyOS behavior, `paru` workflow, systemd-native
service management, boot recovery, kernel handling, and derivative-specific cautions.

**Versions worth pinning** (March 26, 2026):

Only pin versions here when they materially affect compatibility or troubleshooting shape. For
ordinary rolling packages, prefer the current repo state over stale version tables.

| Component | Version | Why it matters |
|-----------|---------|----------------|
| systemd | 260.1-1 | boot and session behavior |
| mkinitcpio | 40-4 | initramfs pipeline changed enough to matter |
| dracut | 110-2 | alternative initramfs pipeline with different expectations |
| linux-cachyos | 6.19.10-1 | kernel and module compatibility |
| linux-cachyos-eevdf | 6.19.10-1 | alternate kernel lane with different behavior surface |
| Hyprland | 0.54.2-1 | old 0.4x and early 0.5x guidance is frequently stale here |
| xdg-desktop-portal-hyprland | 1.3.11-3 | Wayland portal behavior depends on this layer |
| PipeWire | 1:1.6.2-1 | audio and capture stack anchor |
| WirePlumber | 0.5.13-2 | policy layer paired with PipeWire behavior |
| nvidia-utils | 595.58.03-1 | driver branch matters for gaming and Wayland breakage |

## When to use

- Package management on Arch or CachyOS with `pacman`, `paru`, AUR builds, mirrorlists, or keyrings
- systemd service, timer, socket, boot, and journal troubleshooting on Arch-style systems
- Bootloader, initramfs, UKI, Secure Boot, kernel, and recovery work on Arch or CachyOS
- Rolling-release maintenance, `.pacnew` merges, orphan cleanup, foreign package audits
- CachyOS-specific repo, kernel, snapshot, or optimized-repo questions
- Desktop stack work on Arch-style systems: Wayland vs X11, Hyprland, KDE, GNOME, portals, PipeWire, Bluetooth
- Session startup and laptop work: GDM, SDDM, greetd, suspend or resume, power profiles, hybrid graphics
- GPU and gaming work: NVIDIA pain, AMD or Intel graphics, Vulkan, Steam, Proton, Gamescope, MangoHud, GameMode
- Capture and communication stack work: OBS, WebRTC screen sharing, Discord or Teams issues, portals, virtual cameras
- Storage and rollback work: Btrfs, Snapper, LUKS, TRIM, hibernation or resume, snapshot recovery limits
- Remote gaming and input work: Moonlight, Sunshine-style hosting, Steam Remote Play, controllers, Bluetooth pads
- Base Linux ops and CLI tooling on Arch-style systems: `journalctl`, `dmesg`, `lsblk`, `findmnt`, `jq`, `ripgrep`, `bat`, `eza`, `nvim`
- EndeavourOS or Manjaro tasks where the real problem is still Arch package, boot, or service behavior

## When NOT to use

- Shell syntax, quoting, or script portability problems -- use **command-prompt**
- Network architecture, DNS, VPNs, reverse proxies, or firewall design -- use **networking**
- Docker, Podman, image builds, or container runtime issues -- use **docker**
- Kubernetes cluster or manifest work -- use **kubernetes**
- Fleet-wide Linux configuration via playbooks or roles -- use **ansible**
- Security review, vulnerability triage, or offensive testing -- use **security-audit** or **lockpick**
- OPNsense or pfSense appliance work -- use **firewall-appliance**

---

## AI Self-Check

Before returning Arch or CachyOS commands, verify:

- [ ] **No partial upgrades**: do not suggest `pacman -Sy <pkg>` on Arch-style systems. Use a full upgrade path or stop.
- [ ] **Distro identified first**: Arch, CachyOS, EndeavourOS, and Manjaro are not interchangeable once repos diverge.
- [ ] **Boot stack identified**: know the bootloader, ESP mountpoint, kernel package, and initramfs generator before changing kernel or boot files.
- [ ] **Fallback path exists**: do not remove or replace the only known-good kernel or boot entry on a remote system.
- [ ] **AUR trust boundary respected**: review `PKGBUILD` and related files before building. Treat `paru` as convenience, not as proof of safety.
- [ ] **systemd scope is correct**: distinguish system units from user units and use `systemctl --user` only when appropriate.
- [ ] **Wayland stack is coherent**: compositor, portal backend, Xwayland compatibility, and user-session services line up.
- [ ] **Session startup path is identified**: display manager, greeter, or TTY launch path is known before debugging environment propagation or autostart.
- [ ] **Audio stack is coherent**: PipeWire, `pipewire-pulse`, and WirePlumber are not fighting a leftover PulseAudio setup.
- [ ] **Bluetooth path is complete**: `bluetooth.service` alone is not enough if audio routing, trust, pairing, or profile selection is broken.
- [ ] **GPU stack matches the hardware**: Mesa vs NVIDIA stack, Vulkan driver, firmware, and kernel module choice match the actual GPU vendor.
- [ ] **Gaming stack includes 32-bit userspace when needed**: Steam and Proton failures often come from missing multilib graphics pieces, not the game itself.
- [ ] **Capture stack is coherent**: portal backend, PipeWire, WebRTC or Electron client path, and any virtual camera module choice line up with the current session type.
- [ ] **Suspend and rollback claims are real**: hibernation, snapshots, and rollback advice matches the actual filesystem, boot path, and encryption layout.
- [ ] **CachyOS advice is not backported blindly**: optimized repos, custom pacman behavior, snapshot defaults, and kernel tooling are CachyOS-specific.
- [ ] **Snapshots are not backups**: on Btrfs systems, snapshots help with rollback but do not replace real backups.

---

## Workflow

### Step 1: Identify the distro lane first

| Distro | Default stance | What changes |
|--------|----------------|--------------|
| **Arch Linux** | Assume upstream Arch behavior | Vanilla repos, ArchWiki conventions, minimal distro wrappers |
| **CachyOS** | Treat as Arch-compatible with important extras | Optimized repos, custom kernels, snapshot defaults, extra tooling |
| **EndeavourOS** | Mostly Arch workflow | Installer and repo extras exist, but package and boot logic stays close to Arch |
| **Manjaro** | Slow down and check branch state | Own branches and timing; be conservative with AUR and repo-mixing advice |
| **Other Arch-based** | Confirm repo model before acting | Do not assume vanilla Arch support or package timing |

### Step 2: Gather current system state

Start with a narrow fact-gathering pass before prescribing changes:

```bash
cat /etc/os-release
uname -r
pacman -Q pacman systemd
pacman -Qm
systemctl --failed
journalctl -b -p warning..alert
findmnt /boot
findmnt /efi
bootctl status
lsblk -f
echo "Session=$XDG_SESSION_TYPE Desktop=$XDG_CURRENT_DESKTOP"
loginctl list-sessions 2>/dev/null || true
systemctl status display-manager 2>/dev/null || true
systemctl --user --failed 2>/dev/null || true
systemctl --user status pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user status xdg-desktop-portal 2>/dev/null || true
systemctl status power-profiles-daemon 2>/dev/null || true
command -v wpctl >/dev/null 2>&1 && wpctl status
command -v bluetoothctl >/dev/null 2>&1 && bluetoothctl show
pacman -Q obs-studio xdg-desktop-portal discord v4l2loopback-dkms 2>/dev/null
lspci -k | grep -Ei 'vga|3d|display'
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm'
journalctl --user -b | grep -Ei 'portal|pipewire|webrtc|obs'
lsmod | grep '^v4l2loopback'
findmnt -t btrfs
systemctl status fstrim.timer 2>/dev/null || true
ls /etc/*.pacnew /etc/*.pacsave 2>/dev/null
```

If `paru` is present, prefer it for day-to-day AUR workflow. Fall back to raw `makepkg` and
`pacman -U` when debugging build, key, or dependency issues.

### Step 3: Load only the relevant reference

| Task type | Reference |
|-----------|-----------|
| `pacman`, `paru`, AUR, mirrors, keyrings, `.pacnew` | `references/packages-and-aur.md` |
| systemd units, timers, journal, service overrides | `references/systemd-and-journal.md` |
| bootloader, kernel, initramfs, UKI, Secure Boot, recovery | `references/boot-kernel-and-recovery.md` |
| CachyOS repo, kernel, snapshot, or derivative-specific behavior | `references/cachyos-and-derivatives.md` |
| Wayland, X11, Hyprland, GNOME, KDE, PipeWire, Bluetooth | `references/desktop-audio-and-bluetooth.md` |
| Display managers, session startup, suspend or resume, laptop power, hybrid graphics | `references/session-display-and-mobile.md` |
| GPU drivers, Vulkan, Steam, Proton, Gamescope, gaming | `references/graphics-and-gaming.md` |
| OBS, WebRTC screen sharing, Discord or Teams issues, virtual cameras | `references/capture-and-sharing.md` |
| Btrfs, Snapper, LUKS, TRIM, hibernation, rollback limits | `references/storage-and-rollback.md` |
| Remote gaming and controllers | `references/remote-gaming-input-and-tooling.md` |
| Core Linux ops commands and optional CLI tools | `references/base-linux-and-cli.md` |
| Rolling-release footguns, edge cases, and special situations | `references/gotchas-and-special-situations.md` |

Do not load every reference by default. Pick the one that matches the failure mode.

### Step 4: Change one layer at a time

- Fix package state before debugging services that may be broken by stale libraries.
- Fix service configuration before declaring systemd itself broken.
- Fix mountpoints and loader state before rebuilding initramfs or UKIs.
- On CachyOS, separate "vanilla Arch behavior" from "optimized repo or custom kernel behavior."
- Prefer reversible steps: snapshots, package cache, fallback kernels, saved configs.

### Step 5: Validate before closing

```bash
pacman -Qk package_name
systemctl status unit_name
journalctl -u unit_name -b
bootctl status
```

Reboot only when the boot path is understood and at least one known-good entry remains.

---

## Troubleshooting Pattern

Keep triage cross-layer and boring:

1. Confirm the active distro, session type, kernel, and package lane.
2. Identify the failing layer: package state, system service, user service, boot path, desktop session, graphics, or app.
3. Pull the right logs before changing config.
4. Change one layer at a time and retest.
5. Prefer a known-good baseline over tweak stacking.

Core log sweep:

```bash
journalctl -b -p warning..alert
journalctl --user -b
dmesg --level=err,warn
journalctl -u unit_name -b
journalctl --user -u pipewire -u wireplumber -u xdg-desktop-portal -b
```

Practical interpretations:

- `journalctl -b` is the broad system picture for the current boot.
- `journalctl --user -b` matters for Wayland, PipeWire, portals, and desktop-session failures.
- `dmesg` is where kernel and driver problems surface first, especially boot, storage, and GPU issues.
- Focused unit logs beat random reinstall churn.

When a bug looks "desktop-only," compare one clean baseline:

- GNOME or Plasma vs Hyprland
- browser WebRTC vs packaged client
- plain game launch vs Gamescope or MangoHud
- known-good kernel vs newly changed kernel

---

## Default Decisions

- **Arch means full upgrades.** Package skew is often self-inflicted. Resolve sync state first.
- **Use systemd-native tools first.** Reach for `systemctl`, `journalctl`, `bootctl`, `timedatectl`, and `localectl` before distro wrappers.
- **Use `paru` for convenience, not for trust.** When an AUR package misbehaves, drop to `PKGBUILD`, `makepkg`, and the resulting package file.
- **Treat kernel and boot work as one subsystem.** Kernel package, initramfs generator, bootloader, microcode, and UKI signing all have to agree.
- **CachyOS advice is branch-sensitive.** Optimized repos and kernel variants can improve performance, but they add another compatibility layer to reason about.
- **Desktop failures are often session failures.** On Hyprland and other Wayland compositors, user units, portals, and session env matter as much as the package list.
- **Gaming failures are often stack mismatches.** Wrong GPU driver branch, missing multilib userspace, absent firmware, or a broken Proton path is more common than "Linux gaming is bad."

---

## Quick Triage Checklist

- Package weirdness after installing one package? Check whether the system is partially upgraded.
- Service fails after an update? Check for `.pacnew`, unit overrides, and journal errors from the current boot.
- System no longer boots after kernel work? Verify ESP mount, bootloader, initramfs generator, and whether the kernel package actually installed its artifacts.
- CachyOS instability after repo tuning? Re-check CPU capability, repo tier, and whether the system pulled the forked `pacman` package.
- AUR build failures? Inspect `PKGBUILD`, key requirements, pinned dependencies, and whether the package now conflicts with official repos.
- Hyprland desktop weirdness? Check `XDG_SESSION_TYPE`, portal backend, Xwayland availability, and user services before blaming the compositor.
- Hyprland lock, wallpaper, or idle weirdness? Separate compositor issues from `hyprpaper`, `hypridle`, `hyprlock`, and the bar or panel layer.
- Bluetooth audio weirdness? Check BlueZ pairing state, PipeWire node visibility, and the active card profile before reinstalling half the stack.
- Game launches then blackscreens or crashes? Verify GPU vendor stack, Vulkan userspace, Steam multilib, and whether Gamescope or MangoHud is the real fault injector.
- Discord or Teams cannot share a screen? Check Wayland vs X11, portal backend, PipeWire user units, and whether the browser path works before blaming Hyprland.
- Suspend or resume breaks the desktop? Check sleep state, GPU driver logs, lock-screen path, and display manager or greetd behavior before tuning power daemons.
- Snapshot rollback failed or booted strangely? Check subvolume layout, bootloader path, encryption, and whether rollback touched only root or also boot artifacts.
- A weird Arch problem makes no sense? Check the gotchas reference before inventing a new theory; partial upgrades, stale portals, DKMS mismatch, and bad session startup account for a lot.

---

## Reference Files

- `references/packages-and-aur.md` -- Arch package workflow, `paru`, manual AUR builds, keyring and mirror problems, `.pacnew` handling
- `references/systemd-and-journal.md` -- systemd service debugging, unit overrides, user units, journal triage, and safe edit flow
- `references/boot-kernel-and-recovery.md` -- kernel packages, mkinitcpio vs dracut, systemd-boot, UKIs, Secure Boot, and live-ISO recovery
- `references/cachyos-and-derivatives.md` -- CachyOS optimized repos, custom kernels, snapshot defaults, and brief derivative guidance
- `references/desktop-audio-and-bluetooth.md` -- X11 vs Wayland, Hyprland focus, GNOME and KDE notes, portals, PipeWire, and Bluetooth troubleshooting
- `references/session-display-and-mobile.md` -- GDM, SDDM, greetd, session env, suspend or resume, power profiles, and hybrid graphics routing
- `references/graphics-and-gaming.md` -- NVIDIA, AMD, Intel, Vulkan, Steam, Proton, Gamescope, MangoHud, GameMode, and why CachyOS gets attention from Linux gamers
- `references/capture-and-sharing.md` -- OBS, WebRTC screen sharing, Discord and Teams routing, hardware encoding, and virtual camera troubleshooting
- `references/storage-and-rollback.md` -- Btrfs, Snapper, LUKS, TRIM, hibernation, resume, and rollback boundaries
- `references/remote-gaming-input-and-tooling.md` -- Moonlight, Sunshine-style hosting, controllers, and Steam Remote Play
- `references/base-linux-and-cli.md` -- core Linux inspection commands and optional tools such as `nvim`, `jq`, `ripgrep`, `bat`, and `eza`
- `references/gotchas-and-special-situations.md` -- recurring Arch and CachyOS failure patterns, special cases, and what-to-do-next guidance

## Related Skills

- **command-prompt** -- use it for shell syntax, zsh or bash behavior, and script portability
- **networking** -- use it for network services, DNS, VPNs, and firewall design
- **docker** -- use it for container runtime and image concerns instead of host distro administration
- **ansible** -- use it when the real task is codifying Linux changes across many machines
- **security-audit** -- use it for hardening and security review rather than normal package or service administration
- **update-docs** -- use it after substantial system administration changes that introduce new operational gotchas

## Rules

1. **Identify the distro before prescribing commands.** Arch, CachyOS, EndeavourOS, and Manjaro differ where it matters most: repos, wrappers, and recovery assumptions.
2. **No partial upgrade advice.** If the fix begins with `pacman -Sy <pkg>`, it is probably wrong.
3. **Keep `paru`, but keep perspective.** Use it as the default AUR helper because the user does, then drop to raw AUR packaging when the failure gets real.
4. **Know the boot chain before touching it.** Confirm loader, ESP, kernel package, initramfs generator, and signing path first.
5. **Never remove the last known-good kernel path casually.** Especially on remote or encrypted systems.
6. **Prefer systemd-native diagnostics.** `systemctl`, `journalctl`, and `bootctl` usually tell you more than distro wrappers or generic forum folklore.
7. **CachyOS performance features are opt-in complexity.** Treat optimized repos, custom kernels, and scheduler tooling as additions that must be validated, not magic defaults.
8. **For Hyprland and Wayland issues, inspect the user session first.** Portals, user units, and Xwayland compatibility usually matter more than package reinstall churn.
9. **For gaming issues, identify the GPU vendor and userspace first.** Driver branch, Vulkan stack, multilib, and launch wrappers usually explain more than random tweak cargo cults.
10. **For Wayland capture issues, debug portals and PipeWire before app folklore.** OBS, browser WebRTC, Discord, and Teams often fail at the screencast path, not at "Linux video" in general.
11. **Treat display manager, lock screen, and idle helpers as separate layers.** GDM, SDDM, greetd, `hyprlock`, and `hypridle` can fail independently.
12. **Do not oversell snapshots or resume hooks.** Btrfs rollback, hibernation, and encrypted-root recovery all depend on the exact boot and storage layout.
13. **Reach for common Arch failure patterns before exotic explanations.** Partial upgrades, DKMS drift, portal mismatch, stale AUR packages, and bad session startup explain a large share of the chaos.
