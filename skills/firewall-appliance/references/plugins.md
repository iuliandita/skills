# OPNsense Plugin Reference

Operational guidance for common plugins. Not exhaustive - for unlisted plugins,
inspect via `pkg info <name>` and check `/usr/local/etc/` for their configs.

## Security

### os-crowdsec (CrowdSec)
Local LAPI + bouncer (verify OPNsense package with `pkg info os-crowdsec`; upstream CrowdSec v1.7.7 as of May 2026 recheck). Parses logs locally, applies local bans + crowd-sourced blocklists.

**Two separate enforcement layers:**
- **Local decisions** (`crowdsec_blacklists` pf table): IPs your firewall detected and banned
  based on its own log parsing. These are the ones that matter most - they reflect actual
  attacks against YOUR infrastructure.
- **CAPI blocklists** (`crowdsec_blocklists` pf table): crowd-sourced community blocklist
  pulled from CrowdSec central API. Useful background protection, but less actionable for
  health checks (thousands of IPs, mostly noise).

```
# Local activity (check these first)
cscli decisions list             # active LOCAL bans - what YOUR firewall caught
cscli alerts list -l 15          # recent detections with scenario/source/country
cscli metrics                    # parsing stats, scenario hits, bouncer pulls

# Bouncer health
cscli bouncers list              # registered bouncers + last pull timestamp

# pf table enforcement
pfctl -t crowdsec_blacklists -T show | wc -l   # local ban count in pf
pfctl -t crowdsec_blocklists -T show | wc -l   # CAPI community blocklist count

# Hub maintenance
cscli hub update && cscli hub upgrade  # update detection scenarios + parsers
```

- Logs: `/var/log/crowdsec/crowdsec.log`, bouncer: `/var/log/crowdsec/crowdsec-firewall-bouncer.log`
- Config via GUI: Services > CrowdSec > Settings (preferred over CLI config edits)
- **Troubleshooting priority**: always check `cscli decisions list` when diagnosing
  connectivity issues. CrowdSec bans look identical to firewall blocks from the client's
  perspective.
- Stale decisions: CrowdSec doesn't auto-expire all decision types. Review periodically.
- Hub updates: scenarios and parsers need manual hub upgrades. Outdated parsers can miss
  log format changes after OPNsense upgrades.
- Private IP whitelisting: default since v1.6.3. Verify with
  `cscli parsers list | grep whitelist`. Only remove if you specifically need to ban LAN clients.
- Default collections: `crowdsecurity/freebsd` and `crowdsecurity/opnsense` installed automatically.
  Consider adding `crowdsecurity/http-cve` if running web services.
- Testing safely: `cscli decisions add -t ban -d 2m -i <ip>` - 2-minute test ban.
  Find your connecting IP: `echo $SSH_CLIENT | awk '{print $1}'`
- Console enrollment: connect to app.crowdsec.net for dashboard and shared threat intel.
  Without enrollment, you'll see periodic "Machine is not enrolled" log messages - cosmetic only,
  does not affect LAPI or CAPI functionality.

### os-acme-client (Let's Encrypt)
Automated TLS certificate management.

- Check cert expiry: `openssl x509 -enddate -noout -in <cert-path>`
- Renewal logs: GUI under Services > ACME > Log
- Common failure: DNS validation failing due to Unbound caching stale records.
  Restart DNS after ACME config changes.
- Verify automations are actually running - a configured ACME client that stopped
  renewing silently is worse than no ACME at all.

### os-openconnect (OpenConnect VPN)
SSL VPN server compatible with Cisco AnyConnect clients. Good for environments requiring
browser-based VPN login or RADIUS/LDAP auth integration.

- Config: GUI under VPN > OpenConnect
- Logs: `/var/log/ocserv.log`
- Status: `sockstat -4l | grep ocserv` to verify it's listening

### os-zerotier (ZeroTier)
Peer-to-peer mesh VPN. Useful for connecting devices across NATs without port forwarding.
Not a traditional firewall VPN - operates more like a virtual switch.

- Join network: `zerotier-cli join <network-id>`
- Status: `zerotier-cli listnetworks`
- Peers: `zerotier-cli listpeers`
- **Firewall interaction**: ZeroTier creates a virtual interface. Needs firewall pass rules
  on that interface just like any other network segment.

### os-stunnel (SSL Tunnel)
Wraps non-SSL services in TLS. Niche - usually only needed for legacy protocols.
Config: `/usr/local/etc/stunnel/stunnel.conf`.

