# Hardware, desktop, and kernels

NixOS ships more kernel choices than most distros and needs explicit modules for some
hardware paths. `nixos-hardware` carries community profiles; the bundled modules handle
common cases.

## Picking a kernel

`boot.kernelPackages` is the knob. Defaults to the latest LTS that nixpkgs tracks at the
release's branch point. NixOS 25.11 defaults to Linux 6.12 LTS; `pkgs.linuxPackages_latest`
tracks mainline (6.17 at the 25.11 branch, bumped in-branch as mainline advances - Linux
6.18 is an LTS tagged late 2025 and lands under explicit `pkgs.linuxPackages_6_18` once it
is backported to the release branch).

```nix
{
  # latest stable (tracks nixpkgs, moves with rebuilds)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # specific version (pin for stability)
  boot.kernelPackages = pkgs.linuxPackages_6_12;   # LTS

  # hardened kernel variant
  boot.kernelPackages = pkgs.linuxPackages_hardened;

  # zen / liquorix / custom - use overlays or nixpkgs options
  boot.kernelPackages = pkgs.linuxPackages_zen;
}
```

Kernel changes drag every out-of-tree module with them: NVIDIA, ZFS, `v4l2loopback`, DKMS
in general. Before flipping kernels, confirm the modules build against the new kernel in
the nixpkgs tag you are on.

### Kernel modules and parameters

```nix
{
  boot.kernelModules = [ "kvm-amd" "vfio-pci" ];
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
    options snd-hda-intel power_save=1
  '';
  boot.kernelParams = [ "mitigations=auto" "nvidia-drm.modeset=1" ];
}
```

### initrd modules

```nix
{
  boot.initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usb_storage" ];
  boot.initrd.kernelModules = [ "dm_mod" "btrfs" ];
}
```

Needed for LUKS, ZFS, rare storage controllers, or unusual root filesystems. Regenerate
`hardware-configuration.nix` via `nixos-generate-config` after changing hardware.

## nixos-hardware

[nixos-hardware](https://github.com/NixOS/nixos-hardware) carries vendor-specific modules
for laptops and SBCs. Import the profile that matches the hardware:

```nix
# flake.nix
inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

# configuration.nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    # or: lenovo-thinkpad-x1-extreme
    # or: dell-xps-13-9310
    # or: raspberry-pi-4
  ];
}
```

Profiles cover firmware, kernel params, power management, GPU quirks, and occasionally
audio routing or sensors.

## Firmware

Non-Redistributable firmware is under `linux-firmware` but requires `allowUnfree`:

```nix
{
  nixpkgs.config.allowUnfree = true;
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;  # vendor firmware updates via fwupd
}
```

## GPU

### Intel

```nix
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;           # for Steam, older apps
    extraPackages = with pkgs; [ intel-media-driver intel-vaapi-driver vpl-gpu-rt ];
  };
}
```

### AMD

Modern AMDGPU "just works" with Mesa:

```nix
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ rocmPackages.clr.icd amdvlk ];
  };
  services.xserver.videoDrivers = [ "amdgpu" ];   # if using X
}
```

### NVIDIA

Proprietary driver path. Tricky but well-documented:

```nix
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;                     # set true for open-source kernel modules on supported GPUs
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
```

Driver branches: `stable`, `beta`, `production`, `legacy_*`, `vulkan_beta`. Pick the branch
that matches the card. Tesla-era cards need legacy; Turing+ use stable or production.

### Hybrid graphics (laptops)

```nix
{
  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    intelBusId = "PCI:0:2:0";     # check lspci
    nvidiaBusId = "PCI:1:0:0";
  };
}
```

Or `sync.enable = true;` for always-on dGPU, or `reverseSync.enable = true;` for the
external-displays-off-dGPU pattern.

## Desktop: Wayland vs X11

NixOS carries both. Pick by session type and compositor.

### GNOME (Wayland default)

```nix
{
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
}
```

### KDE Plasma 6

```nix
{
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
}
```

### Hyprland

```nix
{
  programs.hyprland.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };
}
```

### niri, sway, river

Each has a top-level `programs.<name>` option. Enable the compositor and an appropriate
portal.

## Steam, Gamescope, and gaming

```nix
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # 32-bit graphics userspace is required for most Steam titles
  hardware.graphics.enable32Bit = true;
}
```

Proton lives in Steam; DXVK and VKD3D ride with Proton. For Proton-GE or custom runners,
`extraCompatPackages` or `protonup` via home-manager handles the install.

## Screen capture on Wayland

Wayland screen capture on Hyprland, Plasma 6, or GNOME uses the
`xdg-desktop-portal` + PipeWire screencast path - not X11 window capture. OBS reads the
portal via `pipewire` source, and browsers use `xdg-desktop-portal`'s screencast prompt.

```nix
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };
  services.pipewire.enable = true;   # must be true; see PipeWire block below

  environment.systemPackages = with pkgs; [
    obs-studio
    (obs-studio.override { plugins = [ obs-studio-plugins.obs-pipewire-audio-capture ]; })
  ];
}
```

If OBS only shows a black screen, confirm `XDG_SESSION_TYPE=wayland`,
`xdg-desktop-portal-hyprland` is installed, and the capture source in OBS is "Screen
Capture (PipeWire)" - not "Screen Capture (X11)".

## PipeWire (audio, capture)

```nix
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;            # if you need JACK apps
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;  # ensure PA is off when PW is on
}
```

## Fonts

```nix
{
  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-cjk-sans noto-fonts-emoji
    liberation_ttf
    jetbrains-mono
    fira-code fira-code-symbols
  ];
  fonts.fontDir.enable = true;
}
```

## Input

```nix
{
  services.libinput.enable = true;
  services.libinput.touchpad.tapping = true;
  services.libinput.touchpad.naturalScrolling = true;

  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
}
```

## Bluetooth

```nix
{
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;   # GUI manager on non-GNOME/KDE
}
```

## Common mistakes

- Changing `boot.kernelPackages` on ZFS or NVIDIA systems without checking module
  availability in the new kernel. Out-of-tree modules lag.
- Editing `hardware-configuration.nix` by hand to tweak UUIDs. Regenerate instead.
- Forgetting `hardware.graphics.enable32Bit = true;` for Steam and 32-bit Vulkan.
- NVIDIA on Wayland without `modesetting.enable = true;`. The session may come up but
  compositors will struggle.
- Enabling PulseAudio *and* PipeWire's pulse shim at once. Disable PA explicitly.
- Importing a `nixos-hardware` laptop profile that does not match your exact SKU. Profiles
  are specific; the wrong one sets kernel params that break other SKUs.
