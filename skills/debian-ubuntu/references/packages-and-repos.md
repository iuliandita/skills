# Packages and Repos

Use this when the problem is apt, dpkg, pinning, repository sources and keys, PPAs, snaps,
Flatpaks, or a local `.deb` file.

## Contents

- Inspect first
- Common moves
- Pinning
- Sources and keyrings
- Snaps
- Flatpak
- Local .deb files

## Inspect first

```bash
apt-cache policy                      # every source with its priority and release fields
apt-cache policy package_name         # installed, candidate, and the version table
apt-mark showhold
dpkg --audit                          # half-installed or unconfigured packages
ls /etc/apt/sources.list /etc/apt/sources.list.d/ /etc/apt/preferences /etc/apt/preferences.d/ 2>&1 || true
ls -l /etc/apt/keyrings/ /usr/share/keyrings/ /etc/apt/trusted.gpg.d/ 2>&1 || true
apt-get -s full-upgrade               # simulate: prints the plan, changes nothing
```

## Common moves

- Prefer `apt install package` for new installs; `apt full-upgrade` when a transition needs
  removals or replacements. Simulate first with `apt-get -s`.
- `sudo dpkg --configure -a` after an interrupted run, then `sudo apt-get -f install` when
  dependencies are still broken.
- `sudo apt-mark hold package` blocks upgrades of one package and `unhold` releases it; simpler
  than a pin when the goal is "do not touch this".
- Use `add-apt-repository` only after checking the source and key. Use `ppa-purge` or a manual
  downgrade when a PPA breaks the system; a purge is consequential, so show its plan first.

## Pinning

Preferences live in `/etc/apt/preferences` and `/etc/apt/preferences.d/`. Files there need no
extension or `.pref`, and names may only use letters, digits, `-`, `_`, and `.`; APT ignores
anything else with a notice. Pins choose between versions; they never choose between two sources
that carry the same version.

Default priorities, before any preferences file:

| Priority | Assigned to |
|----------|-------------|
| 990 | versions in the target release (`APT::Default-Release` or `-t release`), if one is set |
| 500 | versions from other sources that are not installed |
| 100 | the installed version, and archives marked `NotAutomatic: yes` plus `ButAutomaticUpgrades: yes` (Debian backports) |
| 1 | archives marked only `NotAutomatic: yes` (Debian experimental), and phased updates this machine is not yet eligible for |

How APT reads a pin priority `P`:

| Range | Effect |
|-------|--------|
| `P >= 1000` | installed even if that is a downgrade |
| `990 <= P < 1000` | installed even if not from the target release, unless the installed version is newer |
| `500 <= P < 990` | installed unless a target-release version exists or the installed version is newer |
| `100 <= P < 500` | installed unless another distribution has a version or the installed version is newer |
| `0 < P < 100` | installed only when no version of the package is installed |
| `P < 0` | never installed |

`P = 0` is undefined; do not use it. A stanza has three fields, and `Explanation:` lines are
comments:

```text
Explanation: keep unstable available for explicit installs only
Package: *
Pin: release a=unstable
Pin-Priority: 50
```

`Pin: release` matches Release-file fields (`a=` archive or suite, `n=` codename, `v=` version,
`o=` origin, `l=` label, `c=` component); `Pin: origin "host"` matches the site; `Pin: version`
matches a version glob. One-off choices need no pin: `apt install package/release`,
`apt install package=version`, or `apt install -t release package`.

Adding, changing, or removing a pin is consequential: it can hold security fixes back or, at 1000
and above, downgrade packages. Show the stanza and the `apt-get -s full-upgrade` result before and
after, and get confirmation. A version shown at priority 1 with no pin in place is usually a
phased update this machine is not yet eligible for, not a fault.

## Sources and keyrings

- Two formats are valid in `/etc/apt/sources.list.d/`: one-line style in `*.list` and deb822
  style in `*.sources`. Debian 13 recommends a single `debian.sources`; Ubuntu 24.04 LTS and later
  ship `ubuntu.sources`. `apt modernize-sources` (APT in Debian 13) converts old files; read the
  result before trusting it.
- A deb822 stanza uses `Types`, `URIs`, `Suites`, `Components`, and `Signed-By`. Add
  `Enabled: no` to switch a stanza off without deleting it.
- `Signed-By` limits a source to named keys. Without it, APT accepts every key in `trusted.gpg`
  and `trusted.gpg.d/` for that source, so a third-party key there can sign for any repository.
- Keyrings go in `/usr/share/keyrings` when a package manages them and `/etc/apt/keyrings` when
  the operator does. ASCII-armored keys must end in `.asc`, binary keys in `.gpg`, and the file
  must be readable by the `_apt` user. A key embedded in the `Signed-By` field needs APT 2.4 or newer.

Adding a third-party source is consequential. Check the fingerprint against the vendor's
published value, show the stanza, and get confirmation before writing anything:

```bash
gpg --show-keys ./vendor-key.asc                       # read-only: print the fingerprint
sudo install -m 0644 ./vendor-key.asc /etc/apt/keyrings/vendor.asc
sudoedit /etc/apt/sources.list.d/vendor.sources        # Types/URIs/Suites/Components/Signed-By
sudo apt update
apt-cache policy package_name                          # confirm origin and priority
```

## Snaps

```bash
snap list
snap info snap_name                # channels, tracking, installed revision
snap connections snap_name         # connected plugs and slots
snap changes                       # recent snapd operations and their status
snap refresh --list                # pending refreshes, changes nothing
```

- Read `snap connections` before reinstalling; a missing interface explains most failures.
- `sudo snap revert snap_name` reactivates the previous revision with that revision's data;
  changes the newer revision made to its data are discarded. Say so before running it.
- `sudo snap refresh --hold=<duration> snap_name` postpones refreshes for that snap, and `--hold`
  with no value holds forever; `--unhold` clears it. With no snap named, a hold only affects automatic
  refreshes. A hold also holds back security fixes.
- `--classic`, `--devmode`, and `--dangerous` (a local `.snap` with no verified signature) each
  drop a protection. Name the one in use and confirm first.

## Flatpak

```bash
flatpak remotes                    # which remotes exist; do not assume Flathub is configured
flatpak list --app
flatpak update
flatpak uninstall --unused
```

`flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo` adds
Flathub; `--user` or `--system` picks the installation. A remote is a repository trust decision
like any other, so confirm it first. Flatpak runtimes update apart from `apt`; a patched host can
still run an old runtime.

## Local .deb files

```bash
dpkg-deb -I ./package.deb          # control fields: name, version, Depends
dpkg-deb -c ./package.deb          # file list, to spot overwrites of system paths
dpkg-deb -e ./package.deb ./ctl    # extract maintainer scripts to read; they run as root
apt-get -s install ./package.deb   # simulate with dependency resolution
sudo apt install ./package.deb     # the leading ./ marks a file, not a package name
```

- Prefer `apt install ./package.deb` over `dpkg -i`: `dpkg` does not fetch dependencies, and a
  failed `dpkg -i` leaves the package unconfigured until `sudo apt-get -f install` runs.
- A `.deb` installed this way has no repository behind it and gets no updates;
  `apt-cache policy package_name` shows only `/var/lib/dpkg/status` as its source.
- A maintainer script can add a source and a key of its own. Compare `/etc/apt/sources.list.d/`
  and the keyring directories before and after the install.
