#!/usr/bin/env bash
# halcyon build stage 7 — systemd units, services, tmpfiles, ujust shim
set -euo pipefail
echo "::group::50-system — units + services + ujust shim"
# systemd units shipped in files/systemd/{system,user}
cp -r /tmp/build.d/systemd/system/. /usr/lib/systemd/system/ 2>/dev/null || true
cp -r /tmp/build.d/systemd/user/. /usr/lib/systemd/user/ 2>/dev/null || true
# system services: greetd (+ tty2 escape hatch); brew units are retired with brew
systemctl enable greetd.service getty@tty2.service 2>/dev/null || true
# masks (same as the BlueBuild services.yml)
for u in sddm.service gdm.service bazzite-autologin.service nvidia-persistenced.service nvidia-powerd.service; do
  ln -sf /dev/null /etc/systemd/system/"$u"
done
# global user units (pyprland; brew-bundle retired with brew)
mkdir -p /etc/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/pyprland.service /etc/systemd/user/default.target.wants/pyprland.service 2>/dev/null || true
# ujust shim: the ublue ujust integration is not on fedora-bootc; provide
# `ujust` as a thin wrapper over `just` against our recipe dir
dnf5 -y install just
mkdir -p /usr/share/halcyon/just
cat > /usr/bin/ujust <<'SHIM'
#!/usr/bin/env bash
exec just --justfile /usr/share/halcyon/just/00-halcyon.just "$@"
SHIM
chmod 0755 /usr/bin/ujust
[ -f /usr/share/halcyon/just/00-halcyon.just ] || printf '# halcyon ujust recipes (populated from files/justfiles)\n' > /usr/share/halcyon/just/00-halcyon.just
echo "::endgroup::"
