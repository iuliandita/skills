# Bitnami Sealed Secrets Reference

Encrypt Kubernetes Secrets for safe Git storage. The controller decrypts them in-cluster using RSA-4096 asymmetric encryption. Plaintext never touches Git.

**Current**: controller v0.36.1, Helm chart v2.18.4, kubeseal CLI v0.36.1.

**CRITICAL: CVE-2026-22728** (fixed in v0.36.0). The `/v1/rotate` endpoint accepted untrusted annotations -- an attacker could inject `sealedsecrets.bitnami.com/cluster-wide: "true"` into a victim's SealedSecret, submit it to the rotate endpoint, and receive back a re-encrypted SealedSecret with cluster-wide scope. The attacker could then retarget it (change name/namespace) to decrypt the original secret values in any namespace they control. Upgrade past v0.35.x immediately.

---

## When to Use Sealed Secrets

| Situation | Sealed Secrets | ESO | Vault |
|-----------|:-:|:-:|:-:|
| Single cluster, no cloud KMS | **Yes** | Overkill | Overkill |
| Self-hosted / homelab / air-gapped | **Yes** | Maybe (needs store) | Maybe (needs server) |
| GitOps with ArgoCD/Flux, no external deps | **Yes** | Needs provider | Needs server |
| Multi-cluster with shared secrets | Possible (shared keys) | **Better** | **Better** |
| Dynamic secrets (DB creds, PKI) | No | Via Vault | **Yes** |
| Auto-rotation of secret values | No | **Yes** (refreshInterval) | **Yes** (TTL) |
| PCI-DSS CDE (Req 3.6 key management) | Partial (see gaps) | Good (cloud KMS) | **Best** (HSM, audit) |
| Budget-constrained, small team | **Yes** | Free + provider cost | License cost |

**Rule of thumb**: Sealed Secrets when you need encrypted secrets in Git without external infrastructure. ESO when you have (or want) a cloud secret store. Vault when you need dynamic secrets, HSM backing, or enterprise audit.

Sealed Secrets and ESO/Vault are not mutually exclusive. Some teams use Sealed Secrets for static config (registry creds, API keys) and Vault for dynamic DB credentials in the same cluster.

---

## Architecture

```
Developer                          Cluster
   |                                  |
   |  kubeseal --fetch-cert           |
   |<----- public cert (RSA-4096) ----|  sealed-secrets-controller
   |                                  |  (kube-system)
   |  SealedSecret YAML              |
   |  (encrypted, committed to Git)   |
   |                                  |
   |  ArgoCD/kubectl apply            |
   |------- SealedSecret CR --------->|
   |                                  |  controller watches CRs
   |                                  |  decrypts with private key
   |                                  |  creates v1/Secret
   |                                  |  (ownerRef -> SealedSecret)
```

Private key stored as `kubernetes.io/tls` Secret labeled `sealedsecrets.bitnami.com/sealed-secrets-key=active` in the controller namespace. Multiple keys can coexist -- the controller tries all active keys for decryption.

**Caution**: the controller sets `ownerReference` on the generated Secret. Deleting a SealedSecret cascades to the Secret -- any pod mounting it will fail. Verify no pods reference the Secret before deleting.

---

## Sealing Scope Modes

| Scope | Binding | Flag | Use case |
|-------|---------|------|----------|
| **strict** (default) | name + namespace | `--scope strict` | Production default. Maximum security. |
| **namespace-wide** | namespace only | `--scope namespace-wide` | Dynamic secret names (Helm hash suffixes, Kustomize name hashing) |
| **cluster-wide** | neither | `--scope cluster-wide` | Shared secrets across namespaces (image pull secrets, wildcard TLS) |

**Security implications**:
- **strict** binds name + namespace into the ciphertext. Copying a SealedSecret to another namespace or renaming it causes decryption failure. This prevents namespace-boundary escapes.
- **namespace-wide** allows rename within the same namespace. Weakens protection if RBAC grants create-SealedSecret to untrusted users within the namespace.
- **cluster-wide** removes all binding. Any user who can create a SealedSecret CR anywhere can unseal it. Only use when RBAC prevents untrusted SealedSecret creation.

**Default to strict.** Only widen scope when you have a concrete reason and understand the RBAC implications.

---

## Key Management

### Key renewal

- Default: new key every **30 days** (`--key-renew-period=720h`).
- Old keys retained for decryption, new key used for new sealing operations.
- **Key renewal is NOT secret rotation.** Renewing the sealing key does not re-encrypt existing SealedSecrets or rotate the underlying credentials. If a key is compromised, rotate the actual secret values.
- Disable auto-renewal: `keyrenewperiod: "0"` (string with quotes in Helm values).

### Backup (non-negotiable)

