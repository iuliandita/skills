# Image Building: Packer and Cloud-Init

Reference for building VM templates with Packer and configuring first-boot provisioning
with cloud-init. Covers Proxmox, libvirt/QEMU, and VMware builders.

---

## Table of Contents

1. Cloud-Init Configuration
2. Packer for Proxmox
3. Packer for QEMU/libvirt
4. Cloud Image Workflows
5. Template Management

---

## 1. Cloud-Init Configuration

Cloud-init is the industry standard for VM first-boot configuration. Every major cloud
provider and hypervisor supports it. Learn cloud-init once, use it everywhere.

### user-data (the main config)

```yaml
#cloud-config
# user-data: runs on first boot

# System
hostname: myhost
timezone: UTC
locale: en_US.UTF-8

# Users
users:
  - name: admin
    groups: [sudo, docker]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... admin@workstation

# Packages
package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - curl
  - htop
  - vim

# Commands (run in order)
runcmd:
  - systemctl enable --now qemu-guest-agent
  - timedatectl set-ntp true

# Files
write_files:
  - path: /etc/sysctl.d/99-vm.conf
    content: |
      net.ipv4.ip_forward = 1
      vm.swappiness = 10
    permissions: '0644'

# Disk setup (grow root partition)
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true

# Final message
final_message: "Cloud-init completed in $UPTIME seconds"
```

### network-config (v2 format)

```yaml
version: 2
ethernets:
  eth0:
    addresses:
      - 10.10.10.100/24
    routes:
      - to: default
        via: 10.10.10.1
    nameservers:
      addresses: [10.10.10.11, 10.10.10.12]
      search: [example.com]
```

### meta-data

```yaml
instance-id: myvm-001
local-hostname: myvm
```

### Datasources

Cloud-init reads config from different sources depending on the platform:

| Platform | Datasource | Config delivery |
|----------|-----------|----------------|
| Proxmox | NoCloud | cloud-init drive (IDE/SCSI ISO) |
| libvirt | NoCloud | ISO attached as CDROM |
| AWS | EC2 | Instance metadata service (169.254.169.254) |
| GCP | GCE | Metadata server |
| Azure | Azure | Metadata service |
| OpenStack | OpenStack | Metadata service or config drive |

### Debugging cloud-init

```bash
# Check status
cloud-init status --wait          # Block until complete
cloud-init status --long          # Detailed status

# View logs
cat /var/log/cloud-init.log       # Detailed log
cat /var/log/cloud-init-output.log  # Command output

# Re-run cloud-init (testing)
cloud-init clean                  # Clear instance state
cloud-init init                   # Re-run init stage
cloud-init modules --mode config  # Re-run config modules
cloud-init modules --mode final   # Re-run final modules

# Query instance data
cloud-init query userdata         # Show applied user-data
cloud-init query ds.meta_data     # Show metadata
```

### Cloud-init gotchas

- **Runs once by default.** After first boot, changing cloud-init config has no effect
  unless you run `cloud-init clean` first (clears `/var/lib/cloud/instance/`).
- **Proxmox regenerates the cloud-init drive** when you change settings via API/GUI. But
  the guest won't re-read it without `cloud-init clean` + reboot.
- **NetworkManager vs cloud-init networking:** Some distros (RHEL, Fedora) use
  NetworkManager, which may override cloud-init's network config. Set
  `network: {config: disabled}` in cloud-init to let NM handle networking.
- **Alpine cloud-init:** Alpine uses its own cloud-init fork. Some features (like
  `write_files` with certain permissions) behave differently.
- **Order matters:** cloud-init stages run in order: `init` -> `config` -> `final`.
  `runcmd` runs in the `final` stage, after packages are installed.

---

## 2. Packer for Proxmox

Packer automates VM template creation. Build once, clone many.

### Proxmox builder (HCL2)

```hcl
packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2"
    }
  }
}

source "proxmox-iso" "debian" {
  # Connection
  proxmox_url              = "https://pve1.example.com:8006/api2/json"
  username                 = "packer@pve!automation"
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = "pve1"

  # VM settings
  vm_id                = 9000
  vm_name              = "debian-13-template"
  template_description = "Debian 13 cloud template - built ${timestamp()}"

  # Hardware
  cores    = 2
  memory   = 2048
  cpu_type = "host"
  os       = "l26"
  machine  = "i440fx"
  bios     = "seabios"
  # Use seabios for preseed-based installs. OVMF (UEFI) requires different
  # boot_command - the <esc> + preseed URL technique is BIOS-only.

  # Disk
  disks {
    type              = "scsi"
    disk_size         = "20G"
    storage_pool      = "local-lvm"
    format            = "raw"
    io_thread         = true
    ssd               = true
    discard           = true
  }

  scsi_controller = "virtio-scsi-pci"

  # Network
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # ISO
  iso_url          = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso"
  iso_checksum     = "sha256:CHECKSUM_HERE"
  iso_storage_pool = "local"
  unmount_iso      = true

  # Cloud-init
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # Boot and provisioning
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]
  boot_wait = "5s"

  http_directory = "http"

  # SSH
  ssh_username = "root"
  ssh_password = "packer"
  ssh_timeout  = "20m"

  # QEMU agent
  qemu_agent = true
}

build {
  sources = ["source.proxmox-iso.debian"]

  # Install cloud-init and cleanup
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y cloud-init qemu-guest-agent",
      "systemctl enable qemu-guest-agent",
      "cloud-init clean",
      "apt-get autoremove -y",
      "apt-get clean",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
      "sync"
    ]
  }
}
```