## Networking

### os-wireguard (WireGuard VPN)
Modern VPN tunnels. Kernel-level, fast, minimal config.

```
wg show                          # all tunnels: peers, handshakes, transfer
wg show <iface> dump             # machine-readable output
```

- **Stale handshakes**: latest handshake >2 minutes ago = peer is unreachable or
  misconfigured. Check: endpoint IP, allowed IPs, firewall pass rules on the `wg` interface.
- **NAT alignment**: allowed-IPs in WireGuard config must match firewall pass rules on the
  tunnel interface. Mismatch = traffic silently dropped.
- **Tunnel addressing**: use CIDR notation (e.g., 10.10.10.1/24), never /32. Use RFC1918
  ranges distinct from existing LAN subnets.
- **MTU**: 1420 default, 1412 for PPPoE (80 bytes less than WAN MTU).
- **MSS clamping**: create normalization rules to prevent TCP fragmentation through the tunnel.
  IPv4: 1380 (1372 PPPoE). IPv6: 1360 (1352 PPPoE).
- **Assign the WireGuard interface**: creates auto-aliases and outbound NAT rules.
  Cleaner than manual firewall rules on the raw wg device.
- **DNS field**: leave blank on the server side to avoid overwriting OPNsense's DNS config.
  Only set on peer generator for road warriors.
- Restart: `configctl wireguard stop && configctl wireguard start`
- Zero-downtime reload: `/usr/local/etc/rc.d/wireguard reload` (uses `wg syncconf` under the hood)
- Alternative: `pluginctl -s wireguard start` / `stop` / `status`
- **pfSense**: WireGuard is available as `pfSense-pkg-WireGuard`. Commands differ -
  use `service wireguard restart` or manage via GUI (VPN > WireGuard).

### os-haproxy (Load Balancer / Reverse Proxy)
TCP/HTTP load balancer with health checks and SSL offloading.

- Config: `/usr/local/etc/haproxy/`
- Stats socket: `echo "show stat" | socat /var/run/haproxy.socket stdio`
- Backend health: `echo "show servers state" | socat /var/run/haproxy.socket stdio`
- **Firewall interaction**: HAProxy listen addresses need corresponding firewall pass rules.
  Missing rules = connection refused despite HAProxy being configured correctly.

### os-frr (Dynamic Routing)
BGP, OSPF, and other routing protocols via FRRouting.

```
vtysh -c "show ip bgp summary"
vtysh -c "show ip ospf neighbor"
vtysh -c "show ip route"
```

### os-ddclient (Dynamic DNS)
Updates external DNS providers with current WAN IP.

- Config: `/usr/local/etc/ddclient.conf`
- Logs: check syslog for ddclient entries
- Force update: `configctl ddclient force`

## IDS/IPS

### os-suricata (Intrusion Detection/Prevention)
Deep packet inspection. Can run in IDS (alert) or IPS (drop) mode.

```
configctl ids update             # update rule sets
configctl ids restart            # restart Suricata
```

- Logs: `/tmp/suricata_*.log`, also `/var/log/suricata/eve.json` (JSON event log)
- **RAM**: needs 1-2GB minimum. On 4GB devices, Suricata + CrowdSec together is tight.
- **Silent drops**: IPS mode drops matching traffic without any pfctl state entry.
  If traffic vanishes between tcpdump on input and output interfaces, check Suricata logs.
- Rule management: OPNsense auto-downloads ET Open rules by default. Custom rules go in
  the GUI under Services > Intrusion Detection > Rules.

### os-zenarmor (Sensei)
Application-level DPI engine. Even more RAM-hungry than Suricata (2-4GB+).
Generally not suitable for low-memory devices.

## Monitoring

### os-telegraf
Metrics collection agent. Outputs to InfluxDB, Prometheus, etc.

- Config: `/usr/local/etc/telegraf.conf`
- Check output plugin connectivity and buffer status in logs

### os-node_exporter / os-zabbix-agent
Standard monitoring agents. Verify they're listening on expected ports with `sockstat`.

### os-ntopng
Network traffic analysis. Web UI on port 3000 by default.

- **RAM**: 1-2GB+ depending on traffic volume. Not recommended on <8GB devices.

## Virtualization

### os-qemu-guest-agent
QEMU/KVM guest integration. Enables graceful shutdown and filesystem freeze from hypervisor.
No operational concerns - it either works or it doesn't.

