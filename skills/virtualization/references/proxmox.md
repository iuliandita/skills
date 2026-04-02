# Proxmox VE Deep-Dive

Comprehensive reference for Proxmox VE administration, automation, and Terraform provisioning.

---

## Table of Contents

1. API and CLI
2. VM Creation and Configuration
3. Cloud-Init Integration
4. Storage Backends
5. Clustering and HA
6. Live Migration
7. PCI/GPU Passthrough
8. Backup and Snapshots (PBS)
9. Terraform with bpg/proxmox
10. Monitoring and Alerting
11. LXC Containers

---

## 1. API and CLI

Proxmox has a full REST API at `https://<host>:8006/api2/json/`. Every GUI action maps to
an API call. The `pvesh` CLI wraps the API for shell use.

### Authentication

```bash
# API token (preferred for automation -- no 2FA, no session expiry)
pvesh get /version --token 'user@pam!tokenid=TOKEN_SECRET'

# Ticket-based (interactive, short-lived)
curl -k -d 'username=root@pam&password=SECRET' \
  https://pve:8006/api2/json/access/ticket
# Returns CSRFPreventionToken + ticket cookie

# Terraform / API clients: use API tokens with least-privilege
# Create: Datacenter > Permissions > API Tokens
# Assign per-resource permissions, not root
```

### pvesh (API shell wrapper)

```bash
pvesh get /nodes                          # List nodes
pvesh get /nodes/pve1/qemu                # List VMs on pve1
pvesh get /nodes/pve1/qemu/100/status/current  # VM 100 status
pvesh create /nodes/pve1/qemu -vmid 100 -name test -memory 2048 -cores 2
pvesh set /nodes/pve1/qemu/100/config -memory 4096
pvesh create /nodes/pve1/qemu/100/status/start  # Start VM
pvesh get /cluster/resources --type vm    # All VMs cluster-wide
```

### qm (VM management)

```bash
# Lifecycle
qm create 100 --name myvm --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsi0 local-lvm:32 \
  --ide2 local-lvm:cloudinit --boot order=scsi0 --agent enabled=1

qm start 100
qm shutdown 100          # ACPI shutdown (graceful)
qm stop 100              # Hard stop (power off)
qm reset 100             # Hard reset (reboot)
qm reboot 100            # ACPI reboot

# Configuration
qm config 100            # Full config dump
qm set 100 --memory 4096 --cores 4
qm set 100 --scsi0 local-lvm:32,discard=on,iothread=1,ssd=1
qm set 100 --cpu host    # CPU passthrough
qm set 100 --numa 1      # Enable NUMA
qm set 100 --balloon 0   # Disable ballooning

# Disk operations
qm resize 100 scsi0 +10G          # Grow disk (can't shrink)
qm move-disk 100 scsi0 ceph-pool  # Move disk to different storage
qm importdisk 100 image.qcow2 local-lvm  # Import disk image

# Snapshots
qm snapshot 100 snap1 --description "before upgrade"
qm rollback 100 snap1
qm delsnapshot 100 snap1

# Agent commands (requires qemu-guest-agent in VM)
qm agent 100 ping
qm agent 100 get-osinfo
qm agent 100 network-get-interfaces
qm agent 100 get-fsinfo

# Templates
qm template 100          # Convert VM to template (irreversible)
qm clone 100 101 --name new-vm --full  # Full clone from template
```

### pct (LXC containers)

```bash
pct list                                  # List containers
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname myct --memory 512 --cores 1 --net0 name=eth0,bridge=vmbr0,ip=dhcp
pct start/stop/shutdown 200
pct enter 200                             # Attach console
pct exec 200 -- apt update               # Run command in container
pct resize 200 rootfs +5G                # Grow rootfs
```

### pveam (template management)

