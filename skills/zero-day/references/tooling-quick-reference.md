# Zero-Day Tooling Quick Reference

Use this catalog when you need to choose tooling after the target profile is clear.
Don't load it by default; open only the tools relevant to the current target.

| Tool | Purpose | Install |
|------|---------|---------|
| CodeQL | Semantic code analysis, variant queries | `gh codeql` or GitHub releases |
| Semgrep | Pattern + taint analysis (cross-file with Pro) | `pip install semgrep` or `brew` |
| Joern | Code property graph queries | `joern` binary from GitHub releases |
| Ghidra | Binary reverse engineering, decompilation | ghidra-sre.org or GitHub releases |
| Rizin + Cutter | OSS reverse engineering + GUI | `rizin` package or GitHub releases |
| AFL++ | Coverage-guided fuzzing | `apt install afl++` or build from source |
| GDB + GEF/pwndbg | Dynamic binary analysis | `apt install gdb` + plugin |
| pwntools | Exploit development framework (Python) | `pip install pwntools` |
| BinDiff | Binary patch diffing | Bundled with Ghidra (BinDiffHelper) or standalone |
| Diaphora | OSS binary diffing (IDA/Ghidra) | github.com/joxeankoret/diaphora |
| strace/ltrace | Syscall and library call tracing | `apt install strace ltrace` |
| checksec | Binary mitigation detection (Linux) | `apt install checksec` |
| winchecksec | Binary mitigation detection (Windows) | github.com/trailofbits/winchecksec |
| x64dbg | Dynamic binary analysis (Windows) | x64dbg.com |
| searchsploit | Exploit-DB CLI search | `apt install exploitdb` |
| OSS-Fuzz-Gen | AI-generated fuzz targets | github.com/google/oss-fuzz-gen |