### os-vmtools
VMware Tools integration. Same as above but for ESXi/vSphere.

## Plugin interaction gotchas

- **CrowdSec + Suricata**: both can block the same traffic independently. When diagnosing
  a block, check both. CrowdSec operates at the firewall level (pfctl), Suricata at the
  packet inspection level.
- **WireGuard + NAT**: tunnel traffic needs both WireGuard allowed-IPs and pfctl pass rules
  on the tunnel interface. Missing either = silent drop.
- **HAProxy + firewall**: HAProxy binds to addresses that need explicit firewall pass rules.
- **RAM stacking**: multiple heavy plugins compound. Budget: CrowdSec ~200MB, Suricata ~1-2GB,
  ntopng ~1-2GB, Zenarmor ~2-4GB. On a 4GB device, pick at most two of these.
- **Plugin updates vs firmware updates**: plugin updates (`pkg upgrade`) are independent of
  firmware updates (`opnsense-update`). Both can introduce breaking changes. Always check
  changelogs before upgrading.

## OPNsense Release Notes (25.1 / 25.7 / 26.1)

### 25.1 "Ultimate Unicorn" (Jan 2025)
- User/group/privilege management migrated to MVC/API
- "Disable integrated authentication" option removed
- Manual LDAP importer removed
- PPP devices no longer configurable via interface settings
- Certificate expiration tracking widget added
- ZFS snapshot GUI support added
- Kea DHCPv6 support added

### 25.7 "Visionary Viper" (Jul 2025)
- **Dnsmasq replaces ISC DHCP as default** for new installations
  - ISC DHCP moves to plugins in 26.1
  - Migration tools: `isc2kea` for complex setups, Dnsmasq for simple
- **API URLs switched from camelCase to snake_case** (breaking for automation scripts)
- Default system domain changed to `internal`
- OpenVPN legacy and IPsec legacy moved to plugins
- Google Drive backups deprecated
- FreeBSD 14.3-RELEASE-p1 base, Python 3.13
- Experimental privilege separation: web GUI can run as non-root `wwwonly` user
- Setup wizard completely rewritten (MVC/API)

### Dnsmasq migration gotchas (ISC DHCP -> Dnsmasq)
- **Reservations MUST be inside the pool range** - ISC DHCP required them outside. This is the #1 migration footgun. Existing reservations silently break.
- **Unbound DNS can't resolve dnsmasq reservations** unless the `Domain` field is explicitly set per reservation (OPNsense [Issue #8612](https://github.com/opnsense/core/issues/8612))
- **macOS clients get `.localdomain` appended** post-migration, causing resolution failures
- **Port conflicts**: disable ISC DHCP/Kea BEFORE enabling dnsmasq - they grab the same ports
- Migration scripts: [meyergru/iscdhcp_to_dnsmasq](https://github.com/meyergru/iscdhcp_to_dnsmasq), [dreary-ennui/Convert-OPNSenseISCDHCPtoDNSMasqDHCP](https://github.com/dreary-ennui/Convert-OPNSenseISCDHCPtoDNSMasqDHCP)

### Migration checklist
- [ ] Check API scripts for camelCase URLs - update to snake_case
- [ ] Plan ISC DHCP migration path before upgrading to 26.1
- [ ] Verify DHCP reservations are INSIDE the pool range (dnsmasq requirement)
- [ ] Set Domain field on all DHCP reservations if using Unbound DNS
- [ ] Test macOS client DNS resolution post-migration
- [ ] Disable ISC DHCP before enabling dnsmasq (port conflict)
- [ ] Review PPP configuration if using PPPoE/DSL connections
- [ ] Test custom plugins against Python 3.13 compatibility
- [ ] Update backup scripts if using Google Drive backend

### 26.1 "Witty Woodpecker" (Jan 28, 2026) - CURRENT STABLE

Current release: **26.1.5** (March 26, 2026). 25.7.x series EOL at 25.7.11.

- Redesigned Firewall Rules interface
- IDPS moved to declarative `conf.d` structure + new inline inspection mode
- Unbound DNS: multiple blocklist sources now in CE (was Business-only)
- New **Host Discovery** function (auto-identifies devices on connected networks)
- Router Advertisement / interface config migrated to MVC/API
- Extended API coverage for Source NAT tagging and Destination NAT
- ISC DHCP moved to plugins (as planned from 25.7 deprecation)
