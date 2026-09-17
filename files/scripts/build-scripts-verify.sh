#!/usr/bin/env bash
# halcyon build-scripts.yml verification (prompt §5.8)
# NOTE (deviation S): the prompt's `dnf -y remove gcc` is NOT performed — dnf5's
# remove cascades into dependents, and Fedora's emacs-pgtk (native-comp) has a
# runtime `Requires: gcc`: build 11 removed 225 packages including the freshly
# installed emacs-pgtk. gcc stays (it is pulled in by emacs-pgtk anyway); the
# pypr-client C helper still compiled during install-pyprland.sh.
set -euo pipefail
test -x /usr/bin/obsidian && test -f /usr/share/applications/obsidian.desktop
ldd /usr/lib/obsidian/obsidian 2>/dev/null | grep -i 'not found' && { echo 'ERROR: obsidian electron deps missing'; exit 1; } || true
test -x /usr/bin/zotero && grep -q DisableAppUpdate /usr/lib/zotero/distribution/policies.json
test -x /usr/bin/pypr && test -f /usr/lib/systemd/user/pyprland.service
test -d /usr/lib/texlive && test -f /etc/profile.d/texlive.sh
rpm -q gcc perl python3 jq   # all deliberately KEPT (gcc: emacs native-comp dep — NOTES.md §4 S)
rpm -q emacs-pgtk            # must have survived (gcc cascade guard)
