#!/usr/bin/env bash
# halcyon build stage 6 — built apps (transitional: the same scripts the
# BlueBuild build-scripts module ran; retired as halcyon-packages RPMs land —
# MIGRATION §8.2/8.5/8.6 and §8.7)
set -euo pipefail
echo "::group::41-built-apps — obsidian/zotero/pyprland/texlive/python"
export BUILD_SCRIPTS=/tmp/build.d/scripts
bash /tmp/build.d/scripts/install-obsidian.sh
bash /tmp/build.d/scripts/install-zotero.sh
bash /tmp/build.d/scripts/install-pyprland.sh
bash /tmp/build.d/scripts/install-texlive.sh
bash /tmp/build.d/scripts/install-python-packages.sh
echo "::endgroup::"
