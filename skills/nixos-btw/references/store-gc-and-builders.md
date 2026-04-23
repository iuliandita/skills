# Nix store, GC, and remote builders

The Nix store (`/nix/store`) is an append-only content-addressed tree of immutable
derivations. Every system, user profile, dev shell, and direnv cache registers GC roots
that protect store paths from collection.

## Store layout

```
/nix/store/<hash>-<name>-<version>/
/nix/var/nix/profiles/system-<N>-link -> /nix/store/<hash>-nixos-system-...
/nix/var/nix/profiles/per-user/<user>/profile-<N>-link -> ...
/nix/var/nix/gcroots/auto/<symlink> -> somewhere
~/.nix-profile -> /nix/var/nix/profiles/per-user/<user>/profile
```

Never write into `/nix/store` directly. Every path there is immutable by design.

## `nix-store` vs `nix store`

`nix-store` is the older CLI; `nix store` is the newer subcommand under the unified `nix`
CLI. Both coexist. Rough mapping:

| Task | old | new |
|------|-----|-----|
| Query path info | `nix-store -q --references /path` | `nix store references /path` |
| Verify a path | `nix-store --verify-path /path` | `nix store verify /path` |
| Garbage collect | `nix-store --gc` | `nix store gc` |
| Optimise (dedup) | `nix-store --optimise` | `nix store optimise` |
| Add to store | `nix-store --add file` | `nix store add-file file` |
| Print GC roots | `nix-store --gc --print-roots` | `nix store gc --print-roots` |
| Dump / restore | `nix-store --dump`, `--restore` | `nix store dump`, `restore` |
| Copy between stores | `nix-copy-closure`, `nix-store --export` | `nix copy` |

The new CLI is cleaner and works better with flakes. It is under `experimental-features`.

## Garbage collection

### What gets deleted

`nix-store --gc` (alias: `nix-collect-garbage`) deletes any path in `/nix/store` that is
not reachable from a GC root. GC roots include:

- The current and previous system generations
- All user profile generations
- Active dev shells (via `.direnv` symlinks, `result` symlinks from `nix build`)
- `$HOME/.nix-defexpr/channels` entries
- Arbitrary symlinks into `/nix/store` under `/nix/var/nix/gcroots/auto/`

### Commands

```bash
# Delete unreachable paths
nix-collect-garbage                       # keep all generations
sudo nix-collect-garbage -d               # also delete old generations of all profiles
sudo nix-collect-garbage --delete-older-than 30d

# See what would be deleted without deleting
nix-store --gc --print-dead

# See roots that protect paths
nix-store --gc --print-roots

# Dedup identical files across the store
sudo nix-store --optimise
```

### Scheduled GC

Declare it in `configuration.nix`:

```nix
{
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
    persistent = true;  # catch up on missed runs
  };
  nix.settings.auto-optimise-store = true;
}
```

`auto-optimise-store = true` dedupes after each build. Cheap on modern SSDs; can slow bulk
imports on spinning disks.

### GC root footguns

- Deleting a `result` symlink in a project directory removes its GC root. The dev shell's
  build products then become eligible for GC. Your next `nix build` will re-fetch.
- `direnv` with `nix-direnv` creates GC roots under `.direnv/`; aggressive project cleanup
  also removes them.
- CI runners that share a Nix store should register roots for artifacts they care about or
  disable GC during the build.

## Substituters and binary caches

Nix prefers to download pre-built store paths (substitutes) rather than build from source.

Default substituter: `https://cache.nixos.org` with the public key published upstream.

Declare additional substituters:

```nix
{
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://numtide.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
  ];
}
```

### cachix and attic

- **[cachix](https://www.cachix.org/)** - hosted binary cache. Fast to set up; per-org cache
  and signing keys. `cachix use <name>` adds the substituter.
- **[attic](https://github.com/zhaofengli/attic)** - self-hosted binary cache with S3
  backend. Sign with `attic push <cache> <path>` from CI.

For a CI pattern, push every successful build to a shared cache so subsequent runs and
developers hit substitutes instead of rebuilding.

## Remote builders

Offload builds to bigger or differently-arch'd machines:

```nix
{
  nix.buildMachines = [
    {
      hostName = "builder.lan";
      system = "x86_64-linux";
      sshUser = "nix-build";
      sshKey = "/root/.ssh/nix-build";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    }
    {
      hostName = "mbp.lan";
      system = "aarch64-darwin";
      sshUser = "builder";
      sshKey = "/root/.ssh/nix-build";
      maxJobs = 4;
    }
  ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
```

Remote macOS builds cover the `aarch64-darwin` gap for teams on NixOS that need to produce
Darwin artifacts. Determinate Nix introduced a native Linux builder for macOS that reduces
the need for a separate Linux box.

## Signing and verification

```bash
# Generate a signing key pair
nix key generate-secret --key-name mycache-1 > mycache.sec
nix key convert-secret-to-public < mycache.sec > mycache.pub

# Sign paths
nix store sign --key-file mycache.sec <store-path>

# Verify
nix store verify --trusted-public-keys "$(cat mycache.pub)" <store-path>
```

`trusted-substituters` and `trusted-public-keys` control what an untrusted user may
instruct the daemon to fetch.

## Store too big

```bash
# What is taking space
nix path-info --all --size --human-readable | sort -h | tail -30

# Heavy dependents of a path
nix why-depends /run/current-system /nix/store/<hash>-foo

# Older generations you are keeping on purpose?
nix-env --list-generations -p /nix/var/nix/profiles/system
nix-env --delete-generations +5 -p /nix/var/nix/profiles/system

# User-profile closures often dominate after system GC
home-manager expire-generations '-30 days' 2>&1 || true
nix profile wipe-history --older-than 30d 2>&1 || true

sudo nix-collect-garbage -d
```

`nix store optimise` (dedup) and `nix.settings.auto-optimise-store = true;` help on big
stores. Results vary by filesystem - btrfs and XFS benefit most.

## Common mistakes

- Running `nix-collect-garbage -d` moments after a `nixos-rebuild switch`, before
  confirming the new generation boots clean. Keep at least the last known-good generation.
- Pruning generations without also pruning user profiles - user-level closures still hold
  large trees.
- Disabling a substituter without also checking `trusted-substituters` - you get slow
  rebuilds but no clear error.
- Ignoring `--substitute-on-destination` on `nix copy` when deploying to a remote - the
  remote may silently rebuild.
- Treating `/nix/store` as diskful cache. It is authoritative state; backup strategies that
  skip it lose rollback history.
