# Binary Analysis Methodology

Reverse engineering, patch diffing, dynamic analysis, and fuzzing methodology for compiled
software. Use when the target is a binary without source code, or when analyzing what a
security patch actually fixed.

---

## 1. Static Analysis (Reverse Engineering)

### Initial Assessment

```bash
# File type, architecture, endianness
file TARGET

# Security mitigations
checksec --file=TARGET 2>/dev/null || {
  echo "=== Manual checksec ==="
  readelf -l TARGET 2>/dev/null | grep GNU_STACK     # NX (look for RW, not RWE)
  readelf -l TARGET 2>/dev/null | grep GNU_RELRO     # RELRO
  readelf -d TARGET 2>/dev/null | grep BIND_NOW      # Full RELRO
  readelf -s TARGET 2>/dev/null | grep __stack_chk   # Stack canary
  file TARGET | grep -q "Position-Independent" && echo "PIE: enabled"
}

# Symbols present?
nm TARGET 2>/dev/null | wc -l  # 0 = stripped

# Imports -- what functions does it call?
readelf -r TARGET 2>/dev/null | grep -i 'plt' | head -30
# Or for dynamic symbols:
readelf --dyn-syms TARGET 2>/dev/null | head -30
```

**Mitigation impact on exploitation:**

| Mitigation | Effect | Bypass complexity |
|------------|--------|-------------------|
| NX (DEP) | No execute on stack/heap | Medium -- requires ROP/JOP |
| ASLR | Randomized addresses | Medium -- needs info leak |
| Stack Canary | Detects stack smashing | Medium -- needs canary leak or format string |
| Full RELRO | GOT read-only after load | High -- can't overwrite GOT entries |
| PIE | Code at random address | Medium -- needs code address leak |
| CFI | Control flow integrity | High -- limits valid call targets |

### Ghidra Workflow

```bash
# Headless analysis (script is at $GHIDRA_HOME/support/analyzeHeadless)
analyzeHeadless /tmp/ghidra_project PROJECT_NAME -import TARGET -postAnalysis

# Or interactive (recommended for research):
ghidra &
# File -> New Project -> Import TARGET -> Auto Analyze (accept defaults)
```

**Analysis priorities in Ghidra:**

1. **Find entry points**: `main`, exported functions, signal handlers, network-facing functions
2. **Identify dangerous function calls** (Window -> Symbol References):
   - `strcpy`, `strcat`, `sprintf`, `gets` -- unbounded copies
   - `malloc`, `free` -- track allocation/deallocation pairs for UAF
   - `memcpy`, `memmove` -- check size parameter origin
   - `system`, `popen`, `execve` -- command execution
   - `recv`, `read`, `fread` -- data ingestion points
3. **Trace data flow**: from input functions to dangerous sinks
4. **Check function boundaries**: do buffer sizes match between caller and callee?
5. **Examine error paths**: decompiled error handlers often skip cleanup (UAF, leak)

### Rizin/Cutter Workflow

```bash
# Quick analysis
rizin -A TARGET

# List functions
[0x00401000]> afl

# Decompile function
[0x00401000]> pdg @ sym.parse_input

# Find cross-references to dangerous functions
[0x00401000]> axt @ sym.imp.strcpy

# String references
[0x00401000]> iz | grep -i 'error\|fail\|password\|key\|token'
```

### Windows PE Analysis

Windows binaries (PE/PE32+) have a different toolchain and mitigation landscape.

**Initial assessment:**

```powershell
# PE headers
dumpbin /headers TARGET.exe

# Imports (attack surface -- which APIs does it call?)
dumpbin /imports TARGET.exe
# Flag: LoadLibrary, CreateProcess, ShellExecute, WinExec, system,
#       recv, ReadFile, InternetReadFile, URLDownloadToFile

# Check mitigations
winchecksec.exe TARGET.exe
```

**Windows-specific mitigations:**

| Mitigation | Effect | Bypass complexity |
|------------|--------|-------------------|
| ASLR (DYNAMIC_BASE) | Randomized image base | Medium -- needs info leak |
| DEP (NX_COMPAT) | No execute on data pages | Medium -- requires ROP |
| CFG (GUARD_CF) | Validates indirect call targets | High -- limited call targets |
| ACG | Blocks dynamic code generation | High -- no rwx pages, no JIT spray |
| CET (Shadow Stack) | Hardware-backed return address protection | Very high |
| SafeSEH / SEHOP | SEH chain validation | Medium -- can't overwrite SEH easily |
| GS (Stack Cookie) | Stack buffer overrun detection | Medium -- needs cookie leak |

