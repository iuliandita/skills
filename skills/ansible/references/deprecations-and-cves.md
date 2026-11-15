# Deprecations, Breaking Changes, and CVEs

ansible-core removals and deprecations by release, the CalVer migration, and the CVE table with mitigations.

## Deprecations and Breaking Changes

### ansible-core 2.20

**Removals (already removed)**:
- `smart` transport value - choose `ssh` or `paramiko` explicitly
- Galaxy v2 API support - Galaxy servers must support v3
- `PARAMIKO_HOST_KEY_AUTO_ADD` and `PARAMIKO_LOOK_FOR_KEYS` config keys
- `passlib_or_crypt` API from encrypt utility

**Deprecations (removal in 2.24)**:
- `INJECT_FACTS_AS_VARS` defaults to True but will flip to False. Access facts via `ansible_facts['hostname']` instead of `ansible_hostname`.
- `ansible.module_utils._text` imports (`to_bytes`, `to_native`, `to_text`) - use `ansible.module_utils.common.text.converters` instead
- `vars` internal variable cache

### ansible-core 2.19 (previous)

- **Data Tagging** overhaul: improved error reporting but some loop templates broke (GitHub issue #85605). If loops fail with type errors after upgrading, check for native Jinja2 type handling conflicts.

### CalVer migration

All Ansible DevTools projects (molecule, ansible-lint, ansible-navigator, tox-ansible) switched from SemVer to CalVer (`YY.MM.MICRO`) in 2024. Don't be confused by the version jump (e.g., ansible-lint 6.x -> 26.x).

## CVEs to know

| CVE | Severity | Description | Mitigation |
|-----|----------|-------------|------------|
| CVE-2024-11079 | Low | Hostvars bypass unsafe content protections, enabling arbitrary code execution via templated content | Upgrade to ansible-core >= 2.16.14, 2.17.7, or 2.18.1 |
| CVE-2024-8775 | Medium | Vault-encrypted variables exposed in plaintext via `include_vars` without `no_log` | Add `no_log: true` to all secret-handling tasks |
| CVE-2025-14010 | Medium | community.general exposes Keycloak credentials in verbose output | Upgrade to community.general >= 12.0.0 (or 11.4.1 / 10.7.6), i.e. the ansible package >= 12.2.0 |
| CVE-2025-49520 | High | EDA authenticated argument injection in Git URL (command execution) | Patch AAP/EDA |
| CVE-2025-49521 | High | EDA template injection via Git branch/refspec (command execution) | Patch AAP/EDA |

Checked 2026-09-10: [CVE-2026-16493](https://access.redhat.com/security/cve/cve-2026-16493)
is a high-severity collection-install argument injection, missed by the role-install fix for
CVE-2026-11332. Review git sources in `requirements.yml`; use trusted Galaxy/Automation Hub
sources and the vendor's fixed build. The retrieved vendor record does not establish an upstream
fixed-version range, so do not assume the target pin alone proves remediation.
