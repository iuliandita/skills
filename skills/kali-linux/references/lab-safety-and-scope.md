# Kali Lab Safety and Scope

Kali lowers the friction to run security tooling. It does not lower the bar for authorization.

## Baseline rules

- Use Kali tooling only inside an authorized scope.
- Keep practice targets and production systems separate.
- Prefer disposable VMs, snapshots, and isolated USB media.
- Treat `kali-linux-labs` as intentionally vulnerable training content, not workstation furniture.

## Recommended lab shapes

| Shape | Good for | Why |
|-------|----------|-----|
| Throwaway VM | most practice and package testing | easy snapshots and rollback |
| Dedicated USB install | field kit or travel box | isolated from main workstation |
| Nested lab in virtualization stack | multi-host training ranges | fast reset and repeatable states |
| NetHunter lab device | mobile hardware and HID practice | keeps phone-specific quirks contained |

## Good habits

- snapshot before large metapackage installs
- snapshot before branch changes
- verify image checksums before first boot
- keep notes on which adapters, SDRs, and cables actually work
- separate "tooling install complete" from "operator workflow complete"

## Hand-off boundaries

- For live offensive workflow and escalation methodology, move to **lockpick**.
- For novel bug hunting and proof-of-concept work, move to **zero-day**.
- For defensive review of the target's code or config, move to **security-audit**.

## What not to normalize

- installing giant metapackages on a production laptop without a rollback plan
- using intentionally vulnerable labs on the same box that holds client data
- mixing experimental branches just to grab one shiny tool
- assuming a successful install means safe or legal use
