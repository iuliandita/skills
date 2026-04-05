# Terraform PCI-DSS 4.0 Compliance

PCI-DSS 4.0 requirements mapped to Terraform controls, policy-as-code patterns, and CDE infrastructure architecture.

---

## PCI Requirements Mapped to Terraform

### Req 1 -- Network Segmentation

Terraform configs defining VPCs, subnets, security groups, and NACLs **are the network control implementation**. They are in-scope audit artifacts.

```hcl
# CDE VPC -- private subnets only, no internet gateway
resource "aws_vpc" "cde" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-cde"
    pci_scope = "cde"
  })
}

# No public subnets in CDE VPC
resource "aws_subnet" "cde_private" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.cde.id
  cidr_block              = cidrsubnet(aws_vpc.cde.cidr_block, 4, index(data.aws_availability_zones.available.names, each.key))
  availability_zone       = each.key
  map_public_ip_on_launch = false  # enforce this via policy-as-code

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-cde-private-${each.key}"
    pci_scope = "cde"
  })
}
```

### Req 3 -- Encryption at Rest

```hcl
# CDE KMS key with auto-rotation (Req 3.6)
resource "aws_kms_key" "cde" {
  description             = "CDE data encryption"
  enable_key_rotation     = true   # rotates every 365 days
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.cde_kms.json

  tags = merge(local.common_tags, { pci_scope = "cde" })
}

# RDS -- force encryption + force SSL (Req 3/4)
resource "aws_db_instance" "payment_db" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.cde.arn

  parameter_group_name = aws_db_parameter_group.force_ssl.name

  # prevent_destroy -- this is cardholder data
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, { pci_scope = "cde" })
}

resource "aws_db_parameter_group" "force_ssl" {
  family = "postgres16"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
```

### S3 Bucket Hardening (Req 1/3)

Every S3 bucket should block public access by default. AI-generated HCL frequently omits this.

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${local.name_prefix}-data"
  tags   = merge(local.common_tags, { pci_scope = var.pci_scope })
}

# Block all public access -- apply to every bucket unless public access
# is explicitly required and documented with business justification
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Also enforce at the account level as a safety net
resource "aws_s3_account_public_access_block" "account" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cde.arn
    }
    bucket_key_enabled = true  # reduces KMS API costs
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}
```

```hcl
# Access logging -- every bucket needs this for audit trail
resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/${aws_s3_bucket.data.id}/"
}

# Lifecycle rules -- retention for compliance, transitions for cost
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
    noncurrent_version_expiration {
      noncurrent_days = 730  # keep old versions 2 years for PCI
    }
  }
}

# Bucket policy -- enforce TLS and deny overly broad access
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}
```

**Checkov checks**: `CKV_AWS_53` (block public access), `CKV_AWS_19` (SSE), `CKV_AWS_145` (CMK encryption), `CKV_AWS_18` (access logging), `CKV_AWS_21` (versioning), `CKV_AWS_70` (deny non-SSL). If any S3 bucket in a review lacks `aws_s3_bucket_public_access_block`, flag it immediately.

### Req 6 -- Secure Development

**PCI DSS 4.0 puts IaC repos in scope.** Your Terraform repo needs:
- Access controls (branch protection, RBAC on the repo)
- Audit logging (Git history, CI/CD logs)
- Change management (PR-based, reviewed, scanned)
- Static analysis (Checkov, TFLint) on every merge

### Req 7 -- Least-Privilege IAM

```hcl
# BAD -- AI loves to generate this
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Version = "2012-10-17"   # always include -- default is 2008 which breaks modern conditions
    Statement = [{
      Effect   = "Allow"
      Action   = "*"        # instant PCI failure
      Resource = "*"        # instant PCI failure
    }]
  })
}

