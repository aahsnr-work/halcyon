#!/usr/bin/env bash
# halcyon build stage 6 — devtools: the former 22-formula brew Brewfile as
# Fedora RPMs (MIGRATION §8.7; the rest land via halcyon-packages later).
# chezmoi comes from the official Fedora repo (2.72 in F44).
set -euo pipefail
echo "::group::40-devtools — brew-formula replacements (Fedora RPMs)"
dnf5 -y install \
  atuin bat btop cava chafa direnv dust eza fd-find fzf gnuplot \
  lazygit pandoc ripgrep starship tealdeer uv yazi zellij \
  chezmoi \
  gcc perl jq python3
echo "::endgroup::"

# ---------------------------------------------------------------------------
# TODO(user): bun, pixi, opencode publish no Fedora RPMs — add their
# upstream-binary wrapper installs HERE (monorepo type-B specs replace this
# later). Pattern: resolve the latest release via the GitHub API, download
# with --retry, verify the sha256 the release publishes, install to
# /usr/local/bin. Upstreams:
#   bun      https://github.com/oven-sh/bun/releases
#   pixi     https://github.com/prefix-dev/pixi/releases
#   opencode https://github.com/sst/opencode/releases
# ---------------------------------------------------------------------------
