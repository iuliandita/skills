# Git Security & Commit Signing

Credential management, commit signing setup, secret scanning, CVE reference, and hardening.

Research date: March 2026.

---

## Commit Signing Setup

### SSH signing (recommended)

The simplest path. Reuses existing SSH keys, no GPG keyring, works offline.

```bash
# Configure git to use SSH signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true    # sign all commits
git config --global tag.gpgSign true       # sign all tags

# Allowed signers file (for offline verification)
echo "$(git config user.email) $(cat ~/.ssh/id_ed25519.pub)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers

# Verify signing works
echo "test" | git commit-tree HEAD^{tree} -S
git log --show-signature -1
```

**Upload your SSH public key to each forge as a "Signing Key":**
- **GitHub**: Settings > SSH and GPG keys > New SSH key > Key type: **Signing Key**
  (separate from authentication keys)
- **GitLab**: Preferences > SSH Keys > Usage type: **Signing** (or both)
- **Forgejo**: Settings > SSH / GPG Keys > Add Key > type: signing

### GPG signing

More complex but offers key expiry, revocation, and key server distribution.

```bash
# Generate a GPG key (if you don't have one)
gpg --full-generate-key
# Choose: (1) RSA and RSA, 4096 bits, expiry 2y, your git email

# Configure git
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git config --global tag.gpgSign true

# If using GPG agent (pinentry prompts for passphrase)
echo "pinentry-program /usr/bin/pinentry-tty" >> ~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye

# Export public key for forge upload
gpg --armor --export <KEY_ID>
```

**GPG agent caching**: by default, GPG agent caches the passphrase for 600 seconds. For
longer sessions: `echo "default-cache-ttl 86400" >> ~/.gnupg/gpg-agent.conf`

### gitsign (Sigstore) -- keyless signing

Zero key management. Uses OIDC identity (GitHub, Google, Microsoft). Best for open source.

```bash
# Install
go install github.com/sigstore/gitsign@latest
# Or: brew install sigstore/tap/gitsign

# Configure (per-repo recommended, not global)
git config commit.gpgsign true
git config gpg.x509.program gitsign
git config gpg.format x509

# Sign -- opens browser for OIDC auth
git commit -S -m "signed commit"

# Verify
git verify-commit HEAD
```

**Limitations**: requires internet at sign time, ephemeral certificates (no GitHub vigilant mode),
verification requires Sigstore infrastructure. Best for open source, not ideal for air-gapped
or compliance environments.

### 1Password SSH agent

If you use 1Password, its SSH agent can sign git commits with keys stored in the vault.

```bash
# Configure git to use 1Password SSH agent
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAA... your@email.com"
git config --global commit.gpgsign true

# 1Password SSH agent socket (varies by platform)
# macOS: ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
# Linux: ~/.1password/agent.sock
export SSH_AUTH_SOCK=~/.1password/agent.sock
```

### Signing in CI/CD

CI environments need signing without interactive passphrase prompts.

```bash
# GPG in CI: import key from secret, no passphrase (or preset passphrase)
echo "$GPG_PRIVATE_KEY" | gpg --batch --import
git config user.signingkey <KEY_ID>
git config commit.gpgsign true

# SSH in CI: use deploy key as signing key
echo "$SSH_SIGNING_KEY" > /tmp/signing_key
chmod 600 /tmp/signing_key
git config gpg.format ssh
git config user.signingkey /tmp/signing_key
```

---

## Credential Management

### Git credential helpers

| Helper | Platform | Storage | Security level |
|--------|----------|---------|----------------|
| `osxkeychain` | macOS | Keychain | High (biometric) |
| `libsecret` | Linux (GNOME) | GNOME Keyring | High (session-locked) |
| `wincred` | Windows | Windows Credential Store | High |
| `manager` (GCM) | Cross-platform | OS-native store | High |
| `cache --timeout=3600` | Any | In-memory | Medium (auto-expires) |
| `store` | Any | Plaintext `~/.git-credentials` | **DANGEROUS** |

```bash
# Recommended setup (Linux)
git config --global credential.helper libsecret

# With timeout fallback
git config --global credential.helper 'cache --timeout=28800'  # 8 hours

# Per-host credentials (different accounts for different forges)
git config --global credential.https://github.com.helper 'cache --timeout=28800'
git config --global credential.https://gitlab.example.com.helper libsecret
```

### SSH vs HTTPS remotes

