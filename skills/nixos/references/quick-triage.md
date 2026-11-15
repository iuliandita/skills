# Quick Triage Checklist

Symptom to first-checks table for Nix and NixOS problems.

## Quick Triage Checklist

| Symptom | First checks |
|---------|-------------|
| `nixos-rebuild` evaluation error | `--show-trace`, check option name against the current nixpkgs tag, check `imports` paths |
| Build fails mid-derivation | `--print-build-logs`, check sandbox violations, check unfree or insecure gates |
| Boot drops to emergency shell | previous generation from bootloader menu, check `hardware-configuration.nix`, LUKS, kernel modules |
| Flake input won't update | `nix flake update <name>` (Nix 2.19 removed `nix flake lock --update-input`), check `inputs.<x>.follows`, check registry override |
| System is huge, `/nix/store` fills disk | inspect GC roots and generations, preserve known-good rollback, selectively prune, then plain `nix-collect-garbage` |
| `nix-env -i` installed something that won't stick | user profile vs system config; move to `environment.systemPackages` or `home.packages` |
| home-manager drift vs NixOS | standalone vs module mode, which one owns the file, `home-manager switch` vs `nixos-rebuild switch` |
| Unfree package refuses to build | `nixpkgs.config.allowUnfree = true;` or predicate, or `NIXPKGS_ALLOW_UNFREE=1 nix-build --impure` for one-off |
| Secrets in a module show up world-readable | moved to sops-nix/agenix and re-deploy; rotate the exposed secrets |
| ZFS or NVIDIA breaks after kernel bump | `boot.kernelPackages = pkgs.linuxPackages_<pin>;` or wait for out-of-tree module to rebuild |
| nix-darwin change did not apply | `darwin-rebuild switch`, not `nixos-rebuild`; check `users.users.<name>.home` and `nix.enable` |
| Nothing makes sense | check gotchas reference - channel vs flake mixing, stale lock, overlay collisions, GC of an active dev shell |
