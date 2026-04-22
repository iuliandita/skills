# Kali Gotchas and Special Situations

The boring failures win a lot.

## Common failure patterns

### Branch drift
The user thinks they are on normal rolling, but sources show snapshot or partial branches too.
Result: dependency weirdness and package confusion.

### Stale keyring
Repo metadata errors look dramatic, but the fix starts with trust material and package state, not
random mirror hopping.

### Metapackage regret
The machine is slow, crowded, and messy because someone installed `kali-linux-everything` on a
small VM when they really needed one or two focused bundles.

### Live persistence drift
The user swears settings are saved, but the boot entry or persistence mount says otherwise.

### VM passthrough lies
The package is installed, the command exists, but the Wi-Fi adapter, SDR, or USB debugger never
reaches the guest correctly.

### Unsupported wireless expectations
The adapter can connect to Wi-Fi but cannot do monitor mode or injection. Kali is not the thing
lying; the chipset marketing probably is.

### Desktop-session blame
Burp, Wireshark helpers, browser tooling, or capture workflows look broken when the real issue is
session plumbing, PipeWire, portals, or the hypervisor display stack.

## Triage shortcuts

```bash
apt-cache policy 2>&1 || true
grep -Rhv '^#\|^$' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>&1 || true
dpkg -l | grep '^ii  kali-' | head -30
findmnt | grep -Ei 'live|overlay|persistence' 2>&1 || true
rfkill list 2>&1 || true
iw dev 2>&1 || true
lsusb
```

## Decision rule

If the problem can be explained by branch state, image type, persistence, passthrough, firmware,
or chipset support, explain that first. Only move to exotic theories after the basic story is
clean.
