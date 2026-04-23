# configuration.nix and the NixOS module system

NixOS is a module system written in Nix. `configuration.nix` is one module; everything you
import is one too. A module has three things that matter: `imports`, `options`, and `config`.

## /etc/nixos layout

A traditional channel-based install:

```
/etc/nixos/
├── configuration.nix       # entry module
└── hardware-configuration.nix  # generated, do not hand-edit
```

A flake-based install:

```
/etc/nixos/
├── flake.nix
├── flake.lock
├── configuration.nix
├── hardware-configuration.nix
└── modules/
    ├── desktop.nix
    ├── networking.nix
    └── users.nix
```

Keep `hardware-configuration.nix` as-generated. Regenerate with
`nixos-generate-config --root /mnt` during install or `nixos-generate-config` in place.

## Minimal configuration.nix

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "box";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };

  environment.systemPackages = with pkgs; [
    git vim ripgrep fd jq htop
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.11";  # do not change after first install
}
```

## Module anatomy

Every NixOS module conforms to:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ];           # other modules to import
  options = { ... };       # options this module declares
  config  = { ... };       # option values this module sets

  # sugar: if the module sets config and nothing else, drop "config = {}" and inline it.
}
```

Declare your own option for a reusable module:

```nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.my.services.status;
in {
  options.my.services.status = {
    enable = mkEnableOption "custom status service";
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.status = {
      description = "Status";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.my-status}/bin/status --port ${toString cfg.port}";
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
```

## mkMerge, mkForce, mkDefault, mkIf, mkOverride

- `mkDefault value` - lowest precedence; loses to any explicit set
- normal assignment - standard precedence
- `mkForce value` - overrides other modules' values
- `mkOverride prio value` - numeric precedence (lower wins; `mkForce` is 50, `mkDefault` is 1000)
- `mkIf cond attrs` - include the block only when `cond` is true
- `mkMerge [ ... ]` - combine multiple partial config blocks

```nix
{
  services.nginx.enable = mkDefault true;           # caller may override
  services.nginx.package = mkForce pkgs.nginxMainline; # caller may not override
  environment.systemPackages = mkMerge [
    [ pkgs.git ]
    (mkIf config.services.postgresql.enable [ pkgs.postgresql ])
  ];
}
```

## Assertions and warnings

Fail fast at eval time instead of producing a broken system:

```nix
{
  assertions = [
    {
      assertion = config.services.openssh.enable ->
                  !config.services.openssh.settings.PasswordAuthentication;
      message = "SSH password auth must be disabled when openssh is enabled.";
    }
  ];

  warnings = lib.optional (config.networking.hostName == "nixos")
    "hostname is the install default 'nixos' - consider changing.";
}
```

## Option types

The common ones:

| Type | Example |
|------|---------|
| `bool` | `true` or `false` |
| `int`, `port` | `8080` |
| `str`, `path` | `"/var/lib/app"` or `./config.toml` |
| `enum [ "a" "b" ]` | one of the listed strings |
| `listOf <type>` | `[ "x" "y" ]` |
| `attrsOf <type>` | `{ key = value; ... }` |
| `submodule { options = { ... }; }` | structured nested options |
| `nullOr <type>` | the type or `null` |
| `either a b` | `a` or `b` |

## Exploring options

The fastest lookups:

```bash
# Web: https://search.nixos.org/options
nix repl
> :lf /etc/nixos  # load a flake
> :p config.services.nginx.enable

# Option docs from the CLI (slow but offline)
nixos-option services.openssh.enable 2>&1 || true
nix-instantiate --eval -E '(import <nixpkgs/nixos> { configuration = ./configuration.nix; }).options.services.openssh.enable.description'
```

## Common mistakes

- Editing `hardware-configuration.nix` by hand. Regenerate instead.
- Using `mkForce` when `mkDefault` in the other module would be the right fix.
- Putting secrets directly in module strings; they land in `/nix/store` world-readable. Use
  sops-nix or agenix.
- Setting `system.stateVersion` to the current release on an existing system. It locks
  migration behavior; leave the first-install value alone.
- Writing circular `imports` - the module system resolves lazily but circular references on
  `config.<x>` still deadlock evaluation.
