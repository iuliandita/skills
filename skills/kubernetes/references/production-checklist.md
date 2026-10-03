# Kubernetes Production Checklist

Run before finishing any manifest, chart, architecture, or compliance task (Workflow Step 3).

## Manifests

- [ ] Resource requests AND limits set on every container
- [ ] Probe coverage matches the workload: readiness for traffic dependencies; startup and liveness where meaningful; auxiliary-sidecar exceptions documented
- [ ] Pinned image tag or SHA256 digest (never `:latest`)
- [ ] Security context at pod AND container level: non-root, read-only rootfs, drop ALL caps, seccomp RuntimeDefault
- [ ] Replicas >= 2 for HA (>= 3 preferred)
- [ ] topologySpreadConstraints for zone distribution; soft anti-affinity for node spread
- [ ] Rolling update with maxUnavailable: 0
- [ ] Standard `app.kubernetes.io/*` labels
- [ ] Namespace specified explicitly
- [ ] Secrets via External Secrets Operator or Sealed Secrets (not in manifests, ConfigMaps, or env vars)
- [ ] PodDisruptionBudget for HA workloads
- [ ] terminationGracePeriodSeconds matches app shutdown time
- [ ] Gateway API HTTPRoute for external access (not legacy Ingress)
- [ ] Images signed with cosign, verified at admission

## Helm

- [ ] All dependency versions pinned in Chart.yaml
- [ ] OCI registry for chart distribution (digest-pinned in prod)
- [ ] All values documented with comments in values.yaml
- [ ] `values.schema.json` for input validation
- [ ] No `:latest` tags in default values
- [ ] Resources set in default values
- [ ] `NOTES.txt` with post-install instructions
- [ ] `helm template` renders clean YAML
- [ ] Separate values files per environment
- [ ] `.helmignore` excludes test/ci artifacts
- [ ] All hooks have `helm.sh/hook-delete-policy`
- [ ] No secrets in Helm values (use ESO/sealed-secrets references)

## Architecture

- [ ] Cluster topology matches scale and isolation needs
- [ ] GitOps tool chosen with clear promotion strategy (no auto-sync to prod)
- [ ] Gateway API for external traffic (not legacy Ingress)
- [ ] Network policies default-deny in all namespaces
- [ ] Pod Security Standards: `enforce: restricted` on all app namespaces
- [ ] ValidatingAdmissionPolicy or Kyverno for custom admission rules
- [ ] RBAC follows least-privilege; OIDC + MFA for API access
- [ ] Secrets via ESO + cloud KMS, Vault, or Sealed Secrets (match tool to environment - see Architecture reference)
- [ ] Images signed (cosign/Sigstore) and verified at admission
- [ ] Runtime security: Falco (detection) + Tetragon (enforcement)
- [ ] Observability covers metrics, logs, traces (eBPF-based preferred)
- [ ] HPA configured for variable workloads
- [ ] Backup/restore tested and documented
- [ ] DR plan with RTO/RPO targets
- [ ] Cost monitoring in place (OpenCost/KubeCost)
- [ ] cgroup v2 and containerd 2.0+ on all nodes

## Compliance (PCI-DSS 4.0)

- [ ] CDE in dedicated cluster or hard-isolated with dedicated node pools
- [ ] etcd encryption via KMS v2 (not disk-level alone)
- [ ] mTLS between all CDE services (Istio strict / Cilium)
- [ ] K8s audit logging excludes sensitive bodies; RequestResponse is limited to reviewed non-sensitive resources
- [ ] Audit logs shipped to immutable SIEM, automated review rules
- [ ] SBOMs generated and stored for every image
- [ ] No hardcoded secrets anywhere (Req 8.6.2)
- [ ] MFA on all CDE access paths (Req 8.4.2)
- [ ] WAF on public-facing web apps (Req 6.4.2)
- [ ] Certificate inventory maintained (Req 4.2.1.1)
- [ ] Quarterly authenticated internal vulnerability scans (Req 11.3.1.2) - application-level, not just image scanning
