# libvirt, QEMU, and KVM

Reference for direct libvirt/QEMU/KVM management outside of Proxmox. Use this when working
with raw KVM on Linux hosts, OpenStack compute nodes, or custom virtualization setups.

---

## Table of Contents

1. KVM Kernel Modules
2. virsh Commands
3. XML Domain Definitions
4. QEMU Command Line
5. Disk Formats and Management
6. Networking
7. CPU Features and Topology

---

## 1. KVM Kernel Modules

KVM is a kernel module that turns Linux into a type-1 hypervisor. QEMU provides the
userspace emulation. libvirt is the management API layer on top.

```bash
# Verify KVM support
lsmod | grep kvm
# kvm_intel or kvm_amd must be loaded

# Check if KVM is available
ls -la /dev/kvm
# Must exist and be accessible by the libvirt user

# Load modules if missing
modprobe kvm
modprobe kvm_intel  # or kvm_amd

# Check CPU virtualization support
grep -E 'vmx|svm' /proc/cpuinfo

# Nested virtualization (VMs inside VMs)
cat /sys/module/kvm_intel/parameters/nested
# Enable: echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm.conf
```

---

## 2. virsh Commands

virsh is the primary CLI for libvirt. Every command maps to a libvirt API call.

### Lifecycle

```bash
virsh list --all                      # List all domains (VMs)
virsh start myvm                      # Start
virsh shutdown myvm                   # ACPI shutdown (graceful)
virsh destroy myvm                    # Force stop (like pulling power)
virsh reboot myvm                     # ACPI reboot
virsh reset myvm                      # Hard reset
virsh suspend myvm                    # Pause (freeze in memory)
virsh resume myvm                     # Unpause
virsh undefine myvm --remove-all-storage  # Delete VM and disks
```

### Configuration

```bash
virsh dumpxml myvm                    # Full XML config
virsh dominfo myvm                    # Summary info
virsh domblklist myvm                 # List block devices
virsh domiflist myvm                  # List network interfaces
virsh edit myvm                       # Edit XML config (opens $EDITOR)

# Live changes (hot-plug)
virsh setvcpus myvm 4 --live         # Add vCPUs live
virsh setmem myvm 4G --live          # Change memory live (if balloon enabled)
virsh attach-disk myvm /path/to/disk.qcow2 vdb --driver qemu --subdriver qcow2 --live
virsh detach-disk myvm vdb --live
virsh attach-interface myvm bridge virbr0 --model virtio --live
```

### Snapshots

```bash
virsh snapshot-create-as myvm snap1 --description "before upgrade" --disk-only
virsh snapshot-list myvm
virsh snapshot-revert myvm snap1
virsh snapshot-delete myvm snap1
```

### Migration

```bash
# Live migration (shared storage)
virsh migrate --live myvm qemu+ssh://target/system

# Live migration (copy storage)
virsh migrate --live --copy-storage-all myvm qemu+ssh://target/system

# With bandwidth limit (MiB/s)
virsh migrate --live --bandwidth 100 myvm qemu+ssh://target/system
```

### Storage pools

```bash
virsh pool-list --all                 # List storage pools
virsh pool-info default               # Pool details
virsh vol-list default                # List volumes in pool
virsh vol-create-as default myvm.qcow2 20G --format qcow2
virsh vol-resize default myvm.qcow2 30G
virsh vol-delete default myvm.qcow2
```

### Network

```bash
virsh net-list --all                  # List virtual networks
virsh net-dumpxml default             # Network XML config
virsh net-edit default                # Edit network config
virsh net-start default               # Start network
virsh net-autostart default           # Auto-start on boot
```

---

## 3. XML Domain Definitions

### Minimal VM definition

```xml
<domain type='kvm'>
  <name>myvm</name>
  <memory unit='GiB'>4</memory>
  <vcpu placement='static'>2</vcpu>

  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
  </os>

  <features>
    <acpi/>
    <apic/>
  </features>

  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' dies='1' cores='2' threads='1'/>
  </cpu>

  <devices>
    <!-- Disk -->
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap' iothread='1'/>
      <source file='/var/lib/libvirt/images/myvm.qcow2'/>
      <target dev='sda' bus='scsi'/>
    </disk>

    <!-- SCSI controller with iothread -->
    <controller type='scsi' model='virtio-scsi'>
      <driver iothread='1'/>
    </controller>

    <!-- Network -->
    <interface type='bridge'>
      <source bridge='br0'/>
      <model type='virtio'/>
    </interface>

    <!-- VGA (minimal for headless) -->
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>

    <!-- Serial console -->
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>

    <!-- QEMU guest agent -->
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>

    <!-- RNG for entropy -->
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
    </rng>
  </devices>
</domain>
```

### NUMA topology

```xml
<cpu mode='host-passthrough'>
  <topology sockets='1' dies='1' cores='4' threads='2'/>
  <numa>
    <cell id='0' cpus='0-3' memory='4' unit='GiB'/>
    <cell id='1' cpus='4-7' memory='4' unit='GiB'/>
  </numa>
</cpu>
```

### PCI passthrough

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

### Cloud-init via NoCloud

```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/myvm-cidata.iso'/>
  <target dev='sdb' bus='scsi'/>
  <readonly/>
</disk>
```

Generate the ISO:
```bash
cloud-localds myvm-cidata.iso user-data.yaml meta-data.yaml
# Or with network config:
cloud-localds -N network-config.yaml myvm-cidata.iso user-data.yaml meta-data.yaml
```

