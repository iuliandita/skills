# Network Troubleshooting and Performance Tuning

## Troubleshooting Methodology

Work bottom-up through the network stack:

1. **Physical/Link** -- is the interface up? (`ip link show`, check for `NO-CARRIER`)
2. **IP** -- correct address? (`ip addr`), correct route? (`ip route`)
3. **Connectivity** -- can you reach the gateway? (`ping gateway`), the target? (`ping target`)
4. **DNS** -- does name resolution work? (`dig domain`)
5. **Transport** -- is the port open? (`ss -tlnp`, `nmap -p PORT target`)
6. **Application** -- does the service respond? (`curl`, `openssl s_client`)

At each layer, determine: is the problem **here** or **further up the stack**?

---

## Tool Deep-Dives

### tcpdump

The single most useful network debugging tool. Captures packets for analysis.

```bash
# Capture all traffic on interface
tcpdump -i enp0s3 -nn

# DNS traffic only
tcpdump -i any -nn port 53

# Traffic to/from specific host
tcpdump -i any -nn host 10.0.1.50

# HTTP traffic with content
tcpdump -i any -nn -A port 80

# Write to file for Wireshark analysis
tcpdump -i any -nn -w /tmp/capture.pcap

# Read from file
tcpdump -nn -r /tmp/capture.pcap

# TCP SYN packets only (connection attempts)
tcpdump -i any -nn 'tcp[tcpflags] & tcp-syn != 0'

# VLAN-tagged traffic (show 802.1Q headers)
tcpdump -i enp0s3 -nn -e vlan

# Capture with rotation (10 files, 100MB each)
tcpdump -i any -nn -w /tmp/capture.pcap -C 100 -W 10
```

**Key flags:**
- `-nn`: don't resolve hostnames or port names (faster, clearer output)
- `-e`: show link-layer headers (MAC addresses, VLAN tags)
- `-A`: show packet content as ASCII
- `-X`: show packet content as hex + ASCII
- `-w`: write raw packets to file
- `-r`: read from file
- `-c N`: capture N packets then stop

### mtr (My Traceroute)

Combined traceroute + ping. Shows per-hop latency and packet loss.

```bash
# Basic report (non-interactive)
mtr -n --report target.com

# With AS numbers (useful for identifying networks)
mtr -n --report --aslookup target.com

# TCP mode (when ICMP is blocked)
mtr -n --report --tcp --port 443 target.com

# UDP mode
mtr -n --report --udp target.com

# JSON output
mtr -n --report --json target.com
```

**Reading mtr output:**
- `Loss%` > 0 at the final hop = real packet loss
- `Loss%` > 0 at intermediate hops but 0% at final = ICMP rate limiting (not a problem)
- Sudden latency jump at a specific hop = congestion or distance at that hop
- Consistent high latency across all hops = your connection is slow

### ss (Socket Statistics)

Replaced `netstat`. Shows active connections and listening sockets.

```bash
# All TCP listeners with process info
ss -tlnp

# All UDP listeners
ss -ulnp

# All established connections
ss -tnp

# Filter by port
ss -tlnp 'sport = :443'

# Filter by state
ss -tn state established

# Show timer info (useful for debugging connection hangs)
ss -tnp -o

# Show memory usage per socket
ss -tnp -m

# Connection count by state
ss -s
```

### iperf3 (Bandwidth Testing)

```bash
# Server side
iperf3 -s

# Client side -- basic TCP test
iperf3 -c server-ip

# UDP test with target bandwidth
iperf3 -c server-ip -u -b 100M

# Reverse mode (server sends to client)
iperf3 -c server-ip -R

# Multiple parallel streams
iperf3 -c server-ip -P 4

# Test for 60 seconds
iperf3 -c server-ip -t 60

# JSON output
iperf3 -c server-ip --json
```

### curl (Network Debugging)

