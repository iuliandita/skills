# Flakes and channels

Two ways to point a NixOS system at a specific `nixpkgs`. Flakes pin explicitly via a
lockfile; channels pin implicitly via whatever `nix-channel --update` last fetched.

## Channels (the older way)

```bash
sudo nix-channel --list
sudo nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
sudo nix-channel --update
sudo nixos-rebuild switch
```

- `nixos` - system channel used by `nixos-rebuild`
- `nixpkgs` - user-level channel for `nix-env`, `nix-shell`
- `home-manager` - if using standalone home-manager

`nixos-rebuild` reads `<nixpkgs>` from the system channel. Mixing stable and unstable
channels without intent causes version drift that is hard to trace.

## Flakes (the newer, de-facto standard)

Flakes require `experimental-features = nix-command flakes` in `nix.conf`. Determinate Nix
enables this by default; upstream Nix does not.

### Minimal flake.nix for a NixOS host

```nix
{
  description = "box";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  {
    nixosConfigurations.box = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alice = import ./home.nix;
        }
      ];
    };
  };
}
```

### Rebuild from a flake

```bash
sudo nixos-rebuild switch --flake /etc/nixos#box
# or from inside the flake directory:
sudo nixos-rebuild switch --flake .#box
```

### Package outputs, multi-host, and `perSystem`

Adding package outputs alongside `nixosConfigurations` - `nix build .#my-tool` consumes
these directly:

```nix
outputs = { self, nixpkgs, ... }:
let
  forAllSystems = f: nixpkgs.lib.genAttrs
    [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
    (system: f (import nixpkgs { inherit system; }));
in {
  packages = forAllSystems (pkgs: {
    my-tool = pkgs.callPackage ./pkgs/my-tool { };
    default = self.packages.${pkgs.system}.my-tool;
  });

  nixosConfigurations = nixpkgs.lib.genAttrs [ "web1" "web2" "db1" ] (host:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./modules/common.nix        # shared across all hosts
        ./hosts/${host}             # host-specific directory
      ];
    });
};
```

The fleet layout pairs with this:

```
.
|-- flake.nix
|-- modules/common.nix
`-- hosts/
    |-- web1/{default.nix,hardware-configuration.nix}
    |-- web2/{default.nix,hardware-configuration.nix}
    `-- db1/{default.nix,hardware-configuration.nix}
```

For less boilerplate, `flake-parts` exposes `perSystem` for package outputs and
`flake.nixosConfigurations` for systems in the same outputs block.

### Channels to flakes migration

Migrating a working channel-based NixOS install to flakes without breaking it:

1. Back up `/etc/nixos`: `sudo cp -a /etc/nixos /etc/nixos.bak`.
2. Enable experimental features system-wide in the current `configuration.nix`:
   `nix.settings.experimental-features = [ "nix-command" "flakes" ];`, then
   `sudo nixos-rebuild switch` once on the channel path so the daemon picks them up.
3. Initialize git in `/etc/nixos` (flakes evaluate only tracked files):
   `sudo git -C /etc/nixos init && sudo git -C /etc/nixos add .`.
4. Write `flake.nix` wrapping the existing module:
   ```nix
   {
     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
     outputs = { self, nixpkgs }: {
       nixosConfigurations.box = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [ ./configuration.nix ];
       };
     };
   }
   ```
5. Commit the flake: `sudo git -C /etc/nixos add flake.nix && sudo git -C /etc/nixos commit -m init`.
6. Apply safely - `boot` stages for next boot without activating now:
   `sudo nixos-rebuild boot --flake /etc/nixos#box`. Reboot.
7. Verify: `nixos-version`, `systemctl --failed`, and test logins. If broken, pick the
   previous generation in the bootloader menu.
8. Once stable, remove the channel to prevent drift:
   `sudo nix-channel --remove nixos && sudo nix-channel --update`.

### Common flake verbs

```bash
nix flake metadata                 # show input URLs and revs from flake.lock
nix flake update                   # update all inputs and write flake.lock
nix flake lock --update-input nixpkgs  # update one input
nix flake check                    # eval all outputs, run checks
nix flake check --no-build         # eval without building - fast sanity check
nix flake show                     # show outputs tree
```

### Input follows

Use `follows` to deduplicate transitive `nixpkgs` copies:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  home-manager = {
    url = "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = "nixpkgs";    # use our nixpkgs, not theirs
  };
  sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Without `follows`, each input drags its own `nixpkgs`. Your closure bloats and cache hits
drop.

### flake.lock

`flake.lock` is JSON, committed to git. Every input has a locked `rev` and `narHash`. It is
not a lockfile of packages; it is a lockfile of input trees. Builds are reproducible because
every evaluation starts from locked input trees.

## Channels vs flakes, practical tradeoffs

| Property | Channels | Flakes |
|----------|----------|--------|
| Pinning | implicit, per `nix-channel --update` | explicit via `flake.lock` |
| Reproducibility across machines | weak | strong |
| CI story | requires pinning tools (niv, npins) | native |
| Stability upstream | stable | still experimental (default-on in Determinate) |
| `NIX_PATH` required | yes | no |
| Registry | irrelevant | central via `nix registry` |
| Migration cost | low | moderate, new mental model |

If the user already has flakes, keep them. If they are on channels and content, do not push
migration during a troubleshooting session.

## Alternatives to flakes without flakes

- **[npins](https://github.com/andir/npins)** - lock file for channel users without enabling
  flakes. Pins git sources declaratively.
- **[niv](https://github.com/nmattia/niv)** - predecessor to npins, still widely seen in
  older projects.

Both produce a JSON file with locked revs and hashes, read via a small Nix helper.

## Registry

Flakes support a user and system registry of short names. `nixpkgs` resolves to the pinned
flake by default:

```bash
nix registry list            # show active entries
nix registry add foo github:org/repo
nix registry pin foo         # pin to current resolved rev
nix registry remove foo
```

## Pure vs impure evaluation

Flakes default to **pure evaluation**: no access to env vars, `NIX_PATH`, or the user's home
without `--impure`. Some patterns need impurity:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#vscode
```

Prefer setting `nixpkgs.config.allowUnfree = true;` in the flake output instead of reaching
for `--impure` every time.

## Common footguns

- Forgetting to `git add flake.nix` and `flake.lock` before `nixos-rebuild --flake .#host`.
  Flakes evaluate inside a pure sandbox that only sees tracked files.
- Running `nix flake update` alongside an unrelated change and committing both together -
  hard to review. Keep input bumps in their own commit.
- Enabling flakes on the Nix daemon but not also on the user - missing
  `experimental-features` in `~/.config/nix/nix.conf`.
- Mixing `nixos-unstable` and `nixos-25.11` inputs without `follows` - you get two
  `nixpkgs` trees and surprising collisions.
- Assuming `nix flake check` builds everything. Use `nix flake check --keep-going` to see
  all failures and `--no-build` for a fast eval-only sanity pass.
