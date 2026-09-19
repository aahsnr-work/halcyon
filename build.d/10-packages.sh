#!/usr/bin/env bash
# halcyon build stage 3 — core + desktop + gaming + apps (one repo class per
# transaction; COPRs/vendor repos enabled per-use and disabled immediately).
set -euo pipefail
echo "::group::10-packages — core + desktop + gaming + apps"
# --- core set (main core.yml parity: Fedora repos, weak deps off like the
# BlueBuild module had; the Hyprland COPR block below KEEPS weak deps — it
# needs them resolved, see the 2026 COPR weak-deps fix) ---
dnf5 -y --setopt=install_weak_deps=False group-install custom-environment || true
dnf5 -y --setopt=install_weak_deps=False install \
  accountsservice \
  bleachbit \
  bluez \
  bluez-libs \
  bluez-tools \
  brightnessctl \
  cargo \
  cmake \
  cronie \
  curl \
  ddcutil \
  distrobox fail2ban file-roller flatseal fontconfig \
  gcc-c++ git gsettings-desktop-schemas gtk4-layer-shell gzip hunspell \
  hunspell-en hunspell-en-GB hunspell-en-US ImageMagick imv inotify-tools \
  liberation-fonts libinput-utils logrotate lynis man-db mpv ninja-build \
  pipx pkgconf-pkg-config plymouth plymouth-theme-spinner podman \
  podman-sequoia policycoreutils-python-utils python3-xlib qt5ct slurp \
  sqlite swappy transmission-gtk udiskie xdg-desktop-portal xdg-user-dirs \
  xdg-user-dirs-gtk xorg-x11-server-Xorg xorg-x11-server-Xwayland \
  xorg-x11-xauth zathura zathura-pdf-poppler zathura-plugins-all zsh \
  setroubleshoot-server setroubleshoot-plugins setools-console udica \
  jetbrains-mono-fonts google-noto-emoji-fonts google-noto-color-emoji-fonts \
  go grim pymol fastfetch just fonts-filesystem

# --- hardware support the Bazzite base used to provide (fedora-bootc is
# bare; rakuos-base installs the same classes explicitly) ---
dnf5 -y install linux-firmware microcode_ctl amd-ucode-firmware amd-gpu-firmware \
  intel-gpu-firmware nvidia-gpu-firmware atheros-firmware realtek-firmware \
  iwlwifi-dvm-firmware iwlwifi-mvm-firmware \
  alsa-firmware alsa-sof-firmware alsa-ucm \
  NetworkManager-wifi wpa_supplicant \
  pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
  mesa-dri-drivers mesa-vulkan-drivers mesa-libEGL mesa-libGL \
  mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 mesa-libEGL.i686 mesa-libGL.i686
# --- desktop stack: lionheartp COPR per-use (MIGRATION §8.4); weak deps ON
dnf5 -y copr enable -y lionheartp/Hyprland
dnf5 -y install cliphist hyprland-git hyprland-guiutils hyprpwcenter \
  hyprshutdown noctalia-git noctalia-greeter-git nwg-look qt6ct \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  greetd kitty kitty-shell-integration kitty-terminfo gnome-keyring \
  gnome-tweaks papers papirus-icon-theme thunar thunar-archive-plugin \
  thunar-media-tags-plugin thunar-vcs-plugin thunar-volman
dnf5 -y copr disable -y lionheartp/Hyprland
# --- gaming (RPM Fusion + Fedora; terra bits live in 11-terra.sh).
# gamescope + mangohud come from Fedora now (terra-gamescope/-mangohud were
# retired upstream — verified live 2026-09-19); mangohud.i686 covers 32-bit
# overlays for Steam/Proton.
dnf5 -y install steam lutris gamescope mangohud mangohud.i686 gamemode \
  input-remapper usbip evtest ydotool distrobox steam-devices
# --- bazaar: ublue COPR per-use ---
dnf5 -y copr enable -y ublue-os/packages
dnf5 -y install bazaar || true
dnf5 -y copr disable -y ublue-os/packages
# --- apps: zen-browser (sneexy COPR per-use), vscode/brave (vendor repos
# per-use: written, used, disabled and deleted inside this stage) ---
dnf5 -y copr enable -y sneexy/zen-browser
dnf5 -y install zen-browser
dnf5 -y copr disable -y sneexy/zen-browser
install -Dm0644 /dev/null /etc/yum.repos.d/vscode.repo
cat >/etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
install -Dm0644 /dev/null /etc/yum.repos.d/brave-browser.repo
cat >/etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
dnf5 -y install code brave-browser emacs-pgtk neovim nodejs npm tree-sitter-cli
dnf5 -y install brave-origin || true # skip-unavailable semantics (apps.yml)
rm -f /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/brave-browser.repo
echo "::endgroup::"