**Ghidra works for PE** -- import the .exe/.dll the same way as ELF. Auto-analysis
handles PE format, PDB symbol loading (File -> Load PDB), and Windows API resolution.

**x64dbg** (OSS debugger, Windows equivalent of GDB+GEF):
- Load binary, set breakpoints on imported API calls
- Trace execution with conditional breakpoints
- Memory map view for heap/stack inspection
- Built-in pattern scanning and reference finding

**WinDbg** (Microsoft debugger, best for kernel-mode and crash dump analysis):
```
# Analyze a crash dump
.sympath srv*c:\symbols*https://msdl.microsoft.com/download/symbols
!analyze -v

# Check mitigations on running process
!exploitable
!heap -s

# Set breakpoint on API call
bp kernel32!CreateFileW
```

---

## 1.5. Firmware Extraction

For embedded/IoT targets, the binary must be extracted from the firmware image first.

```bash
# Identify firmware format and embedded filesystems
binwalk firmware.bin

# Extract all identified components
binwalk -e firmware.bin
# Extracted files land in _firmware.bin.extracted/

# Specific filesystem extraction
# SquashFS (very common in router/IoT firmware):
unsquashfs filesystem.squashfs

# JFFS2:
jefferson firmware.jffs2 -d output/

# UBI (NAND flash):
ubireader_extract_files firmware.ubi
```

**After extraction:**
- Look for ELF binaries in `/usr/bin/`, `/usr/sbin/`, `/usr/lib/` -- these are your analysis targets
- Check `/etc/` for hardcoded credentials, default configs, private keys
- Examine init scripts (`/etc/init.d/`, systemd units) to understand what services run
- Cross-compile GDB for the target architecture if dynamic analysis is needed (or use QEMU user-mode emulation)

**QEMU user-mode emulation** (run target-architecture binaries on your host):
```bash
# Example: ARM binary on x86 host
sudo apt install qemu-user-static binfmt-support
# Copy target libraries
cp -r extracted_rootfs/lib/ /tmp/target_libs/
# Run with library path
qemu-arm-static -L /tmp/target_libs/ ./target_binary
```

---

## 2. Patch Diffing

The fastest path to 0-day variants. When a vendor releases a security patch, the diff
reveals the vulnerability class and location. Then search for similar patterns nearby.

### Obtaining Pre-Patch and Post-Patch Binaries

**Open source**: check out the commit before and after the fix, build both.

```bash
# Find the fix commit
git log --oneline --all --grep='CVE-XXXX-XXXXX'
git log --oneline --all --grep='security fix'

# Build pre-patch
git checkout COMMIT_BEFORE_FIX^
make clean && make

# Build post-patch
git checkout COMMIT_AFTER_FIX
make clean && make
```

**Closed source**: download the previous version from archive sites, vendor archives, or
package manager caches.

```bash
# Debian/Ubuntu: download specific version
apt download package=VERSION_OLD
apt download package=VERSION_NEW

# Extract
dpkg -x package_old.deb /tmp/old/
dpkg -x package_new.deb /tmp/new/

# Arch Linux: check pacman cache
ls /var/cache/pacman/pkg/package-*.pkg.tar.zst
```

### Diffing with BinDiff (Ghidra Integration)

1. Import both binaries into Ghidra, run auto-analysis on both
2. Install BinDiffHelper extension (Ghidra -> File -> Install Extensions)
3. Export both as BinExport files
4. Run BinDiff: `bindiff old.BinExport new.BinExport`
5. Focus on functions with similarity score between 0.5 and 0.95 -- these are the modified ones

### Diffing with Diaphora (Alternative)

```bash
# Generate SQLite databases from Ghidra
# In Ghidra scripting console:
# Run Diaphora export script on both binaries

# Diff the databases
python3 diaphora.py old.sqlite new.sqlite
```

### What to Look For in Diffs

| Diff pattern | Likely vulnerability class |
|--------------|--------------------------|
| Added bounds check on buffer size | Buffer overflow |
| Added NULL check before use | Null pointer deref or UAF |
| Changed `strcpy` to `strncpy` | Stack/heap buffer overflow |
| Added integer overflow check | Integer overflow -> heap overflow |
| Added lock/mutex around operation | Race condition |
| Changed `==` to constant-time compare | Timing side channel |
| Added input validation/sanitization | Injection |
| Changed deserialization config | Insecure deserialization |

### Variant Analysis from Diff

After understanding what the patch fixed:

