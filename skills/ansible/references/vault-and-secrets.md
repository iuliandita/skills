# Vault & Secrets Reference

Patterns for Ansible Vault, HashiCorp Vault integration, and secrets management in CI/CD.

---

## Ansible Vault

### Core concepts

Ansible Vault encrypts data at rest using AES-256. It can encrypt:
- **Entire files** (common for `vault.yml` in `group_vars/`)
- **Individual variables** (inline encrypted strings)
- **Any YAML/text file** referenced by playbooks

Vault is decrypted at runtime. The password is provided via:
- `--ask-vault-pass` (interactive prompt -- development only)
- `--vault-password-file /path/to/file` (file containing the password)
- `--vault-password-file /path/to/script.sh` (executable that prints the password)
- `--vault-id label@source` (multiple vaults with labels)
- `ANSIBLE_VAULT_PASSWORD_FILE` env var

### File-level encryption

```bash
# Create a new encrypted file
ansible-vault create group_vars/production/vault.yml

# Encrypt an existing file
ansible-vault encrypt secrets.yml

# Edit in place (decrypts to temp, opens $EDITOR, re-encrypts)
ansible-vault edit group_vars/production/vault.yml

# View without editing
ansible-vault view group_vars/production/vault.yml

# Decrypt to plaintext (avoid in production -- use edit/view instead)
ansible-vault decrypt secrets.yml

# Change the encryption password
ansible-vault rekey group_vars/production/vault.yml

# Rekey with different vault IDs
ansible-vault rekey --vault-id old@prompt --new-vault-id new@prompt secrets.yml
```

### Variable-level encryption

Encrypt a single variable value inline:

```bash
# Interactive
ansible-vault encrypt_string 'my_secret_value' --name 'vault_db_password'

# From stdin
echo -n 'my_secret_value' | ansible-vault encrypt_string --stdin-name 'vault_api_key'

# With vault ID
ansible-vault encrypt_string 'my_secret_value' --name 'vault_db_password' --vault-id prod@prompt
```

Output (paste into your vars file):
```yaml
vault_db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6163383762613965313...
```

### File organization pattern

The recommended pattern uses indirection -- vault variables are referenced via regular variables:

```
group_vars/
+-- production/
|   +-- vars.yml           # Regular variables (readable)
|   +-- vault.yml          # Vault-encrypted secrets
+-- staging/
    +-- vars.yml
    +-- vault.yml
```

```yaml
# group_vars/production/vault.yml (encrypted)
---
vault_db_password: "actual_secret_password_here"
vault_api_key: "sk-actual-key-here"
vault_tls_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvgIBADANBgkqhkiG9w...
  -----END PRIVATE KEY-----
```

```yaml
# group_vars/production/vars.yml (plaintext, readable)
---
db_password: "{{ vault_db_password }}"
api_key: "{{ vault_api_key }}"
tls_key: "{{ vault_tls_key }}"
```

**Why indirection?** You can see what variables exist without decrypting. `grep` works on
`vars.yml`. Code review works. Only the actual values require vault access.

### Multi-vault (vault IDs)

Use different passwords for different environments or sensitivity levels:

```bash
# Encrypt with a label
ansible-vault encrypt --vault-id prod@prompt group_vars/production/vault.yml
ansible-vault encrypt --vault-id dev@prompt group_vars/dev/vault.yml

# Run with multiple vault IDs
ansible-playbook playbook.yml \
  --vault-id dev@/path/to/dev-password \
  --vault-id prod@/path/to/prod-password

# Ansible matches the vault ID label in the encrypted file header
```

### no_log: true (mandatory for secrets)

**CVE-2024-8775**: vault-encrypted variables exposed in plaintext via `include_vars` without `no_log`.
This is not theoretical -- it happened.

```yaml
# ALWAYS add no_log when handling secrets
- name: Set database password
  ansible.builtin.template:
    src: db-config.j2
    dest: /etc/myapp/db.conf
    mode: "0600"
  no_log: true

- name: Create database user
  community.postgresql.postgresql_user:
    name: "{{ db_user }}"
    password: "{{ vault_db_password }}"
    state: present
  no_log: true

# Include vars with no_log
- name: Load vault variables
  ansible.builtin.include_vars:
    file: vault.yml
  no_log: true
```

