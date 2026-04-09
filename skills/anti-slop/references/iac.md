# Infrastructure as Code Slop Patterns

Covers Terraform, Ansible, Helm, and Kubernetes manifests.

---

## Terraform

### Over-Modularizing (Soul)

**Detect:**
- Modules wrapping a single resource with no conditional logic, no computed values, no composition
- `module "vpc"` that just passes through all variables to `aws_vpc`
- Module source pointing to a local dir with one `.tf` file
- Modules with more variables than the resource they wrap has arguments

**Fix:** Use modules when they compose multiple resources, add conditional logic, or enforce policy. A single `aws_s3_bucket` doesn't need a module unless it bundles lifecycle rules, policies, and encryption together.

**Exception:** Modules for organizational consistency across teams, or when the module enforces standards (tagging, naming) that individual resources would miss.

### Redundant depends_on (Noise)

**Detect:**
- `depends_on` between resources where Terraform already infers the dependency from attribute references
- `depends_on` pointing at data sources

**Fix:** Remove explicit `depends_on` when the dependency is implicit through resource attribute references. Terraform's dependency graph handles this.

**Exception:** `depends_on` is necessary for side-effect dependencies (IAM policies, provisioners, external scripts) where Terraform can't infer the relationship from HCL references.

### Not Using Locals (Noise)

**Detect:**
- Same expression repeated in multiple resources (e.g., `"${var.env}-${var.app}"` in 5 places)
- Complex expressions inline in resource arguments
- Repeated `lookup()` or `try()` calls with the same fallback

**Fix:** Extract to `locals {}` block. Name the local descriptively.

### Stale / Anti-Patterns (Lies)

- Unpinned provider versions (no `required_providers` with version constraints)
- `provisioner "local-exec"` or `provisioner "remote-exec"` - use Ansible or user_data instead
- `terraform.tfvars` committed to git with real values
- `count` for conditional resources when `for_each` with a set would be clearer
- String interpolation for simple references: `"${var.name}"` -> `var.name`
- Nested `dynamic` blocks when a simple `for_each` on the resource would work
- `data "template_file"` (deprecated) -> `templatefile()` function

### Verbose (Noise)

