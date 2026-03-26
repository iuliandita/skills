# systemd and Journal

On Arch and CachyOS, systemd is usually the fastest path to the truth. Start with unit state, then
read the journal from the affected boot, then inspect overrides.

## Core commands

| Task | Command | Notes |
|------|---------|-------|
| Show status | `systemctl status unit_name` | First stop for unit health and recent logs |
| Failed units | `systemctl --failed` | Fast degraded-system view |
| Unit file and drop-ins | `systemctl cat unit_name` | Shows vendor unit plus overrides |
| Restart service | `sudo systemctl restart unit_name` | Use after config change and reload where needed |
| Enable now | `sudo systemctl enable --now unit_name` | Persist and start |
| Disable now | `sudo systemctl disable --now unit_name` | Persist and stop |
| Edit override | `sudo systemctl edit unit_name` | Preferred over editing vendor units |
| Reload unit files | `sudo systemctl daemon-reload` | Required after unit-file changes |
| Current boot logs | `journalctl -b` | Boot-scoped logs |
| Previous boot logs | `journalctl -b -1` | Useful after failed reboot |
| Unit logs, current boot | `journalctl -u unit_name -b` | Narrow and usually sufficient |
| Follow logs | `journalctl -f` | Live log tail |
| Priority filter | `journalctl -p err..alert` | Higher-severity log slice |
| User unit status | `systemctl --user status unit_name` | For per-user services |
| User unit logs | `journalctl --user -u unit_name` | User session journal |

## Safe debugging order

1. `systemctl status unit_name`
2. `systemctl cat unit_name`
3. `journalctl -u unit_name -b`
4. inspect related config files
5. `sudo systemctl daemon-reload` if unit files changed
6. `sudo systemctl restart unit_name`
7. re-check status and journal

That sequence catches most bad overrides, missing env files, path typos, and startup ordering issues.

## Unit file locations

| Scope | Typical path | Notes |
|-------|--------------|-------|
| Vendor system units | `/usr/lib/systemd/system/` | Package-owned; avoid editing directly |
| Local system overrides | `/etc/systemd/system/` | Your drop-ins and custom units |
| User units | `~/.config/systemd/user/` | Per-user services and timers |

Prefer overrides in `/etc/systemd/system/<unit>.d/*.conf` or `systemctl edit` over editing vendor
files in `/usr/lib/systemd/system/`.

## Common Arch-specific traps

- A package upgrade installed a `.pacnew`, but the active config never got merged.
- A service file changed upstream and your old drop-in now overrides the wrong setting.
- You edited a unit file and forgot `daemon-reload`.
- The service is actually a user unit, but you keep checking the system manager.
- The service binary moved between package versions, but the override still points to the old path.

## Timers and sockets

If a service appears "inactive", check whether a timer or socket is the real entry point:

```bash
systemctl list-timers
systemctl list-sockets
```

Then inspect the paired units:

```bash
systemctl status name.timer
systemctl status name.socket
systemctl status name.service
```

## Journal reading habits that save time

- Use `-b` to stay inside the relevant boot first.
- Use `-u` to avoid drowning in unrelated logs.
- Use `-p` when you only need errors and above.
- Use `-b -1` after a failed reboot or broken kernel change.
- Use `--user` only for per-user services.

## What NOT to do

- Do not edit packaged unit files in `/usr/lib/systemd/system/` unless you are deliberately replacing the vendor unit and understand the maintenance cost.
- Do not assume "service failed" means the service is wrong. Dependency, mount, path, credential, and sandbox failures are common.
- Do not restart blindly without reading the journal from the affected boot.
- Do not forget that boot issues can surface as service failures even when the root cause is package or initramfs state.
