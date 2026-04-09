# PCI-DSS 4.0 Kubernetes Compliance

PCI-DSS 4.0/4.0.1 requirement mapping to Kubernetes controls. PCI-DSS 3.2.1 was retired March 2024. 51 future-dated requirements became mandatory March 31, 2025.

Key shift: PCI-DSS 4.0 is outcome-based with a "customized approach" - prove your K8s controls meet the objective, not that you followed a specific recipe. Continuous compliance replaces annual point-in-time assessment.

---

## Requirements Mapped to K8s Controls

### Req 1 - Network Segmentation

| Sub-req | K8s implementation |
|---------|-------------------|
| 1.2 (restrict traffic) | **NetworkPolicies** with default-deny ingress+egress per namespace, then explicit whitelist rules. Use Cilium for L7 policies. |
| 1.2.5 (services, protocols, and ports allowed with business justification) | Private API server endpoints; authorized CIDR blocks for kubectl access. |
| 1.3 (restrict direct public CDE access) | Private clusters (no public endpoint); Gateway API / ingress in DMZ namespace only. |
| 1.4 (firewall between untrusted and CDE) | VPC-native clusters; separate subnets per node pool. |

### Req 2 - Secure Defaults

| Sub-req | K8s implementation |
|---------|-------------------|
| 2.2.4-6 (harden system components) | Container-Optimized OS or Talos Linux for nodes; distroless or scratch base images; remove unnecessary packages/services from containers. |

### Req 3 - Protect Stored Data

| Sub-req | K8s implementation |
|---------|-------------------|
| 3.5 (render PAN unreadable) | **etcd encryption at rest** via KMS v2 provider (Vault, AWS KMS, GCP Cloud KMS, Azure Key Vault). |
| 3.5.1.2 (disk-level alone insufficient) | KMS-backed `EncryptionConfiguration` for Secrets. Node disk encryption is NOT enough. |
| 3.6/3.7 (key management) | **External Secrets Operator** or **Vault Agent Injector** syncing from Vault; key rotation policies. **Sealed Secrets** acceptable for static secrets with documented key management (see `sealed-secrets.md` PCI-DSS section for gaps and mitigations). |

### Req 4 - Encrypt Transmissions

| Sub-req | K8s implementation |
|---------|-------------------|
| 4.1/4.2 (TLS 1.2+ everywhere) | **mTLS via service mesh** (Istio strict, Cilium mutual auth); TLS at ingress; internal service-to-service encryption. |
| 4.2.1.1 (certificate inventory) | **cert-manager** with automated rotation; certificate monitoring dashboards. |

### Req 5 - Malware Protection

| Sub-req | K8s implementation |
|---------|-------------------|
| 5.2/5.3 (anti-malware, FIM) | **Falco** (eBPF runtime detection); read-only root filesystems; **immutable images** (deploy by SHA256 digest). |

### Req 6 - Secure Development

| Sub-req | K8s implementation |
|---------|-------------------|
| 6.2.1 (bespoke and custom software developed securely) | **Kyverno** / **OPA Gatekeeper** admission policies requiring cosign-signed images from approved registries. |
| 6.3.1 (vulnerability identification) | **Trivy** / **Grype** in CI pipeline scanning every image before push. |
| 6.3.2 (component inventory) | **SBOMs** generated at build time (Syft, Trivy SBOM); stored and queryable alongside images. |
| 6.4.2 (WAF on public-facing apps) | ModSecurity, Cloud Armor, or dedicated WAF in front of ingress/gateway. |

### Req 7 - Restrict Access

| Sub-req | K8s implementation |
|---------|-------------------|
| 7.2 (least privilege) | **RBAC**: per-namespace Roles/RoleBindings; no cluster-admin for workloads; dedicated ServiceAccounts per deployment. |
| 7.2.5 (review app account access) | Audit RBAC bindings quarterly; use rbac-lookup, rakkess. |

### Req 8 - Authentication

| Sub-req | K8s implementation |
|---------|-------------------|
| 8.2/8.3 (unique IDs, strong auth) | OIDC integration (Dex, Keycloak); no shared kubeconfig files. |
| 8.4.2 (MFA for all CDE access) | MFA on all kubectl access paths via identity provider; no direct cert-based auth without MFA. |
| 8.6.2 (no hardcoded secrets) | External secrets management; no secrets in ConfigMaps, env vars in manifests, or Helm values. |

