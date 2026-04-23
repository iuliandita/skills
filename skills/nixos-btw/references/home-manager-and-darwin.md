# home-manager and nix-darwin

home-manager manages user-level configuration declaratively. nix-darwin does the same for
macOS system settings. Both compose with NixOS or run standalone.

## home-manager: three modes

| Mode | Activated by | Rebuild command | When to pick |
|------|--------------|-----------------|--------------|
| **Standalone** | user runs `home-manager switch` | `home-manager switch` | host is not NixOS, or user wants decoupled lifecycle |
| **NixOS module** | wired into `configuration.nix` | `nixos-rebuild switch` | host is NixOS; user wants single deploy |
| **nix-darwin module** | wired into `darwin-configuration.nix` | `darwin-rebuild switch` | host is macOS with nix-darwin |

Pick one per host and stay there. Mixing standalone and module mode on the same user
produces silent overwrites.

### Standalone home-manager (channels)

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

Then `~/.config/home-manager/home.nix`:

```nix
{ config, pkgs, ... }:

{
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    ripgrep fd bat eza jq htop
  ];

  programs.git = {
    enable = true;
    userName = "Alice";
    userEmail = "alice@example.com";
    extraConfig.pull.rebase = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  home.file.".config/foo/config.toml".text = ''
    bar = "baz"
  '';
}
```

Rebuild:

```bash
home-manager switch
home-manager generations
home-manager switch --rollback
```

### Standalone home-manager (flakes)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."alice@box" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}
```

```bash
home-manager switch --flake .#alice@box
```

### home-manager as NixOS module

In `configuration.nix` or one of its imports:

```nix
{ home-manager, ... }:

{
  imports = [ home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-bak";

  home-manager.users.alice = { config, pkgs, ... }: {
    home.stateVersion = "25.11";
    programs.zsh.enable = true;
    home.packages = with pkgs; [ ripgrep fd ];
  };
}
```

Then `nixos-rebuild switch` applies both system and home.

`useGlobalPkgs = true` reuses the NixOS nixpkgs instance instead of instantiating another.

### home-manager as nix-darwin module

Identical shape, different entry point:

```nix
{
  imports = [ home-manager.darwinModules.home-manager ];
  home-manager.users.alice = { pkgs, ... }: {
    home.stateVersion = "25.11";
    home.packages = with pkgs; [ ripgrep fd bat jq python312 ];
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
    programs.starship.enable = true;
    programs.git = {
      enable = true;
      userName = "Alice";
      userEmail = "alice@example.com";
    };
  };
}
```

Then `darwin-rebuild switch`. Pair with a per-project `flake.nix` dev shell (see
`references/dev-shells-and-direnv.md`) and a `.envrc` containing `use flake` so direnv
loads the shell on `cd`.

## nix-darwin: declarative macOS

nix-darwin brings NixOS-style modules to macOS. It manages packages, LaunchDaemons, macOS
defaults, fonts, and some system services. It does not replace macOS or the kernel.

### Install (flakes)

```bash
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake ~/.config/nix-darwin
```

### Minimal darwin flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nix-darwin, nixpkgs }: {
    darwinConfigurations."mbp" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ ./configuration.nix ];
    };
  };
}
```

### Darwin configuration.nix highlights

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ git coreutils jq ];

  # enable the nix-darwin-managed nix daemon
  nix.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # macOS defaults, declaratively
  system.defaults.dock.autohide = true;
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";

  # Homebrew coexists via nix-darwin's brew integration
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    brews = [ "mas" ];
    casks = [ "firefox" "raycast" ];
  };

  # required
  system.stateVersion = 6;
  programs.zsh.enable = true;
}
```

`darwin-rebuild switch --flake ~/.config/nix-darwin#mbp` applies.

## nix-darwin gotchas

- Apple Silicon is `aarch64-darwin`; Intel is `x86_64-darwin`. Rosetta is available but
  costs rebuilds.
- `nix.enable = true` (newer) replaces `services.nix-daemon.enable = true` (older). Pick
  one; the release notes tell you which.
- macOS security occasionally blocks the Nix daemon after an OS upgrade. Reinstall the
  Determinate installer or re-run the uninstall/reinstall dance if `nix` goes missing.
- Homebrew via `homebrew = { enable = true; ... }` uses the actual Homebrew binary; nix-darwin
  only orchestrates it. Casks are not sandboxed by Nix.
- macOS defaults written by nix-darwin apply on next login for some keys; `killall cfprefsd`
  nudges them.
- `system.stateVersion` on darwin is an integer, unlike NixOS.

## Picking a mode by scenario

| Scenario | Mode |
|----------|------|
| NixOS workstation, one user owns the box | home-manager as NixOS module |
| NixOS workstation with many users, each self-managing | standalone home-manager per user |
| macOS daily driver, declarative dotfiles | nix-darwin + home-manager as darwin module |
| macOS laptop, just want Nix for packages | plain Nix + `nix profile`, no nix-darwin |
| Non-NixOS Linux host, Nix as user tool | standalone home-manager |
| WSL2 NixOS | home-manager as NixOS module, same as NixOS |

## Common mistakes

- Running `home-manager switch` on a system where home-manager is wired as a NixOS module.
  The module mode overwrites the standalone state on the next `nixos-rebuild switch`.
- Putting machine-level concerns (boot, kernel, systemd system units) in home-manager. Those
  belong in `configuration.nix`.
- Forgetting `backupFileExtension` on the NixOS module - without it, activation fails when a
  file it would manage already exists.
- Nix-darwin `launchd` units that assume Linux paths. macOS has its own service paths and
  environment.
- Treating nix-darwin like NixOS with a different kernel. It is a shim over macOS, not a
  replacement.