```bash
# Verbose TLS handshake info
curl -vk https://target.com 2>&1 | grep -E '^\*|^<|^>'

# Show timing breakdown
curl -o /dev/null -s -w "\
  DNS:        %{time_namelookup}s\n\
  Connect:    %{time_connect}s\n\
  TLS:        %{time_appconnect}s\n\
  TTFB:       %{time_starttransfer}s\n\
  Total:      %{time_total}s\n\
  Size:       %{size_download} bytes\n" https://target.com

# Test specific TLS version
curl --tlsv1.2 --tls-max 1.2 https://target.com

# Resolve to specific IP (bypass DNS)
curl --resolve target.com:443:10.0.1.50 https://target.com

# Test HTTP/2
curl --http2 -I https://target.com

# Follow redirects and show each hop
curl -vLk https://target.com 2>&1 | grep -E 'Location:|HTTP/'
```

### nmap (Port Scanning)

For troubleshooting, not pentesting. Verify which ports are open and what services are running.

```bash
# Quick scan common ports
nmap -F target

# Service version detection
nmap -sV -p 22,80,443 target

# Scan specific port range
nmap -p 1-1024 target

# UDP scan (slower, requires root)
nmap -sU -p 53,123,161 target

# Check if host is up without port scan
nmap -sn target

# Scan from inside a network namespace
ip netns exec vpn-ns nmap -sV -p 80,443 target
```

---

## Common Issues

### Can't reach a host

```bash
# 1. Check local interface
ip addr show
ip link show    # Look for UP vs DOWN, NO-CARRIER

# 2. Check routing
ip route get 10.0.1.50    # Shows which route would be used

# 3. Check gateway reachability
ping -c 3 $(ip route | grep default | awk '{print $3}')

# 4. Check ARP (is the target's MAC known?)
ip neigh show

# 5. Check for firewall drops
nft list ruleset | grep -i drop
# Or watch for drops in real-time:
nft monitor trace

# 6. Check from the other side (if accessible)
tcpdump -i any -nn host YOUR_IP    # Do the packets arrive?
```

### DNS not resolving

See `references/dns.md` for detailed DNS troubleshooting. Quick checks:

```bash
# Which nameserver is being used?
cat /etc/resolv.conf
resolvectl status    # If systemd-resolved is active

# Can you reach the nameserver?
ping $(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')

# Does direct query work?
dig @8.8.8.8 example.com +short    # Bypass local resolver
```

### TLS/SSL issues

```bash
# Check certificate chain
openssl s_client -connect target:443 -servername target.com </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer

# Check specific TLS version
openssl s_client -connect target:443 -tls1_2

# Test cipher support
openssl s_client -connect target:443 -cipher ECDHE-RSA-AES256-GCM-SHA384

# Full TLS audit (if testssl.sh is installed)
testssl.sh target.com:443
```

### Slow network / high latency

```bash
# 1. Check for packet loss
mtr -n --report target

# 2. Check bandwidth
iperf3 -c target

# 3. Check for bufferbloat (see Performance Tuning below)
# Run iperf3 in one terminal, ping in another -- if latency spikes during
# iperf3, you have bufferbloat

# 4. Check interface errors/drops
ip -s link show enp0s3    # Look for errors, dropped, overruns

# 5. Check for TCP retransmissions
ss -ti | grep retrans

# 6. Check MTU / fragmentation
ping -M do -s 1472 target    # Should work for 1500 MTU
# Reduce size until it works -- that's your path MTU
```

---

## Performance Tuning

### TCP tuning

```bash
# /etc/sysctl.d/99-network-tuning.conf

# Increase buffer sizes (for high-bandwidth links)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable BBR congestion control (better than cubic for lossy/high-latency links)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Enable TCP Fast Open (reduces latency for repeat connections)
net.ipv4.tcp_fastopen = 3

# Connection tracking (for busy routers/firewalls)
net.netfilter.nf_conntrack_max = 262144

# Increase backlog for busy servers
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 4096
```

Apply: `sysctl --system`

### Bufferbloat

Bufferbloat causes high latency under load because oversized network buffers hold packets too
long. Test: run `iperf3` and `ping` simultaneously -- if ping latency spikes 10x+ during the
iperf3 run, you have bufferbloat.

**Fix: use `fq_codel` or `cake` qdisc**

