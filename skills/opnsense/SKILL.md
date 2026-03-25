---
name: opnsense
description: >
  Use when managing, troubleshooting, or hardening OPNsense/pfSense firewalls via SSH. Also
  trigger on firewall hostnames (e.g., "op1", "fw1", "pfsense"), pfctl, pf rules, FreeBSD
  firewall, CrowdSec on OPNsense, pfBlockerNG, CARP failover, or any BSD-based network
  appliance. Do NOT use for Linux firewalls (iptables, nftables, ufw), cloud security groups,
  or application-level WAFs.
source: custom
date_added: "2026-03-19"
effort: high
---

# OPNsense & pfSense Management

Manage, troubleshoot, and harden OPNsense and pfSense firewalls via SSH. Both are FreeBSD-based,
pf-powered firewall distributions -- most concepts, commands, and patterns apply to both.

## Platform detection

If the platform is not obvious from context, **ask the user** which one they're running before
issuing commands. Key differences at a glance:

| | OPNsense | pfSense |
|---|---|---|
| Base OS | HardenedBSD (FreeBSD fork) | FreeBSD |
| Config path | `/conf/config.xml` | `/cf/conf/config.xml` |
| Service control | `configctl service restart <svc>` | `pfSsh.php playback svc restart <svc>` or `service <svc> restart` |
| Plugin prefix | `os-<name>` (e.g., `os-wireguard`) | No prefix (e.g., `pfSense-pkg-WireGuard`) |
| PHP shell | N/A | `pfSsh.php` (interactive PHP shell) |
| Quick rule add | N/A | `easyrule pass wan tcp <src> <dst> <port>` |
| IP blocking | CrowdSec (`os-crowdsec`) | pfBlockerNG |
| Root shell | `csh` | `tcsh` (same heredoc workaround applies) |
| IDS/IPS config | `/tmp/suricata_*.log`, eve.json | `/var/log/suricata/suricata.log`, eve.json |
| Firmware CLI | `configctl firmware check/status` | `pkg-static update` + GUI |
| Template engine | `configd` + `configctl template` | PHP-generated configs |
| REST API | Yes (`/api/`, key/secret auth) | Yes (similar, different endpoints) |
| Licensing | Free, open source | CE: free but slower updates; Plus: $129/yr on non-Netgate HW |
| Release cadence | Bi-weekly, fixed schedule | Irregular, Netgate hardware prioritized |

**2026 status**: OPNsense is the clear choice for new deployments. pfSense CE gets slower updates and zero priority; Plus costs $129/year on non-Netgate hardware. Migration from pfSense to OPNsense has no automated path -- expect ~60% clean config transfer, manual rebuild for NAT rules, VPN, and DNS forwarder settings.

**When platform is unknown**, these commands work on both:
```
pfctl -sr                # firewall rules
pfctl -ss                # state table
ifconfig                 # interfaces
pkg info                 # installed packages
netstat -rn              # routing table
sockstat -4l             # listening sockets
```

## This is FreeBSD, not Linux

The single most important thing to internalize. Both OPNsense and pfSense run on FreeBSD
(or a fork of it). Linux commands do not exist on these systems.

| Linux reflex | OPNsense / pfSense equivalent |
|---|---|
| `iptables` / `nftables` | `pfctl` (packet filter) |
| `systemctl` | `configctl service ...` (OPNsense) / `service ...` (pfSense) |
| `ip addr` / `ifconfig` | `ifconfig` (BSD version) |
| `ss` / `netstat` | `sockstat` |
| `apt` / `yum` | `pkg` (FreeBSD) + `pluginctl` (OPNsense) |
| `journalctl` | log files in `/var/log/` |
| `ip route` | `netstat -rn` |

**Shell gotcha:** OPNsense uses `csh`, pfSense uses `tcsh` -- neither is bash. Bash features
like `$()`, `$((...))`, `2>&1`, `&>`, `|&`, and conditionals (`&&`/`||`) will fail or misbehave
inside remote commands. Use the patterns below.

**Pattern 1 -- Simple commands** (single command, no shell features needed):
```bash
ssh <target> 'pfctl -si' 2>/dev/null | head -20     # redirect stderr LOCALLY, not remotely
ssh <target> 'uptime'
```

