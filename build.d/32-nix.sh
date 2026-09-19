#!/usr/bin/env bash
# halcyon build stage — nix (winter pattern, identical to main's nix.yml:
# https://github.com/fu5ha/winter recipes/modules/nix.yaml — the same files
# ship via the static tree: usr/lib/tmpfiles.d/nix.conf,
# etc/profile.d/01-nix-resolve-home-env.sh, systemd/{var-nix,nix.mount}).
set -euo pipefail
echo "::group::32-nix — nix multi-user install"
dnf5 -y install nix nix-daemon
systemctl enable nix-daemon 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/nix-daemon.service /usr/lib/systemd/system/multi-user.target.wants/nix-daemon.service
# /nix is a bind mount of /var/nix (var-nix.service creates it, nix.mount
# binds it) — enabled in 50-system.sh like main's services.yml did.
echo "::endgroup::"
