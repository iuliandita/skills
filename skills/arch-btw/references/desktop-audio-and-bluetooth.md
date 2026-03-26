# Desktop, Audio, and Bluetooth

Arch does not hide the desktop stack from you. When graphics, portals, audio, or Bluetooth break,
the fix usually comes from identifying the active session model and then checking the right layer.

## X11 vs Wayland

| Stack | Best fit | Common failure mode | First checks |
|-------|----------|---------------------|--------------|
| **Wayland** | Modern GNOME, Plasma, Hyprland, laptop and multi-monitor setups | Portals, screen sharing, old X11 apps, NVIDIA quirks, input/session env | `echo $XDG_SESSION_TYPE`, portal backend, `xorg-xwayland` |
| **X11** | Legacy app compatibility, older workflows, some niche tooling | Tearing, global input exposure, older session glue | display manager, Xorg logs, compositor config |
| **Xwayland** | Running X11 apps inside Wayland | Clipboard, scaling, window rules, games, some input oddities | `xorg-xwayland` installed, compositor support, per-app behavior |

Rules of thumb:

- Do not tell a Wayland user to debug everything as if it were native Xorg.
- Do not tell an X11 user to fix a missing portal or screencast backend that only matters in Wayland sessions.
- If the desktop is Hyprland, assume Wayland first and treat X11 behavior as compatibility mode through Xwayland.

## Desktop environment and compositor routing

### DE vs WM framing

This distinction matters on Arch because troubleshooting depth changes with it.

| Model | Examples | What is usually bundled | What you often assemble yourself |
|-------|----------|-------------------------|----------------------------------|
| **Full desktop environment** | GNOME, KDE Plasma | session glue, settings UI, applets, notification stack, more default integration | less, unless you strip pieces out |
| **Window manager / compositor first** | Hyprland, sway, i3 | window management, little or no full desktop glue | portals, bars, launchers, polkit agent, lock screen, idle handling, more |

If a problem appears only on a WM-style setup, suspect missing session helpers before suspecting the kernel, Mesa, or PipeWire.

### Hyprland

Hyprland is a Wayland compositor, not a full desktop environment. That means session glue matters:

- compositor config
- Xwayland support for legacy apps
- a portal backend such as `xdg-desktop-portal-hyprland`
- wallpaper, bar or panel, notifications, polkit agent, and lock or idle helpers
- PipeWire for screen sharing and media routing

Useful first checks:

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"
pacman -Q hyprland hyprpaper hyprlock hypridle waybar xdg-desktop-portal xdg-desktop-portal-hyprland xorg-xwayland 2>/dev/null
systemctl --user status pipewire pipewire-pulse wireplumber 2>/dev/null
journalctl --user -b | grep -Ei 'hypr|portal|pipewire'
```

Hyprland-specific stance:

- Focus on user-session health before package churn.
- Portal breakage often explains screenshots, file pickers, screen sharing, and some app integration failures.
- If an app is X11-only, reason about Xwayland compatibility instead of blaming Hyprland in the abstract.
- `hyprpaper`, `hypridle`, `hyprlock`, and the bar or panel layer are adjacent tools, not the compositor itself. Failures there can look like "Hyprland is broken" when they are really session-helper issues.
- Wallpaper helpers are cosmetic. Lock and idle helpers are not. A bad `hypridle` or `hyprlock` path can show up as resume, unlock, blank-screen, or power-state problems.
- The common bar on Arch Hyprland setups is `waybar`. Some users loosely call this layer "hyprbar," but it is still a separate bar or panel component, not part of Hyprland itself. Treat bar crashes, missing modules, or bad custom scripts as panel issues first, not graphics-stack failures.

### GNOME

GNOME is a full desktop environment with stronger defaults and more integrated services.

- Default session is Wayland.
- X11 apps usually run through Xwayland.
- Bluetooth and media controls are more integrated, so applet issues can look smaller even when the underlying stack is the same.
- GNOME session behavior is usually the reference case for "Wayland desktop works out of the box."

Useful first checks:

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"
systemctl --user --failed
systemctl --user status pipewire pipewire-pulse wireplumber 2>/dev/null
gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null
journalctl --user -b | grep -Ei 'gnome-shell|mutter|portal|pipewire'
```

What to look for:

- If GNOME works and Hyprland does not, that usually points to missing Wayland session glue on Hyprland rather than a system-wide multimedia failure.
- If GNOME itself has broken portals, screen sharing, or audio routing, suspect the lower stack first: PipeWire, WirePlumber, XDG portals, or BlueZ.
- GNOME tends to hide complexity. Do not confuse a polished control panel with proof that the underlying services are healthy.