```bash
pveam update                              # Refresh template list
pveam available --section system          # List available templates
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

---

## 2. VM Creation and Configuration

### Hardware best practices

**CPU:**
- `cpu: host` for production (full feature passthrough to guest)
- `cpu: x86-64-v2-AES` for migration-compatible baseline across mixed CPU generations
- Enable NUMA for VMs with 4+ cores or 8GB+ RAM
- `hotplug: cpu` works on modern Linux guests (add vCPUs without reboot)

**Memory:**
- Set `balloon: 0` to disable ballooning (see gotchas in SKILL.md)
- Enable NUMA alongside memory for correct topology mapping
- Hugepages: configure on host first, then enable per-VM

**Disk:**
- Interface: `scsi0` with `virtio-scsi-pci` or `virtio-scsi-single` controller
- `iothread=1` on each disk when using virtio-scsi (dedicated I/O thread per disk)
- `ssd=1` when the backing store is SSD (enables TRIM support in guest)
- `discard=on` for thin-provisioned storage (passes UNMAP to storage backend)
- Format: `raw` on LVM-thin (no overhead), `qcow2` on directory storage (snapshots)
- `cache=none` for most workloads (direct I/O, best with battery-backed RAID)
- `cache=writeback` only with battery-backed write cache or when performance > safety

**Network:**
- Model: `virtio` always (unless legacy Windows without virtio drivers)
- Bridge: `vmbr0` (default), create additional bridges for VLANs
- VLAN tag: set on the network device, not the bridge (e.g., `net0: virtio,bridge=vmbr0,tag=100`)

**Boot:**
- BIOS: `seabios` for most Linux VMs (simpler, faster boot)
- BIOS: `ovmf` (UEFI) for Secure Boot, Windows 11, or when EFI is required
- Machine: `q35` for PCIe passthrough, `i440fx` (default) for everything else

### QEMU guest agent

Install in every VM. Required for:
- Clean shutdown (ACPI shutdown waits for agent response)
- IP address reporting in Proxmox UI
- Filesystem freeze during snapshots (consistent backups)
- `qm agent` commands

```bash
# Debian/Ubuntu
apt install qemu-guest-agent
systemctl enable --now qemu-guest-agent

# Alpine
apk add qemu-guest-agent
rc-update add qemu-guest-agent
service qemu-guest-agent start

# RHEL/Fedora
dnf install qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

---

## 3. Cloud-Init Integration

Cloud-init is the standard for first-boot VM configuration. Proxmox has native cloud-init
support -- attach a cloud-init drive and configure via API/CLI.

### Proxmox cloud-init workflow

```bash
# 1. Download a cloud image
wget https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64.qcow2

# 2. Create a VM from the cloud image
qm create 9000 --name debian-13-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --agent enabled=1
qm importdisk 9000 debian-13-generic-amd64.qcow2 local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,iothread=1,ssd=1 \
  --scsihw virtio-scsi-pci --boot order=scsi0

# 3. Add cloud-init drive
qm set 9000 --ide2 local-lvm:cloudinit

# 4. Configure cloud-init
qm set 9000 --ciuser admin --sshkeys ~/.ssh/id_rsa.pub \
  --ipconfig0 ip=10.10.10.100/24,gw=10.10.10.1 \
  --nameserver 10.10.10.1 --searchdomain example.com

# 5. Convert to template
qm template 9000

# 6. Clone for new VMs
qm clone 9000 100 --name prod-web-01 --full
qm set 100 --ipconfig0 ip=10.10.10.101/24,gw=10.10.10.1
qm start 100
```

### Cloud-init vendor data (advanced)

For config beyond what Proxmox's cloud-init fields support, use vendor data snippets:

```yaml
# /var/lib/vz/snippets/custom-vendor-data.yaml
#cloud-config
package_update: true
packages:
  - qemu-guest-agent
  - curl
  - htop
runcmd:
  - systemctl enable --now qemu-guest-agent
write_files:
  - path: /etc/sysctl.d/99-custom.conf
    content: |
      net.ipv4.ip_forward = 1
```

Attach via: `qm set 100 --cicustom "vendor=local:snippets/custom-vendor-data.yaml"`

### Cloud-init gotchas

