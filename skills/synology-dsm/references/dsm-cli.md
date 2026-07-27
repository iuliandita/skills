# DSM Command Surface

Command reference for administering DSM over SSH. Two confidence tiers are marked throughout:

- **Verified**: observed on a DSM 7.1 unit (DS415+, avoton) during hands-on work
- **Documented**: from Synology's CLI Administrator Guide or DSM's own help output. Confirm with
  `<tool> --help` on the target unit before scripting it - flags differ across DSM versions and
  models, and several `syno*` tools have no stable interface contract

The CLI guide is the last one Synology published (copyright 2015-2021, 20 pages) and its examples
are DSM 5-era: the service names it lists and its eth0/eth1 assumptions are stale. Treat it as
normative for argument order and semantics, not for what exists on a DSM 7 unit. Where it prints
argument names with spaces (`full name`, `adv privilege`, `[--dont restart service]`), this file
uses underscores for readability - the guide's own spacing is inconsistent and its
`{--del]` bracket is a typo in the source.

Source:
`https://global.download.synology.com/download/Document/Software/DeveloperGuide/Firmware/DSM/All/enu/Synology_DiskStation_Administration_CLI_Guide.pdf`

## Contents

1. Shell access and elevation
2. Identity and platform
3. Packages
4. Services
5. Shares, users, groups
6. Storage and disks
7. Indexing
8. Logs and notifications
9. Network
10. DSM Web API
11. Extra tooling (Entware, community scripts)

---

## 1. Shell access and elevation

Enable SSH in Control Panel > Terminal & SNMP > Terminal. Keep Telnet off (CVE-2026-32746).

```sh
ssh admin@nas                  # DSM 7 disallows direct root SSH login
sudo -i                        # root shell
```

Working facts (**verified**):

- `/bin/sh` is ash. No bashisms, no process substitution. `bash` exists but scripts invoked by
  DSM run under ash
- `/tmp` is mounted `noexec`. Deploy binaries to `/root/` or a package directory
- `scp` needs `-O` (legacy protocol) because the sftp subsystem is disabled
- Sessions land in `/volume1/homes/<user>`, which pins the volume. `cd /` before unmount work
- `lsof`, `fuser`, `mountpoint`, and `modinfo` are absent. Use `/proc` directly:

```sh
sudo ls -l /proc/*/cwd /proc/*/root /proc/*/fd/* 2>&1 | grep volume1   # who holds the mount
```

Detach anything long-running (**verified** failure mode: an SSH drop kills the job):

```sh
setsid nohup /root/job.sh > /root/job.log 2>&1 < /dev/null &
```

Put the logic in a script file so a later `pkill -f <pattern>` cannot match your own command line.

## 2. Identity and platform

```sh
cat /etc.defaults/VERSION                  # productversion, buildnumber, majorversion  (verified)
grep unique /etc.defaults/synoinfo.conf    # platform id, e.g. synology_avoton_415+     (verified)
uname -a                                   # kernel line (3.10.x or 4.4.x)              (verified)
```

`/etc.defaults/` holds shipped defaults; `/etc/` holds the live copy that DSM regenerates. Edits
in `/etc.defaults/` survive routine updates more often, but a major DSM upgrade can overwrite
either. Treat both as regenerated state, not as configuration you own.

`/etc/fstab` is rewritten at boot (`synocfgen` is among the writers). A volume line looks like:

```
/dev/mapper/cachedev_0 /volume1 btrfs auto_reclaim_space,ssd,synoacl,relatime,nodev 0 0
```

## 3. Packages

```sh
synopkg list --name                  # installed packages            (verified)
synopkg status <Pkg>                 # JSON status                   (verified)
synopkg stop <Pkg> ; synopkg start <Pkg>                            # (verified)
synopkg enable <Pkg> ; synopkg disable <Pkg>   # autostart marker in /var/packages/<Pkg>/enabled
systemctl stop pkgctl-<Pkg>.service  # the unit behind the package   (verified)
```

`synopkg list --started` does not exist on DSM 7.1 (**verified**). Use `synopkg status`.

**Dependencies resurrect packages** (**verified**): `synopkg disable` does not hold if another
installed package declares the target in `install_dep_packages`.

```sh
grep -h install_dep_packages /var/packages/*/INFO
```

Observed: `SynologyDrive` depends on `SynoFinder`, so SynoFinder restarts within a minute of
being disabled. When the real goal is narrower (stop indexing one share), use the indexer's own
control tool in section 7 instead of fighting the package manager.

Package layout: `/var/packages/<Pkg>/` holds `INFO`, `enabled`, `target/` (the install tree,
usually a symlink into `/volume1/@appstore/<Pkg>`), and `etc/`.

