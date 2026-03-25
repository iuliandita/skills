# Container Security & PCI-DSS 4.0 Compliance

Security hardening, vulnerability management, supply chain integrity, and PCI-DSS 4.0 mapping for containerized environments. Updated March 2026.

---

## 2025-2026 CVE Reference

### Critical vulnerabilities -- verify patched

| CVE | CVSS | Component | Impact | Fixed in |
|-----|------|-----------|--------|----------|
| CVE-2025-9074 | 9.3 | Docker Desktop | Container escape via unauthenticated Engine API (192.168.65.7:2375) | Desktop 4.44.3+ |
| CVE-2025-31133 | High | runc | Mount manipulation (/dev/null symlink) enables host procfs writes | runc 1.2.8, 1.3.3, 1.4.0-rc.3 |
| CVE-2025-52565 | High | runc | /dev/console race condition grants premature mount access | runc 1.2.8, 1.3.3, 1.4.0-rc.3 |
| CVE-2025-52881 | High | runc | procfs write redirect bypasses LSM relabel, host procfs writes | runc 1.2.8, 1.3.3, 1.4.0-rc.3 |
| CVE-2026-33634 | Critical | Trivy | Supply chain -- credential-stealing malware in aquasec/trivy Docker Hub images v0.69.4-6 | Trivy v0.69.3 (safe) |
| CVE-2026-2664 | Medium | Docker Desktop | gRPC-FUSE kernel module out-of-bounds read | Desktop 4.62.0+ |
| CVE-2025-13743 | Low | Docker Desktop | Expired Hub PATs leaked in diagnostic bundles via error object serialization | Desktop 4.54.0+ |

### Verification commands

```bash
# Check component versions
docker version | grep -E "Version|API" ; true
docker info | grep -E "runc|containerd" ; true
runc --version 2>/dev/null | head -1 ; true
containerd --version 2>/dev/null ; true

# runc must be >= 1.2.8 or >= 1.3.3 or >= 1.4.0
# containerd should be >= 2.2.2

# Check for vulnerable Trivy images
docker images | grep trivy ; true
# If any show v0.69.4, v0.69.5, or v0.69.6:
# 1. Delete them immediately
# 2. Rotate ALL CI/CD secrets that any pipeline using those images had access to
```

---

## The Trivy Supply Chain Compromise (March 2026)

The defining container security event of 2026. Understanding it matters because the same attack pattern applies to any CI tool.

**Timeline:**
- March 19, 18:24 UTC: Attackers push credential-stealing malware into `aquasec/trivy` Docker Hub images (v0.69.4, 0.69.5, 0.69.6, and `latest` tag)
- March 19-23: Infostealer exfiltrates SSH keys, cloud creds, Docker configs, K8s tokens from CI pipelines pulling compromised images
- March 23: Aqua Security discovers compromise, begins remediation
- Escalation: Attackers compromise Aqua's GitHub org, defacing all 44 repositories
- Aftermath: evidence suggests attackers reestablished access after initial cleanup

The attackers are a cloud-native threat group active 2025-2026, known for Docker API exploitation, Kubernetes attacks, supply chain compromise, ransomware, cryptomining, and self-propagating worms.

**Why it succeeded:** Docker Hub images authenticate via the publisher's credentials. Once the CI/CD pipeline credentials were compromised, the pushed images were indistinguishable from legitimate ones. Mutable tags (`latest`, `v0.69.4`) meant existing workflows pulled malware without any change to their configs.

**A year earlier** (March 2025): `tj-actions/changed-files` was compromised the same way (CVE-2025-30066; upstream: reviewdog/action-setup CVE-2025-30154; ~12 hours of credential theft). These aren't isolated incidents -- supply chain attacks on CI tools are a recurring pattern.

### Lessons (apply to ALL container workflows)

1. **Pin images to SHA256 digests**, not tags:
   ```dockerfile
   # BAD: mutable tag
   FROM aquasec/trivy:0.69.3

   # GOOD: immutable digest
   FROM aquasec/trivy@sha256:abc123def456...
   ```

2. **Pin CI actions to commit SHAs**:
   ```yaml
   # BAD: mutable tag
   uses: aquasecurity/trivy-action@v0.35.0

   # GOOD: immutable SHA
   uses: aquasecurity/trivy-action@<full-40-char-commit-sha>
   ```

3. **Monitor for force-push events** on action repos you depend on. GitHub audit log and StepSecurity Harden-Runner can detect this.

4. **Vendor critical CI tools**: download verified binaries to a private cache, don't pull from upstream on every run.

5. **Rotate secrets immediately** if any CI pipeline ran compromised tools.

---

## Image Scanning Tool Matrix

