# Overlays, overrides, and writing packages

When you need a package that nixpkgs does not carry, a different version than what is
cached, or a patch upstream will not take - overlays, overrides, and hand-written
derivations are the toolbox.

## `override` vs `overrideAttrs`

- **`override { ... }`** - changes the *arguments* passed to a package's function (build
  inputs, flags, boolean features)
- **`overrideAttrs (old: { ... })`** - changes the *attributes* of the resulting derivation
  (src, patches, postPatch, doCheck, env vars)

```nix
# override: swap the curl backend
pkgs.curl.override { opensslSupport = false; gnutlsSupport = true; }

# overrideAttrs: patch and re-version
pkgs.htop.overrideAttrs (old: {
  version = "3.4.2";
  src = pkgs.fetchFromGitHub {
    owner = "htop-dev";
    repo = "htop";
    rev = "v3.4.2";
    hash = "sha256-AAAA...";
  };
  patches = (old.patches or []) ++ [ ./fix-ioctl.patch ];
})
```

Rule of thumb: if the change is a boolean or input, use `override`; if the change is source,
patches, or phases, use `overrideAttrs`.

## Overlays

An overlay is a function `final: prev: { ... }`. `final` is the overlaid package set
(post-overlay); `prev` is the package set as it existed before this overlay applied. Use
`final` to refer to other (possibly overlaid) packages; use `prev` to fall back to upstream.

```nix
# overlays/my-overlay.nix
final: prev: {
  htop = prev.htop.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./htop-fix.patch ];
  });

  myTool = prev.callPackage ./pkgs/my-tool { };

  python3 = prev.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      requests = pyPrev.requests.overrideAttrs (o: {
        doCheck = false;
      });
    };
  };
}
```

Wire into a flake-based NixOS system:

```nix
# flake.nix outputs
nixosConfigurations.box = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix
    ({ ... }: { nixpkgs.overlays = [ (import ./overlays/my-overlay.nix) ]; })
  ];
};
```

Or as a flake input:

```nix
inputs.my-overlay.url = "github:me/my-overlay";
...
modules = [ ({ ... }: { nixpkgs.overlays = [ inputs.my-overlay.overlay ]; }) ];
```

Wire into a channels-based system:

```nix
# configuration.nix
{
  nixpkgs.overlays = [ (import /etc/nixos/overlays/my-overlay.nix) ];
}
```

### Overlay placement on flakes

`~/.config/nixpkgs/overlays.nix` is often **ignored** on pure flakes because the flake
sandbox does not read arbitrary user files. Put overlays in the flake inputs or as files
the flake tracks.

### Overlay composition

Multiple overlays apply left-to-right. Later overlays see the earlier ones via `final`:

```nix
nixpkgs.overlays = [
  (import ./overlays/first.nix)
  (import ./overlays/second.nix)  # sees outputs of first via final.<pkg>
];
```

## Writing a derivation

The canonical function is `stdenv.mkDerivation`. Put packages in `pkgs/<name>/default.nix`
and call with `callPackage`.

```nix
# pkgs/my-tool/default.nix
{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, openssl }:

stdenv.mkDerivation rec {
  pname = "my-tool";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "me";
    repo = "my-tool";
    rev = "v${version}";
    hash = "sha256-AAAA...";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ openssl ];

  cmakeFlags = [ "-DBUILD_TESTS=OFF" ];

  meta = with lib; {
    description = "My tool";
    homepage = "https://github.com/me/my-tool";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "my-tool";
  };
}
```

Called from an overlay:

```nix
final: prev: {
  my-tool = prev.callPackage ./pkgs/my-tool { };
}
```

## Language-specific helpers

| Language | Helper | Typical file |
|----------|--------|--------------|
| Rust | `rustPlatform.buildRustPackage` | `default.nix` with `cargoHash` |
| Go | `buildGoModule` | `default.nix` with `vendorHash` |
| Python | `python3.pkgs.buildPythonApplication` | `default.nix` with `propagatedBuildInputs` |
| Node | `buildNpmPackage` or `buildYarnPackage` | with lock hash |
| Haskell | `haskellPackages.callCabal2nix` | Cabal-derived |

Example Rust:

```nix
{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl }:

rustPlatform.buildRustPackage rec {
  pname = "my-cli";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "me"; repo = "my-cli"; rev = "v${version}";
    hash = "sha256-...";
  };

  cargoHash = "sha256-...";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  meta.mainProgram = "my-cli";
}
```

First build fails with a hash mismatch; copy the "got:" hash into `cargoHash` and rebuild.

Example Go:

```nix
{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "my-cli";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "me"; repo = "my-cli"; rev = "v${version}";
    hash = "sha256-...";
  };

  vendorHash = "sha256-...";      # set to lib.fakeHash first, copy "got:" on rebuild
  # vendorHash = null;              # if go.mod has no dependencies

  subPackages = [ "cmd/my-cli" ];  # limit to specific main packages
  ldflags = [ "-s" "-w" "-X main.version=${version}" ];
  env.CGO_ENABLED = 0;

  meta.mainProgram = "my-cli";
}
```

Same hash-dance as Rust: set `vendorHash = lib.fakeHash;`, build, copy the reported "got:"
hash into the attribute.

## Fetchers

- `fetchFromGitHub { owner; repo; rev; hash; }`
- `fetchFromGitLab`, `fetchFromSourcehut`, `fetchFromCodeberg`
- `fetchurl { url; hash; }`
- `fetchgit { url; rev; hash; }` - for arbitrary git remotes
- `fetchTarball { url; sha256; }` - last resort for single tarballs

Use `sha256` only when a tool explicitly requires it; prefer `hash` in SRI format
(`sha256-...`).

## Unfree and insecure gates

```nix
# System-wide, declarative
nixpkgs.config.allowUnfree = true;

# Or an allowlist predicate
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "vscode" "nvidia-x11" "steam-unwrapped"
];

# Insecure packages that are still used on purpose
nixpkgs.config.permittedInsecurePackages = [ "openssl-1.1.1w" ];
```

One-off impure escape hatch:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#vscode
```

## Common mistakes

- Using `override` where `overrideAttrs` is needed (or vice versa). Error messages are
  cryptic; the distinction matters.
- Forgetting to bump `hash` / `cargoHash` / `vendorHash` after changing `src`. The derivation
  will either rebuild from stale fetch or fail with a mismatch.
- Writing `final: prev:` overlays that mutate `prev.<x>` in-place instead of returning
  new values. Nix attrsets are immutable; you add keys to the returned set.
- Scoping overlays in the wrong place on flakes - user-level `~/.config/nixpkgs/overlays.nix`
  is often ignored.
- Over-using `overrideAttrs` for things a plain option would fix. Check nixpkgs options
  first; many packages expose flags.
