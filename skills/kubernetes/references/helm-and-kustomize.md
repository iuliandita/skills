# Helm and Kustomize Patterns

Helm 4 changes, chart structure, `Chart.yaml`, values design, template patterns, Helm anti-patterns, ArgoCD caveats, and Kustomize overlays, components, and generator pitfalls.

## Contents

- Helm Charts
- Kustomize

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
