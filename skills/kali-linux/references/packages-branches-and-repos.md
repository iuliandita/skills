# Kali Packages, Branches, and Repos

Kali package health starts with one question: which branch model is this machine following?
If you skip that question, every later fix is guesswork.

## Branch model

Official Kali docs describe these main lanes:

| Branch | What it is | Default use |
|--------|------------|-------------|
| `kali-rolling` | main continuously updated branch | default for most users |
| `kali-last-snapshot` | frozen release-like branch between Kali releases | safer, calmer installs |
| `kali-experimental` | partial work-in-progress packages | special cases only |
| `kali-bleeding-edge` | selected packages auto-updated from upstream git | fast and risky |
| `kali-dev` | development integration branch | maintainers and testers |

Practical rule: use either `kali-rolling` or `kali-last-snapshot` as the full distro lane. Do not
enable both just because they sound compatible.

## Healthy source-list patterns

### Rolling install
```bash
grep -Rhv '^#\|^$' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>&1 || true
```

Expected shape is one clear Kali lane, not a soup of Kali plus random Debian suites.

### Snapshot users
If the user wants calmer behavior, verify they intentionally track the snapshot lane rather than
accidentally running stale mirrors.

## Core checks

```bash
apt-cache policy 2>&1 || true
apt-cache policy kali-archive-keyring kali-defaults kali-linux-core kali-linux-default 2>&1 || true
apt list --upgradable 2>&1 | tail -n +2
```

What these tell you:
- `apt-cache policy` shows which repos are active and which release wins package selection
- `kali-archive-keyring` tells you whether repo trust is the real issue
- `kali-defaults` is a good anchor for Kali-specific behavior
- upgradable package count tells you whether the machine is merely behind versus actually broken

## Upgrade stance

Kali docs recommend:

```bash
sudo apt update
sudo apt full-upgrade -y
```

Use `full-upgrade` when package transitions matter. Kali is rolling enough that a half-updated
state often causes more pain than the tool the user was trying to install.

## Mirrors and signatures

For images and mirrors, prefer verified downloads and official repo metadata.
Kali publishes SHA256 sums and GPG signatures for release images. Use those instead of trusting a
random ISO someone found on a USB stick.

## Common package-state failures

### Stale keyring
Symptoms:
- signature warnings
- repo metadata rejected
- packages seem present but updates fail

Check:
```bash
apt-cache policy kali-archive-keyring 2>&1 || true
```

### Branch mixing
Symptoms:
- weird dependency conflicts
- package version pinball
- tools missing expected binaries after install

Check:
```bash
grep -Rhv '^#\|^$' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>&1 || true
apt-cache policy 2>&1 || true
```

### Transitional packages
Kali uses metapackages and some transitional packages. A package can install cleanly yet not be
where the user expects. Check dependencies and the real binary package instead of assuming the
metapackage owns the executable.

## Recovery pattern

1. Confirm the intended branch.
2. Clean up source lists until one main lane wins.
3. Update package metadata.
4. Run `apt full-upgrade`.
5. Re-check the exact package and binary.

## What not to do

- Do not bolt Debian stable, testing, or sid repos onto Kali casually.
- Do not enable every Kali branch at once.
- Do not treat a broken live ISO the same way as an installed root filesystem.
- Do not assume a metapackage means a command should exist under the same name.
