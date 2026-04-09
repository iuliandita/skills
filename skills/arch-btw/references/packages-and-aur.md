# Packages and AUR

Package hygiene is the difference between a boring Arch box and an afternoon lost to package skew.
Favor official repos first, `paru` second, and raw AUR build inspection whenever something looks
off.

## Native package flow

| Task | Command | Notes |
|------|---------|-------|
| Full upgrade | `sudo pacman -Syu` | Default Arch maintenance path |
| Install package | `sudo pacman -S package_name` | Pulls deps from enabled repos |
| Remove package and unused deps | `sudo pacman -Rns package_name` | Read the removal list carefully |
| Search repos | `pacman -Ss string` | Searches name and description |
| Remote package info | `pacman -Si package_name` | Repo metadata and dependencies |
| Local package info | `pacman -Qi package_name` | Installed metadata |
| Owner of file | `pacman -Qo /path/to/file` | Local package ownership |
| Remote owner of file | `pacman -F /path/to/file` | Sync files database lookup |
| Refresh files database | `sudo pacman -Fy` | Needed before `-F` is reliable |
| Foreign packages | `pacman -Qm` | AUR or manually installed packages |
| Orphans | `pacman -Qdt` | Review before removing |
| Verify package files | `pacman -Qk package_name` | File presence check |
| Deep verify | `pacman -Qkk package_name` | More thorough file audit |
| Install built package | `sudo pacman -U /path/to/pkg.pkg.tar.zst` | For local or manually built packages |

## Hard rules for Arch package work

- Use full upgrades on Arch-style systems. `pacman -Sy package_name` creates partial-upgrade risk.
- Read the transaction plan before confirming. Arch tells you what it is about to remove or replace.
- Keep an eye on `pacman -Qm`. Foreign packages are a common source of drift.
- Do not default to `--overwrite`. Conflicting files usually mean packaging or ownership needs to be fixed first. When `--overwrite` is genuinely needed, use a specific glob - never a bare wildcard:

  ```bash
  # Right: overwrite only the conflicting path
  sudo pacman -Syu --overwrite '/usr/lib/python3.*/site-packages/collisions/*'

  # Wrong: blanket overwrite hides real conflicts
  sudo pacman -Syu --overwrite '*'
  ```

- If repo state looks corrupted, refresh carefully, then re-check mirror and keyring state before forcing package operations.

## `paru` stance

`paru` is the default helper in this skill because the user uses it. That changes ergonomics, not
trust boundaries.

- Use `paru` for normal AUR install and upgrade workflow.
- When a package fails to build, debug the underlying `PKGBUILD` and artifacts directly.
- If an AUR package moves into the official repos, expect conflicts, replacements, or stale assumptions.

## Manual AUR workflow

When an AUR package behaves badly, fall back to the boring path:

```bash
git clone https://aur.archlinux.org/package_name.git
cd package_name
less PKGBUILD
makepkg -si
```

If you build first and install later:

```bash
sudo pacman -U ./package_name-version.pkg.tar.zst
```

Before building, inspect:

- `PKGBUILD`
- any `.install` file
- patch files
- download URLs
- PGP key expectations

If the package wants a key, fetch and verify the right key rather than disabling checks.

## AUR package replaced by official repos

When `pacman -Qm` shows a package that now exists in the official repos:

1. Confirm the official package is the same upstream project, not just a name collision.
2. Remove the AUR package and install the official one:

   ```bash
   sudo pacman -Rns aur_package_name
   sudo pacman -S official_package_name
   ```

3. If `pacman -Syu` shows a file conflict, the AUR package likely owns files the official package
   wants. Resolve the conflict explicitly - do not blindly `--overwrite`.

## `.pacnew`, `.pacsave`, and config drift

Arch does not silently merge your config changes for you.

- `.pacnew` means the package shipped a new default config and your local file was preserved.
- `.pacsave` means the package was removed and its old config was preserved.
- Review these after upgrades, especially for system services, bootloader configs, and package manager settings.

Typical pattern:

```bash
ls /etc/*.pacnew /etc/*.pacsave 2>/dev/null
```

If `pacman-contrib` is installed, use `pacdiff` to review and merge safely.

## Mirror and keyring issues

When sync or signature problems appear, check the boring causes first:

1. Time drift
2. dead or slow mirrors
3. stale keyring
4. network interception or proxy weirdness

Common repair moves:

```bash
sudo pacman -Syu archlinux-keyring
sudo pacman -Fy
```

Use a mirror tool only after you confirm the current mirrorlist is the problem. On CachyOS, also
check whether Arch mirrors and Cachy mirrors are both configured as expected.

## What NOT to do

- Do not advise `pacman -Sy package_name` as a routine install path.
- Do not mass-delete `pacman -Qdt` results without reviewing what those packages are.
- Do not assume every `pacman` conflict is solved by `--overwrite`.
- Do not treat AUR packages as if they came with the same support and trust model as official repos.
- Do not forget that derivatives may ship extra repos, wrappers, or package replacements on top of Arch.
