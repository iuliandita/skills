# Production Checklist

Pre-deploy verification for Terraform configurations. Run through every section before
`terraform apply` on production or CDE infrastructure.

---

## HCL

- [ ] No hardcoded regions, AMI IDs, CIDR blocks, or account IDs
- [ ] Provider versions pinned in `required_providers` with `~>` constraints
- [ ] `.terraform.lock.hcl` committed (provider hash verification)
- [ ] All variables typed with descriptions; secrets marked `sensitive`
- [ ] Tags on every taggable resource (Name, Environment, Owner, ManagedBy, pci_scope)
- [ ] Encryption enabled on all storage resources (RDS, EBS, ElastiCache)
- [ ] S3 buckets: public access block (all four `true`), SSE-KMS, versioning, access logging, lifecycle rules, bucket policy denying non-SSL - see main skill S3 review checklist
- [ ] IMDSv2 enforced on all EC2 instances (`http_tokens = "required"`)
- [ ] Security groups: no `0.0.0.0/0` ingress except port 443 on public ALBs
- [ ] IAM policies follow least-privilege - no `"Action": "*"` or `"Resource": "*"`
- [ ] `prevent_destroy` on stateful resources (databases, S3 with data)
- [ ] No `provisioner` blocks
- [ ] `terraform fmt` + `terraform validate` clean

## Modules

- [ ] Each module has variables.tf, outputs.tf, versions.tf, README, examples, tests
- [ ] Exact version pins in production, `~>` in dev
- [ ] `terraform test` passes in CI
- [ ] Modules published to private registry or pinned Git tags (not `ref=main`)

## Operations

- [ ] State backend with encryption, locking, versioning, and access logging
- [ ] OIDC federation for CI/CD - no static cloud credentials
- [ ] Separate IAM roles for plan (read-only) and apply (write)
- [ ] CDE state files in separate backend with separate IAM role
- [ ] GitHub Actions pinned to commit SHAs (post tj-actions compromise)
- [ ] Trivy/Checkov pinned to safe versions (Trivy v0.69.3, NOT v0.69.4-6)

## Compliance (PCI-DSS 4.0)

- [ ] IaC repo has access controls, audit logging, branch protection (Req 6)
- [ ] All infra changes via PR with mandatory review (2+ approvals for CDE)
- [ ] `terraform plan` output archived as immutable CI artifact (Req 10)
- [ ] Checkov + OPA policy gates in CI (Req 6.3)
- [ ] Drift detection running (scheduled plan or dedicated tool) (Req 11.5)
- [ ] State file encrypted with KMS, access logged via CloudTrail (Req 3)
- [ ] No secrets in tfvars, state, or Git (Req 8.6.2)
- [ ] CDE resources tagged `pci_scope = "cde"` for audit traceability
- [ ] Network segmentation enforced via policy-as-code (no `0.0.0.0/0` in CDE SGs)

## Compliance (PCI MPoC)

- [ ] A&M backend infra in its own state file with CDE-level isolation
- [ ] DDoS protection (Shield/WAF) on attestation endpoints
- [ ] Multi-AZ deployment for A&M (downtime = merchants can't accept payments)
- [ ] Attestation decision logs in immutable storage
- [ ] A&M resources tagged `mpoc_domain = "3"` for audit traceability
- [ ] Annual pen test scope documented to include backend infra
