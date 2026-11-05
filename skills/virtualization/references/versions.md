---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Proxmox VE"
    version: "9.2"
    source: "https://pve.proxmox.com/wiki/Roadmap"
  - tool: "Proxmox Backup Server"
    version: "4.2"
    source: "https://pbs.proxmox.com/wiki/index.php/Roadmap"
  - tool: "bpg/proxmox (Terraform)"
    version: "0.115.0"
    source: "https://github.com/bpg/terraform-provider-proxmox/releases"
  - tool: "QEMU"
    version: "11.1.2"
    source: "https://www.qemu.org/download/"
  - tool: "libvirt"
    version: "12.8.0"
    source: "https://libvirt.org/news.html"
  - tool: "XCP-ng"
    version: "8.3 LTS"
    source: "https://docs.xcp-ng.org/releases/"
  - tool: "VMware ESXi"
    version: "8.0 U3k (25595708)"
    source: "https://brcm.tech/vmsa-2026-0006"
  - tool: "VirtualBox"
    version: "7.2.20"
    source: "https://www.virtualbox.org/wiki/Downloads"
  - tool: "Packer"
    version: "1.16.1"
    source: "https://github.com/hashicorp/packer/releases"
  - tool: "cloud-init"
    version: "26.2"
    source: "https://github.com/canonical/cloud-init/releases"
---

# Virtualization target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Reverify before use if the receipt exceeds 120 days.

| Tool | Version | Release date | Notes |
|------|---------|-------------|-------|
| Proxmox VE | 9.2 | May 2026 | Current production lane; review upgrade notes from 9.1 |
| Proxmox Backup Server | 4.2 | Apr 2026 | Dedup, incremental, prune policies |
| bpg/proxmox (Terraform) | 0.115.0 | Oct 2026 | Primary Proxmox IaC provider |
| QEMU | 11.1.2 | Sep 2026 | Stable 11.1 maintenance release |
| libvirt | 12.8.0 | Oct 2026 | Hypervisor abstraction layer |
| XCP-ng | 8.3 LTS | Oct 2024 | Xen-based, LTS since Jun 2025, EOL Nov 2028 |
| VMware ESXi | 8.0 U3k (25595708) | Jul 2026 | Security floor for the 8.0 U3 lane (build number unverified October 2026); check the appliance lane |
| VirtualBox | 7.2.20 | Sep 2026 | Current 7.2 maintenance release |
| Packer | 1.16.1 | Sep 2026 | Image builder, multi-platform |
| cloud-init | 26.2 | Jul 2026 | Instance initialization standard |

## Security recheck (2026-09-10)

[VMSA-2026-0006](https://brcm.tech/vmsa-2026-0006)
addresses critical CVE-2026-47876 (ESX VMXNET3 VM escape, CVSS 9.3). The 8.0 fixed builds are
ESXi80U3k-25595708 or ESXi80U2f-25626445 (build numbers unverified October 2026: the Broadcom advisory is not fetchable); select the matching update lane.
The advisory also covers critical vCenter CVE-2026-59309/CVE-2026-59310;
patch vCenter separately using its response matrix. ESX/vCenter 7.0 require
Broadcom extended-support guidance rather than assuming an 8.0 patch applies.
