#!/usr/bin/env bash
# halcyon build stage 9 — ujust machinery + updater (uupd).
#
# main inherited /usr/bin/ujust + /usr/share/ublue-os/just{,file} from the
# Bazzite base; on fedora-bootc the same machinery is the `ublue-os-just` RPM
# (COPR ublue-os/packages). `ujust update` then works through uupd exactly
# like Bazzite's 10-update.just. The vendored bazzite/halcyon recipe modules
# ship via files/system/usr/share/ublue-os/just/ (root COPY); this stage only
# installs packages, registers imports, and wires the update timer.
set -euo pipefail
echo "::group::50-ujust — ublue-os-just + uupd"
dnf5 -y copr enable -y ublue-os/packages
dnf5 -y install ublue-os-just uupd ublue-os-update-services glow stress-ng
dnf5 -y copr disable -y ublue-os/packages

# the machinery must exist — fail loudly if the package layout changed
test -x /usr/bin/ujust || { echo "  FAIL  /usr/bin/ujust missing from ublue-os-just"; exit 1; }
test -f /usr/share/ublue-os/justfile || { echo "  FAIL  /usr/share/ublue-os/justfile missing"; exit 1; }

# halcyon's own recipes (same files main put in /usr/share/bluebuild/justfiles)
# install as modules alongside the vendored bazzite ones
JUSTDIR=/usr/share/ublue-os/just
for f in cleanup.just doom-setup.just dots.just home-manager-setup.just \
         rebase.just texlive.just; do
  install -m0644 "/ctx/files/justfiles/${f}" "${JUSTDIR}/${f}"
done

# register our modules via the justfile's optional 60-custom import hook
# (the same mechanism main used; `import?` tolerates absence until we write it)
cat > /usr/share/ublue-os/just/60-custom.just <<'EOF'
# halcyon custom modules (bazzite-derived + halcyon's own recipes)
EOF
for f in 80-halcyon.just 81-halcyon-fixes.just 83-halcyon-audio.just \
         87-halcyon-framegen.just cleanup.just doom-setup.just dots.just \
         home-manager-setup.just rebase.just texlive.just; do
  echo "import \"${JUSTDIR}/${f}\"" >> /usr/share/ublue-os/just/60-custom.just
done

# bazzite's steam desktop entries point at the vendored wrappers (bazzite
# Containerfile lines 450-455: Exec + Big Picture + silent autostart for skel)
sed -i 's@/usr/bin/steam@/usr/bin/bazzite-steam@g' /usr/share/applications/steam.desktop 2>/dev/null || true
sed -i 's@Exec=steam steam://open/bigpicture@Exec=/usr/bin/bazzite-steam-bpm@g' /usr/share/applications/steam.desktop 2>/dev/null || true
mkdir -p /etc/skel/.config/autostart
cp "/usr/share/applications/steam.desktop" "/etc/skel/.config/autostart/steam.desktop" 2>/dev/null || true
sed -i 's@/usr/bin/bazzite-steam %U@/usr/bin/bazzite-steam -silent %U@g' /etc/skel/.config/autostart/steam.desktop 2>/dev/null || true
# lutris: pyproto buffer fix from bazzite (net.lutris.Lutris.desktop)
sed -i 's|^Exec=lutris %U$|Exec=env PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python lutris %U|' /usr/share/applications/net.lutris.Lutris.desktop 2>/dev/null || true

# updater timer (from ublue-os-update-services)
systemctl enable uupd.timer 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/uupd.timer /usr/lib/systemd/system/timers.target.wants/uupd.timer 2>/dev/null || true
echo "  INFO  ujust recipes registered:"
grep 'import "' /usr/share/ublue-os/justfile | sed 's/^/        /'
echo "::endgroup::"
