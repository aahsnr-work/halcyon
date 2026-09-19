#!/usr/bin/env bash
# halcyon build stage 1 — repositories (MIGRATION.md §5.1)
set -euo pipefail
echo "::group::01-repos — enable external repos"
dnf5 -y install dnf5-plugins
# RPM Fusion (keys ship in the release RPMs; --nogpgcheck per RPM Fusion practice)
dnf5 -y --nogpgcheck install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y install rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data || true
# negativo17 NVIDIA userland (MIGRATION §4.3 K1: the kernel modules come
# prebuilt from the kernel-p03 COPR; userland must be the same 615.71.09
# driver line — this is the repo rakuos-base uses for its NVIDIA stack)
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
# Microsoft VS Code
cat > /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
# Brave
cat > /etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
# Terra (zed, terra-gamescope i686, terra-mangohud i686, scx, umu, bazzite-portal)
curl -fsSL "https://raw.githubusercontent.com/terrapkg/subatomic-repos/main/terra.repo" \
  -o /etc/yum.repos.d/terra.repo
echo "excludepkgs=zlib" >> /etc/yum.repos.d/terra.repo   # terra zlib must not shadow Fedora (apps.yml exclude)
# transitional COPRs (monorepo replaces these — MIGRATION.md §8)
dnf5 -y copr enable -y lionheartp/Hyprland
dnf5 -y copr enable -y sneexy/zen-browser
dnf5 -y copr enable -y ublue-os/packages
# p03 kernel + prebuilt nvidia-open modules (MIGRATION §4.2 Stage K1; Stage K2
# moves the build into halcyon-packages)
dnf5 -y copr enable -y catpieleaf/kernel-p03
echo "::endgroup::"
