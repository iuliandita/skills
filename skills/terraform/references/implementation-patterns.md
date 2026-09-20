# Terraform and OpenTofu Implementation Patterns

Read this reference when choosing Terraform versus OpenTofu, writing resource/module HCL, moving
state, designing account boundaries, or selecting policy checks. Read the linked state, compliance,
and production-checklist references for their specialist procedures.

## Runtime choice

Choose Terraform for HCP/TFE, Stacks, or vendor support. Choose OpenTofu for client-side state
encryption, `enabled`, OCI registries, or its MPL governance. Most providers currently support both,
but verify the installed runtime and provider schema before relying on a feature. CDKTF is archived;
use HCL or a platform-specific alternative for new work.

## HCL boundaries

Use typed variables, validation, locals for repeated expressions, data sources for discovered values,
and common tags. Mark confidential inputs/outputs `sensitive`, but remember that it only redacts CLI
output; ordinary values can still enter state. Do not hardcode account IDs, regions, AMIs, CIDRs, or
credentials.

```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project = var.project
    Environment = var.environment
    ManagedBy = "terraform"
  }
}

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
    http_tokens   = "required"
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
  lifecycle { create_before_destroy = true }
}
```

Use lifecycle rules for a stated reason: `create_before_destroy` for a safe replacement,
`prevent_destroy` for stateful data, `ignore_changes` only for an external controller, and
`replace_triggered_by` for an explicit replacement dependency. Do not add `depends_on` when
attribute references already express the dependency. Prefer `for_each` over unstable `count` indexes;
OpenTofu's `enabled` is OpenTofu-specific.

Use ephemeral values only with provider arguments documented as write-only/ephemeral. If an ordinary
argument persists a password, route it through a supported runtime delivery mechanism instead.

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/master-password"
}
```

Avoid provisioners, committed real-value tfvars, `terraform.workspace` as the default environment
boundary, and unpinned production module sources.

## Refactors and state moves

Use `import` blocks for declarative imports and `moved` blocks for a reviewed move within one state.
`moved` cannot cross state files. For a cross-state move, freeze both applies, back up both states
with restrictive permissions, add the destination HCL and remove the source HCL, then use an approved
migration path (`state mv` where supported, or state removal plus import). Validate both plans before
and after; neither may create, destroy, or drift unexpectedly. Never `state push` a pre-move backup
as a casual rollback because it can undo a completed move. Treat a stale-lock override as a last resort
with the exact known lock ID.

```hcl
import {
  to = aws_s3_bucket.existing
  id = "my-existing-bucket"
}

moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

For a cross-state move, freeze both applies and back up first. This is state mutation, so perform it
only with approved scope and exact backend/workspace identities:

```bash
set -euo pipefail
umask 077
terraform -chdir=source state pull > source-backup.tfstate
terraform -chdir=destination state pull > destination-backup.tfstate
terraform -chdir=source state rm aws_instance.web
terraform -chdir=destination import aws_instance.web i-0abc1234def56789
```

Stage source removal and destination configuration before the state writes. Run `fmt`, `validate`,
and plans in both directories before and after; block concurrent applies for both states.

## S3 review

For each private production bucket, review public-access blocks, SSE-KMS, versioning, access logging,
lifecycle rules, and a policy that denies non-TLS access without broad unintended principals. Add the
account-level public-access block too. PCI immutable audit storage needs object lock with a deliberate
retention policy. A public bucket is an explicit exception with an asset-specific access design, not a
missing block.

| Companion resource | Review point |
|---|---|
| `aws_s3_bucket_public_access_block` | All four controls enabled unless public access is explicitly designed |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-KMS and deliberate key policy |
| `aws_s3_bucket_versioning` | Recovery and tamper evidence |
| `aws_s3_bucket_logging` | Separate audit destination |
| `aws_s3_bucket_lifecycle_configuration` | Cost/retention transitions |
| `aws_s3_bucket_policy` | Deny insecure transport; inspect wildcard principals |

## Modules and tests

A reusable module should add a coherent policy or composition rather than merely proxy one resource.
Use `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, working examples, and HCL tests. Pin
production module versions exactly in their declarations; the dependency lock file tracks providers,
not remote modules. Release modules with semantic versions and a changelog. Use `terraform test` for fast module checks and run real-infrastructure tests
only in a controlled environment.

## Operations and account boundaries

Use remote state with encryption, locking, narrow access, versioning, and access audit logs. For S3
backends that support it, use S3 lockfile-based state locking; preserve an existing backend's
working lock design during an incremental change. OpenTofu client-side state encryption complements,
not replaces, backend access control.

Split state by risk and ownership: network, IAM, data, monitoring, and separately controlled CDE
stacks should not share a broad apply boundary. CDE state requires its own backend, role, and approval
path. CI should federate through OIDC with separate read-only plan and narrowly scoped apply roles;
lock subject claims to the repository and branch.

```text
states/
  network/cde/       # isolated CDE network boundary
  network/non-cde/
  compute/cde/
  compute/non-cde/
  data/cde/
  iam/               # own state and approval boundary
  monitoring/
```

## Policy and supply chain checks

Run `fmt` and `validate` on every change. Use TFLint for provider-aware linting, Checkov or Trivy for
IaC policy/security scanning, and Conftest/OPA or Sentinel only when the organization owns matching
policy. Pin providers and actions; commit the dependency lock file. Module sources lack the provider
lock file's hash verification, so use trusted registries or exact reviewed tags. Review the current
status of scanners and any security advisory before adding or changing their pins.

The normal review sequence is format -> validate -> lint/scan -> plan -> policy test -> human plan
review -> approved apply. An IaC scanner finding, a plan, and a passing policy gate each answer
different questions; none replaces the others.

## Sources

- [Dependency lock file scope](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [S3 backend locking](https://developer.hashicorp.com/terraform/language/backend/s3)
