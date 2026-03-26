# Platform and Operations

This reference keeps the operational FreeBSD appliance detail out of the main skill body.

## FreeBSD, not Linux

Translate Linux reflexes before doing anything:

- `pfctl` instead of `iptables` or `nftables`
- `configctl` or `service` instead of `systemctl`
- `sockstat` instead of `ss`
- `/var/log/*` instead of `journalctl`

Shell reality matters too:

- OPNsense uses `csh`
- pfSense uses `tcsh`
- complex remote logic should usually be sent as a `sh` heredoc over SSH

## Key commands

Shared packet-filter and diagnostics path:

- `pfctl -sr`
- `pfctl -sn`
- `pfctl -ss`
- `pfctl -si`
- `tcpdump`
- `sockstat -4l`
- `netstat -rn`

OPNsense-specific operations revolve around:

- `configctl`
- `pluginctl`
- `/conf/config.xml`

pfSense-specific operations revolve around:

- `pfSsh.php`
- `service`
- `/cf/conf/config.xml`

## Config model

Both platforms are XML-driven:

- XML is the source of truth
- generated service configs sit below that
- service reload or restart is usually needed after changes

Prefer platform-native helpers over raw XML edits when possible.

## IPv6

Main reminders:

- IPv4 and IPv6 rules are separate
- ICMPv6 is mandatory enough that blanket blocking is wrong
- delegated prefixes can change and break assumptions
- VPN and alias coverage need explicit IPv6 attention

## Plugins and packages

Check the plugin or package layer early:

- OPNsense plugins often explain hidden blocks or side effects
- pfSense package behavior can mirror OPNsense concepts but not the exact commands or paths

Use `references/plugins.md` for detailed OPNsense plugin guidance.

## Standard operating procedures

Before change:

1. back up config
2. explain the change
3. apply the change
4. verify connectivity, logs, and service status

Troubleshooting flow:

1. logs
2. plugin or package security layers
3. active rules, NAT, and state table
4. packet capture
5. DNS path
6. resource pressure

## Updates and maintenance

Update channels are not always coupled.

- verify update status explicitly
- dry-run package changes where possible
- do not apply upgrades without explicit confirmation
- expect that firmware work may require console recovery

## Backup, restore, and disaster recovery

Core rules:

- export config before risky work
- keep at least one remote backup method
- prefer full restore over partial XML surgery
- expect some cases to require reboot for a clean reload

If the firewall is virtualized, pair config backups with hypervisor snapshots before major upgrades.

## HA and CARP

HA guidance boils down to:

- understand CARP, pfSync, and config sync as separate moving parts
- change the master, not the backup
- update the backup first
- use maintenance mode intentionally

Use `references/hardening.md` for the deeper CARP and hardening checklist.
