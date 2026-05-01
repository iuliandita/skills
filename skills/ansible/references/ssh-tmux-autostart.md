# SSH tmux Autostart Role Pattern

Use this when turning a one-host shell profile tweak into fleet-wide Ansible
automation.

## Pattern

Create a small reusable role rather than sprinkling shell edits in service roles.

Role defaults:

```yaml
---
tmux_autostart_user: "{{ ansible_user }}"
tmux_autostart_session: main
```

Role tasks:

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
      # Safe guards:
      # - only over SSH
      # - only when not already inside tmux
      # - only with a real TTY, so scp/rsync/remote commands do not get hijacked
      if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ -t 0 ] && [ -t 1 ] && command -v tmux >/dev/null 2>&1; then
          case "${TERM:-}" in
              dumb|unknown) ;;
              *) exec tmux new-session -A -s {{ tmux_autostart_session | quote }} ;;
          esac
      fi
```

## Inventory Pattern

Create an explicit umbrella group for the managed fleet and exclude hypervisors,
network appliances, and special-purpose hosts unless the user asks for them:

```ini
[managed_hosts:children]
app_servers
worker_nodes
utility_hosts
```

Add a dedicated playbook for safe rollout, then optionally include the role early
in `site.yml`.

```yaml
---
- name: Configure tmux SSH autostart on managed hosts
  hosts: managed_hosts
  become: true
  roles:
    - tmux_autostart
```

## Why `.profile`

Use the login shell startup file for fleet automation when targets may be mixed
Debian, Alpine, and other POSIX-like systems. `.profile` is portable for login SSH
sessions, while `.bashrc` may not exist or may only apply to Bash. Keep the guard
strict so non-interactive commands are not hijacked.

## Validation

Run from the Ansible directory:

```bash
ansible-playbook playbooks/tmux-autostart.yml --syntax-check
ansible-lint playbooks/tmux-autostart.yml roles/tmux_autostart
ansible-inventory --graph managed_hosts
ansible-playbook playbooks/tmux-autostart.yml --check --diff --limit <one-host>
```

If full `site.yml` lint fails due to pre-existing unrelated role issues, still
lint the new playbook and role directly and call out the existing failures
separately.

## Pitfalls

- Do not use raw `lineinfile` for a multi-line shell block. Use `blockinfile`
  with a clear marker.
- Do not put `exec tmux` behind only `SSH_CONNECTION`; require `[ -t 0 ]` and
  `[ -t 1 ]` or `scp`, `rsync`, and remote commands can be broken.
- Do not assume `/home/{{ ansible_user }}`. Use `getent passwd` to locate the
  user's home.
- Do not use `ansible.builtin.apt` unless the fleet is Debian-only. Use
  `ansible.builtin.package` for mixed fleets.
- Check mode with `--diff --limit <one-host>` before applying broadly.
