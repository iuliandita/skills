# Network Segmentation: VLANs, nftables, Namespaces, IPv6

## VLANs (802.1Q)

VLANs segment a physical network into isolated broadcast domains. On Linux, VLAN interfaces are
created as sub-interfaces of a physical interface.

### Creating VLAN interfaces

```bash
# Create VLAN 100 on interface enp0s3
ip link add link enp0s3 name enp0s3.100 type vlan id 100
ip addr add 10.0.100.1/24 dev enp0s3.100
ip link set enp0s3.100 up

# Verify
ip -d link show enp0s3.100    # Shows "vlan protocol 802.1Q id 100"
```

### Persistent VLANs (systemd-networkd)

```ini
# /etc/systemd/network/10-enp0s3.100.netdev
[NetDev]
Name=enp0s3.100
Kind=vlan

[VLAN]
Id=100

# /etc/systemd/network/11-enp0s3.100.network
[Match]
Name=enp0s3.100

[Network]
Address=10.0.100.1/24
```

### Persistent VLANs (Netplan -- Ubuntu/Debian)

```yaml
network:
  version: 2
  ethernets:
    enp0s3: {}
  vlans:
    vlan100:
      id: 100
      link: enp0s3
      addresses: [10.0.100.1/24]
```

### Inter-VLAN routing

To route between VLANs on a Linux router:

1. Enable IP forwarding: `sysctl -w net.ipv4.ip_forward=1` (persist in `/etc/sysctl.d/`)
2. Create VLAN interfaces on the router (as above)
3. Set the router's VLAN IP as the default gateway for hosts in each VLAN
4. Add nftables rules to control which VLANs can talk to each other

```
# Allow VLAN 100 -> VLAN 200, block reverse
table inet filter {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    iifname "enp0s3.100" oifname "enp0s3.200" accept
    # VLAN 200 -> 100 is implicitly dropped by policy
  }
}
```

### Trunk vs access ports

- **Trunk port**: carries multiple VLANs (tagged traffic). The physical interface on the Linux
  router/server is a trunk -- it receives 802.1Q-tagged frames.
- **Access port**: carries one VLAN (untagged). End-host ports on the switch.

The switch must be configured to trunk the VLANs to the Linux host's physical port.

---

## nftables Firewall

nftables replaced iptables as the default Linux firewall. Key differences:
- Single tool (`nft`) instead of `iptables`, `ip6tables`, `arptables`, `ebtables`
- Tables and chains are user-defined (no hardcoded table names)
- Sets, maps, and concatenations for efficient matching
- Atomic rule replacement

### Basic stateful firewall

```
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # Connection tracking
    ct state established,related accept
    ct state invalid drop

    # Loopback
    iif lo accept

    # ICMP (ping, neighbor discovery)
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    # SSH
    tcp dport 22 accept

    # HTTP/HTTPS
    tcp dport { 80, 443 } accept

    # DNS (if running a resolver)
    udp dport 53 accept
    tcp dport 53 accept

    # Log and drop everything else
    log prefix "nft-drop: " limit rate 5/minute
    drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    # Add forwarding rules for VLANs/VPN here
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
```

### nftables sets (efficient matching)

```
# Named set for allowed SSH sources
table inet filter {
  set trusted_ssh {
    type ipv4_addr
    elements = { 10.0.1.0/24, 192.168.1.100 }
  }

  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    tcp dport 22 ip saddr @trusted_ssh accept
  }
}

# Add/remove from set at runtime
nft add element inet filter trusted_ssh { 10.0.2.50 }
nft delete element inet filter trusted_ssh { 192.168.1.100 }
```

### NAT with nftables

```
table ip nat {
  chain prerouting {
    type nat hook prerouting priority dstnat;
    # Port forward: external :8080 -> internal 10.0.1.50:80
    tcp dport 8080 dnat to 10.0.1.50:80
  }

  chain postrouting {
    type nat hook postrouting priority srcnat;
    # Masquerade outbound traffic (for router/gateway)
    oifname "enp0s3" masquerade
  }
}
```

### Zone-based firewall pattern

Group interfaces into zones and control traffic between them:

```
table inet filter {
  set zone_lan { type ifname; elements = { "enp0s3.100", "enp0s3.200" } }
  set zone_wan { type ifname; elements = { "enp0s3" } }
  set zone_vpn { type ifname; elements = { "wg0" } }

  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept

    # LAN -> WAN (internet access)
    iifname @zone_lan oifname @zone_wan accept

    # VPN -> LAN (remote access)
    iifname @zone_vpn oifname @zone_lan accept

    # LAN -> VPN
    iifname @zone_lan oifname @zone_vpn accept

    # WAN -> LAN: drop (default policy)
  }
}
```

### Persisting rules

```bash
# Save current ruleset
nft list ruleset > /etc/nftables.conf

# Load on boot (systemd)
systemctl enable nftables    # Loads /etc/nftables.conf on boot

# Or manual load
nft -f /etc/nftables.conf
```

### nftables vs iptables

Do NOT mix nftables and iptables on the same system. They share the same kernel hooks and
can conflict. On modern distros, `iptables` is often a wrapper around nftables (iptables-nft).
Check with: `iptables --version` -- if it says `nf_tables`, it's the nft backend.

Migration: `iptables-save | iptables-restore-translate > /etc/nftables.conf`

---

## Network Namespaces

Network namespaces provide complete network stack isolation. Each namespace has its own
interfaces, routing table, firewall rules, and socket space.

### Basic usage

