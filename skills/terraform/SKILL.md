---
name: terraform
description: >
  · Write, review, or architect Terraform/OpenTofu infrastructure-as-code -- HCL patterns,
  module design, state management, and policy-as-code. Triggers: 'terraform', 'opentofu',
  'hcl', 'tfvars', 'tfstate', 'module', 'terraform plan', 'sentinel', 'checkov', 'tflint'.
license: MIT
compatibility: "Requires terraform or tofu CLI. Optional: tflint, checkov, conftest"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-24"
  effort: high
  argument_hint: "[path-or-resource]"
---

# Terraform & OpenTofu: Production Infrastructure-as-Code

Write, review, and architect Terraform/OpenTofu infrastructure -- from individual resources to multi-account, PCI-compliant platform architectures. The goal is reproducible, drift-free, auditable infrastructure that passes both peer review and QSA assessment.

**Target versions**: Terraform 1.13-1.14+ (IBM/HashiCorp, BSL), OpenTofu 1.10-1.11+ (Linux Foundation, MPL). Helm provider v3.1+, K8s provider v3.0+, AWS provider v6.x, Azure v4.x, GCP v7.x.

This skill covers four domains depending on context:
- **HCL** -- resource configs, variables, outputs, data sources, expressions, lifecycle rules
- **Modules** -- structure, versioning, testing, registry patterns, reusable components
- **Operations** -- state management, backends, workspaces, import, migration, CI/CD
- **Compliance** -- PCI-DSS 4.0 controls, policy-as-code, audit trails, drift detection, CDE isolation

## Terraform vs OpenTofu (2026)

IBM acquired HashiCorp for $6.4B (closed Feb 2025). Terraform stays BSL 1.1. The codebases have meaningfully diverged.

**Choose Terraform** if: already on HCP Terraform/TFE, need Stacks for multi-component orchestration, want vendor support.

**Choose OpenTofu** if: need client-side state encryption (Terraform never shipped this), BSL is a legal concern, want `enabled` meta-argument on resources, want OCI registry for providers/modules, need Linux Foundation governance.

**Both share the provider plugin protocol** -- most providers work on both. For now.

**CDKTF is dead.** Deprecated Dec 2025, archived. Migrate to HCL or AWS CDK.

## When to use

- Writing or reviewing Terraform/OpenTofu configurations
- Designing module architecture or registry patterns
- Planning state management, backend strategy, or migration
- Setting up CI/CD pipelines for IaC (plan/apply workflows)
- Implementing policy-as-code gates (Checkov, OPA, Sentinel)
- PCI-DSS 4.0 compliance for infrastructure provisioning
- Multi-account/multi-cloud architecture with blast radius controls
- Reviewing AI-generated Terraform for security and correctness

## When NOT to use

- Kubernetes manifests or Helm charts (use **kubernetes**)
- Ansible playbooks or configuration management (use **ansible**)
- Docker/container optimization (use **docker**)
- CI/CD pipeline design (use **ci-cd**)
- Database engine configuration, schema design, or migrations (use **databases**)
- Security auditing application code (use **security-audit**)

---

## AI Self-Check

AI tools consistently produce the same Terraform mistakes. **Before returning any generated HCL, verify against this list:**

- [ ] No hardcoded values -- regions, AMI IDs, CIDR blocks, account IDs must be variables
- [ ] No overly permissive IAM -- no `"Action": "*"` or `"Resource": "*"` unless explicitly requested
- [ ] No `0.0.0.0/0` ingress on security groups (except port 443 for public ALBs, justified)
- [ ] S3 buckets: `aws_s3_bucket_public_access_block` with all four settings `true` (unless public access is explicitly required and justified), plus SSE-KMS encryption (`aws_s3_bucket_server_side_encryption_configuration`), versioning enabled, access logging (`aws_s3_bucket_logging`), and no overly permissive bucket policy (review `aws_s3_bucket_policy` for broad `Principal: "*"` grants)
- [ ] Provider versions pinned in `required_providers` with `~>` constraints
- [ ] Backend config present (not local) with encryption and locking
- [ ] `lifecycle` blocks where needed (`create_before_destroy`, `prevent_destroy` on stateful resources)
- [ ] `sensitive = true` on variables/outputs containing secrets
- [ ] Tags on every taggable resource (at minimum: Name, Environment, Owner, pci_scope if applicable)
- [ ] No deprecated resource arguments (check provider changelog -- AI trains on old syntax)
- [ ] No `provisioner` blocks -- use Ansible or user_data instead
- [ ] State file does NOT contain plaintext secrets (use ephemeral resources on TF 1.10+ or data sources for runtime secret lookup)
- [ ] `terraform fmt` and `terraform validate` pass

