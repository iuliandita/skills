# Session, Display, and Mobile

Many "desktop bugs" on Arch are really session-startup bugs. Before touching PipeWire, portals, or
GPU drivers, identify how the session is started and what owns the environment.

## First checks

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP $DESKTOP_SESSION"
systemctl status display-manager 2>/dev/null || true
loginctl list-sessions 2>/dev/null || true
systemctl status power-profiles-daemon 2>/dev/null || true
journalctl -b | grep -Ei 'gdm|sddm|greetd|seat|logind|suspend|resume|acpi|power'
```

For laptop or hybrid-GPU machines, add:

```bash
lspci -k | grep -Ei 'vga|3d|display'
cat /sys/power/mem_sleep 2>/dev/null
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|suspend|resume'
```

## Display manager routing

### GDM

GDM is the GNOME-first path and a useful integrated baseline.

- Usually the least surprising route for GNOME Wayland sessions
- Good comparison point when Hyprland or greetd launches produce missing env vars or session helpers
- If GDM works and a manual TTY launch does not, suspect session startup and environment propagation before suspecting PipeWire or Mesa

### SDDM

SDDM is common on Plasma and mixed desktop systems.

- Stronger fit for KDE-oriented setups
- Wayland support exists, but config and greeter theme tweaks can add noise quickly
- If Plasma under SDDM behaves but Hyprland under greetd does not, that does not prove a system-wide multimedia bug

### greetd

`greetd` is common on Hyprland machines because it is minimal and composable.

- Good when you want explicit control
- Bad if you forget that explicit control means you also own more session glue
- Be careful with environment propagation, autostart assumptions, and user-session helpers

If a user launches Hyprland from TTY, `greetd`, or a custom script, treat that startup path as part of the bug.

## Hyprland session glue

Hyprland itself does not provide a whole desktop.

Common companion pieces:

- `hyprpaper` for wallpaper
- `hypridle` for idle actions
- `hyprlock` for lock screen
- `waybar` or another panel layer
- notification daemon
- polkit agent
- clipboard helper

Operational rule:

- If the desktop "comes up weird," separate compositor, greeter, portal, lock, idle, and panel layers instead of treating them as one blob.

## Suspend and resume

Suspend and resume bugs are often one of:

1. GPU driver resume failure
2. lock-screen or idle-helper failure
3. display manager or session restart issue
4. firmware or ACPI quirk

Useful checks:

```bash
journalctl -b | grep -Ei 'suspend|resume|sleep|acpi'
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm'
systemctl status power-profiles-daemon 2>/dev/null || true
```

On Hyprland, do not assume a post-resume black screen means Hyprland itself is at fault. `hyprlock`,
`hypridle`, DPMS behavior, and GPU resume all need to be separated.

## Power profiles and laptop tuning

`power-profiles-daemon` is the normal desktop-friendly power layer on many Arch systems.

Useful checks:

```bash
systemctl status power-profiles-daemon
command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl list
command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get
```

`tlp` also exists, but do not stack multiple power-management strategies casually and then wonder why suspend, USB, Bluetooth, or clocks behave strangely.

## Hybrid graphics

Laptop graphics bugs often come from muxless or PRIME-style setups.

- External-display behavior may differ from the internal panel path
- Suspend or resume bugs can appear only when the discrete GPU was active
- On NVIDIA laptops, PRIME assumptions are a frequent source of confusion

Treat "laptop graphics" as a session-plus-driver problem, not only a driver problem.

## What NOT to do

- Do not debug a greetd or TTY-launched Hyprland session as if it were a full GNOME session with all env vars implied.
- Do not blame `power-profiles-daemon` first for every suspend or resume bug.
- Do not treat lock, idle, panel, and compositor failures as the same layer.
- Do not assume external-monitor failures on hybrid laptops match the internal-panel path.
