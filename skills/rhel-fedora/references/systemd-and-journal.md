# systemd and Journal

Use this reference for service startup failures, timer issues, journal triage, overrides, or
user-session service problems.

## First-pass commands

```bash
systemctl --failed
systemctl status unit_name
journalctl -u unit_name -b
journalctl -b -p warning..alert
systemctl list-timers --all
systemctl cat unit_name
systemctl show unit_name | grep -E 'FragmentPath|DropInPaths|Environment='
```

For desktop and Wayland problems, add:

```bash
systemctl --user --failed
journalctl --user -b
systemctl --user status pipewire wireplumber xdg-desktop-portal
```

## Read the unit before editing

Check the shipped unit and every override before making claims:

```bash
systemctl cat unit_name
find /etc/systemd /usr/lib/systemd /run/systemd -type f | grep unit_name 2>&1 || true
```

## Safe override flow

Use drop-ins for environment or small exec changes. Do not patch vendor units casually.

```bash
systemctl edit unit_name
systemctl daemon-reload
systemctl restart unit_name
systemctl status unit_name
```

## Common RPM-family traps

- Service exists but package is missing files: `rpm -V package_name`
- Service starts manually but not under systemd: environment, permissions, SELinux, or sandboxing
- Service bound to port but unreachable: `firewalld`, SELinux labels, or wrong bind address
- Desktop service weirdness: the problem is under `systemctl --user`, not system scope
- Repeated restarts after update: old config or changed defaults, not always "systemd is broken"

## Journal reading heuristics

- `journalctl -u unit -b` for the focused story
- `journalctl -b` for cross-unit correlation
- `journalctl --user -b` for desktop and session problems
- `-p warning..alert` trims noise fast

When SELinux is involved, correlate the journal with AVC output instead of guessing.
