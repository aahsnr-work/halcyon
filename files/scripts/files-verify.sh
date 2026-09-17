#!/usr/bin/env bash
# halcyon files.yml verification (prompt §5.9) — also verifies the brew assets
# that are only present after this module's files copy (see NOTES.md deviation O).
set -euo pipefail
chmod 0755 /usr/libexec/halcyon-image/*
test -f /etc/profile.d/image-path.sh
command -v chezmoi
grep -q 'doom-setup' /usr/share/ublue-os/just/60-custom.just
grep -q 'home-manager-setup' /usr/share/ublue-os/just/60-custom.just
# brew assets (copied by this module's files step + the nix.yml systemd module)
test -f /usr/share/ublue-os/homebrew/Brewfile
test "$(grep -c '^brew ' /usr/share/ublue-os/homebrew/Brewfile)" -eq 21
test -f /usr/lib/systemd/user/brew-bundle.service
