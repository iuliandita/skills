# Session, Display, and Mobile

Use this reference for display managers, session startup, suspend or resume, power profiles, and
hybrid graphics on laptops.

## Gather facts

```bash
systemctl status display-manager 2>&1 || true
loginctl session-status 2>&1 || true
systemctl --user show-environment 2>&1 || true
systemctl status power-profiles-daemon 2>&1 || true
journalctl -b | grep -Ei 'suspend|resume|sleep|acpi|battery|nvidia|amdgpu' 2>&1 || true
```

## Patterns

- GDM and SDDM failures are separate from compositor failures.
- Resume failures are often GPU, lock-screen, or firmware interactions.
- Power-profile changes can affect hybrid graphics and suspend behavior.
- Session env problems break portals, keyrings, and user services in weird ways.
