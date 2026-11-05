---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "Kubernetes"
    version: "1.37.1 / 1.36.5 / 1.35.9"
    source: "https://kubernetes.io/releases/"
  - tool: "Helm"
    version: "4.3.0 / 3.22.0"
    source: "https://helm.sh/docs/topics/version_skew/"
---

# Target versions

| Tool | Version | Source |
|------|---------|--------|
| Kubernetes | 1.37.1 / 1.36.5 / 1.35.9 | [Release history](https://kubernetes.io/releases/) |
| Helm | 4.3.0 / 3.22.0 | [Compatibility matrix](https://helm.sh/docs/topics/version_skew/) |

**Target versions** (October 2026): Kubernetes 1.35-1.37 are the supported minors (1.37.1 / 1.36.5 / 1.35.9). Kubernetes maintains the most recent three minors (1.37, 1.36, 1.35), per the [release history](https://kubernetes.io/releases/); 1.34 entered maintenance mode August 27, 2026 and reaches EOL October 27, 2026. Upstream Kubernetes has no LTS. Managed **vendor extended support** (AKS/EKS) carries older minors longer - attribute it to the platform, not upstream. Helm 4.3.0 and Helm 3.22.0 are the current parallel release lines. Verify Helm 3 support status before selecting it for a new deployment. Check the [Helm compatibility matrix](https://helm.sh/docs/topics/version_skew/) before pairing releases: Helm 4.3.x and Helm 3.22.x both document Kubernetes 1.34-1.37 support, covering the supported minors above.
