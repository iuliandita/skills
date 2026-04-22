# Gotchas and Special Situations

Use this reference when the straightforward path failed and the system still looks cursed.

## Common RPM-family traps

- third-party repo drift after a Fedora release bump
- package not found because CRB / CodeReady Builder / EPEL assumptions are wrong
- SELinux label drift after manual file moves or custom data paths
- runtime `firewalld` fix never made permanent
- Oracle Linux issue caused by UEK assumptions
- Amazon Linux issue caused by treating AL2023 like generic RHEL 9
- module stream mismatch causing solver chaos
- akmods or DKMS drift after a kernel update
- Secure Boot blocking third-party kernel modules
- cloud image missing tools that a full install would have

## What to do next

1. simplify the problem to one layer
2. verify distro lane and repo provenance again
3. verify SELinux and firewall state again
4. compare current kernel path to the last known-good path
5. remove one extra moving part at a time
