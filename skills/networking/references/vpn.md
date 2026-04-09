# VPN and Overlay Network Configuration

## WireGuard

WireGuard is the default choice for new VPN deployments. Minimal attack surface (~4000 lines of
kernel code), high performance (in-kernel), and simple configuration.

### Point-to-Point

```ini
# Server: /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <server_private_key>
Address = 10.100.0.1/24
ListenPort = 51820
# Optional: firewall rules on up/down
PostUp = nft add rule inet filter input udp dport 51820 accept
PostDown = nft delete rule inet filter input udp dport 51820 accept

[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.100.0.2/32
# PresharedKey = <optional_psk>    # Adds post-quantum resistance layer
```

```ini
# Client: /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <client_private_key>
Address = 10.100.0.2/24
DNS = 10.100.0.1    # Use server as DNS (optional)

[Peer]
PublicKey = <server_public_key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0    # Route all traffic through VPN
PersistentKeepalive = 25         # Needed behind NAT
```

### Key Generation

```bash
# Generate keypair
wg genkey | tee privatekey | wg pubkey > publickey

# Generate preshared key (optional, for post-quantum resistance)
wg genpsk > presharedkey

# All-in-one
priv=$(wg genkey); pub=$(echo "$priv" | wg pubkey); echo "Private: $priv"; echo "Public: $pub"
```

### Hub-and-Spoke (site-to-site)

The hub (central server) routes traffic between spokes. Each spoke only connects to the hub.

```ini
# Hub: routes between spoke subnets
[Interface]
PrivateKey = <hub_key>
Address = 10.100.0.1/24
ListenPort = 51820
# Enable forwarding
PostUp = sysctl -w net.ipv4.ip_forward=1

[Peer]  # Spoke A (office)
PublicKey = <spoke_a_key>
AllowedIPs = 10.100.0.2/32, 192.168.1.0/24    # VPN IP + office LAN

[Peer]  # Spoke B (datacenter)
PublicKey = <spoke_b_key>
AllowedIPs = 10.100.0.3/32, 10.10.0.0/16      # VPN IP + DC subnet
```

**AllowedIPs is both an ACL and a routing table.** It controls:
1. Which source IPs are accepted from this peer (inbound filter)
2. Which destination IPs are routed to this peer (outbound routing)

### MTU Tuning

WireGuard default MTU is 1420 (accounts for WG overhead on a 1500 MTU link).

```ini
[Interface]
MTU = 1420    # Standard for Ethernet underlay
# MTU = 1280  # Minimum for IPv6, use if path MTU is constrained
# MTU = 1380  # If underlay is PPPoE (1492 MTU) or has other overhead
```

**Rule of thumb**: WireGuard overhead is 60 bytes (IPv4) or 80 bytes (IPv6). Subtract from
the underlay MTU. When in doubt, test with `ping -M do -s 1392 10.100.0.1` (adjust size until
no fragmentation).

### Troubleshooting

```bash
# Show interface status and peer info
wg show
wg show wg0

# Check for handshake (should be recent - within 2 minutes if active)
wg show wg0 latest-handshakes

# Quick connectivity test
wg show wg0 transfer    # Should show non-zero rx/tx if tunnel is active
```

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| No handshake | Firewall blocking UDP port, wrong endpoint, key mismatch | Check UDP port is open, verify keys match |
| Handshake but no traffic | AllowedIPs misconfigured, routing issue | Check `ip route`, verify AllowedIPs covers the target subnet |
| Intermittent drops behind NAT | Missing PersistentKeepalive | Add `PersistentKeepalive = 25` on the peer behind NAT |
| Slow throughput | MTU mismatch, fragmentation | Test with different MTU values, check for PMTUD issues |
| DNS leaks | DNS not configured in tunnel | Set `DNS =` in client config, or configure systemd-resolved |

---

## OpenVPN

OpenVPN 2.7.0 (Feb 2026) added multi-socket server support and `ovpn` DCO (Data Channel Offload)
kernel module for near-WireGuard performance on Linux. 2.6.x is still maintained (2.6.19).
Still relevant for tap mode (L2 bridging), x509 PKI with CRL/OCSP, and networks that block UDP.