# GOOD -- scoped to exactly what's needed
resource "aws_iam_policy" "payment_service" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [aws_kms_key.cde.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:*:*:secret:cde/*"]
      }
    ]
  })
}
```

### Req 10 -- Logging and Monitoring

```hcl
# CloudTrail for CDE account -- all events, all regions
resource "aws_cloudtrail" "cde" {
  name                       = "cde-audit-trail"
  s3_bucket_name             = aws_s3_bucket.audit_logs.id
  kms_key_id                 = aws_kms_key.audit.arn
  is_multi_region_trail      = true
  enable_log_file_validation = true  # tamper detection
  include_global_service_events = true

  # Data events for state bucket access (Req 10.2)
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.terraform_state.arn}/"]
    }
  }

  tags = merge(local.common_tags, { pci_scope = "cde" })
}

# Audit log bucket -- immutable storage (Req 10.5)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "${local.name_prefix}-audit-logs"
  tags   = merge(local.common_tags, { pci_scope = "cde" })
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    default_retention {
      mode = "COMPLIANCE"  # cannot be overridden even by root
      days = 365           # Req 10.7: minimum 1 year
    }
  }
}
```

### Req 11.5 -- Change Detection

Drift detection satisfies the FIM requirement for infrastructure.

```hcl
# AWS Config rule -- detect security group changes
resource "aws_config_config_rule" "sg_open_check" {
  name = "restricted-incoming-traffic"
  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
  }
  tags = merge(local.common_tags, { pci_scope = "cde" })
}

# AWS Config rule -- detect unencrypted storage
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "encrypted-volumes"
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  tags = merge(local.common_tags, { pci_scope = "cde" })
}
```

---

## Policy-as-Code

### Checkov (recommended, static analysis)

```bash
# Run PCI-specific checks
checkov -d . --framework terraform --check CKV_AWS_16,CKV_AWS_17,CKV_AWS_19,CKV_AWS_145

# Or use the PCI framework
checkov -d . --framework terraform --compliance pci_dss_v4
```

Key PCI checks:
- `CKV_AWS_16`: RDS encrypted at rest
- `CKV_AWS_17`: RDS not publicly accessible
- `CKV_AWS_19`: S3 server-side encryption
- `CKV_AWS_145`: S3 encrypted with CMK
- `CKV_AWS_3`: EBS encrypted
- `CKV_AWS_27`: SNS topic encrypted
- `CKV_AWS_23`: Security group doesn't allow all traffic
- `CKV_AWS_24`: Security group doesn't allow ingress from 0.0.0.0/0 to SSH

### OPA / Conftest (post-plan gate)

Evaluates the JSON plan output -- catches dynamic values static analysis misses.

```rego
# policy/pci/no_public_ingress.rego
package pci

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.after.type == "ingress"
  resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
  resource.change.after.from_port != 443
  msg := sprintf("CDE security group allows public ingress on port %d", [resource.change.after.from_port])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_db_instance"
  resource.change.after.storage_encrypted != true
  msg := "RDS instance must have encryption enabled (PCI Req 3.5)"
}
```

Run with: `terraform show -json plan.tfplan | conftest test -`

### Rollout strategy

Don't drop hard-mandatory on day one. Phase it:
1. **Advisory** (2 weeks): scan and report, no blocking
2. **Soft-mandatory** (2 weeks): block with override option (logged)
3. **Hard-mandatory**: no override, no exceptions

---

## CDE State Isolation

```
states/
  cde/
    network/         # CDE VPC, subnets, NACLs, VPC endpoints
    compute/         # Payment processing (ECS/EKS, security groups)
    data/            # RDS, KMS keys, encryption configs
    monitoring/      # CloudTrail, Config rules, GuardDuty
  non-cde/
    network/         # App VPC, public subnets, ALBs
    compute/         # App tier, internal tools
    data/            # Analytics, caches
  shared/
    iam/             # IAM roles/policies (high-risk, own state)
    dns/             # Route53 zones
    transit/         # Transit Gateway, VPC peering
```

**Each CDE state** gets:
- Own S3 key prefix with separate KMS key
- Own IAM role (pipeline can't reach non-CDE state and vice versa)
- Own approval workflow (manual for CDE, auto for non-CDE dev)
- Own CloudTrail data events
- Cross-state references via `terraform_remote_state` (read-only)

---

## CVEs and Incidents (2026)

| CVE/Incident | Product | Severity | Impact |
|---|---|---|---|
| **CVE-2025-13432** | Terraform Enterprise | Medium | State versions created without sufficient write permissions |
| **CVE-2025-25291/92** | TFE (ruby-saml) | Critical | SAML authentication bypass |
| **CVE-2025-25293** | TFE (ruby-saml) | High | SAML compressed response DoS |
| **CVE-2026-25499** | Proxmox TF/OT provider | High | Path traversal via sudoers docs |
| **tj-actions compromise** | GitHub Actions | Critical | Credential theft from CI pipelines (~12h window, March 2025, CVE-2025-30066) |
| **Trivy compromise** | Trivy (tfsec successor) | Critical | CVE-2026-33634, malicious binaries, credential exfiltration |
| **Terrascan archived** | Terrascan | N/A | No more updates. Migrate to Checkov/Trivy. |
| **CDKTF deprecated** | CDKTF | N/A | No more updates. Migrate to HCL. |
| **Registry supply chain demo** | Terraform Registry | N/A | NDC Oslo 2025: live demo of module squatting + credential theft. No hash verification for modules. |

**No critical RCE in Terraform CLI or OpenTofu CLI.** The vulnerabilities are in Enterprise, providers, and CI tooling.

---

## PCI MPoC Backend Infrastructure

If you run MPoC (SoftPOS / tap-to-pay) backends, Domain 3 (Attestation & Monitoring) and Domain 5 (Overall Environment) put your Terraform-managed infra in scope.

**The A&M backend** must either be PCI-DSS certified or assessed against MPoC Appendix A. All PCI-DSS 4.0 Terraform controls above apply. Additionally:

```hcl
# A&M-specific: dedicated VPC with low-latency networking
resource "aws_vpc" "mpoc_am" {
  cidr_block           = "10.110.0.0/16"
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-mpoc-am"
    pci_scope = "cde"
    mpoc_domain = "3"
  })
}

# A&M attestation endpoint -- needs DDoS protection (exposed to all merchant devices)
resource "aws_shield_protection" "am_endpoint" {
  name         = "mpoc-am-endpoint"
  resource_arn = aws_lb.mpoc_am.arn
}

# WAF on A&M ALB -- rate limiting per device
resource "aws_wafv2_web_acl" "mpoc_am" {
  name  = "mpoc-am-ratelimit"
  scope = "REGIONAL"
  default_action { allow {} }
  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "mpoc-am-default"
  }

  rule {
    name     = "rate-limit-per-device"
    priority = 1
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "mpoc-am-ratelimit"
    }
  }
  # ...
}
```

**Key Terraform considerations for MPoC:**
- A&M state file in its own backend (same isolation as CDE)
- Multi-AZ deployment mandatory (A&M downtime = merchants can't accept payments)
- Attestation decision logs in immutable storage (device enrolled/disabled/flagged)
- Regional deployment if latency SLAs require it (attestation must be real-time)
- Annual pen test scope includes the entire backend infra, not just the app layer

---

## Tagging Strategy for Audit

Every resource needs these tags for PCI traceability:

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team
    pci_scope   = var.pci_scope  # "cde" | "connected" | "out_of_scope"
    pci_req     = var.pci_req    # e.g., "3" for encryption resources
  }
}
```

QSAs can then query AWS resource groups by `pci_scope` tag to verify scope boundaries.