| Tool | Scans | SBOM | Signs | Free | Notes |
|------|-------|------|-------|------|-------|
| **Docker Scout** | Images, SBOM, policies | Generate | No | Free tier | Built into Docker CLI. `docker scout cves`, `docker scout sbom` |
| **Trivy** (v0.69.3) | Images, IaC, repos, SBOM | Generate | No | Yes | Multi-purpose. PIN TO v0.69.3 |
| **Grype** (Anchore) | Images | No | No | Yes | Fast CVE scanner. Pair with Syft |
| **Syft** (Anchore) | N/A | Generate | No | Yes | SBOM generator. SPDX + CycloneDX |
| **Cosign** (Sigstore) | N/A | Attach | Yes | Yes | Keyless OCI signing. Industry standard |
| **Snyk Container** | Images, code | Generate | No | Free tier | Commercial, fix suggestions |
| **Clair** | Images | No | No | Yes | CVE matching. Maintained but older |

### Recommended CI pipeline

```bash
# 1. Build with attestations
docker buildx build --provenance=true --sbom=true -t $IMAGE --push .

# 2. Scan (use multiple tools for coverage)
docker scout cves $IMAGE --exit-code --only-severity critical,high
trivy image --severity HIGH,CRITICAL --exit-code 1 $IMAGE    # pinned v0.69.3!

# 3. Sign (keyless via Sigstore OIDC in CI)
cosign sign $IMAGE@sha256:$DIGEST

# 4. Generate and attach SBOM
syft $IMAGE -o spdx-json > sbom.spdx.json
cosign attach sbom --sbom sbom.spdx.json $IMAGE@sha256:$DIGEST

# 5. Deploy (admission controller verifies signature)
```

---

## Image Signing Workflow

### Keyless signing (CI/CD, recommended)

Uses Sigstore's Fulcio CA + Rekor transparency log. No key management needed. **Cosign v2 vs v3**: v3 changed the default bundle format and verification flags. If verification fails, check the cosign version on both sign and verify sides. The commands below work with both v2 and v3.

```bash
# Sign (in GitHub Actions / GitLab CI with OIDC)
cosign sign ghcr.io/org/app@sha256:<digest>

# Verify
cosign verify ghcr.io/org/app@sha256:<digest> \
  --certificate-identity="ci@org.com" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### Key-pair signing (air-gapped / private environments)

```bash
cosign generate-key-pair
cosign sign --key cosign.key ghcr.io/org/app@sha256:<digest>
cosign verify --key cosign.pub ghcr.io/org/app@sha256:<digest>
```

### SBOM generation and attachment

```bash
# Docker Scout (built-in)
docker scout sbom ghcr.io/org/app:1.0.0

# Syft (standalone)
syft ghcr.io/org/app:1.0.0 -o spdx-json > sbom.spdx.json
syft ghcr.io/org/app:1.0.0 -o cyclonedx-json > sbom.cdx.json

# Attach SBOM to image
cosign attach sbom --sbom sbom.spdx.json ghcr.io/org/app@sha256:<digest>
cosign sign --attachment sbom ghcr.io/org/app@sha256:<digest>
```

SBOM generation is becoming mandatory in many regulatory contexts (US Executive Order, NIS2, PCI-DSS 4.0 Req 6.3.2).

---

## Runtime Hardening

### Compose hardened baseline

```yaml
services:
  app:
    image: myapp:1.0.0@sha256:abc123    # digest-pinned
    read_only: true                      # read-only root filesystem
    security_opt:
      - no-new-privileges:true           # prevent SUID exploitation
    cap_drop:
      - ALL                              # drop all Linux capabilities
    cap_add: []                          # add back ONLY what's needed
    tmpfs:
      - /tmp                             # writable temp (size-limited)
    user: "1001:1001"                    # explicit non-root UID/GID
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      start_period: 15s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### Capability reference

When `cap_drop: ALL` breaks something, add back ONLY what's needed:

| Capability | When needed |
|-----------|------------|
| `NET_BIND_SERVICE` | Bind to ports < 1024 |
| `CHOWN` | Change file ownership (some databases) |
| `SETUID` / `SETGID` | Process identity changes (databases, init scripts) |
| `DAC_OVERRIDE` | Override file permissions (PostgreSQL, MySQL) |
| `FOWNER` | Bypass ownership checks (some database init) |
| `SYS_PTRACE` | Debugging, some monitoring tools |

**Never add** without explicit justification: `SYS_ADMIN`, `ALL`, `NET_RAW`, `MKNOD`.

### Docker daemon hardening

`/etc/docker/daemon.json`:

```json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true,
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": { "Hard": 64000, "Name": "nofile", "Soft": 64000 }
  }
}
```

Key settings:
- `icc: false` -- disable inter-container communication on default bridge
- `no-new-privileges: true` -- global default, prevents privilege escalation via SUID
- `userns-remap: default` -- maps container root to unprivileged host user
- `live-restore: true` -- containers survive daemon restarts

