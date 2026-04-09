# Kubernetes Architecture Decision Framework

Deep-dive reference for cluster design, GitOps strategy, security architecture, and operational patterns. Updated for K8s 1.33-1.35+ and Helm 4.

---

## Cluster Topology Decision Matrix

| Factor | Single Cluster | Multi-Cluster |
|--------|---------------|---------------|
| Services | < 50 | 50+ |
| Teams | 1 | 2+ |
| Regions | 1 | Multi |
| Compliance | Standard | PCI-DSS/HIPAA/SOC2 |
| Blast radius | Acceptable | Must isolate |
| Cost sensitivity | High | Lower priority |

### Multi-Cluster Patterns

**Hub-spoke** (management + workload):
- Central management cluster runs ArgoCD/Flux, monitoring, RBAC
- Workload clusters are cattle - replaceable, version-pinned
- Best for: platform teams managing multiple product teams

**Per-environment** (dev/staging/prod):
- Strict isolation between environments
- Promotion via Git (not cluster-to-cluster)
- Best for: regulated environments (PCI, HIPAA), teams that need prod isolation

**Regional**:
- Data residency compliance (GDPR, sovereignty laws)
- Latency-sensitive workloads
- Active-active for global HA
- Best for: multi-region SaaS, CDN-like workloads

**Cluster API** (lifecycle management):
- Declarative cluster provisioning and upgrades
- Version-controlled cluster definitions
- Best for: 5+ clusters, platform engineering teams

---

## GitOps Strategy

### ArgoCD vs Flux

| Aspect | ArgoCD v3.3+ | Flux v2 |
|--------|-------------|---------|
| UI | Built-in, rich | Capacitor (Gimlet) or community forks (Weaveworks shut down Feb 2024) |
| Multi-cluster | Native (single control plane) | Per-cluster Flux instance |
| Helm | Application CRD wraps `helm template` (no lifecycle) | HelmRelease CRD (full lifecycle: install/upgrade/test/rollback) |
| RBAC | Fine-grained on deployments | Kubernetes RBAC |
| Sync | Pull-based, configurable | Pull-based, event-driven |
| SSA | Supported (v3.3+, aligns with Helm 4) | Supported |
| Multi-tenancy | Projects/AppProjects | GitRepository per tenant |
| Learning curve | Lower (UI helps) | Higher (all YAML) |
| Helm hooks | Maps to sync waves; `test` hooks NOT supported | Full hook support via HelmRelease |

### Repository Patterns

**Mono-repo** (`infrastructure/`):
```
infrastructure/
+-- apps/
|   +-- app-a/
|   |   +-- base/
|   |   +-- overlays/
|   |       +-- dev/
|   |       +-- staging/
|   |       +-- prod/
|   +-- app-b/
+-- platform/
|   +-- monitoring/
|   +-- gateway/          # Gateway API resources
+-- clusters/
    +-- dev/
    +-- prod/
```

**Multi-repo**:
- `app-repo`: application code + Dockerfile
- `config-repo`: Kubernetes manifests / Helm values per env
- `infra-repo`: cluster definitions, platform services, Terraform

**App-of-apps** (ArgoCD):
```yaml
# root-app.yaml - manages all child Applications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <config-repo>
    path: apps
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:          # non-prod only - Critical Rule #5: no auto-sync to prod
      prune: true
      selfHeal: true
```

### ArgoCD + Helm 4 Notes

- ArgoCD 3.3+ needed for Helm 4 compatibility (Kubernetes version format change).
- Multi-source Applications (mature since ArgoCD 2.6) for separating chart version from env values.
- `ignoreMissingValueFiles: true` for default/override patterns with ApplicationSets.
- OCI charts: omit `oci://` prefix in ArgoCD's `repoURL`.
- Wildcard valueFiles (ArgoCD v3.4+, RC as of March 2026): `valueFiles: ["values/*.yaml"]`.
- **Anti-pattern**: `randAlphaNum` or other random functions in Helm templates - causes perpetual OutOfSync.

### Promotion Strategy

**PR-based** (recommended):
1. CI builds image, pushes to registry with SHA tag, signs with cosign
2. CI opens PR to config repo updating image tag/digest in staging overlay
3. Staging auto-syncs, runs smoke tests
4. Manual PR from staging -> prod overlay
5. Reviewer approves, ArgoCD/Flux syncs prod

**Automated pipeline**:
1. CI builds + pushes + signs image
2. Image Automation Controller (Flux) or Image Updater (ArgoCD) detects new tag
3. Auto-commits tag update to staging branch
4. After validation period, promotes to prod branch
5. Requires rollback automation (revert commit on failure)

---

## Networking

### Gateway API (the standard for new clusters)

