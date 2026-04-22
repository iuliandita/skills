# Packages and Repos

Use this when the problem is apt, dpkg, PPAs, packages, or third-party repos.

## Quick checks
- `apt update`
- `apt-cache policy package`
- `apt-mark showhold`
- `dpkg -l | grep '^ii'`
- `apt -f install` when dependency state is broken

## Common moves
- Prefer `apt install package` for new installs.
- Use `apt full-upgrade` when package transitions require removals or replacements.
- Use `dpkg --configure -a` after interrupted package operations.
- Use `add-apt-repository` only after checking the source and key.
- Use `ppa-purge` or manual downgrade when a PPA breaks the system.
