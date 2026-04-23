# Disko, impermanence, nixos-anywhere, and imaging

NixOS can own the disk layout, the persistence model, and the install process
declaratively. This reference covers disko (declarative partitioning), impermanence
(root-on-tmpfs), nixos-anywhere (remote install over SSH), and image generators.

## disko

[disko](https://github.com/nix-community/disko) describes disks as a Nix expression and
applies them via a single command. Replaces the imperative `parted`/`mkfs` dance.

### Minimal LUKS + btrfs example

```nix
# disko-config.nix
{ ... }:

{
  disko.devices = {
    disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-L" "nixos" ];
                subvolumes = {
                  "/root"     = { mountpoint = "/";      mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/home"     = { mountpoint = "/home";  mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/nix"      = { mountpoint = "/nix";   mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/persist"  = { mountpoint = "/persist"; mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/log"      = { mountpoint = "/var/log"; mountOptions = [ "compress=zstd" "noatime" ]; };
                };
              };
            };
          };
        };
      };
    };
  };
}
```

### Apply on a live ISO

```bash
# from a NixOS installer or live image
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake .#box
nixos-install --flake .#box
reboot
```

`--mode destroy,format,mount` wipes and applies; use `--mode mount` for re-mount-only after
an existing disk is already formatted to disko spec.

Wire the disko config into the NixOS config:

```nix
# flake.nix
nixosConfigurations.box = nixpkgs.lib.nixosSystem {
  modules = [
    disko.nixosModules.disko
    ./disko-config.nix
    ./configuration.nix
  ];
};
```

## Impermanence

Root-on-tmpfs: wipe `/` on every boot, keep only what you explicitly persist. Makes the
system stateless-by-default, forces state to be declared.

Two popular approaches:

1. **tmpfs root** - `/` is `tmpfs`; every boot starts clean. `/nix` and `/persist` are real
   filesystems that survive.
2. **btrfs snapshot-on-boot** - `/` is a real btrfs subvolume, wiped to a blank snapshot at
   boot by an early-stage unit. Survives more gracefully when things go wrong mid-boot.

### btrfs snapshot-wipe example

```nix
# early in initrd
boot.initrd.postDeviceCommands = lib.mkAfter ''
  mkdir -p /mnt
  mount -o subvol=/ /dev/mapper/cryptroot /mnt
  btrfs subvolume list -o /mnt/root | cut -f9 -d' ' | \
    while read sub; do btrfs subvolume delete "/mnt/$sub"; done
  btrfs subvolume delete /mnt/root
  btrfs subvolume snapshot /mnt/root-blank /mnt/root
  umount /mnt
'';
```

(Create `/root-blank` once after the first install:
`btrfs subvolume snapshot -r /mnt/root /mnt/root-blank`.)

### impermanence module

[nix-community/impermanence](https://github.com/nix-community/impermanence) declares which
directories and files must persist across the wipe:

```nix
{
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/log"
      { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.alice = {
      directories = [ ".ssh" ".config/foo" "Documents" "Downloads" ];
      files = [ ".zsh_history" ];
    };
  };
}
```

### What to persist

- SSH host keys (else clients get a key-change warning every boot)
- Machine ID (`/etc/machine-id` - some systemd services key off it)
- Network state if NetworkManager
- Bluetooth pairings
- Printer config if CUPS/colord is used
- User home bits that actually need to persist

### Gotchas

- Forgetting to persist SSH host keys makes every boot look like a MITM from the client
  side. Persist them or regenerate and redistribute.
- TimeSync state on fresh boot: `/var/lib/systemd/timers` and `/var/lib/chrony` may need to
  persist.
- docker / podman state under `/var/lib/docker` - persist if containers matter.
- Persist too much and you lose the point; persist too little and apps break every boot.

## nixos-anywhere

Installs NixOS on a remote machine over SSH, including disk formatting via disko.

**Preconditions:**

1. Target booted into something with SSH access (vendor rescue, live ISO, or an existing
   Linux) and `kexec` available - nixos-anywhere reboots into a kexec'd installer.
2. Flake wired with `disko.nixosModules.disko`, a `./disko-config.nix` matching the target
   disk, and a working `nixosConfigurations.<host>`.
3. SSH reachability from workstation to target with a key that reaches root (directly or
   via `sudo`). Local `.ssh/config` entry saves typing.

Then:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#box \
  --target-host root@1.2.3.4
```

What it does:

1. SSHes in, boots the remote into a kexec'd NixOS installer
2. Runs disko to partition and format
3. Runs `nixos-install` with the flake
4. Reboots into the new system

Cheap replace-in-place for cloud hosts, VPS, or bare metal with kexec support. Pair with
sops-nix or agenix so secrets land on first boot.

### When to use

- Cloud VMs where disko controls the layout
- Bare metal with remote KVM access, kexec available
- Fleet installs driven by CI

### When not to use

- Machines without kexec support
- Windows-booted machines you cannot safely wipe
- First time with disko; iterate locally in a VM first

## Image generators

[nixos-generators](https://github.com/nix-community/nixos-generators) builds a single
system image for a target format:

```bash
nix run github:nix-community/nixos-generators -- \
  --format iso \
  --configuration ./configuration.nix \
  --out-link result
```

Common formats:

| Format | Output | Use |
|--------|--------|-----|
| `iso` | live ISO | install media, rescue |
| `sd-aarch64` | raw SD image | Raspberry Pi |
| `qcow` | QEMU qcow2 | libvirt VMs |
| `virtualbox` | OVA | VirtualBox |
| `vmware` | VMDK | VMware |
| `amazon` | AMI | EC2 |
| `gce` | tarball | GCE |
| `azure` | VHD | Azure |
| `docker` | image | containers |
| `install-iso` | installer ISO with custom config | one-shot installs |

### SD images for ARM

```bash
nix build ./#nixosConfigurations.rpi4.config.system.build.sdImage
zstd -d result/sd-image/nixos-sd-image-*.img.zst
sudo dd if=nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Docker images from Nix

`dockerTools.buildLayeredImage` produces an OCI tarball with minimal layers:

```nix
{ pkgs, ... }:

pkgs.dockerTools.buildLayeredImage {
  name = "my-app";
  tag = "latest";
  contents = [ pkgs.cacert pkgs.myApp ];
  config = {
    Cmd = [ "/bin/my-app" ];
    ExposedPorts."8080/tcp" = {};
  };
}
```

`nix build .#dockerImage && docker load < result` uploads it into your local daemon. For
K8s or registry use, push the tarball directly.

## Common mistakes

- Running disko on the wrong device. Double-check `lsblk` and device names before running
  with `--mode destroy`.
- Impermanence without persisting SSH host keys - breaks client trust.
- Impermanence persisting `/var` wholesale - defeats the point; persist specific paths.
- nixos-anywhere on a machine without kexec support - it fails at step one.
- Image generators silently producing a working image with stale inputs because flakes were
  not committed. Commit before building.
- Building a Docker image from Nix but forgetting `cacert` in `contents` - the container
  then cannot validate TLS.