Gateway API v1.5 is GA. Ingress-NGINX retired March 2026. All major implementations support it: Cilium, Envoy Gateway, Istio, Kong, Traefik, NGINX Gateway Fabric, cloud provider LBs.

Advantages over Ingress:
- Role-oriented design (infra admin manages Gateway, app dev manages HTTPRoute)
- Expressive routing (header matching, traffic splitting, mirroring, URL rewrites)
- Standardized extension model (no annotation hell)
- Cross-namespace references

### CNI: Cilium vs Calico

| Feature | Cilium v1.19+ | Calico v3.31+ |
|---------|--------------|---------------|
| Dataplane | eBPF-native | iptables (default) or eBPF |
| L7 Policy | Native (HTTP, gRPC, Kafka, DNS) | Via Envoy sidecar |
| Observability | Hubble (built-in, L3-L7 flow logs, service map) | Separate tooling |
| Service Mesh | Built-in (sidecar-free via eBPF) | No native mesh |
| Gateway API | Full support (L7 LB in v1.19) | Supported |
| Multi-OS | Linux only | Linux + Windows |
| BGP | Supported | Mature, production-proven |
| Scale | Constant-time lookups (hash tables) | iptables degrades; eBPF mode fixes this |

**Cilium** for greenfield. **Calico** for brownfield/multi-OS/enterprise with existing iptables investment.

### kube-proxy

- **nftables mode** is the future (available since 1.31).
- **IPVS mode** deprecated in 1.35, removal targeted for a future release (no firm version committed).
- **iptables mode** still works but consider migration planning.

### Service Mesh

Add only when needed - complexity cost is real.

| Mesh | Architecture | Status |
|------|-------------|--------|
| **Istio ambient** (v1.24+ GA) | ztunnel (node-level L4 mTLS) + optional waypoint proxies (L7) | Sidecarless mTLS with near-zero overhead. The "sidecars are too expensive" argument is dead. |
| **Cilium** | eBPF, no sidecar, no ztunnel | mTLS via WireGuard/IPsec. Simpler but less L7 control. |
| **Linkerd** | Rust micro-proxy sidecars | CNCF Graduated. Stable builds now vendor-only (Buoyant, Feb 2024). Source Apache 2.0 but you build or pay. Adoption cooling. |

---

## Security Architecture

### Admission Control (layered)

1. **ValidatingAdmissionPolicy (CEL)** - native since K8s 1.30 GA. No webhooks, no external deps. Use for standard policies (no `:latest`, require labels, require resource limits). The native answer for most admission needs.

2. **Kyverno** (v1.17+, CNCF Incubating) - for policies that need mutation or resource generation (auto-create NetworkPolicies, inject labels). CEL-based policies in beta (v1.16+). Momentum is stronger than OPA/Gatekeeper.

3. **OPA Gatekeeper** (v3.22+, OPA is CNCF Graduated) - Rego-based, cross-platform. Best when you need the same policy engine across K8s and non-K8s systems.

4. **Cedar** (AWS OSS) - unifies RBAC authorization + admission. Rust rewrite in progress. Not production-ready for K8s yet. Watch this space.

### Runtime Security

| Tool | CNCF Status | Role | Overhead |
|------|------------|------|----------|
| **Falco** v0.43+ | Graduated | Detection (syscall monitoring, rule engine) | 5-10% CPU |
| **Tetragon** v1.6+ | Incubating (Cilium) | Detection + enforcement (eBPF + LSM hooks) | <1% CPU |
| **KubeArmor** v1.6+ | Sandbox | Enforcement (AppArmor/SELinux/BPF-LSM) | Low |

**Practical combo**: Falco for detection/alerting (unmatched rule ecosystem, Falcosidekick integrations) + Tetragon for kernel-level enforcement (kill processes, not just alert).

### Supply Chain Security

**This is table stakes now. Not optional for serious deployments.**

| Tool | Purpose | Status |
|------|---------|--------|
| **cosign** (Sigstore) v3.x | Image signing (keyless via OIDC/Fulcio) | Industry standard. Docker retired DCT/Notary in favor of Sigstore (Aug 2025). |
| **Rekor** | Transparency log for signatures | All cosign signatures recorded publicly. |
| **Syft** / **Trivy** | SBOM generation | Attach SBOMs alongside images. Required for PCI-DSS 4.0 Req 6.3.2. |
| **SLSA** v1.0 | Build provenance framework | Level 2 achievable in an afternoon with GitHub Actions. Level 3 practical target. |
| **helm-sigstore** v0.3+ | Helm chart signing + Rekor upload | For chart distribution. |

Pipeline: build -> scan (Trivy/Grype) -> sign (cosign) -> generate SBOM (Syft) -> push to OCI registry -> verify at admission (Kyverno/Gatekeeper policy)

### CI/CD Supply Chain Hardening (post-Trivy compromise, March 2026)

