#!/usr/bin/env bash
# halcyon desktop.yml post-install verification (prompt §5.2)
set -euo pipefail
rm -f /etc/yum.repos.d/_copr*lionheartp* /etc/yum.repos.d/_copr_lionheartp_Hyprland.repo   # full T17 hygiene (§1.19d)
rpm -q hyprland-git noctalia-git greetd tuigreet xdg-desktop-portal-hyprland
# -git stack ABI consistency guard (§1.15):
ldd /usr/bin/Hyprland 2>/dev/null | grep -i 'not found' && { echo 'ERROR: hyprland -git ABI break'; exit 1; } || true
# provenance guard: hyprland-git's companion libs must come from the COPR, not
# Fedora stable. dnf5 history/from-repo tracking is unavailable on rpm-ostree
# images (repoquery --installed --qf '%{reponame}' prints empty), so provenance
# is checked via the RPM VENDOR field — COPR builds stamp
# "Fedora Copr - user lionheartp" (verified against the COPR repodata 2026-09-17).
rpm -q --qf '%{name} (vendor: %{VENDOR})\n' \
  hyprland-git noctalia-git hyprgraphics hyprlang aquamarine hyprcursor hyprutils || true
for p in hyprgraphics hyprlang aquamarine hyprcursor; do
  rpm -q "$p" >/dev/null 2>&1 || continue
  vendor="$(rpm -q --qf '%{VENDOR}' "$p")"
  echo "$vendor" | grep -qi 'lionheartp' \
    || { echo "ERROR: $p vendor '$vendor' — resolved outside the lionheartp COPR; mixed -git stack risk (§1.15). Remediation: raise the COPR repo priority (dnf5 config-manager setopt '*lionheartp*'.priority=1) between copr-enable and install, via two dnf module entries + interleaved script."; exit 1; }
done
test -f /usr/share/wayland-sessions/hyprland.desktop
id greetd    # Fedora greetd sysusers (spec-verified §1.18); hard gate for the config.toml user
dnf5 repolist --enabled | grep -Ei 'lionheartp' && { echo 'ERROR: COPR still enabled'; exit 1; } || true
