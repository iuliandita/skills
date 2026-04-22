# Desktop, Audio, and Bluetooth

Use this reference for Fedora Workstation, KDE Spin, or similar desktop issues involving Wayland,
X11, PipeWire, portals, and Bluetooth routing.

## First-pass commands

```bash
echo "Session=$XDG_SESSION_TYPE Desktop=$XDG_CURRENT_DESKTOP"
loginctl list-sessions 2>&1 || true
systemctl --user --failed 2>&1 || true
systemctl --user status pipewire pipewire-pulse wireplumber xdg-desktop-portal 2>&1 || true
wpctl status 2>&1 || true
bluetoothctl show 2>&1 || true
```

## Notes

- GNOME on Fedora usually assumes Wayland first.
- KDE can flip between Wayland and X11 depending on driver quality.
- PipeWire and WirePlumber are usually the modern baseline.
- Portal mismatches break screen sharing more often than the app itself.
- Bluetooth audio issues often need card-profile inspection, not just pairing.

## SELinux reminder

Desktop weirdness from portals, screen sharing, or custom paths can still be SELinux-related.
Check AVCs before disabling half the session.
