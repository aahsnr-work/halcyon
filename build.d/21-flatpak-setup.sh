#!/usr/bin/env bash
# halcyon build stage 5 — flatpak transition (MIGRATION §8.1: flatpaks become
# RPMs in a later phase; meanwhile mimic default-flatpaks@v1 with a first-boot
# system-flatpak installer — flatpak state lives in /var and cannot be baked).
set -euo pipefail
echo "::group::21-flatpak-setup — first-boot installer"
dnf5 -y install flatpak
mkdir -p /usr/lib/systemd/system /usr/libexec/halcyon-image
cat > /usr/libexec/halcyon-image/flatpak-setup <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
for app in com.ranfdev.DistroShelf org.onlyoffice.desktopeditors \
           com.bitwarden.desktop com.ticktick.TickTick; do
  flatpak install --system --noninteractive --or-update flathub "$app"
done
SCRIPT
chmod 0755 /usr/libexec/halcyon-image/flatpak-setup
cat > /usr/lib/systemd/system/halcyon-flatpak-setup.service <<'UNIT'
[Unit]
Description=Install halcyon system flatpaks (transition until RPM conversion)
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/etc/.halcyon-flatpaks-done

[Service]
Type=oneshot
ExecStart=/usr/libexec/halcyon-image/flatpak-setup
ExecStartPost=/bin/sh -c 'touch /etc/.halcyon-flatpaks-done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable halcyon-flatpak-setup.service 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/halcyon-flatpak-setup.service \
    /usr/lib/systemd/system/multi-user.target.wants/halcyon-flatpak-setup.service
echo "::endgroup::"