### Server config (minimal, UDP, tun mode)

```ini
# /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/server.crt
key /etc/openvpn/pki/server.key
dh /etc/openvpn/pki/dh.pem
tls-crypt /etc/openvpn/pki/tc.key    # Replaces tls-auth, encrypts control channel
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
persist-key
persist-tun
verb 3
```

### PKI with easy-rsa

```bash
# Initialize PKI
cd /etc/openvpn
make-cadir pki && cd pki
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
./easyrsa build-client-full client1 nopass
openvpn --genkey secret tc.key    # tls-crypt key
```

### Hardening

```ini
# Restrict to modern ciphers only
data-ciphers AES-256-GCM:CHACHA20-POLY1305
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
# Use tls-crypt (not tls-auth) - encrypts + authenticates control channel
tls-crypt /etc/openvpn/pki/tc.key
# Drop privileges after init
user nobody
group nogroup
```

### When to use OpenVPN over WireGuard

- Need L2 bridging (tap mode) for broadcast/multicast protocols
- Require x509 PKI with CRL, OCSP, or certificate-based authentication
- Network blocks UDP entirely (OpenVPN can run over TCP)
- Legacy clients that can't run WireGuard

---

## IPsec / strongSwan

IPsec is the standards-based VPN protocol. Use when interoperating with enterprise equipment,
cloud VPN gateways (AWS VPN, Azure VPN Gateway), or when standards compliance is required.

### Modern config (swanctl - strongSwan 6.x)

```yaml
# /etc/swanctl/swanctl.conf
connections {
  site-to-site {
    version = 2    # IKEv2
    local_addrs = 203.0.113.1
    remote_addrs = 198.51.100.1

    local {
      auth = pubkey
      certs = server.crt
    }
    remote {
      auth = pubkey
      id = "CN=remote.example.com"
    }

    children {
      net {
        local_ts = 10.1.0.0/16
        remote_ts = 10.2.0.0/16
        esp_proposals = aes256gcm128-sha256-modp2048
        start_action = start
        close_action = start
        dpd_action = restart
      }
    }
    proposals = aes256-sha256-modp2048
  }
}
```

### Roadwarrior (remote access) with EAP

```yaml
connections {
  roadwarrior {
    version = 2
    pools = pool-ipv4

    local {
      auth = pubkey
      certs = vpn.crt
      id = vpn.example.com
    }
    remote {
      auth = eap-mschapv2
      eap_id = %any
    }
    children {
      net {
        local_ts = 0.0.0.0/0
        esp_proposals = aes256gcm128-sha256-modp2048
      }
    }
  }
}

pools {
  pool-ipv4 {
    addrs = 10.3.0.0/24
    dns = 1.1.1.1, 9.9.9.9
  }
}

secrets {
  eap-user1 {
    id = user1
    secret = "strong-password-here"
  }
}
```

### When to use IPsec over WireGuard

- Interoperating with cloud VPN gateways (AWS, Azure, GCP all speak IKEv2)
- Enterprise equipment (Cisco, Juniper, Palo Alto)
- Standards compliance requirements (FIPS, government)
- Need for traffic selectors (specific subnet-to-subnet encryption)

---

## Overlay Networks

### Tailscale / Headscale

Tailscale wraps WireGuard in a control plane that handles key exchange, NAT traversal (DERP
relays), and ACLs. Headscale is the self-hosted open-source control server.

**Tailscale** (managed):
```bash
# Install and join
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --accept-routes --accept-dns

# Advertise a subnet (make this node a subnet router)
tailscale up --advertise-routes=10.0.1.0/24

# Use as exit node
tailscale up --advertise-exit-node     # on the exit node
tailscale up --exit-node=<hostname>    # on the client
```

**Headscale** (self-hosted, v0.28.0):
```bash
# Create user and pre-auth key
headscale users create myuser
headscale preauthkeys create --user myuser --reusable --expiration 24h

# Client joins Headscale instead of Tailscale cloud
tailscale up --login-server https://headscale.example.com --authkey <key>
```