### Req 10 - Logging & Monitoring

| Sub-req | K8s implementation |
|---------|-------------------|
| 10.2 (log all CDE access) | **K8s API audit logging** at `RequestResponse` level for CDE namespaces; ship to SIEM. |
| 10.2.2 (audit log record format and content) | Audit policy capturing all create/update/patch/delete on CDE namespace resources. Note: admin action logging is at 10.2.1.2. |
| 10.4.1.1 (automated log review) | SIEM alert rules; Prometheus alerting on anomalous API patterns; Falco runtime alerts to incident response. |
| 10.5 (protect audit logs) | Ship to immutable storage (S3 Object Lock, WORM); separate credentials for log shipping. |
| 10.5.1 (retain 12 months) | 12 months minimum, 3 months immediately available. |
| 10.7.1 (detect control failures) | Health checks on log pipelines; alert if Falco/audit-log shipping stops. Note: 10.7.1 is a service-provider-only requirement. |

### Req 9 - Restrict Physical Access

Cloud provider responsibility for managed K8s (EKS, GKE, AKS). Document the shared responsibility model. For self-hosted clusters, standard datacenter physical security controls apply - not K8s-specific.

### Req 11 - Security Testing

| Sub-req | K8s implementation |
|---------|-------------------|
| 11.3.1 (quarterly vuln scans) | **Trivy Operator** (v0.69.3 - see supply chain warning below) continuous in-cluster scanning; registry scanning on schedule. |
| 11.3.1.2 (authenticated internal scans) | **Application-level** scans with credentials (Nessus, Qualys, OpenVAS) from within the cluster network. This is NOT the same as image scanning - PCI requires scanning the running application endpoints with authenticated plugins. Trivy/Grype scan images; Nessus/Qualys scan the live app. You need both. |
| 11.5/11.5.2 (FIM, change detection) | **Falco** rules for critical file writes; **ArgoCD/Flux** drift detection (Git as source of truth); admission controllers blocking non-compliant changes. |

### Req 12 - Organizational Policies

| Sub-req | K8s implementation |
|---------|-------------------|
| 12.3.1 (risk-based control frequency) | Documented risk assessments for scan/rotation/review intervals. |
| 12.10 (incident response) | Pod isolation via NetworkPolicy updates; container forensics (snapshot before termination); K8s-specific runbooks. |

---

## CDE Isolation Patterns

### Pattern A: Dedicated Cluster (Recommended)

Separate K8s cluster exclusively for CDE workloads. Simplest to validate with QSAs. Clear network boundary.

### Pattern B: Shared Cluster with Hard Isolation (Complex)

If co-locating CDE and non-CDE on the same cluster, ALL of these are required:

**Namespace isolation:**
- Dedicated namespaces: `pci-cde`, `pci-dmz`, `internal`, `management`
- Labels: `pci-zone: cde`, `pci-zone: non-cde` on every namespace

**Network:**
- Default-deny-all NetworkPolicies per namespace
- Explicit allow rules: DMZ -> CDE only on specific ports
- Block all CDE egress to internet except specific payment gateway FQDNs (Cilium L7 policies)

**Node isolation:**
- Dedicated node pools for CDE workloads (taints + tolerations)
- Separate subnets per node pool
- Node-level firewall rules

**Runtime isolation:**
- **gVisor** or **Kata Containers** for CDE pods (sandbox the kernel)
- **User namespaces** (`hostUsers: false`, enabled by default since 1.33) - maps container UID 0 to unprivileged host UID. Container breakout doesn't yield host root. Significant for QSA demonstrations of privilege isolation.
- Seccomp restricted profiles
- AppArmor/SELinux mandatory

**DNS:**
- Separate CoreDNS instances per zone, or DNS policies preventing CDE pods from resolving non-CDE services

**RBAC:**
- No cluster-admin
- Per-namespace Roles only; no ClusterRoleBindings for workload ServiceAccounts
- Separate identity providers or OIDC groups for CDE vs non-CDE operators

**Admission:**
- Kyverno / Gatekeeper enforcing: image signing, no default namespace, no latest tags, resource limits, read-only rootfs, no privileged containers

**Audit:**
- Separate audit log streams for CDE namespaces
- RequestResponse audit level for CDE

### QSA Perspective

