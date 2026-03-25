# High Availability: keepalived, VRRP, Floating IPs

## keepalived (VRRP)

keepalived implements VRRP (Virtual Router Redundancy Protocol) to provide automatic failover
of a virtual IP (VIP) between two or more Linux hosts. When the primary goes down, the backup
takes over the VIP within seconds.

### Basic VRRP (two nodes, one VIP)

**Primary node:**
```
# /etc/keepalived/keepalived.conf
global_defs {
  router_id node1
  vrrp_skip_check_adv_addr
  enable_script_security
}

vrrp_instance VI_1 {
  state MASTER
  interface enp0s3
  virtual_router_id 51
  priority 100           # Higher = preferred master
  advert_int 1           # VRRP advertisement interval (seconds)

  authentication {
    auth_type PASS
    auth_pass secret123  # Must match on all nodes (max 8 chars)
  }

  virtual_ipaddress {
    10.0.1.100/24         # The floating VIP
  }

  track_interface {
    enp0s3                # If this interface goes down, reduce priority
  }
}
```

**Backup node:**
```
global_defs {
  router_id node2
  vrrp_skip_check_adv_addr
  enable_script_security
}

vrrp_instance VI_1 {
  state BACKUP
  interface enp0s3
  virtual_router_id 51    # Must match primary
  priority 90             # Lower than primary
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass secret123
  }

  virtual_ipaddress {
    10.0.1.100/24
  }
}
```

### Health check scripts

The real power of keepalived is conditional failover based on service health, not just
interface state.

```
vrrp_script check_haproxy {
  script "/usr/bin/pgrep haproxy"     # Simple process check
  interval 2                          # Check every 2 seconds
  weight -20                          # Reduce priority by 20 on failure
  fall 3                              # Require 3 consecutive failures
  rise 2                              # Require 2 consecutive successes to recover
}

# More sophisticated check
vrrp_script check_http {
  script "/usr/bin/curl -sf http://localhost:8080/health"
  interval 5
  weight -30
  fall 2
  rise 2
  timeout 3
}

vrrp_instance VI_1 {
  state MASTER
  interface enp0s3
  virtual_router_id 51
  priority 100
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass secret123
  }

  virtual_ipaddress {
    10.0.1.100/24
  }

  track_script {
    check_haproxy
    check_http
  }
}
```

**How weight works:**
- Node starts with `priority 100`
- If `check_haproxy` fails (weight -20): effective priority = 80
- If `check_http` also fails (weight -30): effective priority = 50
- Backup node with priority 90 takes over (90 > 50)

### Notify scripts (run on state transition)

```
vrrp_instance VI_1 {
  # ... (config as above)

  notify_master "/etc/keepalived/notify.sh MASTER"
  notify_backup "/etc/keepalived/notify.sh BACKUP"
  notify_fault  "/etc/keepalived/notify.sh FAULT"
}
```

```bash
#!/usr/bin/env bash
# /etc/keepalived/notify.sh
set -euo pipefail
STATE=$1
case $STATE in
  MASTER)
    logger "keepalived: became MASTER, starting services"
    systemctl start haproxy
    ;;
  BACKUP)
    logger "keepalived: became BACKUP, stopping services"
    systemctl stop haproxy
    ;;
  FAULT)
    logger "keepalived: entered FAULT state"
    ;;
esac
```

---

## HAProxy + keepalived (classic HA pattern)

The most common HA pattern for load balancers. Two HAProxy instances with keepalived
managing a floating VIP.

```
                    VIP: 10.0.1.100
                    |
          +---------+---------+
          |                   |
    [HAProxy A]         [HAProxy B]
    keepalived           keepalived
    priority=100         priority=90
          |                   |
    +-----+-----+      +-----+-----+
    | Backend 1 |      | Backend 2 |
    +-----------+      +-----------+
```

Both HAProxy instances have identical configs pointing to the same backends. Only the MASTER
holds the VIP. If HAProxy A dies, keepalived on node B detects the failure and claims the VIP.

**Key points:**
- Both HAProxy instances must have identical configs
- HAProxy health checks to backends are independent per instance
- keepalived's `check_haproxy` script ensures the VIP only goes to a node where HAProxy is running
- Clients connect to the VIP -- they don't need to know which node is active

---

## Split-brain prevention

Split-brain occurs when both nodes think they're MASTER (e.g., network partition between them
but both can reach clients). This causes duplicate VIPs and packet storms.

**Mitigations:**

1. **Unicast VRRP** (instead of multicast):
```
vrrp_instance VI_1 {
  state MASTER
  interface enp0s3
  virtual_router_id 51
  priority 100

  unicast_src_ip 10.0.1.10    # This node's IP
  unicast_peer {
    10.0.1.11                  # Other node's IP
  }
  # ... rest of config
}
```

2. **Fencing scripts**: if a node detects split-brain, it can fence itself (remove VIP, stop services)

3. **ARP monitoring**: keepalived can check if the VIP is already answered by another node

---

## Floating IPs on bare metal vs cloud

### Bare metal / VMs

