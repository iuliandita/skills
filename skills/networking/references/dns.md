# DNS Configuration and Troubleshooting

## DNS Server Comparison

| Server | Role | Best for | Config style |
|--------|------|----------|-------------|
| **Unbound** | Recursive resolver | Privacy, DNSSEC validation, Pi-hole upstream | `unbound.conf` (hierarchical) |
| **CoreDNS** | Authoritative + recursive | Kubernetes, plugin-based flexibility | `Corefile` (plugin chain) |
| **BIND9** | Authoritative + recursive | Full-featured, zone transfers, DNSSEC signing | `named.conf` + zone files |
| **dnsmasq** | Lightweight forwarder + DHCP | Homelabs, embedded, simple setups | `dnsmasq.conf` (flat) |
| **Pi-hole** | DNS sinkhole (filtering) | Ad/tracker blocking for LAN | Web UI + lists |
| **AdGuard Home** | DNS sinkhole (filtering) | Like Pi-hole but with DoH/DoT built-in | Web UI + YAML |
| **PowerDNS** | Authoritative | Database-backed zones, API-driven | `pdns.conf` + SQL backend |
| **Knot DNS** | Authoritative | High performance, DNSSEC automation | `knot.conf` (YAML-like) |

**Recommendation**: Unbound for recursive resolution (especially with Pi-hole/AdGuard), CoreDNS
for Kubernetes environments, BIND9 when you need authoritative zones with DNSSEC signing.

---

## Unbound Configuration

Minimal recursive resolver with DNSSEC:

```yaml
server:
  interface: 0.0.0.0
  port: 53
  access-control: 10.0.0.0/8 allow
  access-control: 172.16.0.0/12 allow
  access-control: 192.168.0.0/16 allow
  access-control: 127.0.0.0/8 allow

  # Performance
  num-threads: 2
  msg-cache-size: 64m
  rrset-cache-size: 128m
  prefetch: yes
  prefetch-key: yes

  # Privacy
  hide-identity: yes
  hide-version: yes
  qname-minimisation: yes

  # DNSSEC
  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  val-clean-additional: yes

  # Hardening
  harden-glue: yes
  harden-dnssec-stripped: yes
  harden-referral-path: yes
  use-caps-for-id: yes     # 0x20 encoding for cache poisoning resistance
```

### Unbound as Pi-hole upstream

Pi-hole handles DNS filtering; Unbound does recursive resolution behind it:

```
Client -> Pi-hole (:53) -> Unbound (:5335) -> Root servers
```

Configure Unbound on port 5335, set Pi-hole's upstream DNS to `127.0.0.1#5335`.

### Unbound with DoT forwarding

Forward to a DoT upstream instead of doing recursive resolution:

```yaml
server:
  tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 1.1.1.1@853#cloudflare-dns.com
  forward-addr: 1.0.0.1@853#cloudflare-dns.com
```

---

## Split-Horizon DNS

Different answers for the same domain depending on the query source. Common in homelabs where
internal services use the same domain as external (e.g., `app.example.com` resolves to a private
IP internally, public IP externally).

### Pattern 1: Unbound local-zone overrides

```yaml
server:
  # Override specific records for internal clients
  local-zone: "example.com." transparent
  local-data: "app.example.com. IN A 10.0.1.50"
  local-data: "git.example.com. IN A 10.0.1.51"
  # Everything else resolves normally via recursion
```

### Pattern 2: CoreDNS with view-like behavior

CoreDNS doesn't have native views, but you can use the `acl` plugin or run separate CoreDNS
instances on different ports/interfaces:

```
internal:53 {
  hosts {
    10.0.1.50 app.example.com
    10.0.1.51 git.example.com
    fallthrough
  }
  forward . 1.1.1.1
}
```

### Pattern 3: dnsmasq overrides

```
# /etc/dnsmasq.d/local-overrides.conf
address=/app.example.com/10.0.1.50
address=/git.example.com/10.0.1.51
```

### Hairpin NAT alternative

If split-horizon DNS is too complex, configure hairpin NAT on the router so internal clients
hitting the public IP get routed correctly. OPNsense and pfSense both support NAT reflection.

---

## DNSSEC

### Validation (client-side)

Unbound validates DNSSEC by default when `auto-trust-anchor-file` is configured. Test with:

```bash
dig @localhost example.com +dnssec    # Look for 'ad' flag (Authenticated Data)
dig @localhost dnssec-failed.org A    # Should return SERVFAIL (validation failure)
```

### Signing (authoritative)

If you run authoritative DNS and need DNSSEC:

1. **BIND9**: `dnssec-policy "default";` in the zone config (inline signing, automatic key rollout)
2. **Knot DNS**: `dnssec-signing on;` with automatic KASP (Key And Signing Policy)
3. **PowerDNS**: `pdnsutil secure-zone` + `pdnsutil rectify-zone`