**Pattern 2 -- Multiple simple commands** (semicolons work in csh/tcsh):
```bash
ssh <target> 'uptime; df -h /'                       # chain with semicolons, no &&
```

**Pattern 3 -- Complex commands** (variables, arithmetic, redirects, `$()`, pipes):
Pipe a `sh` script via stdin using a heredoc. This is the **reliable fallback** for anything
beyond simple commands. The heredoc is evaluated by `sh` on the remote side, bypassing csh/tcsh.
```bash
ssh <target> sh <<'REMOTE'
  TOTAL=$(sysctl -n hw.physmem)
  FREE=$(sysctl -n vm.stats.vm.v_free_count)
  PAGESIZE=$(sysctl -n hw.pagesize)
  AVAIL=$(( (FREE) * PAGESIZE ))
  echo "RAM: $((TOTAL / 1048576))MB total, $((AVAIL / 1048576))MB free"
  df -h / 2>/dev/null
  pkg audit -F 2>/dev/null | tail -5
REMOTE
```
**Important**: use `<<'REMOTE'` (quoted delimiter) to prevent local shell expansion. Without quotes,
`$()` and variables expand on the local machine before being sent to the remote.

**Anti-pattern -- do NOT use `sh -c "..."`** for anything beyond trivial commands:
```bash
# BAD: nested quoting cascades, $() breaks, unreadable
ssh <target> 'sh -c "TOTAL=\$(sysctl -n hw.physmem); echo \$((TOTAL / 1048576))MB"'
# GOOD: use heredoc instead (Pattern 3 above)
```
The `sh -c "..."` pattern inside SSH single quotes creates a quoting nightmare with double-quote
escaping, dollar-sign escaping, and backslash cascades. It works for one-liners like
`ssh <target> 'sh -c "simple cmd"'` but falls apart fast. Prefer heredocs for anything multi-step.

**Parallelism note**: when running multiple SSH checks in parallel (separate Bash tool calls),
keep each call self-contained. Don't chain dependent SSH calls in one Bash invocation -- if the
first fails, the rest are cancelled.

**Exit code gotcha for parallel calls**: many FreeBSD commands exit non-zero for informational
(not error) reasons. When these run in parallel Bash calls, one non-zero exit cancels ALL sibling
calls. Always append `; true` to guard against this:

| Command | Why it exits non-zero | Guard |
|---|---|---|
| `pkg audit -F` | exit 1 = vulnerabilities found | `pkg audit -F 2>/dev/null; true` |
| `grep <pattern>` | exit 1 = no match | `cmd \| grep pattern; true` |
| `service X status` | exit 1 = service not running | `service X status; true` |
| `cscli decisions list` | exit 1 = no active decisions (OPNsense) | `cscli decisions list; true` |

## Identifying the target device

The user may specify a device by SSH alias, hostname, or IP. If not specified, ask -- don't guess
which firewall to SSH into.

Connect via the Bash tool: `ssh <target> '<command>'`

## Key commands

### Both platforms (pf-based)

```
# Firewall / packet filter
pfctl -sr                        # show active filter rules
pfctl -sn                        # show active NAT rules
pfctl -ss                        # show state table (active connections)
pfctl -si                        # show filter stats
pfctl -sk <ip>                   # kill states for an IP (careful)

# Diagnostics
tcpdump -i <iface> <filter>     # packet capture
systat -ifstat                   # real-time interface stats
top -SH                          # process monitor with threads
sockstat -4l                     # listening IPv4 sockets
netstat -rn                      # routing table
```

### OPNsense-specific

```
# System
opnsense-version -v              # firmware version + arch
configctl firmware check         # force-refresh update info from mirror
configctl firmware status        # pending updates + package list (run AFTER check)
configctl firmware changelog     # changelog for pending update

# Config
cat /conf/config.xml             # master config (all GUI settings live here)
configctl template reload <svc>  # regenerate service config from XML
configctl service restart <svc>  # restart a service

# Plugins
pkg info | grep os-              # list installed OPNsense plugins
pluginctl -i                     # plugin info
pluginctl -s <query>             # search available plugins

# Services
configctl dns restart            # Unbound (DNS resolver)
configctl dhcpd restart          # ISC DHCP
configctl openvpn restart        # OpenVPN (also covers WireGuard)
wg show                          # WireGuard status (if os-wireguard installed)

# Diagnostics
diag dns lookup <host>           # DNS resolution test
diag interface routes            # routing table (OPNsense wrapper)
diag firewall states             # connection tracking summary
```

