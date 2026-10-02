---
name: kubernetes
description: >
  Build and review Kubernetes/K8s manifests, Helm charts, Kustomize overlays, Gateway API, and ArgoCD deployments.
license: MIT
compatibility: "Requires kubectl. Optional: helm, kustomize, kube-score, checkov, cosign"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-24"
  effort: high
  argument_hint: "[manifest-or-chart-or-cluster-task]"
---

# Kubernetes & Helm: Production Infrastructure

Create, review, and architect Kubernetes infrastructure - from raw manifests to Helm charts to multi-cluster strategy. The goal is production-ready, security-hardened, cost-aware infrastructure that a team can maintain.

**Target versions** (October 2026): Kubernetes 1.35-1.37 are the supported minors (1.37.1 / 1.36.5 / 1.35.9). Kubernetes maintains the most recent three minors (1.37, 1.36, 1.35), per the [release history](https://kubernetes.io/releases/); 1.34 entered maintenance mode August 27, 2026 and reaches EOL October 27, 2026. Upstream Kubernetes has no LTS. Managed **vendor extended support** (AKS/EKS) carries older minors longer - attribute it to the platform, not upstream. Helm 4.3.0 and Helm 3.22.0 are the current parallel release lines. Verify Helm 3 support status before selecting it for a new deployment. Check the [Helm compatibility matrix](https://helm.sh/docs/topics/version_skew/) before pairing releases: Helm 4.3.x and Helm 3.22.x both document Kubernetes 1.34-1.37 support, covering the supported minors above.
This skill covers four domains depending on context:
- **Manifests** - raw YAML for Deployments, Services, Gateway API routes, ConfigMaps, Secrets, PVCs
- **Helm** - Helm 4 chart scaffolding, OCI registries, templating, multi-environment values
- **Architecture** - cluster topology, GitOps, security layers, observability, cost, DR
- **Compliance** - PCI-DSS 4.0 controls, CDE isolation, audit logging, supply chain

## When to use

- Creating or reviewing Kubernetes manifests (Deployment, Service, StatefulSet, Job, HTTPRoute, etc.)
- Scaffolding new Helm charts or improving existing ones
- Designing cluster topology, GitOps strategy, or multi-tenancy
- Implementing security contexts, network policies, RBAC, admission control
- Setting up multi-environment deployments (dev/staging/prod)
- Reviewing infrastructure for production or compliance readiness
- Planning observability, cost optimization, or disaster recovery
- PCI-DSS 4.0 compliance for fintech/payment K8s workloads

## When NOT to use

- Configuring CI/CD pipelines (use **ci-cd**)
- Docker/container image optimization (use **docker**)
- Security audits of application code (use **security-audit**)
- Provisioning the cluster itself via IaC (use **terraform**)
- Database engine configuration running on K8s (use **databases**)
- Broad read-only cluster health checks, status reports, and post-maintenance diagnostics (use **kubernetes-health**)
- Instrumentation, collection pipelines, alerts, and SLO design (use **observability**) - this skill owns Kubernetes object configuration

## AI Self-Check

This skill runs inside an AI agent. AI tools consistently produce the same K8s security mistakes. **Before returning any generated manifest, verify against this list:**

- [ ] Security context present on every pod AND every container (not just one level)
- [ ] `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `drop: ["ALL"]`
- [ ] Resource `requests` AND `limits` set (AI almost never includes these unprompted)
- [ ] Image tag is pinned (not `:latest`, not omitted). Prefer SHA256 digest for production.
- [ ] No hardcoded secrets in env vars, ConfigMaps, or Helm values
- [ ] Namespace specified explicitly (not relying on context default)
- [ ] NetworkPolicy included or mentioned (AI almost never generates these alongside deployments)
- [ ] No `privileged: true` or `hostNetwork: true` unless explicitly requested and justified
- [ ] `seccompProfile: { type: RuntimeDefault }` present (often forgotten)
- [ ] Using Gateway API `HTTPRoute` for new external access, not legacy Ingress
- [ ] Readiness probes gate containers required to serve Pod traffic; auxiliary sidecars need them only if their readiness must gate traffic. Add meaningful startup/liveness probes for the workload.
- [ ] Kube context verified before any kubectl/helm/argocd command
- [ ] No auto-sync to production without approval gate
- [ ] **API versions checked**: manifests, Helm templates, and Gateway resources match the target cluster version
- [ ] **Cluster context shown**: namespace, context, and kubeconfig identity are printed before mutating commands
- [ ] **kube-proxy mode checked on 1.35+ clusters**: IPVS mode is deprecated in 1.35, disabled by default from 1.40 (re-enable with the `KubeProxyIPVS` feature gate) and removed in 1.43; recommend nftables mode for new clusters and flag IPVS in reviews
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

Run generated manifests through `kube-score score <manifest>` and `checkov` (Step 4) when available;
use `kube-linter` instead of `kube-score` if the repository already standardizes on it.

## Performance and Operating Practices

- Set requests and limits from measured workload behavior; missing requests damage scheduling and autoscaling.
- Use server-side dry-run and diff before apply; avoid repeated full-cluster renders during tight loops.
- Scope watches, logs, and `kubectl get` calls by namespace/labels in large clusters.
- Prefer declarative GitOps or reviewed manifests over live imperative changes for production.
- Back up CRDs and custom resources before upgrades or operator changes.
- Use policy gates for privileged pods, hostPath, broad RBAC, and mutable image tags.

## Secret delivery and recovery

Trace external secret ownership through workload identity, namespace/RBAC access, refresh, and application reload. Check expired leases and revoked credentials as well as successful rotation; do not assume updating a Secret reloads a process. Keep issuer and pipeline setup with **terraform** and **ci-cd**. For restore drills, use an isolated cluster or namespace, verify application reads and writes plus dependencies, measure recovery time and data loss against RTO/RPO, and record cleanup. A completed backup job alone proves no restore.

## Workflow

Copy this checklist and track progress:
- [ ] Step 1: Domain identified
- [ ] Step 2: Requirements gathered
- [ ] Step 3: Manifests, chart, or design built
- [ ] Step 4: Validation clean (if dry-run, lint, or scoring fails, fix and return to Step 3)
- [ ] Step 5: GitOps owner checked before any live change
- [ ] Production checklist and AI Self-Check passed

### Step 1: Determine the domain

Based on the request:
- **"Create a deployment/service/manifest"** -> Manifests
- **"Create a Helm chart" / "package for deployment"** -> Helm
- **"Design the cluster" / "how should we structure"** -> Architecture
- **"Make this PCI compliant" / "fintech"** -> Compliance
- **"Review this manifest/chart"** -> Apply production checklist + critical rules + AI self-check

Most real tasks blend domains. Work bottom-up: get the manifests right, then template them, then plan the deployment.

### Step 2: Gather requirements

Before writing YAML, determine:
- **Workload type**: stateless (Deployment) vs stateful (StatefulSet) vs batch (Job/CronJob)
- **Container image** and pinned tag or SHA256 digest
- **Ports** exposed (container port, service port, protocol)
- **Config**: env vars, config files, secrets
- **Storage**: ephemeral (emptyDir) vs persistent (PVC) with access mode and size
- **Resources**: CPU/memory requests and limits
- **Health**: startup, liveness, and readiness probe endpoints
- **Access**: internal-only (ClusterIP) vs external (Gateway API HTTPRoute / LoadBalancer)
- **Scale**: replicas, HPA thresholds, pod disruption budget
- **Compliance**: PCI-DSS scope? CDE workload? Regulated environment?
- **Sidecars**: logging, security, or proxy sidecars? Use native sidecars (GA in 1.33)

### Step 3: Build

Follow the domain-specific section below. Always run Step 4, the production checklist in `references/production-checklist.md`, and the AI self-check before finishing.

### Step 4: Validate

```bash
# Always verify kube context first
KUBE_CONTEXT="$(kubectl config current-context)"
printf 'Using kube context: %s\n' "$KUBE_CONTEXT"

# Manifests
kubectl --context "$KUBE_CONTEXT" apply -f <manifest> --dry-run=server  # Server-side validation
command -v kube-score >/dev/null || echo "kube-score not installed: skip scoring and say so"
kube-score score <manifest>                     # Best practice scoring
checkov -d . --framework kubernetes  # when available
# Fix and return to Step 3 until dry-run errors and findings this change introduced are clean; report pre-existing ones

# Helm 4
helm lint <chart>/                              # Lint chart
helm template <release> <chart>/               # Render templates locally
helm template <release> <chart>/ -f values-prod.yaml  # With env overlay
helm --kube-context "$KUBE_CONTEXT" install <release> <chart>/ --dry-run=server --debug  # Server-side dry run
```

### Step 5: GitOps-managed emergency or scaling changes

When changing a live workload managed by ArgoCD, Flux, or another reconciler, read `references/gitops-emergency-changes.md`; live `kubectl scale`, `kubectl patch`, or manual apply may be reverted unless the desired state changes too.

## Manifests

Read `references/manifest-templates.md` for complete, copy-pasteable YAML templates (Deployment, Service, Gateway API HTTPRoute, ConfigMap, PVC, StatefulSet, native sidecar).

### Key patterns

**Labels**: use the `app.kubernetes.io/*` standard labels on every resource:
- `app.kubernetes.io/name` - app name
- `app.kubernetes.io/version` - version string
- `app.kubernetes.io/component` - role (frontend, backend, database)
- `app.kubernetes.io/part-of` - parent system

**External access** (new clusters must use Gateway API, not legacy Ingress):
- **Gateway API** `HTTPRoute` (GA v1.5): role-oriented, expressive routing, no annotation hell. Ingress-NGINX retired March 2026; migrate to a maintained controller. Later [CVE-2026-4342](https://github.com/kubernetes/kubernetes/issues/137893) permits configuration injection and controller code execution; affected branch versions are before 1.13.9 / 1.14.5 / 1.15.1 respectively. Those fixes do not restore ongoing support.
- **ClusterIP** (default): internal-only
- **LoadBalancer**: cloud LB without HTTP routing
- **Headless** (`clusterIP: None`): StatefulSet pod discovery

**Security context** (non-negotiable on every pod - both pod-level AND container-level). See the Deployment template in `manifest-templates.md` for the full YAML. Key fields: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `drop: ["ALL"]`, `seccompProfile: RuntimeDefault`.

**Probe types** (select meaningful checks for the workload; auxiliary sidecars need readiness only when they must gate Pod traffic):
- `startupProbe`: gates the other probes until the app is ready (high `failureThreshold`, moderate `periodSeconds`)
- `livenessProbe`: restarts unhealthy pods (conservative - don't restart on slow responses)
- `readinessProbe`: removes from service endpoints (aggressive - pull traffic fast on failure)

**Pod distribution**: prefer `topologySpreadConstraints` over pod anti-affinity for zone-level distribution (anti-affinity is O(n^2) at scale). Combine both: `topologySpreadConstraints` for zones + soft anti-affinity for node-level separation within zones.

**Native sidecars** (GA in K8s 1.33): init containers with `restartPolicy: Always`. Start before main containers, stay running alongside them, terminate after main containers exit. Replaces all sidecar lifecycle hacks (preStop hooks, shareProcessNamespace kill scripts).

**In-place pod resize** (GA in K8s 1.35): CPU and memory can be updated on running pods without restart. VPA can now resize without disruption using `InPlaceOrRecreate` mode.

**Config/secrets**: ConfigMap for non-sensitive data. For secrets, use External Secrets Operator syncing from a vault/cloud KMS, or Sealed Secrets for encrypted-in-git workflows (see `references/sealed-secrets.md`). Never commit plaintext secrets anywhere.

## Helm Charts

**Helm 4** (4.0.0 released Nov 12, 2025; 4.3.0 current) is current. Verify the current Helm 3 support policy before selecting 3.22.0.

### What changed in Helm 4

- **Server-side apply (SSA) is the default** for new releases. Better conflict detection when multiple controllers touch the same resources.
- **OCI digest installation**: `helm install myapp oci://registry/chart@sha256:abc...` - immutable, tamper-proof.
- **WASM plugin system** - post-renderers must reference plugin names, not raw executables (breaking change).
- **CLI flag renames**: `--atomic` -> `--rollback-on-failure`, `--force` -> `--force-replace`. The old flags still work as deprecated aliases on both install and upgrade (a brief Helm 4.0 regression that broke `helm install --atomic` was fixed in v4.1.3); prefer `--rollback-on-failure` for new scripts.
- **`helm registry login` takes domain only** (e.g., `ghcr.io`, not full URL).
- **OCI registries are the recommended distribution method.** Traditional `index.yaml` repos still work but are no longer the default path.

### Chart structure

```bash
helm create <app-name>
```

```
<app-name>/
+-- Chart.yaml           # Metadata (apiVersion: v2, name, version, appVersion)
+-- values.yaml          # Default config values
+-- values.schema.json   # JSON schema for values validation
+-- charts/              # Bundled dependencies
+-- crds/                # CRDs (not templated, installed first)
+-- templates/
|   +-- NOTES.txt        # Post-install usage instructions
|   +-- _helpers.tpl     # Template helper functions
|   +-- deployment.yaml
|   +-- service.yaml
|   +-- httproute.yaml   # Gateway API (prefer over ingress.yaml)
|   +-- configmap.yaml
|   +-- hpa.yaml
|   +-- tests/
|       +-- test-connection.yaml
+-- .helmignore
```

### Chart.yaml

Required: `apiVersion: v2`, `name`, `version` (SemVer), `description`, `type` (application|library).

Pin dependencies with `~` for patch-level ranges:
```yaml
dependencies:
  - name: postgresql
    version: "~12.0.0"          # matches 12.0.x
    repository: "oci://registry-1.docker.io/bitnamicharts"  # OCI preferred
    condition: postgresql.enabled
```

Run `helm dependency update` after adding deps.

### values.yaml design

Organize hierarchically. Core sections:
- `image` (repository, tag/digest, pullPolicy)
- `replicaCount`
- `service` (type, port, targetPort)
- `gateway` (enabled, parentRefs, hostnames) - prefer over `ingress`
- `resources` (requests + limits - ALWAYS set both)
- `autoscaling` (enabled, min/maxReplicas, targetCPU)
- `securityContext` (runAsNonRoot, readOnlyRootFilesystem, drop ALL caps)
- `nodeSelector`, `tolerations`, `affinity`

**Multi-environment**: create `values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml` as overlays. Never modify `values.yaml` for env-specific config.

### Template patterns

**Helpers (_helpers.tpl)**: define `<chart>.name`, `<chart>.fullname`, `<chart>.labels`, `<chart>.selectorLabels`, `<chart>.image`. Truncate names to 63 chars.

Key Go template patterns:
- Conditional: `{{- if .Values.gateway.enabled }}`
- Iteration: `{{- range .Values.env }}`
- File include: `{{ .Files.Get "config/app.yaml" | nindent 4 }}`
- Defaults: `{{ .Values.image.tag | default .Chart.AppVersion }}`
- Required: `{{ required "image.repository is required" .Values.image.repository }}`
- Release namespace: `{{ .Release.Namespace }}` (never hardcode namespace)
- Nested access: alias with `{{- $var := .Values.deep.nested }}` to avoid spaghetti

### Helm anti-patterns

- Hardcoded values in templates (should come from `values.yaml`)
- `tpl` on static strings (it is for dynamic template rendering)
- `.Values.foo.bar.baz` chains without `default` on optional values
- Unpinned chart dependencies (use `~` ranges or exact versions)
- No `NOTES.txt`
- Missing `.helmignore` (test/ci files end up in package)
- `randAlphaNum` in templates deployed via ArgoCD (causes perpetual OutOfSync)
- Mega-umbrella charts (15+ subcharts, 200+ value overrides) - use ArgoCD ApplicationSets instead
- `replicaCount: 1` for production HA workloads (no redundancy, single point of failure)
- `authentication.enabled: false` or `persistence.enabled: false` in production values (data loss, unauthorized access)
- Secrets in Helm values (use ESO/sealed-secrets/vault; Helm values end up readable in cluster Secrets)
- Hook resources without `helm.sh/hook-delete-policy` (orphaned Jobs accumulate)
- Using `--post-renderer` with raw executables (broken in Helm 4; must use plugin names)
- Ignoring SSA migration - upgrading to Helm 4 on existing releases can surface previously-hidden conflicts

### ArgoCD + Helm caveats

- ArgoCD only runs `helm template` - it does NOT use Helm lifecycle management. Don't rely on Helm hooks for critical operations; use ArgoCD sync waves instead.
- `test` hooks are unsupported in ArgoCD.
- Multi-source Applications (ArgoCD 2.6+) for separating chart version from environment values.
- OCI charts: omit the `oci://` prefix in ArgoCD's `repoURL` field.

## Kustomize

Kustomize is built into kubectl (`kubectl apply -k`) and available as a standalone CLI.

### Overlay pattern (base + environments)

```
app/
+-- base/
|   +-- kustomization.yaml   # references resources
|   +-- deployment.yaml
|   +-- service.yaml
+-- overlays/               # dev/ staging/ prod/, each a kustomization.yaml with resources: [../../base]
```

Each overlay's `kustomization.yaml` sets `resources`, then adds `patches`, `images`, and `configMapGenerator`/`secretGenerator` overrides for that environment.

### Components

Reusable cross-cutting patches (monitoring, security context, sidecar injection) that any overlay can opt into with `components: [../../components/monitoring]`. Prefer components over duplicating patches across overlays.

### secretGenerator / name-suffix-hash pitfall

`secretGenerator` and `configMapGenerator` append a content hash suffix to the resource name (e.g., `app-config-abc12345`). Deployments referencing the generated name by a fixed name break because the hash changes on every edit. Always reference generated resources by the base name and let Kustomize resolve the suffix, or set `options.disableNameSuffixHash: true` if the hash-based rolling update is not desired.

## Architecture

Read `references/architecture.md` for the full architecture decision framework. Key patterns:

### Cluster topology

**Single cluster** when: < 50 services, single team, single region, non-critical workloads.

**Multi-cluster** when: multi-region HA, team isolation, blast radius reduction, compliance boundaries (PCI CDE).

### GitOps

**ArgoCD** when: UI matters, app-of-apps, multi-cluster from single control plane, RBAC on deployments.

**Flux** when: Git-native preferred, lighter footprint, full Helm lifecycle (install/upgrade/test/rollback/uninstall), Kustomize post-rendering.

Promotion: dev -> staging -> prod via PR-based promotion. No auto-sync to prod.

### Networking

**Gateway API** (GA v1.5) is the standard for new clusters (see Rule 10).

**CNI**: Cilium (eBPF, greenfield) or Calico (brownfield/multi-OS/Windows). Cilium includes Hubble observability, L3-L7 policy, and optional sidecar-free service mesh.

**kube-proxy**: nftables mode is the future. IPVS deprecated in 1.35, disabled by default from 1.40 (re-enable with the `KubeProxyIPVS` feature gate) and removed in 1.43 (https://kubernetes.io/docs/reference/networking/virtual-ips/).

**Service mesh** (add only when needed):
- **Istio ambient** (GA in 1.24): sidecarless L4 mTLS via ztunnel, optional L7 via waypoint proxies.
- **Cilium**: mTLS via WireGuard/IPsec, no mesh abstraction. Simpler but less L7 control.
- **Linkerd**: stable builds now vendor-only (Buoyant). Source is Apache 2.0 but you build your own or pay.

### Security (defense in depth)

8 layers for production:
1. **Cluster hardening**: CIS benchmark, API server audit logging, etcd encryption via KMS v2
2. **Pod Security Standards**: **`enforce: restricted` is the default for all app namespaces**. Restricted only permits adding `NET_BIND_SERVICE`, so images that start as root and need `SETUID`/`SETGID`/`CHOWN` should first be reconfigured or rebuilt to run non-root. If that is impossible, isolate them in a dedicated namespace enforcing `baseline` with a documented exception (owner, reason, review date), keeping `audit`/`warn` at `restricted` there too. Set `audit: restricted` and `warn: restricted` everywhere else for visibility into what would break before enforcing.
3. **Admission control**: ValidatingAdmissionPolicy (CEL, native since 1.30) for standard policies; Kyverno for mutation/generation; OPA Gatekeeper for cross-platform orgs
4. **Network policies**: default-deny ingress/egress per namespace; Cilium for L7 policies
5. **RBAC**: namespace-scoped roles, no cluster-admin for apps, OIDC auth with MFA
6. **Supply chain**: cosign/Sigstore for image signing, SLSA Level 2-3, SBOMs. **Pin all CI actions and tools to commit SHAs** - the Trivy supply chain compromise (March 2026, CVE-2026-33634) proved mutable tags can be force-pushed with malware. Read `references/architecture.md` (Supply chain integrity) for the Trivy takeaways, safe versions, and secret-rotation window.
7. **Secrets**: External Secrets Operator + cloud KMS (primary); Vault for dynamic secrets/PKI; Sealed Secrets for encrypted-in-git without external deps (see `references/sealed-secrets.md`); SOPS for small teams
8. **Runtime security**: Falco for detection (CNCF Graduated), Tetragon for eBPF enforcement (<1% overhead)

### Platform awareness

- **cgroup v2 required** on K8s 1.36+ (`FailCgroupV1` defaults to true; kubelet won't start on cgroup v1 unless `failCgroupV1: false`). Nodes on cgroup v1 (CentOS 7, RHEL 7, Ubuntu 18.04) will fail.
- **containerd 2.0 required** on K8s 1.36+. Last release supporting containerd 1.x is 1.35.
- **AppArmor annotation auto-population stopped** in 1.34; full removal in 1.36. Use `securityContext.appArmorProfile` field.
- **DRA (Dynamic Resource Allocation)** GA in 1.34 for GPU/FPGA/hardware scheduling. Replaces device plugin model.
- **User namespaces** (`hostUsers: false`) enabled by default since K8s 1.33. Maps container UID 0 to unprivileged host UID. Huge for PCI multi-tenancy - container breakout doesn't yield host root.
- **Pod-level mTLS** (KEP-4317) beta in 1.35, feature gate `PodCertificates` must be manually enabled. Native X.509 certs for pods without service mesh. Future alternative to Istio/Cilium for Req 4 compliance.

## Compliance

Read `references/compliance.md` for the full PCI-DSS 4.0 requirements mapping to Kubernetes controls.

### Quick reference: PCI-DSS 4.0 on K8s

PCI-DSS 4.0 is the only active version (3.2.1 retired March 2024). 51 future-dated requirements became mandatory March 31, 2025.

**Critical K8s-specific requirements:**
- **Req 1**: Network segmentation -> default-deny NetworkPolicies, private API server, VPC-native clusters
- **Req 3.5**: Data encryption -> etcd encryption via KMS v2 (not just disk encryption - Req 3.5.1.2 forbids relying on disk-level alone)
- **Req 4**: Encrypt transmissions -> mTLS between all CDE services (Istio strict / Cilium mutual auth)
- **Req 6.3.2**: Component inventory -> SBOMs for every image
- **Req 8.4.2**: MFA for all CDE access -> OIDC + MFA on all kubectl paths
- **Req 8.6.2**: No hardcoded secrets -> External Secrets Operator, never in manifests/values/env vars
- **Req 10.4.1.1**: Automated audit log review -> K8s audit policy with Metadata for sensitive payloads and RequestResponse only for reviewed non-sensitive resources, ship to SIEM with alert rules
- **Req 11.5**: FIM / change detection -> Falco runtime detection, ArgoCD drift detection, image digest pinning

**CDE isolation**: dedicated cluster strongly preferred. Shared cluster puts the entire cluster in PCI scope and requires dedicated node pools + taints, gVisor/Kata for CDE pods, separate DNS, separate audit streams, and extensive QSA documentation. Most QSAs push back on shared clusters.

**PCI MPoC**: MPoC backends (attestation/monitoring for tap-to-pay) fall under full PCI-DSS scope. No K8s-specific addenda - standard PCI-DSS 4.0 controls apply.

## Reference Files

- `references/manifest-templates.md` - manifest templates and reusable workload patterns
- `references/production-checklist.md` - manifest, Helm, architecture, and PCI-DSS checklists; run before finishing any build or review
- `references/architecture.md` - cluster and platform design guidance, including supply chain integrity after the Trivy compromise
- `references/sealed-secrets.md` - Sealed Secrets patterns and caveats
- `references/compliance.md` - PCI-DSS and platform hardening guidance
- `references/gitops-emergency-changes.md` - safe workflow for urgent changes to GitOps-managed workloads

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** KUBERNETES
- **Deliverable bucket:** `audits`
- **Mode:** conditional. When invoked to **analyze, review, audit, or improve** existing repo content, apply the reporting size and evidence rules in `references/output-contract.md` and write the deliverable to `docs/local/audits/kubernetes/<YYYY-MM-DD>-<slug>.md`. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; only used in audit/review mode).

## Related Skills

- **docker** - for Dockerfile and Compose patterns. Kubernetes deploys the images Docker builds. Image optimization belongs in docker; manifest design belongs here.
- **ci-cd** - for pipeline design that deploys to K8s. Kubernetes skill covers manifests and Helm charts; ci-cd covers the pipeline stages that apply them.
- **terraform** - for provisioning the cluster itself (EKS, GKE, AKS, bare-metal node pools). Terraform creates the cluster; kubernetes configures what runs on it.
- **kubernetes-health** - for read-only cluster status checks, node/workload diagnostics, events, ingress/storage/log sweeps, and post-maintenance reports.
- **databases** - for deploying databases on K8s (StatefulSets, operators, PVCs). Kubernetes owns the manifest pattern; databases owns the engine configuration within.
- **ansible** - can deploy to K8s via `kubernetes.core` collection, but manifest and Helm chart design belong here.

## Rules

These are non-negotiable. Violating any of these is a bug.

1. **No `:latest` tags.** Pin images to a specific version or SHA256 digest.
2. **Namespace everything.** The default namespace is a code smell.
3. **Resource requests AND limits on every pod.** No exceptions.
4. **Verify requester authorization before cluster changes.** In shared chats, do not run kubectl, Helm, ArgoCD, or GitOps edits for admin requests from a non-admin participant. Stop and ask the authorized owner for explicit approval.
5. **No auto-sync to prod.** Manual approval or PR-based promotion.
6. **Pin dependency versions.** Helm chart deps, provider versions, everything.
7. **`helm template` before every apply.** Catch template errors before they hit the cluster.
8. **Secrets never in plaintext.** Not in Git, not in ConfigMaps, not in Helm values, not in env vars in manifests.
9. **Test changes in staging first.** Policy changes, admission controllers, upgrades, SSA migration.
10. **Gateway API for new external access.** Ingress-NGINX retired March 2026. Stop deploying new Ingress resources.
11. **Sign images with cosign.** Verify at admission. SLSA Level 2 minimum for production.
12. **Understand resource metric semantics.** HPA CPU target is percentage of CPU *request*, not node capacity. Example: a pod requesting `cpu: 100m` with `averageUtilization: 70` scales when per-pod CPU usage hits 70m (100m * 70%) - it does not matter whether the node has 2 or 64 cores. Don't confuse requests (scheduling floor), limits (enforcement ceiling), and actual usage (what the container is consuming right now).
