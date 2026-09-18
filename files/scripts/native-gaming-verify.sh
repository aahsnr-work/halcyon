#!/usr/bin/env bash
# native-gaming-verify.sh — gates for the RakuOS-style native gaming additions
set -euo pipefail

echo "::group::native-gaming-verify — Lutris"
if rpm -q lutris >/dev/null 2>&1; then
  ver="$(rpm -q --qf '%{VERSION}' lutris)"
  echo "  PASS  lutris-${ver} installed"
else
  echo "  FAIL  lutris missing"
  echo "::endgroup::"
  exit 1
fi
if test -x /usr/bin/lutris; then
  echo "  PASS  /usr/bin/lutris executable"
else
  echo "  FAIL  /usr/bin/lutris missing"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "::group::native-gaming-verify — Heroic Games Launcher"
if rpm -q heroic-games-launcher >/dev/null 2>&1 || rpm -q heroic >/dev/null 2>&1; then
  echo "  PASS  heroic RPM installed"
else
  echo "  FAIL  heroic RPM missing"
  echo "::endgroup::"
  exit 1
fi
if test -x /usr/bin/heroic; then
  echo "  PASS  /usr/bin/heroic executable"
else
  echo "  FAIL  /usr/bin/heroic missing"
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"

echo "--- native-gaming-verify complete — all checks passed ---"
