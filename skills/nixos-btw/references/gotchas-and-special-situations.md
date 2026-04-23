# Recurring NixOS and Nix gotchas

The failures that explain most "why is this broken?" sessions. Work through the top of the
list first; exotic causes come after the boring ones are ruled out.

## Channels vs flakes drift

Symptom: `nixos-rebuild switch` uses an older `nixpkgs` than the user expects, or vice
versa.

Cause: the system is on channels but the user thinks they are on flakes, or `flake.nix`
exists but `nixos-rebuild` is run without `--flake`.

Fix:
- Confirm by `cat /etc/nixos/flake.nix` and `nix-channel --list`.
- If flakes: always use `nixos-rebuild --flake .#host`.
- If channels: `sudo nix-channel --update` before rebuild.
- Do not run both paths on the same machine unless you know why.

## Stale flake.lock

Symptom: upstream shipped a fix; a rebuild still produces the old behavior.

Cause: `flake.lock` pins the input at the old rev.

Fix:
```bash
nix flake update                               # update all inputs
nix flake lock --update-input nixpkgs          # just one
nix flake metadata                             # confirm revs
```

Commit the lock change in its own commit.

## `nix-env -i` polluting the user profile

Symptom: a tool is installed, it works, but it does not appear in `configuration.nix` and
survives `nixos-rebuild switch --rollback`.

Cause: `nix-env -i` installs into `~/.nix-profile`, which is separate state from system
generations.

Fix:
```bash
nix-env -q                       # what is there
nix-env -e '*'                   # wipe the user profile
# Then add the packages to environment.systemPackages or home.packages.
```

## Options that no longer exist

Symptom: `error: The option 'services.foo.bar' does not exist.`

Cause: option was renamed or removed between NixOS releases.

Fix:
```bash
# Search the current release
nix repl
> :lf nixpkgs
> options.services.foo.<TAB>

# Check release notes for renames
# https://nixos.org/manual/nixos/stable/release-notes.html
```

Many renames provide a deprecation warning for one release, then fail outright in the next.

## Overlay collision

Symptom: two overlays both redefine the same package; the second wins but silently, and the
first overlay's intent is lost.

Cause: overlays run left-to-right. A later overlay's `final: prev: { pkg = ... }` replaces
earlier definitions unless it composes via `prev.pkg`.

Fix: if both overlays should layer, call `prev.pkg.overrideAttrs` in the later overlay so
it sees the earlier changes.

## `hardware-configuration.nix` out of sync

Symptom: after moving a disk, rebuilding with a new SSD, or switching filesystems, the
system boots to emergency shell or cannot find root.

Fix:
```bash
sudo nixos-generate-config --root /   # regenerates hardware-configuration.nix
```

Never hand-edit UUIDs in `hardware-configuration.nix`. Regenerate.

## Kernel swap killed out-of-tree modules

Symptom: after `boot.kernelPackages = pkgs.linuxPackages_latest;`, NVIDIA or ZFS fails.

Cause: the new kernel's module set in nixpkgs does not include (yet) a build for NVIDIA or
ZFS.

Fix:
- Roll back the generation.
- Pin to `linuxPackages_<version>` that has module coverage.
- For ZFS, use `boot.zfs.package.latestCompatibleLinuxPackages` as a safer source (the attribute path has moved across releases - verify with `nix repl` against your nixpkgs tag).

## GC nuked a dev shell

Symptom: `direnv reload` triggers a long rebuild of a previously cached shell.

Cause: `nix-collect-garbage -d` removed paths whose GC root had been cleaned (e.g., the
`.direnv/` symlinks rotated or the `result` symlink got deleted).

Fix:
- Re-enter the shell; it rebuilds or re-fetches.
- For projects you care about, keep the dev shell registered: `nix develop --profile
  .direnv/nix-profile` or rely on `nix-direnv` which registers GC roots under `.direnv/`.

## `--impure` creep

Symptom: something only builds with `--impure`. A week later, five commands need it.

Cause: the config is reading env vars, `NIX_PATH`, or host files that flakes' pure eval
disallows.

