# Roles & Collections Reference

Detailed patterns for role development, collection packaging, Galaxy usage, and testing with Molecule.

---

## Role Anatomy

### Complete role structure

```
roles/nginx/
+-- defaults/
|   +-- main.yml           # Default variables (weakest precedence)
+-- vars/
|   +-- main.yml           # Internal constants (stronger precedence)
|   +-- Debian.yml          # OS-specific vars (loaded conditionally)
|   +-- RedHat.yml
+-- tasks/
|   +-- main.yml           # Entry point (includes sub-task files)
|   +-- install.yml
|   +-- configure.yml
|   +-- service.yml
+-- handlers/
|   +-- main.yml           # Service restart/reload handlers
+-- templates/
|   +-- nginx.conf.j2
|   +-- vhost.conf.j2
+-- files/
|   +-- dhparam.pem
+-- meta/
|   +-- main.yml           # Dependencies, platforms, Galaxy metadata
|   +-- argument_specs.yml  # Argument validation (ansible-core 2.11+)
+-- molecule/
|   +-- default/
|       +-- molecule.yml
|       +-- converge.yml
|       +-- verify.yml
|       +-- prepare.yml     # Pre-convergence setup (optional)
+-- README.md
+-- LICENSE
```

### defaults/main.yml

Everything a user might want to customize. Prefix all variables with the role name:

```yaml
---
# Role: nginx
# All variables prefixed with nginx_ to avoid collisions

# Package
nginx_package_name: nginx
nginx_package_state: present

# Service
nginx_service_enabled: true
nginx_service_state: started

# Configuration
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
nginx_client_max_body_size: 10m

# SSL (optional)
nginx_ssl_enabled: false
nginx_ssl_certificate: ""
nginx_ssl_certificate_key: ""
nginx_ssl_protocols: "TLSv1.2 TLSv1.3"
nginx_ssl_ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"

# Virtual hosts
nginx_vhosts: []
#   - server_name: example.com
#     root: /var/www/example
#     listen: 80
```

### vars/main.yml

Internal constants that users should NOT override:

```yaml
---
# OS-specific package names and paths
# Loaded conditionally from vars/{{ ansible_os_family }}.yml
nginx_config_dir: /etc/nginx
nginx_log_dir: /var/log/nginx
nginx_pid_file: /run/nginx.pid
```

### tasks/main.yml

Entry point that includes sub-task files for clarity:

```yaml
---
- name: Include OS-specific variables
  ansible.builtin.include_vars: "{{ ansible_os_family }}.yml"

- name: Install nginx
  ansible.builtin.include_tasks: install.yml
  tags: [nginx, nginx-install]

- name: Configure nginx
  ansible.builtin.include_tasks: configure.yml
  tags: [nginx, nginx-configure]

- name: Manage nginx service
  ansible.builtin.include_tasks: service.yml
  tags: [nginx, nginx-service]
```

### meta/main.yml

```yaml
---
galaxy_info:
  role_name: nginx
  namespace: myorg
  author: Your Name
  description: Install and configure nginx web server
  license: MIT
  min_ansible_version: "2.17"

  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - noble
    - name: EL
      versions:
        - "8"
        - "9"

  galaxy_tags:
    - nginx
    - webserver
    - reverse_proxy

dependencies: []
# - role: common
#   vars:
#     common_packages:
#       - curl
```

### meta/argument_specs.yml

Argument validation (ansible-core 2.11+). Validates variables at role invocation:

```yaml
---
argument_specs:
  main:
    short_description: Install and configure nginx
    options:
      nginx_worker_processes:
        type: str
        default: auto
        description: Number of worker processes (or 'auto')
      nginx_ssl_enabled:
        type: bool
        default: false
        description: Enable SSL configuration
      nginx_ssl_certificate:
        type: path
        description: Path to SSL certificate (required if ssl_enabled)
      nginx_vhosts:
        type: list
        elements: dict
        default: []
        description: List of virtual host configurations
        options:
          server_name:
            type: str
            required: true
          root:
            type: path
            required: true
          listen:
            type: int
            default: 80
```

---

## Collection Structure

### Layout

```
namespace/collection_name/
+-- galaxy.yml              # Collection metadata (required)
+-- meta/
|   +-- runtime.yml         # Module routing, deprecations
+-- plugins/
|   +-- modules/            # Custom Ansible modules
|   +-- inventory/          # Inventory plugins
|   +-- callback/           # Callback plugins
|   +-- filter/             # Jinja2 filter plugins
|   +-- lookup/             # Lookup plugins
|   +-- module_utils/       # Shared Python utilities
+-- roles/                  # Bundled roles
+-- playbooks/              # Reusable playbooks
+-- docs/
+-- tests/
|   +-- integration/
|   +-- unit/
+-- changelogs/
|   +-- changelog.yaml
+-- README.md
```

### galaxy.yml

