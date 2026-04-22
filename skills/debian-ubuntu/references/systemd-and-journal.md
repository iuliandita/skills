# systemd and Journal

Use this for unit failures, boot timing, user services, and logs.

## Checks
- `systemctl --failed`
- `systemctl status unit_name`
- `journalctl -b -p warning..alert`
- `journalctl -u unit_name -b`
- `systemctl --user --failed`
- `journalctl --user -b`

## Notes
- Distinguish system and user units.
- Check overrides with `systemctl cat unit_name`.
- Use `systemctl --user` only for desktop-session services.