**AI should never own `terraform apply`.** In March 2026, an AI-assisted Terraform workflow deleted production infrastructure through escalating cleanup logic. Plan output is reviewed by a human. Always.

---

## Workflow

### Step 1: Determine the domain

Based on the request:
- **"Create a VPC/RDS/EC2/resource"** -> HCL
- **"Create a reusable module"** -> Modules
- **"Set up state backend" / "migrate state"** -> Operations
- **"Make this PCI compliant" / "policy gates"** -> Compliance
- **"Review this Terraform"** -> Apply production checklist + critical rules + AI self-check
- **"Review S3 buckets"** -> S3 hardening review (see below) + AI self-check

### Step 2: Gather requirements

Before writing HCL, determine:
- **Cloud provider(s)** and account/project structure
- **Resource type** and its dependencies
- **Environment** (dev/staging/prod) and promotion strategy
- **State backend** and locking mechanism
- **Compliance scope**: PCI CDE? Regulated? What tags/policies apply?
- **Existing modules**: reuse before creating new ones
- **Secrets**: how are they injected? (Vault, SSM, Secrets Manager -- never tfvars)

### Step 3: Build

Follow the domain-specific section below. Always `terraform fmt` + `terraform validate` + run Checkov before finishing.

### Step 4: Validate

```bash
terraform fmt -check -recursive              # Format check
terraform validate                            # Syntax + provider validation
tflint --recursive                           # Provider-specific linting
checkov -d . --framework terraform           # Security/compliance scan
terraform plan -out=plan.tfplan              # Review the plan
terraform show -json plan.tfplan | conftest test -  # Policy-as-code gate (OPA)
```

---

## HCL Patterns

### Resource structure

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.private_subnet_id

  root_block_device {
    encrypted   = true
    kms_key_id  = var.kms_key_arn
    volume_size = 20
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # IMDSv2 -- enforce this always
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-web-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}
```

### Key patterns

**Variables**: type them. Default non-sensitive ones. Mark secrets `sensitive`. Use `validation` blocks for constraints.

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "db_password" {
  type      = string
  sensitive = true  # prevents logging in plan output
}
```

**Locals**: extract repeated expressions. Name descriptively.

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  is_prod     = var.environment == "prod"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    pci_scope   = var.pci_scope
  }
}
```

**Data sources**: for runtime lookups. Never hardcode AMI IDs, AZ lists, or account IDs.

```hcl
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

**Ephemeral resources** (TF 1.10+ / OT 1.11+): secrets that never persist in state. Ephemeral values can only flow into `write_only` arguments, provider configs, provisioners, or other ephemeral contexts -- not into regular resource arguments.

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/master-password"
}

resource "aws_db_instance" "main" {
  password = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string  # must be write_only in provider
}
```

**Lifecycle rules**: use deliberately, not defensively.
- `create_before_destroy` -- for zero-downtime replacements (LBs, ASGs, DNS)
- `prevent_destroy` -- for stateful resources (databases, S3 buckets with data)
- `ignore_changes` -- for attributes managed outside Terraform (ASG desired_count managed by HPA)
- `replace_triggered_by` -- force recreation when a dependency changes

**Import blocks** (TF 1.5+): declarative imports, no state surgery.

```hcl
import {
  to = aws_s3_bucket.existing
  id = "my-existing-bucket"
}
```

**Moved blocks** (TF 1.8+): declarative intra-state refactoring. Rename resources or move into/out of modules within the same state file. Reviewed in PRs, applied automatically on `terraform apply`. Does NOT work across state files -- for cross-state moves, see the state surgery workflow in `references/state-and-security.md`.

```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

