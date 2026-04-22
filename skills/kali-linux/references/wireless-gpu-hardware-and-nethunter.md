# Kali Wireless, GPU, Hardware, and NetHunter Notes

A lot of Kali frustration is really hardware frustration.

## Wireless reality

Menu entries do not guarantee capability. Check the actual chipset, firmware, and connection path.

Core checks:
```bash
rfkill list 2>&1 || true
iw dev 2>&1 || true
lspci -k | grep -Ei 'network|wireless'
lsusb
journalctl -b | grep -Ei 'ath|iwlwifi|brcm|rtl|mt76' 2>&1 || true
command -v airmon-ng >/dev/null 2>&1 && airmon-ng 2>&1 || true
```

What usually breaks wireless workflows:
- unsupported chipset for monitor mode or injection
- missing firmware
- low USB power on small systems or hubs
- VM passthrough that exposes the device badly
- NetworkManager or another service holding the interface in the wrong mode

## SDR, Bluetooth, RFID, and USB gear

Kali has metapackages for SDR, Bluetooth, and RFID, but hardware still decides the truth.
Check:
- does the kernel see the device?
- does the user have access to the device node?
- did the package install the expected helper binaries?
- is USB passthrough stable if this is a VM?

## GPU and cracking workflows

For GPU-heavy tools such as `hashcat`, the key question is not "is Kali installed" but:
- does the GPU exist in this environment?
- is this bare metal or a VM?
- does the driver stack match the GPU?
- is the user asking for packaging help or actual cracking workflow?

If it is packaging and driver shape, stay here.
If it becomes offensive password-audit tradecraft on an authorized target, that intersects with
**lockpick**.

## GUI capture and desktop helpers

Desktop tools can fail because the session is broken, not because the security tool is broken.
Check:
```bash
echo "Session=$XDG_SESSION_TYPE Desktop=$XDG_CURRENT_DESKTOP"
command -v systemctl >/dev/null 2>&1 && systemctl --user status pipewire pipewire-pulse wireplumber xdg-desktop-portal 2>&1 || true
```

## NetHunter

NetHunter is not just Kali on a phone. It changes the answer because:
- the Android host and kernel matter
- HID support depends on the device and kernel
- wireless injection support is device-specific
- mobile storage and USB expectations differ from desktop Kali

Core check:
```bash
command -v nethunter >/dev/null 2>&1 && nethunter -h 2>&1 | head -20
```

When a NetHunter question becomes kernel porting or exploit technique, route to **lockpick** for
authorized offensive workflow. When it becomes original vulnerability discovery, reversing depth
work, or PoC development, route to **zero-day**. When it becomes defensive review of the target
system or code, route to **security-audit**.
