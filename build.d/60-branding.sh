#!/usr/bin/env bash
# halcyon build stage 11 — branding: os-release identity + plymouth theme
# assets. PRETTY_NAME reflects the actual base (MIGRATION-sanctioned
# divergence from main's "halcyon (Bazzite fork)"); HOME_URL matches main.
set -euo pipefail
echo "::group::60-branding — os-release + plymouth"
sed -i 's|^NAME=.*|NAME=halcyon|; s|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Fedora bootc)"|' /usr/lib/os-release
if grep -q '^HOME_URL=' /usr/lib/os-release; then
  sed -i 's|^HOME_URL=.*|HOME_URL=https://github.com/aahsnr-work/halcyon|' /usr/lib/os-release
else
  echo 'HOME_URL=https://github.com/aahsnr-work/halcyon' >> /usr/lib/os-release
fi
# plymouth theme assets are generated from the baked astronaut wallpaper
bash /ctx/files/scripts/build-plymouth-assets.sh
echo "::endgroup::"