### What NOT to write

- `provisioner "local-exec"` or `provisioner "remote-exec"` -- use Ansible
- `depends_on` when Terraform already infers the dependency from attribute references
- `count` for conditional resources when `for_each` with a set is clearer (OpenTofu: use `enabled`)
- String interpolation for simple references: `"${var.name}"` -> `var.name`
- `terraform.tfvars` committed to Git with real values
- `terraform.workspace` for environment separation (use separate state files or workspaces with distinct backends)
- Inline `provisioner` blocks of any kind

### S3 bucket review checklist

When reviewing or writing S3 bucket configurations, verify every bucket has **all six** companion resources. AI-generated HCL routinely omits several of these.

| # | Resource | Why | Checkov |
|---|----------|-----|---------|
| 1 | `aws_s3_bucket_public_access_block` | Block all public access (all four settings `true`) | CKV_AWS_53 |
| 2 | `aws_s3_bucket_server_side_encryption_configuration` | SSE-KMS with customer-managed key | CKV_AWS_145 |
| 3 | `aws_s3_bucket_versioning` | Rollback + tamper evidence | CKV_AWS_21 |
| 4 | `aws_s3_bucket_logging` | Access audit trail (target a dedicated logging bucket) | CKV_AWS_18 |
| 5 | `aws_s3_bucket_lifecycle_configuration` | Expiration/transition rules for cost and compliance retention | -- |
| 6 | `aws_s3_bucket_policy` | Explicit deny on non-SSL requests (`aws:SecureTransport = false`); no `Principal: "*"` grants unless public access is justified | CKV_AWS_70 |

Also verify the **account-level** safety net: `aws_s3_account_public_access_block` with all four settings `true`. This catches any bucket that accidentally ships without its own block.

For PCI CDE buckets, add `aws_s3_bucket_object_lock_configuration` with COMPLIANCE mode retention for immutable audit storage (Req 10.5).

See `references/compliance.md` for full S3 hardening HCL examples including account-level blocks and object lock.

---

## Modules

Read `references/module-patterns.md` for detailed module structure, testing patterns, and registry strategies.

### Structure

```
modules/<provider>/<resource-type>/
  main.tf           # Resources
  variables.tf      # Inputs
  outputs.tf        # Outputs
  versions.tf       # Required providers + terraform version
  README.md         # Usage examples
  examples/         # Working example configs
  tests/            # .tftest.hcl files
```

### Versioning

- **Production**: pin exact versions (`= 2.1.3`) or use dependency lock file
- **Dev/staging**: allow minor updates (`~> 2.1`)
- Every module gets semantic versioning and a CHANGELOG
- **Provider versions**: pin with `~>` in `required_providers`. The `.terraform.lock.hcl` file pins exact hashes -- commit it.

### Testing (2026 standard)

- **`terraform test`** (native, GA): HCL-based unit tests for every module. Fast, runs in CI on every PR.
- **Terratest** (Go): integration tests that spin up real infrastructure. Run nightly or pre-release.
- Both complement each other. `terraform test` for fast validation, Terratest for real-world proof.

### Anti-patterns

- Modules wrapping a single resource with no added logic (just use the resource directly)
- Modules with more variables than the resource they wrap has arguments
- `module "vpc"` that just passes through all variables to `aws_vpc`
- Not pinning module versions in production
- Using Git refs for module sources in production (use a registry or exact tags)

---

## Operations

Read `references/state-and-security.md` for state backends, locking, encryption, OIDC federation, CI/CD pipeline patterns, and state surgery (cross-state resource migration).

### State management

See `references/state-and-security.md` for full backend config examples, OIDC federation patterns, CI/CD pipeline flows, and cross-state migration workflows.

**S3 + native locking** (TF 1.10+): DynamoDB-based locking is deprecated. Use `use_lockfile = true`. Encrypt with KMS. Enable versioning and CloudTrail data events on the bucket.

