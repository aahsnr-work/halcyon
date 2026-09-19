#!/usr/bin/env bash
# halcyon build stage 3 — core + desktop + gaming + apps (one repo class per call)
set -euo pipefail
echo "::group::10-packages — core + desktop + gaming + apps"
# --- core.yml set (Fedora) ---
dnf5 -y install accountsservice bleachbit bluez-tools brightnessctl cargo cmake \
  cronie curl ddcutil distrobox fail2ban file-roller flatseal fontconfig gcc-c++ \
  git gsettings-desktop-schemas gtk4-layer-shell gzip hunspell hunspell-en \
  hunspell-en-GB hunspell-en-US ImageMagick imv inotify-tools jq liberation-fonts \
  libinput-utils logrotate lynis man-db mpv ninja-build pipx pkgconf-pkg-config \
  plymouth plymouth-theme-spinner podman podman-sequoia policycoreutils-python-utils \
  python3-xlib qt5ct slurp sqlite swappy transmission-gtk udiskie \
  xdg-desktop-portal xdg-user-dirs xdg-user-dirs-gtk xhost xorg-x11-server-Xwayland xorg-x11-xauth \
  zathura-plugins-all zsh grim go pymol fastfetch fonts-filesystem setroubleshoot-plugins \
  go \
  zathura zathura-pdf-poppler zathura-plugins-all zsh grim go pymol fastfetch \
  fonts-filesystem setroubleshoot-plugins xorg-x11-xauth setroubleshoot-server setools-console udica \
  jetbrains-mono-fonts google-noto-emoji-fonts just || true
# --- desktop stack (lionheartp COPR; MIGRATION §8.4) ---
dnf5 -y install cliphist hyprland-git hyprland-guiutils hyprpwcenter hyprshutdown \
  noctalia-git noctalia-greeter-git nwg-look qt6ct xdg-desktop-portal-hyprland \
  greetd kitty kitty-shell-integration kitty-terminfo gnome-keyring gnome-tweaks \
  papers papirus-icon-theme thunar thunar-archive-plugin thunar-media-tags-plugin \
  thunar-vcs-plugin thunar-volman
# --- gaming (RPM Fusion + Fedora + Terra; MIGRATION §5.1) ---
dnf5 -y install steam lutris gamescope mangohud gamemode input-remapper usbip \
  evtest ydotool distrobox
dnf5 -y install terra-gamescope terra-gamescope-libs terra-mangohud scx-scheds \
  scx-tools umu-launcher umu-wrapper bazzite-portal
dnf5 -y install bazaar
# --- apps (vendor repos + monorepo/COPR transitional) ---
dnf5 -y install code brave-browser zen-browser emacs-pgtk neovim nodejs npm tree-sitter-cli
dnf5 -y install zed || true          # terra; tolerate transient repo issues
dnf5 -y install bazaar || true
echo "::endgroup::"

# brave-origin — skip-unavailable semantics (apps.yml)
dnf5 -y install brave-origin || true   # brave-origin: skip-unavailable (apps.yml semantics)

# NerdFontsSymbolsOnly — pinned direct download (replaces the bluebuild fonts module entry)
NF_VER=3.4.0
mkdir -p /usr/share/fonts/nerd-fonts-symbols-only
curl -fsSL --retry 5 "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NF_VER}/NerdFontsSymbolsOnly.tar.xz" \
  | tar -xJ -C /usr/share/fonts/nerd-fonts-symbols-only --strip-components=1 --wildcards '*/SymbolsNerdFont-Regular.ttf' '*/SymbolsNerdFontMono-Regular.ttf' || \
  echo "  WARN  nerd-fonts symbols-only download failed — non-fatal"
