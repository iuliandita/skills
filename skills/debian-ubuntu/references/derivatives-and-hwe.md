# Derivatives and HWE

Use this for Ubuntu HWE, Ubuntu release upgrades, Mint, Pop!_OS, Devuan, Kali, and other
Debian-derived distro specifics that materially change package, boot, or service behavior.

## Checks
- `cat /etc/os-release`
- `lsb_release -a 2>&1 || true`
- `uname -r`
- `apt-cache policy linux-generic linux-generic-hwe 2>&1 || true`
- `apt-cache policy 2>&1 | sed -n '1,40p'`
- `ps -p 1 -o comm=`
- `command -v systemctl >/dev/null 2>&1 && systemctl --version`
- `command -v do-release-upgrade >/dev/null 2>&1 && do-release-upgrade --help | head -20`
- `command -v ubuntu-drivers >/dev/null 2>&1 && ubuntu-drivers devices`
- `command -v apt-mark >/dev/null 2>&1 && apt-mark showhold`

## Distro notes

### Debian stable
- Default to conservative package movement and explicit pinning when any non-stable lane appears.
- Prefer backports over casual mixing with testing or sid.

### Debian testing
- Treat testing as a moving target with fewer Debian-specific safety rails than stable.
- Before recommending fixes, check whether the issue is a transient testing transition rather than a local host problem.

### Debian unstable (sid)
- Treat sid as high-churn and breakage-prone by design.
- Be stricter about package origin, pinning, and transition awareness than on stable.

### Ubuntu LTS
- Current LTS baseline is Ubuntu 26.04 LTS (Resolute Raccoon).
- Common upgrade sources are Ubuntu 24.04 LTS and Ubuntu 25.10.
- HWE changes the kernel lane. Check whether the host tracks `linux-generic` or `linux-generic-hwe`.
- PPAs, snaps, and AppArmor are normal parts of the troubleshooting surface here.

### Ubuntu interim
- Treat interim releases as short-lived stepping stones, not a long-term server baseline.
- Before advising upgrades, check release support status and the documented path into the current LTS.

### Ubuntu flavors
- Kubuntu, Xubuntu, Lubuntu, Ubuntu Budgie, and similar flavors still fit this skill when the issue is ordinary apt, boot, kernel, or base service administration.
- Desktop-session advice must follow the actual flavor stack instead of assuming GNOME defaults.

### Linux Mint
- Mint follows Ubuntu LTS closely but adds its own update tooling and desktop defaults.
- Cinnamon and Mint tooling can shift the desktop/session troubleshooting path even when apt behavior is standard Ubuntu underneath.
- Prefer checking Mint-managed update state before assuming a pure Ubuntu workflow.

### Pop!_OS
- Pop!_OS layers System76 firmware, power, graphics, and recovery behavior on top of Ubuntu.
- Confirm whether the issue is ordinary Ubuntu package behavior or a System76-specific layer such as firmware, graphics switching, or COSMIC components.
- NVIDIA guidance may differ because Pop images and vendor tooling shape the baseline.

### Devuan
- Devuan is the big service-management exception in this family.
- Do not assume systemd, `systemctl`, `journalctl`, or Ubuntu-style desktop-session plumbing.
- Check PID 1, installed init packages, and the actual service-management stack before prescribing commands.
- For Devuan, package and repository advice may still be Debian-like while service and boot workflows diverge sharply.

### Kali
- Kali is Debian-derived, so apt, dpkg, boot, and kernel basics can still fit this skill.
- Do not treat Kali like a generic desktop or server distro when the question is really about offensive tooling, lab images, or pentest workflow. That should move to a dedicated Kali skill later.
- Be conservative with desktop and hardening assumptions because Kali images, package sets, and intended use differ from stock Debian.

### Other Debian-based distros
- Explicitly confirm repo model, release base, and service stack first.
- This bucket can include Zorin OS, elementary OS, and MX Linux, but only if the underlying issue is still ordinary apt, boot, or service administration.
- If the distro's identity changes the package manager, service stack, or operating model, stop pretending it is just Ubuntu with a different wallpaper.

## What is out of scope
- RPM-family distros such as RHEL, Fedora, Rocky, AlmaLinux, Oracle Linux, and Amazon Linux
- NixOS and declarative system-management workflows
- Kali offensive tooling, exploit workflow, lab-image conventions, or training-specific behavior

## Notes
- Ubuntu HWE changes the kernel lane.
- Mint follows Ubuntu LTS and adds its own update tooling.
- Pop!_OS adds System76 firmware and power behavior.
- Devuan may break systemd assumptions outright.
- Kali is only a partial fit here for base OS administration, not for security-distro workflow.
