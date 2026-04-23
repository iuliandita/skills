# Determinate Nix, Lix, and lanes

Three Nix CLI/daemon implementations coexist: upstream Nix (NixOS/nix), Determinate Nix
(DeterminateSystems/nix), and Lix (lix-project/lix). They are API-compatible for most
workflows but diverge at the edges. Name the lane before suggesting daemon flags, daemon
service names, or CLI behaviors that differ.

## Upstream Nix

- Repo: [NixOS/nix](https://github.com/NixOS/nix)
- Maintainers: NixOS Foundation contributors
- Flakes: behind `experimental-features = nix-command flakes`
- Latest stable: 2.33 (Dec 2025), 2.32 (Oct 2025)
- Release cadence: roughly 6 weeks

This is what ships in `nixos` for every standard NixOS release.

## Determinate Nix

- Repo: [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer)
- Docs: [docs.determinate.systems](https://docs.determinate.systems/determinate-nix/)
- Downstream distribution of upstream Nix with validated backports and feature work
- Flakes and `nix-command` enabled by default
- Daemon: `determinate-nixd` (not `nix-daemon`)
- Features: parallel evaluation, lazy trees, native Linux builder for macOS
- SOC 2 Type II-validated release process; defined CVE process

Install path: Determinate Installer. Works on Linux, macOS, and WSL. On NixOS, you
typically do not swap the in-system Nix for Determinate; Determinate shines on non-NixOS
hosts and developer machines.

### Determinate-specific commands

```bash
determinate-nixd status           # daemon health
determinate-nixd version
determinate-nixd upgrade          # updates Determinate Nix
```

On macOS, the Determinate installer manages the daemon via a LaunchDaemon rather than the
upstream Nix daemon.

### When to recommend Determinate

- macOS daily driver wanting flakes-on-by-default without editing `nix.conf`
- Enterprise environments that need a validated CVE response path
- Teams needing cross-compilation macOS <-> Linux without a separate Linux build box

### When to stay with upstream

- Inside NixOS, upstream is the integrated path
- CI that already has a working upstream pipeline
- Tooling that expects `nix-daemon` by name

## Lix

- Repo: [lix-project/lix](https://git.lix.systems/lix-project/lix)
- Fork of Nix focused on correctness, compatibility, and a healthier community governance
  model
- Build system: Meson (upstream Nix still uses autotools)
- Community-driven; independent of both the NixOS Foundation and Determinate Systems
- Mostly CLI- and daemon-compatible with upstream Nix

### Notable Lix traits

- Improved error messages, especially for eval traces
- Backported fixes and performance improvements that stalled upstream
- Uses `nix-daemon` like upstream (unlike Determinate's `determinate-nixd`)
- Co-installable with upstream for experimentation in most cases

### When to recommend Lix

- Dissatisfaction with upstream governance and community direction
- Better error messages during heavy module development
- A desire for backward-compatibility focus over feature experimentation

### When to stay with upstream or Determinate

- Paid support or enterprise compliance (Determinate)
- Default NixOS install experience (upstream)
- Tooling strictly tested against one of the other two

## Coexistence and switching

### Installer collisions

If you ran the Determinate Installer and later want to switch to Lix, uninstall
Determinate first:

```bash
/nix/nix-installer uninstall
```

Then run the Lix installer or the upstream install script. Mixing installers rarely ends
well.

### On NixOS

NixOS installs upstream Nix by default. Some users switch to Lix with:

```nix
{
  nix.package = pkgs.lix;
}
```

(Only when the `lix` package exists in the user's nixpkgs; check with
`nix search nixpkgs lix`.)

Switching to Determinate on NixOS is less common - Determinate targets non-NixOS hosts.

### On macOS (nix-darwin)

```nix
# pick one
{ nix.package = pkgs.nix; }         # upstream
{ nix.package = pkgs.lix; }         # Lix
# Determinate: use the Determinate installer, skip nix-darwin's nix management
```

## Lane-specific gotchas

### Determinate

- Some documentation and tooling assumes `nix-daemon` as the service name. On Determinate,
  the daemon is `determinate-nixd`.
- The Determinate store may be initialized with options that upstream does not set; reading
  `nix config show` before assuming defaults is wise.
- `determinate-nixd upgrade` is separate from a NixOS `nixos-rebuild switch`; it upgrades
  the Determinate binary itself.
- On macOS after a system upgrade, macOS may block the daemon. Reinstall via the
  Determinate installer or run the repair command.

### Lix

- Some packaged tools hardcode `/nix/var/nix/daemon-socket/socket` expectations; Lix keeps
  the same path so most work.
- Eval differences from upstream are rare but real; when a flake evaluates on upstream but
  fails on Lix (or vice versa), the trace is the quickest path to the cause.
- Binary caches signed with upstream keys still work on Lix.

### Upstream

- Flakes default to experimental; users must opt in.
- Release cadence is slower than Determinate's feature velocity.
- Community-driven issue response; no defined SLA.

## Checking which lane you are on

```bash
nix --version
# upstream prints "nix (Nix) 2.33.x"
# Lix prints "nix (Lix, like Nix) 2.93.x" (Lix versioning is independent)
# Determinate prints a Determinate-specific version string

command -v determinate-nixd >/dev/null && echo "Determinate present"

# daemon check (Linux)
systemctl status nix-daemon 2>&1 || true
systemctl status determinate-nixd 2>&1 || true
```

## Common mistakes

- Recommending `nix-daemon` restart commands on a Determinate system (wrong service name).
- Assuming Lix has a flake behavior difference it does not. Lix and upstream agree on
  flake semantics; start troubleshooting elsewhere.
- Mixing installers. Pick one, uninstall cleanly, then install the other.
- Using Determinate on NixOS expecting nix-darwin-style benefits. Determinate's value is
  loudest on macOS and non-NixOS Linux.
- Conflating "Lix is a fork" with "Lix is incompatible." It is largely compatible; the
  divergence is in governance, build system, and feature prioritization.
