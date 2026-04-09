# OPNsense Hardening & Improvement Checklist

Use this reference when auditing an OPNsense device or suggesting improvements.
Items are grouped by category. Not everything applies to every deployment -
tailor recommendations to the device's role and hardware constraints.

## DNS (Unbound)

- [ ] **DNSSEC enabled** + "Harden DNSSEC data" - validates upstream responses,
      marks unsigned trust-anchored zones as bogus
- [ ] **DNS over TLS** - port 853 to trusted resolvers (Cloudflare, Quad9, etc.).
      Always set "Verify CN" to prevent MITM. Block outgoing port 53 on WAN to
      force all DNS through the encrypted path
- [ ] **DNS rebinding protection** - enabled in Administration settings. Configure
      private network ranges that shouldn't appear in public DNS responses
- [ ] **Hide identity + version** - refuse `id.server` and `version.server` queries
- [ ] **Strict QNAME minimisation** - send minimal info to upstream resolvers
- [ ] **DNS blocklists** - built-in blocklist integration (ads, malware, trackers).
      Pair with an allowlist for false positives
- [ ] **Redirect rogue DNS** - NAT rule redirecting all outbound port 53 traffic
      to the local Unbound instance, preventing clients from bypassing local DNS
- [ ] **Safe Search enforcement** - "Force SafeSearch" option if appropriate for the network
- [ ] **Access control lists** - restrict query permissions by client network.
      Limit "Allow Snoop" to admin hosts only

## Firewall

