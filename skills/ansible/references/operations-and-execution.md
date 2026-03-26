# Operations and Execution

This reference covers the practical day-2 mechanics around running Ansible reliably:

- inventory structure
- `ansible.cfg`
- execution environments
- CI/CD integration
- `ansible-navigator`

## Inventory

Prefer environment-separated inventory trees:

```text
inventory/
+-- production/
|   +-- hosts.yml
|   +-- group_vars/
|   +-- host_vars/
+-- staging/
|   +-- hosts.yml
|   +-- group_vars/
|   +-- host_vars/
```

Prefer YAML inventory over legacy INI when touching existing inventories. YAML handles nested
groups and structured data cleanly.

Rules of thumb:

- keep environments separate
- keep secrets out of plaintext inventory
- use dynamic inventory plugins for cloud and virtualization, static files for stable fleets
- understand merge behavior before mixing static and dynamic inventory sources

## ansible.cfg

Production defaults worth caring about:

- `host_key_checking = True`
- `pipelining = True`
- fact caching enabled
- readable callbacks enabled
- deprecation warnings enabled
- `become` explicit per play or task, not globally forced

`pipelining = True` is usually the biggest performance win, but it requires compatible sudoers
settings on the managed hosts.

## Execution Environments

Execution environments bundle:

- `ansible-core`
- collections
- Python dependencies
- system packages

Use them to keep local, CI, and platform execution consistent.

Best practices:

- separate EEs by domain instead of one giant image
- pin collection versions
- pin base images
- scan EE images like any other container artifact

## Vault and Secrets

Keep detailed Vault usage in `references/vault-and-secrets.md`, but operationally:

- keep vault files close to the environment they serve
- prefix secret variables consistently
- reference secrets indirectly
- use `--vault-password-file` or `--vault-id` for automation
- apply `no_log: true` anywhere decrypted values may surface

## CI/CD Integration

Good defaults:

- use an EE image in CI
- dry-run first with `--check --diff`
- add a manual gate for production
- pull vault credentials from CI secrets, never the repo
- archive output for auditability

If the CI system is the real problem, route to the `ci-cd` skill. This reference is about how
Ansible fits into the pipeline, not about designing the pipeline itself.

## ansible-navigator

Use `ansible-navigator` when:

- you are running inside execution environments
- you want interactive debugging
- you need a more platform-aligned execution path

Use `ansible-playbook` for simpler legacy or ad-hoc runs.
