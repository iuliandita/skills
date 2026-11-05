# Kali administration

## Branches and repositories

Identify the intended lane and inspect active apt sources and `apt-cache policy` before repair. `kali-rolling` is the usual full distribution; `kali-last-snapshot` is the release-like alternative. Experimental and bleeding-edge repositories are partial, special-purpose sources, not interchangeable full lanes. Avoid mixing Debian suites or multiple full Kali branches. Check the archive keyring and signature errors before changing mirrors; back up sources and review changes before writing.

For package transitions, update metadata and simulate `apt-get -s full-upgrade`; review removals, held packages and service impact before authorizing the transaction. Verify the package and its binary afterwards. A metapackage may depend on a tool without owning its executable.

## Metapackages

Start with `kali-linux-default`, `kali-linux-headless`, or a focused `kali-tools-*` bundle. Inspect dependencies before installation. `kali-linux-everything` is large; reserve it for machines intended for the full collection. `kali-linux-labs` contains intentionally vulnerable training software for controlled environments only. `kali-tweaks` helps select metapackages and settings.

## Images, live boot and persistence

Choose installer, live, VM, ARM or cloud images for the actual environment and verify official checksums and signatures. A live session is not an installed root filesystem: check the selected boot entry, persistence partition and mount before assuming changes survive reboot. Back up data and confirm the target device before writing an image or altering partitions. Distinguish a damaged image, boot configuration and failing storage before recovery.

## Hardware and NetHunter

Check chipset, firmware, `rfkill`, `iw dev`, `lspci -k`, `lsusb` and VM passthrough before assuming a wireless package supports monitor mode or injection. Check GPU driver and host exposure for GPU workloads; USB power and permissions matter for peripherals. NetHunter depends on the Android device, kernel, USB and wireless capabilities; inspect the exact edition and supported hardware rather than treating it as desktop Kali.

## Common gotchas

Mixed branches, stale keyrings, unnecessary metapackages, nonpersistent live boots, missing passthrough and desktop-session failures can resemble broken tools. Diagnose those first. For authorized offensive work use **privilege-escalation** (opt-in; if installed); for novel vulnerability research use **vulnerability-research** (opt-in; if installed).
