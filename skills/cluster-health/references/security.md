# Security

## Purpose

Run read-only checks for RBAC, secret exposure signals, image risk, and policy engines.

## Commands

```bash
kubectl --context <context> auth can-i --list --as=system:serviceaccount:<namespace>:<serviceaccount> -n <namespace> | head -n 120
kubectl --context <context> get clusterrolebindings,rolebindings -A | head -n 120
kubectl --context <context> get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}' | head -n 120
kubectl --context <context> get networkpolicies -A | head -n 120
kubectl --context <context> get validatingadmissionpolicies,mutatingadmissionpolicies 2>&1 | head -n 80
kubectl --context <context> get constrainttemplates,constraints -A 2>&1 | head -n 80
kubectl --context <context> get policies.kyverno.io,clusterpolicies.kyverno.io -A 2>&1 | head -n 80
```

Keep `2>&1` on the policy-engine queries. Distinguish "engine not installed" from "RBAC forbidden":

- `error: the server doesn't have a resource type "constrainttemplates"` -> Gatekeeper/that engine
  is not installed. Not a finding unless the cluster is supposed to run it.
- `Error from server (Forbidden)` -> the engine may be installed but this context cannot read its
  CRDs. Report it as a coverage gap, do not conclude "no policies."

## Interpretation

- **`auth can-i --list` shows granted verbs, not exercised ones.** A serviceaccount listing `*` on
  `*` is cluster-admin-equivalent and worth flagging; a narrow verb set is normal. The list is what
  the SA *could* do, not what it has done. Do not read a broad grant as proof of compromise, but do
  flag wildcard verbs/resources on workload SAs as excessive.
- **ClusterRoleBindings to `cluster-admin` are expected for some components.** Control-plane and
  managed-addon SAs legitimately bind cluster-admin. A binding to a default or workload SA, or to a
  group like `system:authenticated`, is the dangerous shape. Read the subject, not just the role.
- **Image-tag risk is about mutability, not vintage.** A `:latest` or untagged image can change
  under the same reference, defeating rollbacks and admission scanning. A pinned `@sha256:` digest
  is immutable. Flag mutable tags in production namespaces; mutable tags in dev are routine.
  Counting tags is not a vulnerability scan - this check spots mutability and obvious risk, not CVEs.
- **NetworkPolicy presence is not enforcement.** Policies only take effect if the CNI enforces them
  (Calico, Cilium, etc.). On a CNI that ignores NetworkPolicy, the objects exist but do nothing.
  "Policies present" is not "traffic restricted" unless the CNI enforces. Note the CNI before
  claiming isolation.
- **A policy engine installed is not a policy engine enforcing.** Gatekeeper/Kyverno can run in
  audit/warn mode rather than enforce, and individual policies have their own action
  (`Enforce`/`Audit`/`Warn`). Presence of the controller and CRDs does not prove violations are
  blocked. When it matters, note the enforcement mode rather than assuming deny.

## Secret handling

Never print secret values. List secret names and metadata only when a specific check needs them.
`kubectl get secret -o yaml` exposes base64 data that decodes trivially - do not dump it into a
report. Treat the presence of a secret in an unexpected namespace as a metadata finding, not a
reason to read its contents.

## Criteria

- GREEN: expected policy engines present and enforcing, no privileged binding sprawl on workload SAs, production images pinned by digest or immutable tag.
- YELLOW: broad bindings needing review, policy engine in audit-only mode, many mutable image tags outside dev, NetworkPolicies present but CNI enforcement unconfirmed.
- RED: cluster-admin bound to workload/default SAs or broad groups, secret-exposure indicators, or a required policy engine down or in no-op mode during enforcement-critical operation.

## Common False Positives

- Cluster-admin bindings used by managed control-plane and addon components.
- Mutable tags in development namespaces.
- Missing policy CRDs on clusters that intentionally do not use that engine (distinct from RBAC denial).
- NetworkPolicies that appear unused because the workload genuinely needs broad egress.

## Output Caps

Use `head` and namespace filters. Never print secret values; list secret names and metadata only when
needed.
