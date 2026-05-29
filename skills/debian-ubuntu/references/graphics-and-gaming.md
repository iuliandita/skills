# Graphics and Gaming

Use this for NVIDIA, AMD/Mesa, Intel, Vulkan, Steam, Proton, Gamescope, MangoHud, and desktop
gaming failures on Debian/Ubuntu. The recurring root causes are wrong driver branch, missing 32-bit
(`i386`) userspace, and a broken Vulkan loader path - not "Linux gaming is bad."

## Identify the GPU and active driver first

```bash
lspci -k | grep -EiA3 'vga|3d|display'
glxinfo -B 2>&1 | grep -Ei 'vendor|renderer|opengl' || true
lsmod | grep -Ei 'nvidia|nouveau|amdgpu|radeon|i915|^xe'
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm' 2>&1 || true
```

`lspci -k` shows `Kernel driver in use:` per device - that is the actual driver, not the one you
think is installed. NVIDIA on `nouveau` instead of the proprietary module, or a hybrid laptop
rendering on the wrong GPU, shows up here.

## NVIDIA (proprietary vs nouveau)

```bash
ubuntu-drivers devices                 # Ubuntu: recommended driver per hardware
apt-cache policy nvidia-driver-* 2>&1 | head -40
nvidia-smi 2>&1 || true                # only works when the proprietary driver is loaded and bound
dkms status                            # NVIDIA module builds via DKMS per kernel
```

- On Ubuntu, `ubuntu-drivers autoinstall` (or `ubuntu-drivers install nvidia:<branch>`) is the
  supported path; Debian uses `nvidia-driver` from non-free plus the kernel headers.
- `nvidia-smi` failing after a kernel update is usually DKMS drift: the module did not rebuild for
  the new `uname -r`. Confirm with `dkms status` and that `linux-headers-$(uname -r)` is installed.
- On Wayland, confirm the driver branch supports it; very old branches force Xorg fallback.

## AMD and Intel (Mesa)

```bash
apt-cache policy mesa-vulkan-drivers libgl1-mesa-dri 2>&1 | head -40
vainfo 2>&1 || true                    # VA-API hardware video decode
```

AMD and Intel use the in-kernel `amdgpu`/`i915`/`xe` drivers plus Mesa userspace; there is usually
no separate driver install. Graphics behavior tracks the shipped Mesa version. For newer GPUs on
Debian stable, Mesa may be too old - that is a backports/newer-kernel situation, not a config bug.

## Vulkan

```bash
vulkaninfo --summary 2>&1 | head -40 || true   # from vulkan-tools
apt-cache policy vulkan-tools mesa-vulkan-drivers 2>&1 | head
```

`vulkaninfo` listing no devices means the loader cannot find an ICD. For 32-bit games it must find
the `i386` Vulkan driver too. A missing or mismatched ICD is the usual "Vulkan not available" cause.

## 32-bit (i386) userspace - the top Steam/Proton failure

```bash
dpkg --print-foreign-architectures               # must list i386 for Steam
sudo dpkg --add-architecture i386 && sudo apt update   # if missing
# then install the i386 graphics userspace matching the GPU vendor, e.g.:
#   AMD/Intel: mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386
#   NVIDIA:    libnvidia-gl-<branch>:i386
```

Steam and most Proton titles need 32-bit graphics libraries. If `dpkg --print-foreign-architectures`
does not list `i386`, the multiarch userspace is absent and games fail with library or Vulkan
errors despite a working 64-bit desktop.

## Steam, Proton, and launch wrappers

```bash
glxinfo -B 2>&1 | grep renderer       # confirm the right GPU is rendering
DRI_PRIME=1 glxinfo -B 2>&1 | grep renderer   # hybrid: force the dGPU
```

- Test a plain game launch before adding Gamescope or MangoHud; a wrapper can mask or cause the
  failure. Gamescope (`gamescope -- %command%`) and MangoHud are layers on top of a working stack.
- On hybrid laptops, `DRI_PRIME=1` (Mesa) or the NVIDIA PRIME profile decides which GPU runs the
  game. A title rendering on the iGPU when you expect the dGPU is a PRIME/offload setting, not a
  driver fault.

## Notes

- Verify the driver actually in use (`lspci -k`) before blaming the game or Proton.
- Steam/Proton failures are usually missing `i386` userspace or a broken Vulkan loader.
- DKMS drift after a kernel update is the classic "NVIDIA stopped working" cause.
- Compare a clean baseline: plain launch vs Gamescope/MangoHud, and iGPU vs dGPU on hybrids.
