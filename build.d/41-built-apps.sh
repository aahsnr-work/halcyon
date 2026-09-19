#!/usr/bin/env bash
# halcyon build stage 8 — built apps (transitional: the same scripts the
# BlueBuild build-scripts module ran; retired as halcyon-packages RPMs land —
# MIGRATION §8.2/8.5/8.6 and §8.7). The python-packages sources are staged
# from the ctx mount to the path install-python-packages.sh expects (the
# build-scripts.yml equivalent of `files: python-packages -> /usr/src`).
set -euo pipefail
echo "::group::41-built-apps — obsidian/zotero/pyprland/texlive/python"
export BUILD_SCRIPTS=/ctx/files/scripts
rm -rf /usr/src/python-packages
cp -a /ctx/files/python-packages /usr/src/python-packages
bash /ctx/files/scripts/install-obsidian.sh
bash /ctx/files/scripts/install-zotero.sh
bash /ctx/files/scripts/install-pyprland.sh
bash /ctx/files/scripts/install-texlive.sh
bash /ctx/files/scripts/install-python-packages.sh
rm -rf /usr/src/python-packages
echo "::endgroup::"
