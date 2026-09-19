#!/usr/bin/env bash
# halcyon build stage 2 — kernel + NVIDIA via the ublue akmods pattern
# (MIGRATION.md §4.2 deviation: p03 deferred; stock Fedora kernel at the
# akmods-pinned version + prebuilt nvidia-open modules from
# ghcr.io/ublue-os/akmods{,-nvidia-open}:main-44)
set -euo pipefail
echo "::group::02-kernel — remove stock kernel, install akmods-pinned kernel + nvidia"
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
  rpm --erase "$pkg" --nodeps || true
done

KERNEL_VERSION="$(find /tmp/kernel-rpms/kernel-core-*.rpm -prune -printf "%f\n" | sed 's/kernel-core-//g;s/.rpm//g')"
echo "  INFO  akmods-pinned kernel version: ${KERNEL_VERSION}"

# shim kernel-install plugins (05-rpmostree/50-dracut error during bootc builds)
cd /usr/lib/kernel/install.d \
  && mv 05-rpmostree.install 05-rpmostree.install.bak \
  && mv 50-dracut.install 50-dracut.install.bak \
  && printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install \
  && printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install \
  && chmod +x 05-rpmostree.install 50-dracut.install

KERNEL_RPMS=(
  "/tmp/kernel-rpms/kernel-${KERNEL_VERSION}.rpm"
  "/tmp/kernel-rpms/kernel-core-${KERNEL_VERSION}.rpm"
  "/tmp/kernel-rpms/kernel-modules-${KERNEL_VERSION}.rpm"
  "/tmp/kernel-rpms/kernel-modules-core-${KERNEL_VERSION}.rpm"
  "/tmp/kernel-rpms/kernel-modules-extra-${KERNEL_VERSION}.rpm"
)
dnf5 -y install "${KERNEL_RPMS[@]}" /tmp/akmods-rpms/*.rpm

# restore kernel-install plugins
cd /usr/lib/kernel/install.d \
  && mv -f 05-rpmostree.install.bak 05-rpmostree.install \
  && mv -f 50-dracut.install.bak 50-dracut.install
cd -

# versionlock the kernel to the akmods-pinned version
dnf5 versionlock add kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

# initramfs for the pinned kernel
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f \
  "/lib/modules/${KERNEL_VERSION}/initramfs.img" >/dev/null
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
echo "::endgroup::"
