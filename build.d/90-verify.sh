#!/usr/bin/env bash
# halcyon build stage 14 — verification gates (T12; MIGRATION §11.4).
# Consolidates the still-relevant checks from the retired BlueBuild-era
# module verify scripts (desktop/apps/files/build-scripts/branding-verify).
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::90-verify — image gates"

# --- p03 kernel + NVIDIA (MIGRATION §4) ---
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
# the COPR kmod package's %{VERSION} is the KERNEL version — the DRIVER
# version lives in the module metadata, which is what the userland must match
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"
gate "p03 kernel installed"            rpm -q kernel-p03
gate "nvidia-open built for p03"       rpm -q kernel-p03-nvidia-open
gate "stock kernel absent"             sh -c '! rpm -q kernel >/dev/null 2>&1'
gate "p03 vmlinuz"                     test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "p03 initramfs"                   test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "p03 modules tree"                test -d "/usr/lib/modules/${KVER}"
gate "nvidia modules for p03"          sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config"        grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked"    sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
gate "nvidia userland matches modules" test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present"              test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs"       rpm -q nvidia-driver-libs.i686 mesa-libGL.i686

# --- repo lifecycle end state (80-finalize; TODO: no third-party repos) ---
gate "no third-party repo files"       sh -c '! ls /etc/yum.repos.d/ | grep -Eq "copr|vscode|brave|terra|negativo|rpmfusion|fedora-nvidia"'

# --- desktop / greeter ---
gate "hyprland-git (lionheartp)"       rpm -q hyprland-git
gate "noctalia-greeter-git"            rpm -q noctalia-greeter-git
gate "greeter wrapper"                 test -x /usr/bin/noctalia-greeter-session
gate "greetd config command"           grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml
gate "noctalia state tmpfiles"         test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf
gate "portal-gtk present"              rpm -q xdg-desktop-portal-gtk

# --- apps / stack ---
gate "steam installed"                 rpm -q steam
gate "bazzite-steam wrapper"           test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam"  sh -c 'grep -q "bazzite-steam" /usr/share/applications/steam.desktop 2>/dev/null || grep -rq "bazzite-steam" /usr/share/applications/ 2>/dev/null'
gate "scx + umu + bazaar"              sh -c 'rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal'
gate "obsidian desktop"                test -f /usr/share/applications/obsidian.desktop
gate "zen-browser installed"           rpm -q zen-browser
gate "flatpak user unit"               test -f /usr/lib/systemd/user/halcyon-flatpak-setup.service
gate "no system flatpak remotes"       sh -c '! ls /etc/flatpak/remotes.d/ 2>/dev/null | grep -q .'

# --- devtools (brew-formula replacements; chezmoi from Fedora) ---
gate "devtools RPM set"                sh -c 'rpm -q bat eza fzf lazygit ripgrep starship tealdeer yazi zellij pandoc dust uv atuin chezmoi'
gate "python helpers in /usr/bin"      sh -c 'for b in fconf fe ff fkill fp fssh rmi rmtmp screenshot se; do test -e /usr/bin/$b || exit 1; done'
gate "texlive profile"                 test -f /etc/profile.d/texlive.sh

# --- ujust + uupd (main-parity: was base-provided, now ublue-os-just) ---
gate "ujust wrapper present"           test -x /usr/bin/ujust
gate "justfile imports registered"     sh -c 'grep -q "80-halcyon.just" /usr/share/ublue-os/justfile && grep -q "rebase.just" /usr/share/ublue-os/justfile'
gate "uupd installed + timer unit"     sh -c 'rpm -q uupd && test -f /usr/lib/systemd/system/uupd.timer'
gate "bazzite-just recipes present"    test -f /usr/share/ublue-os/just/80-halcyon.just

# --- nix (winter pattern) + chezmoi wiring ---
gate "nix packages"                    rpm -q nix nix-daemon
gate "nix.mount + var-nix units"       sh -c 'test -f /usr/lib/systemd/system/nix.mount && test -f /usr/lib/systemd/system/var-nix.service'
gate "nix tmpfiles + profile script"   sh -c 'test -f /usr/lib/tmpfiles.d/nix.conf && test -f /etc/profile.d/01-nix-resolve-home-env.sh'
gate "chezmoi units + global symlinks" sh -c 'test -L /etc/systemd/user/default.target.wants/chezmoi-init.service && test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer'

# --- system / branding ---
gate "zsh is default shell"            grep -q 'SHELL=/bin/zsh' /etc/default/useradd
gate "flatpak first-boot unit"         test -f /usr/lib/systemd/user/halcyon-flatpak-setup.service
gate "PATH guard present"              test -f /etc/profile.d/00-path-guard.sh
gate "plymouth theme selected"         grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "os-release identity"             grep -q '^NAME=halcyon' /usr/lib/os-release
gate "login shell with empty PATH finds grep" env -i PATH= HOME=/root /bin/bash -lc 'command -v grep'

# --- package census (total + per-vendor provenance, baked into the image) ---
echo "::group::90-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "  INFO  total installed packages: ${TOTAL_PACKAGES}"
# GitHub Actions annotation: podman build streams this line into the build
# step's output, where the runner promotes it to a run notice.
echo "::notice title=halcyon package count::${TOTAL_PACKAGES} RPMs installed"
echo "  INFO  per-vendor breakdown (repo provenance):"
rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/        /'
install -d -m0755 /usr/share/halcyon
{
  echo "halcyon image package census (generated at build time)"
  echo "date_utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "kernel_p03: $(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03 2>/dev/null || echo unknown)"
  echo "total_packages: ${TOTAL_PACKAGES}"
  echo
  echo "per-vendor:"
  rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/  /'
} > /usr/share/halcyon/package-count
chmod 0644 /usr/share/halcyon/package-count
echo "  INFO  census baked to /usr/share/halcyon/package-count (ujust package-count)"
echo "::endgroup::"

gate "package census baked"            test -s /usr/share/halcyon/package-count
[ "$fail" = 0 ] || { echo "::error::image verification failed"; exit 1; }
echo "::endgroup::"
