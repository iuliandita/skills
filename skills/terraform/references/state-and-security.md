# Terraform State Management & Security

State backends, locking, encryption, OIDC federation, and CI/CD pipeline patterns.

---

## State Backends

### S3 + Native Locking (recommended for AWS, TF 1.10+)

DynamoDB-based locking is **deprecated**. Use S3 native locking.

```hcl
terraform {
  backend "s3" {
    bucket       = "company-terraform-state"
    key          = "prod/network/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:eu-west-1:ACCOUNT:key/KEY-ID"
    use_lockfile = true  # S3 native locking (TF 1.10+)

    # For PCI: enable access logging
    # S3 bucket must have versioning, CloudTrail data events, and access logging enabled
  }
}
```

### Backend Selection

| Backend | Use Case | PCI-Ready |
|---------|----------|-----------|
| **S3 + native locking** | AWS teams | Yes (with KMS, versioning, CloudTrail) |
| **Azure Blob** | Azure teams | Yes (with CMK encryption) |
| **GCS** | GCP teams | Yes (with CMEK) |
| **HCP Terraform** | Managed experience | Yes (HYOK encryption) |
| **Terraform Enterprise** | On-prem regulated | Yes (self-hosted, air-gap capable) |
| **PostgreSQL** | Self-hosted, small teams | Needs hardening |
| **Local** | **Never in production** | No |

### State File Security for PCI

State files are a PCI liability -- they contain resource attributes, connection strings, and sometimes plaintext secrets.

**Mandatory controls:**
- Encrypt at rest with customer-managed KMS key (Req 3.5)
- Restrict access to pipeline IAM role + break-glass admin only
- Enable bucket versioning for rollback
- CloudTrail data events on state bucket -- every read/write logged (Req 10)
- Alert on any state access outside the CI/CD pipeline role
- Retention: 1 year minimum (Req 10.7), fintech typically 7 years

**OpenTofu advantage**: client-side state encryption (AES-GCM, AWS KMS, GCP KMS, OpenBao) encrypts before upload. Even a compromised backend can't read your state.

---

## OIDC Federation (zero static credentials in CI)

Static cloud credentials in CI/CD are the #1 anti-pattern. OIDC eliminates them.

### GitHub Actions + AWS

```hcl
# OIDC provider (one-time setup)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]  # AWS auto-validates GitHub OIDC; this value is effectively ignored but required by the resource
}

# Role for plan (read-only, any branch)
resource "aws_iam_role" "terraform_plan" {
  name = "terraform-plan"
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:org/infrastructure:*"
        }
      }
    }]
  })
}

# Role for apply (write, main branch only)
resource "aws_iam_role" "terraform_apply" {
  name = "terraform-apply"
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:org/infrastructure:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

### GitLab CI + AWS

Use `id_tokens` section in `.gitlab-ci.yml`:
```yaml
plan:
  id_tokens:
    AWS_TOKEN:
      aud: https://gitlab.example.com
  script:
    - >
      export $(aws sts assume-role-with-web-identity
      --role-arn $PLAN_ROLE_ARN
      --role-session-name gitlab-plan
      --web-identity-token $AWS_TOKEN
      --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
      --output text | awk '{print "AWS_ACCESS_KEY_ID="$1" AWS_SECRET_ACCESS_KEY="$2" AWS_SESSION_TOKEN="$3}')
    - terraform plan
```

### Key principles

- **Separate roles**: read-only for `plan` (any branch), write for `apply` (main only)
- Lock subject claims to specific repos AND branches
- CDE resources get their own IAM role with tighter scope than non-CDE
- Short-lived credentials (15min-1h) -- no long-lived keys
- Audit all `AssumeRoleWithWebIdentity` calls via CloudTrail

---

## CI/CD Pipeline Pattern

### Recommended flow

```
PR opened:
  terraform fmt -check
  terraform validate
  tflint --recursive
  checkov -d . --framework terraform
  terraform plan -out=pr-plan.tfplan
  terraform show -json pr-plan.tfplan > plan.json
  conftest test plan.json                    # OPA policy gate
  Post plan output as PR comment
  Archive plan.json as CI artifact

