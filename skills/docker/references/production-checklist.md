# Docker Production Checklist

Deploy-time and operational checks that go on top of the build-time AI Self-Check in SKILL.md, plus the PCI-DSS 4.0 compliance checklist.

## Deploy-time additions

- [ ] runc >= 1.4.0 (CVE-2025-31133/52565/52881 patched)
- [ ] BuildKit >= 0.33.1 (includes CVE-2026-15793, CVE-2026-33747/33748, and CVE-2026-93318 fixes)
- [ ] Docker Desktop >= 4.71.0 (adds CVE-2026-5817/5843 Model Runner container-to-host RCE fixes; see the CVE table in `references/security-and-compliance.md` for the earlier CVE-2025-9074 and CVE-2026-28400 floors)
- [ ] Trivy v0.72.0+ from official releases (v0.69.4-6 COMPROMISED)
- [ ] Images signed with cosign, verified at deploy
- [ ] SBOM generated for every production image
- [ ] Vulnerability scanning in CI (Docker Scout, Grype, or Trivy v0.72.0+)
- [ ] CI tools pinned to SHA256 digests (not mutable tags)
- [ ] Base images rebuilt/updated regularly (weekly minimum)
- [ ] Separate override files for dev/prod
- [ ] Logging config with rotation (`max-size`, `max-file`)
- [ ] `read_only: true` + `no-new-privileges` + `cap_drop: ALL` on production services

## Compliance (PCI-DSS 4.0)

- [ ] Containers run as non-root with minimal capabilities (Req 2.2)
- [ ] Read-only root filesystem, one process per container (Req 2.2)
- [ ] Images scanned for vulnerabilities before deployment (Req 6.3)
- [ ] SBOM generated for every CDE image (Req 6.3.2)
- [ ] No hardcoded secrets in images or compose files (Req 8.6.2)
- [ ] Image digests pinned for immutability (Req 5/11.5)
- [ ] Container logs shipped to immutable SIEM (Req 10)
- [ ] Runtime detection in place (Falco/Tetragon) (Req 5.2/5.3)
- [ ] Registry access audit-logged (Req 10.4.1.1)
- [ ] Base images from trusted, verified sources (Req 6.2.1)
