#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-obsidian — resolving latest release"

OBSIDIAN_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${OBSIDIAN_TMP}"; rm -rf "${OBSIDIAN_TMP}"' EXIT

cd "${OBSIDIAN_TMP}"

# Query GitHub API for the newest release that ships a desktop AppImage.
# NOTE: releases/latest is unusable here — it is periodically a mobile-only
# (apk) release with no AppImage asset. Each asset's API entry carries a
# sha256 `digest`, which we verify the download against. GH_TOKEN/GITHUB_TOKEN/
# BB_PASSWORD (set by the CI action) are used opportunistically to raise the
# api.github.com rate limit; unauthenticated requests still work.
echo "--- Querying GitHub API for latest Obsidian desktop release ---"
GH_AUTH="${GH_TOKEN:-${GITHUB_TOKEN:-${BB_PASSWORD:-}}}"
AUTH_ARGS=()
if [ -n "${GH_AUTH}" ]; then
  AUTH_ARGS=(-H "Authorization: Bearer ${GH_AUTH}")
  echo "  INFO  using authenticated GitHub API request"
fi
API_RESPONSE="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  "${AUTH_ARGS[@]}" \
  'https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=15' 2>/dev/null || true)"
ASSET_LINE="$(printf '%s' "${API_RESPONSE}" | jq -r '
  ([.[]? | .assets[]? | select((.name | test("(?i)\\.appimage$")) and ((.name | test("(?i)-arm64")) | not))][0]
    | [.browser_download_url, (.digest // "-")]) | @tsv' 2>/dev/null || true)"
APPIMAGE_URL="$(printf '%s' "${ASSET_LINE}" | cut -f1 || true)"
APPIMAGE_DIGEST="$(printf '%s' "${ASSET_LINE}" | cut -f2 || true)"

if [ -z "${APPIMAGE_URL}" ] || [ "${APPIMAGE_URL}" = "null" ]; then
  APPIMAGE_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.7/Obsidian-1.8.7.AppImage"
  APPIMAGE_DIGEST="-"
  echo "  WARN  GitHub API unavailable or returned no AppImage URL — using fallback: ${APPIMAGE_URL}"
else
  echo "  OK    resolved AppImage URL: ${APPIMAGE_URL}"
fi
echo "::endgroup::"

echo "::group::install-obsidian — download & extract"
echo "--- Downloading AppImage ---"
curl -fsSL --progress-bar "${APPIMAGE_URL}" -o obsidian.AppImage
size=$(du -h obsidian.AppImage | cut -f1)
echo "  OK    downloaded obsidian.AppImage (${size})"

# --- Integrity: verify against the release asset's sha256 digest ---
if [ -n "${APPIMAGE_DIGEST}" ] && [ "${APPIMAGE_DIGEST}" != "-" ] && [ "${APPIMAGE_DIGEST}" != "null" ]; then
  expected="${APPIMAGE_DIGEST#sha256:}"
  actual="$(sha256sum obsidian.AppImage | cut -d' ' -f1)"
  if [ "${expected}" = "${actual}" ]; then
    echo "  OK    sha256 verified against GitHub API asset digest (${actual:0:12}…)"
  else
    echo "  FAIL  sha256 mismatch — expected ${expected:0:12}…, got ${actual:0:12}…" >&2
    exit 1
  fi
else
  echo "  WARN  no digest available for this asset — download is TLS-verified only"
fi

chmod +x obsidian.AppImage

echo "--- Extracting AppImage contents ---"
./obsidian.AppImage --appimage-extract >/dev/null
echo "  OK    AppImage extracted to squashfs-root/"
echo "::endgroup::"

echo "::group::install-obsidian — install to /usr/lib/obsidian"
INSTALL_DIR="/usr/lib/obsidian"
mkdir -p "${INSTALL_DIR}"
echo "--- Copying files to ${INSTALL_DIR} ---"
cp -rf squashfs-root/* "${INSTALL_DIR}/"
installed_size=$(du -sh "${INSTALL_DIR}" | cut -f1)
echo "  OK    ${INSTALL_DIR} populated (${installed_size})"

echo "--- Creating /usr/bin/obsidian symlink ---"
ln -sf "${INSTALL_DIR}/obsidian" /usr/bin/obsidian
echo "  OK    /usr/bin/obsidian → ${INSTALL_DIR}/obsidian"
echo "::endgroup::"

echo "::group::install-obsidian — desktop entry & icons"
if [ -f "${INSTALL_DIR}/obsidian.desktop" ]; then
  install -Dm644 "${INSTALL_DIR}/obsidian.desktop" /usr/share/applications/obsidian.desktop
  sed -i 's|^Exec=.*|Exec=/usr/bin/obsidian %U|' /usr/share/applications/obsidian.desktop
  sed -i 's|^Icon=.*|Icon=obsidian|' /usr/share/applications/obsidian.desktop
  echo "  OK    /usr/share/applications/obsidian.desktop installed & patched"
else
  echo "  WARN  obsidian.desktop not found inside AppImage — skipping"
fi

icon_installed=false
for icon in "${INSTALL_DIR}"/usr/share/icons/hicolor/*/apps/obsidian.png "${INSTALL_DIR}/obsidian.png"; do
  if [ -f "${icon}" ]; then
    install -Dm644 "${icon}" /usr/share/icons/hicolor/512x512/apps/obsidian.png
    echo "  OK    icon installed from ${icon}"
    icon_installed=true
    break
  fi
done
if [ "${icon_installed}" = true ]; then :; else echo "  WARN  no icon file found inside AppImage"; fi

echo "--- Updating desktop database and icon cache ---"
update-desktop-database /usr/share/applications &>/dev/null || true
echo "  OK    update-desktop-database done"
gtk-update-icon-cache /usr/share/icons/hicolor &>/dev/null || true
echo "  OK    gtk-update-icon-cache done"

echo "--- install-obsidian complete ---"
echo "::endgroup::"