- Declaring variables with `type = string` and no `description`, `default`, or `validation` - the variable block is just noise
- Empty `tags = {}` on every resource (either tag meaningfully or don't)
- `output` blocks for values nobody consumes downstream

---

## Ansible

### command/shell When a Module Exists (Lies)

The #1 Ansible slop pattern. If there's a module for it, use the module.

**Detect:**
- `command: apt-get install ...` -> `ansible.builtin.apt:`
- `command: systemctl restart ...` -> `ansible.builtin.systemd:` with `state: restarted`
- `shell: curl ... | bash` -> `ansible.builtin.get_url:` + `ansible.builtin.command:`
- `command: useradd ...` -> `ansible.builtin.user:`
- `command: cp /src /dst` -> `ansible.builtin.copy:`
- `shell: pip install ...` -> `ansible.builtin.pip:`

**Fix:** Replace with the appropriate module. Modules are idempotent; `command`/`shell` are not (unless you add `creates`/`removes`).

**Exception:** When no module exists for the operation, or when the module's behavior differs from what you need. Document why.

### ignore_errors Everywhere (Soul)

**Detect:**
- `ignore_errors: true` on tasks that should fail loudly
- `ignore_errors: true` without a comment explaining why
- `failed_when: false` on tasks that can meaningfully fail

**Fix:** Remove `ignore_errors` unless the task is genuinely optional. Use `failed_when` with a specific condition. Use `rescue` blocks in `block`/`rescue`/`always` for expected failures.

### Register-and-Never-Use (Noise)

**Detect:**
- `register: result` on tasks where `result` is never referenced
- Registered variables used only in a `debug` task

**Fix:** Remove unused `register` directives. If you need them for debugging, gate the debug task with `when: debug | default(false)`.

### Not Using Handlers (Lies)

**Detect:**
- Service restart tasks that run unconditionally after config changes
- `ansible.builtin.systemd: state=restarted` in the main task list instead of as a handler
- Config file tasks without `notify:` that should trigger restarts

**Fix:** Use `handlers` with `notify`. Handlers only run when notified and only once per play, preventing unnecessary restarts.

### Stale Patterns (Lies)

- Module names without FQCN: `apt:` -> `ansible.builtin.apt:`
- `with_items` -> `loop` (modern Ansible)
- `include:` -> `include_tasks:` or `import_tasks:`
- No YAML anchors for repeated blocks (DRY violation)

---

## Helm

### Hardcoded Values in Templates (Lies)

**Detect:**
- Literal strings in templates that should come from `values.yaml`
- Image tags hardcoded in deployment templates
- Resource limits/requests hardcoded instead of templated
- Namespace hardcoded instead of using `{{ .Release.Namespace }}`

**Fix:** Everything environment-specific goes in `values.yaml`. Templates should be parameterized.

### .Values Spaghetti (Noise)

**Detect:**
- Deeply nested `.Values` references without defaults: `{{ .Values.foo.bar.baz.qux }}`
- No `default` function on optional values
- Repeated `.Values.x.y.z` chains that should be aliased with `$var := .Values.x.y`

**Fix:** Use `default` for optional values. Use `with` or `$var` assignments for deeply nested access. Keep `values.yaml` flat where possible.

### Chart Anti-Patterns (Soul)

- Unpinned chart dependencies in `Chart.yaml`
- `tpl` function used on static strings (it's for dynamic template rendering)
- Subchart values overridden in parent `values.yaml` without documenting why
- No `NOTES.txt` for post-install instructions
- `.helmignore` missing, including test/ci files in the packaged chart

---

## Kubernetes Manifests

### Missing Production Basics (Lies)

**Detect:**
- Pods/Deployments without resource `requests` and `limits`
- `image: foo:latest` or `image: foo` (no pinned tag/digest)
- No `namespace` specified (relies on context default)
- No `readinessProbe` or `livenessProbe`
- No `securityContext` (running as root by default)
- No `PodDisruptionBudget` for HA workloads

**Fix:** Add resource limits, pin image versions, set namespace, add probes, add security context with `runAsNonRoot: true`.

**Exception:** Development/test manifests, CronJobs, and one-shot Jobs may skip probes. Security context can be inherited from PodSecurityStandards/PodSecurityPolicies at the namespace level.

### Imperative in Automation (Soul)

**Detect:**
- `kubectl create` or `kubectl run` in CI/CD pipelines or scripts
- `kubectl edit` in documentation/runbooks
- `kubectl apply -f -` with inline heredocs in shell scripts (fragile)
- Manual `kubectl scale` instead of HPA

**Fix:** Use declarative manifests with `kubectl apply -f`. Use HPA for scaling. Use Kustomize or Helm for environment variations.

### Anti-Patterns (Noise)

- `hostNetwork: true` without justification
- `privileged: true` in securityContext
- Secrets in plain YAML (not sealed/encrypted)
- `emptyDir` for persistent data
- Sidecar containers doing what an init container should
- `nodeSelector` with a single node name (defeats scheduling)

## Proxmox / LXC / VM IaC Patterns

### Terraform Proxmox Provider (Noise + Lies)

**Detect:**
- `telmate/proxmox` provider without pinned version (breaking changes between releases)
- `clone` template with `full_clone = true` when linked clone would work (wastes storage)
- Hardcoded VMID numbers instead of letting Proxmox auto-assign (`vmid = 0`)
- `os_type = "cloud-init"` without actually configuring cloud-init (blank network config)
- `disk` blocks without `iothread = true` on virtio-scsi (leaving performance on the table)
- `scsihw = "lsi"` instead of `virtio-scsi-single` (slower)
- Missing `agent = 1` when the VM has qemu-guest-agent installed
- `memory = 2048` with `balloon = 0` (disabling balloon wastes RAM on overcommitted hosts)

**Fix:** Pin provider version. Use linked clones for ephemeral VMs. Enable iothread, virtio-scsi-single, and balloon for KSM.

### Ansible Proxmox Modules (Soul)

**Detect:**
- Using `command: qm ...` or `shell: pvesh ...` when `community.general.proxmox` / `proxmox_kvm` modules exist
- Hardcoding API credentials in playbooks instead of vault/env
- `api_token_id` and `api_token_secret` in plaintext (use Ansible Vault)
- Creating VMs imperatively without idempotency checks (`state: present` handles this)
- Not using `proxmox_template` for downloading ISOs/templates (manual `wget` in tasks)

### LXC Container Config (Lies)

**Detect:**
- `nesting=1` without `keyctl=1` when running Docker inside LXC (Docker won't start)
- `unprivileged: 0` (privileged LXC) when unprivileged would work
- Static IPs hardcoded in LXC config AND in cloud-init AND in Ansible (three sources of truth)
- `rootfs` on slow storage (local-lvm) for I/O-heavy workloads when faster storage exists
- Missing `features: mount=nfs` when the container needs NFS mounts
- `mp0` mount points with `backup=1` on large data volumes (inflates PBS backups)
