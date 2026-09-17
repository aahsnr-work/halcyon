#!/usr/bin/env bash
# halcyon Step E — directory-installed GNOME extensions (prompt §5.1)
# (replaces the gnome-extensions module — §11 #1)
set -euo pipefail
rm -rf /usr/share/gnome-shell/extensions     # the 12 dirs from §1.9b (not RPM-owned)
glib-compile-schemas /usr/share/glib-2.0/schemas || true
rm -f /etc/dconf/db/local.d/*bazzite* /etc/dconf/db/local.d/*gnome* 2>/dev/null || true
[ -d /etc/dconf/db/local.d ] && dconf update || true
