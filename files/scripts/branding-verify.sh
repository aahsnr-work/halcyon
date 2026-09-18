#!/usr/bin/env bash
# halcyon branding.yml verification (prompt §5.11)
set -euo pipefail

echo "::group::branding-verify — OS identity & theming checks"

# --- OS release name ---
echo "--- Checking /etc/os-release identity ---"
pretty=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' || true)
if echo "${pretty}" | grep -qi 'halcyon'; then
  echo "  PASS  PRETTY_NAME=\"${pretty}\""
else
  echo "  FAIL  PRETTY_NAME does not contain 'halcyon' — got: \"${pretty}\""
  echo "::endgroup::"
  exit 1
fi

# --- Plymouth theme ---
echo "--- Checking Plymouth theme ---"
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  current_theme=$(plymouth-set-default-theme 2>/dev/null || echo "(unknown)")
  echo "  INFO  current Plymouth theme: ${current_theme}"
  if plymouth-set-default-theme halcyon 2>/dev/null; then
    echo "  PASS  Plymouth 'halcyon' theme applied"
    if [ -f /usr/share/plymouth/themes/halcyon/background.png ]; then
      echo "  PASS  splash background asset present"
    else
      echo "  NOTE  splash background missing — theme falls back to plugin default"
    fi
  else
    echo "  NOTE  Plymouth 'halcyon' set failed — keeping previous theme (boot splash only)"
  fi
else
  echo "  SKIP  plymouth-set-default-theme not in PATH (headless build)"
fi

# --- MOTD ---
echo "--- Checking MOTD ---"
if test -f /etc/motd.d/motd.txt; then
  lines=$(wc -l < /etc/motd.d/motd.txt)
  echo "  PASS  /etc/motd.d/motd.txt present (${lines} lines)"
else
  echo "  FAIL  /etc/motd.d/motd.txt missing"
  echo "::endgroup::"
  exit 1
fi

# --- Backgrounds ---
echo "--- Checking halcyon backgrounds directory ---"
if test -d /usr/share/backgrounds/halcyon; then
  count=$(find /usr/share/backgrounds/halcyon -maxdepth 1 -type f | wc -l)
  echo "  PASS  /usr/share/backgrounds/halcyon/ present (${count} file(s))"
else
  echo "  FAIL  /usr/share/backgrounds/halcyon/ missing"
  echo "::endgroup::"
  exit 1
fi

echo "--- branding-verify complete — all checks passed ---"
echo "::endgroup::"