```bash
# Export ALL sealing keys (there may be multiple from renewals)
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > "$TMPFILE"

# Encrypt before storing -- NEVER store plaintext key backups
age -r age1... "$TMPFILE" > sealed-secrets-keys-$(date +%Y%m%d).yaml.age
rm -P "$TMPFILE" 2>/dev/null || rm "$TMPFILE"  # -P = secure delete on macOS; shred on Linux

# Store in 3+ locations: password manager, encrypted USB, NAS
# NOT in Git. NOT unencrypted on any disk.
```

Back up after every key renewal (minimum monthly). Automate with a CronJob or external script.

### Disaster recovery

```bash
# 0. Decrypt the age backup first (if encrypted per the backup procedure)
age -d sealed-secrets-keys-YYYYMMDD.yaml.age > sealed-secrets-keys.yaml

# 1. Restore keys BEFORE deploying the controller
kubectl apply -f sealed-secrets-keys.yaml

# 2. Deploy controller -- picks up existing keys on startup
helm install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system --version 2.18.4

# 3. Verify
kubectl -n kube-system logs -l app.kubernetes.io/name=sealed-secrets | grep "registered"

# 4. Clean up plaintext key file
rm -P sealed-secrets-keys.yaml 2>/dev/null || rm sealed-secrets-keys.yaml

# Offline decryption (if you have the backup private key)
kubeseal --recovery-unseal --recovery-private-key backup.key < sealed-secret.yaml
```

### Secret value rotation

Rotating the actual secret value (e.g. a database password) is manual:

1. Rotate the credential at the source (e.g. `ALTER USER ... PASSWORD '...'` in Postgres)
2. Re-seal with the new value:
   ```bash
   kubectl create secret generic db-creds \
     -n production \
     --from-literal=password=new-password-here \
     --dry-run=client -o yaml \
     | kubeseal -o yaml > sealed-db-creds.yaml
   ```
3. Commit and push (or `kubectl apply` directly)
4. The controller overwrites the existing Secret with the new value
5. Restart or roll the consuming pods (unless they watch for Secret changes)

### Cluster migration

Migrating to a new cluster does NOT require re-sealing if you restore the sealing keys:

1. Export keys from old cluster (see Backup above)
2. Apply key backup to the new cluster before deploying the controller
3. Deploy sealed-secrets controller -- it picks up the existing keys
4. Apply your SealedSecret manifests from Git -- they decrypt normally

If you do NOT have the key backup, you must re-seal everything using the new cluster's cert.

### Multi-cluster key sharing

To use the same SealedSecrets across clusters (e.g. staging/prod with identical manifests):

```bash
# Generate key pair manually (BYOC)
openssl req -x509 -days 365 -nodes -newkey rsa:4096 \
  -keyout sealed-secrets.key -out sealed-secrets.crt \
  -subj "/CN=sealed-secret/O=sealed-secret"

# Deploy to each cluster
kubectl -n kube-system create secret tls sealed-secrets-shared \
  --cert=sealed-secrets.crt --key=sealed-secrets.key
kubectl -n kube-system label secret sealed-secrets-shared \
  sealedsecrets.bitnami.com/sealed-secrets-key=active

# Restart controller pods to pick up the new key
```

**WARNING**: the BYOC cert expires after `-days N` (365 in the example above). After expiry, the controller still decrypts existing SealedSecrets (private key remains valid), but `kubeseal --fetch-cert` returns an expired cert. Either disable auto-renewal (`keyrenewperiod: "0"`) and set a calendar reminder to regenerate before expiry, or use a longer validity period (`-days 3650`).

**Trade-off**: shared keys mean one compromise affects all clusters. Per-cluster keys are safer but require per-cluster sealing. For PCI environments, per-cluster keys are strongly preferred.

---

## kubeseal CLI Patterns

### Seal a secret

```bash
# Always specify namespace explicitly (default: "default" -- common mistake)
kubectl create secret generic db-creds \
  -n production \
  --from-literal=password=hunter2 \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > sealed-db-creds.yaml
```

### Seal a single value (raw mode)

```bash
# Strict scope requires name + namespace
echo -n "hunter2" | kubeseal --raw \
  --name db-creds --namespace production
```

### Merge into existing SealedSecret

```bash
# Add/update a single key without re-sealing everything
echo -n "new-api-key" | kubectl create secret generic api-creds \
  -n production \
  --from-file=api-key=/dev/stdin \
  --dry-run=client -o yaml \
  | kubeseal --merge-into existing-sealed-secret.yaml
```

### Validate before committing

```bash
kubeseal --validate < sealed-secret.yaml
```

### Re-encrypt with latest key

```bash
# Uses the controller's /v1/rotate endpoint
kubeseal --re-encrypt < sealed-secret.yaml > re-sealed-secret.yaml
# Post-CVE-2026-22728: scope is validated during rotation. Upgrade to v0.36.0+ first.
```