1. Identify the **root cause pattern** (not just the specific instance)
2. Search the *same binary* for similar patterns the patch didn't cover
3. Search *related binaries* (same vendor, same codebase, forked projects)
4. Check if the fix itself introduces a new bug (regression, incomplete fix)

---

## 3. Dynamic Analysis

### GDB with Extensions

```bash
# Install GEF (GDB Enhanced Features) -- recommended for exploit dev
bash -c "$(curl -fsSL https://gef.blah.cat/sh)"

# Or pwndbg
git clone https://github.com/pwndbg/pwndbg && cd pwndbg && ./setup.sh
```

**Common debugging workflow:**

```bash
# Run with arguments
gdb -q ./TARGET
(gdb) run ARGS

# Set breakpoint at interesting function
(gdb) break *0xADDRESS
(gdb) break function_name

# Examine crash state
(gdb) bt                    # backtrace
(gdb) info registers        # register state
(gdb) x/32xw $esp          # examine stack
(gdb) x/s $rdi             # examine string argument
(gdb) heap chunks           # GEF: heap state
(gdb) vmmap                 # GEF: memory map

# Watch for specific conditions
(gdb) watch *(int*)0xADDRESS  # break on memory write
(gdb) catch signal SIGSEGV     # catch segfault
```

### Syscall Tracing

```bash
# Trace all syscalls
strace -f -e trace=all ./TARGET ARGS 2>&1 | head -200

# Focus on file operations
strace -f -e trace=file ./TARGET ARGS

# Focus on network operations
strace -f -e trace=network ./TARGET ARGS

# Library call tracing
ltrace -f ./TARGET ARGS 2>&1 | head -200

# Trace specific library calls
ltrace -e 'malloc+free+strcpy+memcpy' ./TARGET ARGS
```

### Sanitizer-Instrumented Builds

If you have source code, build with sanitizers for amplified bug detection:

```bash
# AddressSanitizer (buffer overflow, UAF, double-free, stack-use-after-return)
gcc -fsanitize=address -g -O1 target.c -o target_asan

# MemorySanitizer (uninitialized memory reads)
clang -fsanitize=memory -g -O1 target.c -o target_msan

# UndefinedBehaviorSanitizer (integer overflow, null deref, alignment)
gcc -fsanitize=undefined -g -O1 target.c -o target_ubsan

# ThreadSanitizer (data races)
gcc -fsanitize=thread -g -O1 target.c -o target_tsan

# Combine (ASan + UBSan is common)
gcc -fsanitize=address,undefined -g -O1 target.c -o target_combo
```

Run with ASan environment tuning:
```bash
ASAN_OPTIONS=detect_leaks=1:halt_on_error=0:print_stats=1 ./target_asan ARGS
```

---

## 4. Fuzzing

### AFL++ Workflow

```bash
# Instrument the binary (requires source)
CC=afl-clang-fast CXX=afl-clang-fast++ ./configure
make clean && make

# Or compile directly
afl-clang-fast -fsanitize=address -g target.c -o target_fuzz

# Create corpus directory with seed inputs
mkdir -p corpus/
# Add representative inputs (small, diverse, covering different code paths)
echo "minimal valid input" > corpus/seed1
cp existing_testcases/* corpus/

# Run fuzzer
afl-fuzz -i corpus/ -o findings/ -- ./target_fuzz @@
# @@ = placeholder for input file path

# For stdin-based targets:
afl-fuzz -i corpus/ -o findings/ -- ./target_fuzz

# Parallel fuzzing (multiple cores)
# Master:
afl-fuzz -M fuzzer01 -i corpus/ -o findings/ -- ./target_fuzz @@
# Secondaries:
afl-fuzz -S fuzzer02 -i corpus/ -o findings/ -- ./target_fuzz @@
afl-fuzz -S fuzzer03 -i corpus/ -o findings/ -- ./target_fuzz @@
```

### Writing Effective Fuzz Harnesses

**The harness isolates the target function for fuzzing:**

```c
// harness.c -- fuzz a parsing function
#include <stdint.h>
#include <stddef.h>

// Include or link the target code
extern int parse_input(const uint8_t *data, size_t size);

// AFL++ persistent mode (much faster than fork mode)
__AFL_FUZZ_INIT();

int main(void) {
    __AFL_INIT();
    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;
        if (len < 4) continue;  // minimum viable input
        parse_input(buf, len);
    }
    return 0;
}
```

