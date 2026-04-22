# Desktop, Audio, and Bluetooth

Use this for Wayland, X11, GNOME, KDE, Cinnamon, COSMIC, PipeWire, and Bluetooth.

## Checks
- `echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"`
- `systemctl --user status pipewire pipewire-pulse wireplumber`
- `systemctl --user status xdg-desktop-portal`
- `wpctl status`
- `bluetoothctl show`

## Notes
- Match compositor, portal backend, and session services.
- If audio is broken, check leftover PulseAudio before reinstalling PipeWire.
- Bluetooth audio depends on pairing, trust, and profile selection.