| Protocol | Auth | Firewall | Credential storage |
|----------|------|----------|-------------------|
| **SSH** | SSH key | Port 22 (may be blocked) | SSH agent |
| **HTTPS** | Token/password | Port 443 (rarely blocked) | Credential helper |

**Recommendation**: SSH for development machines (key-based, no token expiry), HTTPS for CI/CD
(token-based, scoped, rotatable).

### Token rotation

- **GitHub PATs**: fine-grained tokens with expiry (90 days max recommended). Classic tokens
  don't expire but should be rotated quarterly.
- **GitLab tokens**: project/group access tokens with expiry. Service accounts for CI.
- **Forgejo tokens**: personal access tokens. No fine-grained scoping yet.

---

## Secret Scanning

### Tools

| Tool | Scope | Speed | False positive rate |
|------|-------|-------|-------------------|
| `gitleaks` 9.x | Current + history | Fast | Low |
| `trufflehog` 3.x | Current + history | Medium | Very low (verified) |
| `detect-secrets` | Current only | Fast | Medium |
| GitHub secret scanning | Push-time | Real-time | Low (pattern-based) |
| GitLab secret detection | CI pipeline | CI-speed | Medium |

### Scanning workflow

```bash
# Quick scan (current state only)
gitleaks detect --source . --no-git

# Full history scan
gitleaks detect --source . --log-opts="--all"

# Scan staged changes only (pre-commit hook)
gitleaks protect --staged

# Scan with trufflehog (verifies against live APIs)
trufflehog filesystem . --only-verified
trufflehog git . --since-commit=HEAD~20
```

### Pre-commit hook for secret detection

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v9.0.0  # check for latest  # pin to specific version
    hooks:
      - id: gitleaks
```

Or with `lefthook`:

```yaml
# lefthook.yml
pre-commit:
  commands:
    gitleaks:
      run: gitleaks protect --staged --no-banner
```

### Secret remediation

When a secret is found in git history:

1. **Rotate the secret immediately.** Assume it's compromised. Scrubbing history removes
   future exposure, not past.
2. **Scrub from history** using `git-filter-repo`:

```bash
# Replace secret with placeholder
git filter-repo --replace-text <(echo 'ACTUAL_SECRET==>REDACTED')

# Or remove entire files that contained secrets
git filter-repo --invert-paths --path .env.production

