# Security Audit: Hardening Checklists

Detailed checklists for passes 6-8. Read this file when executing those passes.

## Cryptography & Data Protection (Pass 6)

- [ ] **TLS verification**: is `rejectUnauthorized: false` or `NODE_TLS_REJECT_UNAUTHORIZED=0` used? If so, is it opt-in per-connection and documented, not global?
- [ ] **Sensitive data in logs**: are passwords, tokens, or API keys logged? Check logging middleware and error handlers.
- [ ] **Sensitive data in error responses**: do 500 errors leak stack traces, DB schemas, or env vars to clients?
- [ ] **Settings endpoint responses**: do API responses include fields that should be redacted (API keys, passwords, tokens)? Are there separate admin/non-admin views?
- [ ] **Secrets storage**: are secrets in `.env` files, env vars, or a proper secret manager (Vault, K8s secrets, etc.)?
- [ ] **Encryption at rest**: are sensitive DB columns (API keys, tokens, OAuth secrets) encrypted, or stored as plaintext?
- [ ] **CORS configuration**: is `Access-Control-Allow-Origin: *` used in production? Is it intentional?
- [ ] **Cookie flags**: `httpOnly`, `secure`, `sameSite` set on session cookies?
- [ ] **HSTS**: is `Strict-Transport-Security` header set?
- [ ] **CSP**: is `Content-Security-Policy` configured?

## Container & Infrastructure (Pass 7)

### Dockerfile

- [ ] Runs as non-root user? (`USER` directive in final stage, not just `PUID` env var)
- [ ] Minimal base image? (distroless, alpine, slim - not full Ubuntu/Debian)
- [ ] No secrets in build args or layer history? (`docker history` check)
- [ ] `.dockerignore` excludes `.env`, `.git`, `node_modules`, test fixtures?
- [ ] Health check defined? (`HEALTHCHECK` directive)
- [ ] Multi-stage build? (build deps not in final image)
- [ ] No `apt-get install` without `--no-install-recommends`?
- [ ] Base image pinned to digest, not just tag?

### Kubernetes (skip if not applicable)

- [ ] Resource limits on every container?
- [ ] No `latest` tags in image references?
- [ ] Images pinned to digest (`@sha256:...`), not just tag? Tags are mutable.
- [ ] NetworkPolicy or CiliumNetworkPolicy on security-tooling namespaces (trivy, falco, etc.)?
- [ ] SecurityContext: `readOnlyRootFilesystem`, `runAsNonRoot`, `drop ALL` capabilities? **IMPORTANT**: `drop: ["ALL"]` removes capabilities containers may need at startup. Never blanket-apply - check each container's entrypoint first. LSIO/HOTIO images (PUID/PGID) need `add: ["SETUID", "SETGID"]`. Images that chown at startup need `add: ["CHOWN"]`. Images using gosu/setpriv/su-exec need `add: ["SETUID", "SETGID"]`. Official redis/valkey/postgres images need `add: ["SETUID", "SETGID"]`. Always test one container before rolling out across namespaces.
- [ ] NetworkPolicy defined?
- [ ] Secrets not hardcoded in manifests (use external-secrets, sealed-secrets, or vault)?
- [ ] Service accounts with minimal RBAC?
- [ ] Pod security standards (restricted profile)?

### Helm (skip if not applicable)

- [ ] Secrets not in values files?
- [ ] Chart version pinned?
- [ ] `helm template` renders without warnings?

### Terraform (skip if not applicable)

**Automated** (if available):
- `trivy config --tf-vars terraform.tfvars .` or `checkov -d .`

**Manual**:
- [ ] State backend uses encryption at rest? (S3 SSE, GCS CMEK, Azure Blob encryption)
- [ ] State backend has access controls? (bucket policy, IAM, not world-readable)
- [ ] State locking enabled? (DynamoDB for S3, built-in for GCS/Azure)
- [ ] No `.tfstate` files committed to git? Check `.gitignore` and git history.
- [ ] Provider credentials not hardcoded? (should use env vars, instance profiles, or workload identity)
- [ ] No `0.0.0.0/0` ingress rules without justification? (security groups, firewall rules, NSGs)
- [ ] IAM policies follow least privilege? (no `"Action": "*"` or `"Resource": "*"` on broad policies)
- [ ] Encryption enabled on storage/databases? (EBS, RDS, S3, GCS, Azure disks)
- [ ] Public access explicitly disabled on storage buckets unless intentional?
- [ ] SSH keys not embedded in `user_data` or `cloud-init` as plaintext?
- [ ] Sensitive variables marked `sensitive = true`? (prevents logging in plan output)
- [ ] Provider versions pinned with constraints? (not `>= 0.0.0` or unconstrained)

### Ansible (skip if not applicable)

- [ ] Secrets encrypted with `ansible-vault`? Not plaintext in `group_vars`, `host_vars`, or playbooks.
- [ ] `no_log: true` on tasks that handle passwords, tokens, or keys?
- [ ] Vault password not committed? (`.vault_pass` in `.gitignore`, or use `--ask-vault-pass`)
- [ ] No `command`/`shell` tasks with user-controlled variables without validation?
- [ ] SSH private keys not in the repo? (use vault or CI secret injection)
- [ ] `become` (sudo/doas) only where needed, not globally?
- [ ] `ansible_become_password` not in plaintext inventory?

