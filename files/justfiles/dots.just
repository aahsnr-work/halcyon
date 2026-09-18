# vim: set ft=make :

# Round-trip edits to the dotfiles repo cloned at ~/Git/configs/dotfiles
# (https://github.com/aahsnr-configs/dotfiles — remote uses the
# github.com-aahsnr-configs SSH host alias)

# Flip the dotfiles origin to SSH (needed after a fresh HTTPS-only clone)
[group("dotfiles")]
dots-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${HOME}/Git/configs/dotfiles"
    git remote set-url origin git@github.com-aahsnr-configs:aahsnr-configs/dotfiles.git
    git remote -v

# Stage, commit and push all dotfiles changes
[group("dotfiles")]
dots-push msg="updated":
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${HOME}/Git/configs/dotfiles"
    git add -A
    git commit -m "{{msg}}"
    git push origin main
    echo "Dotfiles pushed: {{msg}}"

# Show dotfiles branch/status and the last few commits
[group("dotfiles")]
dots-status:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${HOME}/Git/configs/dotfiles"
    git status -sb
    echo
    git log --oneline -5