### pfSense-specific

```
# System
pkg-static update                # refresh package database
pkg info                         # installed packages

# Config
cat /cf/conf/config.xml          # master config (note different path from OPNsense)

# PHP shell (powerful, be careful)
pfSsh.php playback svc restart <service>   # restart a service
pfSsh.php playback enableallowallwan       # example built-in playback command

# Quick rule management
easyrule pass wan tcp any <dst-ip> 443     # quick firewall rule addition
easyrule block wan <src-ip>                # quick block

# Plugins
pkg info | grep pfSense-pkg-    # list installed pfSense packages

# Services
service unbound restart          # DNS resolver
service dhcpd restart            # DHCP
service openvpn restart          # OpenVPN
wg show                          # WireGuard (if pfSense-pkg-WireGuard installed)
```

## Config system

### OPNsense

Everything flows through `/conf/config.xml`. The GUI reads and writes this file, and
`configd` generates actual service configs from it. The hierarchy:

1. `/conf/config.xml` -- source of truth (XML)
2. `configd` templates -- transform XML into service-specific configs
3. `/usr/local/etc/` -- generated configs (Unbound, HAProxy, etc.)
4. `configctl template reload <service>` -- regenerate from XML
5. `configctl service restart <service>` -- restart with new config

When editing config.xml directly, always reload the relevant service afterward. But prefer
`configctl` and the plugin APIs over raw XML edits when possible -- they handle validation and
dependent service restarts.

### pfSense

Same XML-driven model but at `/cf/conf/config.xml`. pfSense lacks `configctl` -- instead:

- PHP-based config generation (configs written directly by PHP classes)
- `pfSsh.php` for programmatic config changes and service control
- `pfSsh.php playback` commands for common operations (list available with `pfSsh.php playback`)
- Direct `service <name> restart` for service restarts
- `/usr/local/etc/` for generated configs (same location as OPNsense)

After editing config.xml directly on pfSense, use `pfSsh.php` to reload or restart:
```
pfSsh.php playback svc restart <service>
```

Or trigger a full config reload:
```
/etc/rc.reload_all
```

## REST API

Both platforms have REST APIs for automation. API docs are built into the GUI:
- OPNsense: `https://<firewall>/api-docs/`
- pfSense: `https://<firewall>/api-docs/` (with `pfSense-pkg-API` package installed)

For interactive sessions, prefer SSH. Use the API for scripts, monitoring, and CI/CD pipelines.

## IPv6

Both platforms have full IPv6 support. The configuration is non-trivial and error-prone.

**Common setup patterns:**
- **DHCPv6-PD (prefix delegation)**: ISP assigns a /48 or /56 prefix via DHCPv6 on WAN.
  Delegates sub-prefixes to LAN/VLAN interfaces.
  - OPNsense: Interfaces > [WAN] > DHCPv6 with "Request Prefix" enabled
  - pfSense: Interfaces > [WAN] > DHCPv6 Client Configuration
- **SLAAC + RDNSS**: router advertisements for stateless address config.
  - OPNsense: Services > Router Advertisements
  - pfSense: Services > DHCPv6 Server & RA > Router Advertisements
- **Static**: manual prefix assignment. Use for stable server addressing.

**Key gotchas:**
- Firewall rules are separate for IPv4 and IPv6. A "pass all" IPv4 rule does NOT apply to IPv6.
  Check both tabs when troubleshooting connectivity.
- `pfctl -sr` shows both v4 and v6 rules. Filter with `grep inet6` for v6-only rules.
- GeoIP aliases may not include IPv6 ranges depending on the database. Verify coverage.
- WireGuard tunnels need explicit IPv6 allowed-IPs if carrying v6 traffic.
- ICMPv6 is required for IPv6 to function (neighbor discovery, RA, PMTUD). Never block
  ICMPv6 entirely -- at minimum allow types 1-4, 128, 133-137.
- Prefix delegation changes on ISP reconnect can break static internal references.
  Use ULA (fd00::/8) for stable internal addressing alongside dynamic GUA prefixes.

**Diagnostics (both platforms):**
```
ifconfig | grep inet6                          # IPv6 addresses on all interfaces
ping6 -c 3 2606:4700:4700::1111               # test IPv6 connectivity (Cloudflare)
netstat -rn -f inet6                           # IPv6 routing table
```

