---
name: terraform
description: >
  Write and review Terraform/OpenTofu infrastructure: HCL, modules, state, providers, and policy checks.
license: MIT
compatibility: "Requires terraform or tofu CLI. Optional: tflint, checkov, conftest"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-24"
  effort: high
  argument_hint: "[path-or-resource]"
---

# Terraform and OpenTofu

Write and review reproducible infrastructure with narrow state boundaries, protected credentials,
reviewable plans, and explicit human approval for every apply. Use the installed runtime and pinned
provider schema as the authority for resource arguments and behavior.

**Version-specific behavior**: inspect the existing lock file and provider documentation before
changing pins or relying on a runtime feature.

## When to use

- Writing or reviewing Terraform/OpenTofu configurations, modules, providers, state, or imports
- Designing backend, locking, state-boundary, OIDC, policy-as-code, or drift-detection decisions
- Implementing infrastructure controls for regulated or PCI-scoped systems
- Reviewing generated HCL for security, correctness, replacement, and state impact

## When NOT to use

- Kubernetes manifests or Helm charts; use **kubernetes**
- Read-only Kubernetes health checks; use **kubernetes-health**
- VM guest configuration; use **ansible** or **virtualization**
- CI/CD pipeline architecture; use **ci-cd**
- Database schema, indexing, replication, or engine operations; use **databases**
- Application security auditing; use **security-audit**

## AI Self-Check

- [ ] Provider versions and resource arguments match the installed lock file and current provider docs
- [ ] Regions, account IDs, CIDRs, AMIs, and credentials are variables or discovered values, not literals
- [ ] IAM is least privilege; broad actions/resources and public ingress are explicit, justified exceptions
- [ ] Storage has encryption, access controls, versioning, logging, and a deliberate public-access posture
- [ ] Backend encryption, locking, state access, and `sensitive` value exposure are reviewed
- [ ] Stateful resources have deliberate lifecycle, backup, migration, and replacement behavior
- [ ] Provider/module/action versions are pinned; `.terraform.lock.hcl` is committed
- [ ] Secret values avoid ordinary state when supported and have a documented runtime delivery path
- [ ] Imports, moves, replacements, and destroys are visible in the reviewed plan
- [ ] No provisioners or committed real-value tfvars appear; tags/ownership are present where supported
- [ ] `terraform fmt` and `terraform validate` pass; scans and policy gates match the repository's policy
- [ ] Cross-cutting agent hygiene applied; read `references/agent-hygiene.md` when relevant

## Secret lifecycle

Trace each credential from issuer to CI identity, provider use, state, and workload. Record who
rotates and revokes it, lease duration, and the application reload path. Treat `sensitive` as display
redaction, not protection from state persistence. Verify rotation and revocation in an approved test
environment without printing values; pass runtime delivery ownership to **kubernetes** and pipeline
identity ownership to **ci-cd**.

## Workflow

### 1. Determine the scope

Identify the provider/account boundary, environment, resource dependencies, backend and lock design,
existing modules, compliance scope, and secret delivery path. For an existing system, inspect the
current HCL, `.terraform.lock.hcl`, backend, workspace/state boundary, and prior plan conventions
before introducing a new pattern.

### 2. Route to the narrow implementation guidance

- Read `references/implementation-patterns.md` for Terraform-versus-OpenTofu choice, HCL structure,
  lifecycle/ephemeral values, imports/moves, S3 review, module shape, account boundaries, and scans.
- Read `references/state-and-security.md` for backend configuration, encryption, locking, OIDC, or
  state surgery. Read it before any state-changing command.
- Read `references/module-patterns.md` for module API/testing or registry choices.
- Read `references/compliance.md` for PCI controls, drift detection, audit evidence, and regulated
  architecture. Read `references/production-checklist.md` before a production delivery.

### 3. Build and validate without applying

Run the relevant checks from the affected stack. A passing syntax check is not a safe infrastructure
change: inspect planned creates, changes, replacements, imports, and destroys with the owner.

```bash
terraform fmt -check -recursive
terraform validate
tflint --recursive
checkov -d . --framework terraform
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan | conftest test -
```

Report checks that ran, their results, and any unavailable tool. `plan`, state operations, and a
policy gate provide different evidence. Do not run `terraform apply`, `tofu apply`, destroy, state
removal, force-unlock, or a live migration without explicit authorization and a reviewed exact scope.

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** TERRAFORM
- **Deliverable bucket:** `audits`
- **Mode:** conditional. For analysis, review, audit, or improvement of existing content, apply the
  local reporting rules and write `docs/local/audits/terraform/<YYYY-MM-DD>-<slug>.md`. Building or
  explaining infrastructure remains conversational.
- **Severity scale:** `P0 | P1 | P2 | P3 | info`

## Related Skills

- **ansible** - configuration after provisioning
- **kubernetes** / **kubernetes-health** - cluster configuration and read-only cluster diagnostics
- **databases** - database engine operations behind provisioned services
- **ci-cd** - pipeline design that invokes Terraform
- **docker** - container image design

## Rules

1. **Run `fmt` and `validate` for every HCL change.**
2. **Pin providers, modules, and CI actions.** Commit the dependency lock file.
3. **Protect state and secrets.** Encrypt, lock, restrict, and audit state; never commit credentials.
4. **Use least privilege and explicit lifecycle controls.** Do not hide a destructive replacement.
5. **Do not use provisioners.** Use declarative infrastructure, user data, or **ansible**.
6. **Separate high-risk/CDE state.** Give it an independent backend, identity, and approval boundary.
7. **Use OIDC for CI where supported.** Keep plan and apply identities separate and narrowly scoped.
8. **Review and archive the plan before every apply.**
9. **AI does not own `terraform apply`.** A human reviews the concrete plan and authorizes the change.