**Harness design principles:**
- Target the smallest unit that processes untrusted input (parser, decoder, handler)
- Initialize state once outside the loop, reset per iteration
- Skip obviously invalid inputs early (minimum length check)
- Don't catch signals -- let ASan/fuzzer handle crashes
- Use persistent mode for 10-20x speedup

### libFuzzer Harness (Alternative)

```c
// fuzz_target.c
#include <stdint.h>
#include <stddef.h>

extern int parse_input(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 4) return 0;
    parse_input(data, size);
    return 0;
}
```

```bash
clang -fsanitize=fuzzer,address -g fuzz_target.c target.c -o fuzzer
./fuzzer corpus/ -max_len=4096 -jobs=4
```

### Crash Triage

```bash
# Reproduce crash
./target_fuzz < findings/crashes/id:000000,...

# Get crash details with ASan
ASAN_OPTIONS=print_stats=1 ./target_asan < findings/crashes/id:000000,...

# Minimize crash input
afl-tmin -i findings/crashes/id:000000,... -o minimized.bin -- ./target_fuzz @@

# Deduplicate crashes by unique ASan stack trace
# (afl-cmin is for corpus minimization, not crash dedup)
for crash in findings/crashes/id:*; do
  ASAN_OPTIONS=print_stats=1 ./target_asan < "$crash" 2>&1 | grep '#[0-9]' | md5sum
done | sort | uniq -w 32 --all-repeated=separate
```

**Crash classification:**

| Signal | Likely cause |
|--------|-------------|
| SIGSEGV (read) | NULL deref, UAF (read), out-of-bounds read |
| SIGSEGV (write) | Buffer overflow, UAF (write), out-of-bounds write |
| SIGABRT | ASan detection, assertion failure, double-free |
| SIGFPE | Division by zero, integer overflow (with UBSan trap) |
| SIGBUS | Unaligned access, mmap beyond file |

### Language-Specific Fuzzing

**Go:**
```bash
# Built-in fuzzing (Go 1.18+)
# Write fuzz test:
# func FuzzParse(f *testing.F) {
#     f.Add([]byte("seed"))
#     f.Fuzz(func(t *testing.T, data []byte) {
#         Parse(data)
#     })
# }
go test -fuzz=FuzzParse -fuzztime=60s ./...
```

**Rust:**
```bash
cargo install cargo-fuzz
cargo fuzz init
# Edit fuzz/fuzz_targets/fuzz_target_1.rs
cargo fuzz run fuzz_target_1 -- -max_total_time=300
```

**Java (Jazzer):**
```java
// FuzzTarget.java
import com.code_intelligence.jazzer.api.FuzzedDataProvider;

public class FuzzTarget {
    public static void fuzzerTestOneInput(FuzzedDataProvider data) {
        String input = data.consumeRemainingAsString();
        TargetClass.parse(input);
    }
}
```

```bash
jazzer --target_class=FuzzTarget --cp=target.jar
```

---

## 5. Exploit Prototyping (Binary)

Once a vulnerability is confirmed, prototype the exploit to assess actual impact.

### Memory Corruption Exploit Skeleton (x86-64 Linux)

```python
#!/usr/bin/env python3
"""PoC skeleton -- adapt to specific vulnerability."""
from pwn import *

context.arch = 'amd64'
context.os = 'linux'

# Target binary
binary = ELF('./target')
# libc (if needed for ret2libc)
# libc = ELF('./libc.so.6')

def exploit():
    # Connect to target
    p = process('./target')
    # p = remote('target.host', PORT)  # for remote

    # Phase 1: Information leak (defeat ASLR)
    # ... send crafted input to leak address ...
    # leaked = u64(p.recv(8))
    # base = leaked - KNOWN_OFFSET

    # Phase 2: Build payload
    payload = b'A' * OFFSET_TO_RIP  # overflow to return address
    # ... ROP chain or shellcode ...

    # Phase 3: Send and get shell
    p.sendline(payload)
    p.interactive()

if __name__ == '__main__':
    exploit()
```

### Crash-to-Exploit Assessment

Not every crash is exploitable. Evaluate:

| Factor | Exploitable | Not exploitable |
|--------|------------|-----------------|
| Crash type | Write to controlled address | Read from NULL |
| Controlled data | Attacker controls what's written | Only controls trigger, not content |
| Mitigations | Some bypassed or bypassable | Full CFI + sandboxed |
| Crash location | In exploitable function (allocator, vtable) | In safe abort handler |
| Reliability | Deterministic crash | Timing-dependent, low probability |

**Rule of thumb**: if you control what is written and where it's written, it's probably
exploitable given enough effort. If you only control that a crash happens, it's a DoS.
