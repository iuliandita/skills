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

## Nonstandard service port

For an HTTP service moved to TCP 8443, inspect the current SELinux mapping and active firewalld
zone before changing either layer:

```bash
semanage port -l | grep -w http_port_t
firewall-cmd --get-active-zones
ss -ltnp
```

Use `-a` only when the port has no mapping. If it already has a different type, review the owner
before intentionally changing it with `-m`.

```bash
: "${SERVICE_ZONE:?set SERVICE_ZONE to the active zone for the service interface}"
sudo semanage port -a -t http_port_t -p tcp 8443
sudo firewall-cmd --permanent --zone="$SERVICE_ZONE" --add-port=8443/tcp
sudo firewall-cmd --reload

semanage port -l | grep -E '^http_port_t[[:space:]].*8443'
firewall-cmd --zone="$SERVICE_ZONE" --query-port=8443/tcp
ss -ltnp | grep ':8443'
curl --fail --silent --show-error http://127.0.0.1:8443/  # use https:// when the service terminates TLS
```

Choose `SERVICE_ZONE` from the active-zone inspection for the service's interface. Keep SELinux
enforcing and expose only the required port.

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