# Force-push all branches and tags
git push origin --force --all
git push origin --force --tags
```

3. **Coordinate with team** -- force-push rewrites history. Everyone needs to re-clone or
   `git fetch --all && git reset --hard origin/main`.
4. **Update forge** -- GitHub/GitLab cache old objects. Contact support for immediate purge,
   or wait for GC (varies by forge).
5. **Add to `.gitignore`** to prevent recurrence.

---

## Git CVE Reference (2024-2026)

### git (core)

| CVE | Version | Severity | Description |
|-----|---------|----------|-------------|
| CVE-2025-48384 | < 2.50.1 | **Critical (8.1)** | Arbitrary file write via `\r` in `.gitmodules` during recursive clone. **Actively exploited** -- CISA KEV. |
| CVE-2025-48385 | < 2.50.1 | High | Bundle URI validation bypass -- protocol injection, potential RCE |
| CVE-2025-48386 | < 2.50.1 | Medium | Buffer overflow in `wincred` credential helper (Windows only) |
| CVE-2024-32002 | < 2.45.1 | Critical (9.1) | Recursive clone RCE via symlink + submodule |
| CVE-2024-50349 | < 2.48.1 | Medium | Credential leak via terminal escape in URL |
| CVE-2025-27509 | < 2.49.0 | Medium | Incomplete patch for CVE-2024-50349 |

**Action**: ensure git >= 2.50.1 (ideally 2.53.x). CVE-2025-48384 is **actively exploited in the
wild** -- a weaponized `.gitmodules` file can overwrite hook scripts to achieve RCE on `git clone
--recursive`. Patched in v2.50.1, v2.49.1, v2.48.2, v2.47.3, and backports. Linux and macOS
affected; Windows is not.

### Supply chain (git-adjacent)

| Incident | Date | Impact |
|----------|------|--------|
| tj-actions/changed-files (CVE-2025-30066) | March 2025 | GitHub Actions supply chain. Malicious code via compromised `reviewdog` maintainer account (CVE-2025-30154). Secrets exfiltrated from 23k+ repos. Led to Coinbase breach (~70k customers). |
| Trivy Docker Hub compromise (CVE-2026-33634) | March 2026 | Credential-stealing malware in Docker Hub images v0.69.4-6. |
| xz utils backdoor (CVE-2024-3094) | March 2024 | Backdoor in xz 5.6.0/5.6.1 targeting SSH. |

### Git forge vulnerabilities

| CVE | Forge | Severity | Description |
|-----|-------|----------|-------------|
| Forgejo directory traversal RCE | Forgejo <= v13.0.1 | Critical | Template processing allows authenticated RCE via symlink to `.ssh/authorized_keys`. Fixed in v13.0.2+. |
| CVE-2025-11702 | GitLab | High (8.5) | Runner hijacking -- authenticated users could hijack project runners from other projects. Fixed in 18.3.5/18.4.3/18.5.1. |
| CVE-2025-25291/25292 | GitLab | Critical | SAML SSO authentication bypass -- user impersonation. Fixed in 17.9.x patches. |
| CVE-2025-8110 | Gogs | High (8.7) | Symlink bypass RCE zero-day. 700+ compromised instances. Fixed in v0.13.4 (Jan 2026). |

### AI tooling and MCP vulnerabilities

| CVE | Component | Severity | Description |
|-----|-----------|----------|-------------|
| CVE-2025-68143 | Anthropic MCP Git server | High (8.8) | Path traversal in `git_init` -- arbitrary filesystem access. Fixed 2025.9.25. |
| CVE-2025-68144 | Anthropic MCP Git server | High (8.1) | Argument injection in `git_diff`/`git_checkout`. Fixed 2025.12.18. |
| CVE-2025-65964 | n8n | Critical (9.4) | RCE via `core.hooksPath` exploitation in Git hooks. |

**MCP + Filesystem server chaining**: combining the Git MCP server with the Filesystem MCP server
created a toxic attack surface enabling full code execution from prompt injection.

### Malicious project configs

AI tool project configs (`.claude/`, `.cursor/`, `.vscode/tasks.json`, `.idea/runConfigurations/`)
can define hooks or tasks that execute arbitrary code when a developer opens the project.

**Mitigation**: treat all project config dirs in cloned repos as untrusted. Review hook configs
before opening a project from an untrusted source. `core.hooksPath` is a security-sensitive
setting -- if an attacker controls it, they control code execution.

---

## Git Security Hardening

### Per-user configuration

```bash
# Refuse to clone/fetch from repos with suspicious ownership
git config --global safe.directory '*'    # DO NOT use '*' -- this disables the check!
# Instead, add specific trusted directories:
git config --global --add safe.directory /home/user/projects/repo

# Disable credential helper fallback to plaintext
git config --global credential.helper ''

# Require signed commits for verification
git config --global merge.verifySignatures true  # reject unsigned merges
git config --global log.showSignature true       # always show signatures in log

# Prevent accidental pushes to wrong remote
git config --global push.default current  # only push current branch, not all matching
git config --global push.autoSetupRemote true  # auto-track on first push (git 2.37+, single-remote repos only)
```

### Repository-level hardening

```bash
# Reject unsigned commits on merge (server-side equivalent of branch protection)
git config receive.denyNonFastForwards true
git config receive.denyDeletes true

# Transfer size limits (prevent repo bombs)
git config pack.packSizeLimit 100m
git config receive.maxInputSize 104857600  # 100MB
```

### Cloning untrusted repositories

When cloning repos from untrusted sources:

1. **Don't use `--recurse-submodules`** until you've reviewed `.gitmodules`
2. **Check for suspicious hooks** in `.githooks/`, `.husky/`, `.pre-commit-config.yaml`
3. **Check for project configs** that auto-execute (`.claude/`, `.vscode/tasks.json`, `Makefile` targets)
4. **Review CI configs** that might run on fork PRs (`.github/workflows/`, `.gitlab-ci.yml`)
5. **Use `--depth 1`** if you only need the latest state (limits exposure to history-based attacks)

---

## Git LFS

For repositories with large binary files (design assets, ML models, data files).

```bash
# Install and set up
git lfs install

# Track file patterns
git lfs track "*.psd"
git lfs track "*.zip"
git lfs track "models/**"

# Verify tracking
git lfs ls-files

# Migrate existing large files to LFS
git lfs migrate import --include="*.psd" --everything
```

**LFS gotchas**:
- LFS storage is separate from git storage. GitHub free tier: 1GB storage, 1GB/month bandwidth.
- `git clone` downloads LFS pointers, not files. `git lfs pull` fetches actual files.
- Self-hosted LFS requires a separate LFS server (Forgejo includes one).
- LFS files don't show meaningful diffs (they're pointers). Use `git lfs diff` or configure
  diff drivers in `.gitattributes`.
