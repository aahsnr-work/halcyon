#!/usr/bin/env bash
# halcyon build stage 9 — verification gates (T12; MIGRATION §11.4 semantics)
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::90-verify — image gates"
gate "p03 kernel installed"            rpm -q kernel-p03
gate "nvidia-open built for p03"       rpm -q kernel-p03-nvidia-open
gate "hyprland-git (lionheartp)"       rpm -q hyprland-git
gate "noctalia-greeter-git"            rpm -q noctalia-greeter-git
gate "greeter wrapper"                 test -x /usr/bin/noctalia-greeter-session
gate "greetd config command"           grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml
gate "noctalia state tmpfiles"         test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf
gate "steam installed"                 rpm -q steam
gate "obsidian desktop"                test -f /usr/share/applications/obsidian.desktop
gate "zen-browser installed"           rpm -q zen-browser
gate "flatpak first-boot unit"         test -f /usr/lib/systemd/system/halcyon-flatpak-setup.service
gate "PATH guard present"              test -f /etc/profile.d/00-path-guard.sh
gate "plymouth theme selected"         grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "SELinux config present"          grep -q CONFIG_SECURITY_SELINUX /usr/lib/modules/*/config
gate "login shell with empty PATH finds grep" env -i PATH= HOME=/root /bin/bash -lc 'command -v grep'
[ "$fail" = 0 ] || { echo "::error::image verification failed"; exit 1; }
echo "::endgroup::"