PR merged to main:
  terraform plan -out=apply-plan.tfplan      # re-plan on main (PR plan may be stale)
  terraform show -json apply-plan.tfplan > plan.json
  conftest test plan.json                    # re-validate
  Manual approval gate (required for CDE)
  terraform apply apply-plan.tfplan
  Archive apply output as CI artifact
```

### Supply chain hardening for CI

- **Pin ALL GitHub Actions to commit SHAs** -- `uses: hashicorp/setup-terraform@<sha>`, not `@v3`. The tj-actions/changed-files compromise (March 2026) stole credentials from ~12 hours of CI runs.
- **Pin Trivy to v0.69.3** -- v0.69.4/5/6 were compromised (CVE-2026-33634). Pin to SHA.
- **Pin Checkov to a specific version** -- `pip install checkov==X.Y.Z` or use the container image with a digest
- **Use StepSecurity Harden-Runner** to detect unexpected network connections in CI jobs
- **Separate CI secrets by environment** -- staging pipeline should NOT access prod credentials

---

## Secrets Management

### The hierarchy (worst to best)

| Method | PCI Acceptable | Notes |
|--------|---------------|-------|
| Hardcoded in `.tf` | **No** | Instant audit failure |
| `terraform.tfvars` in Git | **No** | Same as above |
| `terraform.tfvars` gitignored + CI injection | Marginal | Plaintext in pipeline env |
| Environment variables in CI | Marginal | Static, long-lived |
| **Ephemeral resources** (TF 1.10+) | Yes | Never persists in state |
| **AWS SSM / Secrets Manager** (data source) | Yes | Encrypted, access-controlled, audited |
| **HashiCorp Vault** (dynamic secrets) | Best | Short-lived, rotated, lease-based |

### Ephemeral resources (TF 1.10+ / OT 1.11+)

The right answer for new code. Secret is read at plan/apply time, never written to state.

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/master-password"
}

resource "aws_db_instance" "main" {
  password = ephemeral.aws_secretsmanager_secret_version.db_password.secret_string
}
```

### Vault dynamic secrets

For CI/CD: Vault AWS secrets engine generates temporary IAM credentials per pipeline run. No static keys anywhere.

```hcl
data "vault_aws_access_credentials" "deploy" {
  backend = "aws"
  role    = "terraform-deploy"
  type    = "sts"  # short-lived STS credentials
}

provider "aws" {
  access_key = data.vault_aws_access_credentials.deploy.access_key
  secret_key = data.vault_aws_access_credentials.deploy.secret_key
  token      = data.vault_aws_access_credentials.deploy.security_token
}
```

---

## Drift Detection

PCI Req 11.5 requires change detection. Manual `terraform plan` is necessary but insufficient.

### Approaches

| Approach | Frequency | Effort |
|----------|-----------|--------|
| Scheduled `terraform plan` in CI | Every 4-6 hours | Low -- just a cron job |
| HCP Terraform health assessments | Every 24 hours | Low -- built-in |
| Cloud-native monitoring (AWS Config Rules) | Real-time | Medium -- separate tool chain |
| Dedicated tool (env0, Spacelift) | Configurable | Medium -- SaaS cost |

### Remediation

- **Non-CDE drift**: auto-remediate after human review of the plan
- **CDE drift**: always manual approval, treated as a security incident
- Log all drift events and remediation actions for audit evidence

---

## Audit Trail Architecture

PCI Req 10 demands comprehensive logging. Three layers for Terraform:

**Layer 1: Git history** (who requested what)
- All infra changes via PR with mandatory review (2+ approvals for CDE)
- Branch protection preventing direct pushes to main
- PR links to change ticket

**Layer 2: Plan/apply output** (what actually changed)
- `terraform plan -out=plan.tfplan` + `terraform show -json plan.tfplan` archived as CI artifact
- `terraform apply` output similarly captured
- Stored in S3 with object lock (immutable, tamper-proof)
- Retention: 1 year minimum (Req 10.7)

**Layer 3: Cloud audit** (what the cloud actually did)
- CloudTrail / Activity Log / Cloud Audit Logs capture every API call
- VPC Flow Logs for network evidence
- State bucket access logs
- All in immutable storage with COMPLIANCE mode object lock

**Traceability chain**: PR #142 -> plan-142.json -> apply-142.log -> CloudTrail correlation. QSAs love this.
