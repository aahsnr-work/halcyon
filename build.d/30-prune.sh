#!/usr/bin/env bash
# halcyon build stage 4 — prune, AFTER the packages stage. The guarded scripts
# hard-fail if their "keeper" packages (steam, lutris, bazaar, …) are missing;
# on the BlueBuild-era Bazzite base those came with the image, but on
# fedora-bootc they only exist once 10-packages.sh has installed them — so
# this stage must never run before it. (MIGRATION §9: the BlueBuild-era
# removals.yml set is mostly obsolete on the bootc base — no GNOME, no
# Bazzite; only the trimmed removal list remains. The guarded scripts below
# no-op safely when their removal targets are absent.)
set -euo pipefail
echo "::group::30-prune — bootc-base trim"
# zram-generator-defaults: halcyon manages swap differently (Bazzite-era
# removal, kept per removals.yml); nano-default-editor: replaced by helix/neovim.
# --no-autoremove must follow the remove command keyword (dnf5 CLI).
PKGS_TO_REMOVE=()
for pkg in nano nano-default-editor zram-generator-defaults; do
  rpm -q "${pkg}" >/dev/null 2>&1 && PKGS_TO_REMOVE+=("${pkg}")
done
if [ "${#PKGS_TO_REMOVE[@]}" -gt 0 ]; then
  dnf5 -y remove --no-autoremove "${PKGS_TO_REMOVE[@]}"
fi
dnf5 -y autoremove || true
echo "::endgroup::"
echo "::group::30-prune — guarded removals + footprint (existing scripts)"
bash /tmp/build.d/scripts/guarded-removals.sh
bash /tmp/build.d/scripts/file-footprint.sh
bash /tmp/build.d/scripts/gnome-extensions.sh
bash /tmp/build.d/scripts/fonts-cleanup.sh
echo "::endgroup::"
