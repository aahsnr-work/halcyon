#!/usr/bin/env bash
# halcyon build stage 2 — p03 kernel + NVIDIA open (MIGRATION.md §4, staged K1)
set -euo pipefail
echo "::group::02-kernel — p03 + nvidia-open"
dnf5 -y install kernel-p03 kernel-p03-nvidia-open
# swap out the stock Fedora kernel
dnf5 -y --allowerasing remove kernel kernel-core kernel-modules kernel-modules-extra || true
# VERIFY (MIGRATION §4.4): p03 keeps SELinux; the running system is checked at boot
grep -q CONFIG_SECURITY_SELINUX /usr/lib/modules/*/config || \
  echo "  WARN  CONFIG_SECURITY_SELINUX not found in p03 kernel config — verify at boot"
echo "::endgroup::"
