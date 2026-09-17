#!/usr/bin/env bash
# halcyon build-scripts.yml verification (prompt §5.8)
# NOTE (deviation S): the prompt's `dnf -y remove gcc` is NOT performed — dnf5's
# remove cascades into dependents, and Fedora's emacs-pgtk (native-comp) has a
# runtime `Requires: gcc`: build 11 removed 225 packages including the freshly
# installed emacs-pgtk. gcc stays (it is pulled in by emacs-pgtk anyway); the
# pypr-client C helper still compiled during install-pyprland.sh.
set -euo pipefail

echo "::group::build-scripts-verify — installed tool checks"

# --- Obsidian ---
echo "--- Checking Obsidian ---"
if test -x /usr/bin/obsidian; then
  echo "  PASS  /usr/bin/obsidian executable"
else
  echo "  FAIL  /usr/bin/obsidian missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if test -f /usr/share/applications/obsidian.desktop; then
  echo "  PASS  obsidian.desktop present"
else
  echo "  FAIL  /usr/share/applications/obsidian.desktop missing"
  echo "::endgroup::"
  exit 1
fi

echo "  INFO  Checking Obsidian Electron shared-library deps..."
if ldd /usr/lib/obsidian/obsidian 2>/dev/null | grep -i 'not found'; then
  echo "  FAIL  obsidian Electron deps missing (ldd reported 'not found' above)"
  echo "::endgroup::"
  exit 1
else
  echo "  PASS  obsidian Electron deps satisfied"
fi

# --- Zotero ---
echo "--- Checking Zotero ---"
if test -x /usr/bin/zotero; then
  echo "  PASS  /usr/bin/zotero executable"
else
  echo "  FAIL  /usr/bin/zotero missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if grep -q DisableAppUpdate /usr/lib/zotero/distribution/policies.json; then
  echo "  PASS  Zotero DisableAppUpdate policy present"
else
  echo "  FAIL  DisableAppUpdate policy missing from Zotero distribution/policies.json"
  echo "::endgroup::"
  exit 1
fi

# --- Pyprland ---
echo "--- Checking Pyprland ---"
if test -x /usr/bin/pypr; then
  echo "  PASS  /usr/bin/pypr executable"
else
  echo "  FAIL  /usr/bin/pypr missing or not executable"
  echo "::endgroup::"
  exit 1
fi

if test -f /usr/lib/systemd/user/pyprland.service; then
  echo "  PASS  pyprland.service user unit present"
else
  echo "  FAIL  /usr/lib/systemd/user/pyprland.service missing"
  echo "::endgroup::"
  exit 1
fi

# --- TeX Live ---
echo "--- Checking TeX Live ---"
if test -d /usr/lib/texlive; then
  echo "  PASS  /usr/lib/texlive directory present"
else
  echo "  FAIL  /usr/lib/texlive directory missing"
  echo "::endgroup::"
  exit 1
fi

if test -f /etc/profile.d/texlive.sh; then
  echo "  PASS  /etc/profile.d/texlive.sh present"
else
  echo "  FAIL  /etc/profile.d/texlive.sh missing"
  echo "::endgroup::"
  exit 1
fi

# --- Deliberately retained packages (deviation S) ---
echo "--- Checking deliberately retained packages ---"
echo "  INFO  gcc, perl, python3, jq are intentionally kept (gcc: emacs native-comp dep — NOTES.md §4 S)"
for pkg in gcc perl python3 jq; do
  if rpm -q "${pkg}" &>/dev/null; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${pkg}")
    echo "  PASS  ${pkg}-${ver} installed"
  else
    echo "  FAIL  ${pkg} not installed (expected to be retained)"
    echo "::endgroup::"
    exit 1
  fi
done

echo "--- Checking emacs-pgtk survived gcc cascade guard ---"
if rpm -q emacs-pgtk &>/dev/null; then
  ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' emacs-pgtk)
  echo "  PASS  emacs-pgtk-${ver} installed (gcc cascade guard held)"
else
  echo "  FAIL  emacs-pgtk missing — gcc removal cascaded into it (regression!)"
  echo "::endgroup::"
  exit 1
fi

echo "--- build-scripts-verify complete — all checks passed ---"
echo "::endgroup::"
