# Capture and Sharing

Use this for OBS, browser screen sharing, Discord, Teams, WebRTC, and virtual cameras.

## Checks
- `systemctl --user status xdg-desktop-portal`
- `systemctl --user status pipewire wireplumber`
- `journalctl --user -b | grep -Ei 'portal|pipewire|webrtc|obs'`
- `lsmod | grep '^v4l2loopback'`

## Notes
- Most capture failures are portal or PipeWire path failures.
- Virtual cameras depend on matching session and module state.