Key rollout is the hard part. BIND9's `dnssec-policy` handles KSK/ZSK rotation automatically.
For DS record updates at the registrar, use CDS/CDNSKEY records (RFC 7344) if the registrar
supports them.

---

## DNS-over-HTTPS (DoH) and DNS-over-TLS (DoT)

| Protocol | Port | Encryption | Proxy-friendly | Status |
|----------|------|-----------|----------------|--------|
| DoT | 853 | TLS | No (blocked by some ISPs) | Mature, widely supported |
| DoH | 443 | HTTPS | Yes (looks like web traffic) | Mature, browser-native |
| DoQ | 853/UDP | QUIC | No | Emerging, limited support |

### Hosting your own DoH/DoT endpoint

**Option 1**: Caddy + CoreDNS (DoH)

```
dns.example.com {
  reverse_proxy localhost:8053
}
```

With CoreDNS listening on `8053` with the `doh` plugin.

**Option 2**: Unbound native DoT

```yaml
server:
  interface: 0.0.0.0@853
  tls-service-key: /etc/letsencrypt/live/dns.example.com/privkey.pem
  tls-service-pem: /etc/letsencrypt/live/dns.example.com/fullchain.pem
  tls-port: 853
```

**Option 3**: AdGuard Home (DoH + DoT out of the box)

AdGuard Home supports DoH, DoT, and DNSCrypt with automatic certificate management.

---

## DNS Troubleshooting

### Diagnostic commands

```bash
# Basic query
dig example.com A +short

# Query a specific server
dig @8.8.8.8 example.com A

# Trace delegation (shows full resolution path)
dig example.com +trace

# Check DNSSEC
dig example.com +dnssec +multi

# Reverse DNS
dig -x 93.184.216.34

# Check SOA (useful for zone transfer debugging)
dig example.com SOA +short

# Check all record types
dig example.com ANY +noall +answer

# systemd-resolved status
resolvectl status
resolvectl query example.com
```

### Common issues

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| SERVFAIL | DNSSEC validation failure, upstream timeout | Check `dig +dnssec`, test without DNSSEC validation |
| NXDOMAIN | Domain doesn't exist or typo | Check spelling, verify domain is registered |
| Slow resolution | DNS forwarder overloaded, high latency upstream | Switch upstream, enable prefetching |
| Resolution works for some clients | Split DNS misconfigured, DHCP pushing wrong DNS | Check each client's `/etc/resolv.conf` |
| `systemd-resolved` ignoring your config | NetworkManager overriding `/etc/resolv.conf` | Use `resolvectl` or drop-in configs |
| Truncated responses | UDP response >512 bytes, EDNS not supported | Check for `tc` flag, verify firewall allows EDNS |
| DNS leaks through VPN | `resolv.conf` not updated, IPv6 DNS not tunneled | Set DNS inside VPN config, disable IPv6 if not tunneled |

### systemd-resolved gotchas

systemd-resolved manages `/etc/resolv.conf` as a stub resolver (`127.0.0.53`). If you're
running your own DNS server:

1. **Disable the stub listener**: `DNSStubListener=no` in `/etc/systemd/resolved.conf`
2. **Point resolv.conf at your server**: `ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf`
   (or manage it manually)
3. **Or symlink to your own**: remove the symlink and write a static `/etc/resolv.conf`

Check what's active: `resolvectl status` shows per-interface DNS configuration.

---

## DNS in Kubernetes

CoreDNS is the default DNS server in Kubernetes. Key gotchas:

### ndots problem

Default `ndots:5` means any query with <5 dots gets search domains appended first. A query for
`api.example.com` generates 5+ DNS queries before the real one. Fix:

```yaml
spec:
  dnsConfig:
    options:
      - name: ndots
        value: "2"
```

### DNS policy

- `ClusterFirst` (default): pod DNS queries go to CoreDNS
- `None`: fully custom via `dnsConfig` - use when pods need external DNS only
- `Default`: use the node's DNS - rarely what you want in K8s

### CoreDNS Corefile customization

```
.:53 {
    errors
    health { lameduck 5s }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
    }
    forward . /etc/resolv.conf { max_concurrent 1000 }
    cache 30
    loop
    reload
    loadbalance
}
```

To add custom DNS entries, use the `hosts` plugin or a separate zone block.

---

## Common DNS Attacks (defensive awareness)

| Attack | Description | Mitigation |
|--------|------------|------------|
| Cache poisoning | Inject false records into resolver cache | DNSSEC validation, randomize source port + TXID, 0x20 encoding |
| DNS amplification | Abuse open resolvers for DDoS | Don't run open resolvers, rate limit, BCP38 |
| Subdomain takeover | Dangling CNAME to deprovisioned service | Audit CNAME records, remove when service is decommissioned |
| DNS tunneling | Exfiltrate data via DNS queries | Monitor for abnormal query patterns, long TXT records |
| NXDOMAIN flooding | Exhaust resolver resources with random subdomains | Rate limiting, aggressive NSEC caching |