- **Namespaces alone are NOT sufficient** for PCI scoping. K8s was not designed for hard multi-tenancy.
- **Shared clusters put the entire cluster in scope** unless you demonstrate isolation equivalent to separate networks.
- QSAs will probe privilege escalation paths (service account tokens, kubelet creds, node breakout).
- **Most QSAs strongly prefer dedicated clusters.** Shared clusters require significantly more evidence.

---

## K8s Audit Policy for CDE

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests to CDE namespaces at RequestResponse level
  - level: RequestResponse
    namespaces: ["pci-cde", "pci-dmz"]
    resources:
      - group: ""
        resources: ["pods", "services", "secrets", "configmaps", "serviceaccounts", "persistentvolumeclaims"]
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets"]
      - group: "batch"
        resources: ["jobs", "cronjobs"]
      - group: "networking.k8s.io"
        resources: ["networkpolicies", "ingresses"]
      - group: "gateway.networking.k8s.io"
        resources: ["httproutes", "gateways"]
  # Log all authentication events
  - level: Metadata
    nonResourceURLs: ["/api*", "/healthz*"]
  # Log RBAC changes cluster-wide
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
```

---

## etcd Encryption for PCI

K8s Secrets are base64-encoded, not encrypted in etcd by default. PCI Req 3.5 demands actual encryption.

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - kms:
          apiVersion: v2              # KMS v2 mandatory; v1 deprecated
          name: vault-kms-provider
          endpoint: unix:///run/kmsplugin/socket.sock
      - identity: {}                  # fallback for reading unencrypted secrets
```

**Ranked by PCI compliance:**
1. **External KMS** (Vault, AWS KMS, GCP Cloud KMS, Azure Key Vault) - best; keys never on disk; audit trail
2. **aescbc with external key** - acceptable; key in EncryptionConfiguration file
3. **aesgcm** - acceptable but manual key rotation
4. **identity (plaintext)** - NOT PCI COMPLIANT

---

## PCI MPoC (Mobile Payments on COTS)

PCI MPoC v1.1 (released Nov 2024, latest) governs accepting card payments on commercial off-the-shelf devices (tap-to-pay on phone, SoftPOS). Builds upon and unifies the older SPoC and CPoC standards (which are not yet deprecated by payment schemes). 5 security domains with modular requirements.

### The 5 domains

| Domain | Scope | Infra relevance |
|---|---|---|
| 1. Software Core | SDK security, crypto, key injection | App team |
| 2. Application Integration | SDK integration, app-level security | App team |
| **3. Attestation & Monitoring** | **Backend that checks device health, detects anomalies, disables compromised devices** | **Your K8s infra** |
| 4. Software Management | SDK distribution, key management, updates | DevOps/app overlap |
| **5. MPoC Solution** | **Solution provider's infra, third-party management** | **Your cloud/cluster** |

### Domain 3 - A&M backend (the infra-critical one)

The Attestation & Monitoring backend must either be:
- **PCI-DSS certified** (full assessment - most common path), OR
- Assessed against **MPoC Appendix A** by the MPoC security lab (lighter, only when A&M is isolated from account data processing)

**What Domain 3 requires from K8s infra:**
- **Continuous device monitoring**: measurements must be fresh and authentic. The backend collects attestation data from every enrolled device and analyzes it in near-real-time.
- **Anomaly detection + response**: detect rooted/jailbroken devices, emulators, screen sharing, RASP violations. Must be able to disable compromised devices immediately.
- **Low latency**: real-time attestation affects pod scheduling, node affinity, HPA thresholds, and geographic placement. Consider dedicated node pools and topologySpreadConstraints for A&M workloads.
- **Availability**: A&M downtime = merchants can't process payments. HA with PDB, multi-AZ, aggressive readiness probes.
- **RASP integration**: client-side integrity violations are reported to the A&M backend and must be logged, analyzed, and acted on.
- **Annual pen testing**: the entire SoftPOS solution (mobile + backend) requires independent vulnerability assessment and penetration testing annually to maintain MPoC certification.

### v1.1 changes (Nov 2024)

- Expanded definition: now includes POI devices and enterprise devices, not just consumer phones
- SDK composition: one MPoC SDK can integrate another (may change attestation flow)
- Removed kernel functional validation requirements (simplifies some device checks)
- New guidance document + technical FAQs (v1.8, Sep 2025) for implementation clarity

### K8s architecture for MPoC A&M

