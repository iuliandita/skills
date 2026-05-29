# systemd and Journal

Use this for unit failures, boot timing, user services, timers, and logs on systemd-based
Debian/Ubuntu systems. Note the Devuan exception: Devuan does not use systemd by default, so verify
PID 1 (`ps -p 1 -o comm=`) before assuming `systemctl` exists.

## Inspect first

```bash
systemctl --failed
systemctl status <unit>
systemctl is-enabled <unit>
systemctl is-active <unit>
journalctl -b -p warning..alert
journalctl -u <unit> -b
systemctl --user --failed
journalctl --user -b
systemd-analyze blame | head -20
```

- `systemctl --failed` is the fastest triage: it lists units in a failed state cluster-wide.
- `journalctl -u <unit> -b` scopes logs to one unit for the current boot. Add `-f` to follow,
  `-e` to jump to the end, `--no-pager` for scripting.
- `systemd-analyze blame` and `systemd-analyze critical-chain` find slow-boot units.

## System vs user units

```bash
systemctl status <unit>            # system manager (PID 1)
systemctl --user status <unit>     # per-user manager (desktop/session services)
loginctl show-user "$USER" 2>&1 || true
```

- System units run as root under PID 1; user units run under `systemd --user` and only while the
  user has a session (unless lingering is enabled with `loginctl enable-linger`).
- Desktop-session services (PipeWire, WirePlumber, xdg-desktop-portal) are user units. Debugging
  them with plain `systemctl` (no `--user`) looks up the wrong manager and reports "unit not found."

## Overrides (the correct way to edit units)

```bash
systemctl cat <unit>                       # see the effective unit + any drop-ins
sudo systemctl edit <unit>                 # create a drop-in under /etc/systemd/system/<unit>.d/
sudo systemctl edit --full <unit>          # override the whole unit file
sudo systemctl daemon-reload               # reload after manual file edits
systemctl show <unit> -p FragmentPath,DropInPaths
```

- Prefer drop-ins (`systemctl edit`) over editing files under `/lib/systemd/system` or
  `/usr/lib/systemd/system`; package upgrades overwrite those. Drop-ins in `/etc` survive upgrades.
- After hand-editing any unit file, run `daemon-reload` or systemd keeps the old definition.
- `systemctl cat` shows the merged result including drop-ins, which is what actually runs.

## Timers (systemd's cron replacement)

```bash
systemctl list-timers --all
systemctl status <unit>.timer
journalctl -u <unit>.service -b      # the timer triggers a .service of the same name
```

A timer (`foo.timer`) activates a service (`foo.service`). To see why a scheduled job failed, read
the `.service` journal, not the `.timer`. `OnCalendar=` and `Persistent=` in the timer control
schedule and catch-up after downtime.

## Masking, enabling, and boot state

```bash
systemctl enable --now <unit>        # enable at boot and start now
systemctl disable --now <unit>       # disable at boot and stop now
systemctl mask <unit>                # symlink to /dev/null; cannot be started until unmasked
systemctl unmask <unit>
```

A `masked` unit cannot start by any means until unmasked - a common "service refuses to start for no
reason" cause. Check `systemctl status` for the `masked` state.

## Notes

- Distinguish system and user units before debugging; the wrong manager reports false "not found."
- Check overrides with `systemctl cat <unit>`; a drop-in may be changing behavior invisibly.
- `daemon-reload` after editing any unit file by hand.
- On Devuan or other non-systemd Debian derivatives, none of this applies - check the actual init
  (sysvinit, OpenRC, runit) first.