---

## 4. QEMU Command Line

Direct QEMU usage is rare (virsh/Proxmox wrap it), but useful for debugging and
understanding what's happening under the hood.

```bash
# Minimal KVM boot
qemu-system-x86_64 -enable-kvm -m 2G -smp 2 \
  -drive file=disk.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -nographic

# With cloud-init
qemu-system-x86_64 -enable-kvm -m 2G -smp 2 \
  -drive file=disk.qcow2,if=virtio,format=qcow2,discard=unmap \
  -drive file=cidata.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic

# QEMU monitor (runtime control)
# Press Ctrl-A C in -nographic mode for the monitor console
# Or use -monitor unix:/tmp/monitor.sock,server,nowait
```

### QEMU monitor commands

```
info status              # VM state
info block               # Block device info
info network             # Network device info
info cpus                # vCPU info
system_reset             # Hard reset
system_powerdown         # ACPI shutdown
quit                     # Kill QEMU
device_add               # Hot-add device
drive_mirror             # Block migration
```

---

## 5. Disk Formats and Management

| Format | Thin provision | Snapshots | Performance | Use case |
|--------|---------------|-----------|-------------|----------|
| **raw** | No (pre-allocated) | No (native) | Best | LVM-thin, Ceph (thin at storage layer) |
| **qcow2** | Yes | Yes (internal) | Good | Directory storage, development |
| **vmdk** | Depends | Yes | Good | VMware compat (migration only) |
| **vpc/vhd** | Depends | Yes | OK | Hyper-V compat |

### qcow2 management

```bash
# Create
qemu-img create -f qcow2 disk.qcow2 20G

# Resize
qemu-img resize disk.qcow2 +10G

# Convert between formats
qemu-img convert -f vmdk -O qcow2 disk.vmdk disk.qcow2
qemu-img convert -f qcow2 -O raw disk.qcow2 disk.raw

# Info (check actual vs virtual size)
qemu-img info disk.qcow2

# Check for errors
qemu-img check disk.qcow2

# Compact (reclaim sparse space)
qemu-img convert -O qcow2 disk.qcow2 disk-compact.qcow2
mv disk-compact.qcow2 disk.qcow2
```

### Backing files (copy-on-write)

```bash
# Create overlay disk backed by a template
qemu-img create -f qcow2 -b template.qcow2 -F qcow2 overlay.qcow2
# overlay.qcow2 only stores changes from template.qcow2
# Great for fast VM cloning from templates
```

---

## 6. Networking

### Bridge networking (most common)

```bash
# Create a bridge (systemd-networkd)
# /etc/systemd/network/br0.netdev
[NetDev]
Name=br0
Kind=bridge

# /etc/systemd/network/br0.network
[Match]
Name=br0
[Network]
Address=10.10.10.1/24
Gateway=10.10.10.1

# /etc/systemd/network/en.network
[Match]
Name=enp0s*
[Network]
Bridge=br0
```

### macvtap

Direct connection to physical NIC. Better performance than bridge, but the VM can't
communicate with the host (by design -- use bridge if host-VM communication is needed).

```xml
<interface type='direct'>
  <source dev='enp0s25' mode='bridge'/>
  <model type='virtio'/>
</interface>
```

### Open vSwitch (OVS)

Software-defined networking. Useful for complex topologies, VXLAN overlays, and OpenFlow.

```bash
# Create OVS bridge
ovs-vsctl add-br ovs-br0
ovs-vsctl add-port ovs-br0 enp0s25
```

```xml
<interface type='bridge'>
  <source bridge='ovs-br0'/>
  <virtualport type='openvswitch'/>
  <model type='virtio'/>
</interface>
```

### vhost-net

Kernel-based virtio network backend. Significantly better performance than userspace
QEMU networking. Enabled by default in most modern setups.

```bash
# Verify vhost-net is loaded
lsmod | grep vhost_net
# If missing: modprobe vhost_net
```

---

## 7. CPU Features and Topology

### CPU modes

| Mode | Compatibility | Performance | Migration |
|------|--------------|-------------|-----------|
| `host-passthrough` | None (exact host CPU) | Best | Same CPU model only |
| `host-model` | Similar CPUs | Good | Similar generations |
| `custom` | Any (you pick features) | Depends | Full control |

### CPU pinning

Pin vCPUs to physical cores for consistent performance (databases, latency-sensitive):

```xml
<vcpu placement='static'>4</vcpu>
<cputune>
  <vcpupin vcpu='0' cpuset='2'/>
  <vcpupin vcpu='1' cpuset='3'/>
  <vcpupin vcpu='2' cpuset='6'/>
  <vcpupin vcpu='3' cpuset='7'/>
  <emulatorpin cpuset='0-1'/>
</cputune>
```

Pin to physical cores, not HT siblings. Use `lscpu -e` to see core-to-thread mapping.
Avoid pinning to core 0 (often handles interrupts).

### virt-install

```bash
# Create VM from ISO
virt-install --name myvm --memory 4096 --vcpus 4 \
  --disk size=20,format=qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --network bridge=br0,model=virtio \
  --os-variant debian12 \
  --cdrom debian-12-netinst.iso \
  --graphics none --console pty,target.type=serial

# Create VM from cloud image
virt-install --name myvm --memory 2048 --vcpus 2 \
  --import --disk path=disk.qcow2,format=qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --cloud-init user-data=user-data.yaml \
  --network bridge=br0,model=virtio \
  --os-variant debian12 \
  --noautoconsole
```
