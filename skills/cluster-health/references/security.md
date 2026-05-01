# Security

## Purpose

Run read-only checks for RBAC, secret exposure signals, image risk, and policy engines.

## Commands

```bash
kubectl --context <context> auth can-i --list --as=system:serviceaccount:<namespace>:<serviceaccount> -n <namespace> | head -n 120
kubectl --context <context> get clusterrolebindings,rolebindings -A | head -n 120
kubectl --context <context> get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}' | head -n 120
kubectl --context <context> get networkpolicies -A | head -n 120
kubectl --context <context> get validatingadmissionpolicies,mutatingadmissionpolicies 2>/dev/null | head -n 80 || true
kubectl --context <context> get constrainttemplates,constraints -A 2>/dev/null | head -n 80 || true
kubectl --context <context> get policies.kyverno.io,clusterpolicies.kyverno.io -A 2>/dev/null | head -n 80 || true
```

## Criteria

- GREEN: expected policy engines healthy, no obvious privileged binding sprawl, images pinned enough for review.
- YELLOW: broad bindings need review, policy engine CRDs absent, many mutable image tags.
- RED: unexpected cluster-admin bindings, public secret exposure indicators, policy engine down when required.

## Common False Positives

- Cluster-admin bindings used by managed control-plane components.
- Mutable tags in development namespaces.
- Missing policy CRDs on clusters that intentionally do not use that engine.

## Output Caps

Use `head` and namespace filters. Never print secret values; list secret names and metadata only when
needed.
