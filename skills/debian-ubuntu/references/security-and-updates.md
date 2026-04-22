# Security and Updates

Use this for AppArmor, unattended-upgrades, security maintenance, and update hygiene.

## Checks
- `aa-status`
- `journalctl -b | grep -Ei 'apparmor|denied'`
- `apt list --upgradable`
- `systemctl status unattended-upgrades`
- `needrestart -r l` if installed

## Notes
- AppArmor denials can look like random app failures.
- Security updates and firmware updates are separate concerns.
