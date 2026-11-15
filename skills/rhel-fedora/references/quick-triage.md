# Quick Triage Checklist

Symptom to first-checks table for RHEL-family and Fedora problems.

## Quick Triage Checklist

| Symptom | First checks |
|---------|-------------|
| Package weirdness after install | `dnf repolist`, `dnf check`, `rpm -q`, module stream mismatch (RHEL 8/9), third-party repo drift |
| Package unavailable on RHEL | entitlement or CRB missing? `subscription-manager repos --list-enabled`, repo enablement, EPEL assumptions |
| SELinux broke my app | `getenforce`, `ausearch -m avc -ts recent`, labeling vs boolean vs policy module |
| Service fails after update | repo drift, dropped config, `systemctl status`, `journalctl -b`, `rpm -V package` |
| Won't boot after kernel work | EFI mount, `grubby --info=ALL`, `dracut` image, Secure Boot, fallback kernel |
| Fedora upgrade weirdness | exact Fedora release, `dnf system-upgrade` state, third-party repos, COPR packages |
| RHEL clone behaves oddly | clone-specific release docs, vault state, EPEL assumptions, unsupported in-place upgrade folklore |
| Oracle Linux issue | RHCK vs UEK first, then driver/storage/virtualization path |
| Amazon Linux mismatch | AL2023 vs AL2, cloud-init defaults, AWS package docs, missing extra repos |
| Desktop weirdness after update | `XDG_SESSION_TYPE`, portal, Xwayland, user services |
| Bluetooth audio issues | BlueZ pairing, PipeWire nodes, card profile |
| Game blackscreen/crash | GPU driver, Vulkan, multilib graphics libs, Gamescope/MangoHud |
| Screen share broken | Wayland vs X11, portal backend, PipeWire user units |
| Suspend/resume breaks desktop | sleep state, GPU logs, lock-screen, display manager |
| NVIDIA/module vanished after kernel change | akmods or DKMS drift, Secure Boot signing, current kernel vs installed module |
| Nothing makes sense | check gotchas reference - repo drift, SELinux labeling, module stream confusion, stale third-party repos, and kernel lane mismatch explain a lot |
