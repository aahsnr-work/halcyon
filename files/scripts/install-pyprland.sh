#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-pyprland — resolving latest release"

PYPR_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${PYPR_TMP}"; rm -rf "${PYPR_TMP}"' EXIT

cd "${PYPR_TMP}"

# Query GitHub API for latest release tag with fallback
echo "--- Querying GitHub API for latest Pyprland release ---"
LATEST_TAG="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  https://api.github.com/repos/hyprland-community/pyprland/releases/latest 2>/dev/null |
  jq -r '.tag_name // empty' || true)"

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  LATEST_TAG="3.4.4"
  echo "  WARN  GitHub API unavailable or rate-limited — using fallback version ${LATEST_TAG}"
else
  echo "  OK    latest Pyprland release: ${LATEST_TAG}"
fi
echo "::endgroup::"

echo "::group::install-pyprland — download & extract source"
TARBALL_URL="https://github.com/hyprland-community/pyprland/archive/refs/tags/${LATEST_TAG}.tar.gz"
echo "--- Downloading source tarball ---"
echo "  INFO  URL: ${TARBALL_URL}"
curl -fsSL --progress-bar "${TARBALL_URL}" -o pyprland.tar.gz
size=$(du -h pyprland.tar.gz | cut -f1)
echo "  OK    downloaded pyprland.tar.gz (${size})"

tar -xzf pyprland.tar.gz
echo "  OK    extracted pyprland-${LATEST_TAG}/"
cd "pyprland-${LATEST_TAG}"
echo "::endgroup::"

echo "::group::install-pyprland — Python virtualenv + pip install"
INSTALL_DIR="/usr/lib/pyprland"
echo "--- Creating virtualenv at ${INSTALL_DIR} ---"
rm -rf "${INSTALL_DIR}"
python3 -m venv "${INSTALL_DIR}"
echo "  OK    virtualenv created ($(python3 --version))"

echo "--- Upgrading pip / build tools ---"
"${INSTALL_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel hatchling
echo "  OK    pip/setuptools/wheel/hatchling up to date"

echo "--- Installing Pyprland package ---"
"${INSTALL_DIR}/bin/pip" install --no-cache-dir .
echo "  OK    Pyprland ${LATEST_TAG} installed into virtualenv"
echo "::endgroup::"

echo "::group::install-pyprland — C client helper"
if [ -f "client/pypr-client.c" ] && command -v gcc &>/dev/null; then
  gcc_ver=$(gcc --version | head -n1)
  echo "  INFO  compiling pypr-client C helper (${gcc_ver})"
  if gcc -O3 client/pypr-client.c -o /usr/bin/pypr-client; then
    echo "  OK    /usr/bin/pypr-client compiled"
  else
    echo "  WARN  gcc exited non-zero for pypr-client — non-fatal"
  fi
else
  [ ! -f "client/pypr-client.c" ] && echo "  SKIP  client/pypr-client.c not present in this release"
  command -v gcc &>/dev/null || echo "  SKIP  gcc not available — skipping C client compilation"
fi
echo "::endgroup::"

echo "::group::install-pyprland — symlinks & systemd unit"
echo "--- Linking CLI binaries to /usr/bin ---"
ln -sf "${INSTALL_DIR}/bin/pypr" /usr/bin/pypr
echo "  OK    /usr/bin/pypr → ${INSTALL_DIR}/bin/pypr"

ln -sf "${INSTALL_DIR}/bin/pypr-quickstart" /usr/bin/pypr-quickstart
echo "  OK    /usr/bin/pypr-quickstart → ${INSTALL_DIR}/bin/pypr-quickstart"

if [ -f "${INSTALL_DIR}/bin/pypr-gui" ]; then
  ln -sf "${INSTALL_DIR}/bin/pypr-gui" /usr/bin/pypr-gui
  echo "  OK    /usr/bin/pypr-gui → ${INSTALL_DIR}/bin/pypr-gui"
else
  echo "  SKIP  pypr-gui binary not present in this release"
fi

mkdir -p /usr/lib/systemd/user
echo "--- Installing pyprland.service user unit ---"
if [ -f "systemd-unit/pyprland.service" ]; then
  install -Dm644 "systemd-unit/pyprland.service" /usr/lib/systemd/user/pyprland.service
  echo "  OK    installed upstream pyprland.service"
else
  echo "  INFO  upstream systemd-unit/pyprland.service not found — writing inline unit"
  cat >/usr/lib/systemd/user/pyprland.service <<'UNIT'
[Unit]
Description=Starts pyprland daemon
After=graphical-session.target
Wants=graphical-session.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
ExecStartPre=/bin/sh -c '[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] || exit 0'
ExecStart=/usr/bin/pypr
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT
  echo "  OK    inline pyprland.service written"
fi

echo "--- install-pyprland complete: Pyprland ${LATEST_TAG} → ${INSTALL_DIR}, /usr/bin/pypr ---"
echo "::endgroup::"
