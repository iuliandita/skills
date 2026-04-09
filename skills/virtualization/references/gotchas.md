# Virtualization Gotchas and Pitfalls

Battle-tested failure modes from production Proxmox/KVM environments. Read this before
making non-trivial changes to VM infrastructure. Each entry represents hours of debugging
that you don't have to repeat.

---

## Table of Contents

1. QEMU Behavior
2. LVM Thin Pools
3. Memory and Ballooning
4. Live Migration
5. PCI/GPU Passthrough
6. Proxmox-Specific
7. Terraform (bpg/proxmox)
8. Cloud-Init
9. Storage Performance

---

## 1. QEMU Behavior

### Reboot vs stop/start (the #1 gotcha)

**Problem:** Guest `reboot` does NOT restart the QEMU process. It resets the virtual
hardware within the same QEMU instance. This means:

- Disk config changes (discard, cache, iothread, bus type) don't take effect
- Memory balloon device changes don't take effect
- New PCI devices don't attach
- CPU model changes don't apply
- Machine type changes don't apply

**Fix:** Always use `qm stop` then `qm start` (Proxmox) or `virsh destroy` then
`virsh start` (libvirt) for hardware configuration changes. `qm reboot` and `virsh reboot`
are NOT sufficient.

**How to remember:** Reboot = guest OS restart. Stop/start = new QEMU process.

### QEMU agent timeout on first boot

**Problem:** When creating a VM with `agent.enabled = true` and using cloud-init, the first
boot takes longer because cloud-init needs to install the QEMU guest agent package. The
QEMU agent isn't available until after cloud-init finishes.

**Symptoms:** Terraform apply shows timeout warnings. Proxmox UI shows "QEMU agent not
running" for the first few minutes.

**Fix:** Set agent timeout to 2+ minutes. This is expected behavior, not a failure.

---

## 2. LVM Thin Pools

### 100% data_percent = total I/O failure

**Problem:** When an LVM thin pool's data space reaches 100%, ALL VMs on that pool
experience I/O failure simultaneously. No graceful degradation, no warnings to the guest -
just hung I/O and frozen VMs.

**Recovery:**
1. `lvextend -L +50G <vg>/<thin_pool>` - add space to the thin pool
2. If no space available: live-migrate VMs to another node/pool
3. After extending: `qm stop <vmid>` then `qm start <vmid>` (not reboot - QEMU needs restart)
4. `qm reset` does NOT work here - the QEMU disk backend needs to re-detect the pool state

**Prevention:**
- Monitor `data_percent` (not filesystem usage inside VMs!)
- Alert at 80% (warning) and 90% (critical)
- Enable `discard=on` on VM disks + `fstrim.timer` in guests to reclaim deleted blocks
- Remember: `data_percent` = blocks ever written, not current usage

### data_percent only goes up (without TRIM)

**Problem:** LVM thin pool `data_percent` tracks blocks that have been written. Deleting
files in the guest doesn't free thin pool blocks unless TRIM/discard is properly configured
end-to-end.

**The full chain:**
1. QEMU disk config: `discard=on` (passes SCSI UNMAP from guest to host)
2. Guest filesystem: `fstrim.timer` enabled (sends TRIM to QEMU disk)
3. LVM thin pool: processes the discard and frees blocks

**If any link is broken, space is never reclaimed.**

### Thin pool metadata exhaustion

Less common but equally fatal. The thin pool has a separate metadata area. If metadata
fills up, the pool becomes read-only. Monitor `metadata_percent` alongside `data_percent`.

---

## 3. Memory and Ballooning

### Balloon device + Alpine/BSD = pain

**Problem:** The KVM balloon device works by asking the guest to return unused memory to the
host. This works well on recent Debian/Ubuntu with the balloon driver. It does NOT work
reliably on:

- **Alpine Linux** - can't hotplug DIMMs. Balloon changes need full power-cycle (stop/start)
- **FreeBSD** - balloon driver support varies by version
- **Older kernels** - balloon driver may not handle memory pressure correctly

**Symptoms:** VM becomes unresponsive, OOM kills inside guest, guest hangs when balloon
deflates (host trying to reclaim memory).

**Fix:** Disable ballooning (`balloon: 0` in Proxmox, `memory_min_mb = 0` in Terraform).
Provision VMs with the memory they actually need. Overcommitment via ballooning is a
false economy.

### Memory hotplug limitations

**Problem:** Adding memory to a running VM (hotplug) requires the guest OS to accept new
DIMM modules. This works on modern Linux (Debian 12+, Ubuntu 22.04+, RHEL 9+) but fails
silently on many other OSes.

