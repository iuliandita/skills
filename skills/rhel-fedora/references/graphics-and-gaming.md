# Graphics and Gaming

Use this reference for NVIDIA, AMD, Intel, Vulkan, Steam, Proton, Gamescope, MangoHud, and driver
or kernel-lane mismatches.

## First-pass commands

```bash
lspci -k | grep -Ei 'vga|3d|display'
lsmod | grep -E 'nvidia|amdgpu|i915|xe' 2>&1 || true
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm' 2>&1 || true
vulkaninfo --summary 2>&1 || true
rpm -qa | grep -Ei 'mesa|nvidia|akmod|kmod|vulkan|steam|gamescope|mangohud' | sort
```

## Notes

- Fedora NVIDIA and gaming setups often hinge on RPM Fusion state, akmods, Secure Boot, and matching kernel headers.
- Enterprise clones may use DKMS or vendor repos instead of Fedora-style akmods.
- Oracle UEK vs RHCK can change out-of-tree module behavior.
- Steam and Proton still need 32-bit userspace on many setups.
- Gamescope and MangoHud are useful tests, but also extra moving parts.