**Key features:**
- MagicDNS: automatic DNS for all nodes (`hostname.tailnet-name.ts.net`)
- ACLs: JSON/YAML policy controlling node-to-node access
- Subnet routers: expose non-Tailscale subnets through a Tailscale node
- Exit nodes: route all internet traffic through a specific node
- Funnel: expose local services to the public internet (Tailscale only)

### Nebula

Nebula (by Defined Networking, originally Slack) is a certificate-based overlay for large meshes.
No central relay - nodes connect directly with NAT hole-punching.

```yaml
# /etc/nebula/config.yml
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/host.crt
  key: /etc/nebula/host.key

static_host_map:
  "10.42.0.1": ["lighthouse.example.com:4242"]

lighthouse:
  am_lighthouse: false
  hosts:
    - "10.42.0.1"

listen:
  host: 0.0.0.0
  port: 4242

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: 22
      proto: tcp
      groups:
        - admin
    - port: 443
      proto: tcp
      cidr: any
```

**Certificate management:**
```bash
# Create CA
nebula-cert ca -name "My Org"

# Issue node cert with group membership
nebula-cert sign -name "web1" -ip "10.42.0.10/24" -groups "web,prod"

# Issue lighthouse cert
nebula-cert sign -name "lighthouse" -ip "10.42.0.1/24" -groups "lighthouse"
```

### ZeroTier

ZeroTier is another overlay network. Simpler setup than Nebula but requires a controller
(self-hosted or managed).

```bash
# Join a network
zerotier-cli join <network-id>

# Self-hosted controller: ztncui or ZeroTierOne controller API
# Planet/moon: custom root servers for private deployments
```

### Overlay Comparison

| Feature | Tailscale | Headscale | Nebula | ZeroTier |
|---------|-----------|-----------|--------|----------|
| Protocol | WireGuard | WireGuard | Custom (Noise) | Custom |
| Auth | SSO/OAuth | OIDC | Certificates | API keys |
| NAT traversal | DERP relays | DERP relays | Lighthouse + hole-punch | Root servers |
| Self-hosted | No (Headscale) | Yes | Yes | Yes (controller) |
| Max nodes | Unlimited (paid) | No limit | No practical limit | 50 free, unlimited paid |
| ACLs | JSON policy | JSON policy | Certificate groups | Flow rules |
| DNS | MagicDNS | MagicDNS | Manual | Manual |
| Best for | Teams, remote access | Privacy, homelab | Large mesh, Slack-scale | Quick setup, IoT |

---

## Cloudflare Tunnels

Cloudflare Tunnel (`cloudflared`, v2026.3.0) creates outbound-only encrypted connections from
your origin to Cloudflare's edge. No inbound ports needed - the tunnel connects out to
Cloudflare, which proxies traffic back through it.

### Architecture

```
Internet -> Cloudflare Edge (CDN, WAF, DDoS, Access) -> cloudflared -> Origin server
                                                         (outbound only)
```

- `cloudflared` runs on your server and establishes 4 QUIC connections to 2 Cloudflare datacenters
- Traffic flows through Cloudflare's network - they terminate TLS, apply WAF rules, and enforce
  Zero Trust policies before forwarding to your origin
- The origin never needs a public IP or open firewall ports

### Setup

```bash
# Install cloudflared
# Debian/Ubuntu: apt install cloudflared
# Arch: paru -S cloudflared
# Docker: cloudflare/cloudflared:latest

# Authenticate (opens browser)
cloudflared tunnel login

# Create a named tunnel
cloudflared tunnel create my-tunnel

# Configure ingress rules
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: <TUNNEL_UUID>
credentials-file: /root/.cloudflared/<TUNNEL_UUID>.json

ingress:
  - hostname: app.example.com
    service: http://localhost:3000
  - hostname: git.example.com
    service: http://localhost:3001
  - hostname: ssh.example.com
    service: ssh://localhost:22
  - service: http_status:404    # catch-all (required)
EOF

# Route DNS (creates CNAME to tunnel)
cloudflared tunnel route dns my-tunnel app.example.com

# Run
cloudflared tunnel run my-tunnel
```