**Fix:** Size memory correctly at VM creation. If you must change memory, plan for a
stop/start cycle.

### Hugepages and ballooning are mutually exclusive

Hugepages-backed memory can't be ballooned. If you enable hugepages on a VM, the balloon
device has no effect. This isn't a bug - hugepages are pinned physical memory by definition.

---

## 4. Live Migration

### SSH disconnect aborts migration

**Problem:** `qm migrate` (Proxmox) and `virsh migrate` (libvirt) run in the foreground.
If the SSH session drops (network blip, laptop sleep, terminal disconnect), the migration
aborts.

**Impact:** Migration is abort-safe (source VM stays running, target LVs cleaned up), so
data loss doesn't occur. But you've wasted time and I/O bandwidth.

**Fix:**
```bash
# Proxmox
nohup qm migrate <vmid> <target> --online --with-local-disks \
  > /tmp/migrate-<vmid>.log 2>&1 &
tail -f /tmp/migrate-<vmid>.log

# libvirt
nohup virsh migrate --live --copy-storage-all myvm qemu+ssh://target/system \
  > /tmp/migrate-myvm.log 2>&1 &
```

### Memory convergence for write-heavy VMs

**Problem:** Live migration copies memory pages while the VM runs. If the VM writes memory
faster than the migration can copy it, it never converges. QEMU eventually forces a brief
pause to complete the transfer (usually < 100ms), but for very write-heavy VMs (databases,
Redis, in-memory caches), this pause can be longer.

**Mitigation:** Migrate during low-traffic windows. Consider increasing migration bandwidth
(Proxmox: Datacenter > Options > Migration Settings).

### CPU feature mismatch

**Problem:** Live migration requires compatible CPU features on source and target. If the
source has AVX-512 and the target doesn't, migration fails.

**Fix:** Use a baseline CPU type for VMs that need migration across heterogeneous hardware:
- `x86-64-v2-AES` - modern baseline (SSE4.2 + AES-NI)
- `x86-64-v3` - includes AVX2
- `host` - only for same-model CPU clusters

---

## 5. PCI/GPU Passthrough

### pcie=0 vs pcie=1

**Problem:** Using `pcie=1` (PCIe mode) requires q35 machine type and may cause issues
with some devices. `pcie=0` (standard PCI) works everywhere.

**Rule:** Use `pcie=0` unless you specifically need PCIe features (e.g., PCIe ACS, SR-IOV).

### x-vga on compute GPUs

**Problem:** Setting `x-vga=1` on a compute GPU (used for CUDA/OpenCL, not display output)
interferes with the VM's virtual display adapter. The GPU tries to act as the primary
display device, which can cause boot failures or blank console.

**Rule:** Only set `x-vga=1` on display GPUs (where the VM uses the physical GPU for
video output). For compute GPUs: `x-vga=0` (or omit entirely).

### GPU reset bug

**Problem:** Some GPUs (especially older AMD cards and some NVIDIA Quadro models) don't
reset properly when the VM shuts down. The device gets stuck in a state where it can't be
re-assigned to a new VM (or the same VM after restart) without rebooting the host.

**Workaround:** Some vendors have firmware updates that fix this. Others don't. Check the
Proxmox/VFIO community wikis for your specific GPU model. AMD's reset bug is particularly
well-documented.

### IOMMU group pollution

**Problem:** All devices in an IOMMU group must be passed to the same VM. If a GPU shares
a group with the SATA controller, you can't pass just the GPU.

**Fix:**
1. Use a different PCIe slot (different groups)
2. Enable ACS in BIOS (if available)
3. ACS override patch (last resort, has security implications)

---

## 6. Proxmox-Specific

### fail2ban on Debian 13 (trixie)

**Problem:** Traditional fail2ban configs for Proxmox reference `/var/log/daemon.log`, which
doesn't exist on Debian 13+ with systemd/journald.

**Fix:**
```ini
# /etc/fail2ban/jail.d/proxmox.conf
[proxmox]
enabled = true
backend = systemd
journalmatch = _COMM=pvedaemon
maxretry = 3
bantime = 3600
```

### openipmi on non-IPMI hardware

**Problem:** The `openipmi` service starts on boot and fails on hardware without a BMC/IPMI
controller. Generates NodeSystemdServiceFailed alerts in monitoring.

**Fix:** `systemctl mask openipmi` - masking survives package updates, disabling doesn't.

### Proxmox cluster and quorum

**Problem:** A 2-node cluster loses quorum when one node goes down. Without quorum, the
surviving node can't start HA services or modify cluster config.