keepalived + VRRP works directly. The VIP is added as a secondary IP on the active node's
interface via gratuitous ARP. Clients on the same L2 segment update their ARP cache.

**Requirements:**
- Nodes must be on the same L2 network (same VLAN/broadcast domain)
- VRRP multicast (224.0.0.18) or unicast must be allowed between nodes
- The VIP must be in the same subnet as the interface

### Cloud (DigitalOcean, Hetzner, etc.)

Cloud providers typically don't support L2 features like gratuitous ARP. Instead:

- **DigitalOcean**: Floating IPs via API -- use keepalived notify scripts to reassign via `doctl`
- **Hetzner**: Floating IPs via API -- notify script calls Hetzner Cloud API
- **AWS**: Elastic IPs or ENI reassignment via API (or use Route53 health checks for DNS failover)

```bash
# Example notify script for DigitalOcean
#!/usr/bin/env bash
set -euo pipefail
STATE=$1
FLOATING_IP="203.0.113.50"
DROPLET_ID=$(curl -s http://169.254.169.254/metadata/v1/id)

if [[ "$STATE" == "MASTER" ]]; then
  doctl compute floating-ip-action assign "$FLOATING_IP" "$DROPLET_ID"
fi
```

---

## Multiple VIPs

Run multiple VRRP instances for different services or active-active failover:

```
# Active-active: each node is MASTER for one VIP, BACKUP for the other
# Node A:
vrrp_instance VI_WEB {
  state MASTER
  interface enp0s3
  virtual_router_id 51
  priority 100
  virtual_ipaddress { 10.0.1.100/24 }
}

vrrp_instance VI_DB {
  state BACKUP
  interface enp0s3
  virtual_router_id 52
  priority 90
  virtual_ipaddress { 10.0.1.101/24 }
}

# Node B: opposite priorities
vrrp_instance VI_WEB {
  state BACKUP
  virtual_router_id 51
  priority 90
  virtual_ipaddress { 10.0.1.100/24 }
}

vrrp_instance VI_DB {
  state MASTER
  virtual_router_id 52
  priority 100
  virtual_ipaddress { 10.0.1.101/24 }
}
```

---

## Troubleshooting keepalived

```bash
# Check VIP assignment
ip addr show enp0s3 | grep 10.0.1.100

# Check keepalived state
systemctl status keepalived
journalctl -u keepalived -f

# Common log messages
# "Entering MASTER STATE" -- this node has the VIP
# "Entering BACKUP STATE" -- this node released the VIP
# "VRRP_Instance(VI_1) Transition to MASTER STATE" -- failover in progress
# "ip address associated with VRID not present" -- VIP configuration issue

# Watch VRRP advertisements (requires tcpdump)
tcpdump -i enp0s3 -nn vrrp
# Or for unicast VRRP:
tcpdump -i enp0s3 -nn proto 112

# Verify both nodes can see each other's advertisements
# If only one direction works, check firewall rules for protocol 112 (VRRP)
```

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Both nodes are MASTER | Split-brain (network partition) | Use unicast VRRP, add fencing |
| VIP doesn't fail over | Backup can't receive VRRP ads | Check firewall for protocol 112, verify L2 connectivity |
| VIP fails over but clients can't reach it | Gratuitous ARP not received | Check switch ARP settings, verify same L2 segment |
| Constant flapping (MASTER/BACKUP) | Health check script is flaky | Increase `fall`/`rise` values, check script reliability |
| keepalived starts but no VIP | Config error, interface name wrong | Check `journalctl -u keepalived`, verify interface name matches |
| VIP works but service doesn't | Service not running on new MASTER | Add notify scripts to start/stop services on transition |

---

## Corosync + Pacemaker (when keepalived isn't enough)

keepalived handles VIP failover well but has limitations:
- No resource ordering (start A before B)
- No resource colocation (A and B must run together)
- No quorum-based decisions
- No fencing (STONITH)

For complex HA clusters with multiple interdependent resources, use Corosync + Pacemaker:

```bash
# Quick setup (RHEL/Debian)
# Install: pacemaker, corosync, pcs (or crmsh)

# Initialize cluster
pcs cluster auth node1 node2
pcs cluster setup --name mycluster node1 node2
pcs cluster start --all

# Add a VIP resource
pcs resource create VIP ocf:heartbeat:IPaddr2 ip=10.0.1.100 cidr_netmask=24

# Add a service resource
pcs resource create HAProxy systemd:haproxy

# Colocation: HAProxy must run where VIP is
pcs constraint colocation add HAProxy with VIP

# Order: VIP must start before HAProxy
pcs constraint order VIP then HAProxy

# STONITH (fencing) -- required for production
pcs stonith create fence_node1 fence_ipmilan ipaddr=10.0.0.1 login=admin passwd=secret
```

**When to use Pacemaker over keepalived:**
- Multiple interdependent services (DB + app + VIP)
- Need for fencing (STONITH) in production
- Quorum-based decisions (3+ node clusters)
- Resource ordering and colocation constraints

**When keepalived is enough:**
- Simple VIP failover
- Two-node active-passive
- HAProxy or Nginx HA (the most common case)