**OpenTofu**: add client-side state encryption on top (AES-GCM, AWS KMS, GCP KMS, or OpenBao) -- encrypts before upload, even a compromised backend can't read state.

### State file splitting (blast radius)

Split by risk and ownership:
```
states/
  network/cde/         # CDE VPC -- separate IAM role, separate approval
  network/non-cde/     # Everything else
  compute/cde/         # Payment processing
  compute/non-cde/     # App tier
  data/cde/            # RDS with cardholder data
  iam/                 # IAM is high-risk -- own state, own approval
  monitoring/          # CloudTrail, GuardDuty, Config
```

CDE state files get their own backend, IAM role, and approval workflow. A `terraform apply` on non-CDE infra must never touch CDE resources.

### CI/CD credentials: OIDC federation

**No static credentials in CI.** Use OIDC federation (GitHub Actions, GitLab CI):

- CI generates a signed JWT per pipeline run
- Cloud provider validates JWT against CI platform's OIDC endpoint
- Short-lived credentials issued, scoped to that execution
- **Separate roles**: read-only for `plan` (any branch), write for `apply` (main only)
- Lock subject claims to specific repos AND branches

### Supply chain integrity

The Terraform ecosystem has real supply chain risks (March 2026):

- **Pin GitHub Actions to commit SHAs** -- `tj-actions/changed-files` was compromised March 2025 via upstream reviewdog/action-setup (CVE-2025-30154) (~12 hours of credential theft). Same pattern as the Trivy compromise a year later.
- **Module supply chain is weak** -- modules have no hash verification (unlike the provider lock file). Typosquatting on the public registry is a demonstrated attack vector (NDC Oslo 2025).
- **Terrascan: dead.** Archived Nov 2025. Migrate to Checkov or Trivy.
- **tfsec: merged into Trivy.** Still works standalone but no new development.
- **Trivy IaC scanning**: pin to a verified version in CI. Check release notes before updating -- supply chain attacks on CI tools are real. Pin to SHA digest, not mutable tag.
- **CDKTF: dead.** Deprecated Dec 2025, archived. Migrate to HCL.

---

## Architecture

### Multi-account strategy

```
Organization root
+-- Security OU
|   +-- Log Archive account (CloudTrail, Config, audit logs)
|   +-- Security Tooling account (GuardDuty, Security Hub)
+-- Infrastructure OU
|   +-- Shared Services account (Transit Gateway, DNS, CI/CD)
+-- Workloads OU
|   +-- Dev account
|   +-- Staging account
|   +-- Production account
+-- CDE OU (PCI)
    +-- CDE Production account (payment processing -- isolated)
    +-- CDE Staging account
```

Terraform manages cross-account via `provider` aliases with `assume_role`:

```hcl
provider "aws" {
  alias  = "cde"
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::CDE_ACCOUNT:role/TerraformDeployRole"
  }
}
```

### Security scanning stack

| Tool | Role | Status |
|------|------|--------|
| **Checkov** | Static HCL + plan analysis, 750+ checks, PCI/CIS/NIST frameworks | 🟢 Active, recommended |
| **Trivy** (absorbed tfsec) | IaC + container + repo scanning, single binary | 🟢 Active (v0.69.3 safe, v0.69.4-6 COMPROMISED) |
| **TFLint** | Provider-specific linting, catches misconfigs linters miss | 🟢 Active |
| **OPA / Conftest** | Custom policy-as-code on JSON plan output | 🟢 Active (CNCF) |
| **Sentinel** | Native TFC/TFE policy engine | 🟢 Active (proprietary) |
| **tfsec** | Security scanner | 🟡 Deprecated (merged into Trivy) |
| **Terrascan** | IaC scanner | 🔴 Archived Nov 2025 -- migrate off |
| **CDKTF** | TypeScript/Python IaC | 🔴 Deprecated Dec 2025 -- migrate off |

**Recommended CI pipeline**: `terraform fmt` -> `terraform validate` -> `tflint` -> `checkov` -> `terraform plan` -> `conftest test` (OPA) -> human review -> `terraform apply`

