#!/usr/bin/env bash
# halcyon build stage 7 — flatpak: package only at build time; flathub USER
# repo only (no flathub system repo, no fedora flatpaks — user policy). The
# four transition apps install per-user at first login (MIGRATION §8.1:
# they become monorepo RPMs later; flatpak state lives in /var/home anyway).
set -euo pipefail
echo "::group::21-flatpak-setup — flatpak package + user-repo wiring"
dnf5 -y install flatpak
# the base must not carry flatpak remotes or the fedora flatpak set: wipe any
# system remotes/state and drop fedora-workstation-repositories (ships the
# fedora-flatpak remote) if present
rm -rf /etc/flatpak/remotes.d /var/lib/flatpak /etc/flatpak/removes.d 2>/dev/null || true
if rpm -q fedora-workstation-repositories >/dev/null 2>&1; then
  dnf5 -y remove fedora-workstation-repositories
fi

mkdir -p /usr/libexec/halcyon-image
cat > /usr/libexec/halcyon-image/flatpak-setup <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# per-user: flathub is the ONLY remote, configured at user scope
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
for app in com.ranfdev.DistroShelf org.onlyoffice.desktopeditors \
           com.bitwarden.desktop com.ticktick.TickTick; do
  flatpak install --user --noninteractive --or-update flathub "$app"
done
SCRIPT
chmod 0755 /usr/libexec/halcyon-image/flatpak-setup

# user unit — wired --global in 50-system.sh; runs once at first login
cat > /usr/lib/systemd/user/halcyon-flatpak-setup.service <<'UNIT'
[Unit]
Description=Install halcyon user flatpaks from flathub (transition until RPM conversion)
Wants=network-online.target
After=network-online.target
ConditionPathExists=!%h/.config/halcyon/.flatpak-done

[Service]
Type=oneshot
ExecStart=/usr/libexec/halcyon-image/flatpak-setup
ExecStartPost=/bin/sh -c 'mkdir -p %h/.config/halcyon && touch %h/.config/halcyon/.flatpak-done'
RemainAfterExit=yes

[Install]
WantedBy=default.target
UNIT
echo "::endgroup::"