### Fetch cert for offline sealing

```bash
# From running controller (needs cluster access)
kubeseal --fetch-cert \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system > cluster.pem

# Fallback: extract from secret directly
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > cluster.pem

# Seal with offline cert
kubeseal --cert cluster.pem -o yaml < secret.yaml > sealed.yaml
```

**CI pipeline usage**: store `cluster.pem` as a CI variable (e.g. `SEALED_SECRETS_CERT`). The cert is the **public** half of the keypair -- safe to store as a regular CI variable or even commit to the repo. It cannot decrypt anything. Refresh after every key renewal (default: 30 days) -- stale certs still work but seal with an old key.

### Non-default controller location

```bash
kubeseal \
  --controller-name my-sealed-secrets \
  --controller-namespace my-namespace \
  < secret.yaml > sealed.yaml
```

---

## GitOps Integration

### ArgoCD

SealedSecrets are CRDs -- ArgoCD handles them natively. No plugins needed.

```
apps/my-app/
  kustomization.yaml
  deployment.yaml
  service.yaml
  sealed-secret.yaml     # encrypted, committed
```

**Pitfalls**:
- **Sync diff noise**: ArgoCD may show the generated Secret as out-of-sync. Use `ignoreDifferences` on Secret resources or rely on the ownerReference.
- **Pruning**: ArgoCD pruning the SealedSecret cascades to the Secret (ownerReference). Set `argocd.argoproj.io/sync-options: Prune=false` on SealedSecrets if needed.
- **Multi-cluster**: each target cluster needs its own controller and keys unless you share keys (see multi-cluster section above).
- **`randAlphaNum` in Helm + SealedSecrets**: if a Helm chart generates a Secret name with a random suffix, you cannot use strict scope. Use namespace-wide scope, or pin the name.

### Flux

Flux works identically via `Kustomization` resources. Deploy the controller itself via `HelmRelease` CRD.

### Kustomize

SealedSecrets go in as regular resources:
```yaml
# kustomization.yaml
resources:
  - sealed-secret.yaml
```

Do NOT use `secretGenerator` for secrets managed by SealedSecrets -- that generates plain Secrets with content hashes in the name, breaking strict scope.

### File naming convention

Use `.sealed.yaml` suffix to distinguish from plaintext manifests:
```
k8s/my-app/
  deployment.yaml
  service.yaml
  db-creds.sealed.yaml
```

---

## PCI-DSS 4.0 Compliance

Sealed Secrets satisfy some PCI requirements but have gaps.

### What it covers

| Requirement | How Sealed Secrets helps |
|-------------|------------------------|
| **Req 3.5** (strong cryptography) | RSA-OAEP + AES-256-GCM hybrid encryption. Satisfies "strong cryptography" for data in transit to the cluster and at rest in Git. |
| **Req 8.6.2** (no hardcoded secrets) | Plaintext never in Git, ConfigMaps, Helm values, or env vars in manifests. |
| **Req 3.6.1** (documented key management) | Full lifecycle: generation (RSA-4096 on controller boot), distribution (public cert via `kubeseal --fetch-cert`), storage (K8s Secret in controller namespace), retirement (old keys retained for decrypt, not used for new sealing after renewal), destruction (manual -- delete old key Secrets when no SealedSecrets reference them). |

### Gaps and mitigations

| Gap | Impact | Mitigation |
|-----|--------|-----------|
| No audit trail for seal/unseal operations | Req 10.2 (log all CDE access) | Enable K8s audit logging on SealedSecret CR events + Secret reads |
| No dynamic/short-lived secrets | Req 3.6 (key management lifecycle) | Pair with Vault for dynamic DB credentials |
| No automatic secret value rotation | Req 3.7.1 (key management policies) | Manual re-seal + apply. Automate via CI pipeline that re-seals on credential rotation. |
| Unsealed secrets in etcd are base64, not encrypted | Req 3.5.1.2 (disk-level alone insufficient) | Enable etcd encryption-at-rest via KMS v2 |
| No HSM integration for key storage | Req 3.6.1 (key storage security) | BYOC with HSM-generated keys, or use ESO + cloud KMS |
| No split knowledge for key generation | Req 3.7.4 (split knowledge / dual control) | Manual BYOC ceremony: custodian A generates key on air-gapped machine, custodian B imports to cluster, neither sees the other's portion. Document the ceremony. |

**Bottom line for PCI**: Sealed Secrets work for static secrets (API keys, registry creds, webhook tokens) in a CDE if combined with etcd encryption and proper audit logging. For dynamic credentials (DB passwords, PKI), pair with Vault or ESO. QSAs will probe the key management gaps -- document your mitigations. See `compliance.md` for the full PCI-DSS requirements mapping and etcd encryption config (KMS v2 ranked options). See `architecture.md` Secrets Management section for the tool decision matrix.