- Cloud-init runs ONCE on first boot. Changing cloud-init config after first boot requires
  clearing the instance data: `cloud-init clean` in the guest, then reboot.
- The cloud-init drive is a small ISO attached to the VM. Proxmox regenerates it when you
  change cloud-init settings via the API.
- Some images (Alpine) need `cloud-init` package installed in the image first.
- Network config: Proxmox generates NoCloud datasource config. If the guest has
  NetworkManager, it may fight with cloud-init's network config.

---

## 4. Storage Backends

### LVM-Thin

The most common storage for local SSDs. Thin provisioning means VMs only consume space they
actually write to.

```bash
# Check thin pool status
lvs -a -o+devices,data_percent,metadata_percent
# data_percent = blocks ever written (not current usage!)
# metadata_percent = thin pool metadata usage

# Extend thin pool when running low
lvextend -L +50G pve/data

# Check actual block usage vs allocated
pvesm status
```

**CRITICAL: data_percent semantics.** `data_percent` measures blocks that have EVER been
written to, not current filesystem usage. A VM that wrote 50GB then deleted it still shows
50GB in data_percent. The only way to reclaim space is:
1. `discard=on` on the QEMU disk config
2. `fstrim` in the guest (or `fstrim.timer` for automatic weekly TRIM)
3. **Both require `qm stop` + `qm start`** if discard was added after VM creation (guest
   reboot doesn't restart QEMU, so disk config changes don't take effect)

### ZFS

Built into Proxmox. Best for data integrity (checksums), compression, and native snapshots.

```bash
# Pool status
zpool status
zpool list

# Create VM storage on ZFS
pvesm add zfspool zfs-pool --pool rpool/data --content images,rootdir

# Snapshots are instant (copy-on-write)
# Replication uses ZFS send/receive
```

### Ceph (RBD)

Integrated into Proxmox for shared storage across cluster nodes. VMs can live-migrate
without `--with-local-disks` because Ceph is shared.

Setup requires 3+ nodes, dedicated network for Ceph traffic (10Gbps+ recommended).

### NFS

Good for ISOs, templates, backups, and VZDump storage. Not ideal for VM disks (latency).

```bash
pvesm add nfs nfs-storage --server 10.10.10.4 --export /volume1/pve \
  --content iso,vztmpl,backup
```

---

## 5. Clustering and HA

### Cluster setup

Minimum 3 nodes for quorum. Dedicated cluster network recommended (corosync).

```bash
# On first node
pvecm create mycluster

# On additional nodes
pvecm add 10.10.10.1    # IP of existing cluster node

# Status
pvecm status             # Cluster status, quorum info
pvecm nodes              # Node list with votes
```

### High Availability

HA requires shared storage (Ceph, NFS, iSCSI) or local storage with replication.

```bash
# Add VM to HA
ha-manager add vm:100 --state started --group ha-group1
ha-manager status

# HA groups define which nodes can run which VMs
ha-manager groupadd ha-group1 --nodes pve1,pve2,pve3 --nofailback 0
```

**Fencing:** HA requires reliable fencing (IPMI, iLO, iDRAC, or watchdog). Without fencing,
split-brain scenarios can start the same VM on two nodes simultaneously, causing data
corruption. The default software watchdog works but hardware watchdog is preferred.

---

## 6. Live Migration

### When it works

- **Shared storage (Ceph, NFS):** Migration moves only memory and CPU state. Fast.
- **Local storage:** Requires `--with-local-disks`. Copies disk over the network during
  migration. Slow for large disks but the VM stays online.

### CLI patterns

```bash
# Basic online migration (shared storage)
qm migrate 100 pve2 --online

# With local disks (LVM-thin to LVM-thin)
qm migrate 100 pve2 --online --with-local-disks

# For large VMs -- ALWAYS use nohup (SSH disconnect aborts migration)
nohup qm migrate 100 pve2 --online --with-local-disks \
  > /tmp/migrate-100.log 2>&1 &
tail -f /tmp/migrate-100.log

# Offline migration (VM must be stopped)
qm migrate 100 pve2
```

