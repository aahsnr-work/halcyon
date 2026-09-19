#!/usr/bin/env bash
# halcyon build stage 9 — verification gates (T12; MIGRATION §11.4 semantics)
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::90-verify — image gates"
# --- p03 kernel + NVIDIA (MIGRATION §4, rakuos-port p03-verify semantics) ---
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
# --- desktop / greeter ---
gate "hyprland-git (lionheartp)"       rpm -q hyprland-git
gate "noctalia-greeter-git"            rpm -q noctalia-greeter-git
gate "greeter wrapper"                 test -x /usr/bin/noctalia-greeter-session
gate "greetd config command"           grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml
gate "noctalia state tmpfiles"         test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf
# --- apps / stack ---
gate "steam installed"                 rpm -q steam
gate "obsidian desktop"                test -f /usr/share/applications/obsidian.desktop
gate "zen-browser installed"           rpm -q zen-browser
gate "flatpak first-boot unit"         test -f /usr/lib/systemd/system/halcyon-flatpak-setup.service
gate "PATH guard present"              test -f /etc/profile.d/00-path-guard.sh
gate "plymouth theme selected"         grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "login shell with empty PATH finds grep" env -i PATH= HOME=/root /bin/bash -lc 'command -v grep'
[ "$fail" = 0 ] || { echo "::error::image verification failed"; exit 1; }
echo "::endgroup::"