- [ ] **Bogon/RFC1918 blocking on WAN** - block private and bogon networks on all
      WAN-facing interfaces (default in OPNsense, verify it hasn't been disabled)
- [ ] **GeoIP aliases** - block traffic from countries you have no business talking to.
      OPNsense supports MaxMind and IPinfo databases. Use continent-level blocks
      for broad coverage, country-level for precision. Monitor "Loaded#" field
      and adjust "Firewall Maximum Table Entries" if tables overflow
- [ ] **URL table blocklists** - Spamhaus DROP/EDROP, abuse.ch, emerging threats.
      Create URL Table aliases that auto-refresh, apply as block rules on WAN inbound
- [ ] **Default deny outbound** - don't rely on implicit allow. Explicitly permit
      only required outbound traffic per VLAN/interface
- [ ] **State tracking flush** - after modifying aliases used in stateful rules,
      flush connection states (Firewall > Diagnostics > States Dump) for
      immediate effect
- [ ] **Anti-lockout rule** - verify it exists on the management interface.
      On non-management interfaces, ensure there ISN'T an anti-lockout rule
      accidentally permitting traffic
- [ ] **Logging on deny rules** - enable logging on all deny/reject rules for
      CrowdSec and Suricata to analyze
- [ ] **Rule descriptions** - every rule should have a description. Undocumented rules
      become mystery rules in 6 months

## WireGuard VPN

- [ ] **Tunnel addressing** - use CIDR notation (e.g., 10.10.10.1/24), never /32.
      Use RFC1918 ranges distinct from existing LAN subnets
- [ ] **MTU** - 1420 default, 1412 for PPPoE. 80 bytes less than WAN MTU
- [ ] **MSS clamping** - create normalization rules: 1380 IPv4 (1372 PPPoE),
      1360 IPv6 (1352 PPPoE). Prevents TCP fragmentation through the tunnel
- [ ] **Assign WireGuard interface** - creates auto-aliases and outbound NAT rules.
      Cleaner than manual firewall rules on the raw wg device
- [ ] **DNS field** - leave blank on the server side to avoid overwriting
      OPNsense's DNS config. Only set on peer generator for road warriors
- [ ] **Firewall rules** - WAN: allow UDP to WireGuard port. Tunnel interface:
      allow traffic per policy. Don't forget both layers
- [ ] **Key rotation** - WireGuard keys don't expire, but periodic rotation is
      good practice, especially for road warrior peers

## Web GUI / SSH Hardening

- [ ] **HTTPS only** - never run the GUI over HTTP
- [ ] **HSTS enabled** - forces HTTPS, prevents certificate warning bypass
- [ ] **Session timeout** - set idle timeout (15-30min recommended)
- [ ] **CSRF protection** - verify HTTP Referer enforcement is enabled (default)
- [ ] **SSH key-only auth** - disable password login, require key-based auth
- [ ] **SSH interface binding** - bind to management interface only, not all interfaces
- [ ] **Non-default SSH port** - move off port 22 to reduce noise
- [ ] **Disable root SSH** - use a non-root account, escalate with `su` or group privileges
- [ ] **Restrict SSH ciphers** - disable weak KEX, ciphers, and MACs via GUI
      (System > Settings > Administration > Secure Shell)
- [ ] **Console password protection** - protect console menu from unauthorized physical access

## CrowdSec

- [ ] **Hub freshness** - `cscli hub update && cscli hub upgrade` regularly.
      Outdated parsers can miss log format changes after OPNsense upgrades
- [ ] **Collections installed** - at minimum: `crowdsecurity/freebsd`,
      `crowdsecurity/opnsense` (installed by default). Consider adding
      `crowdsecurity/http-cve`, `crowdsecurity/nginx` if running web services
- [ ] **Private IP whitelisting** - default since v1.6.3. Verify with
      `cscli parsers list | grep whitelist`. Only remove if you specifically
      need to ban LAN clients
- [ ] **Console enrollment** - connect to app.crowdsec.net for dashboard,
      shared threat intel, and alert notifications
- [ ] **Bouncer health** - `cscli bouncers list` should show an active bouncer
      with a recent last_pull timestamp
- [ ] **Decision review** - periodically check `cscli decisions list` for
      stale bans or false positives

## Firmware & Maintenance

- [ ] **Run audits before updating** - OPNsense has built-in firmware audits:
      connectivity audit (DNS, IPv6, HA/CARP), health audit (disk/filesystem),
      security audit (CVE check against installed packages)
- [ ] **Cleanup audit** - remove stale update temp files that can block future updates
- [ ] **Config backups** - verify automatic config backup is enabled
      (System > Configuration > Backups). Consider offsite backup via
      SFTP, Nextcloud, or Git integration
- [ ] **Backup before major upgrades** - export config + create hypervisor snapshot
      if virtualized. Major version upgrades can break plugins
- [ ] **Config history** - enable config change tracking for audit trail.
      Compare versions via unified diff if OPNcentral is installed

## HA / CARP

For multi-firewall deployments with automatic failover.

- [ ] **Dedicated pfSync interface** - state sync should use its own interface,
      not share with LAN or WAN. Security and performance reasons
- [ ] **XMLRPC sync on master only** - only the master pushes config to backup.
      Never configure XMLRPC sync on the backup node
- [ ] **Matching interface assignments** - master and backup must have identical
      interface assignments (same physical layout or mapped correctly)
- [ ] **CARP VIP subnet masks** - always match the parent interface's subnet mask.
      Mismatched masks cause split-brain
- [ ] **Outbound NAT to VIP** - switch from automatic to manual NAT, target the
      CARP virtual IP so NAT survives failover. Don't NAT to physical interface IPs
- [ ] **Firewall pass for CARP protocol** - allow IP protocol 112 on all interfaces
      participating in CARP
- [ ] **Switch compatibility** - disable or configure IGMP snooping, MAC flapping
      detection, and storm control on the connected switch. Enterprise switches
      (Cisco, Juniper) may need MLAG/stacking for reliable CARP MAC failover
- [ ] **Split-brain check** - both nodes showing MASTER = misconfigured VIPs or
      VHIDs. Verify exact config parity between nodes
- [ ] **Zero-downtime updates** - always update backup first, then put master into
      CARP maintenance mode, verify failover, update former master, leave maintenance mode

## Network Segmentation

- [ ] **VLANs for IoT/guest/management** - separate untrusted devices from the main LAN.
      Each VLAN gets its own interface, DHCP scope, and firewall rules
- [ ] **Inter-VLAN default deny** - block all inter-VLAN traffic by default,
      explicitly permit only required flows (e.g., IoT -> DNS only)
- [ ] **Management VLAN** - restrict GUI/SSH access to a dedicated management network.
      Don't expose the management interface to guest or IoT VLANs
- [ ] **DHCP per VLAN** - each VLAN gets its own DHCP scope with appropriate
      DNS servers, gateway, and lease times

## Monitoring & Alerting

Without monitoring, you only find out something is broken when users complain.

- [ ] **Metrics export** - install os-telegraf or os-node_exporter. Send metrics to
      InfluxDB/Prometheus/Grafana. Key metrics: CPU, RAM, disk, interface throughput,
      state table size, packet drops
- [ ] **Log forwarding** - configure syslog to forward to a central log server
      (Loki, Graylog, ELK). Critical for forensics and correlating events across devices
- [ ] **Disk usage alerts** - especially `/var` on small-disk devices (eMMC, CF cards).
      Suricata and CrowdSec logs fill disks fast. Monitor with Telegraf disk plugin
      or a cron script checking `df -h /var`
- [ ] **State table monitoring** - `pfctl -si | grep entries` shows current state count.
      Alert when approaching `net.pf.states_limit` (default 200000). Full state tables
      silently drop new connections
- [ ] **Certificate expiry monitoring** - if using ACME/Let's Encrypt, monitor cert
      expiry dates. A silently-failed renewal is worse than no ACME at all
- [ ] **CrowdSec bouncer health** - `cscli bouncers list` shows last pull time.
      Alert if a bouncer hasn't pulled in >15 minutes
- [ ] **WireGuard handshake staleness** - latest handshake >2 minutes = peer unreachable.
      Monitorable via `wg show` output parsing
- [ ] **Newsyslog rotation** - verify `/etc/newsyslog.conf` has appropriate rotation
      settings for all active log files. Default rotation may be insufficient for
      high-traffic devices with IDS/IPS enabled
