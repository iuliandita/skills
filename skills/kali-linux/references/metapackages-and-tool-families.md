# Kali Metapackages and Tool Families

Kali is easier to manage when you think in bundles and workflows instead of one giant package dump.
The official metapackage docs and `kali-meta` page are the map.

## Big-picture install bundles

| Metapackage | What it does | Good default |
|-------------|--------------|--------------|
| `kali-linux-core` | base Kali system plus core offensive essentials such as `netcat-traditional` and `tcpdump` | minimal Kali with the right flavor |
| `kali-linux-headless` | default install without GUI | remote VM, cloud lab, thin box |
| `kali-linux-default` | tools included in normal desktop images | most general-purpose Kali installs |
| `kali-linux-arm` | ARM-suitable tool mix | SBCs and ARM devices |
| `kali-linux-nethunter` | NetHunter-related tooling | mobile and Android-adjacent workflows |
| `kali-linux-large` | older larger desktop bundle | legacy expectations |
| `kali-linux-everything` | every metapackage and tool bundle | only when disk, bandwidth, and patience are cheap |
| `kali-linux-labs` | intentionally vulnerable practice environments | controlled training only |

Practical rule: start with `kali-linux-default` or a small focused install. Reach for
`kali-linux-everything` only when the machine truly exists to be a huge toolbox.

## Desktop and system metapackages

Kali also exposes system and desktop bundles such as:
- `kali-system-core`
- `kali-system-cli`
- `kali-system-gui`
- `kali-desktop-core`
- `kali-desktop-gnome`
- `kali-desktop-xfce`
- `kali-desktop-kde`
- `kali-desktop-i3`

Those matter because many "tool problems" are actually desktop or session problems.
Burp, browser helpers, proxy tools, capture utilities, and USB GUI apps care about the session.

## Workflow-oriented tool families

The Kali metapackage docs group tools by job. That grouping is the fastest way to decide what to
install.

### `kali-tools-information-gathering`
Use for reconnaissance and discovery before touching the target deeply.
Examples from the Kali tools index include discovery and recon-oriented tooling such as `theharvester`.

### `kali-tools-vulnerability`
Use for vulnerability assessment and surface mapping.
Examples from the official tools index and release notes include `nuclei`, `nikto`, and GVM-related tooling where available.
If the user wants broad defensive review of their own project rather than Kali package selection,
hand off to **security-audit**.

### `kali-tools-web`
Use for web testing and content discovery.
Examples confirmed on the Kali tools pages include:
- `sqlmap` - SQL injection automation
- `gobuster` - fast content and directory discovery
- `dirb`, `dirsearch`, `ffuf`, `feroxbuster` - wordlist-driven content discovery
- `whatweb` - web fingerprinting
- `wpscan` - WordPress assessment
- `burpsuite` and `caido` - intercepting and manual web workflow
- `sstimap` and `XSStrike` - SSTI and XSS-focused testing in the 2026.1 release lane

### `kali-tools-passwords`
Use for credential auditing and cracking workflows.
Examples confirmed on Kali tool pages include:
- `hashcat` - offline cracking with GPU-friendly workflows
- `hydra` - online login brute forcing and service credential testing

### `kali-tools-wireless`
Use when the user needs the family view, not one protocol silo.
This umbrella overlaps with narrower hardware bundles such as:
- `kali-tools-802-11`
- `kali-tools-bluetooth`
- `kali-tools-rfid`
- `kali-tools-sdr`
- `kali-tools-voip`

Examples confirmed on Kali tool pages include:
- `aircrack-ng` suite - Wi-Fi capture, replay, and cracking workflow
- `kismet` - broad wireless discovery and capture ecosystem
- `reaver` and `wash` - WPS testing
- `wifite`, `fluxion`, `wifiphisher`, `airgeddon` - campaign-style wireless testing helpers

### `kali-tools-reverse-engineering`
Use for binary inspection and reversing workflows.
If the task becomes deep vulnerability discovery, exploitability research, or fuzzing strategy,
hand off to **zero-day**.
The 2026.1 release also added `GEF`, which improves GDB-based reversing and exploit debugging.

### `kali-tools-exploitation`
Use for exploitation tooling packages and launchers.
Examples confirmed on Kali tool pages include `metasploit-framework` and its many helper commands
such as `msfconsole` and `msfvenom`.
If the user is asking how to conduct exploitation on an authorized target rather than how to keep
Kali healthy, hand off to **lockpick**.

### `kali-tools-post-exploitation`
Use for post-access tooling families and operator workflow packages.
Again, once the question becomes operational tradecraft or escalation flow, this skill should hand
off to **lockpick**.

### `kali-tools-forensics`
Use for live and offline evidence collection and analysis.
Keep this separate from offensive workflow and from generic Linux package debugging.

### `kali-tools-reporting`
Use for writing up findings, screenshots, and engagement outputs.
It is easy to ignore, but a complete Kali install for real work usually needs reporting tools too.

### Specialist bundles
Kali also ships targeted bundles such as:
- `kali-tools-gpu`
- `kali-tools-hardware`
- `kali-tools-crypto-stego`
- `kali-tools-fuzzing`
- `kali-tools-windows-resources`

If the request moves from installing fuzzing tools to designing fuzzing strategy, crash triage, or
novel vulnerability discovery, hand off to **zero-day**.

These are better than shotgun-installing random packages when the user already knows the workflow.

## Tool pages worth remembering

The official Kali tools index is useful because it shows three things at once:
- the tool page
- the package name
- the installed command name

That helps when a user says "I installed it but the command is missing." On Kali, the package,
page, and command name are often close, but not always identical.

Use this quick lookup flow:

```bash
apt-cache policy package-name 2>&1 || true
apt-cache depends package-name 2>&1 || true
dpkg -L package-name 2>&1 || true
command -v expected-command 2>/dev/null || true
```

Check in this order:
1. did the package really install?
2. is the package a metapackage or transitional package?
3. did the real binary land in a different package?
4. is the binary name different from the package name?

Do not assume package name, tool page name, and command name are the same string.

## Safe routing boundaries

- Use this skill to choose and maintain the Kali package set.
- Use **lockpick** when the user moves from "what should I install" to "how do I escalate or pivot on an authorized target".
- Use **zero-day** when the user moves from "which reversing tools do I need" to "help me discover a novel bug or build a PoC".
- Use **security-audit** when the user is defending an application or service rather than working the Kali workstation itself.
