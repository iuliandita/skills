# Gotchas and Special Situations

Arch and CachyOS break in recurring, boring ways. Check these before inventing a new explanation.

## The biggest recurring gotchas

### Partial upgrades

Symptom pattern:

- one package install triggered a cascade of weird library or service failures
- symbols, sonames, or binaries no longer line up
- the user ran `pacman -Sy` earlier

What to do:

- stop treating the package as isolated
- move back to a full upgrade model
- check package integrity and journal output after sync state is corrected

### DKMS drift after kernel changes

Symptom pattern:

- NVIDIA, `v4l2loopback`, or another external module worked yesterday and vanished after a kernel move
- the package is installed, but the module is missing for the running kernel

What to do:

- confirm the running kernel first
- confirm the module exists for that kernel
- treat this as kernel-module drift before blaming the desktop, OBS, or Steam

Fast triage:

```bash
uname -r
dkms status
# If a module shows "added" but not "installed" for the running kernel:
sudo dkms install module_name/version -k "$(uname -r)"
```

### Portal mismatch on Wayland

Symptom pattern:

- screenshots, file pickers, screen sharing, or OBS capture break together
- the browser path and Electron path fail in similarly weird ways
- GNOME works but Hyprland does not

What to do:

- check session type
- check `xdg-desktop-portal` plus the compositor-specific backend
- check PipeWire and WirePlumber user services

### AUR package replaced by official repos

Symptom pattern:

- a package that used to be harmless from AUR now conflicts with repo packages
- updates start producing file conflicts or dependency weirdness

What to do:

- confirm whether the package should still be foreign
- stop treating old AUR choices as sacred
- prefer the official repo package when the project has been adopted upstream

### `.pacnew` drift

Symptom pattern:

- a service survives for a while, then fails after an unrelated update
- defaults changed upstream but local config never absorbed them

What to do:

- check `.pacnew` files before rewriting service logic
- compare local overrides with current package defaults

## Special situations worth recognizing fast

### Browser works, packaged client does not

This is common with Discord, Teams, and other Electron-style clients.

Interpretation:

- browser or PWA path working usually means the lower WebRTC, portal, and PipeWire stack is mostly fine
- the packaged client is then the more likely differentiator

What to do:

- use the browser result as a narrowing tool, not a random workaround

### GNOME works, Hyprland does not

Interpretation:

- the machine is probably not missing the entire multimedia stack
- the likely problem is session composition, portal wiring, or helper processes on Hyprland

What to do:

- inspect the Hyprland session path before touching system packages

### Rollback succeeded, boot still failed

Interpretation:

- root may have rolled back while `/boot`, UKIs, or bootloader artifacts did not

What to do:

- verify subvolume scope and boot artifact ownership before trusting the rollback story

### Suspend worked until a lock-screen change

Interpretation:

- the resume problem may be in the lock or idle path, not the kernel

What to do:

- separate GPU resume, lock helper, idle helper, and display manager behavior

### Controller problem only happens in one game

Interpretation:

- input may be fine system-wide
- the problem may be game mapping, Steam Input, or per-title config rather than Bluetooth or HID

What to do:

- prove whether input reaches the desktop and Steam before changing lower layers

## What to check first when...

| Situation | Check first |
|-----------|-------------|
| A package install broke unrelated things | partial upgrade state |
| Wayland screen share broke | portal backend and PipeWire user units |
| NVIDIA broke after update | running kernel and matching module path |
| OBS virtual camera vanished | `v4l2loopback` for the running kernel |
| Resume blackscreens only on Hyprland | `hyprlock`, `hypridle`, DPMS, GPU logs |
| Boot broke after rollback | `/boot`, UKI, and loader state |
| AUR package suddenly conflicts | whether it should still be from AUR |
| Bluetooth device shows in UI but not as audio or input | trust, connect, and actual PipeWire or input-node visibility |

## What NOT to do

- Do not assume every weird symptom is a brand-new Arch bug.
- Do not stack random fixes from five blog posts before checking the usual breakpoints.
- Do not blame Hyprland, systemd, or the kernel first when a helper layer is the more likely failure.
- Do not treat browser-vs-client differences as noise; they are often the most useful split you have.
