#!/usr/bin/env bash
# halcyon build stage 1 — base external repos.
#
# Repo lifecycle policy (bazzite pattern + TODO "remove non-fedora repos
# after use"): third-party repos are enabled ONLY inside the stage that
# consumes them and disabled immediately after; 80-finalize.sh deletes every
# leftover repo file. This stage only sets up the two repos that several
# stages share:
#   - RPM Fusion (steam, media, gaming). Its NVIDIA packages are EXCLUDED
#     here — this is the ublue-os/akmods partition: NVIDIA userland/modules
#     come from negativo17 ONLY, so the solver can never pull the
#     conflicting RPM Fusion nvidia chain (xorg-x11-drv-nvidia →
#     nvidia-kmod → akmod-nvidia).
#   - negativo17 fedora-nvidia (NVIDIA userland matching the p03 modules).
#
# COPRs and vendor repos (lionheartp, sneexy, ublue-os/packages, catpieleaf,
# terra, vscode, brave) are handled per-use in their own stages.
set -euo pipefail
echo "::group::01-repos — base external repos"
dnf5 -y install dnf5-plugins
# RPM Fusion (keys ship in the release RPMs; --nogpgcheck per RPM Fusion practice)
dnf5 -y --nogpgcheck install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y install rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data || true
# NVIDIA exclusion on every RPM Fusion repo file (akmods partition)
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
  grep -q '^excludepkgs=' "${f}" || \
    echo "excludepkgs=xorg-x11-drv-nvidia* akmod-nvidia kmod-nvidia* nvidia-settings nvidia-modprobe nvidia-persistenced nvidia-driver-NVML" >> "${f}"
done
# negativo17 NVIDIA userland — the only NVIDIA source in this image
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
echo "::endgroup::"
