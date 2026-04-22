# Security and Updates

Use this reference for SELinux, firewalld, package signing, update cadence, FIPS-adjacent checks,
and other security-sensitive default behavior.

## SELinux first-pass

```bash
getenforce
sestatus
ausearch -m avc -ts recent 2>&1 || true
semanage boolean -l 2>&1 | head -40 || true
```

## firewalld first-pass

```bash
firewall-cmd --get-active-zones 2>&1 || true
firewall-cmd --list-all 2>&1 || true
firewall-cmd --list-all-zones 2>&1 || true
```

## Update principles

- Fedora updates move fast. Third-party repos lag.
- RHEL-family updates are slower but shaped by support policy and repo enablement.
- Package signing failures are evidence. Do not bypass them casually. Do not recommend `--nogpgcheck`, `gpgcheck=0`, or `repo_gpgcheck=0` except in a tightly scoped emergency diagnostic with an explicit risk callout and rollback plan.
- FIPS or compliance-sensitive hosts need extra caution around crypto, kernels, and unsupported repos.

## SELinux rules of thumb

- relabel when labels are wrong
- use booleans when the policy already models the intended behavior
- generate custom policy only after you understand the denial
- `setenforce 0` is for temporary diagnosis, not a permanent fix
