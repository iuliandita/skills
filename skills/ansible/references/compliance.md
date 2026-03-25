# Compliance Reference

PCI-DSS 4.0 requirements mapping, CIS benchmarks, Ansible-Lockdown, hardening patterns,
and audit logging for regulated environments.

---

## PCI-DSS 4.0 Requirements Mapping

PCI-DSS 4.0 is the only active version (3.2.1 retired March 2024). 51 future-dated requirements
became mandatory March 31, 2025. Ansible enforces configuration-level controls on managed systems.

### Where Ansible is the primary enforcement tool

| PCI Req | Description | Ansible Implementation |
|---------|-------------|----------------------|
| 1.2 | Network controls configured and maintained | `ansible.posix.firewalld` / `community.general.ufw` rules as code |
| 2.2 | System components hardened | CIS benchmark roles (Ansible-Lockdown), remove unnecessary packages/services |
| 2.2.4 | Only necessary services enabled | Disable unused services via `ansible.builtin.service` (or `systemd`/OpenRC-specific) |
| 2.2.7 | Non-console admin access encrypted | SSH hardening (key-only, protocol 2, idle timeout) |
| 5.2 | Anti-malware deployed | Deploy and configure ClamAV/ESET/etc. via roles |
| 5.3 | Anti-malware mechanisms active | Ensure AV service enabled, scan schedule configured |
| 8.2.3 | Strong authentication factors (service providers only) | PAM configuration for password complexity |
| 8.3.6 | Password complexity | `/etc/security/pwquality.conf` managed by template |
| 8.6.2 | No hardcoded credentials | Ansible Vault for all secrets, `no_log: true` |
| 10.2 | Audit logs capture events | Deploy and configure auditd with PCI-relevant rules |
| 10.3 | Audit logs protected | Log file permissions, integrity monitoring |
| 10.4.1.1 | Automated log review | Deploy log shippers (Filebeat, Promtail), alert rules |
| 10.6 | Time synchronization | NTP/chrony configuration via template |
| 11.5 | Change detection / FIM | Deploy AIDE/OSSEC, configure baselines, alerting |

### Where Ansible supports (but is not the primary tool)

| PCI Req | Description | Ansible Role | Primary Tool |
|---------|-------------|-------------|-------------|
| 1.1 | Network segmentation | Deploy firewall rules | Terraform (VPC/subnet), K8s (NetworkPolicy) |
| 3 | Protect stored data | Configure encryption at rest | Terraform (KMS), application-level encryption |
| 4 | Encrypt transmissions | Deploy TLS certificates | cert-manager, ACME, Istio mTLS |
| 6.3 | Vulnerability management | Patch management playbooks | Trivy, Grype, dependency scanning |
| 8.4.2 | MFA for CDE access | Configure PAM with MFA module | OIDC provider, Duo, YubiKey |
| 10.4.1.1 | Automated audit review | Deploy SIEM agents | Splunk, ELK, SIEM platform |

### PCI MPoC

MPoC (Mobile Payments on COTS) backend infrastructure falls under full PCI-DSS scope.
The A&M (Attestation & Monitoring) backend is a standard server workload -- same Ansible
hardening controls as any CDE system. No MPoC-specific Ansible requirements beyond PCI-DSS 4.0.