---

## Compliance

Read `references/compliance.md` for the full PCI-DSS 4.0 requirements mapping, drift detection strategy, audit trail architecture, and OIDC patterns.

### Quick reference: PCI-DSS 4.0 and IaC

**PCI DSS 4.0 explicitly puts IaC repos in scope** (Req 6). Your Terraform repo needs the same controls as any CDE system -- access controls, audit logging, change management.

**Critical requirements:**
- **Req 1**: Network segmentation via VPC/subnet/SG configs in Terraform -- these ARE the audit artifacts
- **Req 3**: Encryption enforced via IaC (`storage_encrypted = true`, KMS keys, `force_ssl`)
- **Req 6**: Secure development lifecycle -- PR reviews, static analysis, policy-as-code gates on every merge
- **Req 7**: Least-privilege IAM enforced in Terraform -- no `"Action": "*"` in CDE
- **Req 8.6.2**: No hardcoded secrets -- use ephemeral resources (TF 1.10+) or Vault/SSM data sources
- **Req 10**: Audit trail -- Git PRs + archived plan/apply JSON + CloudTrail + immutable S3
- **Req 11.5**: Change detection -- drift detection satisfies FIM requirement for infrastructure

**State file security**: state contains secrets (even with `sensitive`). Encrypt at rest (S3 SSE-KMS), restrict access (IAM policy), enable versioning, log all access (CloudTrail data events), retain 1+ year.

**QSA expectations (2026)**: operational proof, not policy intent. Git history showing reviewed PRs, archived plan outputs, policy scan results per deployment, drift reports proving continuous compliance.

---

## Production Checklist

Read `references/production-checklist.md` for the full pre-deploy checklist covering HCL quality, module standards, operations, PCI-DSS 4.0, and PCI MPoC compliance.

---

## Reference Files

- `references/module-patterns.md` -- module design and testing patterns
- `references/state-and-security.md` -- state backend, locking, encryption, OIDC patterns, and state surgery (cross-state migration)
- `references/compliance.md` -- compliance and audit-oriented Terraform guidance
- `references/production-checklist.md` -- pre-deploy verification checklist (HCL, modules, operations, PCI-DSS, MPoC)

---

## Related Skills

- **ansible** -- for day-2 configuration of provisioned resources. Terraform provisions the VM;
  Ansible configures what runs on it. No `provisioner` blocks -- use Ansible instead.
- **kubernetes** -- K8s manifests and Helm charts. Terraform provisions the cluster; kubernetes configures what runs on it.
- **databases** -- engine tuning and operations. Terraform provisions managed databases; databases skill tunes the engine.
- **ci-cd** -- pipeline design that runs `terraform plan/apply`. Terraform covers HCL; ci-cd covers the pipeline stages.
- **docker** -- container image patterns. Terraform provisions container infrastructure but Dockerfile design belongs in docker.

---

## Rules

These are non-negotiable. Violating any of these is a bug.

1. **`terraform fmt` + `terraform validate` on every change.** Non-negotiable.
2. **Pin provider versions.** `required_providers` with `~>` constraints. Commit the lock file.
3. **Never commit secrets.** Not in `.tf`, not in `.tfvars`, not in state. Use ephemeral resources, Vault, or SSM.
4. **No `provisioner` blocks.** Use Ansible or user_data.
5. **No `"Action": "*"` in IAM policies.** Least-privilege only.
6. **Encrypt everything.** Storage, transit, state backend. No exceptions.
7. **State backend with locking and encryption.** Never local state in production.
8. **Separate CDE state files.** Own backend, own IAM role, own approval workflow.
9. **OIDC federation for CI/CD.** No static cloud credentials.
10. **Pin CI actions to commit SHAs.** Mutable tags are compromised supply chain vectors (tj-actions March 2025, Trivy March 2026).
11. **`terraform plan` before every `apply`.** Archive the plan output.
12. **AI never owns `terraform apply`.** Plan output is reviewed by a human. Always.
13. **Run the AI self-check.** Every generated HCL gets verified against the checklist above before returning.