```bash
# Create namespace
ip netns add test-ns

# Run command in namespace
ip netns exec test-ns ip addr    # Shows only loopback

# Connect to host network via veth pair
ip link add veth-host type veth peer name veth-ns
ip link set veth-ns netns test-ns

# Configure host side
ip addr add 10.200.0.1/24 dev veth-host
ip link set veth-host up

# Configure namespace side
ip netns exec test-ns ip addr add 10.200.0.2/24 dev veth-ns
ip netns exec test-ns ip link set veth-ns up
ip netns exec test-ns ip link set lo up

# Test
ip netns exec test-ns ping 10.200.0.1

# Give namespace internet access (NAT through host)
ip netns exec test-ns ip route add default via 10.200.0.1
# Plus masquerade rule on host for veth-host traffic
```

### Practical uses

- **Testing**: create isolated network environments for testing firewall rules, DNS, etc.
- **Service isolation**: run services in separate network stacks (similar to containers)
- **VPN routing**: run specific apps through a VPN without affecting the whole system
- **Multi-homing**: different default routes for different applications

### VPN in a namespace (route specific apps through VPN)

```bash
# Create namespace
ip netns add vpn-ns

# Move WireGuard interface into namespace
ip link set wg0 netns vpn-ns

# Configure WireGuard inside namespace
ip netns exec vpn-ns wg setconf wg0 /etc/wireguard/wg0.conf
ip netns exec vpn-ns ip addr add 10.100.0.2/24 dev wg0
ip netns exec vpn-ns ip link set wg0 up
ip netns exec vpn-ns ip route add default dev wg0

# Run app through VPN
ip netns exec vpn-ns curl ifconfig.me    # Shows VPN IP
curl ifconfig.me                          # Shows real IP
```

---

## Subnetting

### Homelab subnet planning

A common pattern for homelabs with VLANs:

| VLAN | Subnet | Purpose |
|------|--------|---------|
| 1 | 192.168.1.0/24 | Management / default |
| 10 | 10.0.10.0/24 | Servers |
| 20 | 10.0.20.0/24 | IoT (isolated) |
| 30 | 10.0.30.0/24 | Guest WiFi (isolated) |
| 40 | 10.0.40.0/24 | Media / entertainment |
| 100 | 10.100.0.0/24 | WireGuard VPN |

**Rules of thumb:**
- Don't use 192.168.0.0/24 or 192.168.1.0/24 for VPN ranges -- they overlap with most home routers
- Use 10.x.x.x/24 ranges for VLANs to avoid conflicts with default home router subnets
- Keep VPN ranges in a distinct /16 (e.g., 10.100.x.x) to avoid overlap
- CGNAT range (100.64.0.0/10) is used by Tailscale -- don't overlap if using both

### IPv6

IPv6 uses /64 for all regular subnets. Smaller than /64 breaks SLAAC.

```
| Prefix | Purpose |
|--------|---------|
| /128 | Single host (loopback) |
| /64 | Standard subnet (LAN, VLAN) |
| /56 | Typical ISP delegation to residential |
| /48 | Typical ISP delegation to business, or ULA site |
| fd00::/8 | Unique Local Addresses (ULA) -- like RFC 1918 for IPv6 |
| fe80::/10 | Link-local (auto-configured, non-routable) |
```

**ULA for private use:**
```bash
# Generate a random ULA prefix (should be globally unique)
# Format: fdXX:XXXX:XXXX::/48
# Use a generator or: printf 'fd%02x:%04x:%04x::/48\n' $RANDOM $RANDOM $RANDOM
```

**Dual-stack considerations:**
- If deploying IPv6, also deploy it through VPNs or disable it on VPN interfaces
- Half-configured IPv6 leaks traffic around IPv4-only VPNs
- nftables `inet` family handles both IPv4 and IPv6 in one table

---

## Linux Bridge

Linux bridges connect multiple interfaces at L2 (like a virtual switch).

```bash
# Create bridge
ip link add br0 type bridge
ip link set br0 up

# Add interfaces to bridge
ip link set enp0s3 master br0
ip link set enp0s4 master br0

# Assign IP to bridge (the bridge acts as the gateway)
ip addr add 10.0.1.1/24 dev br0
```

### Bridge + VLAN filtering

Modern Linux bridges support VLAN-aware mode:

```bash
# Enable VLAN filtering
ip link add br0 type bridge vlan_filtering 1
ip link set br0 up

# Port enp0s3: trunk (tagged VLAN 10, 20)
ip link set enp0s3 master br0
bridge vlan add vid 10 dev enp0s3
bridge vlan add vid 20 dev enp0s3

# Port enp0s4: access (untagged VLAN 10)
ip link set enp0s4 master br0
bridge vlan add vid 10 dev enp0s4 pvid untagged

# Show VLAN table
bridge vlan show
```

---

## Dynamic Routing (FRRouting)

FRRouting (FRR) provides BGP, OSPF, IS-IS, PIM, and more on Linux.

### Basic OSPF

```
# /etc/frr/frr.conf
frr version 10.5
frr defaults traditional

router ospf
  ospf router-id 10.0.1.1
  network 10.0.1.0/24 area 0
  network 10.0.2.0/24 area 0
  passive-interface enp0s3    # Don't send OSPF hellos on this interface

interface enp0s4
  ip ospf cost 10
  ip ospf hello-interval 10
  ip ospf dead-interval 40
```

### Basic BGP

```
router bgp 65001
  bgp router-id 10.0.1.1
  neighbor 10.0.2.1 remote-as 65002

  address-family ipv4 unicast
    network 10.0.1.0/24
    neighbor 10.0.2.1 activate
  exit-address-family
```

### FRR management

```bash
# Interactive shell (Cisco-like CLI)
vtysh

# Show routing table
vtysh -c "show ip route"

# Show OSPF neighbors
vtysh -c "show ip ospf neighbor"

# Show BGP summary
vtysh -c "show ip bgp summary"

# Reload config
systemctl reload frr
```
