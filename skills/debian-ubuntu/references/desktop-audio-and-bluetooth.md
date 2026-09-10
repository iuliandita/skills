# Desktop, Audio, and Bluetooth

Use this for Wayland, X11, GNOME, KDE, Cinnamon, COSMIC, PipeWire, and Bluetooth.

## Checks
- `echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"`
- `systemctl --user status pipewire pipewire-pulse wireplumber`
- `systemctl --user status xdg-desktop-portal`
- `wpctl status`
- `bluetoothctl show`
- `pactl list cards short` and `pactl list cards` for available vs active Bluetooth profiles

## Bluetooth profile switching
A device that connects but sounds wrong is usually a profile choice, not a pairing fault.
`a2dp-sink` is the music profile; `headset-head-unit`/`handsfree-head-unit` enable the mic at
much lower quality. WirePlumber switches to the headset profile whenever an app opens a
microphone.

- Set it for this session: `pactl set-card-profile bluez_card.AA_BB_CC_DD_EE_FF a2dp-sink`
- Stop the auto-switch persistently on WirePlumber 0.5.x with a drop-in in
  `~/.config/wireplumber/wireplumber.conf.d/`: set `bluez5.autoswitch-profile = false`, and drop
  the `hsp_*`/`hfp_*` entries from `bluez5.roles` only if the headset mic is not needed.
- Check `wireplumber --version` first: 0.4 used `~/.config/wireplumber/bluetooth.lua.d/`, and
  mixing the two config formats silently does nothing.

## Notes
- Match compositor, portal backend, and session services.
- If audio is broken, check leftover PulseAudio before reinstalling PipeWire.
- Bluetooth audio depends on pairing, trust, and profile selection.
- Mint Cinnamon defaults to X11: screen capture there is direct, not portal-mediated. Confirm
  `XDG_SESSION_TYPE` before prescribing portal fixes.
