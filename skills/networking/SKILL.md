---
name: networking
description: >
  · Configure and debug Linux networking: DNS, reverse proxies, VPNs, WireGuard, VLANs, nftables, and routing.
license: MIT
compatibility: "Requires Linux. Tools vary by task: nftables, WireGuard, dig, mtr, tcpdump"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-25"
  effort: high
  argument_hint: "<task-or-topology>"
---

# Networking: Configuration, Troubleshooting, and Optimization

Configure, troubleshoot, and optimize Linux networking infrastructure. Covers DNS, reverse proxies,
VPNs, firewalls (nftables), VLANs, subnetting, high availability, dynamic routing, and network
performance tuning.

**Target versions** (September 2026):

| Tool | Version | Notes |
|------|---------|-------|
| Caddy | 2.11.4 | Auto-HTTPS, Caddyfile + JSON API |
| Nginx | 1.30.5 stable / 1.31.6 mainline | Patched for CVE-2026-90439; includes fixes for CVE-2026-42533/60005/56434 |
| Traefik | 3.7.12 | Gateway API native, v2 EOL approaching |
| HAProxy | 3.4.4 LTS / 3.3.14 stable / 3.2.23 LTS | 3.4 LTS EOL 2031-Q2 |
| WireGuard tools | 1.0.20260223 | Kernel module + userspace tools |
| strongSwan | 6.0.7 | swanctl config (legacy ipsec.conf deprecated) |
| nftables | 1.1.7 | iptables successor, default on modern distros |
| keepalived | 2.4.3 | VRRP + health checks |
| Unbound | 1.26.0 | Includes July 2026 DNS security fixes |
| CoreDNS | 1.14.7 | K8s default DNS, plugin-based |
| FRRouting | 10.7.1 (retained, unverified) | Verify the current publisher release before targeting this pin |
| Tailscale / Headscale | Headscale 0.29.3 | Self-hosted control server |
| cloudflared | 2026.8.3 | Cloudflare Tunnel (outbound-only) |
| OpenVPN | 2.7.7 / 2.6.21 LTS | 2.7.x: multi-socket, DCO; 2.6 is the LTS branch |

