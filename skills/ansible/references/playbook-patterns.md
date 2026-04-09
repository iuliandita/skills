# Playbook Patterns Reference

Copy-pasteable task patterns for common operations. All examples use FQCNs and follow production
conventions (idempotent, `no_log` where needed, `changed_when`/`failed_when` on shell tasks).

---

## Package Management

### apt (Debian/Ubuntu)

```yaml
- name: Install required packages
  ansible.builtin.apt:
    name:
      - nginx
      - curl
      - jq
      - unattended-upgrades
    state: present
    update_cache: true
    cache_valid_time: 3600
  become: true

- name: Remove obsolete packages
  ansible.builtin.apt:
    name:
      - apache2
      - telnet
    state: absent
    purge: true
    autoremove: true
  become: true

- name: Pin package version
  ansible.builtin.apt:
    name: "nginx={{ nginx_version }}"
    state: present
    allow_downgrade: true
  become: true
```

### dnf (RHEL/CentOS/Fedora)

```yaml
- name: Install required packages
  ansible.builtin.dnf:
    name:
      - nginx
      - curl
      - jq
    state: present
  become: true

- name: Enable module stream
  ansible.builtin.dnf:
    name: "@nodejs:20/common"
    state: present
  become: true

- name: Install from specific repo
  ansible.builtin.dnf:
    name: custom-package
    enablerepo: custom-repo
    state: present
  become: true
```

### apk (Alpine Linux)

```yaml
- name: Update cache and install packages
  community.general.apk:
    name:
      - nginx
      - curl
      - jq
    state: present
    update_cache: true
  become: true

- name: Remove packages
  community.general.apk:
    name:
      - telnet
    state: absent
  become: true

- name: Install from specific repository
  community.general.apk:
    name: my-package
    repository: http://dl-cdn.alpinelinux.org/alpine/edge/testing
    state: present
  become: true

- name: Install without cache (containers)
  community.general.apk:
    name: nginx
    state: present
    no_cache: true       # skips local cache - useful in ephemeral containers
  become: true
```

**Note:** `community.general.apk` is NOT in `ansible-core` - install the `community.general` collection.
`name` and `upgrade` are mutually exclusive. Don't loop packages individually - pass the full list to `name`.
The generic `ansible.builtin.package` auto-detects apk on Alpine but lacks apk-specific features
(`update_cache`, `no_cache`, `repository`).

---

## File Operations

### Copy, template, and file management

```yaml
- name: Deploy configuration from template
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: "0644"
    validate: "nginx -t -c %s"
  become: true
  notify: Restart nginx

- name: Copy static file
  ansible.builtin.copy:
    src: ssl/dhparam.pem
    dest: /etc/nginx/dhparam.pem
    owner: root
    group: root
    mode: "0600"
  become: true

- name: Create directory structure
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0755"
  loop:
    - /opt/app
    - /opt/app/config
    - /opt/app/data
    - /opt/app/logs
  become: true

- name: Set file permissions recursively
  ansible.builtin.file:
    path: /opt/app
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    recurse: true
  become: true

- name: Create symlink
  ansible.builtin.file:
    src: /opt/app/releases/current
    dest: /opt/app/current
    state: link
    force: true
  become: true
```

### Line-in-file operations

```yaml
- name: Ensure sysctl parameter is set
  ansible.builtin.lineinfile:
    path: /etc/sysctl.conf
    regexp: '^net\.ipv4\.ip_forward'
    line: "net.ipv4.ip_forward = 1"
    state: present
  become: true
  notify: Reload sysctl

- name: Add authorized SSH key
  ansible.posix.authorized_key:
    user: "{{ item.user }}"
    key: "{{ item.key }}"
    state: present
    exclusive: false
  loop: "{{ ssh_authorized_keys }}"
  no_log: true

- name: Manage block in configuration
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} ANSIBLE MANAGED - app hosts"
    block: |
      {{ app_primary_ip }}  app.internal
      {{ app_secondary_ip }}  app-backup.internal
  become: true
```

---

## Service Management

### systemd

```yaml
- name: Deploy systemd unit file
  ansible.builtin.template:
    src: myapp.service.j2
    dest: /etc/systemd/system/myapp.service
    owner: root
    group: root
    mode: "0644"
  become: true
  notify: Restart myapp

- name: Enable and start service
  ansible.builtin.systemd:
    name: myapp
    state: started
    enabled: true
    daemon_reload: true
  become: true

- name: Reload service (not restart)
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
  become: true
```