The Trivy supply chain attack (CVE-2026-33634) demonstrated that **mutable Git tags and Docker Hub tags are not trustworthy** - attackers force-pushed all trivy-action tags to credential-stealing malware and published malicious Docker images.

**Non-negotiable rules for CI/CD:**
- **Pin ALL GitHub Actions to commit SHAs**: `uses: org/action@<40-char-sha>`, never `@v1` or `@latest`. This is now a PCI-DSS Req 6.2.1 expectation for CDE pipelines.
- **Pin CI tool images to SHA256 digests**: `image: tool@sha256:<digest>`, never `:latest` or even `:v1.2.3`.
- **Use Dependabot/Renovate** to update pinned SHAs - automation makes SHA-pinning sustainable.
- **Enable StepSecurity Harden-Runner** or equivalent to detect unexpected network connections and file system access in CI jobs.
- **Separate CI secrets by environment**: staging pipeline should NOT have access to production credentials.
- **Monitor action repos for force-push events**: subscribe to security advisories for all actions you use.

**Trivy safe versions (as of 2026-03-24):** binary v0.69.3, `trivy-action@v0.35.0`, `setup-trivy@v0.2.6`. Do NOT use v0.69.4/5/6.

### Secrets Management

| Tool | Best For | GitOps-friendly | External deps |
|------|---------|-----------------|---------------|
| **External Secrets Operator** v2.2+ | Production, multi-cluster, cloud KMS | Yes (references, not values) | Cloud KMS / Vault |
| **HashiCorp Vault** + VSO | Enterprise, dynamic secrets, PKI | Yes (references) | Vault server |
| **Sealed Secrets** v0.36.1+ | Encrypted-in-git, self-hosted, air-gapped, no external deps | Yes (encrypted CRs in git) | None |
| **SOPS** + age/KMS | Small teams, encrypted files in git | Yes (encrypted in git) | KMS or age keys |

**ESO + cloud secret manager** when you have cloud KMS. **Vault** when you need dynamic secrets or PKI. **Sealed Secrets** when you need encrypted-in-git without external infrastructure - works well for self-hosted clusters, homelabs, and environments where standing up Vault or a cloud KMS is overkill. Sealed Secrets and ESO are not mutually exclusive - some teams use Sealed Secrets for static config and Vault/ESO for dynamic credentials. **SOPS** for teams that prefer file-level encryption over CRDs.

**Full Sealed Secrets reference**: scope modes, key management, PCI-DSS gaps, kubeseal patterns, ArgoCD integration, anti-patterns - see `references/sealed-secrets.md`.

**CRITICAL: CVE-2026-22728** (Sealed Secrets < v0.36.0) - scope-widening via the rotate API. Upgrade immediately.

**Critical**: K8s Secrets are base64-encoded, not encrypted. Enable etcd encryption at rest via KMS v2. KMS v1 is deprecated (disabled by default since 1.29). This applies regardless of which secrets tool you use - once unsealed/synced, the Secret sits in etcd.

### Pod Security Standards (PSS)

Three profiles. Enforce at namespace level via labels.

**Restricted** (use for all app namespaces): non-root, drop ALL caps, RuntimeDefault seccomp, no privilege escalation, no hostPath/hostNetwork/hostPID.

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Set `audit` and `warn` to restricted on ALL namespaces - even where you can't enforce yet. This generates visibility into what would break.

### CIS Benchmark

Run via **kube-bench** (as a Job). Key areas:
- API server: audit logging, disable anonymous auth, OIDC
- etcd: encrypt at rest via KMS v2, restrict access to API server only
- Kubelet: disable anonymous auth, protect read-only port
- Network: CNI with network policy support (Cilium preferred)

---

## Observability Stack

### eBPF-First Observability

eBPF enables kernel-level visibility without kernel modules, sidecar proxies, or application changes.

| Category | Tool | What It Does |
|----------|------|-------------|
| **Networking** | Cilium + Hubble | CNI, network policy, L3-L7 flow logs, service map |
| **Runtime** | Tetragon | Syscall monitoring, process enforcement, file integrity |
| **Metrics** | Prometheus + VictoriaMetrics/Thanos | Metrics collection, long-term storage |
| **Logs** | Fluent Bit -> Loki | Lightweight log shipping, cost-effective storage |
| **Traces** | OpenTelemetry Collector -> Tempo/Jaeger | Vendor-neutral tracing, tail-based sampling |
| **Dashboards** | Grafana | RED/USE method dashboards |
| **Alerts** | Prometheus Alertmanager | PagerDuty/Slack/OpsGenie |
| **Profiling** | Parca | Continuous eBPF-based profiling |

### Dashboard Methodology

**RED method** (request-driven services):
- **R**ate: requests per second
- **E**rrors: error rate (5xx / total)
- **D**uration: latency percentiles (p50, p95, p99)

