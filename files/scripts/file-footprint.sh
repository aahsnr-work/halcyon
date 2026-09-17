#!/usr/bin/env bash
# halcyon Step D — file footprint + service/justfile pruning (prompt §5.1)
set -uo pipefail
# Waydroid set (§1.12)
rm -f /etc/default/waydroid-launcher \
  /usr/bin/waydroid-launcher /usr/bin/waydroid-choose-gpu \
  /usr/libexec/waydroid-container-start /usr/libexec/waydroid-container-stop \
  /usr/libexec/waydroid-container-restart /usr/libexec/waydroid-fix-controllers \
  /usr/share/applications/waydroid-container-restart.desktop \
  /usr/share/polkit-1/actions/org.bazzite.waydroid.policy \
  /usr/share/polkit-1/rules.d/30-waydroid.rules
rm -f /usr/share/applications/Waydroid.desktop /usr/share/applications/Waydroid-create.desktop \
  /usr/share/applications/Waydroid-info.desktop 2>/dev/null || true
rm -rf /usr/share/applications/waydroid 2>/dev/null || true
# Bling set (§1.6)
rm -f /usr/libexec/bazzite-bling-fastfetch \
  /usr/share/ublue-os/bazzite/fastfetch.jsonc \
  /usr/share/bazzite-cli/bling.sh /usr/share/bazzite-cli/bling.fish \
  /etc/profile.d/bazzite-neofetch.sh
# excise the bazzite-cli recipe block from 80-bazzite.just
# (real file: header comment is immediately followed by the recipe's own
# [group("development")] line; the block ends at the NEXT [group( after the
# recipe body — verified against ublue-os/bazzite main 2026-09-17)
JUSTFILE=/usr/share/ublue-os/just/80-bazzite.just
if [ -f "${JUSTFILE}" ] && grep -q 'Enable a Bluefin-style CLI experience' "${JUSTFILE}"; then
  awk '
    /^# Enable a Bluefin-style CLI experience/ {skip=1; groups=0; body=0}
    skip {
      if ($0 ~ /^\[group\(/) {
        groups++
        if (body > 0 || groups >= 2) { skip=0; print; next }
        next
      }
      if ($0 !~ /^#/ && $0 !~ /^[[:space:]]*$/) body++
      next
    }
    {print}
  ' "${JUSTFILE}" >"${JUSTFILE}.new"
  mv "${JUSTFILE}.new" "${JUSTFILE}"
  echo 'excised bazzite-cli recipe from 80-bazzite.just'
fi
# GNOME config footprint (§1.9)
rm -f /etc/dconf/db/distro.d/00-bazzite-desktop-silverblue-global \
  /etc/dconf/db/distro.d/01-bazzite-desktop-silverblue-folders \
  /etc/dconf/db/distro.d/locks/00-bazzite-desktop-silverblue-global-lock
rm -f /usr/share/glib-2.0/schemas/*bazzite*-silverblue-*.gschema.override
# (broader than the prompt's zz0-0[0-4] pattern: build 12 revealed a 6th variant
#  — zz0-20-bazzite-nvidia-silverblue-global — NOTES.md §5)
rm -rf /usr/share/gnome-background-properties
rm -f /usr/share/backgrounds/default.jxl /usr/share/backgrounds/default-dark.jxl
rm -f /usr/lib/systemd/system/dconf-update.service
rm -f /usr/share/ublue-os/motd/tips/30-gnome.md \
  /usr/share/applications/gnome-ssh-askpass.desktop \
  /usr/share/ublue-os/firefox-config/03-bazzite-gnome.js
rm -f /etc/skel/.config/gnome-initial-setup-done
rm -rf /etc/skel/.local/share/org.gnome.Ptyxis
if [ -f /etc/xdg/mimeapps.list ]; then
  sed -i '/org\.gnome\./d' /etc/xdg/mimeapps.list || true
fi
# KEEP: /etc/skel/.var/app/com.ranfdev.DistroShelf/, /usr/bin/distroshelf-helper,
#       /etc/xdg/mineapps.list (DistroShelf flatpak retained — §1.16)
# SDDM/autologin
rm -rf /etc/sddm.conf.d
# dangling service hygiene (all || true)
systemctl disable inputplumber.service powerstation.service jupiter-fan-control.service \
  vpower.service jupiter-biosupdate.service jupiter-controller-update.service \
  sdgyrodsu.service waydroid-container.service bazzite-autologin.service \
  dconf-update.service 2>/dev/null || true
systemctl --global disable sdgyrodsu.service steamos-powerbuttond.service 2>/dev/null || true
rm -f /usr/lib/systemd/user/gamescope-session-plus@ogui-steam.service.wants/steamos-powerbuttond.service
# prune dangling wants symlinks
find /etc/systemd /usr/lib/systemd -name '*.wants' -type d -exec find {} -xtype l -delete \; 2>/dev/null || true
# Justfiles: delete removed-subsystem recipes + their import lines
for jf in 82-bazzite-waydroid.just 91-bazzite-decky.just 95-bazzite-deck-session.just 90-bazzite-de.just; do
  rm -f "/usr/share/ublue-os/just/${jf}"
  sed -i "\|${jf}|d" /usr/share/ublue-os/justfile 2>/dev/null || true
done
rm -f /usr/share/ublue-os/just/*deck-variant*.just 2>/dev/null || true
# report any other recipes referencing removed subsystems (manual follow-up list;
# KEEP 82-bazzite-apps.just / 94-bazzite-protonplus.just / 95-bazzite-nvidia.just)
grep -l 'gnome-shell\|gdm\|sddm\|waydroid\|decky' /usr/share/ublue-os/just/*.just 2>/dev/null |
  tee -a /tmp/halcyon-inventory.txt || true
# steamos-manager: point the stale desktop target at Hyprland
PLATFORM_TOML=/usr/share/steamos-manager/platform.toml
if [ -f "${PLATFORM_TOML}" ] && grep -q 'desktop = "gnome.desktop"' "${PLATFORM_TOML}"; then
  sed -i 's/desktop = "gnome.desktop"/desktop = "hyprland.desktop"/' "${PLATFORM_TOML}"
fi
grep -q '^SHELL=/bin/bash' /etc/default/useradd || sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
exit 0
