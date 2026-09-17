#!/usr/bin/env bash
# halcyon files.yml verification (prompt §5.9) — also verifies the brew assets
# that are only present after this module's files copy (see NOTES.md deviation O).
set -euo pipefail

echo "::group::files-verify — dotfile & brew asset checks"

# --- Script permissions ---
echo "--- Fixing script permissions ---"
chmod 0755 /usr/libexec/halcyon-image/*
echo "  OK    /usr/libexec/halcyon-image/* → 0755"

# --- Core files ---
echo "--- Checking core installed files ---"

if test -f /etc/profile.d/image-path.sh; then
  echo "  PASS  /etc/profile.d/image-path.sh present"
else
  echo "  FAIL  /etc/profile.d/image-path.sh missing"
  echo "::endgroup::"
  exit 1
fi

if command -v chezmoi &>/dev/null; then
  echo "  PASS  chezmoi in PATH ($(command -v chezmoi))"
else
  echo "  FAIL  chezmoi not found in PATH"
  echo "::endgroup::"
  exit 1
fi

# --- Justfile recipes ---
echo "--- Checking 60-custom.just recipes ---"

JUST60=/usr/share/ublue-os/just/60-custom.just
if grep -q 'doom-setup' "${JUST60}"; then
  echo "  PASS  doom-setup recipe present in 60-custom.just"
else
  echo "  FAIL  doom-setup recipe missing from ${JUST60}"
  echo "::endgroup::"
  exit 1
fi

if grep -q 'home-manager-setup' "${JUST60}"; then
  echo "  PASS  home-manager-setup recipe present in 60-custom.just"
else
  echo "  FAIL  home-manager-setup recipe missing from ${JUST60}"
  echo "::endgroup::"
  exit 1
fi

# --- Brew assets (copied by files step + nix.yml systemd module) ---
echo "--- Checking brew assets ---"

if test -f /usr/share/ublue-os/homebrew/Brewfile; then
  echo "  PASS  Brewfile present"
else
  echo "  FAIL  /usr/share/ublue-os/homebrew/Brewfile missing"
  echo "::endgroup::"
  exit 1
fi

brew_count=$(grep -c '^brew ' /usr/share/ublue-os/homebrew/Brewfile)
if [ "${brew_count}" -eq 21 ]; then
  echo "  PASS  Brewfile contains exactly 21 brew entries"
else
  echo "  FAIL  Brewfile brew-entry count mismatch: expected 21, got ${brew_count}"
  echo "::endgroup::"
  exit 1
fi

if test -f /usr/lib/systemd/user/brew-bundle.service; then
  echo "  PASS  brew-bundle.service user unit present"
else
  echo "  FAIL  /usr/lib/systemd/user/brew-bundle.service missing"
  echo "::endgroup::"
  exit 1
fi

echo "--- files-verify complete — all checks passed ---"
echo "::endgroup::"
