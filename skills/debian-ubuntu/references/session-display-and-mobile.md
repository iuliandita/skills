# Session, Display, and Mobile

Use this for display managers, login sessions, suspend/resume, power, and laptop graphics.

## Checks
- `systemctl status display-manager`
- `loginctl list-sessions`
- `systemctl status power-profiles-daemon`
- `journalctl -b | grep -Ei 'suspend|resume|sleep|gdm|sddm|lightdm'`

## Notes
- Identify the display manager and launch path before debugging the session.
- Hybrid graphics changes the output path on laptops.