### OpenRC (Alpine Linux)

**Use `ansible.builtin.service`, NOT `ansible.builtin.systemd`.** The `service` module auto-detects
OpenRC via the `ansible_service_mgr` fact.

```yaml
- name: Start and enable service
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
    runlevel: default       # OpenRC-specific - which runlevel to enable in
  become: true

- name: Restart service
  ansible.builtin.service:
    name: nginx
    state: restarted
  become: true

- name: Stop and disable service
  ansible.builtin.service:
    name: nginx
    state: stopped
    enabled: false
  become: true
```

**OpenRC gotchas:**
- `ansible.builtin.systemd` does NOT work on Alpine - always use `ansible.builtin.service`
- `ansible.builtin.service_facts` has known bugs with OpenRC: `KeyError: '*'` crash on custom
  init scripts (ansible-core issue [#85551](https://github.com/ansible/ansible/issues/85551)),
  intermittent parsing failures ([#84512](https://github.com/ansible/ansible/issues/84512)),
  and incorrect status detection ([#50822](https://github.com/ansible/ansible/issues/50822))
- **Workaround**: use `rc-service <name> status` via `command` + `register` instead of `service_facts`
- Alpine uses BusyBox - binary paths may differ (e.g. `/bin/rm` not `/usr/bin/rm`)

```yaml
# OpenRC init script template
# Deploy to /etc/init.d/<service_name>
- name: Deploy OpenRC init script
  ansible.builtin.template:
    src: myapp.initd.j2
    dest: "/etc/init.d/{{ app_name }}"
    owner: root
    group: root
    mode: "0755"
  become: true
  notify: "Restart {{ app_name }}"
```

```jinja2
{# myapp.initd.j2 - OpenRC init script #}
#!/sbin/openrc-run

name="{{ app_description | default('Application Service') }}"
command="{{ app_dir }}/bin/{{ app_binary }}"
command_args="{{ app_args | default('') }}"
command_user="{{ app_user }}"
command_background=yes
pidfile="/run/${RC_SVCNAME}.pid"
directory="{{ app_dir }}"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner {{ app_user }}:{{ app_group }} --mode 0755 \
        {{ app_dir }}/data {{ app_dir }}/logs
}
```

For cross-distro roles, use `ansible.builtin.service` everywhere. For distro-specific init
scripts, conditionally deploy systemd units vs OpenRC scripts based on `ansible_service_mgr`:

```yaml
- name: Deploy systemd unit
  ansible.builtin.template:
    src: myapp.service.j2
    dest: /etc/systemd/system/myapp.service
  when: ansible_service_mgr == "systemd"
  become: true

- name: Deploy OpenRC init script
  ansible.builtin.template:
    src: myapp.initd.j2
    dest: /etc/init.d/myapp
    mode: "0755"
  when: ansible_service_mgr == "openrc"
  become: true
```

---

### systemd unit template

```jinja2
{# myapp.service.j2 #}
[Unit]
Description={{ app_description | default('Application Service') }}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={{ app_user }}
Group={{ app_group }}
WorkingDirectory={{ app_dir }}
ExecStart={{ app_dir }}/bin/{{ app_binary }} {{ app_args | default('') }}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths={{ app_dir }}/data {{ app_dir }}/logs

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier={{ app_name }}

# Limits
LimitNOFILE={{ app_nofile_limit | default(65535) }}
LimitNPROC={{ app_nproc_limit | default(4096) }}

{% if app_env is defined %}
# Environment
{% for key, value in app_env.items() %}
Environment="{{ key }}={{ value }}"
{% endfor %}
{% endif %}

[Install]
WantedBy=multi-user.target
```

---

## User and Group Management

```yaml
- name: Create application group
  ansible.builtin.group:
    name: "{{ app_group }}"
    system: true
    state: present
  become: true

- name: Create application user
  ansible.builtin.user:
    name: "{{ app_user }}"
    group: "{{ app_group }}"
    shell: /usr/sbin/nologin
    system: true
    create_home: false
    home: "{{ app_dir }}"
    state: present
  become: true

- name: Add user to supplementary groups
  ansible.builtin.user:
    name: "{{ deploy_user }}"
    groups:
      - docker
      - sudo
    append: true
  become: true

- name: Set user password (vault-encrypted)
  ansible.builtin.user:
    name: "{{ item.name }}"
    password: "{{ item.password | password_hash('sha512', item.salt) }}"
    update_password: on_create
  loop: "{{ user_accounts }}"
  no_log: true
  become: true
```

---

## Firewall Management

### firewalld (RHEL/CentOS)

```yaml
- name: Enable firewalld
  ansible.builtin.systemd:
    name: firewalld
    state: started
    enabled: true
  become: true

- name: Allow application ports
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: true
    immediate: true
    state: enabled
  loop:
    - "{{ app_port }}/tcp"
    - "443/tcp"
    - "80/tcp"
  become: true

- name: Allow service by name
  ansible.posix.firewalld:
    service: ssh
    permanent: true
    immediate: true
    state: enabled
  become: true

- name: Remove default zone services
  ansible.posix.firewalld:
    service: "{{ item }}"
    permanent: true
    immediate: true
    state: disabled
  loop:
    - cockpit
    - dhcpv6-client
  become: true
```

### UFW (Ubuntu/Debian)

```yaml
- name: Set UFW defaults
  community.general.ufw:
    direction: "{{ item.direction }}"
    policy: "{{ item.policy }}"
  loop:
    - { direction: incoming, policy: deny }
    - { direction: outgoing, policy: allow }
  become: true

- name: Allow SSH from management network
  community.general.ufw:
    rule: allow
    port: "22"
    proto: tcp
    src: "{{ management_cidr }}"
    comment: "SSH from management"
  become: true

- name: Allow application ports
  community.general.ufw:
    rule: allow
    port: "{{ item.port }}"
    proto: "{{ item.proto | default('tcp') }}"
    comment: "{{ item.comment }}"
  loop:
    - { port: "443", comment: "HTTPS" }
    - { port: "80", comment: "HTTP (redirect only)" }
  become: true

- name: Enable UFW
  community.general.ufw:
    state: enabled
  become: true
```

---

## SSH Hardening

```yaml
- name: Harden SSH configuration
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    owner: root
    group: root
    mode: "0600"
    validate: "sshd -t -f %s"
  become: true
  notify: Restart sshd

# Or with lineinfile for targeted changes:
- name: Disable root login
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^#?PermitRootLogin"
    line: "PermitRootLogin no"
  become: true
  notify: Restart sshd

- name: Disable password authentication
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^#?PasswordAuthentication"
    line: "PasswordAuthentication no"
  become: true
  notify: Restart sshd

- name: Set SSH idle timeout
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^#?ClientAliveInterval"
    line: "ClientAliveInterval {{ ssh_idle_timeout | default(300) }}"
  become: true
  notify: Restart sshd
```

---

## Cron Jobs

```yaml
- name: Schedule log rotation
  ansible.builtin.cron:
    name: "Rotate application logs"
    minute: "0"
    hour: "2"
    job: "/usr/sbin/logrotate /etc/logrotate.d/myapp"
    user: root
    state: present
  become: true

- name: Schedule backup
  ansible.builtin.cron:
    name: "Daily database backup"
    minute: "30"
    hour: "3"
    weekday: "1-5"
    job: "/opt/scripts/backup.sh >> /var/log/backup.log 2>&1"
    user: backup
    state: present
  become: true

- name: Remove deprecated cron job
  ansible.builtin.cron:
    name: "Old cleanup job"
    state: absent
    user: root
  become: true
```

---

## Command and Shell Tasks (When Modules Don't Exist)

Always add `changed_when`/`failed_when` and consider `creates`/`removes`:

```yaml
- name: Check if application is already installed
  ansible.builtin.command:
    cmd: /opt/app/bin/myapp --version
  register: app_version_check
  changed_when: false
  failed_when: false

- name: Install application (only if not present)
  ansible.builtin.command:
    cmd: /opt/app/install.sh --prefix=/opt/app
    creates: /opt/app/bin/myapp
  become: true
  when: app_version_check.rc != 0

- name: Run database migration
  ansible.builtin.command:
    cmd: "{{ app_dir }}/bin/migrate --up"
    chdir: "{{ app_dir }}"
  register: migrate_result
  changed_when: "'No migrations to run' not in migrate_result.stdout"
  become: true
  become_user: "{{ app_user }}"

- name: Get current kernel version (informational)
  ansible.builtin.command:
    cmd: uname -r
  register: kernel_version
  changed_when: false
```

---

## Jinja2 Template Patterns

### Conditionals

```jinja2
{% if nginx_ssl_enabled | default(false) %}
server {
    listen 443 ssl http2;
    ssl_certificate {{ nginx_ssl_cert }};
    ssl_certificate_key {{ nginx_ssl_key }};
}
{% endif %}
```

### Loops

```jinja2
{% for upstream in nginx_upstreams %}
upstream {{ upstream.name }} {
{% for server in upstream.servers %}
    server {{ server.host }}:{{ server.port }} weight={{ server.weight | default(1) }};
{% endfor %}
}
{% endfor %}
```

### Filters

```jinja2
{# Common filters #}
{{ my_list | join(', ') }}
{{ my_string | lower }}
{{ my_string | upper }}
{{ my_string | regex_replace('^old', 'new') }}
{{ my_dict | to_nice_yaml(indent=2) }}
{{ my_dict | to_nice_json(indent=2) }}
{{ my_var | default('fallback_value') }}
{{ my_list | unique | sort }}
{{ my_password | password_hash('sha512') }}
{{ my_ip | ansible.utils.ipaddr('address') }}    {# requires ansible.utils collection #}

{# Mandatory variable (fails if undefined) #}
{{ required_var | mandatory }}
```

### Multiline strings

```jinja2
{# Preserve newlines (for config files) #}
{{ multiline_config }}

{# Block scalar (strip trailing newline) #}
{% for rule in firewall_rules -%}
-A INPUT -p {{ rule.proto }} --dport {{ rule.port }} -j {{ rule.action }}
{% endfor %}

{# Note: -%} strips whitespace/newlines after the tag #}
{# -% strips whitespace/newlines before the tag #}
```

### Lookups

```jinja2
{# Read a file #}
{{ lookup('ansible.builtin.file', '/path/to/file') }}

{# Environment variable #}
{{ lookup('ansible.builtin.env', 'HOME') }}

{# Password generation (stored in file for idempotency) #}
{{ lookup('ansible.builtin.password', '/tmp/pw length=32 chars=ascii_letters,digits') }}

{# Vault-encrypted variable #}
{{ lookup('ansible.builtin.vars', 'vault_db_password') }}
```

---

## Wait and Verification Patterns

```yaml
- name: Wait for service to become healthy
  ansible.builtin.uri:
    url: "http://localhost:{{ app_port }}/health"
    status_code: 200
  register: health_check
  until: health_check.status == 200
  retries: 30
  delay: 5

- name: Wait for port to be open
  ansible.builtin.wait_for:
    host: "{{ inventory_hostname }}"
    port: "{{ app_port }}"
    state: started
    timeout: 60

- name: Wait for file to exist
  ansible.builtin.wait_for:
    path: /var/run/myapp.pid
    state: present
    timeout: 30

- name: Verify configuration
  ansible.builtin.command:
    cmd: "nginx -t"
  register: nginx_test
  changed_when: false
  failed_when: nginx_test.rc != 0
  become: true
```

---

## Delegation and Serial Execution

```yaml
# Rolling update (2 hosts at a time)
- name: Rolling application update
  hosts: webservers
  serial: 2
  max_fail_percentage: 25
  become: true

  pre_tasks:
    - name: Remove from load balancer
      ansible.builtin.uri:
        url: "http://{{ lb_host }}/api/backends/{{ inventory_hostname }}"
        method: DELETE
      delegate_to: localhost

  tasks:
    - name: Update application
      ansible.builtin.copy:
        src: app-{{ app_version }}.tar.gz
        dest: /opt/app/
      notify: Restart app

  post_tasks:
    - name: Wait for health check
      ansible.builtin.uri:
        url: "http://{{ inventory_hostname }}:{{ app_port }}/health"
        status_code: 200
      retries: 10
      delay: 5

    - name: Re-add to load balancer
      ansible.builtin.uri:
        url: "http://{{ lb_host }}/api/backends"
        method: POST
        body_format: json
        body:
          host: "{{ inventory_hostname }}"
          port: "{{ app_port }}"
      delegate_to: localhost
```

---

## Async Tasks

```yaml
- name: Run long-running backup (async)
  ansible.builtin.command:
    cmd: /opt/scripts/full-backup.sh
  async: 3600        # max runtime: 1 hour
  poll: 0            # fire and forget (don't wait)
  register: backup_job
  become: true

- name: Continue with other tasks...
  ansible.builtin.debug:
    msg: "Backup running in background"

- name: Wait for backup to complete
  ansible.builtin.async_status:
    jid: "{{ backup_job.ansible_job_id }}"
  register: backup_result
  until: backup_result.finished
  retries: 120
  delay: 30
```