Security recheck (2026-09-16): nginx's [publisher advisories](https://nginx.org/en/security_advisories.html)
rate CVE-2026-90439 (HTTP/3 buffer overflow) medium: affected 1.29.2-1.31.5, fixed in
1.30.5+ or 1.31.6+. CVE-2026-42533 (map/regex buffer overflow) major: affected
0.9.6-1.31.2, fixed in 1.30.4+ or 1.31.3+; CVE-2026-60005 and CVE-2026-56434 were
fixed in those same 1.30.4+/1.31.3+ releases. CVE-2026-42530 (HTTP/3 use-after-free)
affects 1.31.0-1.31.1 and is fixed in 1.31.2+. The separate, earlier CVE-2026-42945
(rewrite buffer overflow) was fixed in 1.30.1/1.31.0. Check enabled modules and
vendor backports.
[Unbound advisories](https://nlnetlabs.nl/projects/unbound/security-advisories/) also
rate CVE-2026-32665 high: DoQ-enabled 1.22.0-1.25.1 is affected, with a fix in
1.25.2. Check compile-time DoQ support and configured listeners before assessing exposure.

## When to use

- Configuring DNS servers (Unbound, CoreDNS, dnsmasq, BIND9, Pi-hole, AdGuard Home)
- Setting up or troubleshooting reverse proxies and load balancers
- VPN configuration (WireGuard, OpenVPN, IPsec) and overlay networks
- Linux firewall rules (nftables, legacy iptables)
- VLAN configuration, subnetting, network segmentation
- High availability with keepalived/VRRP, floating IPs
- Network diagnostics (tcpdump, mtr, ss, dig, iperf3, Wireshark/tshark)
- TCP/network performance tuning (MTU, buffers, congestion control, bufferbloat)
- Dynamic routing with FRRouting (BGP, OSPF)
- TLS/certificate management for network services
- Split-horizon DNS, DNS-over-HTTPS/TLS, DNSSEC

## When NOT to use

- OPNsense/pfSense firewall appliance management (use **firewall-appliance**)
- Web browsing, scraping, or headless page interaction - use **browse**
- Kubernetes networking: NetworkPolicy, Gateway API, service mesh, CNI (use **kubernetes**)
- Broad Kubernetes cluster health checks, node status, and post-maintenance diagnostics (use **cluster-health**)
- Docker/container networking: bridge, overlay, Compose networks (use **docker**)
- Cloud VPCs, security groups, managed load balancers (use **terraform**)
- Network config management at scale via playbooks (use **ansible**)
- Offensive pentesting, exploitation, lateral movement (use **lockpick**)
- Application-level security review, SSRF, header injection (use **security-audit**)
- CI/CD-automated network configuration management at pipeline scale (use **ci-cd**)

---

## AI Self-Check

Before returning any generated network configuration, verify:

- [ ] **No hardcoded secrets**: passwords, PSKs, API keys use placeholders or env vars
- [ ] **Correct interface names**: didn't assume `eth0` - modern Linux uses predictable names
  (`enp0s3`, `ens18`, etc.). Ask or check `ip link` output
- [ ] **MTU considered**: VPN tunnels need reduced MTU (WireGuard: 1420, OpenVPN: ~1400, VXLAN:
  1450). Mismatched MTU causes silent packet drops
- [ ] **DNS resolver order**: systemd-resolved vs /etc/resolv.conf vs NetworkManager - check
  which DNS manager is active before modifying
- [ ] **Firewall persistence**: nftables rules need `nft list ruleset > /etc/nftables.conf` or
  a service to persist across reboots. Raw `nft add` commands are ephemeral
- [ ] **Port conflicts checked**: reverse proxy ports (80, 443) may conflict with existing
  services. Verify with `ss -tlnp`
- [ ] **TLS versions**: minimum TLS 1.2 for all services. TLS 1.3 preferred where supported
- [ ] **Private IP ranges correct**: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (not /24)
- [ ] **Subnet overlap**: VPN address ranges must not overlap with LAN or other VPN ranges
- [ ] **IPv6 considered**: dual-stack config or explicit disable. Half-configured IPv6 leaks
  traffic around IPv4-only VPNs
- [ ] **Backup before modifying**: save current config before changes (`nft list ruleset >
  backup.nft`, `cp nginx.conf nginx.conf.bak`). Network misconfigs can lock out remote access
- [ ] **Service reload vs restart**: prefer graceful reload (`nginx -s reload`, `systemctl
  reload`) over restart to avoid dropping active connections
- [ ] **IP forwarding enabled**: any config involving routing, VPN, or inter-VLAN traffic
  needs `net.ipv4.ip_forward = 1` (and `net.ipv6.conf.all.forwarding = 1` for dual-stack).
  Without it, the kernel silently drops forwarded packets
- [ ] **systemd-resolved conflict**: if deploying a local DNS server (Unbound, CoreDNS,
  dnsmasq), check whether systemd-resolved is binding port 53. Disable its stub listener
  (`DNSStubListener=no`) or bind your server to a different port
- [ ] **Topology verified**: interface names, routes, DNS resolvers, namespaces, VPN state, and firewall backend are observed before changes
- [ ] **Rollback path preserved**: remote network changes include timed rollback, console access, or an alternate path
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

---

## Performance

- Measure path, DNS, TLS, and application latency separately before tuning.
- Use packet captures with narrow filters and time windows to avoid huge captures and privacy spill.
- Prefer persistent nftables sets, DNS caches, and proxy connection reuse where appropriate.


---

## Best Practices

- Diagnose before changing: capture current routes, rules, addresses, and resolver state.
- Change one layer at a time: DNS, routing, firewall, proxy, VPN, or application.
- Keep emergency access open when editing firewall, VPN, or default-route configuration remotely.


## Workflow

### Step 1: Identify the task type

| Task type | Start with | Reference |
|-----------|------------|-----------|
| **Troubleshoot** | Symptoms, recent changes, affected scope | `references/troubleshooting.md` |
| **Configure DNS** | Current resolver, authoritative vs recursive, split-horizon needs | `references/dns.md` |
| **Set up reverse proxy** | Which proxy, upstream services, TLS requirements | `references/reverse-proxies.md` |
| **Configure VPN** | Topology (p2p, hub-spoke, mesh), protocol choice | `references/vpn.md` |
| **Network segmentation** | VLANs, subnets, nftables zones, namespaces | `references/segmentation.md` |
| **High availability** | keepalived/VRRP, floating IPs, health checks | `references/ha.md` |

### Step 2: Gather context

Before writing config or running commands:

1. **What distro and init system?** (systemd vs OpenRC - affects service management)
2. **What's the current network state?** (`ip addr`, `ip route`, `ss -tlnp`, `resolvectl status`)
3. **Is there an existing firewall?** (`nft list ruleset`, `iptables-save`)
4. **Who manages DNS?** (`resolvectl status` or `cat /etc/resolv.conf` - check for systemd-resolved stub)
5. **Any existing VPN/overlay?** (`wg show`, `tailscale status`, `ip link` for tun/wg/vxlan devices)
6. **Is this behind NAT?** (affects VPN, reverse proxy, and HA design)

### Step 3: Implement

Read the appropriate reference file for detailed patterns. Key principles:

- **Test before persisting.** Add nftables rules, verify connectivity, then save. Apply reverse
  proxy config changes with `--dry-run` or syntax check first (`caddy validate`, `nginx -t`,
  `haproxy -c`).
- **One change at a time.** Over SSH, save the exact rules/routes/manager configuration being
  changed and schedule a tested restoration command before applying. A generic networking
  restart is not a rollback. Verify the timer exists; cancel it only after a second session
  confirms management access and the intended allowed/blocked traffic.
- **Log what you changed.** Network debugging is 10x harder when you don't know what changed.

### Step 4: Validate

| What to validate | How |
|-----------------|-----|
| DNS resolution | `dig @server domain A +short`, `dig domain AAAA +short` |
| Reverse proxy | `curl -v https://domain` (verify certificate trust, headers, upstream response) |
| VPN tunnel | `wg show` (WireGuard), `ping` across tunnel, check `ip route` |
| Firewall rules | `nft list ruleset`, test both allowed and blocked traffic |
| VLAN tagging | `ip -d link show`, `tcpdump -e -i interface` (check 802.1Q tags) |
| HA failover | Stop primary, verify VIP migrates, check `journalctl -u keepalived` |
| Performance | `iperf3 -c server`, `mtr target`, check for packet loss and jitter |

---

## Quick Reference: Diagnostic Tools

| Tool | Purpose | Key usage |
|------|---------|-----------|
| `ip` | Interface, route, neighbor, rule management | `ip addr`, `ip route`, `ip neigh`, `ip link` |
| `ss` | Socket statistics (replaces netstat) | `ss -tlnp` (TCP listeners), `ss -ulnp` (UDP) |
| `dig` | DNS queries | `dig @8.8.8.8 example.com A +short` |
| `mtr` | Combined traceroute + ping | `mtr -n --report target` (non-interactive) |
| `tcpdump` | Packet capture | `tcpdump -i any -nn port 53` (DNS traffic) |
| `tshark` | Wireshark CLI | `tshark -i any -f 'port 443' -Y 'tls.handshake'` |
| `curl` | HTTP testing | `curl -v -o /dev/null https://target` (verified TLS and HTTP details) |
| `iperf3` | Bandwidth testing | Server: `iperf3 -s` / Client: `iperf3 -c server` |
| `nft` | nftables rule management | `nft list ruleset`, `nft monitor trace` |
| `wg` | WireGuard status | `wg show`, `wg showconf wg0` |
| `resolvectl` | systemd-resolved status | `resolvectl status`, `resolvectl query domain` |
| `doggo` | Modern dig alternative | `doggo example.com A @8.8.8.8 --json` |
| `nmap` | Port scanning, service detection | `nmap -sV -p 1-1024 target` |
| `socat` | Multipurpose relay | `socat TCP-LISTEN:8080,fork TCP:backend:80` |

---

## Quick Reference: CIDR and DNS

CIDR/netmask and DNS record-type lookup tables live in `references/cheat-sheets.md`. Load that
file only when a task needs the literal mapping.

---

## Quick Reference: Reverse Proxy Selection

| Proxy | Best for | TLS | Config style | L4 support |
|-------|----------|-----|-------------|------------|
| **Caddy** | Simple setups, auto-HTTPS | Automatic (ACME) | Caddyfile / JSON API | Yes (experimental) |
| **Nginx** | High traffic, static files | Manual or certbot | nginx.conf | Yes (stream module) |
| **Traefik** | Docker/K8s, dynamic backends | Automatic (ACME) | Labels / file / K8s CRDs | Yes (TCP/UDP) |
| **HAProxy** | Pure load balancing, L4/L7 | Manual | haproxy.cfg | Yes (native) |

### Caddy reverse proxy quick start

```
# /etc/caddy/Caddyfile - three subdomains, auto-HTTPS
app.example.com {
    reverse_proxy localhost:3000
}

api.example.com {
    reverse_proxy localhost:8080
}

grafana.example.com {
    reverse_proxy localhost:3001
}
```

Caddy handles TLS certificate provisioning automatically via ACME (Let's Encrypt). DNS A/AAAA
records for all three subdomains must point to the host. Validate: `caddy validate --config /etc/caddy/Caddyfile`.

Read `references/reverse-proxies.md` for configuration patterns, TLS setup,
health checks, rate limiting, and WebSocket/gRPC proxying.

---

## Quick Reference: VPN Protocol Selection

| Protocol | Speed | Complexity | Key exchange | Best for |
|----------|-------|-----------|--------------|----------|
| **WireGuard** | Fastest | Minimal config | Noise (Curve25519) | P2P, hub-spoke, general use |
| **OpenVPN** | Good | Complex PKI | TLS/x509 | Legacy, tap mode (L2) |
| **IPsec (strongSwan)** | Good | Most complex | IKEv2 | Site-to-site, standards compliance |
| **Tailscale/Headscale** | Fast (WG underneath) | Zero config | WG + DERP relays | Overlay mesh, remote access |
| **Nebula** | Fast | Low | Certificate-based | Large mesh, Slack-scale |

### WireGuard site-to-site quick start

Each peer must route its local LAN. If WireGuard runs on a separate host rather than the LAN's
default gateway, add a route on each LAN gateway for the remote LAN via its local WireGuard
host. Verify return routes, forwarding and firewall policy in both directions; tunnel-peer
pings alone do not prove LAN-to-LAN connectivity.

```ini
# Site A (/etc/wireguard/wg0.conf) - 10.0.1.0/24
[Interface]
PrivateKey = <SITE_A_PRIVATE_KEY>
Address = 10.100.0.1/30
ListenPort = 51820
# MTU: derive from measured underlay; 1420 for 1500-byte underlay with 80-byte overhead,
# or 1412 for a 1492-byte PPPoE underlay with the same overhead.

[Peer]
PublicKey = <SITE_B_PUBLIC_KEY>
Endpoint = site-b.example.com:51820
AllowedIPs = 10.0.2.0/24, 10.100.0.2/32
PersistentKeepalive = 25

# Site B (/etc/wireguard/wg0.conf) - 10.0.2.0/24
[Interface]
PrivateKey = <SITE_B_PRIVATE_KEY>
Address = 10.100.0.2/30
ListenPort = 51820

[Peer]
PublicKey = <SITE_A_PUBLIC_KEY>
Endpoint = site-a.example.com:51820
AllowedIPs = 10.0.1.0/24, 10.100.0.1/32
PersistentKeepalive = 25
```

Both sides need `net.ipv4.ip_forward = 1` in `/etc/sysctl.d/`. **AllowedIPs** is the remote
subnet (not `0.0.0.0/0` - that's full-tunnel, not site-to-site). Generate keys in a new
protected directory with `umask 077`, following `references/vpn.md`; never overwrite existing keys.

Read `references/vpn.md` for setup patterns, key management, MTU tuning,
NAT traversal, and overlay network comparison.

---

## Quick Reference: nftables vs iptables

iptables is legacy. nftables is the default on Debian 11+, RHEL 9+, Arch, and most modern distros.

```
# Minimal nftables ruleset - stateful firewall with SSH
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    tcp dport 22 accept
    icmp type echo-request accept
    icmpv6 type { echo-request, nd-neighbor-solicit, nd-router-advert } accept
  }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy accept; }
}
```

Read `references/segmentation.md` for VLAN setup, nftables zones, network
namespaces, and inter-VLAN routing patterns.

---

## PCI-DSS 4.0 Relevance

Network configuration touches several PCI-DSS requirements:

| Req | Area | What to check |
|-----|------|--------------|
| 1.2 | Network security controls | Firewall rules restrict inbound/outbound to minimum necessary |
| 1.3 | CDE segmentation | VLANs, nftables, or physical separation between CDE and other networks |
| 1.4 | Trusted/untrusted boundaries | Reverse proxy TLS termination, WAF placement |
| 2.2 | Hardening | Disable unnecessary services, unused ports closed |
| 4.1 | Encryption in transit | TLS 1.2+ everywhere, no plaintext on untrusted segments |
| 11.3 | Network monitoring | IDS/IPS (Suricata), log aggregation, flow analysis |

---

## Reference Files

- `references/dns.md` - DNS server comparison, DNSSEC, split-horizon,
  DoH/DoT, Pi-hole/AdGuard, troubleshooting
- `references/reverse-proxies.md` - Caddy, Nginx, Traefik, HAProxy
  configuration patterns, TLS, WebSocket, gRPC, rate limiting
- `references/vpn.md` - WireGuard, OpenVPN, IPsec/strongSwan setup,
  overlay networks (Tailscale, Headscale, Nebula, ZeroTier), key management
- `references/segmentation.md` - VLANs, subnetting, nftables firewall
  patterns, network namespaces, IPv6
- `references/troubleshooting.md` - Diagnostic methodology, tool deep-dives,
  common issues, performance tuning
- `references/ha.md` - keepalived/VRRP, floating IPs, HAProxy + keepalived
  HA, health check patterns
- `references/cheat-sheets.md` - CIDR/netmask table, private/CGNAT/link-local/ULA
  ranges, DNS record types

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** NETWORKING
- **Deliverable bucket:** `audits`
- **Mode:** conditional. When invoked to **analyze, review, audit, or improve** existing repo content, emit the full contract - monospace inline header, severity-grouped inline summary, linked Markdown deliverable, and concise monospace conclusion - and write the deliverable to `docs/local/audits/networking/<YYYY-MM-DD>-<slug>.md`. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; only used in audit/review mode).

## Related Skills

- **firewall-appliance** - manages BSD-based firewall appliances (OPNsense, pfSense). This skill
  handles Linux networking; firewall-appliance handles FreeBSD appliance firewalls. If the user
  mentions pfctl, CARP, or OPNsense/pfSense hostnames, route to firewall-appliance.
- **kubernetes** - owns K8s networking (NetworkPolicy, Gateway API, service mesh, CNI). This
  skill covers general DNS and proxy config; K8s-specific networking goes to kubernetes.
- **cluster-health** - owns read-only Kubernetes cluster diagnostics. If the request is
  "is the cluster healthy?" rather than "configure DNS/proxy/routing", route there.
- **docker** - owns container networking (bridge, Compose networks, port mapping). This skill
  covers host-level Linux networking.
- **terraform** - owns cloud infrastructure (VPCs, security groups, cloud LBs, Route53). This
  skill covers bare-metal/VM networking.
- **ansible** - manages config at scale via playbooks. This skill provides the networking
  knowledge; ansible handles the automation wrapper.
- **lockpick** - offensive network testing, exploitation, lateral movement. This skill covers
  defensive configuration and hardening.
- **security-audit** - application-level security review (SSRF, header injection). This skill
  covers network-layer security (firewalls, TLS, segmentation).
- **browse** - web browsing, scraping, headless page interaction. This skill covers network
  infrastructure, not web content retrieval.
- **ci-cd** - pipeline design for automated network config management. This skill provides the networking knowledge; ci-cd handles pipeline orchestration around it.

## Rules

1. **Ask which interface.** Never assume `eth0`. Modern Linux uses predictable interface names.
   Check with `ip link` or ask the user.
2. **Test before persisting.** Network misconfigs can lock you out of remote machines. Apply
   changes temporarily, verify connectivity (especially SSH), then persist.
3. **MTU matters.** VPN tunnels, VXLAN, and PPPoE all reduce effective MTU. Mismatched MTU
   causes silent packet drops that are painful to debug. Always calculate and set explicitly.
4. **Check who manages DNS.** systemd-resolved, NetworkManager, and manual /etc/resolv.conf
   fight each other. Identify the active manager before making DNS changes.
5. **Verify the existing firewall.** Check `nft list ruleset` and `iptables-save` before
   adding rules. Mixing nftables and iptables on the same system causes unpredictable behavior.
6. **No plaintext on untrusted segments.** TLS 1.2+ for all services. If something needs to
   cross an untrusted network without TLS, tunnel it through a VPN.
7. **Subnet overlap kills VPNs.** Before assigning VPN address ranges, inventory all LAN
   subnets and existing VPN ranges. Overlapping ranges cause routing black holes.
8. **Defer to specialized skills.** OPNsense/pfSense -> firewall-appliance. K8s networking -> kubernetes.
   Container networking -> docker. Cloud infra -> terraform. Pentesting -> lockpick.
