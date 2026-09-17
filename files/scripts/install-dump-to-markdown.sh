#!/usr/bin/env bash
# build-scripts.yml — install-dump-to-markdown.sh
# Installs the repo-local dump-to-markdown package (staged by the files
# module in build-scripts.yml into /usr/src/dump-to-markdown) into a
# dedicated virtualenv, then symlinks the CLI onto PATH. Pattern mirrors
# install-pyprland.sh.
set -euo pipefail

VENV_DIR="/usr/lib/dump-to-markdown"
SRC_DIR="/usr/src/dump-to-markdown"

echo "::group::install-dump-to-markdown — staged source check"
if [ ! -f "${SRC_DIR}/pyproject.toml" ]; then
  echo "  FAIL  ${SRC_DIR}/pyproject.toml missing — files-module staging did not run"
  echo "::endgroup::"
  exit 1
fi
echo "  OK    staged package source present at ${SRC_DIR}"
echo "::endgroup::"

echo "::group::install-dump-to-markdown — virtualenv + pip install"
echo "--- Creating virtualenv at ${VENV_DIR} ---"
rm -rf "${VENV_DIR}"
python3 -m venv "${VENV_DIR}"
echo "  OK    virtualenv created ($(python3 --version))"

echo "--- Upgrading pip / build tools ---"
"${VENV_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel
echo "  OK    pip/setuptools/wheel up to date"

echo "--- Installing dump-to-markdown package ---"
"${VENV_DIR}/bin/pip" install --no-cache-dir "${SRC_DIR}"
echo "  OK    dump-to-markdown installed into virtualenv"
echo "::endgroup::"

echo "::group::install-dump-to-markdown — CLI symlink & smoke test"
echo "--- Linking CLI onto PATH ---"
ln -sf "${VENV_DIR}/bin/dump-to-markdown" /usr/bin/dump-to-markdown
echo "  OK    /usr/bin/dump-to-markdown → ${VENV_DIR}/bin/dump-to-markdown"

echo "--- Smoke: dump-to-markdown --version ---"
dump-to-markdown --version
echo "::endgroup::"

echo "::group::install-dump-to-markdown — cleanup staged source"
rm -rf "${SRC_DIR}"
echo "  INFO  removed staged source ${SRC_DIR} (installed copy lives in ${VENV_DIR})"
echo "--- install-dump-to-markdown complete ---"
echo "::endgroup::"