### Proxmox clone builder (faster)

For cloud images that are already ready, use `proxmox-clone` instead of building from ISO:

```hcl
source "proxmox-clone" "debian" {
  proxmox_url              = "https://pve1.example.com:8006/api2/json"
  username                 = "packer@pve!automation"
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = "pve1"

  clone_vm_id  = 9000       # Source template VM ID
  vm_id        = 9001
  vm_name      = "debian-13-custom"

  full_clone = true

  # SSH (to run provisioners)
  ssh_username = "admin"
  ssh_private_key_file = var.ssh_private_key_file  # avoid tilde in HCL - use a variable or absolute path
}
```

---

## 3. Packer for QEMU/libvirt

### QEMU builder

```hcl
packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1.1"
    }
  }
}

source "qemu" "debian" {
  iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso"
  iso_checksum = "sha256:CHECKSUM_HERE"

  output_directory = "output-debian"
  vm_name          = "debian-13.qcow2"

  format       = "qcow2"
  disk_size    = "20G"
  memory       = 2048
  cpus         = 2
  accelerator  = "kvm"

  net_device   = "virtio-net"
  disk_interface = "virtio-scsi"

  headless = true

  ssh_username = "root"
  ssh_password = "packer"
  ssh_timeout  = "20m"

  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]

  http_directory = "http"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y cloud-init qemu-guest-agent",
      "systemctl enable qemu-guest-agent",
      "cloud-init clean",
      "apt-get clean",
      "truncate -s 0 /etc/machine-id",
      "sync"
    ]
  }
}
```

---

## 4. Cloud Image Workflows

### Using pre-built cloud images (fastest path)

Most distros publish cloud images ready for cloud-init. Skip Packer entirely for standard
setups:

```bash
# Debian
wget https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64.qcow2

# Ubuntu
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Alpine (check https://alpinelinux.org/cloud/ for current version)
wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-x86_64-bios-cloudinit-r0.qcow2

# Fedora (check https://fedoraproject.org/cloud/download for current release)
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-41-1.3.x86_64.qcow2

# Rocky Linux (uses .latest symlink - always current minor)
wget https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
```

### Custom cloud image pipeline (CI/CD)

For organizations that need customized base images:

```
1. Download upstream cloud image (weekly cron)
2. Customize with Packer (install agents, security baseline, SSH keys)
3. Upload to Proxmox (scp to local:import/ on each node)
4. Create/update template VM
5. New VMs clone from template + cloud-init for per-VM config
```

### Proxmox template from cloud image (manual)

```bash
# Download cloud image to Proxmox node
cd /var/lib/vz/template/iso/
wget https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64.qcow2

# Create template VM
qm create 9000 --name debian-13-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --agent enabled=1 \
  --scsihw virtio-scsi-pci

# Import disk
qm importdisk 9000 debian-13-generic-amd64.qcow2 local-lvm

# Attach imported disk
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,iothread=1,ssd=1 \
  --boot order=scsi0

# Add cloud-init drive
qm set 9000 --ide2 local-lvm:cloudinit

# Optional: serial console for cloud images that expect it
qm set 9000 --serial0 socket --vga serial0

# Convert to template
qm template 9000
```

---

## 5. Template Management

### Template versioning strategy

Templates are immutable once created. Use a naming/numbering scheme:

```
debian-13-v20260401     # Date-based (simple, clear)
debian-13-2.1.0         # SemVer (more formal)
9000-9049               # VM ID range reserved for templates
```

### Multi-node template distribution

Templates live on local storage and must exist on each node. Options:

1. **CI pipeline:** Build on one node, scp to others
   ```bash
   # On build node
   qm template 9000
   # Copy to other nodes (vzdump + restore)
   vzdump 9000 --storage local --mode stop --compress zstd
   scp /var/lib/vz/dump/vzdump-qemu-9000-*.zst pve2:/var/lib/vz/dump/
   # On target node
   qmrestore /var/lib/vz/dump/vzdump-qemu-9000-*.zst 9000 --storage local-lvm
   qm template 9000
   ```

2. **Shared storage:** Store templates on NFS/Ceph (accessible from all nodes)

3. **Proxmox replication:** Replicate template storage with ZFS send/receive

### Image hardening checklist

Before converting a VM to a template:

- [ ] Packages updated (`apt update && apt upgrade`)
- [ ] cloud-init installed and enabled
- [ ] QEMU guest agent installed and enabled
- [ ] SSH hardened (key-only auth, no root login)
- [ ] `machine-id` cleared (`truncate -s 0 /etc/machine-id`)
- [ ] SSH host keys removed (cloud-init regenerates them)
- [ ] Bash history cleared
- [ ] `/tmp` and `/var/tmp` cleaned
- [ ] No leftover user data, credentials, or logs
- [ ] `cloud-init clean` run (so it re-runs on first boot)
- [ ] Filesystem synced (`sync`)