### Dashboard-managed tunnels (simpler)

Create the tunnel in the Cloudflare Zero Trust dashboard instead of CLI. The dashboard generates
a single `cloudflared service install <token>` command - run it on the origin and you're done.
Ingress rules are managed in the dashboard UI.

### Cloudflare Access (Zero Trust)

Pair tunnels with Cloudflare Access to gate services behind SSO/MFA:

- Create an Access Application for each hostname
- Attach an Access Policy (e.g., "allow users from @company.com via Google SSO")
- Users hit a Cloudflare login page before reaching the origin
- Works for HTTP, SSH (browser-rendered terminal), RDP, and arbitrary TCP

### When to use Cloudflare Tunnels

- Exposing homelab services to the internet without port forwarding or dynamic DNS
- Adding WAF/DDoS protection without managing certificates or reverse proxies
- Zero Trust access to internal services (SSH, RDP, internal web apps)
- When you don't have a static IP or your ISP blocks inbound ports

### When NOT to use

- Latency-sensitive applications (adds a hop through Cloudflare's edge)
- High-bandwidth internal traffic (all traffic routes through Cloudflare)
- When you need full control over TLS termination (Cloudflare terminates TLS)
- Privacy-sensitive workloads where routing through a third party is unacceptable
- UDP services (limited support - QUIC and WARP only, no arbitrary UDP)
- When the service doesn't use HTTP/S, SSH, RDP, or SMB (limited protocol support)

### cloudflared vs traditional VPN

| Feature | Cloudflare Tunnel | WireGuard/IPsec |
|---------|-------------------|-----------------|
| Inbound ports | None | UDP port required |
| TLS certs | Automatic (Cloudflare) | Manual or ACME |
| DDoS protection | Built-in | None (need separate) |
| Access control | Cloudflare Access (SSO/MFA) | Key-based or PKI |
| Protocol support | HTTP, SSH, RDP, SMB, TCP | Any IP protocol |
| Latency | Extra hop through CF edge | Direct tunnel |
| Data path | Through Cloudflare | Peer-to-peer |
| Self-hosted | No (requires Cloudflare account) | Fully self-hosted |
| Cost | Free tier available | Free |

### Breaking change (Feb 2026)

`cloudflared proxy-dns` was removed from all new releases due to a vulnerability in an
underlying DNS library. If you used cloudflared as a DoH proxy, switch to a dedicated DNS
resolver (Unbound, dnscrypt-proxy).

---

## VPN Security Considerations

### Common mistakes

1. **Split tunneling without DNS protection**: if only some traffic goes through the VPN but DNS
   queries go to the local resolver, DNS leaks reveal browsing activity
2. **No kill switch**: if the VPN drops, traffic flows unencrypted. Use nftables rules to block
   non-VPN traffic when the tunnel is down
3. **Reusing keys across devices**: each device should have its own keypair
4. **Not rotating keys**: WireGuard has no built-in key rotation. Automate it or schedule manual
   rotation quarterly
5. **Overlapping subnets**: if two sites use 192.168.1.0/24, routing breaks when connected via VPN.
   Plan subnets before deploying VPN

### Kill switch (nftables)

```
table inet vpn_killswitch {
  chain output {
    type filter hook output priority 0; policy drop;
    oifname "wg0" accept                    # Allow traffic through VPN
    oifname "lo" accept                      # Allow loopback
    ip daddr <vpn_server_ip> udp dport 51820 accept  # Allow WG handshake
    ct state established,related accept      # Allow established connections
  }
}
```

### DNS leak prevention

```ini
# WireGuard client config
[Interface]
DNS = 10.100.0.1    # DNS server inside the VPN

# Plus: disable systemd-resolved stub or configure it to use VPN DNS
# resolvectl dns wg0 10.100.0.1
# resolvectl domain wg0 ~.    # Route all DNS through this interface
```
