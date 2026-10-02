# Ansible Production Checklist

Run before finishing any playbook, role, operations, or compliance task (Workflow Step 3).

## Playbooks

- [ ] FQCNs on every module (`ansible.builtin.*`, `community.general.*`, etc.)
- [ ] Every task has a descriptive `name:`
- [ ] `become: true` only where needed (not play-level unless every task requires it)
- [ ] `no_log: true` on all tasks handling secrets
- [ ] Variables quoted: `"{{ var }}"` not `{{ var }}`
- [ ] No `command`/`shell` when a module exists
- [ ] `changed_when`/`failed_when` on all `command`/`shell` tasks
- [ ] Handlers have unique names and `notify:` strings match exactly
- [ ] Tags on logical task groups
- [ ] `--check` mode works (no tasks that break in check mode without `check_mode: false`)
- [ ] Idempotent - running twice produces no changes on the second run
- [ ] No `state: latest` in production (pin package versions)
- [ ] `ansible-lint --profile production` passes clean

## Roles

- [ ] All variables prefixed with role name (`nginx_port`, not `port`)
- [ ] `defaults/main.yml` for all user-configurable values
- [ ] `meta/main.yml` with dependencies, platforms, and minimum ansible version
- [ ] Molecule test scenario with converge + idempotence + verify
- [ ] README with usage examples and variable documentation
- [ ] No hardcoded values in `tasks/` (everything parameterized)
- [ ] `handlers/main.yml` for service restarts (not inline restarts in tasks)

## Operations

- [ ] Inventory separated by environment (production, staging, dev)
- [ ] `group_vars/` and `host_vars/` for environment-specific config
- [ ] Vault-encrypted secrets in dedicated `vault.yml` files
- [ ] Vault password via `--vault-password-file` (not interactive prompt in CI)
- [ ] SSH key-based auth (no `ansible_ssh_pass` in inventory)
- [ ] EE image pinned to specific tag (not `:latest`)
- [ ] ansible.cfg committed with sane defaults (no `host_key_checking = False` in production)
- [ ] Collections pinned in `requirements.yml` with version constraints
- [ ] `ansible-lint` in CI pipeline (production profile)

## Compliance (PCI-DSS 4.0)

- [ ] CIS benchmark role applied and tested (Req 2.2)
- [ ] SSH hardened: key-only auth, no root login, idle timeout (Req 2.2.7)
- [ ] Firewall rules managed as code (Req 1)
- [ ] Auditd rules deployed for CDE systems (Req 10.2)
- [ ] Log forwarding to immutable SIEM (Req 10.4.1.1)
- [ ] FIM agent deployed and configured (AIDE/OSSEC) (Req 11.5)
- [ ] All secrets Vault-encrypted, `no_log: true` everywhere (Req 8.6.2)
- [ ] Password policies enforced via PAM (Req 8.3.6)
- [ ] Playbook execution logged and archived (Req 10, Req 6)
- [ ] Anti-malware deployed on all in-scope systems (Req 5.2)
- [ ] NTP configured for consistent timestamps (Req 10.6)
- [ ] Unnecessary services disabled (Req 2.2.4)
