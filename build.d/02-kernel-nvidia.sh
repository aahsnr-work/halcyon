#!/usr/bin/env bash
# halcyon build stage 2 — kernel + NVIDIA open via the ublue akmods prebuilt
# RPMs (the p03 kernel is deferred; MIGRATION.md §4.2 Stage K2 covers it later).
# The akmods image pins the exact Fedora kernel release its modules were built
# against — installing both keeps kernel and module versions matched.
set -euo pipefail
echo "::group::02-kernel-nvidia — kernel pin + akmods + nvidia-open"
ls /tmp/kernel-rpms/ /tmp/akmods-rpms/
# pin the kernel to the release the akmods were built against
dnf5 -y install /tmp/kernel-rpms/kernel*.rpm
# NVIDIA open kernel modules (prebuilt for that kernel release)
dnf5 -y install /tmp/akmods-rpms/*.rpm
# NVIDIA userland from RPM Fusion
dnf5 -y install xorg-x11-drv-nvidia
# drop the now-superseded stock kernel if it differs from the pinned one
dnf5 -y --allowerasing remove kernel kernel-core kernel-modules kernel-modules-extra || true
echo "::endgroup::"