---

## Security Hardening

### RBAC

- **No user should have `get` on Secrets in the controller namespace.** The private key is stored there.
- Restrict `create` on `sealedsecrets` CRs to only the namespaces/users that need them.
- The controller ServiceAccount needs cluster-wide `get`/`list`/`create`/`update`/`patch` on Secrets (or scoped to managed namespaces via `additionalNamespaces`).
- **Avoid SealedSecrets targeting `kube-system`.** The unsealed Secret lands in the same namespace as the sealing private key -- a single RBAC misconfiguration exposes both. Deploy application secrets in application namespaces.

### Network policy for the controller

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sealed-secrets-controller
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: sealed-secrets
  policyTypes: [Ingress, Egress]
  ingress:
    - ports:
        - protocol: TCP
          port: 8080        # kubeseal cert fetch + webhook
  egress:
    - to:
        - ipBlock:
            cidr: <API_SERVER_IP>/32
      ports:
        - protocol: TCP
          port: 443          # K8s API
    - to:                    # DNS -- scope to kube-dns only
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### Monitoring

Scrape Prometheus metrics from the controller:
- `sealed_secrets_controller_unseal_errors_total` -- alert on non-zero
- `sealed_secrets_controller_condition` -- controller health

### Additional hardening

- Pin controller image digest, not just tag
- Resource requests/limits (controller is lightweight: 64Mi/100m typical)
- `PodDisruptionBudget` if multiple replicas (controller is leader-elected)
- `securityContext`: non-root (default in Helm chart), read-only rootfs, drop all caps

---

## Helm Installation (Production)

```bash
# OCI registry (preferred -- immutable, no helm repo add)
helm install sealed-secrets-controller \
  oci://registry-1.docker.io/bitnamicharts/sealed-secrets \
  -n kube-system \
  --version 2.18.4 \
  --set fullnameOverride=sealed-secrets-controller \
  --set keyrenewperiod="720h" \
  --set resources.requests.memory=64Mi \
  --set resources.requests.cpu=50m \
  --set resources.limits.memory=128Mi \
  --set resources.limits.cpu=100m \
  --set metrics.serviceMonitor.enabled=true
```

For longer key lifetime (e.g. 90-day renewal):
```bash
--set keyrenewperiod="2160h"
```

---

## Common Failures

### "no key could decrypt secret"

The controller does not have the private key used to seal. Causes:
- Controller redeployed without restoring key backup
- Secret sealed against a different cluster's cert
- Key secret accidentally deleted

```bash
# Check registered keys
kubectl -n kube-system get secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active
kubectl -n kube-system logs -l app.kubernetes.io/name=sealed-secrets | grep "registered"
```

### Namespace mismatch (strict scope)

The SealedSecret was sealed for namespace `default` (kubeseal's default) but applied to `production`. The controller logs "no key could decrypt" even though the key exists -- the name/namespace binding in the ciphertext does not match.

**Fix**: always specify `-n <namespace>` on the input secret when sealing.

### Secret created but not updating

The controller does not watch for changes to the generated Secret. If someone manually edits the Secret, it stays edited until the SealedSecret is re-applied.

### Controller OOMKill

Usually fine unless you have thousands of SealedSecrets or `watchForSecrets: true` is enabled (watches all Secrets cluster-wide). Increase memory limits or tune kubeclient QPS/burst settings (configurable since v0.34.0).

---

## Anti-Patterns

1. **Not backing up the private key.** Lose the key = lose all secrets. No recovery possible.
2. **Using cluster-wide scope as default.** "Because it is easier" destroys namespace isolation guarantees.
3. **Committing the private key to Git.** The entire security model depends on the private key staying in the cluster.
4. **Assuming key renewal = secret rotation.** See Key Management section -- they are completely different operations.
5. **Sealing without specifying namespace.** kubeseal defaults to `default`. See Common Failures > Namespace mismatch.
6. **Stale offline certificates.** Fetching the cert once and using it for months means you are sealing with an old key. The controller can still decrypt (old keys retained), but you are not using the current key.
7. **Not enabling etcd encryption-at-rest.** Sealed Secrets protect secrets in Git and during transit. Once unsealed, the Secret sits in etcd base64-encoded. Without etcd encryption, anyone with etcd access reads everything.
8. **Sharing keys across prod and non-prod.** Dev cluster compromise exposes prod secrets.
9. **Running controller in non-default namespace without telling kubeseal.** The CLI defaults to `sealed-secrets-controller` in `kube-system`. Use `--controller-name` and `--controller-namespace`.
10. **Not upgrading past v0.35.x.** See CVE-2026-22728 at top of this document.
