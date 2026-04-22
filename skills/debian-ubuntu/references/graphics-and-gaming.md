# Graphics and Gaming

Use this for NVIDIA, Mesa, Vulkan, Steam, Proton, Gamescope, and desktop gaming failures.

## Checks
- `lspci -k | grep -Ei 'vga|3d|display'`
- `journalctl -b | grep -Ei 'nvidia|amdgpu|i915|xe|drm'`
- `apt-cache policy nvidia-driver mesa-vulkan-drivers`
- `dpkg --print-foreign-architectures`

## Notes
- Verify the actual driver in use before blaming the game.
- Steam/Proton often need 32-bit graphics libraries.
