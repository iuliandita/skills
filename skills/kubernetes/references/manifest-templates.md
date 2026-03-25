# Kubernetes Manifest Templates

Production-ready, copy-pasteable YAML templates. Every template includes security context, probes, resource limits, and standard labels. Updated for K8s 1.33-1.35+.

---

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/version: "<version>"
    app.kubernetes.io/component: <component>
    app.kubernetes.io/part-of: <system>
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
        app.kubernetes.io/version: "<version>"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: <app-name>
        image: <registry>/<image>@sha256:<digest>  # prefer digest over tag
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        startupProbe:
          httpGet:
            path: /health
            port: http
          failureThreshold: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        envFrom:
        - configMapRef:
            name: <app-name>-config
        - secretRef:
            name: <app-name>-secret  # created by ESO ExternalSecret, not manually
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
      terminationGracePeriodSeconds: 30
```

---

## Deployment with Native Sidecar (K8s 1.33+)

Native sidecars are init containers with `restartPolicy: Always`. They start before main containers, run alongside them, and terminate after main containers exit. Replaces preStop hacks and shareProcessNamespace kill scripts.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: log-shipper              # native sidecar
        image: <log-shipper-image>:<tag>
        restartPolicy: Always           # this makes it a sidecar
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: logs
          mountPath: /var/log/app
      containers:
      - name: <app-name>
        image: <image>:<tag>
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        startupProbe:
          httpGet:
            path: /health
            port: http
          failureThreshold: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 5
        volumeMounts:
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: logs
        emptyDir: {}
```

---

## Gateway API HTTPRoute (replaces Ingress)

Gateway API is GA (v1.5). Ingress-NGINX retires March 2026. Use HTTPRoute for all new external access.

Prerequisites: install a Gateway API implementation (Cilium, Envoy Gateway, Istio, Kong, Traefik, NGINX Gateway Fabric) and create a Gateway resource.

```yaml
# Gateway (managed by infra team, typically one per cluster/namespace)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: <namespace>
spec:
  gatewayClassName: <implementation>  # e.g., cilium, istio, envoy-gateway
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: <tls-secret>
    allowedRoutes:
      namespaces:
        from: Same
---
# HTTPRoute (managed by app team)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "<app-name>.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: <app-name>
      port: 80
---
# Traffic splitting (canary) -- replaces the base HTTPRoute during rollout
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>          # same name as base route to replace it
  namespace: <namespace>
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "<app-name>.example.com"
  rules:
  - backendRefs:
    - name: <app-name>-stable
      port: 80
      weight: 90
    - name: <app-name>-canary
      port: 80
      weight: 10
```

---

## Service

### ClusterIP (internal)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: <app-name>
  ports:
  - name: http
    port: 80
    targetPort: http
```

### Headless (StatefulSet discovery)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>-headless
  namespace: <namespace>
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app.kubernetes.io/name: <app-name>
  ports:
  - name: http
    port: 80
    targetPort: http
```

---

## ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-config
  namespace: <namespace>
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  # For file-based config:
  # config.yaml: |
  #   key: value
```

---

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <app-name>-data
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: <storage-class>
  resources:
    requests:
      storage: 10Gi
```

Access modes:
- `ReadWriteOncePod` (RWOP): single pod exclusive access (GA since 1.29, CSI only). **Prefer for databases and single-writer workloads** -- `ReadWriteOnce` only restricts to a single *node*, so multiple pods on the same node can still mount it and corrupt data.
- `ReadWriteOnce` (RWO): single node read-write. Use when RWOP is unavailable (non-CSI drivers) or multiple pods on the same node intentionally share storage.
- `ReadOnlyMany` (ROX): multi-node read-only
- `ReadWriteMany` (RWX): multi-node read-write (requires NFS or similar)

---

## StatefulSet

Use for workloads needing stable identity, persistent storage per replica, or ordered deployment (databases, message queues, consensus clusters).

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  serviceName: <app-name>-headless
  replicas: 3
  podManagementPolicy: Parallel  # or OrderedReady for strict ordering
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: <app-name>
        image: <image>:<tag>
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        startupProbe:
          httpGet:
            path: /health
            port: http
          failureThreshold: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: data
          mountPath: /data
      terminationGracePeriodSeconds: 30
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: <storage-class>
      resources:
        requests:
          storage: 20Gi
```

---

## CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: <job-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <job-name>
    app.kubernetes.io/component: batch
spec:
  schedule: "0 2 * * *"  # 2am daily
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 3
      activeDeadlineSeconds: 3600
      template:
        spec:
          restartPolicy: OnFailure
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: <job-name>
            image: <image>:<tag>
            resources:
              requests:
                memory: "256Mi"
                cpu: "250m"
              limits:
                memory: "512Mi"
                cpu: "500m"
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop: ["ALL"]
```

---

## HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app-name>
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Container-level metrics (target specific container in multi-container pods)
  - type: ContainerResource
    containerResource:
      name: memory
      container: <app-name>
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

---

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  minAvailable: 2  # or use maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
```

---

## NetworkPolicy (default deny + allow)

```yaml
# Default deny all ingress/egress in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow specific ingress (from gateway namespace)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-<app-name>-ingress
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/component: gateway  # adjust for your gateway namespace
    ports:
    - protocol: TCP
      port: 8080
---
# Allow DNS egress (almost always needed)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

---

## Pod Security Standards (namespace labels)

Apply to every app namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```