### Docker Compose (skip if not applicable)

- [ ] No `privileged: true` on runtime containers?
- [ ] No `network_mode: host` without justification?
- [ ] Sensitive env vars from `.env` or secrets, not hardcoded in `docker-compose.yml`?
- [ ] Volumes don't mount sensitive host paths (`/`, `/etc`, `/root`, Docker socket)?
- [ ] Docker socket (`/var/run/docker.sock`) not mounted unless required and documented?
- [ ] `read_only: true` where feasible?
- [ ] Images pinned to digests or specific tags, not `latest`?

### Proxmox / LXC (skip if not applicable)

- [ ] API tokens scoped to minimum required privileges? (not `Administrator` role for automation)
- [ ] API access over HTTPS with valid certificate? (not `--insecure` or TLS verification disabled in scripts)
- [ ] API token secrets not hardcoded in Terraform/Ansible? (use vault or env vars)
- [ ] Privileged LXC containers justified? Unprivileged is the default and safer.
- [ ] `nesting=1,keyctl=1` only on containers that actually run Docker/Podman inside?
- [ ] LXC mount points (`mp0`, `mp1`) don't expose sensitive host paths (`/etc`, `/root`, `/var/lib/pve`)?
- [ ] Proxmox firewall enabled on datacenter and node level? (disabled by default)
- [ ] Backup encryption enabled for Proxmox Backup Server? (plaintext backups expose all VM/CT data)
- [ ] No shared storage (NFS/CIFS) mounted with write access from untrusted VMs/CTs?
- [ ] `root@pam` not used for API automation? (create dedicated API users/tokens)
- [ ] Two-factor auth enabled for web UI access?
- [ ] Cluster communication (`corosync`) on isolated VLAN, not on the management network?
- [ ] Management web UI on a dedicated VLAN, not accessible from VM/CT subnets?
- [ ] MFA (TOTP/WebAuthn) enforced on ALL admin accounts, not just root?
- [ ] Emergency/break-glass accounts documented with rotation schedule?
- [ ] Hardening baseline pinned and drift-detected? (see [Proxmox Hardening Guide](https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide))

### Cloud-Init / User Data (skip if not applicable)

- [ ] No plaintext passwords or tokens in user-data scripts?
- [ ] SSH keys injected via cloud provider metadata, not hardcoded?
- [ ] Scripts fetched over HTTPS with integrity verification (checksums)?
- [ ] No `curl | bash` patterns without pinned URL + checksum?

## CI/CD & Supply Chain (Pass 8)

### CI/CD Workflows

- [ ] **Actions pinning**: CI actions pinned to commit SHAs, not mutable tags? (`actions/checkout@<sha>` not `@v4`)
- [ ] **GITHUB_TOKEN permissions**: is `permissions:` block present and minimal (not default write-all)?
- [ ] **Secrets exposure**: are secrets passed only to steps that need them, not globally?
- [ ] **Pull request target**: are workflows triggered by `pull_request_target` reviewing untrusted code with write permissions?
- [ ] **Script injection**: are `${{ github.event.*.body }}` or similar user-controlled expressions used in `run:` blocks?
- [ ] **Artifact poisoning**: are artifacts from PR builds trusted in subsequent workflows?

### Supply Chain Hardening

- [ ] **CI job images pinned to digest**: all `image:` references in CI configs use `tag@sha256:digest` format, not bare tags? Tags can be force-pushed to point at malicious images (Trivy/TeamPCP supply chain attack, 2026-03-19 - 76 of 77 version tags force-pushed in trivy-action).
- [ ] **No `:latest` tags in CI jobs**: CI job images don't use `:latest`? Combined with `pull_policy: always`, a single Docker Hub push silently compromises all pipeline runs.
- [ ] **CI runner credentials scoped**: `$DOCKER_AUTH_CONFIG` and registry credentials only injected into jobs that need private registry access, not globally?
- [ ] **Docker Content Trust**: `DOCKER_CONTENT_TRUST=1` set on CI runners to reject unsigned images?
- [ ] **Registry pull-through cache**: CI images pulled through a private registry mirror rather than directly from public registries? Provides audit chokepoint and caching buffer against compromised upstream images.
- [ ] **Security scanner egress restricted**: vulnerability scanners (Trivy, etc.) running in-cluster have network policies limiting egress to only required destinations (DB downloads, registries, webhooks)?
- [ ] **Scanner service account scope**: security scanner operators don't have broader cluster access than necessary? Review `accessGlobalSecretsAndServiceAccount` and similar flags.
- [ ] **Deprecated tools removed**: EOL security tools (e.g., tfsec) replaced with maintained alternatives? Abandoned repos are prime supply chain targets.

### OSS Governance

- [ ] **SECURITY.md**: does the repo have a security policy and vulnerability disclosure process?
- [ ] **dependabot.yml / renovate.json**: is automated dependency updating configured?
- [ ] **Branch protection**: is the default branch protected (require reviews, status checks, no force push)?
- [ ] **SBOM generation**: is a Software Bill of Materials generated on release?
- [ ] **Release signing**: are releases/containers signed (cosign, sigstore)?
- [ ] **CODEOWNERS**: is the file present for security-critical paths?
- [ ] **License compliance**: are dependency licenses compatible?

### OpenSSF Scorecard (if the tool is available)

```
scorecard --repo=github.com/OWNER/REPO --format json
```