**When to use `no_log`:**
- Any task that uses vault-encrypted variables
- Tasks that set passwords, tokens, or API keys
- Tasks that output credentials in stdout/stderr
- `debug` tasks that print secret values (remove these before production)

**When NOT to use `no_log`:**
- Regular configuration tasks (makes debugging impossible)
- Tasks using non-sensitive variables
- Verification tasks that need visible output

### Vault password management

```bash
# Password file (simplest -- protect with file permissions)
echo 'vault_password_here' > ~/.ansible-vault-pass
chmod 600 ~/.ansible-vault-pass

# In ansible.cfg
[defaults]
vault_password_file = ~/.ansible-vault-pass

# Password script (pulls from external source)
#!/usr/bin/env bash
# vault-pass.sh -- pulls from a password manager or secret store
set -euo pipefail
pass show ansible/vault-production
```

**Never store vault passwords in git.** Add to `.gitignore`:
```
.vault-pass*
*.vault-password
```

---

## HashiCorp Vault Integration

The `hashicorp.vault` certified collection provides native Ansible integration with HashiCorp Vault.

### Lookup plugin (read secrets at runtime)

```yaml
- name: Read database credentials from Vault
  ansible.builtin.set_fact:
    db_password: "{{ lookup('hashicorp.vault.vault_read', 'secret/data/production/db').data.data.password }}"
  no_log: true

# With specific auth method
- name: Read with AppRole auth
  ansible.builtin.set_fact:
    api_key: >-
      {{ lookup('hashicorp.vault.vault_read',
         'secret/data/production/api',
         auth_method='approle',
         role_id=lookup('env', 'VAULT_ROLE_ID'),
         secret_id=lookup('env', 'VAULT_SECRET_ID')
      ).data.data.key }}
  no_log: true
```

### hashi_vault lookup (legacy but widely used)

```yaml
- name: Read secret
  ansible.builtin.set_fact:
    db_creds: "{{ lookup('community.hashi_vault.hashi_vault',
      'secret/data/production/db',
      url='https://vault.example.com:8200',
      token=lookup('env', 'VAULT_TOKEN')
    ) }}"
  no_log: true
```

### Dynamic secrets (database credentials)

```yaml
- name: Generate temporary database credentials
  hashicorp.vault.vault_read:
    path: database/creds/myapp-role
    url: "{{ vault_url }}"
    auth_method: approle
    role_id: "{{ vault_role_id }}"
    secret_id: "{{ vault_secret_id }}"
  register: db_creds
  no_log: true

- name: Use temporary credentials
  ansible.builtin.template:
    src: db-config.j2
    dest: /etc/myapp/db.conf
    mode: "0600"
  vars:
    db_user: "{{ db_creds.data.username }}"
    db_pass: "{{ db_creds.data.password }}"
  no_log: true
```

### SSH secret engine (signed certificates)

```yaml
- name: Sign SSH host key
  hashicorp.vault.vault_write:
    path: ssh-host/sign/host-role
    data:
      cert_type: host
      public_key: "{{ lookup('ansible.builtin.file', '/etc/ssh/ssh_host_ed25519_key.pub') }}"
    url: "{{ vault_url }}"
    auth_method: approle
    role_id: "{{ vault_role_id }}"
    secret_id: "{{ vault_secret_id }}"
  register: signed_cert
  no_log: true

- name: Deploy signed certificate
  ansible.builtin.copy:
    content: "{{ signed_cert.data.signed_key }}"
    dest: /etc/ssh/ssh_host_ed25519_key-cert.pub
    mode: "0644"
  notify: Restart sshd
```

---

## CI/CD Secrets Patterns

### GitLab CI

