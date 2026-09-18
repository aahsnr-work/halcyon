#!/usr/bin/env bash
# p03-verify.sh — build-time gates for the P03 kernel integration
# (kernel-p03 from COPR catpieleaf/kernel-p03 + kernel-p03-nvidia-open)
set -euo pipefail

echo "::group::p03-verify — P03 kernel packages"
rpm -q kernel-p03 >/dev/null || { echo "  FAIL  kernel-p03 not installed"; echo "::endgroup::"; exit 1; }
p03_ver="$(rpm -q --qf '%{VERSION}-%{RELEASE}' kernel-p03)"
echo "  PASS  kernel-p03-${p03_ver} installed"

rpm -q kernel-p03-nvidia-open >/dev/null || { echo "  FAIL  kernel-p03-nvidia-open not installed"; echo "::endgroup::"; exit 1; }
nv_ver="$(rpm -q --qf '%{VERSION}' kernel-p03-nvidia-open)"
echo "  PASS  kernel-p03-nvidia-open installed (kernel ${nv_ver})"
echo "::endgroup::"

echo "::group::p03-verify — modules on disk"
krel="$(rpm -q --qf '%{VERSION}-%{RELEASE}' kernel-p03)"
if test -d "/usr/lib/modules/${krel}"; then
  echo "  PASS  /usr/lib/modules/${krel} present"
else
  echo "  FAIL  /usr/lib/modules/${krel} missing — kernel install scriptlets did not run"
  echo "::endgroup::"
  exit 1
fi

nv_ko="$(find "/usr/lib/modules/${krel}" -name 'nvidia*.ko*' 2>/dev/null | head -1)"
if test -n "${nv_ko}"; then
  echo "  PASS  nvidia-open modules present (${nv_ko##*/})"
else
  echo "  FAIL  no nvidia modules found for kernel ${krel}"
  echo "::endgroup::"
  exit 1
fi

if test -f "/usr/lib/modules/${krel}/vmlinuz"; then
  echo "  PASS  vmlinuz present"
else
  echo "  FAIL  vmlinuz missing for ${krel}"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "::group::p03-verify — Fedora kernel removed"
for gone in kernel kernel-core kernel-modules kernel-devel kmod-nvidia; do
  if rpm -q "${gone}" >/dev/null 2>&1; then
    echo "  FAIL  ${gone} still installed — must be removed with the P03 switch"
    echo "::endgroup::"
    exit 1
  else
    echo "  PASS  ${gone} absent"
  fi
done
echo "::endgroup::"

echo "::group::p03-verify — NVIDIA userland match"
nvidia_userland="$(rpm -q --qf '%{VERSION}' nvidia-driver-libs 2>/dev/null | head -1 || true)"
if [ "${nvidia_userland}" = "${nv_ver}" ]; then
  echo "  PASS  NVIDIA userland ${nvidia_userland} matches kernel modules"
else
  echo "  FAIL  userland ${nvidia_userland:-absent} != module driver ${nv_ver}"
  echo "::endgroup::"
  exit 1
fi

if test -x /usr/bin/nvidia-smi; then
  echo "  PASS  nvidia-smi present"
else
  echo "  FAIL  nvidia-smi missing (userland incomplete)"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "::group::p03-verify — Secure Boot artifacts"
if test -f /etc/kernel/certs/p03-kernel/mok.der; then
  echo "  PASS  /etc/kernel/certs/p03-kernel/mok.der present (user enrolls via mokutil)"
else
  echo "  FAIL  p03 MOK cert missing — Secure Boot systems will not boot the signed kernel"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "--- p03-verify complete — all checks passed ---"
