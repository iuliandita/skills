# Base Linux and CLI

This skill is Arch-first, not a generic Linux textbook, but it still needs a useful shared baseline
for routine host inspection and day-to-day recovery work.

## Core commands worth reaching for first

### Logs and services

- `journalctl` for system and user logs
- `dmesg` for kernel and driver errors
- `systemctl` for services, timers, sockets, and unit state
- `loginctl` for session ownership and seat state

### Package and Arch-specific state

- `pacman -Q`, `pacman -Qm`, and `pacman -Qk` for package state
- `pacman -Qo` to map a file back to its owning package
- `pkgfile` to find which repo package provides a missing file

### Storage and filesystem reality

- `lsblk` and `findmnt` for storage and mount reality
- `blkid` for filesystem and UUID facts
- `df -h` and `du -sh` for space usage
- `file`, `stat`, and `readlink -f` for "what is this path, really?"

### Processes and resources

- `ps`, `top`, and `uptime` for quick process and load checks
- `free -h` for memory pressure

### Hardware and kernel routing

- `lspci -k` and `lsusb` for device routing
- `lsmod` and `modinfo` for kernel module state
- `udevadm info` when device naming or permissions look wrong

### Quick network reality

- `ip -br a` for interface state
- `ss -tulpn` for listening sockets

Use those for host inspection. If the task turns into real DNS, routing, VPN, firewall, or proxy
work, switch to **networking**.

These are the default layer before random tweaks, wiki fragments, or helper scripts.

## Optional packages worth having on Arch

These are useful because they reduce friction, not because they change how the system works.

### Editing and parsing

- `neovim` for editing
- `jq` for JSON inspection

### Search and navigation

- `ripgrep` for fast text search
- `fd` for friendlier file discovery
- `fzf` for fuzzy selection in interactive workflows
- `bat` for readable file inspection
- `eza` for modern file listing

### Resource and disk inspection

- `btop` or `bottom` for interactive process and resource views
- `ncdu` or `dust` for disk-usage triage

### Arch-specific quality-of-life

- `pkgfile` for "which package provides this binary or path?"

Because Arch is rolling, do not pin versions for these unless a breaking change actually matters.
What matters here is that the package exists in the official repos and fits the workflow.

## Suggested stance

- Use plain tools first when debugging a broken system.
- Add quality-of-life tools on healthy systems or when the task is clearly interactive administration.
- If a helper tool is missing, degrade to the boring base command instead of blocking the workflow.

## Example fallbacks

```bash
pkgfile bin/lsblk 2>/dev/null || pacman -Qo /usr/bin/lsblk
bat /etc/pacman.conf 2>/dev/null || cat /etc/pacman.conf
eza -la 2>/dev/null || ls -la
fd fstab /etc 2>/dev/null || find /etc -name '*fstab*'
```

## What NOT to do

- Do not require optional CLI tools for core recovery steps.
- Do not turn every Arch answer into a dotfiles or editor preference discussion.
- Do not confuse "nicer output" with better diagnosis.
- Do not let quick `ip` or `ss` checks grow into a networking deep dive inside this reference.