### Migration gotchas

- **SSH disconnect kills migration.** `qm migrate` runs in the foreground. A network blip
  or laptop lid close aborts the migration. Always use `nohup` for VMs with large disks.
- **Migration is abort-safe.** If migration fails or is aborted, the source VM keeps running.
  Target LVs are cleaned up automatically.
- **CPU compatibility.** Live migration requires compatible CPU features on source and target.
  Using `cpu: host` prevents migration across different CPU generations. Use
  `x86-64-v2-AES` or similar baseline for migration-compatible configs.
- **Memory convergence.** VMs with high write rates (databases) may struggle to converge
  memory during live migration. QEMU will eventually force a brief pause to complete the
  transfer (typically < 100ms for most workloads).

---

## 7. PCI/GPU Passthrough

### Prerequisites

1. Enable IOMMU in BIOS (Intel VT-d or AMD-Vi)
2. Enable in kernel: add `intel_iommu=on` or `amd_iommu=on` to boot params
3. Load vfio modules: `vfio`, `vfio_iommu_type1`, `vfio_pci`

```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Bind GPU to vfio-pci driver (required before passthrough works)
# Find the device's vendor:device IDs with: lspci -nn | grep -i nvidia
echo "options vfio-pci ids=10de:XXXX,10de:YYYY" > /etc/modprobe.d/vfio-pci.conf
# XXXX = GPU, YYYY = audio device (pass both if in same IOMMU group)

# Blacklist host GPU driver (prevents host from claiming the device)
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf

# Rebuild initramfs and reboot for vfio-pci binding to take effect
update-initramfs -u
# Reboot, then verify: lspci -nnk | grep -A3 NVIDIA should show "Kernel driver in use: vfio-pci"
```

### Proxmox hardware mappings (PVE 8.1+)

Hardware mappings abstract physical PCI devices into logical names. This allows Terraform
and automation to reference devices by name instead of bus address, and supports live
migration to nodes with different PCI topologies.

```bash
# Create mapping via API
pvesh create /cluster/mapping/pci --id gpu-quadro --map 'node=pve3,path=0000:01:00.0'
```

### VM configuration

```bash
# Compute GPU (no display output needed)
qm set 100 --hostpci0 mapping=gpu-quadro,pcie=0
# pcie=0: standard PCI passthrough (works everywhere)
# pcie=1: PCIe passthrough (needed for some features, requires q35)
# NO x-vga for compute GPUs -- x-vga is only for display passthrough

# Display GPU (VM uses GPU for video output)
qm set 100 --hostpci0 mapping=gpu-display,pcie=1,x-vga=1
# x-vga=1: marks device as primary display adapter
# Requires q35 machine type and OVMF BIOS
```

### Terraform passthrough

```hcl
variable "hostpci" {
  type = list(object({
    device  = string           # hostpci slot: "hostpci0", "hostpci1", etc.
    mapping = string           # Proxmox hardware mapping name
    pcie    = optional(bool, false)   # PCIe vs PCI mode
    xvga    = optional(bool, false)   # Display GPU passthrough
    rombar  = optional(bool, true)    # ROM BAR visibility
  }))
  default = []
}
```

### Passthrough gotchas

- **IOMMU group isolation:** All devices in an IOMMU group must be passed to the same VM.
  If a GPU shares a group with other devices, use ACS override patch (last resort) or pick
  a different PCIe slot.
- **`pcie=0` vs `pcie=1`:** Use `pcie=0` (standard PCI) unless you specifically need PCIe
  features. `pcie=1` requires q35 machine type.
- **`x-vga` is only for display GPUs.** Don't set it on compute GPUs (CUDA/OpenCL). It
  interferes with the VM's virtual display adapter.
- **Driver installation:** The guest needs the GPU driver (nvidia, amdgpu). Install after
  first boot with passthrough enabled.
