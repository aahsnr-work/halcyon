#!/usr/bin/env bash
# halcyon build stage 4 — devtools: Fedora-available former-brew formulas
# (the rest land via halcyon-packages; brew pipeline retired — MIGRATION §8.7)
set -euo pipefail
echo "::group::40-devtools — Fedora brew-formula replacements + build base"
dnf5 -y install atuin bat btop cava chafa direnv eza fzf gnuplot ripgrep \
  tealdeer uv fd-find gcc perl jq python3
# chezmoi (not in Fedora) — pinned upstream binary
CZ_VER="$(curl -fsSL https://api.github.com/repos/twpayne/chezmoi/releases/latest | jq -r .tag_name | tr -d v)"
curl -fsSL --retry 5 "https://github.com/twpayne/chezmoi/releases/download/v${CZ_VER}/chezmoi_${CZ_VER}_linux_amd64.tar.gz" \
  | tar -xz -C /usr/local/bin chezmoi
chmod 0755 /usr/local/bin/chezmoi
echo "::endgroup::"