### Secrets management

**Build-time** (BuildKit secret mounts):

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
    git clone https://${GITHUB_TOKEN}@github.com/org/repo.git
```

The secret is available ONLY during the `RUN` that mounts it. Not in any layer. Not in `docker history`.

**Runtime** (Compose secrets):

```yaml
secrets:
  api_key:
    file: ./secrets/api_key.txt
  db_pass:
    environment: DB_PASSWORD_SECRET    # from host env (Compose v5)

services:
  app:
    secrets: [api_key, db_pass]
    environment:
      API_KEY_FILE: /run/secrets/api_key
```

**What NOT to do:**

```dockerfile
# NEVER: baked into image history
ARG DB_PASSWORD
ENV DB_PASSWORD=$DB_PASSWORD
COPY .env /app/.env
```

---

## PCI-DSS 4.0 Container Requirements

PCI-DSS 4.0 is the only active version (3.2.1 retired March 2024). All future-dated requirements became mandatory March 31, 2025.

### Requirements mapped to container controls

| PCI Req | Title | Container implementation |
|---------|-------|------------------------|
| 1.2 | Network segmentation | Separate Docker networks for CDE vs non-CDE. `internal: true` on CDE backend networks. No `network_mode: host`. |
| 2.2 | Harden system components | Non-root user, drop all caps, read-only rootfs, one process per container, minimal base image |
| 2.2.4-6 | Remove unnecessary functionality | Distroless/Chainguard base images. No shells, package managers, or dev tools in production. |
| 5.2/5.3 | Malware protection, FIM | Immutable images (deploy by digest). `read_only: true`. Runtime detection (Falco/Tetragon). |
| 6.2.1 | Bespoke and custom software developed securely | Images from verified publishers. Signed with cosign. Verified at deployment (admission control). |
| 6.3.1 | Vulnerability identification | Image scanning in CI (Docker Scout, Grype, Trivy v0.69.3) and before every deployment. |
| 6.3.2 | Component inventory | SBOM generated for every production image. Stored and queryable. |
| 6.4.2 | WAF on public-facing apps | Reverse proxy with WAF (ModSecurity, Cloud Armor) in front of CDE containers. |
| 8.6.2 | No hardcoded secrets | No secrets in Dockerfiles, Compose files, env vars, committed `.env` files. Use Compose secrets or Vault. |
| 10.4.1.1 | Automated audit log review | Container stdout/stderr to immutable SIEM. Docker daemon audit logging. Log rotation configured. |
| 11.5 | Change detection / FIM | Image digest pinning (any change = new digest). Falco for runtime FIM. ArgoCD/Flux for deployment drift. |

### CDE container isolation

For PCI CDE workloads running in Docker Compose (non-Kubernetes):

```yaml
networks:
  cde:
    driver: bridge
    internal: true
    driver_opts:
      com.docker.network.bridge.enable_ip_masquerade: "false"

services:
  payment-processor:
    image: payment:1.0.0@sha256:abc123
    networks: [cde]
    read_only: true
    security_opt: [no-new-privileges:true]
    cap_drop: [ALL]
    user: "1001:1001"
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "10"
        tag: "cde/{{.Name}}"
```

### PCI MPoC considerations

MPoC (Mobile Payments on COTS) backend infrastructure falls under full PCI-DSS 4.0 scope. No container-specific addenda -- standard PCI-DSS 4.0 controls apply. Key points:

- A&M backends: containerized or not, same PCI requirements
- Container logs from MPoC backends: immutable, retained per Req 10
- Image provenance: signed and SBOM'd (Req 6.2.1, 6.3.2)
- Network segmentation between MPoC and non-MPoC containers (Req 1)

### QSA evidence for containerized environments

What a QSA wants to see:

1. **Build pipeline**: signed commits -> CI build -> scan results -> image signing -> push to private registry
2. **Scan reports**: per-image, per-deployment (Docker Scout, Trivy, Grype output)
3. **SBOM archive**: component inventory for every deployed image version
4. **Runtime config**: Compose/K8s configs showing read-only rootfs, non-root, dropped caps
5. **Network topology**: CDE vs non-CDE container network diagrams
6. **Log evidence**: immutable container logs with audit trail
7. **Secret management evidence**: no hardcoded secrets in git history, image layers
8. **Patch management**: base image update frequency, runc/containerd version verification

### Docker Hardened Images (DHI)

Docker offers commercial Hardened Images for security-critical workloads:
- Ultra-minimal, purpose-built for production
- No shell or package manager in prod variants
- Pre-scanned with Docker Scout
- Accelerated CVE patching SLA
- Available for common runtimes (Node.js, Python, Go, Java, Nginx, etc.)

Evaluate alongside Chainguard images for PCI CDE workloads.
