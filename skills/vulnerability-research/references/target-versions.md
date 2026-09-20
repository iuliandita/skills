# Zero-Day Target Versions

September 2026 snapshot. Release targets checked 2026-09-10 against upstream release pages.
Verify current releases before pinning.

- [CodeQL CLI](https://github.com/github/codeql-cli-binaries/releases/tag/v2.27.0): v2.27.0
- [Semgrep](https://github.com/semgrep/semgrep/releases/tag/v1.176.0): v1.176.0
- [Joern](https://github.com/joernio/joern/releases/tag/v4.0.624): v4.0.624
- [Ghidra](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.3_build): 12.1.3
- [AFL++](https://github.com/AFLplusplus/AFLplusplus/releases/tag/v5.03c): v5.03c. Check the tagged license and compiler-support matrix before bundling; this refresh did not confirm the former AGPL/LLVM 23 claims.
- [Rizin](https://github.com/rizinorg/rizin/releases/tag/v0.9.1): v0.9.1. [CVE-2026-22780](https://github.com/rizinorg/rizin/security/advisories/GHSA-f3v7-xhmj-9cjj) affects versions before 0.8.2; 0.8.2 fixes the Mach-O heap overflow.
