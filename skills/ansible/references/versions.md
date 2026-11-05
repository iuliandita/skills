---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "ansible-core"
    version: "2.21.4"
    source: "https://docs.ansible.com/projects/ansible-core/devel/reference_appendices/release_and_maintenance.html"
  - tool: "ansible (community package)"
    version: "14.4.0"
    source: "https://pypi.org/project/ansible/"
  - tool: "molecule"
    version: "26.9.0"
    source: "https://pypi.org/project/molecule/"
  - tool: "ansible-lint"
    version: "26.9.0"
    source: "https://pypi.org/project/ansible-lint/"
  - tool: "ansible-navigator"
    version: "26.9.0"
    source: "https://pypi.org/project/ansible-navigator/"
  - tool: "ansible-builder"
    version: "3.1.1"
    source: "https://pypi.org/project/ansible-builder/"
  - tool: "AWX"
    version: "24.6.1"
    source: "https://github.com/ansible/awx/releases"
  - tool: "AAP"
    version: "2.7"
    source: "https://access.redhat.com/support/policy/updates/ansible-automation-platform"
---

# Ansible target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages.

| Tool | Version | Source | Notes |
|---|---|---|---|
| ansible-core | 2.21.4 | <https://docs.ansible.com/projects/ansible-core/devel/reference_appendices/release_and_maintenance.html> | Current stable, Python 3.12+ controller. Verify managed-node Python support and branch EOL in the support matrix before pinning |
| ansible (community package) | 14.4.0 | <https://pypi.org/project/ansible/> | Depends on ansible-core 2.21 |
| molecule | 26.9.0 | <https://pypi.org/project/molecule/> | CalVer |
| ansible-lint | 26.9.0 | <https://pypi.org/project/ansible-lint/> | CalVer |
| ansible-navigator | 26.9.0 | <https://pypi.org/project/ansible-navigator/> | CalVer |
| ansible-builder | 3.1.1 | <https://pypi.org/project/ansible-builder/> | EE definition v3 |
| AWX | 24.6.1 | <https://github.com/ansible/awx/releases> | Last formal release Jul 2024; upstream AWX releases paused for a major refactor, devel branch active - track ansible/awx; awx-operator ~2.19.x still ships for K8s deploys. Verify current AWX/AAP release status before recommending a specific version or install path |
| AAP | 2.7 | <https://access.redhat.com/support/policy/updates/ansible-automation-platform> | Current stream; verify supported installation methods and patch builds in the vendor lifecycle documentation before deployment |
