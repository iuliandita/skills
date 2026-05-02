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

For CI workflows that fan out Ansible deploy jobs by changed path, verify that the
pipeline actually runs the playbook you are touching. Adding only a playbook or role is
not enough when CI uses per-role detect-change outputs. Check that the workflow path
filters, detect-change outputs, and deploy jobs all include the new role, playbook, or
inventory area. For a baseline playbook spanning multiple host groups, provision every
SSH key required by inventory, not just a service-specific key.

Use this job shape as a reference, adapting secret names and playbook paths:

```yaml
deploy-baseline:
  needs: detect-changes
  if: needs.detect-changes.outputs.baseline == 'true' || github.event_name == 'workflow_dispatch'
  runs-on: self-hosted
  steps:
    - uses: actions/checkout@<pinned-sha> # vX
    - name: Set up SSH and vault
      env:
        SSH_KEY_PRIMARY: ${{ secrets.SSH_KEY_PRIMARY }}
        SSH_KEY_SECONDARY: ${{ secrets.SSH_KEY_SECONDARY }}
        ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
      run: |
        mkdir -p ~/.ssh
        echo "$SSH_KEY_PRIMARY" > ~/.ssh/id_primary
        chmod 600 ~/.ssh/id_primary
        echo "$SSH_KEY_SECONDARY" > ~/.ssh/id_secondary
        chmod 600 ~/.ssh/id_secondary
        echo "$ANSIBLE_VAULT_PASSWORD" > /tmp/.vault_pass
        chmod 600 /tmp/.vault_pass
    - name: Deploy baseline
      run: |
        cd ansible
        ANSIBLE_VAULT_PASSWORD_FILE=/tmp/.vault_pass ansible-playbook playbooks/baseline.yml
    - name: Cleanup secrets
      if: always()
      run: rm -f /tmp/.vault_pass ~/.ssh/id_primary ~/.ssh/id_secondary
```

Validate the Ansible side before relying on the pipeline:

```bash
ansible-playbook playbooks/baseline.yml --syntax-check
ansible-lint playbooks/baseline.yml roles/<role>
```

Successful fan-out should show the detect-changes job and expected deploy job as
successful, with unrelated jobs skipped.

## Shell Profile Rollouts

When turning a one-host shell profile tweak into fleet-wide automation, create a small
reusable role rather than sprinkling shell edits in service roles.

For SSH tmux autostart, the role defaults should stay explicit:

```yaml
---
tmux_autostart_user: "{{ ansible_user }}"
tmux_autostart_session: main
```

Use `ansible.builtin.blockinfile` with a clear marker, and locate the target home
directory with `ansible.builtin.getent` rather than assuming `/home/{{ ansible_user }}`.

```yaml
---
- name: Ensure tmux is installed
  ansible.builtin.package:
    name: tmux
    state: present

- name: Read target user account details
  ansible.builtin.getent:
    database: passwd
    key: "{{ tmux_autostart_user }}"

- name: Manage tmux autostart for interactive SSH logins
  ansible.builtin.blockinfile:
    path: "{{ getent_passwd[tmux_autostart_user][4] }}/.profile"
    create: true
    owner: "{{ tmux_autostart_user }}"
    mode: "0644"
    marker: "# {mark} ANSIBLE MANAGED BLOCK - tmux SSH autostart"
    block: |
      # Auto-start tmux for interactive SSH sessions.
      if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ -t 0 ] && [ -t 1 ] && command -v tmux >/dev/null 2>&1; then
          case "${TERM:-}" in
              dumb|unknown) ;;
              *) exec tmux new-session -A -s {{ tmux_autostart_session | quote }} ;;
          esac
      fi
```

Use `.profile` when targets may be mixed Debian, Alpine, and other POSIX-like systems.
It is portable for login SSH sessions, while `.bashrc` may not exist or may only apply
to Bash. Keep the guards strict so non-interactive commands, `scp`, and `rsync` are not
hijacked.

Validation:

```bash
ansible-playbook playbooks/tmux-autostart.yml --syntax-check
ansible-lint playbooks/tmux-autostart.yml roles/tmux_autostart
ansible-inventory --graph managed_hosts
ansible-playbook playbooks/tmux-autostart.yml --check --diff --limit <one-host>
```

Prefer an explicit umbrella group such as `managed_hosts`, and exclude hypervisors,
network appliances, and special-purpose hosts unless the user asks for them.

## ansible-navigator

Use `ansible-navigator` when:

- you are running inside execution environments
- you want interactive debugging
- you need a more platform-aligned execution path

Use `ansible-playbook` for simpler legacy or ad-hoc runs.