- **Reset bug:** Some GPUs (older AMD, some NVIDIA Quadro) don't reset properly on VM
  shutdown. The device becomes unusable until the host reboots. Check the PVE community
  wiki for your specific GPU model.

---

## 8. Backup and Snapshots (PBS)

### Proxmox Backup Server (PBS)

Dedicated backup solution with deduplication, incremental backups, and encryption.

```bash
# Configure PBS storage in Proxmox
pvesm add pbs pbs-storage --server 10.10.10.5 --datastore store1 \
  --username backup@pbs --password SECRET --fingerprint FINGERPRINT

# Manual backup
vzdump 100 --storage pbs-storage --mode snapshot --compress zstd

# Schedule via GUI or /etc/cron.d/vzdump
# Recommended: daily with 7-day retention, weekly with 4-week retention
```

### VZDump (built-in backups)

```bash
# Snapshot mode (online, requires QEMU agent for consistency)
vzdump 100 --mode snapshot --compress zstd --storage local

# Suspend mode (brief pause, consistent)
vzdump 100 --mode suspend --compress zstd --storage nfs-backup

# Stop mode (offline, guaranteed consistent)
vzdump 100 --mode stop --compress zstd --storage nfs-backup
```

### Snapshot vs backup

| Feature | Snapshot | Backup (VZDump/PBS) |
|---------|----------|---------------------|
| Speed | Instant (COW) | Minutes to hours |
| Storage | Same pool as VM | Separate storage |
| Purpose | Quick rollback point | Disaster recovery |
| Retention | Short-term (days) | Long-term (weeks/months) |
| Impact on performance | Yes (COW writes double) | Minimal (snapshot mode) |

**Don't use snapshots as backups.** Snapshots live on the same storage as the VM. If the
storage fails, both the VM and its snapshots are gone.

---

## 9. Terraform with bpg/proxmox

The `bpg/proxmox` provider is the actively maintained Terraform provider for Proxmox VE.
The older Telmate provider is abandoned -- don't use it.

### Provider configuration

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.100"
    }
  }
}

provider "proxmox" {
  endpoint = "https://pve1.example.com:8006/"
  api_token = "terraform@pve!automation=SECRET"
  insecure  = true  # Self-signed cert (use ca_cert in production)
  ssh {
    agent = true
    node {
      name    = "pve1"
      address = "10.10.10.1"
    }
  }
}
```

### VM resource pattern

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  node_name = var.proxmox_node
  name      = var.name
  vm_id     = var.vm_id

  bios       = var.bios          # "seabios" or "ovmf"
  machine    = var.machine        # "q35" for PCIe, null for default
  on_boot    = true
  boot_order = ["scsi0"]

  agent {
    enabled = true
    timeout = "2m"               # First boot timeout (cloud-init installs agent)
  }

  cpu {
    cores = var.cores
    type  = "host"
    numa  = true
  }

  memory {
    dedicated = var.memory_mb
    floating  = 0                # 0 = balloon disabled
  }

  disk {
    datastore_id = var.datastore
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.disk_size_gb
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore
    interface    = null           # null defaults to ide2

    user_account {
      username = var.cloud_init_user
      keys     = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "${var.ip}/${var.subnet_prefix}"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
      domain  = var.search_domain
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      disk,                      # Disk resized via qm, not Terraform
      network_device[0].mac_address,  # Auto-generated
      node_name,                 # Changes after live migration
    ]
  }
}
```

### Terraform lifecycle patterns (critical)

**`prevent_destroy = true`:** Non-negotiable on all VMs. Prevents accidental `terraform
destroy` from killing production VMs.

**`ignore_changes = [disk]`:** Disk resize must happen via `qm resize` on the host, not
Terraform. If you don't ignore disk changes, Terraform will try to recreate the VM when
the actual disk size doesn't match the config.

**`ignore_changes = [node_name]`:** After live migration, the VM's node_name changes.
Without this ignore rule, Terraform would try to migrate it back on next apply.