OPNsense-specific:
```
configctl service list | grep radvd            # check RA daemon
```

pfSense-specific:
```
service radvd status                           # check RA daemon
```

## Plugins and packages

### OPNsense plugins

OPNsense has a large plugin ecosystem with `os-` prefixed packages. Enumerate installed plugins
early in any session because plugins like CrowdSec and Suricata can silently affect traffic in
ways that look like firewall rule problems.

```
pkg info | grep os-              # list installed plugins
pluginctl -i                     # plugin info
pluginctl -s <query>             # search available plugins
```

Read `${CLAUDE_SKILL_DIR}/references/plugins.md` for detailed operational guidance on common OPNsense
plugins (CrowdSec, WireGuard, Suricata, HAProxy, ACME, and more). Always check that file when
dealing with OPNsense plugin-specific issues.

### pfSense packages

pfSense uses the same `pkg` system but packages are prefixed `pfSense-pkg-` instead of `os-`.

```
pkg info | grep pfSense-pkg-    # list installed packages
```

**Key pfSense packages** (with OPNsense equivalents):

| pfSense package | OPNsense equivalent | Purpose |
|---|---|---|
| pfBlockerNG | os-crowdsec | IP/DNS blocking (pfBlockerNG also does DNSBL) |
| pfSense-pkg-Suricata | os-suricata | IDS/IPS |
| pfSense-pkg-snort | os-suricata | IDS/IPS (legacy, Suricata preferred) |
| pfSense-pkg-WireGuard | os-wireguard | WireGuard VPN |
| pfSense-pkg-haproxy | os-haproxy | Reverse proxy / load balancer |
| pfSense-pkg-squid | N/A (os-proxy removed) | Web proxy / caching |
| pfSense-pkg-ntopng | os-ntopng | Traffic analysis |
| pfSense-pkg-acme | os-acme-client | Let's Encrypt certificates |
| pfSense-pkg-API | Built-in (`/api/`) | REST API |

