#!/usr/bin/env bash
# halcyon build stage 2 — prune the Bazzite GNOME/desktop set
# (equivalent of the old removals.yml Step B + guarded-removals + footprint)
set -euo pipefail
echo "::group::02-prune — GNOME removal (removals.yml Step B)"
dnf5 -y --allowerasing remove \
  nautilus-gsconnect gnome-shell-extension-gsconnect gnome-shell-extension-user-theme \
  gnome-search-yafti gnome-rounded-blur firewall-config \
  ibus-mozc ibus-pinyin ibus-table-chinese-cangjie ibus-table-chinese-quick \
  inputplumber steamos-manager-powerstation jupiter-fan-control jupiter-hw-support-btrfs \
  galileo-mura steamdeck-dsp powerbuttond vpower sdgyrodsu hid-replay \
  steamdeck-backgrounds steamdeck-gnome-presets \
  waydroid fastfetch \
  firefox firefox-langpacks \
  gnome-shell mutter gdm gnome-session gnome-session-wayland-session nautilus ptyxis \
  gnome-control-center gnome-settings-daemon gjs xdg-desktop-portal-gnome
dnf5 -y autoremove
echo "::endgroup::"
echo "::group::02-prune — guarded removals + footprint (existing scripts)"
bash /tmp/build.d/scripts/guarded-removals.sh
bash /tmp/build.d/scripts/file-footprint.sh
bash /tmp/build.d/scripts/gnome-extensions.sh
bash /tmp/build.d/scripts/fonts-cleanup.sh
echo "::endgroup::"