Key A&M backend considerations for Ansible:
- Multi-AZ deployment hardening (consistent config across all instances)
- Attestation decision logging (auditd rules for attestation events)
- HSM integration (configure PKCS#11 libraries and access)
- High availability (ensure services auto-restart, health checks in place)

---

## CIS Benchmarks with Ansible-Lockdown

### Overview

[Ansible-Lockdown](https://ansible-lockdown.readthedocs.io/) is the primary community framework
for automated CIS/STIG benchmark compliance. Recognized by MITRE for meeting PCI-DSS, HIPAA,
NIST, CMMC, and FedRAMP requirements.

### Available benchmark roles

| OS | CIS | STIG |
|----|-----|------|
| RHEL 7 | Yes | Yes |
| RHEL 8 | Yes | Yes |
| RHEL 9 | Yes | Yes |
| Ubuntu 18.04 | Yes | -- |
| Ubuntu 20.04 | Yes | Yes |
| Ubuntu 22.04 | Yes | -- |
| Ubuntu 24.04 | Yes | -- |
| CentOS 7/8/Stream | Yes | -- |
| Amazon Linux 2/2023 | Yes | -- |
| Windows Server 2019 | Yes | Yes |
| Windows Server 2022 | Yes | Yes |
| Windows Server 2025 | Yes | -- |

New benchmarks merged within 2-4 weeks of CIS/STIG release.

**Not supported**: Alpine Linux. CIS has not published a benchmark for Alpine, and neither
ansible-lockdown nor `devsec.hardening` officially support it. Alpine's minimal attack surface
(musl, BusyBox, no systemd, no PAM by default) makes it inherently hardened, but for formal
compliance you need a custom hardening role. Alternatives: run `lynis audit system` (supports
Alpine) for an auditable checklist, apply `devsec.hardening.ssh_hardening` (partially works
since sshd config is distro-agnostic -- test it), and handle the rest with targeted tasks
(sysctl, iptables/nftables, service minimization via `rc-update del`).

### Usage

```yaml
# Install the role
# In requirements.yml:
roles:
  - name: ansible-lockdown.rhel9_cis
    version: "1.5.0"    # Pin version!

# In your playbook:
- name: Apply CIS Level 2 hardening
  hosts: all
  become: true

  vars:
    # CIS level (1 = basic, 2 = advanced)
    cis_level: 2

    # Skip controls that break your application
    # ALWAYS review each control before enabling
    rule_1_1_1_1: false         # Disable cramfs (keep if needed)
    rule_1_6_1_1: true          # Enforce SELinux
    rule_5_2_4: true            # SSH MaxAuthTries
    rule_5_2_5: true            # SSH MaxSessions

    # Server vs workstation profile
    cis_server_level: true
    cis_workstation_level: false

  roles:
    - role: ansible-lockdown.rhel9_cis
      tags: [cis, hardening]
```

### Important caveats

**Never apply CIS blindly.** Common controls that break things:

| Control | What it does | When to disable |
|---------|-------------|-----------------|
| USB storage disable | Blocks USB devices | If servers use USB for KVM/backup |
| IPv6 disable | Disables IPv6 stack | If your network uses IPv6 |
| Auditd space_left_action | Halts system on full audit log | If you prefer alert-only |
| SSH AllowUsers | Restricts SSH to named users | If you use LDAP/AD groups |
| Core dump disable | Prevents core dumps | If you need crash diagnostics |
| IP forwarding disable | Blocks packet routing | On load balancers, routers, Docker hosts |
| Unattended upgrades | Auto-installs security patches | If you need change control windows |

**Testing workflow:**
1. Apply to a staging/test system first
2. Review all changes (`--check --diff`)
3. Run your application test suite after hardening
4. Document which controls are disabled and why
5. Apply to production one system at a time (serial: 1)

---

## Hardening Playbook Patterns

### SSH hardening (template-based)

```jinja2
{# sshd_config.j2 -- PCI-DSS compliant SSH configuration #}
# Managed by Ansible -- do not edit manually
# PCI-DSS 4.0: Req 2.2.7 (encrypted non-console admin), Req 8 (authentication)

# Protocol 2 is the only option since OpenSSH 7.6+ (directive removed).
# Kept for: compliance scanners that grep for it, and older SSH versions.
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries {{ ssh_max_auth_tries | default(3) }}
MaxSessions {{ ssh_max_sessions | default(2) }}
LoginGraceTime {{ ssh_login_grace_time | default(60) }}

# Session
ClientAliveInterval {{ ssh_alive_interval | default(300) }}
ClientAliveCountMax {{ ssh_alive_count_max | default(0) }}

# Access control
{% if ssh_allow_users is defined %}
AllowUsers {{ ssh_allow_users | join(' ') }}
{% endif %}
{% if ssh_allow_groups is defined %}
AllowGroups {{ ssh_allow_groups | join(' ') }}
{% endif %}

# Crypto (PCI-DSS compliant)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Other
X11Forwarding no
PermitEmptyPasswords no
PermitUserEnvironment no
AllowTcpForwarding {{ 'yes' if ssh_allow_tcp_forwarding | default(false) else 'no' }}
Banner /etc/ssh/banner
```

### Auditd rules (PCI-DSS Req 10.2)

```yaml
# tasks/auditd.yml
- name: Deploy auditd rules
  ansible.builtin.template:
    src: audit.rules.j2
    dest: /etc/audit/rules.d/99-pci.rules
    owner: root
    group: root
    mode: "0640"
  become: true
  notify: Restart auditd

- name: Ensure auditd is running and enabled
  ansible.builtin.systemd:
    name: auditd
    state: started
    enabled: true
  become: true
```

```jinja2
{# audit.rules.j2 -- PCI-DSS 4.0 Req 10.2 audit rules #}
# Managed by Ansible

# Record all authentication events (Req 10.2.1.4, 10.2.1.5)
-w /var/log/faillog -p wa -k auth
-w /var/log/lastlog -p wa -k auth
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# Monitor user/group changes (Req 10.2.1.5)
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor sudo usage (Req 10.2.1.2)
-w /etc/sudoers -p wa -k sudo
-w /etc/sudoers.d/ -p wa -k sudo

# Monitor SSH configuration (Req 2.2.7)
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd

# Monitor system time changes (Req 10.6)
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Monitor network configuration (Req 1)
-w /etc/sysconfig/network -p wa -k network
-w /etc/hosts -p wa -k network
-w /etc/hostname -p wa -k network

# Monitor cron (Req 10.2.1.5)
-w /etc/cron.d -p wa -k cron
-w /etc/crontab -p wa -k cron
-w /var/spool/cron -p wa -k cron

# Make the configuration immutable (until reboot)
{% if auditd_immutable | default(true) %}
-e 2
{% endif %}
```

### NTP/chrony configuration (PCI-DSS Req 10.6)

```yaml
- name: Install chrony
  ansible.builtin.package:
    name: chrony
    state: present
  become: true

- name: Configure chrony
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony.conf
    owner: root
    group: root
    mode: "0644"
  become: true
  notify: Restart chrony

- name: Ensure chrony is running
  ansible.builtin.systemd:
    name: chronyd
    state: started
    enabled: true
  become: true
```

### AIDE (FIM -- PCI-DSS Req 11.5)

```yaml
- name: Install AIDE
  ansible.builtin.package:
    name: aide
    state: present
  become: true

- name: Deploy AIDE configuration
  ansible.builtin.template:
    src: aide.conf.j2
    dest: /etc/aide.conf
    owner: root
    group: root
    mode: "0600"
  become: true

- name: Initialize AIDE database
  ansible.builtin.command:
    cmd: aide --init
    creates: /var/lib/aide/aide.db.new.gz
  become: true

- name: Move new database to active
  ansible.builtin.command:
    cmd: mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    removes: /var/lib/aide/aide.db.new.gz
    creates: /var/lib/aide/aide.db.gz
  become: true

- name: Schedule daily AIDE check
  ansible.builtin.cron:
    name: "AIDE integrity check"
    minute: "0"
    hour: "5"
    job: "/usr/sbin/aide --check | /usr/bin/mail -s 'AIDE report {{ inventory_hostname }}' {{ aide_alert_email }}"
    user: root
  become: true
```

---

## Audit Logging for Ansible Itself

### Callback plugins

Capture playbook execution details for audit trails:

```ini
# ansible.cfg
[defaults]
# File-based logging (simplest)
log_path = /var/log/ansible/ansible.log

# Callback plugins for structured logging
callbacks_enabled = ansible.posix.json, community.general.log_plays, profile_tasks

[callback_log_plays]
log_folder = /var/log/ansible/plays/
```

### AWX/AAP audit trail

AWX and AAP provide built-in audit logging:
- **Activity stream**: all changes to AWX objects (users, projects, job templates, credentials)
- **Job events**: per-task execution details with timestamps and results
- **REST API queries**: `GET /api/v2/activity_stream/` for audit reports
- **RBAC**: who has access to what, with full audit trail
- **External logging**: ship to Splunk, ELK, or any syslog-compatible SIEM

```bash
# Query AWX activity stream
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "https://awx.example.com/api/v2/activity_stream/?timestamp__gte=2026-01-01" | jq '.results[] | {timestamp, operation, summary_fields}'
```

### CI/CD audit artifacts

For PCI Req 10 compliance, archive playbook output:

```yaml
# GitLab CI
ansible-deploy:
  script:
    - ansible-playbook -i inventory/production deploy.yml --diff | tee /tmp/ansible-output.log
  artifacts:
    paths:
      - /tmp/ansible-output.log
    expire_in: 1 year          # PCI requires 1 year retention
    when: always               # Keep even on failure
```

---

## Compliance Verification Playbook

A meta-playbook to verify that hardening controls are in place:

```yaml
# verify-compliance.yml
- name: Verify PCI-DSS compliance posture
  hosts: cde_servers
  become: true
  gather_facts: true

  tasks:
    - name: "Req 2.2.7 -- Verify SSH hardening"
      ansible.builtin.command:
        cmd: sshd -T
      register: sshd_config
      changed_when: false

    - name: "Req 2.2.7 -- Assert SSH is properly configured"
      ansible.builtin.assert:
        that:
          - "'permitrootlogin no' in sshd_config.stdout"
          - "'passwordauthentication no' in sshd_config.stdout"
          # Protocol directive was removed in OpenSSH 7.6+ (only protocol 2 is supported).
          # The fallback ('protocol' not in output) handles modern SSH where the directive is gone.
          - "'protocol 2' in sshd_config.stdout or 'protocol' not in sshd_config.stdout"
        fail_msg: "SSH hardening check FAILED"

    - name: "Req 10.2 -- Verify auditd is running"
      ansible.builtin.systemd:
        name: auditd
      register: auditd_status
      changed_when: false

    - name: "Req 10.2 -- Assert auditd is active"
      ansible.builtin.assert:
        that:
          - auditd_status.status.ActiveState == "active"

    - name: "Req 10.6 -- Verify NTP is configured"
      ansible.builtin.systemd:
        name: "{{ 'chronyd' if ansible_os_family == 'RedHat' else 'chrony' }}"
      register: ntp_status
      changed_when: false

    - name: "Req 10.6 -- Assert NTP is active"
      ansible.builtin.assert:
        that:
          - ntp_status.status.ActiveState == "active"

    - name: "Req 11.5 -- Verify AIDE is installed"
      ansible.builtin.stat:
        path: /var/lib/aide/aide.db.gz
      register: aide_db

    - name: "Req 11.5 -- Assert AIDE database exists"
      ansible.builtin.assert:
        that:
          - aide_db.stat.exists
        fail_msg: "AIDE database not found -- FIM not initialized"

    - name: "Req 1 -- Verify firewall is active"
      ansible.builtin.systemd:
        name: "{{ 'firewalld' if ansible_os_family == 'RedHat' else 'ufw' }}"
      register: firewall_status
      changed_when: false

    - name: "Req 1 -- Assert firewall is active"
      ansible.builtin.assert:
        that:
          - firewall_status.status.ActiveState == "active"

    - name: Compliance summary
      ansible.builtin.debug:
        msg: "All PCI-DSS configuration checks PASSED on {{ inventory_hostname }}"
```

Run regularly (weekly or after changes) and archive the output for QSA review.
