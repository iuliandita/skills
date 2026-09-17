# CIDR and DNS Lookup Tables

Compact mapping tables, kept out of the always-loaded SKILL.md. Load this file only when a
task needs the literal numbers or record shapes.

## CIDR Cheat Sheet

| CIDR | Netmask | Hosts | Common use |
|------|---------|-------|------------|
| /32 | 255.255.255.255 | 1 | Host route, loopback |
| /31 | 255.255.255.254 | 2 | Point-to-point link (RFC 3021) |
| /30 | 255.255.255.252 | 2 | Legacy point-to-point |
| /29 | 255.255.255.248 | 6 | Small service subnet |
| /28 | 255.255.255.240 | 14 | DMZ, management |
| /27 | 255.255.255.224 | 30 | Small office |
| /26 | 255.255.255.192 | 62 | Department |
| /25 | 255.255.255.128 | 126 | Floor / building wing |
| /24 | 255.255.255.0 | 254 | Standard LAN segment |
| /16 | 255.255.0.0 | 65534 | Large campus / datacenter |
| /8 | 255.0.0.0 | 16M+ | Class A (10.0.0.0/8) |

**Private ranges (RFC 1918):** `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
**CGNAT (RFC 6598):** `100.64.0.0/10` (used by Tailscale, carrier NAT)
**Link-local:** `169.254.0.0/16` (IPv4), `fe80::/10` (IPv6)
**ULA (IPv6):** `fd00::/8` (private, like RFC 1918 for IPv6)

## DNS Record Types

| Type | Purpose | Example |
|------|---------|---------|
| A | IPv4 address | `example.com. 300 IN A 93.184.216.34` |
| AAAA | IPv6 address | `example.com. 300 IN AAAA 2606:2800:220:1::` |
| CNAME | Alias to another name | `www.example.com. IN CNAME example.com.` |
| MX | Mail server | `example.com. IN MX 10 mail.example.com.` |
| TXT | Arbitrary text (SPF, DKIM, verification) | `example.com. IN TXT "v=spf1 ..."` |
| SRV | Service location | `_sip._tcp.example.com. IN SRV 10 5 5060 sip.example.com.` |
| NS | Nameserver delegation | `example.com. IN NS ns1.example.com.` |
| CAA | Certificate authority authorization | `example.com. IN CAA 0 issue "letsencrypt.org"` |
| SVCB/HTTPS | Service binding (newer) | `example.com. IN HTTPS 1 . alpn="h2,h3"` |
| PTR | Reverse DNS | `34.216.184.93.in-addr.arpa. IN PTR example.com.` |