Fix:
- Identify the impure read; move its value into `specialArgs` or a flake input.
- For unfree packages, set `nixpkgs.config.allowUnfree = true;` rather than relying on
  `NIXPKGS_ALLOW_UNFREE=1 nix ... --impure`.

## Secrets ended up in the store

Symptom: `/nix/store/<hash>-config.json` contains a password in plaintext.

Cause: `environment.etc."foo.json".text = ''{...}''` with a secret interpolated, or
`builtins.readFile ./secret.txt`.

Fix:
- Rotate the secret immediately.
- Move to sops-nix or agenix; reference `config.sops.secrets.<name>.path` instead of
  interpolating the value.

## `nix flake check` passes, `nixos-rebuild` fails

Symptom: flake check green, rebuild red.

Cause: `nix flake check` builds default system outputs but may skip complex targets; or a
system-level activation script fails at `switch-to-configuration`, not at build.

Fix:
- Run `nixos-rebuild dry-activate --flake .#host --show-trace` to see the activation step.
- Inspect `journalctl -b` from a previous attempt for failing systemd units.

## systemd-boot entry spam

Symptom: the bootloader menu has 50 entries.

Fix:
```nix
boot.loader.systemd-boot.configurationLimit = 20;
```

Then `sudo nix-collect-garbage -d` removes the underlying generations and their entries.

## `sops-nix` or `agenix` not decrypting on first boot

Symptom: services that need a secret fail to start.

Cause: the host's age key is missing (first install) or the secret was not re-keyed after
a host key rotation.

Fix:
- Confirm `/etc/ssh/ssh_host_ed25519_key` exists.
- `sops updatekeys` or `agenix -r` if keys rotated.
- Verify the decrypted file appears in `/run/secrets/<name>` or `/run/agenix/<name>`
  after activation.

## Determinate `nix-daemon` commands fail

Symptom: `systemctl restart nix-daemon` says "unit not found" on a Determinate install.

Cause: the daemon is `determinate-nixd`, not `nix-daemon`.

Fix:
```bash
sudo systemctl restart determinate-nixd
determinate-nixd status
```

## Home-manager file already exists

Symptom: `home-manager switch` fails with "cannot overwrite existing file".

Cause: a real file exists at a path home-manager wants to manage.

Fix:
- Set `home-manager.backupFileExtension = "hm-bak";` (NixOS module) to auto-backup.
- Or delete the conflicting file and rerun.

## nix-darwin: macOS defaults not applied

Symptom: `system.defaults.dock.autohide = true;` set, but Dock still shows.

Fix:
- Run `killall Dock` or log out and back in; some defaults need the consuming service
  restart.
- Confirm `darwin-rebuild switch` (not `nixos-rebuild`) ran and reported success.
- Some settings are per-user; scope to the right `users.users.<name>` block.

## Rebuild succeeds, service fails to start

Symptom: build green, boot entry created, unit crashes post-activation.

Fix:
```bash
journalctl -u <unit> -b --no-pager | tail -100
systemd-analyze verify /etc/systemd/system/<unit>.service 2>&1 || true
```

Common causes: missing env var, wrong user, read-only filesystem assumption, service
running in sandbox that blocks a path.

## Cache miss cascade

Symptom: every rebuild is slow; builds from source that you thought would substitute.

Cause: a substituter is unreachable, a public key is missing, or the user is a non-trusted
user invoking builds the daemon cannot substitute.

Fix:
```bash
nix config show | grep -E 'substituters|trusted'
curl -sSf https://cache.nixos.org/nix-cache-info | head
nix store ping --store https://cache.nixos.org
```

Add the user to `nix.settings.trusted-users` if they run flakes with untrusted
substituters.

## Things that look broken but are not

- `/etc/resolv.conf` is a symlink into `/run/NetworkManager/...` or systemd-resolved. Do
  not hand-edit; configure via the NixOS module instead.
- `/home/<user>` not owned by the user after adding them to `configuration.nix` - user
  creation copies default files; home contents still need migration from the previous
  user.
- `ls /etc` looks sparse compared to other distros. Most `/etc` paths are symlinks into
  `/nix/store`.
- `sudo` asks for your password even after editing sudoers in Nix - it works, `/etc/sudoers`
  is regenerated each rebuild.
