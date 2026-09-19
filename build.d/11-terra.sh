#!/usr/bin/env bash
# halcyon build stage 4 — Terra packages (USER-EDITABLE LIST).
#
# Every package here is installed from Terra, whatever its type. The Terra
# repos are enabled ONLY for this stage and disabled immediately after
# (repo lifecycle policy — see 80-finalize.sh for the final sweep).
#
# Ordering note: this stage runs after 10-packages.sh and BEFORE 30-prune.sh;
# the prune keeper checks expect terra-gamescope/scx-*/umu-launcher/
# bazzite-portal to be present by then. If you add packages with install
# ordering needs, keep that order in mind — some terra packages may be
# missing from earlier stages by design.
#
# Fonts parity (main fonts.yml) is included here: jetbrainsmono-nerd-fonts +
# nerdfontssymbolsonly-nerd-fonts exist only in Terra; the Fedora-side fonts
# (google-noto-*, jetbrains-mono-fonts, liberation) install in 10-packages.sh.
set -euo pipefail
echo "::group::11-terra — Terra packages"
FEDORA_MAJOR="$(rpm -E %fedora)"

# --- the list you edit -----------------------------------------------------
# NOTE: terra-gamescope/terra-mangohud no longer exist in Terra (verified
# live 2026-09-19) — Fedora 44 provides gamescope + mangohud directly, and
# 10-packages.sh installs them (incl. mangohud.i686 for 32-bit overlays).
TERRA_PKGS=(
  # desktop/gaming stack that main inherited from the Bazzite base
  zed
  scx-scheds scx-tools
  umu-launcher umu-wrapper
  bazzite-portal
  # fonts.yml parity (Terra-only nerd fonts)
  jetbrainsmono-nerd-fonts
  nerdfontssymbolsonly-nerd-fonts
)
# ---------------------------------------------------------------------------

dnf5 -y install --nogpgcheck \
  --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
  terra-release
# optional terra subrepos (mesa/multimedia) — present only if their release
# packages install cleanly; skip-unavailable keeps the build green otherwise
dnf5 -y install --nogpgcheck --skip-unavailable \
  --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
  terra-release-mesa terra-release-multimedia || true
# remove the hardcoded priority so config-manager options are effective
sed -i '/^priority=/d' /etc/yum.repos.d/terra*.repo 2>/dev/null || true

dnf5 -y install --skip-unavailable "${TERRA_PKGS[@]}" || true

# report anything terra did not provide (do not fail the build — the keeper
# gate in 30-prune.sh is the source of truth for what MUST exist)
for pkg in "${TERRA_PKGS[@]}"; do
  rpm -q "${pkg%%.i686}" >/dev/null 2>&1 || \
    echo "  WARN  terra did not provide: ${pkg}"
done

# disable every terra repo immediately (repo lifecycle policy)
dnf5 -y config-manager setopt "terra.enabled=0" 2>/dev/null || true
for f in /etc/yum.repos.d/terra*.repo; do
  [ -f "${f}" ] && sed -i 's/^enabled=1/enabled=0/' "${f}"
done
echo "::endgroup::"