```yaml
---
namespace: myorg
name: infrastructure
version: 1.0.0
readme: README.md
authors:
  - Your Name <you@example.com>
description: Infrastructure automation collection
license_file: LICENSE
tags:
  - infrastructure
  - linux
  - hardening
dependencies:
  ansible.posix: ">=1.5.0"
  community.general: ">=8.0.0"
repository: https://github.com/myorg/ansible-infrastructure
issues: https://github.com/myorg/ansible-infrastructure/issues
build_ignore:
  - .gitignore
  - .github
  - tests/output
```

### meta/runtime.yml

```yaml
---
requires_ansible: ">=2.17.0"
action_groups:
  myorg:
    - myorg.infrastructure.my_module

plugin_routing:
  modules:
    old_module_name:
      redirect: myorg.infrastructure.new_module_name
      deprecation:
        removal_version: "2.0.0"
        warning_text: Use new_module_name instead.
```

### Build and publish

```bash
# Build the collection artifact
ansible-galaxy collection build

# Install locally for testing
ansible-galaxy collection install myorg-infrastructure-1.0.0.tar.gz --force

# Publish to Galaxy
ansible-galaxy collection publish myorg-infrastructure-1.0.0.tar.gz --api-key $GALAXY_API_KEY

# Publish to private Automation Hub
ansible-galaxy collection publish myorg-infrastructure-1.0.0.tar.gz \
  --server https://hub.example.com/api/galaxy/content/published/ \
  --api-key $HUB_API_KEY
```

---

## requirements.yml

Pin collection versions for reproducible environments:

```yaml
---
collections:
  - name: ansible.posix
    version: ">=1.5.0,<2.0.0"
  - name: community.general
    version: ">=9.0.0,<10.0.0"
  - name: community.crypto
    version: ">=2.0.0"
  - name: kubernetes.core
    version: ">=4.0.0"
  - name: hashicorp.vault
    version: ">=1.0.0"

  # Private collection from Automation Hub
  - name: myorg.infrastructure
    version: ">=1.0.0"
    source: https://hub.example.com/api/galaxy/content/published/

roles:
  # Galaxy roles (pin to tags, not branches)
  - name: geerlingguy.docker
    version: "7.4.1"
  - name: ansible-lockdown.rhel9_cis
    version: "1.5.0"
```

Install with: `ansible-galaxy install -r requirements.yml`

**Warning**: Galaxy roles have no hash verification (unlike provider lock files in Terraform).
Typosquatting on the public registry is a demonstrated attack vector. Verify role names and
authors before adding to `requirements.yml`.

---

## Molecule Testing

### molecule.yml (default scenario)

```yaml
---
dependency:
  name: galaxy
  options:
    requirements-file: requirements.yml

driver:
  name: podman                     # Preferred over Docker (rootless, no daemon)

platforms:
  - name: ubuntu-noble
    image: "docker.io/geerlingguy/docker-ubuntu2404-ansible:latest"
    pre_build_image: true
    tmpfs:
      - /run
      - /tmp
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    command: ""
    privileged: true               # Needed for systemd in container

  - name: rhel9
    image: "docker.io/geerlingguy/docker-rockylinux9-ansible:latest"
    pre_build_image: true
    tmpfs:
      - /run
      - /tmp
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    command: ""
    privileged: true

  - name: alpine
    image: "ghcr.io/buluma/alpine-openrc:latest"
    pre_build_image: true
    privileged: true               # required for OpenRC in container
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    command: /sbin/init             # boot OpenRC
    tty: true

provisioner:
  name: ansible
  config_options:
    defaults:
      callbacks_enabled: profile_tasks
    ssh_connection:
      pipelining: true
  playbooks:
    prepare: prepare.yml
    converge: converge.yml
    verify: verify.yml
  inventory:
    group_vars:
      all:
        nginx_ssl_enabled: false
        nginx_worker_connections: 512

verifier:
  name: ansible

lint: |
  set -e
  ansible-lint -p production
```

### converge.yml

```yaml
---
- name: Converge
  hosts: all
  become: true
  roles:
    - role: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"
```

### verify.yml

