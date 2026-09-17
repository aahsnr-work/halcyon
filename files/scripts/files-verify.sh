#!/usr/bin/env bash
# halcyon files.yml verification (prompt §5.9) — also verifies the brew assets
# that are only present after this module's files copy (see NOTES.md deviation O).
set -euo pipefail

echo "::group::files-verify — dotfile & brew asset checks"
trap 'echo "::endgroup::"' EXIT

# --- Target paths ---
HALCYON_LIBEXEC="/usr/libexec/halcyon-image"
IMAGE_PATH_SH="/etc/profile.d/image-path.sh"
JUST60="/usr/share/ublue-os/just/60-custom.just"
BREWFILE="/usr/share/ublue-os/homebrew/Brewfile"
BREW_SERVICE="/usr/lib/systemd/user/brew-bundle.service"
BREW_ENV="/etc/environment.d/10-homebrew.conf"
BREW_INSTALLER="/usr/libexec/halcyon-image/brew-bundle-install"

# --- Script permissions ---
echo "--- Fixing and checking script permissions ---"
if [[ -d "${HALCYON_LIBEXEC}" ]]; then
  find "${HALCYON_LIBEXEC}" -maxdepth 1 -type f -exec chmod 0755 {} +
  script_count=$(find "${HALCYON_LIBEXEC}" -maxdepth 1 -type f -perm -0111 | wc -l)
  if [[ "${script_count}" -gt 0 ]]; then
    echo "  PASS  ${HALCYON_LIBEXEC}/* executable (${script_count} scripts)"
  else
    echo "  FAIL  no executable scripts found in ${HALCYON_LIBEXEC}"
    exit 1
  fi
else
  echo "  FAIL  ${HALCYON_LIBEXEC} directory missing"
  exit 1
fi

# --- Core files & environment ---
echo "--- Checking core installed files & environment ---"
if [[ -f "${IMAGE_PATH_SH}" ]]; then
  echo "  PASS  ${IMAGE_PATH_SH} present"
else
  echo "  FAIL  ${IMAGE_PATH_SH} missing"
  exit 1
fi

if grep -q '/usr/libexec/halcyon-image' "${IMAGE_PATH_SH}"; then
  echo "  PASS  halcyon helper-scripts PATH export present in ${IMAGE_PATH_SH}"
else
  echo "  FAIL  /usr/libexec/halcyon-image PATH missing from ${IMAGE_PATH_SH}"
  exit 1
fi

# Brew PATH for non-login sessions (Wayland, GUI apps, systemd --user) lives in
# environment.d — brew.sh (from Bazzite base) covers interactive login shells.
if [[ -f "${BREW_ENV}" ]]; then
  echo "  PASS  ${BREW_ENV} present"
  if grep -q '/home/linuxbrew/.linuxbrew/bin' "${BREW_ENV}"; then
    echo "  PASS  Homebrew bin PATH entry present in ${BREW_ENV}"
  else
    echo "  FAIL  Homebrew bin PATH entry missing from ${BREW_ENV}"
    exit 1
  fi
else
  echo "  FAIL  ${BREW_ENV} missing — brew packages will be invisible to Wayland/GUI apps"
  exit 1
fi

if command -v chezmoi >/dev/null 2>&1; then
  echo "  PASS  chezmoi in PATH ($(command -v chezmoi))"
else
  echo "  FAIL  chezmoi not found in PATH"
  exit 1
fi

# --- Justfile recipes ---
echo "--- Checking 60-custom.just recipes ---"
if [[ ! -f "${JUST60}" ]]; then
  echo "  FAIL  ${JUST60} missing"
  exit 1
fi

for recipe in doom-setup home-manager-setup; do
  if grep -q "${recipe}" "${JUST60}"; then
    echo "  PASS  ${recipe} recipe present in 60-custom.just"
  else
    echo "  FAIL  ${recipe} recipe missing from ${JUST60}"
    exit 1
  fi
done

# --- Brew assets (Brewfile staged by brew.yml; units by the systemd
#     module's file copy; payload itself is verified in brew-verify.sh) ---
echo "--- Checking brew assets ---"
if [[ ! -f "${BREWFILE}" ]]; then
  echo "  FAIL  ${BREWFILE} missing"
  exit 1
fi
echo "  PASS  Brewfile present"

brew_count=$(grep -c '^[[:space:]]*brew ' "${BREWFILE}" || true)
if [[ "${brew_count}" -gt 0 ]]; then
  echo "  PASS  Brewfile contains ${brew_count} brew entries"
else
  echo "  FAIL  Brewfile contains no valid 'brew' entries"
  exit 1
fi

if [[ -f "${BREW_SERVICE}" ]]; then
  echo "  PASS  brew-bundle.service user unit present"
else
  echo "  FAIL  ${BREW_SERVICE} missing"
  exit 1
fi

if [[ -x "${BREW_INSTALLER}" ]]; then
  echo "  PASS  ${BREW_INSTALLER} present and executable"
else
  echo "  FAIL  ${BREW_INSTALLER} missing or not executable"
  exit 1
fi

echo "--- files-verify complete — all checks passed ---"