**pfBlockerNG** (pfSense's primary IP/DNS blocking tool):
- IP blocking: GeoIP, threat feeds (Spamhaus, abuse.ch), custom lists
- DNS blocking (DNSBL): ad blocking, malware domains, similar to OPNsense's built-in DNS blocklists
- Config: Firewall > pfBlockerNG
- Logs: `/var/log/pfblockerng/`
- Force update: `pfSsh.php playback pfblockerngupdate`
- **pfBlockerNG vs CrowdSec**: pfBlockerNG is feed-based (static lists). CrowdSec is behavior-based
  (detects and bans based on log analysis). Different approaches, not direct equivalents.

**Suricata on pfSense** (paths differ from OPNsense):
- Config: Services > Suricata (GUI)
- Logs: `/var/log/suricata/<interface>/` (per-interface subdirectories)
- Eve JSON: `/var/log/suricata/<interface>/eve.json`
- Rule updates: GUI or `pfSsh.php playback svc restart suricata`

## Standard operating procedures

### Before any change

1. Back up config:
   - OPNsense: `cp /conf/config.xml /conf/backup/config-$(date +%Y%m%d-%H%M%S).xml`
   - pfSense: `cp /cf/conf/config.xml /cf/conf/backup/config-$(date +%Y%m%d-%H%M%S).xml`
2. Show the user what will change and why
3. Apply the change
4. Verify: test connectivity, check logs, confirm service status

### Troubleshooting flow

1. Gather symptoms: check firewall logs, system logs, service-specific logs
   - OPNsense: `/var/log/filter.log` (firewall), `/var/log/system.log`
   - pfSense: `/var/log/filter.log` (firewall), `/var/log/system.log`
2. Check security plugin logs first:
   - OPNsense: CrowdSec bans (`cscli decisions list`) and Suricata drops
   - pfSense: pfBlockerNG blocks (`/var/log/pfblockerng/`) and Suricata drops
3. Inspect active rules (`pfctl -sr`), state table (`pfctl -ss`), NAT (`pfctl -sn`)
4. Trace traffic with `tcpdump` on relevant interfaces
5. Verify DNS resolution
   - OPNsense: `diag dns lookup <host>`
   - pfSense: `host <domain>` or `drill <domain>`
6. Check resource usage (`top -SH`, `systat`) -- low-RAM devices struggle with IDS/IPS plugins

### Update checks and maintenance

#### OPNsense

Three independent update channels. Check all three -- they're not coupled.

```
# Firmware (OPNsense core + base OS)
configctl firmware check           # force-refresh from mirror
configctl firmware status          # shows version, available upgrades (run AFTER check)
configctl firmware changelog       # detailed changelog for pending update

# Plugins
configctl firmware plugins         # list installed plugins with update status
pkg upgrade -n                     # dry run: show what would be upgraded

# FreeBSD base packages
pkg audit -F                       # check for known vulnerabilities
pkg version -vRL=                  # list packages with available updates
```

**Do NOT use `opnsense-update -c`** -- it's unreliable and can report "no updates" when updates exist.

#### pfSense

```
# System updates
pkg-static update                  # refresh package database
pkg upgrade -n                     # dry run: show what would be upgraded

# Packages
pkg info | grep pfSense-pkg-      # list installed packages
pkg audit -F                       # check for known vulnerabilities
```

pfSense firmware updates are best managed via the GUI (System > Update) or `pfSsh.php playback`.

**Both platforms**: firmware updates can reboot the device and may require console access if
something breaks. Never apply without explicit user confirmation. Check the changelog first.

### Routine health check

Good default when user asks "how's my firewall doing." Works for both platforms with minor
command differences.

**Parallel safety**: most of these can run as separate parallel Bash calls. Commands that
exit non-zero for informational reasons (marked with !) MUST use `; true` guards.

1. Version + uptime + disk:
   - OPNsense: `opnsense-version -v; uptime; df -h /`
   - pfSense: `uname -a; uptime; df -h /`
2. Firmware updates (OPNsense only, sequential):
   - `configctl firmware check` then `configctl firmware status`
3. ! `pkg audit -F 2>/dev/null; true` -- known CVEs
4. DNS health:
   - OPNsense: `diag dns lookup example.com; configctl dns diagnostics 2>/dev/null; true`
   - pfSense: `host example.com; service unbound status; true`
5. Security plugin status:
   - OPNsense (CrowdSec): `cscli decisions list; cscli alerts list -l 15; cscli metrics` (heredoc)
   - pfSense (pfBlockerNG): check `/var/log/pfblockerng/` logs
6. IDS/IPS freshness (if installed):
   - OPNsense: `configctl ids update`
   - pfSense: check Suricata rule dates in `/var/log/suricata/`
7. State table: `pfctl -si | grep -E 'current entries|limit'` -- check if approaching limit
8. Resource usage: memory via sysctl heredoc (Pattern 3). Also check `/var` usage:
   `df -h /var` -- on small-disk devices, logs fill fast with IDS/IPS enabled.

### Backup and restore

**Config export (before risky changes or upgrades):**
```bash
# Local backup
# OPNsense:
cp /conf/config.xml /conf/backup/config-$(date +%Y%m%d-%H%M%S).xml
# pfSense:
cp /cf/conf/config.xml /cf/conf/backup/config-$(date +%Y%m%d-%H%M%S).xml

# Download to local machine (from the SSH client side)
scp <target>:/conf/config.xml ./backup-$(date +%Y%m%d).xml          # OPNsense
scp <target>:/cf/conf/config.xml ./backup-$(date +%Y%m%d).xml       # pfSense
```

**Config restore:**
```bash
# Upload config to the device
scp ./backup.xml <target>:/conf/config.xml          # OPNsense
scp ./backup.xml <target>:/cf/conf/config.xml       # pfSense

# Reboot to apply the restored config fully
# WARNING: this disconnects the SSH session
shutdown -r now
```

A reboot is the most reliable way to load a restored config.xml -- all services restart with
the restored configuration. Alternatives:
- OPNsense: `configctl service restart all` (most changes, some need reboot)
- pfSense: `/etc/rc.reload_all` (most changes, some need reboot)

Partial restores (importing only specific sections of config.xml) can lead to unexpected
behavior -- prefer full restores when possible.

**Automated backups:**
- OPNsense: scheduled backups to SFTP, Nextcloud, or Git (System > Configuration > Backups)
- pfSense: AutoConfigBackup (gold subscription) or manual cron + scp

For critical devices, enable at least one remote backup method -- a local-only backup doesn't
help if the disk dies.

**Disaster recovery (full reinstall):**
1. Install OPNsense/pfSense on new/replacement hardware
2. Complete initial wizard (just enough to get network access)
3. Import saved config.xml via GUI
4. Reboot -- device should come up with full config
5. Verify: interfaces, VIPs, VPN tunnels, firewall rules, plugins/packages
6. Reinstall any plugins/packages that were on the old system (plugin list is in config.xml
   but the packages themselves need to be downloaded again)

Console settings are excluded from imports by default to prevent lockout when restoring to
different hardware with different interface names.

If the device is virtualized (Proxmox, ESXi), also take a hypervisor-level snapshot before
major upgrades -- faster rollback than config restore.

### HA / CARP

Both OPNsense and pfSense support CARP for high availability. The concepts are identical
(both use the same FreeBSD CARP implementation).

Read `${CLAUDE_SKILL_DIR}/references/hardening.md` for the HA/CARP checklist (OPNsense-specific but
concepts apply to pfSense).

Key concepts:
- **CARP** (Common Address Redundancy Protocol): automatic failover via shared virtual IPs.
  Uses IP protocol 112 with multicast advertisements.
- **pfSync**: replicates the firewall state table between nodes. Needs a dedicated interface.
- **Config sync**: keeps config synchronized from master to backup.
  - OPNsense: XMLRPC sync (configure on master only)
  - pfSense: XMLRPC sync (same -- configure on master only)

Common tasks:
```
# Check CARP status (both platforms)
ifconfig | grep carp             # CARP interface states (MASTER/BACKUP)

# Verify pfSync (both platforms)
pfctl -ss | wc -l                # state count -- should be similar on both nodes

# Maintenance mode
# OPNsense: Interfaces > Virtual IPs > Status > "Enter Persistent CARP Maintenance Mode"
# pfSense: Status > CARP (failover) > "Enter Persistent CARP Maintenance Mode"
```

**Zero-downtime update procedure (both platforms):**
1. Update the backup node first
2. Put the master into CARP maintenance mode (forces failover to backup)
3. Verify backup has assumed master role and traffic flows
4. Update the former master
5. Leave maintenance mode -- original master reassumes primary role

### Improvement / hardening audit

Read `${CLAUDE_SKILL_DIR}/references/hardening.md` for a comprehensive checklist covering DNS hardening,
firewall best practices, WireGuard tuning, GUI/SSH security, CrowdSec optimization, firmware
maintenance, HA/CARP, network segmentation, and monitoring. That checklist is OPNsense-specific
but the principles apply equally to pfSense -- adjust command paths as documented above.

## Reference files

The `references/` directory contains detailed checklists for OPNsense specifically:
- `references/plugins.md` -- operational guidance for common OPNsense plugins (CrowdSec,
  WireGuard, Suricata, HAProxy, ACME, FRR, etc.)
- `references/hardening.md` -- comprehensive hardening and improvement checklist

These references cover OPNsense. For pfSense equivalents, map concepts using the platform
comparison table above.

## Safety rules

These exist because bricking a firewall remotely means driving to wherever it is.

- **Never** modify rules that could lock out SSH access. If the change touches the SSH port or the
  management interface, triple-check the rule order and confirm with the user.
- **Never** disable the LAN interface or change its IP without explicit confirmation and a rollback
  plan.
- **Never** apply firmware or plugin updates without asking first -- updates can reboot the device
  and may require physical console access if something goes wrong.
- **Always** confirm destructive changes: rule deletions, service disables, plugin removals,
  state table flushes (`pfctl -Fa`).
- **Estimate blast radius**: if a change could cause network disruption beyond the target device,
  warn the user with specifics (e.g., "this will drop all VPN tunnels for ~30s").
- **OPNsense CrowdSec**: don't delete decisions or bouncers without understanding why they exist.
  A ban that looks wrong might be catching a real attack.
- **pfSense pfBlockerNG**: don't disable feed lists without understanding what they block.
  Review the deny logs before removing feeds.
- **HA/CARP (both platforms)**: never make config changes directly on the backup node -- XMLRPC
  sync from master will overwrite them. Always change on master and let sync propagate.
- **pfSense `easyrule`**: convenient but creates rules without descriptions. Document what you
  added and why. Consider using the GUI or config.xml for permanent rules instead.
