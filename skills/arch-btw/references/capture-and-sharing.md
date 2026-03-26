# Capture and Sharing

On modern Arch desktops, screen sharing is usually a session and portal problem before it is an
OBS problem. The core path is:

1. compositor or desktop session
2. `xdg-desktop-portal` plus the correct backend
3. PipeWire and WirePlumber user services
4. app capture path: browser WebRTC, Electron client, OBS source, or virtual camera

This is why Discord, Teams, and OBS can all fail for what looks like the same reason on Wayland.

## First checks

Start with session facts and portal health:

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"
pacman -Q obs-studio xdg-desktop-portal xdg-desktop-portal-hyprland discord v4l2loopback-dkms 2>/dev/null
systemctl --user status xdg-desktop-portal pipewire pipewire-pulse wireplumber 2>/dev/null
journalctl --user -b | grep -Ei 'portal|pipewire|webrtc|obs'
lsmod | grep '^v4l2loopback'
```

If available, these help narrow the media side:

```bash
command -v wpctl >/dev/null 2>&1 && wpctl status
command -v ffmpeg >/dev/null 2>&1 && ffmpeg -hide_banner -encoders | grep -E 'nvenc|vaapi|amf|qsv'
```

## Wayland screen sharing model

On Wayland, apps usually do not scrape the screen directly the way old X11 tooling did.

- Browsers and many communication apps use WebRTC screen capture through XDG Desktop Portal and PipeWire.
- OBS on Wayland uses PipeWire capture sources instead of old X11 capture assumptions.
- If the portal backend is wrong or missing, the symptom can look app-specific even when the real break is shared infrastructure.

Operational stance:

- Hyprland users should expect portal wiring to matter more than on GNOME or Plasma.
- GNOME and Plasma usually provide more session glue by default, so they are useful baseline comparisons.
- If screen sharing works in GNOME but not Hyprland on the same machine, suspect portal or session composition first.

## Desktop routing

### Hyprland

On Hyprland, check the exact portal stack first.

- `xdg-desktop-portal`
- `xdg-desktop-portal-hyprland`
- running PipeWire and WirePlumber user units
- Xwayland installed for legacy apps that still assume X11

If screen share selectors do not appear, or apps hang on "loading sources," the portal path is usually the first suspect.

### GNOME

GNOME is a good "known integrated Wayland desktop" baseline.

- If browser screen sharing works in GNOME but not elsewhere, the lower stack is probably fine.
- If GNOME also fails, suspect PipeWire, portal state, or user-session problems rather than the app itself.

### KDE Plasma

Plasma Wayland sits between GNOME defaults and Hyprland manual composition.

- KWin plus the portal stack are part of the normal capture path.
- If capture breaks only in one app, compare browser WebRTC, native client, and OBS behavior before changing drivers.

## Discord and Teams

Treat Discord and Teams as capture clients, not as proof of how the desktop works.

Common routing:

- browser or PWA path: usually the cleanest way to test WebRTC screen sharing
- packaged Electron-style client: may lag browser behavior or expose extra Wayland quirks
- X11 session: can avoid some portal issues, but that does not mean the Wayland stack is fixed

Practical stance:

- If Discord or Teams cannot share a screen on Wayland, test the same workflow in a supported browser first.
- If browser sharing works but the packaged client does not, the app packaging or Electron layer is likely the differentiator.
- If neither works, focus on `xdg-desktop-portal`, backend choice, and PipeWire user services.

Do not treat "works in browser, fails in client" as random. That usually isolates the problem well.

## OBS on Arch

OBS is straightforward on Arch when the capture model matches the session:

- X11 session: traditional capture assumptions still work more often
- Wayland session: prefer PipeWire-backed sources and portal-mediated capture

Useful checks:

```bash
pacman -Q obs-studio
systemctl --user status xdg-desktop-portal pipewire wireplumber 2>/dev/null
journalctl --user -b | grep -Ei 'portal|pipewire|obs'
```

Important package reality:

- `obs-studio` in Arch depends on `pipewire`.
- `v4l2loopback-dkms` is optional for virtual camera support.
- portal backends are optional for Wayland window and screen capture.

If OBS opens but captures nothing on Wayland, suspect portals before reinstalling Mesa.

## Hardware encoding

Encoding problems are not the same as capture problems.

- NVIDIA: think NVENC
- AMD: think VA-API first, with AMF support depending on the app stack
- Intel: think VA-API or QSV depending on the tool and generation

The quick test is not "did OBS open." The quick test is whether the expected encoder exists:

```bash
ffmpeg -hide_banner -encoders | grep -E 'nvenc|vaapi|amf|qsv'
```

If capture works but recording or streaming fails under load, check the encoder path next.

## Virtual cameras

The common Arch path for virtual cameras is `v4l2loopback-dkms`.

What matters:

- the module must be present for the running kernel
- the module must actually be loaded
- the consumer app must see the loopback device as a camera

First checks:

```bash
pacman -Q v4l2loopback-dkms 2>/dev/null
lsmod | grep '^v4l2loopback'
find /usr/lib/modules -name 'v4l2loopback*.ko*' 2>/dev/null
```

On custom kernels, including CachyOS kernels, virtual camera issues are often simple module-build or module-load issues, not OBS issues.

## CachyOS angle

CachyOS matters here mostly because it adds moving parts:

- custom kernels
- different package cadence for some desktop pieces
- gaming-oriented defaults that make users test capture and streaming more aggressively

Why Linux gamers mention CachyOS:

- performance-focused kernels and repos
- gaming documentation
- common use with Steam, Gamescope, MangoHud, and Wayland desktops

That does not make capture stack problems disappear. It just means more users hit OBS, Discord, and Gamescope interactions sooner.

## Common failure splits

| Symptom | First suspicion |
|--------|-----------------|
| Browser can share, Discord cannot | packaged client or Electron path |
| Nothing can share on Wayland | portal backend, PipeWire, or session env |
| OBS opens but shows black capture | wrong source type or broken portal path |
| Virtual camera missing | `v4l2loopback` not built or not loaded |
| Recording works, stream encoder fails | hardware encode path, not screen capture |
| Works on GNOME, fails on Hyprland | missing Hyprland session glue or portal mismatch |

## What NOT to do

- Do not debug Discord or Teams screen sharing as if they bypass the portal stack on Wayland.
- Do not confuse capture problems with encoding problems; first prove whether the app can see a source.
- Do not assume OBS failure means GPU drivers are broken.
- Do not assume a packaged Electron client is a better reference than the browser path.
- Do not forget that custom kernels can break virtual camera modules independently of the rest of the desktop.
