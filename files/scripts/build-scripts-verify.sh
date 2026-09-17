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

# --- dump-to-markdown ---
echo "--- Checking dump-to-markdown ---"
if test -x /usr/bin/dump-to-markdown; then
  echo "  PASS  /usr/bin/dump-to-markdown executable"
else
  echo "  FAIL  /usr/bin/dump-to-markdown missing or not executable"
  echo "::endgroup::"
  exit 1
fi

dtm_version="$(/usr/bin/dump-to-markdown --version)"
if echo "${dtm_version}" | grep -q "1.2.0"; then
  echo "  PASS  dump-to-markdown version reported (${dtm_version})"
else
  echo "  FAIL  unexpected dump-to-markdown --version output: ${dtm_version}"
  echo "::endgroup::"
  exit 1
fi

if test -d /usr/lib/dump-to-markdown; then
  echo "  PASS  /usr/lib/dump-to-markdown virtualenv present"
else
  echo "  FAIL  /usr/lib/dump-to-markdown virtualenv missing"
  echo "::endgroup::"
  exit 1
fi

if test ! -d /usr/src/dump-to-markdown; then
  echo "  PASS  staged source cleaned up (/usr/src/dump-to-markdown absent)"
else
  echo "  FAIL  staged source still present at /usr/src/dump-to-markdown (cleanup skipped?)"
  echo "::endgroup::"
  exit 1
fi

echo "--- Functional smoke: dump a tiny tree ---"
DTM_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${DTM_TMP}"; rm -rf "${DTM_TMP}"' EXIT
mkdir -p "${DTM_TMP}/smoke/src"
echo "x = 1" >"${DTM_TMP}/smoke/src/a.py"
# shellcheck disable=SC2016  # heading pattern is a literal, backticks included
if /usr/bin/dump-to-markdown --root "${DTM_TMP}/smoke" --output "${DTM_TMP}/smoke-dump.md"; then
  if grep -q '^## `smoke/src/a.py`$' "${DTM_TMP}/smoke-dump.md" &&
    grep -q '^```python$' "${DTM_TMP}/smoke-dump.md"; then
    echo "  PASS  smoke dump produced expected heading + fence ($(wc -l <"${DTM_TMP}/smoke-dump.md") lines)"
  else
    echo "  FAIL  smoke dump missing expected heading/fence content"
    echo "::endgroup::"
    exit 1
  fi
else
  echo "  FAIL  dump-to-markdown exited non-zero on smoke tree"
  echo "::endgroup::"
  exit 1
fi

echo "--- build-scripts-verify complete — all checks passed ---"
echo "::endgroup::"
