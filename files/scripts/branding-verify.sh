#!/usr/bin/env bash
# halcyon branding.yml verification (prompt §5.11)
set -euo pipefail
grep -q 'PRETTY_NAME="halcyon' /etc/os-release
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme theme || plymouth-set-default-theme spinner || true
fi
test -f /etc/motd.d/motd.txt
test -d /usr/share/backgrounds/halcyon