```yaml
---
- name: Verify
  hosts: all
  become: true
  gather_facts: true

  tasks:
    - name: Check nginx is installed
      ansible.builtin.package_facts:
        manager: auto

    - name: Assert nginx package is present
      ansible.builtin.assert:
        that:
          - "'nginx' in ansible_facts.packages"
        fail_msg: "nginx package is not installed"
        success_msg: "nginx package is installed"

    - name: Check nginx service (systemd)
      ansible.builtin.systemd:
        name: nginx
      register: nginx_service
      when: ansible_service_mgr == "systemd"

    - name: Assert nginx is active and enabled (systemd)
      ansible.builtin.assert:
        that:
          - nginx_service.status.ActiveState == "active"
          - nginx_service.status.UnitFileState == "enabled"
        fail_msg: "nginx service is not running or not enabled"
      when: ansible_service_mgr == "systemd"

    - name: Check nginx service (OpenRC)
      ansible.builtin.command:
        cmd: rc-service nginx status
      changed_when: false
      failed_when: openrc_status.rc != 0
      register: openrc_status
      when: ansible_service_mgr == "openrc"

    - name: Check nginx config syntax
      ansible.builtin.command:
        cmd: nginx -t
      register: nginx_test
      changed_when: false
      failed_when: nginx_test.rc != 0

    - name: Check nginx responds on port 80
      ansible.builtin.uri:
        url: http://localhost:80
        status_code: [200, 301, 302]
      register: http_response

    - name: Assert HTTP response
      ansible.builtin.assert:
        that:
          - http_response.status in [200, 301, 302]
```

### prepare.yml (optional pre-convergence setup)

```yaml
---
- name: Prepare
  hosts: all
  become: true

  tasks:
    - name: Update package cache (Debian)
      ansible.builtin.apt:
        update_cache: true
      when: ansible_os_family == "Debian"

    - name: Install prerequisites
      ansible.builtin.package:
        name:
          - python3
          - sudo
        state: present
```

### Molecule workflow

```bash
# Full test cycle (recommended for CI)
molecule test
# Sequence: dependency -> lint -> cleanup -> destroy -> syntax -> create ->
#           prepare -> converge -> idempotence -> side_effect -> verify ->
#           cleanup -> destroy

# Development loop (fast iteration)
molecule create                 # Create test instances
molecule converge               # Apply role
molecule converge               # Run again (idempotence check - should have 0 changes)
molecule verify                 # Run verification
molecule login -h ubuntu-noble  # SSH into instance for debugging
molecule destroy                # Clean up

# Specific scenario
molecule test -s security       # Run the 'security' scenario
```

### tox-ansible (matrix testing)

Test across multiple Python and ansible-core versions:

```ini
# tox-ansible.ini (or tox.ini with tox-ansible plugin)
[tox]
envlist = py{312,313}-ansible{2.19,2.20}-{default,security}
min_version = 4.0

[testenv]
deps =
    ansible2.19: ansible-core>=2.19,<2.20
    ansible2.20: ansible-core>=2.20,<2.21
    molecule[podman]
commands =
    molecule test -s {posargs:default}
```

Run with: `tox` (all combinations) or `tox -e py312-ansible2.20-default` (specific combo)

---

## Galaxy Best Practices

### Consuming Galaxy content

```bash
# Install from Galaxy
ansible-galaxy role install geerlingguy.docker -p roles/

# Install collection
ansible-galaxy collection install community.general

# Install from requirements.yml (reproducible)
ansible-galaxy install -r requirements.yml

# List installed
ansible-galaxy role list
ansible-galaxy collection list

# Force reinstall (useful when debugging version issues)
ansible-galaxy collection install community.general --force
```

### Verifying Galaxy content

Galaxy has no signing or hash verification. Mitigations:
- Pin exact versions in `requirements.yml`
- Verify the author (check GitHub org, not just Galaxy username)
- Review the role/collection code before production use
- Use Automation Hub for certified content in regulated environments
- Monitor Galaxy roles for suspicious updates (compare git tags to Galaxy releases)

### Publishing to Galaxy

```bash
# Role (imports from GitHub)
# 1. Create role on Galaxy and link to GitHub repo
# 2. Tag a release on GitHub
# 3. Galaxy imports automatically (or trigger via API)

# Collection
ansible-galaxy collection build
ansible-galaxy collection publish namespace-name-1.0.0.tar.gz --api-key $TOKEN
```

---

## Import vs Include

### Static (import_*) vs Dynamic (include_*)

| | `import_tasks` | `include_tasks` |
|---|---|---|
| When processed | Pre-processed at playbook load time | Processed at runtime when reached |
| Conditionals | `when` applied to every imported task | `when` evaluated once on the include |
| Loops | Cannot loop over imports | Can loop over includes |
| Tags | Tags propagate to imported tasks | Tags on include only, not inner tasks |
| Handlers | Can notify imported handlers by name | Must use `listen` for dynamic handlers |
| Recommended | Default choice for predictable behavior | When dynamic selection needed |

**Rule of thumb**: use `import_tasks` unless you need runtime conditionals or loops on the include itself.

```yaml
# Static import (preferred)
- name: Import install tasks
  ansible.builtin.import_tasks: install.yml

# Dynamic include (when needed)
- name: Include OS-specific tasks
  ansible.builtin.include_tasks: "{{ ansible_os_family | lower }}.yml"
```

For roles:
```yaml
# Static import (preferred)
- ansible.builtin.import_role:
    name: nginx

# Dynamic include (runtime selection)
- ansible.builtin.include_role:
    name: "{{ webserver_role }}"
```
