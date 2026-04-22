# Base Linux and CLI

Use this reference when the task is basic host inspection and you need the RPM-family-native tools.

## Useful commands

```bash
cat /etc/os-release
rpm -qa | wc -l
rpm -q package_name
rpm -qi package_name
rpm -V package_name
repoquery --whatprovides /path/to/file 2>&1 || true
dnf repolist --enabled 2>&1 || true
grubby --default-kernel 2>&1 || true
restorecon -Rv /path 2>&1 || true
semanage fcontext -l 2>&1 | head -40 || true
```

## Notes

- `rpm -V` is great when files disappeared or permissions look wrong.
- `repoquery` beats guessing which package owns a capability.
- `restorecon` fixes labels; it does not change policy.
