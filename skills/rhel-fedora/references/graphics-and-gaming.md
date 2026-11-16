# Graphics and Gaming

Use this reference for NVIDIA, AMD, Intel, Vulkan, Steam, Proton, Gamescope, MangoHud, RPM Fusion
NVIDIA akmods, Secure Boot module signing, and driver or kernel-lane mismatches.

## Contents

- First-pass commands
- Notes
- RPM Fusion NVIDIA: what gets installed
- Secure Boot: enroll the signing key first
- Install the driver
- Verify the module built and loaded

## First-pass commands

```bash
lspci -k | grep -Ei 'vga|3d|display'
lsmod | grep -E 'nvidia|nouveau|amdgpu|i915|xe' 2>&1 || true
journalctl -b | grep -Ei 'nvrm|nvidia|amdgpu|i915|xe|drm' 2>&1 || true
vulkaninfo --summary 2>&1 || true
rpm -qa | grep -Ei 'mesa|nvidia|akmod|kmod|vulkan|steam|gamescope|mangohud' | sort
dnf repolist --enabled 2>&1 | grep -i rpmfusion || true
mokutil --sb-state 2>&1 || true
```

## Notes

- Fedora NVIDIA and gaming setups often hinge on RPM Fusion state, akmods, Secure Boot, and matching kernel headers.
- Enterprise clones may use DKMS or vendor repos instead of Fedora-style akmods.
- Oracle UEK vs RHCK can change out-of-tree module behavior.
- Steam and Proton still need 32-bit userspace on many setups.
- Gamescope and MangoHud are useful tests, but also extra moving parts.

## RPM Fusion NVIDIA: what gets installed

- An akmod is a source package that rebuilds its kernel module locally when a kernel arrives
  without one; it needs a compiler and the matching `kernel-devel`. The build runs after the RPM
  transaction and at boot, and can take several minutes.
- Fedora uses `akmod-nvidia` from the RPM Fusion nonfree repository. On RHEL and compatible
  rebuilds RPM Fusion points to the prebuilt `kmod-nvidia` instead, and needs EPEL plus
  CodeReady Builder (RHEL) or CRB (clones) enabled first.
- The default `akmod-nvidia` follows NVIDIA's current branch, which RPM Fusion documents as having
  dropped older GPUs from Fedora 44 on. It lists Maxwell and Pascal cards under
  `akmod-nvidia-580xx` with `xorg-x11-drv-nvidia-580xx`, and Kepler cards under the `470xx` pair.
  Check the card against NVIDIA's supported-chips list before picking a branch.

## Secure Boot: enroll the signing key first

With Secure Boot on, the kernel refuses unsigned modules. akmods (Fedora 36 and later) signs what
it builds with a local key, and that key must be enrolled as a Machine Owner Key (MOK). RPM Fusion
is explicit that this happens before the driver is installed; otherwise the module is rejected
and the next boot can end at a blank screen.

Read-only state:

```bash
mokutil --sb-state
ls -l /etc/pki/akmods/certs/ /etc/pki/akmods/private/ 2>&1 || true
mokutil --list-new 2>&1 || true                                    # keys queued for enrollment
mokutil --test-key /etc/pki/akmods/certs/public_key.der 2>&1 || true
```

Enrollment is consequential: it adds a key the firmware will trust for kernel modules, and it
needs someone at the console on the next boot. Show these steps and get confirmation first. Do
not start it on a remote host with no console access.

```bash
sudo dnf install kmodtool akmods mokutil openssl
sudo kmodgenca -a          # generate the key pair with defaults; exits if one exists, -f overwrites
sudo mokutil --import /etc/pki/akmods/certs/public_key.der   # asks for a one-time password
systemctl reboot
```

At the next boot the MOK Management screen appears: choose "Enroll MOK", "Continue", "Yes", and
type the password. That screen uses a QWERTY layout whatever the system keymap is, so choose a
password that types the same on both. Afterwards `mokutil --test-key` on the certificate and
`mokutil --list-enrolled` confirm the key is in.

- The private key in `/etc/pki/akmods/private/` can sign modules this machine will load. Keep it
  root-only; RPM Fusion recommends an encrypted root filesystem or moving the key off the machine.
- A firmware update or a Secure Boot key reset can drop the MOK. Repeat the `--import` step.
- Disabling Secure Boot instead is a security downgrade; only on the user's explicit choice.

## Install the driver

Adding RPM Fusion is a third-party repository change, and the install pulls a kernel module, so
both are consequential: show the DNF transaction and get confirmation. On Fedora:

```bash
sudo dnf install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf upgrade --refresh              # reboot first if this installed a new kernel
sudo dnf install akmod-nvidia
sudo dnf install xorg-x11-drv-nvidia-cuda   # optional: CUDA, NVENC/NVDEC, nvidia-smi
```

RPM Fusion's own RHEL-family commands pass `--nogpgcheck` for the release packages. Do not copy
that silently: say so, and verify the release package and its key against RPM Fusion's published
keys as [packages and repos](packages-and-repos.md) describes for any release RPM.

`dnf autoremove` can remove `akmod-nvidia` as unneeded. Mark it: `sudo dnf mark user akmod-nvidia`
on DNF 5 (Fedora 41 and later), `sudo dnf mark install akmod-nvidia` on older DNF.

## Verify the module built and loaded

Wait for the build, then check before rebooting:

```bash
modinfo -F version nvidia                      # a version means it built for the running kernel
rpm -q kernel-core                             # installed kernels
modinfo -F version nvidia -k <kernel-release>  # same check for a kernel that is not running
systemctl status akmods.service 2>&1 || true
journalctl -b -u akmods.service 2>&1 | tail -n 30 || true
ls /var/cache/akmods/ 2>&1 || true
```

`modinfo: ERROR: Module nvidia not found` means the build has not finished or has failed. Use the
`-k` form when the newest installed kernel is not the running one. After a full reboot:

```bash
lsmod | grep -E '^nvidia'
lsmod | grep nouveau                           # expect no output once nvidia is in use
journalctl -k -b | grep -Ei 'nvidia|nvrm|module verification|lockdown' 2>&1 || true
nvidia-smi 2>&1 || true                        # needs the -cuda package
```

If the module is missing for a kernel, rebuild it. This compiles and installs a module, so confirm
first, and name the kernel explicitly:

```bash
rpm -q "kernel-devel-$(uname -r)"              # the build needs headers for that exact kernel
sudo akmods --force --kernels "$(uname -r)"    # retry even if an earlier attempt failed
```

- Built but not loaded with Secure Boot on is a signing problem: recheck `mokutil --test-key`.
- Built and loaded but a black screen is a display-stack problem; RPM Fusion says not to add
  `nvidia-drm.modeset=1` to the kernel command line on current packages.
- To back out, RPM Fusion's documented removal is `sudo dnf remove xorg-x11-drv-nvidia\*`. Show
  the removal list first.
