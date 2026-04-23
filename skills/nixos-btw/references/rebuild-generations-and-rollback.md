# nixos-rebuild, generations, and rollback

Every `nixos-rebuild switch` produces a **generation**: an immutable snapshot in
`/nix/var/nix/profiles/system-<N>-link`. Previous generations stay around until GC. This is
the whole safety model.

## Rebuild verbs

| Verb | Builds | Activates now | Adds boot entry | Use when |
|------|--------|---------------|-----------------|----------|
| `build` | yes | no | no | CI or dry-run without touching the system |
| `dry-activate` | yes | no | no | preview what would change on activation |
| `test` | yes | yes | **no** | risky change; reboot returns to previous gen |
| `switch` | yes | yes | yes | standard apply |
| `boot` | yes | no | yes | apply on next boot (good for remote work) |
| `build-vm` | yes | no | no | build a QEMU VM you can `run` to test |
| `build-vm-with-bootloader` | yes | no | no | same, with bootloader |

`test` is the underused verb. A bad login manager config in `test` mode survives a reboot;
in `switch` mode it does not.

### Flake forms

```bash
sudo nixos-rebuild switch --flake /etc/nixos#box
sudo nixos-rebuild test --flake .#box --show-trace
sudo nixos-rebuild boot --flake .#box --target-host root@other  # remote build on local
sudo nixos-rebuild switch --flake .#box --build-host builder.lan
```

### nixos-rebuild-ng

NixOS 25.11 made **`nixos-rebuild-ng`** the default. It is a Python rewrite of
`nixos-rebuild` with the same verbs and flags. Older guides reference the Perl version; the
behavior is the same for 95% of workflows, but internal tracing and some edge flags differ.

## Useful flags

```bash
--show-trace               # full Nix eval trace on error
--print-build-logs         # stream builder stdout/stderr live
--keep-going               # continue after a failed derivation
--cores 4                  # parallelism per build
--max-jobs 2               # parallel derivations
--no-reexec                # do not reexec into the new nixos-rebuild
--rollback                 # revert to previous generation (then reboot for boot changes)
--upgrade                  # bump channels before rebuild (channels only)
--fast                     # skip nix channel update and some sanity checks
--target-host user@host    # deploy to a remote machine (SSH)
--build-host user@host     # build on a remote, activate locally
```

## Generations

List system generations:

```bash
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
```

User profile generations (per `$USER`):

```bash
nix-env --list-generations
```

Switch to a specific generation (activation; reboot for bootloader changes):

```bash
sudo nix-env --switch-generation 42 -p /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Roll back to the previous generation:

```bash
sudo nixos-rebuild switch --rollback
```

Delete old generations (but keep the current one and its immediate predecessor):

```bash
sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system
sudo nix-collect-garbage -d   # also removes unreachable store paths
```

## Boot entries

Every generation produces a boot entry. Bootloader varies:

- **systemd-boot** (default for UEFI installs): entries in `/boot/loader/entries/*.conf`.
  `sudo bootctl status` shows what is active and what is known.
- **GRUB**: entries regenerated on every rebuild; Nix manages them.
- **EFI / UKI**: UKIs produced on newer setups bake kernel+initrd together.

Do not hand-edit entries. They regenerate on every rebuild.

Limit the number of visible boot entries:

```nix
boot.loader.systemd-boot.configurationLimit = 20;
boot.loader.grub.configurationLimit = 20;
```

GC does not remove the entries themselves until the underlying generation is gone.

## Rollback flow when things break

From a running system:

```bash
sudo nixos-rebuild switch --rollback
```

From the bootloader menu at boot time: pick a previous entry. The menu shows timestamps and
kernel versions. Boot one, then `nixos-rebuild switch --rollback` from userspace to persist.

From a rescue shell (single-user or initramfs emergency):

```bash
# Find the generation
ls -l /nix/var/nix/profiles/
# Activate it manually
/nix/var/nix/profiles/system-41-link/bin/switch-to-configuration boot
reboot
```

## `dry-activate` before big changes

```bash
sudo nixos-rebuild dry-activate --flake .#box
```

Prints the activation steps that **would** run: units that start/stop, users that change,
file tree changes. No reboot, no switch. Cheap to run; expensive to skip before a change
that touches login, users, or SSH.

## build-vm

Builds a QEMU VM booting the exact config you are about to switch to:

```bash
nixos-rebuild build-vm --flake .#box
./result/bin/run-box-vm
```

Great for testing login manager changes, new users, or boot-level tweaks without
risking the actual host.

## Remote deploys

`--target-host` and `--build-host` let you build locally and apply remotely:

```bash
sudo nixos-rebuild switch \
  --flake .#prod \
  --target-host root@prod.lan \
  --build-host localhost
```

For fleet-level deploys, consider tools built on top: `deploy-rs`, `colmena`, or `nixops4`.

## Common mistakes

- Running `nix-collect-garbage -d` immediately after a switch and before a reboot confirms
  the new generation works. Keep at least the last known-good generation.
- Using `switch` for changes you suspect might break login. `test` is safer; a reboot
  recovers the last switched generation.
- Confusing `nixos-rebuild --rollback` with `switch-to-configuration`. The former goes back
  one generation; the latter activates a specific generation you name.
- Hand-editing `/boot/loader/entries/*.conf`. Regenerated on every rebuild.
- Forgetting to commit `flake.nix` and `flake.lock` before a flake-based rebuild. The pure
  sandbox only sees tracked files.
