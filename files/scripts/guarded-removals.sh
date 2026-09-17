#!/usr/bin/env bash
# halcyon Step C — guarded removals + hard verification (prompt §5.1)
set -uo pipefail
# compose-variance / expected-absent candidates: remove only what is installed
CANDIDATES=(
  gnome-classic-session gnome-classic-session-xsession gnome-terminal gnome-console
  gnome-text-editor evince loupe snapshot totem gnome-calculator gnome-calendar
  gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-font-viewer
  gnome-logs gnome-maps gnome-remote-desktop gnome-system-monitor gnome-tour
  gnome-weather gnome-initial-setup gnome-extensions-app gnome-software baobab
  simple-scan yelp malcontent-control gnome-bluetooth jupiter-sd-mounting-btrfs
  ds-inhibit plasma-login-manager hhd hhd-ui decky-loader bluebubbles
  gnome-shell-extension-apps-menu gnome-shell-extension-background-logo
  gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu
  gnome-shell-extension-window-list gnome-shell-extension-workspace-indicator
  mozilla-filesystem
)
present=()
for p in "${CANDIDATES[@]}"; do
  if rpm -q "$p" >/dev/null 2>&1; then
    present+=("$p")
  fi
done
echo "guarded candidates present: ${present[*]:-none}"

# reverse-dep gates: sddm / cage stay (→ masked in services.yml) if a keeper needs them
for p in sddm cage; do
  if rpm -q "$p" >/dev/null 2>&1; then
    reqs="$(dnf -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
    if [ -n "${reqs}" ]; then
      echo "gate: keeping ${p} (required by: $(echo "${reqs}" | tr '\n' ' '))"
    else
      echo "gate: removing ${p} (nothing installed requires it)"
      present+=("$p")
    fi
  fi
done

if [ "${#present[@]}" -gt 0 ]; then
  dnf -y remove "${present[@]}" || echo 'WARNING: guarded dnf remove failed; hard verification below will catch survivors' >&2
fi

# hard-fail verification (constraint 14)
# HARD: keepers empirically present in the base image (2026-09-17 build) that
# must survive our removals.
rc=0
for p in gnome-shell gdm mutter waydroid fastfetch firefox inputplumber \
  steamos-manager-powerstation steamdeck-gnome-presets jupiter-fan-control; do
  if rpm -q "$p" >/dev/null 2>&1; then
    echo "ERROR: ${p} still installed after removals" >&2
    rc=1
  fi
done
for p in bazaar bazzite-portal steam terra-gamescope umu-launcher lutris \
  scx-scheds scx-tools usbip xwiimote-ng input-remapper; do
  if ! rpm -q "$p" >/dev/null 2>&1; then
    echo "ERROR: keeper ${p} missing after removals" >&2
    rc=1
  fi
done
# SOFT: the published stable base does NOT ship these (prompt §1 expected them;
# recorded as base-image variance in NOTES.md §5). Warn loudly so a future base
# that re-adds them doesn't slip away unnoticed, but don't fail the build.
for p in steamos-manager gamescope-session-ogui-steam gamemode; do
  rpm -q "$p" >/dev/null 2>&1 ||
    echo "WARNING: ${p} not present — known stable-channel base variance (NOTES.md §5)"
done
if [ -f /usr/bin/distroshelf-helper ]; then
  echo "distroshelf-helper file present (kept)"
else
  echo "WARNING: /usr/bin/distroshelf-helper absent — stable-channel base variance (NOTES.md §5)"
fi
exit "$rc"
