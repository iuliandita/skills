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

## When to use

- Managing or troubleshooting OPNsense and pfSense firewalls over SSH
- Reviewing pf rules, NAT, CARP, Unbound, WireGuard, CrowdSec, or pfBlockerNG on these appliances
- Hardening BSD firewall appliances and validating safe remote-change workflows

## When NOT to use

- Linux networking, reverse proxies, VPN setup, or nftables work outside firewall appliances -- use networking
- General shell scripting or local shell behavior outside the BSD firewall context -- use command-prompt
- Fleet-wide configuration management via playbooks -- use ansible
- Offensive testing, exploitation, or post-exploitation -- use lockpick
- Application-level security review or dependency scanning -- use security-audit

## Workflow

### Step 1: Detect platform

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

## FreeBSD Mental Model

Read `references/platform-and-operations.md` for the detailed FreeBSD shell model, key commands,
config system, REST API, IPv6 gotchas, SOPs, and recovery procedures.

- Treat both platforms as FreeBSD appliances, not Linux hosts.
- For anything beyond trivial SSH one-liners, prefer piping a POSIX `sh` heredoc instead of fighting `csh` or `tcsh`.
- Guard non-zero informational commands with `; true` when running checks in parallel.

## Operations and Common Tasks

- Identify the target device explicitly before changing anything.
- Back up config before risky changes or upgrades.
- Check plugin or package layers early because they often explain traffic behavior that looks like a firewall-rule problem.
- Treat firmware, plugin, backup, and HA work as operational procedures, not casual single commands.
- Use `references/plugins.md` for plugin specifics and `references/hardening.md` for hardening and CARP guidance.

## Reference Files

The `references/` directory contains detailed checklists for OPNsense specifically:
- `references/plugins.md` -- operational guidance for common OPNsense plugins (CrowdSec,
  WireGuard, Suricata, HAProxy, ACME, FRR, etc.)
- `references/hardening.md` -- comprehensive hardening and improvement checklist

These references cover OPNsense. For pfSense equivalents, map concepts using the platform
comparison table above.

## Related Skills

- **networking** -- for Linux reverse proxies, VPNs, DNS, and nftables work outside BSD firewall appliances
- **command-prompt** -- for general shell scripting and local shell behavior; this skill covers the FreeBSD firewall context
- **security-audit** -- for defensive security review of application code and supply chain, rather than firewall administration
- **lockpick** -- for authorized offensive testing and post-exploitation, not defensive firewall operations
- **ansible** -- for fleet-wide firewall automation or playbook-based configuration management

## Rules

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
