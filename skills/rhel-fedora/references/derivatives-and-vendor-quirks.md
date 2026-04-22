# Derivatives and Vendor Quirks

Use this reference when the distro family matters more than the package name.

## Fedora

- fast-moving
- short support window
- COPR and third-party repos are common
- release bumps often expose repo lag first

## CentOS Stream

- sits ahead of the next RHEL point release
- useful for previewing enterprise changes
- not a drop-in mental model for supported RHEL production guidance

## RHEL

- support tooling and entitlement matter
- package absence often means repo access or subscription issues
- major-version upgrades should follow Red Hat's documented path, usually `leapp`

## Rocky Linux and AlmaLinux

- close to RHEL in package shape
- do not rely on RHEL subscription-manager guidance
- minor versions rotate into vault / archival paths as new ones land
- EPEL is common, but still a deliberate support-boundary choice

## Oracle Linux

- check RHCK vs UEK immediately
- UEK can change driver, storage, container, and support assumptions
- Oracle docs can differ from generic RHEL advice even when package names look familiar

## Amazon Linux 2023

- AWS-shaped distro, not generic clone behavior
- cloud-init and image defaults matter a lot
- package naming and repo expectations can differ from RHEL examples
- separate AL2023 from old Amazon Linux 2 advice before doing anything else

## Rule of thumb

If the distro is not clearly one of the lanes above, read `/etc/os-release`, check the enabled
repos, and identify whether the vendor expects Fedora-style speed, RHEL-style support policy, or
something cloud-specific before prescribing a fix.
