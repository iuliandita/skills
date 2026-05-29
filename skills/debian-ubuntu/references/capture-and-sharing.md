# Capture and Sharing

Use this for OBS, browser screen sharing, Discord, Teams, WebRTC, and virtual cameras on
Debian/Ubuntu. On Wayland, screen capture goes through the xdg-desktop-portal ScreenCast interface
backed by PipeWire. Most "screen share is black/blank" reports are a broken portal or PipeWire path,
not the app.

## Inspect first

```bash
echo "Session=$XDG_SESSION_TYPE Desktop=$XDG_CURRENT_DESKTOP"
systemctl --user status xdg-desktop-portal 2>&1 || true
systemctl --user status pipewire pipewire-pulse wireplumber 2>&1 || true
journalctl --user -b | grep -Ei 'portal|pipewire|webrtc|obs|screencast' 2>&1 || true
dpkg -l | grep -E 'xdg-desktop-portal' | grep '^ii'
```

- `XDG_SESSION_TYPE` determines the capture path: `wayland` uses the portal + PipeWire ScreenCast;
  `x11` uses direct X11 capture and does not need the portal for screen grabbing.
- These are user units. Use `systemctl --user`; a plain `systemctl` reports the wrong manager.

## Portal backend must match the desktop

```bash
dpkg -l | grep -E 'xdg-desktop-portal-(gtk|gnome|kde|wlr|hyprland|cosmic)' | grep '^ii'
ls /usr/share/xdg-desktop-portal/portals/ 2>&1 || true
```

`xdg-desktop-portal` is a frontend that delegates to a backend implementation. The ScreenCast
interface only works if the right backend for the compositor is installed and selected:

| Desktop | ScreenCast backend package |
|---------|---------------------------|
| GNOME | `xdg-desktop-portal-gnome` |
| KDE Plasma | `xdg-desktop-portal-kde` |
| wlroots (Sway, etc.) | `xdg-desktop-portal-wlr` |
| COSMIC | `xdg-desktop-portal-cosmic` |

`xdg-desktop-portal-gtk` alone does NOT provide ScreenCast on most compositors - it covers file
chooser and settings, not screen capture. A blank Wayland share with only the GTK backend installed
is the classic missing-backend case. Install the compositor-matching backend.

## Browser and Electron clients (Discord, Teams, web meetings)

- Chromium/Chrome and Electron apps need WebRTC PipeWire support to capture on Wayland. Modern
  Chromium builds enable it by default; very old packaged builds may need the
  `WebRTCPipeWireCapturer` feature flag. Prefer the up-to-date browser package over flag-tweaking.
- Discord and Teams ship as Electron. If screen share is blank on Wayland, the cause is the same
  portal/PipeWire path as everything else - test sharing in a browser first to isolate app vs stack.
- Test order: browser WebRTC vs packaged Electron client. If the browser captures and the client
  does not, the fault is in the app's Electron/portal handling, not the system stack.

## OBS

```bash
journalctl --user -b | grep -Ei 'obs|pipewire|portal' 2>&1 || true
```

- On Wayland, OBS captures the screen via the PipeWire/portal "Screen Capture (PipeWire)" source,
  not the X11 "Screen Capture (XSHM)" source. Selecting the wrong source on Wayland yields a black
  capture.
- If OBS comes from a snap or flatpak, confinement/interface state affects portal and device access;
  check `snap connections obs-studio` or `flatpak permissions` before assuming a config bug.

## Virtual camera (v4l2loopback)

```bash
lsmod | grep '^v4l2loopback'
dpkg -l | grep -E 'v4l2loopback' | grep '^ii'
ls -1 /dev/video* 2>&1 || true
modinfo v4l2loopback 2>&1 | head -5 || true
```

- The OBS virtual camera and similar tools need the `v4l2loopback` kernel module loaded. It is DKMS
  on Debian/Ubuntu (`v4l2loopback-dkms`), so it rebuilds per kernel - check `dkms status` after a
  kernel update if `/dev/video*` virtual devices disappear.
- A consuming app must support the loopback device; some apps filter by reported pixel formats, so
  the exclusive-caps/label module options can matter.

## Notes

- Most capture failures are portal or PipeWire path failures, not the app.
- The ScreenCast portal backend must match the compositor; the GTK backend alone is not enough.
- Wayland uses the PipeWire ScreenCast source; X11 uses direct capture. Pick the matching source.
- Virtual cameras depend on the `v4l2loopback` module being loaded and built for the running kernel.
