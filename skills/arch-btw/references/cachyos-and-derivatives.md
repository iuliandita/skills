# CachyOS and Other Arch Derivatives

CachyOS stays close enough to Arch that upstream habits still matter, but it layers on optimized
repos, custom kernels, scheduler tooling, and snapshot-friendly defaults. Treat those as real
differences, not branding.

## CachyOS quick model

| Area | What changes from vanilla Arch |
|------|--------------------------------|
| Repos | Optimized `x86-64-v3`, `x86-64-v4`, and `znver4` builds exist |
| Kernels | Multiple Cachy kernel variants and scheduler-focused builds are available |
| Packaging | The `cachyos` repo can install a forked `pacman` package |
| Recovery posture | Btrfs + Snapper + `snap-pac` make rollback more convenient on default installs |
| Tooling | Kernel Manager, settings helpers, and other Cachy-specific tooling exist |

## Optimized repos

CachyOS recompiles Arch packages for:

- `x86-64-v3`
- `x86-64-v4`
- `znver4`

CPU capability matters. The official docs use:

```bash
/lib/ld-linux-x86-64.so.2 --help | grep supported
gcc -march=native -Q --help=target 2>&1 | awk '/-march=/{print $2}'
```

Two important cautions:

- Intel Alder Lake and newer can report `x86-64-v4` support badly enough to cause confusion because AVX-512 is not reliably usable across P-cores and E-cores.
- The `cachyos` repo can bring in a forked `pacman` package. If you only want optimized package repos, keep that distinction explicit.

## CachyOS kernel stance

Relevant official pieces:

- `linux-cachyos` is the main performance-tuned kernel line
- `linux-cachyos-eevdf` is a distinct kernel variant
- the Kernel Manager can install kernels from Arch repos or build Cachy-specific custom kernels
- scheduler tooling can persist choices through `/etc/scx_loader.toml`

Operational guidance:

- Prefer a shipped Cachy kernel before jumping into custom compilation.
- Keep at least one known-good kernel entry when testing scheduler or kernel changes.
- On remote hosts, default to the least surprising kernel path first.

## Snapshots on CachyOS

CachyOS documents `snap-pac` as a default integration with Snapper for package operations.

Practical implication:

- package installs, upgrades, and removals via `pacman` can create before/after snapshots automatically
- that makes rollback easier, but it does not remove the need for real backups
- old snapshots still need cleanup and bootloader integration varies by loader

Do not promise snapshot recovery for bootloader damage or disk failure.

## Suggested CachyOS workflow

1. confirm repo tier and architecture target
2. confirm whether the host uses the forked `pacman` package or vanilla Arch `pacman`
3. confirm current kernel line
4. confirm snapshot tooling and bootloader
5. make one change at a time

## Other Arch derivatives

### EndeavourOS

- Very close to Arch in day-to-day package and service behavior
- Ships extra repo content and defaults, but Arch workflows usually transfer cleanly
- If something is broken, start with vanilla Arch assumptions and only then inspect Endeavour-specific extras

### Manjaro

- Uses its own branches and package timing rather than tracking Arch repos directly
- AUR advice needs more caution because repo age and dependency timing can diverge
- Be explicit about branch state before recommending package or kernel moves

## What NOT to do

- Do not assume every Arch tip applies unchanged once optimized repos or forked `pacman` are involved.
- Do not recommend repo-tier changes without checking CPU support first.
- Do not sell snapshots as backups.
- Do not treat derivative-specific wrappers as the primary truth when `pacman`, systemd, and boot artifacts say otherwise.
