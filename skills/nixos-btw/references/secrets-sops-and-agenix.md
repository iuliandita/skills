# Secrets: sops-nix and agenix

Nix puts every build input into `/nix/store`, and the store is world-readable. Anything you
interpolate into a module string ends up there. Secrets need to be decrypted at **activation
time**, not build time, and read from a path outside the store.

Two common options:

- **sops-nix** - encrypts with age, PGP, or cloud KMS; edits with `sops`; decrypts at
  activation into `/run/secrets/`.
- **agenix** - encrypts with age only; edits with `agenix`; decrypts at activation into
  `/run/agenix/` (configurable).

Both integrate with home-manager and nix-darwin via their own modules.

## sops-nix

### Install

```nix
# flake.nix
inputs.sops-nix = {
  url = "github:Mic92/sops-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# configuration.nix
{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];
}
```

### Age key for the host

Generate on the host once (or derive from SSH host key):

```bash
# From existing SSH host key (no new material to manage)
sudo nix-shell -p ssh-to-age --run \
  'ssh-keyscan -t ed25519 localhost | ssh-to-age'

# Or a fresh age key
sudo mkdir -p /var/lib/sops-nix
sudo nix-shell -p age --run 'age-keygen -o /var/lib/sops-nix/key.txt'
sudo chmod 600 /var/lib/sops-nix/key.txt
```

### .sops.yaml (single-host)

```yaml
keys:
  - &alice age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &host_box age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *alice
          - *host_box
```

### .sops.yaml (multi-host fleet)

Scope each host's secrets to that host's key so each server only decrypts its own:

```yaml
keys:
  - &alice   age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &web1    age1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  - &web2    age1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  - &db1     age1cccccccccccccccccccccccccccccccccccccccccccccccccccc
creation_rules:
  # Shared secrets readable by every host + admin
  - path_regex: secrets/shared/.*\.yaml$
    key_groups:
      - age: [*alice, *web1, *web2, *db1]
  # Per-host secrets readable only by that host + admin
  - path_regex: secrets/hosts/web1/.*\.yaml$
    key_groups:
      - age: [*alice, *web1]
  - path_regex: secrets/hosts/web2/.*\.yaml$
    key_groups:
      - age: [*alice, *web2]
  - path_regex: secrets/hosts/db1/.*\.yaml$
    key_groups:
      - age: [*alice, *db1]
```

### Adding a new host

1. Boot the host (live ISO or nixos-anywhere target) and capture its ed25519 SSH host key,
   or generate a dedicated age key you copy into `/var/lib/sops-nix/key.txt` before
   activation.
2. Derive its age public key:
   `ssh-keyscan -t ed25519 <host> | ssh-to-age`.
3. Add the key to `.sops.yaml` under `keys:` with an anchor.
4. Add a `creation_rules` entry scoped to `secrets/hosts/<new>/.*\.yaml$` listing the
   new anchor and any shared admins.
5. `sops updatekeys secrets/hosts/<new>/*.yaml` to re-key any existing secrets that now
   need the new host added.
6. Add `nixosConfigurations.<new>` to the flake and deploy with `nixos-anywhere` or a
   normal `nixos-rebuild --flake .#<new> --target-host`.

### Encrypting a secret

```bash
# Creates or edits, opening your $EDITOR
sops secrets/prod.yaml
```

### Consuming in NixOS

```nix
{
  sops = {
    defaultSopsFile = ./secrets/prod.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    # or age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      "db/password" = {
        owner = "postgres";
        group = "postgres";
        mode = "0400";
        restartUnits = [ "postgresql.service" ];
      };
      "wg/privateKey" = {
        owner = "root";
        mode = "0400";
      };
    };
  };

  services.postgresql.enable = true;
  systemd.services.postgresql.serviceConfig.EnvironmentFile =
    config.sops.secrets."db/password".path;
}
```

The decrypted file path is `config.sops.secrets."db/password".path` - typically
`/run/secrets/db/password`. Modules reference the path, not the value.

## agenix

Lighter option; age-only, fewer moving parts.

### Install

```nix
inputs.agenix.url = "github:ryantm/agenix";

# configuration.nix
{ inputs, ... }:
{
  imports = [ inputs.agenix.nixosModules.default ];
  environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.default ];
}
```

### secrets.nix (declares recipients per secret)

```nix
let
  alice = "ssh-ed25519 AAAA... alice";
  hostBox = "ssh-ed25519 AAAA... root@box";

  users = [ alice ];
  systems = [ hostBox ];
in
{
  "db-password.age".publicKeys = users ++ systems;
  "wg-private.age".publicKeys = users ++ [ hostBox ];
}
```

### Encrypt

```bash
agenix -e db-password.age
```

### Consume

```nix
{
  age.secrets.db-password = {
    file = ./secrets/db-password.age;
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  };

  systemd.services.postgresql.serviceConfig.EnvironmentFile =
    config.age.secrets.db-password.path;
}
```

Decrypted path is `config.age.secrets.<name>.path`, typically `/run/agenix/<name>`.

## Picking between them

| Concern | sops-nix | agenix |
|---------|----------|--------|
| Encryption backends | age, PGP, AWS KMS, GCP KMS, Azure KV | age only |
| Edit UX | `sops` (industry tool) | `agenix -e` |
| File format | YAML/JSON/.env/binary | binary blobs per secret |
| Granularity | fields inside a file | one secret per file |
| Team workflow | broader tooling | minimal deps |
| nix-darwin / home-manager | both support | both support |

Most new hobbyist NixOS setups land on agenix. Most team / fleet setups land on sops-nix.

## Home-manager module

sops-nix and agenix both have home-manager modules. Decrypted paths live under
`$XDG_RUNTIME_DIR/secrets/` or the configured prefix. Useful for per-user git credentials,
API tokens for user services.

## What not to do

- Do not put secrets in `builtins.readFile ./path-to-plaintext`. That path gets copied into
  the store at eval time.
- Do not pass secrets via `environment.etc."foo".text = "..."`. Same issue.
- Do not echo secrets into systemd unit `Environment=` lines. Use `EnvironmentFile=` that
  points to an agenix/sops-decrypted path.
- Do not check in `/var/lib/sops-nix/key.txt` or the host age private key. They must stay on
  the host.
- Do not forget to add new hosts' public keys to `.sops.yaml` or `secrets.nix` and re-key
  existing secrets (`sops updatekeys` or `agenix -r`) when rotating.

## Rotation

```bash
# sops: update keys listed in .sops.yaml for existing files
sops updatekeys secrets/prod.yaml

# agenix: re-encrypt all declared secrets
agenix -r
```

Rotate host age keys on machine replacement; rotate the underlying secret whenever it may
have been exposed (e.g., accidentally committed unencrypted).

## Common mistakes

- Assuming `/run/secrets/` is backed by disk. It is a tmpfs by default - contents vanish on
  reboot, and are re-decrypted at activation.
- Forgetting `restartUnits = [ ... ]` when a secret changes. Without it, the consuming
  service keeps its old env.
- Putting the age key under `/nix/store` by accident (e.g., `age.keyFile =
  ./key.txt`). The path gets copied into the store. Use an absolute path outside the store.
- Using agenix with hosts whose ed25519 SSH key has not been converted to age format; the
  host cannot decrypt.
- Committing secrets unencrypted. git log keeps them forever; rotate immediately and use
  `git filter-repo` to rewrite if the exposure is severe.
