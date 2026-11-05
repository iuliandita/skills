---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Caddy"
    version: "2.11.6"
    source: "https://github.com/caddyserver/caddy/releases"
  - tool: "Nginx"
    version: "1.30.5 stable / 1.31.6 mainline"
    source: "https://nginx.org/en/security_advisories.html"
  - tool: "Traefik"
    version: "3.7.13 (v2 lane 2.11.57)"
    source: "https://github.com/traefik/traefik/releases"
  - tool: "HAProxy"
    version: "3.4.6 LTS / 3.3.16 stable / 3.2.25 LTS"
    source: "https://www.haproxy.org/"
  - tool: "WireGuard tools"
    version: "1.0.20260223"
    source: "https://git.zx2c4.com/wireguard-tools/"
  - tool: "strongSwan"
    version: "6.1.0"
    source: "https://github.com/strongswan/strongswan/releases"
  - tool: "nftables"
    version: "1.1.7"
    source: "https://netfilter.org/projects/nftables/"
  - tool: "keepalived"
    version: "2.4.3"
    source: "https://github.com/acassen/keepalived/releases"
  - tool: "Unbound"
    version: "1.26.1"
    source: "https://nlnetlabs.nl/projects/unbound/security-advisories/"
  - tool: "CoreDNS"
    version: "1.14.7"
    source: "https://github.com/coredns/coredns/releases"
  - tool: "FRRouting"
    version: "10.7.1"
    source: "https://github.com/FRRouting/frr/releases"
  - tool: "Headscale"
    version: "0.29.4"
    source: "https://github.com/juanfont/headscale/releases"
  - tool: "cloudflared"
    version: "2026.9.3"
    source: "https://github.com/cloudflare/cloudflared/releases"
  - tool: "OpenVPN"
    version: "2.7.7 / 2.6.23 LTS"
    source: "https://openvpn.net/community-downloads/"
---

# Networking target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Notes |
|------|---------|-------|
| Caddy | 2.11.6 | Auto-HTTPS, Caddyfile + JSON API; GHSA-6365-7ppr-5r92 is fixed since 2.11.5 |
| Nginx | 1.30.5 stable / 1.31.6 mainline | Patched for CVE-2026-90439; includes fixes for CVE-2026-42533/60005/56434 |
| Traefik | 3.7.13 (v2 lane 2.11.57) | Gateway API native, v2 EOL approaching |
| HAProxy | 3.4.6 LTS / 3.3.16 stable / 3.2.25 LTS | 3.4 LTS EOL 2031-Q2 |
| WireGuard tools | 1.0.20260223 | Kernel module + userspace tools |
| strongSwan | 6.1.0 (fixes CVE-2026-78133 and ten others, 2026-09-07) | swanctl config (legacy ipsec.conf deprecated) |
| nftables | 1.1.7 | iptables successor, default on modern distros |
| keepalived | 2.4.3 | VRRP + health checks |
| Unbound | 1.26.1 | Security floor after the 2026-09-16 advisories |
| CoreDNS | 1.14.7 | K8s default DNS, plugin-based |
| FRRouting | 10.7.1 | Released 2026-08-31 alongside 10.6.2/10.5.5/10.4.5 |
| Tailscale / Headscale | Headscale 0.29.4 | Self-hosted control server |
| cloudflared | 2026.9.3 | Cloudflare Tunnel (outbound-only) |
| OpenVPN | 2.7.7 / 2.6.23 LTS | 2.7.x: multi-socket, DCO; 2.6 is the LTS branch |

## Security recheck (2026-10-02)

nginx's [publisher advisories](https://nginx.org/en/security_advisories.html)
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
