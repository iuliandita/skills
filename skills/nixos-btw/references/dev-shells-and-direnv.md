# Dev shells and direnv

Per-project reproducible environments are one of Nix's practical wins. The old way is
`shell.nix`; the new way is `flake.nix` dev shells. Pair either with `nix-direnv` for
transparent `cd`-to-activate behavior.

## Classic shell.nix

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    go_1_24
    golangci-lint
    protobuf
    sqlite
  ];

  shellHook = ''
    export CGO_ENABLED=0
    echo "go dev shell ready"
  '';
}
```

```bash
nix-shell            # enter the shell
nix-shell --run make # run a command inside it
nix-shell -p ripgrep # ad-hoc one-off
```

`nix-shell -p <pkg>` is the fastest "install this for this terminal only" - no profile
pollution, no state.

## Flake dev shells

```nix
{
  description = "my project";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
  let
    forAllSystems = f: nixpkgs.lib.genAttrs
      [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
      (system: f (import nixpkgs { inherit system; }));
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [ rustup cargo pkg-config openssl ];
        RUST_BACKTRACE = "1";
      };
      python = pkgs.mkShell {
        packages = with pkgs; [ python3 python3.pkgs.pip python3.pkgs.ruff ];
      };
    });
  };
}
```

```bash
nix develop            # enter default dev shell
nix develop .#python   # alternate
nix develop --command make  # run inside without a subshell
```

### Flake dev shells with flake-utils or flake-parts

To avoid the per-system boilerplate, use `flake-utils.lib.eachDefaultSystem` or
`flake-parts`. Both shrink the outputs block substantially.

```nix
# flake-utils
inputs.flake-utils.url = "github:numtide/flake-utils";
outputs = { nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
  let pkgs = nixpkgs.legacyPackages.${system}; in {
    devShells.default = pkgs.mkShell { packages = [ pkgs.go ]; };
  });
```

## direnv + nix-direnv

`direnv` loads a per-directory shell env on `cd`. `nix-direnv` teaches direnv about Nix dev
shells and caches them so repeated `cd` is instant and survives garbage collection via GC
roots.

### Install (NixOS)

```nix
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # caches nix-shell / nix develop output
  };
}
```

### Install (home-manager)

```nix
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;    # or bash/fish equivalents
  };
}
```

### Per-project `.envrc`

For classic shell.nix:

```bash
# .envrc
use nix
```

For a flake dev shell:

```bash
# .envrc
use flake
# or a specific shell
use flake .#python
```

Enable the env once per new directory:

```bash
direnv allow
```

### direnv cache

`nix-direnv` caches the result in `.direnv/`. That directory holds GC roots so the cached
closure does not disappear on `nix-collect-garbage`. Add `.direnv/` to `.gitignore`.

If a cache becomes stale (you changed `shell.nix` or a flake input):

```bash
direnv reload
```

## Dev-shell hygiene

- Pin inputs. Channels-based `<nixpkgs>` drifts silently.
- Do not mutate `result` symlinks from `nix build` inside a dev shell; the shell tracks
  its own closure.
- Prefer `nix develop` inside a project with a flake. `nix-shell` still works but it relies
  on `NIX_PATH`.
- Separate build tooling from runtime config: `nativeBuildInputs` vs `packages` / env.
- For language-specific workflows, stay close to the language's real tooling:
  - Rust: `rustup` inside a shell is fine. `fenix` or `rust-overlay` gives per-project
    pinned toolchains.
  - Python: `poetry2nix` or `uv2nix` convert lockfiles to flakes; otherwise `mkShell` with
    a Python interpreter and overrides.
  - Node: `buildNpmPackage` needs a hash; for dev shells, `nodePackages` + local
    `package.json` via `npm ci` is often simpler.
  - Go: `buildGoModule` for shipping; dev shell just needs `go` and tooling.

## Patterns

### Multi-language project

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    go_1_24
    nodejs_22
    python3
    python3.pkgs.pip
    postgresql_17
    docker-compose
    jq fd ripgrep
  ];
  shellHook = ''
    export PGDATA=$PWD/.pgdata
    [[ -d $PGDATA ]] || initdb -D $PGDATA
  '';
};
```

### Project-specific overlays in the dev shell

```nix
let
  overlays = [ (import ./overlays/dev.nix) ];
  pkgs = import nixpkgs { inherit system overlays; };
in {
  devShells.default = pkgs.mkShell { packages = [ pkgs.my-patched-tool ]; };
}
```

### `nix run` and `nix shell`

- `nix run nixpkgs#ripgrep -- pattern file` - fetch, run, done
- `nix shell nixpkgs#{ripgrep,fd,bat}` - ephemeral multi-tool shell
- `nix run .#` - run the flake's default app

## Common mistakes

- Forgetting `direnv allow`; the `.envrc` will be silently skipped.
- `.direnv/` committed to git. Add it to `.gitignore`.
- Using `nix-shell` on a flakes-first project where `nix develop` is the intended path.
- Baking secrets into `shellHook`. Use `.envrc` or a secrets manager (sops-nix for shared
  project state).
- Forgetting to add `pkg-config` and language-specific header packages (`openssl.dev`, etc.)
  when a native extension build fails.
- Expecting the dev shell's packages to be on `PATH` outside the shell. They are scoped to
  the shell session (or direnv-loaded directory).
