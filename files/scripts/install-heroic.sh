#!/usr/bin/env bash
# install-heroic.sh — Heroic Games Launcher, native RPM (RakuOS-style native
# gaming: not Flatpak). Resolves the latest GitHub release with a pinned
# fallback (same pattern as install-pyprland.sh).
set -euo pipefail

FALLBACK_TAG="2.17.2"

echo "::group::install-heroic — resolving latest release"
TAG="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest 2>/dev/null \
  | jq -r '.tag_name // empty' || true)"
if [ -z "${TAG}" ] || [ "${TAG}" = "null" ]; then
  TAG="v${FALLBACK_TAG}"
  echo "  WARN  GitHub API unavailable — using fallback ${TAG}"
else
  echo "  OK    latest Heroic release: ${TAG}"
fi
echo "::endgroup::"

echo "::group::install-heroic — download & install RPM"
RPM_URL="https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/${TAG}/heroic-${TAG#v}-linux-amd64.rpm"
TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${TMP}"; rm -rf "${TMP}"' EXIT
curl --fail --retry 5 --retry-delay 2 -sSL "${RPM_URL}" -o "${TMP}/heroic.rpm" \
  || { echo "  FAIL  download failed: ${RPM_URL}" >&2; echo "::endgroup::"; exit 1; }
size="$(du -h "${TMP}/heroic.rpm" | cut -f1)"
echo "  OK    downloaded heroic.rpm (${size})"
dnf install -y "${TMP}/heroic.rpm"
test -x /usr/bin/heroic || { echo "  FAIL  /usr/bin/heroic missing after install"; echo "::endgroup::"; exit 1; }
echo "  OK    Heroic Games Launcher installed"
echo "--- install-heroic complete ---"
echo "::endgroup::"