**`ignore_changes = [network_device[0].mac_address]`:** MAC addresses are auto-generated.
Without this, Terraform detects drift on every plan.

**`cloud_init_interface = null`:** When null, the bpg/proxmox provider defaults to `ide2`
for the cloud-init drive. Explicitly set to `scsi1` if you need SCSI.

**QEMU agent timeout:** On first boot, the QEMU agent isn't installed yet (cloud-init
installs it). The provider's `agent.timeout = "2m"` gives cloud-init time to install and
start the agent. First apply may show a timeout warning -- this is expected.

### Disk resize procedure (the Terraform trap)

Terraform CANNOT resize Proxmox VM disks. The bpg/proxmox provider doesn't support it.

```bash
# 1. On Proxmox host
qm resize <vmid> scsi0 +10G

# 2. In the VM guest
growpart /dev/sda 1              # Expand partition (GPT) -- needed for both ext4 and XFS
resize2fs /dev/sda1              # Expand ext4 filesystem
# Or for XFS:
# growpart /dev/sda 1 && xfs_growfs /

# 3. Update Terraform variable to match new size
# This prevents Terraform from showing drift
```

---

## 10. Monitoring and Alerting

### Built-in metrics

Proxmox exposes metrics via its API. Key endpoints:

```bash
pvesh get /nodes/pve1/status        # Node CPU, memory, uptime
pvesh get /nodes/pve1/rrddata --timeframe hour  # Time-series data
pvesh get /cluster/resources --type vm  # All VMs with status
```

### Prometheus integration

Use the Proxmox VE Exporter or query the API directly:

```bash
# pve-exporter (community)
# Exposes /metrics endpoint for Prometheus scraping
# Covers node, VM, container, storage, and cluster metrics
```

### Key metrics to monitor

| Metric | Warning | Critical | Notes |
|--------|---------|----------|-------|
| Thin pool data_percent | 80% | 90% | 100% = all VM I/O fails |
| Thin pool metadata_percent | 75% | 85% | Metadata exhaustion kills the pool |
| Node CPU steal time | >10% | >25% | Overcommitment indicator |
| Node memory free | <15% | <5% | OOM killer territory |
| Ceph health | WARN | ERR | Any non-HEALTH_OK |
| VM disk I/O latency | >10ms | >50ms | Storage bottleneck |
| Corosync ring status | any error | -- | Cluster communication failure |

### LVM thin pool monitoring (textfile collector)

```bash
#!/usr/bin/env bash
set -euo pipefail
# Write to node_exporter textfile collector directory
OUTPUT="/var/lib/node_exporter/textfile/lvm_thin.prom"
lvs --noheadings --nosuffix --units b -o lv_name,data_percent,metadata_percent \
  --select 'lv_attr=~[t]' | while read -r name data meta; do
  echo "lvm_thin_data_percent{lv=\"$name\"} $data"
  echo "lvm_thin_metadata_percent{lv=\"$name\"} $meta"
done > "$OUTPUT"
```

---

## 11. LXC Containers

Proxmox supports both VMs (KVM) and containers (LXC). Use containers for lightweight
workloads that don't need full OS isolation.

### When to use LXC vs VM

| Factor | LXC | VM (KVM) |
|--------|-----|----------|
| Overhead | Minimal (shared kernel) | Full OS boot, more RAM |
| Isolation | Namespace-based | Full hardware virtualization |
| Kernel | Host kernel | Own kernel |
| Use case | System services, DNS, proxies | Full OS, custom kernel, passthrough |
| Security | Less isolated (shared kernel) | Stronger isolation |

### Unprivileged containers

Always prefer unprivileged containers (default in Proxmox). Privileged containers run as
root on the host -- a container escape gives full host access.

```bash
# Check if container is unprivileged
pct config 200 | grep unprivileged
# unprivileged: 1 = good
```

### Bind mounts

```bash
# Mount host directory into container
pct set 200 --mp0 /mnt/data,mp=/data
# Permissions: match container's internal UID mapping
```
