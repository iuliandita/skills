# Security and Updates

Use this for AppArmor, unattended-upgrades, the Debian security suites, the Ubuntu security
pocket, and update hygiene.

## Contents

- Checks
- unattended-upgrades: is it working
- unattended-upgrades: configuration
- Debian security suites
- Ubuntu security pockets

## Checks

```bash
aa-status 2>&1 || true
journalctl -b | grep -Ei 'apparmor|denied' 2>&1 || true
apt list --upgradable 2>&1 | tail -n +2
apt-cache policy | grep -Ei 'security' 2>&1 || true   # is a security source configured at all
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer 2>&1 || true
needrestart -r l 2>&1 || true                         # list only, restarts nothing
ls -l /var/run/reboot-required 2>&1 || true
```

- AppArmor denials can look like random app failures.
- Security updates and firmware updates are separate concerns.
- `needrestart` reports services still running old libraries after an update; an installed fix is
  not an applied fix until they restart.

## unattended-upgrades: is it working

```bash
dpkg -l unattended-upgrades 2>&1 | tail -n 1
apt-config dump | grep -E 'APT::Periodic|Unattended-Upgrade'
cat /etc/apt/apt.conf.d/20auto-upgrades 2>&1 || true
systemctl status apt-daily.timer apt-daily-upgrade.timer 2>&1 || true
sudo unattended-upgrade --dry-run --debug             # simulates, installs nothing
tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log 2>&1 || true
tail -n 50 /var/log/unattended-upgrades/unattended-upgrades-dpkg.log 2>&1 || true
```

- It runs only when both `APT::Periodic::Update-Package-Lists "1";` and
  `APT::Periodic::Unattended-Upgrade "1";` are in effect. They normally sit in
  `/etc/apt/apt.conf.d/20auto-upgrades`; `apt-config dump` shows the merged result whatever file
  set them.
- `apt-daily.timer` refreshes package lists and `apt-daily-upgrade.timer` runs the upgrade. Both
  use a randomized delay, and a machine that was off can run them at the next boot.
- The dry run prints the allowed origins and the packages it would upgrade. "Allowed origins"
  that do not match what `apt-cache policy` prints for the security source is the usual reason
  nothing is installed. Search the log for "sanity check failed" when a run aborts.
- It holds back any package that would raise a conffile prompt or need a dependency from an
  origin that is not allowed; held packages are in the log, not in an error.

## unattended-upgrades: configuration

The shipped defaults are in `/etc/apt/apt.conf.d/50unattended-upgrades`. Put local settings in a
drop-in that sorts after it (Debian's wiki uses `52unattended-upgrades-local`) so package updates
do not collide with local edits.

| Option | Default | Notes |
|--------|---------|-------|
| `Unattended-Upgrade::Origins-Pattern` | Debian: the release codename with label `Debian` or `Debian-Security`, and `<codename>-security` | `keyword=value` matching against Release fields |
| `Unattended-Upgrade::Allowed-Origins` | Ubuntu: `<codename>`, `<codename>-security`, and the ESM origins | `origin:archive` pairs; `-updates`, `-proposed`, `-backports` are commented out |
| `Unattended-Upgrade::Package-Blacklist` | empty | Python regular expressions; a match is never upgraded |
| `Unattended-Upgrade::Automatic-Reboot` | `false` | reboots without confirmation when `/var/run/reboot-required` exists |
| `Unattended-Upgrade::Automatic-Reboot-Time` | `now` | for example `02:00` |
| `Unattended-Upgrade::Mail`, `MailReport` | unset, `on-change` | needs a working `mailx` |
| `Unattended-Upgrade::Remove-Unused-Dependencies` | `false` | the equivalent of `apt-get autoremove` after the run |

- `sudo dpkg-reconfigure -plow unattended-upgrades` turns the periodic run on or off.
- Changing origins, enabling automatic reboot, or disabling the service is consequential: show the
  drop-in and the dry-run output it produces, and get confirmation. An origin added here upgrades
  with no human in the loop, a PPA included.
- A blacklist entry or a hold on a package also blocks its security fixes. Record why and when it
  comes off.

## Debian security suites

- Security fixes for a release come from the `<codename>-security` suite on
  `security.debian.org/debian-security`, for example `trixie-security` or `bookworm-security`,
  with the same components as the main archive entry.
- `<codename>-updates` and `<codename>-backports` are separate suites and neither is a security
  source. Backports sit at priority 100, so nothing is installed from them unless asked for.
- Debian's default unattended-upgrades pattern takes the release itself and its security suite,
  not `-updates` or `-backports`.
- A host with no `-security` line in `apt-cache policy` is not receiving security fixes as they
  are published. Adding the suite is a source change; follow the confirmation steps in
  [packages and repos](packages-and-repos.md).
- Match on codename, not `stable`, in sources and patterns. A `stable` entry silently becomes the
  next release on release day.

## Ubuntu security pockets

Each Ubuntu series is split into pockets, named `<series>` for release and `<series>-<pocket>`
for the rest:

| Pocket | Contents |
|--------|----------|
| release | packages as first released; never updated afterwards, not even for security |
| `-security` | security fixes, built so that they need nothing from `-updates` |
| `-updates` | non-security updates, plus security fixes copied over from `-security` |
| `-proposed` | staging for updates under test; opt-in only |
| `-backports` | packages the series did not ship with; no security support from the Ubuntu Security Team |

- The security pocket is configured against `security.ubuntu.com`, not a mirror, so a slow mirror
  cannot delay a fix. Keep that entry when switching the other pockets to a mirror.
- Ubuntu 24.04 LTS and later keep these in deb822 form in `/etc/apt/sources.list.d/ubuntu.sources`.
- `-security` and `-updates` both at priority 500 for the same version in `apt-cache policy` is
  normal, not a duplicate source.
- The default `Allowed-Origins` installs from the release pocket, `-security`, and the ESM
  origins (Ubuntu Pro) only.
  Enabling `-updates` there is a policy change: it adds unattended feature and bug-fix updates.
- Security coverage depends on the component and on Ubuntu Pro; check the series' current
  support status before promising that a `universe` package is patched.