**USE method** (infrastructure):
- **U**tilization: % resource busy
- **S**aturation: queue depth, waiting
- **E**rrors: error count

---

## Cost Optimization Playbook

### Right-sizing

1. Deploy VPA in **recommendation mode**
2. Collect 2 weeks of data
3. Adjust requests to p95 usage, limits to 2x requests
4. **In-place pod resize** (GA in K8s 1.35): VPA can now use `InPlaceOrRecreate` mode to resize CPU/memory without pod restart. Re-evaluate VPA adoption - the "restarts pods" objection is gone.
5. Re-evaluate monthly

### Autoscaling Stack

```
HPA (pod-level) + Karpenter/Cluster Autoscaler (node-level) + VPA (right-sizing)
```

- **HPA**: scales pods on CPU/memory/custom metrics. `autoscaling/v2` only (v2beta* removed in 1.25/1.26). Container-level metrics supported.
- **Karpenter** (v1.10+, `kubernetes-sigs/karpenter`): faster and more flexible than Cluster Autoscaler. 10 provider implementations (AWS most mature, plus Azure, GCP, AlibabaCloud, Proxmox, and others). GCP provider is community-maintained.
- **KEDA**: event-driven/queue-based scaling (SQS, Kafka, etc.)
- **VPA + HPA coexistence**: VPA handles memory right-sizing (via in-place resize), HPA handles replica count on custom metrics. Practical now that in-place resize is GA.

### Spot/Preemptible Instances

Safe for:
- Stateless workloads with replicas >= 3
- Batch jobs with checkpointing
- Dev/staging environments

Unsafe for:
- Databases, stateful services
- Single-replica workloads
- Workloads without graceful shutdown

### Monitoring Cost

- **OpenCost** / **KubeCost**: per-namespace, per-label cost attribution
- Set up alerts: namespace exceeding budget, unattached PVCs, idle nodes
- Review monthly: delete unused PVCs, consolidate underused namespaces

### DRA (Dynamic Resource Allocation) - GA in K8s 1.34

New API for claiming specialized hardware (GPUs, FPGAs, network devices). Replaces the old device plugin model. 20-35% GPU cost reduction through flexible allocation. Use `ResourceClaim`, `ResourceClaimTemplate`, `DeviceClass` resources.

---

## Disaster Recovery

### Velero Backup Strategy

```bash
# Full cluster backup (daily)
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 720h \
  --include-namespaces app-ns-1,app-ns-2

# PV snapshots (for stateful workloads)
velero schedule create pv-snapshots \
  --schedule="0 */6 * * *" \
  --ttl 168h \
  --include-resources persistentvolumeclaims
```

### Recovery Patterns

| Scenario | Strategy | RTO |
|----------|----------|-----|
| Pod failure | Self-healing (replicas + probes) | Seconds |
| Node failure | Karpenter/Cluster Autoscaler + PDB | Minutes |
| AZ failure | topologySpreadConstraints + multi-AZ | Minutes |
| Cluster failure | Velero restore to new cluster | Hours |
| Region failure | Active-passive failover + DNS | Hours |
| Data corruption | Point-in-time restore from backups | Hours |

### Chaos Testing

Run quarterly at minimum:
- **Pod failure**: kill random pods, verify self-healing
- **Node drain**: drain a node, verify PDB and rescheduling
- **Network partition**: inject latency/drops, verify timeouts and circuit breakers
- **DNS failure**: block DNS, verify graceful degradation
- **Dependency failure**: kill a database, verify app error handling

Tools: LitmusChaos, Chaos Mesh, Gremlin (SaaS)

---

## Platform Requirements (K8s 1.35+)

Keep these in mind when upgrading:

| Requirement | Version | Impact |
|-------------|---------|--------|
| **cgroup v2** | 1.35+ | Kubelet fails to start on cgroup v1 nodes. CentOS 7, RHEL 7, Ubuntu 18.04 affected. |
| **containerd 2.0+** | 1.36+ | Last release supporting containerd 1.x is 1.35. |
| **AppArmor via securityContext** | 1.34+ | Annotations removed. Use `securityContext.appArmorProfile` field. |
| **KMS v2** | Now | KMS v1 disabled by default since 1.29. Migrate to v2. |
| **nftables kube-proxy** | Plan now | IPVS deprecated in 1.35, removal version TBD. |
| **autoscaling/v2** | Now | v2beta1/v2beta2 removed in 1.25/1.26. |
| **User namespaces** | 1.33+ (on by default) | `hostUsers: false` maps container UID 0 to unprivileged host UID. Huge for multi-tenancy/PCI. |
| **Pod-level mTLS** | 1.35 beta | KEP-4317. Native X.509 certs for pods without service mesh. Future alternative to Istio/Cilium for zero-trust. |
