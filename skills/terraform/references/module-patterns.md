# Terraform Module Patterns

Module design, testing, versioning, and registry strategies for production Terraform/OpenTofu.

---

## Module Structure

```
modules/<provider>/<resource-type>/
  main.tf             # Resources
  variables.tf        # Inputs -- typed, described, validated
  outputs.tf          # Outputs -- expose what consumers need, nothing more
  versions.tf         # required_providers + required_version
  locals.tf           # Computed values (optional, merge into main.tf if small)
  data.tf             # Data sources (optional)
  README.md           # Usage example, inputs/outputs table, gotchas
  examples/
    basic/            # Minimum viable usage
    complete/         # All features enabled
  tests/
    basic.tftest.hcl  # Unit tests
```

### versions.tf (every module needs this)

```hcl
terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

### variables.tf patterns

```hcl
# Required -- no default
variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy into"
}

# Optional -- sensible default
variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.medium"
}

# Validated
variable "environment" {
  type        = string
  description = "Deployment environment"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

# Sensitive
variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

# Complex
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "Security group ingress rules"
  default     = []
}
```

### outputs.tf patterns

Expose what consumers need. Don't dump every attribute.

```hcl
output "id" {
  description = "Resource ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

# Sensitive outputs
output "connection_string" {
  description = "Database connection string"
  value       = "postgresql://${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}"
  sensitive   = true
}
```

---

## Testing

### terraform test (native, GA)

```hcl
# tests/basic.tftest.hcl
run "creates_vpc" {
  command = plan  # or apply for integration tests

  variables {
    project     = "test"
    environment = "dev"
    cidr_block  = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR mismatch"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames must be enabled"
  }
}

run "validates_tags" {
  command = plan

  variables {
    project     = "test"
    environment = "prod"
    cidr_block  = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.tags["Environment"] == "prod"
    error_message = "Environment tag must match variable"
  }
}
```

Run with: `terraform test` (or `terraform test -parallelism=4` for speed)

### Mocking (TF 1.7+ / OT 1.8+)

```hcl
# tests/with_mock.tftest.hcl
mock_provider "aws" {
  alias = "mock"
}

run "test_with_mocked_provider" {
  providers = {
    aws = aws.mock
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Should create 3 private subnets"
  }
}
```

### Terratest (Go, integration)

For real infrastructure verification. Slower but proves things work end-to-end. Use for:
- Validating network connectivity (can service A reach service B?)
- Verifying encryption is actually enabled (not just in the plan)
- Testing IAM permissions work as expected
- PCI compliance evidence (QSAs want proof, not plans)

---

## Versioning Strategy

| Context | Pin Style | Example |
|---------|-----------|---------|
| Production root configs | Exact | `source = "app.terraform.io/org/vpc/aws" version = "= 2.1.3"` |
| Dev/staging root configs | Minor | `source = "app.terraform.io/org/vpc/aws" version = "~> 2.1"` |
| Module-to-module deps | Minor | `version = "~> 3.0"` |
| Provider versions | Minor | `version = "~> 6.0"` |

### Semantic versioning rules for modules

- **Major** (3.0.0): breaking changes to inputs/outputs, resource recreation required
- **Minor** (2.1.0): new optional features, no breaking changes
- **Patch** (2.1.3): bug fixes only

### The lock file

`.terraform.lock.hcl` pins exact provider hashes (SHA256). **Commit it.** This is your provider supply chain protection -- without it, a compromised registry can serve different binaries.

```bash
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_arm64
```

---

## Registry Patterns

### Private registry (HCP Terraform / TFE)

- Native monorepo support (2025+): specify VCS repo + subdirectory per module
- Automatic version detection from Git tags
- Module access controlled by TFE organization RBAC

### Git-based (no registry)

```hcl
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//modules/aws/vpc?ref=v2.1.3"
}
```

**Pin to tags, never `ref=main`** in production. Git refs have no hash verification.

### OCI registry (OpenTofu 1.10+)

Push modules to your existing container registry (GHCR, ECR, Harbor):

```hcl
module "vpc" {
  source  = "oci://ghcr.io/org/terraform-modules/vpc"
  version = "2.1.3"
}
```

### Module supply chain warning

Terraform modules fetched from registries have **no cryptographic hash verification** (unlike providers via the lock file). A compromised module version serves different code on next `terraform init`. Mitigation:
- Use private registries with access control
- Pin exact versions
- Review module source on every version bump
- Vendor critical modules into your repo for air-gapped/PCI environments

---

## Anti-Patterns

- **Wrapper modules**: a module that wraps a single resource and just passes through variables. Use the resource directly.
- **God modules**: a "platform" module that creates VPC + ECS + RDS + ALB + everything. Split by resource type and lifecycle.
- **Variable sprawl**: module has 40 variables, most with defaults nobody changes. Provide opinionated defaults, expose only what varies.
- **No tests**: modules without `terraform test` or Terratest. Untested modules are untrustworthy modules.
- **Using `count` for on/off**: `count = var.enabled ? 1 : 0` forces index-based references (`module.foo[0].id`). OpenTofu has `enabled` meta-argument. In Terraform, use `for_each` with a set: `for_each = var.create ? toset(["this"]) : toset([])`.
- **Not committing the lock file**: `.terraform.lock.hcl` is your provider supply chain protection. Commit it.