```bash
# Check current qdisc
tc qdisc show dev enp0s3

# Set CAKE (best for shaped links like DSL/cable)
tc qdisc replace dev enp0s3 root cake bandwidth 100mbit

# Set fq_codel (good for datacenter/LAN)
tc qdisc replace dev enp0s3 root fq_codel
```

### MTU optimization

```bash
# Find path MTU
ping -M do -s 1472 target.com    # 1472 + 28 (IP+ICMP headers) = 1500
# If it fails, reduce until it works

# Common MTU values
# 1500  -- Ethernet standard
# 9000  -- Jumbo frames (datacenter, must be configured end-to-end)
# 1420  -- WireGuard tunnel
# 1400  -- OpenVPN tunnel (approximate)
# 1450  -- VXLAN
# 1492  -- PPPoE (DSL)

# Set MTU
ip link set enp0s3 mtu 9000

# Verify path MTU discovery is working
sysctl net.ipv4.ip_no_pmtu_disc    # Should be 0
```

### Connection tracking tuning (firewalls/routers)

```bash
# Check current connection count vs max
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max

# If count is near max, increase
sysctl -w net.netfilter.nf_conntrack_max=524288

# Reduce timeout for established connections (default 5 days is too long)
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600
```

---

## TLS Certificate Management

### Critical: OpenSSL CVE-2025-15467 (CVSS 9.8)

Stack buffer overflow RCE via malformed encrypted message. Affects all OpenSSL versions since 3.0.
Patched in OpenSSL 3.6.1 / 3.5.5 / 3.4.4 / 3.3.6 / 3.0.19 (Jan 2026). **Upgrade immediately.**
12 additional vulnerabilities were fixed in the same batch.

Check your version: `openssl version` -- anything below the patched versions is vulnerable.

### Let's Encrypt with certbot

**45-day certificate rollout timeline:**
- Now: 90-day certs (default), 6-day short-lived certs available
- May 2026: opt-in to 45-day certs
- Feb 2027: default changes to 64-day certs
- Feb 2028: default changes to 45-day certs

Certbot 5.4.0 supports IP address certificates (`--ip-address`) and ARI (ACME Renewal
Information) for smarter renewal timing.

```bash
# Standalone (if no web server is running on 80)
certbot certonly --standalone -d example.com

# Webroot (if web server is running)
certbot certonly --webroot -w /var/www/html -d example.com

# DNS challenge (for wildcard certs)
certbot certonly --manual --preferred-challenges dns -d '*.example.com'

# IP address certificate (new in certbot 5.4.0)
certbot certonly --standalone --ip-address 203.0.113.50

# Auto-renewal
certbot renew --dry-run
# Cron/timer for renewal is installed automatically

# Check certificate expiry
openssl x509 -noout -dates -in /etc/letsencrypt/live/example.com/cert.pem
```

### Self-signed certificates (internal services)

```bash
# Quick self-signed cert (1 year)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=internal.example.com" \
  -addext "subjectAltName=DNS:internal.example.com,IP:10.0.1.50"
```

### mTLS (mutual TLS)

**Breaking change (2025-2027):** Major public CAs (Sectigo from Sep 2025) are removing the
Client Authentication EKU from SSL/TLS certificates. By Feb 2027, public CA certs won't work
for mTLS at all. **You must use a private CA** for mTLS client certificates -- step-ca, cfssl,
Vault PKI, or plain OpenSSL. This affects VPNs, mTLS, Wi-Fi onboarding, and any system using
public CA certs for client auth.

```bash
# Create private CA
openssl req -x509 -newkey rsa:4096 -keyout ca-key.pem -out ca-cert.pem -days 3650 -nodes \
  -subj "/CN=Internal CA"

# Create client cert signed by CA
openssl req -newkey rsa:2048 -keyout client-key.pem -out client-csr.pem -nodes \
  -subj "/CN=client1"
openssl x509 -req -in client-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out client-cert.pem -days 365

# Test mTLS connection
curl --cert client-cert.pem --key client-key.pem --cacert ca-cert.pem https://server:443
```