Use GNOME as the "integrated desktop" baseline, not as the model for how Hyprland works internally.

### KDE Plasma

Plasma is a full desktop environment with a Wayland-capable compositor stack via KWin.

- More configurable than GNOME
- Better apples-to-apples comparison with Hyprland on "Wayland but customizable"
- KDE applets such as `plasma-pa` and `bluedevil` can mask or expose lower-level PipeWire and BlueZ issues depending on how they fail

Useful first checks:

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"
systemctl --user --failed
systemctl --user status pipewire pipewire-pulse wireplumber 2>/dev/null
journalctl --user -b | grep -Ei 'kwin|plasma|xdg-desktop-portal|pipewire'
```

What to look for:

- On Plasma Wayland, KWin and the portal stack are part of the normal session story. Screen sharing and picker issues are often portal or user-session issues, not generic "Wayland is broken."
- If Plasma audio applets fail but `wpctl status` and `pactl info` look healthy, the fault may be in the desktop integration layer rather than PipeWire itself.
- Plasma is a good midpoint between GNOME's stronger defaults and Hyprland's more manual composition.

If a user says "KDE handles this fine but Hyprland does not," suspect portals, XDG session variables, or missing session helpers before suspecting PipeWire itself.

### Other common Arch desktops

Keep these routing hints short but explicit:

- **Xfce, Cinnamon, MATE**: often still involve X11 assumptions more often than GNOME or Plasma. Check whether the bug is session-type-specific before giving Wayland-only advice.
- **sway**: closer to Hyprland than to GNOME or Plasma in troubleshooting shape. Expect compositor-plus-tools debugging, not DE-style integration.
- **i3**: usually X11-first. Do not prescribe Wayland portal fixes unless the user is explicitly running a mixed or migrated setup.

## PipeWire and WirePlumber

On modern Arch systems, PipeWire is the normal answer unless the user explicitly chose otherwise.

Core packages in the usual stack:

- `pipewire`
- `pipewire-pulse`
- `wireplumber`

Useful commands:

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
wpctl status
wpctl get-volume @DEFAULT_AUDIO_SINK@
pactl info
pactl list short sinks
pactl list short sources
```

Operational rules:

- `pipewire-pulse` is the PulseAudio compatibility layer most desktop apps expect.
- WirePlumber is the session and policy manager. If audio devices appear and disappear strangely, check it early.
- Do not mix "leftover PulseAudio" assumptions into a PipeWire system without evidence.

Fast interpretations:

- `pactl info` server name should make sense for PipeWire-backed PulseAudio compatibility.
- `wpctl status` shows the real node and default-device picture more clearly than guessing from an applet.
- User-unit failures matter more than system-unit status for PipeWire on desktops.

## PipeWire plus Bluetooth audio

Bluetooth audio lives across multiple layers:

1. BlueZ controller and pairing
2. PipeWire media graph
3. WirePlumber policy and profile selection

Check all three before changing packages.

Useful commands:

```bash
systemctl status bluetooth
bluetoothctl show
bluetoothctl devices
bluetoothctl info MAC_ADDRESS
wpctl status
wpctl inspect ID
pactl list cards short
```

Common failure patterns:

- Device pairs but no audio node appears: BlueZ succeeded, PipeWire or WirePlumber integration did not.
- Device connects with the wrong profile: inspect card profile and route selection.
- Headset microphone missing: profile or codec path is wrong, not necessarily "Bluetooth is broken."
- GUI applet fails but CLI works: desktop integration bug, not stack failure.

## BlueZ basics

Arch package split matters:

- `bluez` provides the daemon
- `bluez-utils` provides tools such as `bluetoothctl`

Typical service check:

```bash
systemctl status bluetooth
```

Typical CLI pairing flow:

```text
bluetoothctl
power on
scan on
pair MAC_ADDRESS
trust MAC_ADDRESS
connect MAC_ADDRESS
```

Treat pairing, trust, and connect as separate states. "It shows up in the UI" is not enough.

## What NOT to do

- Do not debug Hyprland as if it were a full GNOME-style desktop with all helpers implied.
- Do not debug GNOME or Plasma as if they were bare compositors with no session integration; they ship more working assumptions by default.
- Do not assume X11 advice applies unchanged under Wayland.
- Do not chase Bluetooth audio problems only in `bluetoothctl`; PipeWire and WirePlumber decide whether the device becomes a usable audio node.
- Do not restart random user services until you know whether the session is Hyprland, GNOME, Plasma, X11, or Wayland.
