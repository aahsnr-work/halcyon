# vim: set ft=make :

# Custom ujust recipes for halcyon
# Imported by /usr/share/ublue-os/just/60-custom.just at build time

# Rebase the current system to the published halcyon image
[group("system")]
rebase-to-custom tag="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "Rebasing system to ${IMAGE}..."
    if command -v bootc >/dev/null 2>&1; then
        sudo bootc switch "${IMAGE}"
    elif command -v rpm-ostree >/dev/null 2>&1; then
        sudo rpm-ostree rebase "ostree-unverified-registry:${IMAGE}"
    else
        echo "Neither bootc nor rpm-ostree was detected on this system." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Reboot into the new deployment:  systemctl reboot"
    echo "After reboot, switch to the signed tag (README: Install / rebase):"
    echo "  sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:${{tag}}"

# Install a TeX Live package in user mode into ~/texmf
[group("texlive")]
texlive-install package:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        if [ ! -d "$HOME/texmf" ]; then
            echo "Initializing TeX Live usertree in $HOME/texmf..."
            tlmgr init-usertree
        fi
        echo "Installing TeX Live package '{{package}}' in user mode..."
        tlmgr --usermode install "{{package}}"
        echo "Package '{{package}}' installed successfully into $HOME/texmf."
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi

# Update all user-installed TeX Live packages in ~/texmf
[group("texlive")]
texlive-update:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v tlmgr >/dev/null 2>&1; then
        [ -f /etc/profile.d/texlive.sh ] && . /etc/profile.d/texlive.sh
    fi
    if command -v tlmgr >/dev/null 2>&1; then
        echo "Updating user TeX Live packages in $HOME/texmf..."
        tlmgr --usermode update --all
    else
        echo "tlmgr not found in PATH." >&2
        exit 1
    fi

# Reclaim disk space (Nix garbage collection, Flatpak unused runtimes, journal trim)
[group("system")]
halcyon-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Cleaning up system and user caches ==="
    if command -v nix-collect-garbage >/dev/null 2>&1; then
        echo "Collecting Nix garbage (deleting old generations)..."
        nix-collect-garbage -d || true
    fi
    if command -v flatpak >/dev/null 2>&1; then
        echo "Uninstalling unused Flatpak runtimes..."
        flatpak uninstall --unused -y || true
    fi
    echo "Trimming journald logs (system journal needs privileges)..."
    sudo journalctl --vacuum-time=7d || true
    echo "Cleanup complete!"
