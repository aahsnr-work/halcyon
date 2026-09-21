# vim: set ft=make :

# Rebase the current system to the published halcyon image
# (README: Install / rebase — unsigned first, signed tag after reboot)
[group("system")]
rebase-to-custom tag="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "Rebasing system to ${IMAGE}..."
    if command -v bootc >/dev/null 2>&1; then
        sudo bootc switch "${IMAGE}"
    else
        echo "bootc was not detected on this system." >&2
        echo "halcyon is a bootc image — there is no legacy-ostree fallback path." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Reboot into the new deployment:  systemctl reboot"
    echo "After reboot, switch to the signed tag (README: Install / rebase):"
    echo "  sudo bootc switch --enforce-container-sigpolicy ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "  (the image ships /etc/pki/containers/halcyon.pub + a sigstore policy entry — verification is enforced by policy.json)"