## 4. Services

```sh
systemctl list-units --type=service --state=running     # (verified)
systemctl status <unit>
```

Guide-documented `synoservice` syntax (**documented**, from the CLI Administrator Guide):

```
synoservice {--help}
synoservice {--list} [running]
synoservice {--enable | --disable} service...
synoservice {--start | --stop | --restart} service...
synoservice {--keyon | --keyoff} service...
synoservice {--detail} service...
```

`--enable`/`--disable` persist the setting **and** start or stop the service immediately.
`--start`/`--stop`/`--restart` do not modify settings. The guide says a start "will check if the
service has been enabled" but does not state what happens when it has not, so do not promise the
user a specific failure mode.

`--hard-disable`, `--hard-stop`, `--hard-enable`, and `--hard-start` appear in some DSM builds'
own `--help` output but are not in the guide. Run `synoservice --help` on the unit before using
them.

Core services worth knowing (**verified** present on DSM 7.1): `pgsql`, `pgsql-adapter`,
`s2s_daemon`, `synologand`, `nfs-server`, `nfs-mountd`, `synoindexd`, `synoelasticd`.

To free `/volume1` on DSM 7 there is no `syno_poweroff_task` (**verified** absent on 7.1). Stop
packages, then the services that hold the volume, then unmount - after `cd /`.

## 5. Shares, users, groups

Guide-documented syntax (**documented**, from the CLI Administrator Guide):

```
synouser  {--help} | {--add} username passwd "full name" expired email app_privilege
synouser  {--del} username... | {--rename} old new | {--modify} username passwd "full name" expired email
synogroup {--help} | {--add} groupname username... | {--del} groupname...
synogroup {--rename} old_groupname new_groupname | {--member} groupname username...
synoshare {--help}
synoshare {--add} sharename share_desc share_path user_list_na user_list_rw user_list_ro share_browsable adv_privilege
synoshare {--del} {TRUE | FALSE} sharename...
synoshare {--rename} old_sharename new_sharename
synoshare {--setuser} sharename {NA | RO | RW} {+ | - | =} user_list
```

`synoshare --del` takes a boolean **first**: `TRUE` deletes configuration and data, `FALSE`
deletes only the configuration and leaves the directory, which DSM will then restore as a share
with default privileges on the next restart. Both are destructive in different ways; confirm
which one the user means before running either. It cannot delete Hybrid Share folders.

Listing flags (`--enum`, `--get`, `--list`) exist on real units for several of these tools but
are **not in the guide**, and `synouser --setpw` appears only in the guide's examples, not its
synopsis. Run `<tool> --help` on the unit rather than scripting against a flag
recalled from a forum post.

Share data lives at `/volume1/<share>`. ACLs are Synology ACLs (`synoacl` mount option), so
`getfacl`/`setfacl` do not tell the whole story. DSM ships `synoacltool` for Synology ACLs, but it
is not in the CLI guide and its interface is not contractual - run it with no arguments to get
its usage before relying on it. The guide covers only `synouser`, `synogroup`, `synoshare`,
`synonet`, `synoservice`, and `synowin`; everything else in this file is `--help`-derived or
observed, and marked accordingly.

## 6. Storage and disks

```sh
cat /proc/mdstat                          # arrays, degradation, resync progress   (verified)
sudo mdadm --detail /dev/md2              # array detail                           (verified)
sudo vgs ; sudo lvs ; sudo pvs            # LVM layer                              (verified)
sudo btrfs filesystem show                                                       # (verified)
sudo btrfs filesystem usage /volume1      # data vs metadata allocation            (verified)
sudo btrfs subvolume list /volume1                                                # (verified)
sudo smartctl -a /dev/sda                 # SMART, present on DSM                  (verified)
sudo dmesg | tail -100                                                            # (verified)
```

Device stack (**verified**):

```
/dev/sdX3  ->  mdN (RAID, data)  ->  vgN/volume_N  ->  cachedev_N (flashcache shim)  ->  btrfs
```

`md0` (system, ~8 GB) and `md1` (swap, ~2 GB) are RAID1 across **all** disks. They are commonly
found degraded and ignored for months. Check them on every engagement.

See `storage-and-backup.md` for repair, replacement, and the compatibility database.

## 7. Indexing

**Identify which indexer is running hot before pausing anything.** Three separate subsystems
produce the same "the NAS is hammering the disks" complaint and they take different levers:

| Process | Belongs to | Lever |
|---|---|---|
| `synoelasticd`, `synotifyd` | SynoFinder / Universal Search | the `fileindex` tool below |
| `synoindexd` | media indexing for Photos, Video Station, Audio Station | the indexed-folder list in DSM's Indexing Service settings - `fileindex` does not control it |
| Photos face and subject recognition | Synology Photos | unshare the folder from Photos, or disable recognition in the Photos settings |

```sh
top -b -n 1 | head -20
ps w | grep -E 'synoindex|synoelastic|synotifyd'
```

Pausing SynoFinder's indexing when `synoindexd` is the busy process changes nothing. This is the
most common misdiagnosis on a media share.

The SynoFinder watch list is `/usr/syno/etc/synotifyd/fileindex`, JSON, one entry per indexed
share (**verified**). Read it, do not hand-edit it - DSM regenerates this class of config and a
package restart rewrites it. Change it through the tool so the daemon sees the change:

```sh
sudo /var/packages/SynoFinder/target/tool/fileindex -a share_pause  -n <sharename>   # (verified)
sudo /var/packages/SynoFinder/target/tool/fileindex -a share_resume -n <sharename>   # (verified)
sudo /var/packages/SynoFinder/target/tool/fileindex -a is_idle                       # (documented)
```

Other actions seen in its help (**documented** - confirm with `--help` on the unit): `reindex`,
`share_rebuild`, `volume_pause`, `volume_resume`. `-n <name>` is required; `-p <path>` alone
fails with `name is required` (**verified**).

Two things the tool does not tell you and that are not established: whether a pause survives a
reboot or a SynoFinder restart, and whether `-n` is case-sensitive. Copy the share name exactly
as `synoshare` reports it, and re-check the pause with `is_idle` after a restart rather than
assuming persistence.

This is the correct lever for excluding a share from SynoFinder indexing - far better than
fighting package dependencies.

## 8. Logs and notifications

```sh
sudo dmesg                                  # kernel ring buffer, wraps           (verified)
ls /var/log/                                # syslog-style logs
ls /var/log/synolog/                        # DSM Log Center databases
```

DSM's Log Center stores structured logs in SQLite databases under `/var/log/synolog/`, not plain
text. Read them with `sqlite3` if present, or export from the Log Center UI. Do not assume a
plain-text grep covers DSM events.

`dmesg` wraps. When a flood of one message is running, a full-snapshot diff is the only reliable
way to see what else happened:

```sh
sudo dmesg > /root/dmesg.before
# ... action ...
sudo dmesg > /root/dmesg.after
diff /root/dmesg.before /root/dmesg.after | head -50
```

## 9. Network

```sh
ip a ; ip r                                 # standard iproute2 present          (verified)
cat /etc/hosts ; cat /etc/resolv.conf
```

Guide-documented `synonet` syntax (**documented**). All of these change live networking and can
cut your own session:

```
synonet {--help}
synonet {--dhcp} iface
synonet {--manual} iface ip mask [--dont_restart_service]
synonet {--set_gateway} gateway
synonet {--set_dns} dns
synonet {--set_mtu} iface MTU
synonet {--set_hostname} hostname [--dont_restart_service]
```

DSM's firewall is configured through Control Panel and enforced with its own ruleset. Editing
iptables directly does not persist and can be reverted by DSM at any time; use the UI or the
firewall's own config path.

## 10. DSM Web API

DSM exposes an HTTP API at `/webapi/` used by the web UI itself. Entry points: `query.cgi` for
API discovery, `auth.cgi` / `entry.cgi` with `SYNO.API.Auth` for session login, then per-package
API namespaces (`SYNO.Core.*`, `SYNO.FileStation.*`, `SYNO.Backup.*`).

Use it for automation instead of screen-scraping the UI. Two rules:

- Never pass the password on the command line. Use a curl config file with mode 0600, an
  environment variable, or stdin - process listings are readable by other users
- API sets and versions differ per DSM release; call `query.cgi` on the target unit rather than
  hardcoding a version from documentation

Synology's "DSM Login Web API Guide" is the reference. Community clients exist (for example the
`synology-dsm` Python client used by Home Assistant) if a maintained wrapper is preferable to
raw calls.

## 11. Extra tooling

- **Entware** adds an `opkg` package manager for tools DSM omits. It installs outside DSM's
  package system, so DSM updates can break it and it is unsupported by Synology. Reach for it
  only when a needed tool genuinely does not exist; prefer `python3`, which ships with DSM
- **Community scripts** (for example 007revad's collection for the drive compatibility database)
  patch DSM state directly. Read any such script before running it, pin the version, and expect
  a DSM update to revert its effects
- Compiling on the NAS is not worth it. Cross-build static binaries elsewhere and copy them to
  `/root/` (see the build guidance in `btrfs-recovery.md`)