```yaml
# .gitlab-ci.yml
ansible-deploy:
  stage: deploy
  image: my-ee:1.0.0
  variables:
    ANSIBLE_HOST_KEY_CHECKING: "false"
  script:
    # Vault password from CI variable (masked in logs)
    - ansible-playbook -i inventory/production deploy.yml
      --vault-password-file <(echo "$VAULT_PASSWORD")
      --diff
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

**Key points:**
- `$VAULT_PASSWORD` is a CI/CD variable (Settings > CI/CD > Variables, masked)
- `<(echo "$VAULT_PASSWORD")` is process substitution -- the password never touches disk
- For HashiCorp Vault: pass `VAULT_TOKEN` or `VAULT_ROLE_ID`/`VAULT_SECRET_ID` as CI variables
- Pin the EE image to a specific tag (not `:latest`)

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<sha>           # Pin to SHA!
      - name: Run playbook
        run: |
          echo "${{ secrets.VAULT_PASSWORD }}" > /tmp/.vault-pass
          ansible-playbook -i inventory/production deploy.yml \
            --vault-password-file /tmp/.vault-pass \
            --diff
          rm -f /tmp/.vault-pass
        env:
          ANSIBLE_HOST_KEY_CHECKING: "false"
```

**Warning**: pin ALL GitHub Actions to commit SHAs. The tj-actions compromise (March 2025)
and Trivy compromise (March 2026) prove mutable tags are not safe.

### AWS SSM Parameter Store

```yaml
- name: Read secret from SSM
  ansible.builtin.set_fact:
    db_password: "{{ lookup('amazon.aws.ssm_parameter', '/production/db/password', region='us-east-1') }}"
  no_log: true
```

### Environment variable injection

For container-based execution (EEs, Docker):

```yaml
# Pass secrets via environment
- name: Configure application
  ansible.builtin.template:
    src: config.j2
    dest: /etc/myapp/config.yml
    mode: "0600"
  vars:
    api_key: "{{ lookup('ansible.builtin.env', 'API_KEY') }}"
  no_log: true
```

---

## Secret Rotation

### Vault rekey (change encryption password)

```bash
# Single file
ansible-vault rekey group_vars/production/vault.yml

# Multiple files (batch)
find . -name 'vault.yml' -exec ansible-vault rekey {} +

# Change from old to new password file
ansible-vault rekey --vault-password-file old-pass --new-vault-password-file new-pass vault.yml
```

### Rotating application secrets

```yaml
# rotate-secrets.yml
- name: Rotate application secrets
  hosts: appservers
  become: true
  vars_prompt:
    - name: confirm_rotation
      prompt: "Type 'rotate' to confirm secret rotation"
      private: false

  tasks:
    - name: Abort if not confirmed
      ansible.builtin.fail:
        msg: "Rotation not confirmed"
      when: confirm_rotation != 'rotate'

    - name: Generate new API key
      ansible.builtin.set_fact:
        new_api_key: "{{ lookup('ansible.builtin.password', '/dev/null length=64 chars=ascii_letters,digits') }}"
      no_log: true

    - name: Update application config
      ansible.builtin.template:
        src: config.j2
        dest: /etc/myapp/config.yml
        mode: "0600"
      notify: Restart application
      no_log: true

    - name: Wait for application to restart
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
      retries: 10
      delay: 5

    - name: Verify new key works
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/api/verify"
        headers:
          Authorization: "Bearer {{ new_api_key }}"
        status_code: 200
      no_log: true
```

---

## Anti-Patterns

- **Vault password in git** -- even in a "private" repo. Use CI/CD secrets or a password manager.
- **`ansible-vault decrypt` in CI** -- decrypts to plaintext on disk. Use `--vault-password-file` instead.
- **Vault password = "password"** -- use a generated password (64+ chars).
- **Single vault password for all environments** -- use vault IDs to separate dev/staging/prod.
- **Secrets in `debug` tasks** -- remove before merging. Use `no_log: true` on any task printing secrets.
- **`ansible_ssh_pass` in inventory** -- use SSH keys. Period.
- **Vault files without the `vault_` prefix convention** -- makes it impossible to grep for which variables are secrets.
- **Missing `no_log: true`** on tasks handling vault variables -- CVE-2024-8775 is the poster child.
- **Committing `.vault-pass` files** -- add to `.gitignore` immediately.
