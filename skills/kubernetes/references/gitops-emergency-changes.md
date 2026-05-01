# GitOps-Managed Emergency Changes

Use this when changing a live workload that is managed by ArgoCD, Flux, or
another reconciler. Do not stop at `kubectl scale`, `kubectl patch`, or manual
apply; reconciliation may revert live changes.

## Workflow

1. Identify the owner before or immediately after the live action:
   ```bash
   kubectl get deploy -A | grep -i <app>
   kubectl -n <ns> get deploy <name> -o jsonpath='{.metadata.annotations}{"\n"}{.metadata.ownerReferences}{"\n"}'
   kubectl get applications.argoproj.io -A | grep -i <app-or-namespace>
   ```
2. If ArgoCD tracking annotations exist, inspect the Application source:
   ```bash
   kubectl -n argocd get application <app> -o jsonpath='{.spec.source.repoURL}{"\n"}{.spec.source.path}{"\n"}{.spec.source.targetRevision}{"\n"}{.spec.syncPolicy}{"\n"}'
   ```
3. Make the desired-state change in Git, then commit and push it. For example,
   if scaling a deployment to zero, set the replica count to zero in the manifest
   or chart values that the GitOps controller renders.
4. Refresh or sync the Application if needed, then verify the live object after
   reconciliation:
   ```bash
   kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
   kubectl -n <ns> get deploy <name>
   ```
5. If the workload scales back up, assume the GitOps source or another controller
   still wants it running. Check autoscalers, operators, controller settings, and
   recent Events before declaring success.

## Pitfalls

- Do not declare success after only a live `kubectl scale`; wait for reconciliation.
- Do not edit generated manifests if the GitOps source is Helm or Kustomize values.
- Do not disable auto-sync as a substitute for changing source of truth unless the
  authorized owner explicitly approves a temporary operational freeze.
- Do not forget autoscalers. HPA, KEDA, operators, and custom controllers can all
  restore replica counts independently of the GitOps tool.
