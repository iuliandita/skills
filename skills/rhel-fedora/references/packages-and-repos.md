# Packages and Repos

Use this reference when the problem is package state, repo config, package provenance, module
streams, local RPMs, or third-party repo drift.

## Gather package facts first

```bash
dnf --version 2>&1 || yum --version 2>&1 || true
dnf repolist --enabled 2>&1 || yum repolist enabled 2>&1 || true
dnf repoquery package_name 2>&1 || true
dnf info package_name 2>&1 || true
dnf module list --enabled 2>&1 || true
rpm -q package_name
rpm -qi package_name
rpm -V package_name
rpm -qa | sort | head -50
```

## Package principles

- Prefer distro repos first, then vendor repos, then EPEL or COPR, then manual RPMs.
- A local `.rpm` install is not proof that the repo state is healthy.
- `rpm -Uvh` bypasses DNF's dependency planning. Use it only when you know why.
- On RHEL, package absence often means the right repo is not enabled.
- On Fedora, package weirdness often means third-party repo lag after a release bump.

## Repo sanity checks

```bash
grep -R "^\[\|^enabled=\|^baseurl=\|^metalink=" /etc/yum.repos.d/ 2>&1 || true
dnf repolist all 2>&1 || true
dnf config-manager --dump 2>&1 || true
subscription-manager repos --list-enabled 2>&1 || true
```

Check for:
- duplicate vendor repos
- dead mirrorlists or metalinks
- release RPMs left behind from old versions
- CRB / CodeReady Builder / PowerTools mismatch
- EPEL installed where the base distro or support policy does not want it

## Modules and AppStream

Module streams are a classic source of weird package solver behavior.

```bash
dnf module list package_name 2>&1 || true
dnf module info package_name:stream 2>&1 || true
dnf module reset package_name 2>&1 || true
```

Rules:
- verify whether a module is actually in play before resetting anything
- document the active stream before changing it
- be careful with PostgreSQL, Node.js, PHP, and container tools on older enterprise lanes

## Local RPM handling

Preferred order:
1. inspect the package
2. verify signature, signing-key fingerprint, and origin before trusting it
3. install with DNF so dependencies are resolved

```bash
rpm -qpR ./package.rpm
rpm -qpi ./package.rpm
rpm -K ./package.rpm
rpm -qi gpg-pubkey-* 2>&1 || true
dnf install ./package.rpm 2>&1 || true
```

For third-party release RPMs and repo keys, verify the key fingerprint and source before importing or trusting the repo. `rpm -K` tells you a package is signed, not that the signer is the one you intended to trust.

## Fedora-specific notes

- COPR is convenient, not neutral. Treat it like a trust boundary.
- Fedora multimedia, Steam, and proprietary-driver work often depends on RPM Fusion state; verify it before debugging package availability or akmods.
- `updates-testing` is for targeted use, not for permanent random enablement.
- Release upgrades often expose lagging third-party repos first.

## Enterprise-lane notes

- RHEL may need `subscription-manager` plus CRB enablement before package names make sense.
- Rocky and Alma often pair with EPEL, but package advice still needs repo provenance.
- Oracle Linux may provide the package under a different repo or kernel lane expectation.
- Amazon Linux is its own packaging lane. Avoid blind copy-paste from generic RHEL docs.