All PCI-DSS 4.0 controls in this document apply to the A&M backend cluster. Additionally:
- **Dedicated namespace or cluster** for A&M workloads (same CDE isolation principles)
- **mTLS** between A&M services and any payment processing components
- **Immutable audit logs** for all attestation decisions (device enrolled/disabled/flagged)
- **Rate limiting + DDoS protection** on attestation endpoints (exposed to all merchant devices)
- **Geographic affinity** if latency SLAs require regional deployment

---

## Compliance Tooling

### Open Source

| Tool | Coverage |
|------|---------|
| **kube-bench** | CIS K8s Benchmark; run as Job, maps to multiple PCI requirements |
| **Falco** | Runtime detection (Req 11.5, 5.2, 10.2); PCI-DSS rule pack included |
| **Tetragon** | eBPF runtime enforcement |
| **Trivy** / **Trivy Operator** | Image scanning (Req 6.3.1, 11.3), SBOM generation (Req 6.3.2), K8s misconfiguration scanning |
| **Checkov** | IaC scanning with PCI-DSS policy pack; auto-generates compliance reports |
| **Kyverno** / **OPA Gatekeeper** | Admission policies (Req 6.2.1, 7.2) |
| **ArgoCD** / **Flux** | GitOps drift detection (Req 11.5 FIM equivalent) |
| **cert-manager** | Certificate lifecycle (Req 4.2.1.1) |
| **External Secrets Operator** | Secrets management (Req 3.6, 8.6.2) |
| **Sealed Secrets** | Encrypted secrets in git (Req 8.6.2); partial Req 3.6 (see gaps in `sealed-secrets.md`) |
| **Cilium** / **Calico** | NetworkPolicy enforcement (Req 1.2) |

### Commercial

| Tool | Coverage |
|------|---------|
| **Prisma Cloud** (Palo Alto) | Full lifecycle: scanning, runtime, PCI dashboards |
| **NeuVector** (SUSE, open-source) | Runtime protection, segmentation visualization, CIS scanning |
| **Sysdig Secure** | Falco-based runtime + scanning + PCI compliance reporting |
| **Wiz** | Cloud + K8s security posture; PCI framework built-in |
| **Kubescape** (ARMO) | Open-source scanner; NSA, MITRE, CIS, PCI frameworks |

### Cloud Provider References

- **GKE**: PCI-DSS v4.0 constraint templates for Policy Controller
- **AKS**: Multi-part PCI-DSS 4.0.1 reference architecture (network, identity, data, malware, monitoring, policy)
- **EKS**: AWS whitepaper "Architecting Amazon EKS and Bottlerocket for PCI DSS Compliance"

---

## Actionable Checklist

1. **Decide scope**: Dedicated CDE cluster (preferred) or shared with hard isolation
2. **Lock down control plane**: Private API endpoint, OIDC auth with MFA, no static tokens
3. **etcd encryption**: KMS v2 provider, not identity/plaintext, not disk-level alone
4. **RBAC**: Per-namespace, least privilege, no cluster-admin for workloads, quarterly review
5. **NetworkPolicies**: Default-deny-all on every namespace, explicit allow, test with kubectl exec probes
6. **mTLS**: Between all CDE services (Istio strict / Cilium mutual auth)
7. **Image pipeline**: Scan (Trivy) -> sign (cosign) -> SBOM (Syft) -> verify at admission (Kyverno)
8. **Runtime security**: Falco with PCI rule pack, seccomp restricted, read-only rootfs, no privileged
9. **Secrets**: ESO, Vault, or Sealed Secrets (document PCI gaps if using Sealed Secrets); no plaintext secrets in Git/ConfigMaps/env vars/Helm values
10. **Audit logging**: K8s audit policy at RequestResponse for CDE, ship to immutable SIEM, automated alerts
11. **Certificates**: cert-manager, automated rotation, inventory dashboard
12. **Vulnerability scanning**: Continuous (Trivy Operator), quarterly authenticated internal scans (Req 11.3.1.2)
13. **FIM**: Falco runtime + ArgoCD drift detection + image digest pinning
14. **Incident response**: Runbooks for container forensics, pod isolation, snapshot-before-kill
15. **Node hardening**: Container-Optimized OS / Talos; kube-bench CIS pass; auto-patching
16. **Documentation**: Network diagrams (showing K8s objects), data flow diagrams, risk assessments, RBAC review records
