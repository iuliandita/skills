---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "NixOS stable"
    version: "26.05 Yarara (released 2026-05-30, maintained until 2026-12-31)"
    source: "https://nixos.org/blog/announcements/2026/nixos-2605/"
  - tool: "NixOS previous stable"
    version: "25.11 Xantusia (EOL 2026-06-30)"
    source: "https://nixos.org/manual/nixos/stable/release-notes"
  - tool: "NixOS upcoming"
    version: "26.11 Zokor (planned 2026-11-23, branch-off 2026-11-16)"
    source: "https://github.com/NixOS/nixpkgs/issues/567567"
  - tool: "Nix"
    version: "2.35.2"
    source: "https://github.com/NixOS/nix/releases"
  - tool: "home-manager"
    version: "release-26.05"
    source: "https://github.com/nix-community/home-manager/branches"
  - tool: "nix-darwin"
    version: "nix-darwin-26.05"
    source: "https://github.com/nix-darwin/nix-darwin/branches"
  - tool: "Linux kernel default for NixOS 26.05"
    version: "6.18 LTS"
    source: "https://nixos.org/blog/announcements/2026/nixos-2605/"
---

# NixOS target versions

Pins referenced by `../SKILL.md`. Migrated from the SKILL.md block labelled October 2026.
Pin versions only when they shape compatibility or troubleshooting. For ordinary package
work, trust the live channel or flake lock over a stale table. Reverify before use if the
receipt exceeds 120 days.

| Component | Version or date | Why it matters |
|-----------|-----------------|----------------|
| NixOS stable | 26.05 "Yarara" (May 2026) | current stable, released 2026-05-30, maintained until 2026-12-31 |
| NixOS previous stable | 25.11 "Xantusia" (Nov 2025) | EOL 2026-06-30; upgrade off it now |
| NixOS upcoming | 26.11 "Zokor" (planned 2026-11-23) | Branch-off 2026-11-16 per the release schedule (NixOS/nixpkgs#567567); do not target an unreleased version for production |
| Nix (CLI / daemon) | 2.35.2 | stable upstream; verify the packaged distro lane before upgrading |
| `nixos-rebuild-ng` | only implementation in 26.05 | Python rewrite; default since 25.11, Bash implementation and `system.rebuild.enableNg` removed in 26.05 |
| home-manager | release-26.05 (May 2026) | matches NixOS 26.05; unstable tracks nixos-unstable |
| nix-darwin | nix-darwin-26.05 | release branch matching nixpkgs 26.05; `master` tracks nixpkgs-unstable |
| Determinate Nix | downstream, flakes-on by default | validated distribution; parallel eval, lazy trees |
| Lix | fork of Nix | compatibility-focused fork; Meson build, improved errors |
| Kernel default for 26.05 | Linux 6.18 LTS | 26.05 defaults to Linux 6.18 LTS and removed `linux_hardened` (source: https://nixos.org/blog/announcements/2026/nixos-2605/); consistent with `hardware-desktop-and-kernel.md` |