**Fix:** Use 3+ nodes, or configure a QDevice (Corosync Qdevice) on a lightweight third
host to serve as a quorum witness.

### LXC container bind mount permissions

**Problem:** Bind-mounting host directories into unprivileged LXC containers requires
matching the container's UID/GID mapping. The container's root (UID 0) maps to UID 100000
on the host (by default).

**Fix:** `chown -R 100000:100000 /host/path` for directories shared with unprivileged
containers, or use the `mp0` option with `backup=0` to avoid backup bloat.

---

## 7. Terraform (bpg/proxmox)

### prevent_destroy + ignore_changes (non-negotiable)

Every VM resource needs:
```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes = [
    disk,                           # Disk resized via qm, not TF
    network_device[0].mac_address,  # Auto-generated
    node_name,                      # Changed by live migration
  ]
}
```

Without `prevent_destroy`: `terraform destroy` kills production VMs.
Without `ignore_changes[disk]`: TF detects drift after `qm resize`, tries to recreate VM.
Without `ignore_changes[node_name]`: TF tries to migrate VM back after live migration.

### cloud_init_interface = null defaults to ide2

**Problem:** When `cloud_init_interface` is null (unset), the provider creates the
cloud-init drive on `ide2`. This is fine for most setups but can conflict if you're using
IDE for CD-ROM or have a specific bus requirement.

**Fix:** Set explicitly to `scsi1` if you want SCSI, or leave as null for the default.

### Disk resize is not supported

**Problem:** The bpg/proxmox provider cannot resize disks. There's no resize operation in
the Proxmox API that maps cleanly to a Terraform resource update.

**Procedure:**
1. `qm resize <vmid> scsi0 +10G` on the host
2. `growpart /dev/sda 1` in the guest
3. `resize2fs /dev/sda1` in the guest
4. Update `disk_size_gb` in Terraform to match (prevents drift)

### vendor_data_file_id changes cause replacement

**Problem:** If you change the `vendor_data_file_id` (cloud-init vendor data snippet),
Terraform may try to recreate the VM. Add to `ignore_changes` if you update vendor data
frequently.

---

## 8. Cloud-Init

### Runs once, then never again

**Problem:** Cloud-init is designed to run once on first boot. Changing cloud-init config
via Proxmox API after the first boot has no effect on the running VM.

**To re-apply:** `cloud-init clean` in the guest, then reboot. This clears the instance
data and forces cloud-init to re-run.

### Network config fights with NetworkManager

**Problem:** On distros with NetworkManager (RHEL, Fedora), cloud-init's network config
and NM's own config can conflict, causing network flapping or wrong DNS settings.

**Fix:** Either let cloud-init handle networking (disable NM for cloud-init-managed
interfaces) or let NM handle it (`network: {config: disabled}` in cloud-init).

### Alpine cloud-init quirks

Alpine uses a different cloud-init package (`cloud-init` from Alpine repos) that behaves
slightly differently from the Canonical version. Test cloud-init configs on Alpine
specifically if you're building Alpine templates.

---

## 9. Storage Performance

### virtio-scsi-single vs virtio-scsi-pci

**Problem:** `virtio-scsi-pci` uses one SCSI controller shared across all disks. Under
heavy I/O, the controller becomes a bottleneck. `virtio-scsi-single` creates one controller
per disk, each with its own iothread.

**When it matters:** Databases, VMs with multiple disks, high-IOPS workloads.

**When it doesn't:** Single-disk VMs with moderate I/O.

### Cache modes matter

| Mode | Data safety | Performance | Use case |
|------|------------|-------------|----------|
| `none` | Good (direct I/O) | Good | Default, most workloads |
| `writeback` | Risky (host cache) | Best | Battery-backed RAID only |
| `writethrough` | Best (sync writes) | Worst | When data safety > speed |
| `directsync` | Best | Bad | Same as writethrough, direct I/O |
| `unsafe` | None | Best | Testing only, NEVER production |

### SSD emulation + discard chain

For thin-provisioned storage on SSDs, all four pieces must be in place:

1. **QEMU disk:** `ssd=1` (tells guest it's on SSD)
2. **QEMU disk:** `discard=on` (passes TRIM from guest to host)
3. **Guest OS:** `fstrim.timer` enabled (or `discard` mount option)
4. **Host storage:** Thin-provisioned pool that supports discard

Missing any link means deleted data never gets reclaimed at the storage level.
And remember: adding `discard=on` to an existing VM requires `qm stop` + `qm start`
(not reboot) because QEMU disk config only applies when QEMU starts fresh.
