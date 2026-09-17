#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-obsidian — resolving latest release"

OBSIDIAN_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${OBSIDIAN_TMP}"; rm -rf "${OBSIDIAN_TMP}"' EXIT

cd "${OBSIDIAN_TMP}"

# Query GitHub API for the latest Obsidian AppImage URL, with fallback.
echo "--- Querying GitHub API for latest Obsidian release ---"
APPIMAGE_URL="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null |
  jq -r '.assets[] | select(.name | test("(?i)\\.appimage$")) | .browser_download_url' |
  head -n1 || true)"

if [ -z "${APPIMAGE_URL}" ] || [ "${APPIMAGE_URL}" = "null" ]; then
  APPIMAGE_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.7/Obsidian-1.8.7.AppImage"
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
"${icon_installed}" || echo "  WARN  no icon file found inside AppImage"

echo "--- Updating desktop database and icon cache ---"
update-desktop-database /usr/share/applications &>/dev/null || true
echo "  OK    update-desktop-database done"
gtk-update-icon-cache /usr/share/icons/hicolor &>/dev/null || true
echo "  OK    gtk-update-icon-cache done"

echo "--- install-obsidian complete ---"
echo "::endgroup::"
