#!/usr/bin/env bash
# halcyon build stage 8 — branding: os-release identity + plymouth theme assets
set -euo pipefail
echo "::group::60-branding — os-release + plymouth"
sed -i 's|^NAME=.*|NAME=halcyon|; s|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Fedora bootc)"|' /usr/lib/os-release
# plymouth theme assets are generated from the baked astronaut wallpaper
bash /tmp/build.d/scripts/build-plymouth-assets.sh
echo "::endgroup::"
