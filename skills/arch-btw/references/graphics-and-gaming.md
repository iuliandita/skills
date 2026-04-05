# Graphics and Gaming

Linux gaming on Arch is mostly about stack alignment, not magic tweaks. The hard parts are:

- correct GPU driver path for the actual hardware
- matching Vulkan and OpenGL userspace
- 32-bit multilib pieces for Steam and Proton
- Wayland, Xwayland, and Gamescope interaction
- knowing when CachyOS is helping and when it is just adding another variable

## First checks

Start here before touching launch options:

```bash
lspci -k | grep -Ei 'vga|3d|display'
uname -r
pacman -Q mesa vulkan-radeon vulkan-intel nvidia-utils nvidia-open linux-firmware steam gamescope mangohud gamemode 2>/dev/null
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm|vulkan'
```

If available, these help too:

```bash
command -v glxinfo >/dev/null 2>&1 && glxinfo -B
command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary
command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi
```

`glxinfo` usually comes from `mesa-utils`. `vulkaninfo` usually comes from `vulkan-tools`.

## Vendor routing

### AMD

AMD is usually the least painful Linux gaming path.

- Mesa provides the main OpenGL stack.
- `vulkan-radeon` provides RADV, the default Vulkan path most Arch users want.
- Wayland, Gamescope, VRR, and modern Proton setups are usually straightforward here.
- Firmware still matters. If the kernel log shows GPU init or firmware errors, check `linux-firmware` before chasing compositor settings.

Common AMD mistakes:

- old firmware
- mixed or stale Mesa packages
- assuming the issue is Proton when the kernel log already shows amdgpu trouble

### Intel

Intel works well for desktop Linux, but the gaming ceiling depends heavily on generation.

- Mesa is again the main userspace stack.
- `vulkan-intel` is the normal Vulkan driver package.
- Wayland behavior is usually good, but performance expectations need to match the iGPU class.
- On laptops, memory bandwidth, power profile, and shader cache behavior can matter more than exotic tweaks.

Common Intel mistakes:

- expecting handheld or AAA-game performance from weak iGPUs
- blaming Steam when the system is just GPU-limited
- missing Vulkan support on older or unsupported hardware

### NVIDIA

NVIDIA is the neverending Linux footgun source because more layers have to agree:

- kernel module choice
- userspace driver package
- compositor behavior
- Gamescope compatibility
- PRIME or hybrid graphics path on laptops

Main stance:

- `nvidia-utils` is the userspace anchor.
- `nvidia-open` exists, but it is not a universal answer. Hardware generation and support expectations still matter.
- Keep the kernel package and NVIDIA module path coherent. Driver mismatch after a kernel move is a classic Arch breakage.
- Wayland has improved a lot, but NVIDIA issues still often show up first in Hyprland, Gamescope, suspend or resume, HDR, and hybrid-GPU workflows.

Common NVIDIA mistakes:

- updating kernel and not the matching driver path
- treating every compositor issue as a Hyprland bug when the driver stack is already unhappy
- broken PRIME offload assumptions on laptops
- missing 32-bit userspace for Steam and Proton

## Hybrid graphics on laptops

Many laptops have two GPUs (iGPU + dGPU). On Arch, this affects gaming, Gamescope, suspend, and
external display behavior.

Common layouts:

| Combo | Typical path | Key pain points |
|-------|-------------|-----------------|
| Intel iGPU + NVIDIA dGPU | PRIME offload or reverse PRIME | driver mismatch, suspend, external displays |
| AMD iGPU + NVIDIA dGPU | PRIME offload | same NVIDIA pain with different iGPU driver |
| AMD iGPU + AMD dGPU | PRIME offload via Mesa | simpler driver story, but offload routing still matters |

Fast checks:

```bash
lspci -k | grep -Ei 'vga|3d|display'
cat /proc/driver/nvidia/gpus/*/information 2>&1 || true
command -v prime-run >/dev/null 2>&1 && echo "prime-run available"
command -v supergfxctl >/dev/null 2>&1 && supergfxctl -g
```

Operational stance:

- Identify which GPU renders the display and which runs offloaded workloads before changing driver packages.
- Games launched via Steam can use `prime-run %command%` or env vars to target the dGPU.
- Gamescope behavior on hybrid systems depends on which GPU it binds to.
- Suspend bugs on hybrid laptops are often dGPU power-state issues, not compositor bugs.
- External monitors may route through the dGPU even when the internal panel uses the iGPU.

## Steam and Proton

Steam is the default Linux gaming path on Arch. Most "Steam is broken" reports are really one of:

1. missing multilib
2. wrong GPU userspace
3. bad launch wrapper
4. broken shader cache or Proton prefix

Key operational points:

- Steam itself is only part of the stack.
- Proton depends on the graphics stack below it.
- 32-bit userspace matters for many games and compatibility layers.
- If a launch option chain becomes too clever, suspect the launch options before suspecting Proton.

Useful split:

| Symptom | First suspicion |
|--------|-----------------|
| Steam UI works, game crashes instantly | Proton prefix, Vulkan path, missing multilib, launch options |
| Native game fails too | driver stack or compositor layer |
| Only one game breaks after tweaks | game-specific launch options or prefix state |
| Everything breaks after update | Mesa, NVIDIA, kernel, or firmware skew |

## Gamescope, MangoHud, GameMode

These are useful, but they are also common sources of self-inflicted complexity.

### Gamescope

Gamescope is a nested compositor widely used for gaming, especially on Wayland, handheld-style setups, and frame pacing experiments.

- Good tool, but not a universal "make Linux gaming better" button
- If a game works without Gamescope and breaks with it, treat Gamescope as the suspect first
- Especially relevant with HDR, fullscreen behavior, scaling, capture, and NVIDIA edge cases

### MangoHud

MangoHud is for visibility, not salvation.

- Use it to verify FPS, frametimes, clocks, and GPU use
- If a game only fails with MangoHud injected, the overlay is part of the problem

### GameMode

GameMode can help with CPU governor and process priority behavior, but it is not a replacement for a healthy driver stack.

- Good for polish
- Bad as a first-line explanation for crashes or black screens

## Why CachyOS gets gaming attention

CachyOS gets mentioned by Linux gamers for concrete reasons:

- optimized repos for newer CPU targets
- custom kernel options and easy kernel switching
- gaming-focused documentation
- integrated attention to schedulers, performance defaults, and convenience tools
- snapshot-friendly recovery on common installs

The CachyOS gaming guide explicitly covers package installation, Steam with Proton, Proton variants, Lutris, and gaming launch-option helpers.

Important reality check:

- CachyOS is not magic and does not bypass bad driver support
- some gains are workload-dependent, not universal
- each added optimization layer is also another compatibility variable

## Things users often forget

These are common misses that are worth checking early:

- multilib enabled for Steam-era gaming stacks
- 32-bit userspace matching the active GPU vendor
- firmware current enough for the GPU
- VRR or HDR assumptions not matching the compositor or monitor path
- PRIME or hybrid-GPU offload on laptops
- controller, input, or anti-cheat issues that are not actually graphics failures
- launch options copied from Reddit that stack multiple wrappers blindly
- shader cache corruption or stale compatibility prefixes

## What NOT to do

- Do not prescribe random kernel flags, environment variables, or launch-option soup before checking the base driver stack.
- Do not blame Proton first when the native graphics stack is already broken.
- Do not assume NVIDIA advice applies to AMD or Intel.
- Do not assume Gamescope, MangoHud, or GameMode are harmless; they are extra moving parts.
- Do not sell CachyOS as "faster Linux gaming by default" without explaining the tradeoff: more tuned components also means more variables.
