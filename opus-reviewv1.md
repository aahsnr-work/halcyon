Below are full rewrites of every file that needs to change, plus the deletions. I've left `.github/workflows/build.yml`'s action pins as-is — I can't confirm which majors exist as of today, so verify those against each action's releases page rather than taking my word for it.

---

## Deletions

```bash
# Bazzite-fork residue: every target of these four scripts is absent on a
# bare fedora-bootc base. Their useful parts are folded into remove-packages.
git rm build_files/base/guarded-removals
git rm build_files/base/file-footprint
git rm build_files/base/gnome-extensions
git rm build_files/base/fonts-cleanup

# greetd config moves into ctx so it can be installed AFTER the greetd RPM
git mv system_files/shared/etc/greetd/config.toml build_files/desktop/greetd/config.toml
git mv system_files/shared/etc/pam.d/greetd       build_files/desktop/greetd/greetd.pam

# placeholder UUID, never registered
git rm artifacthub-repo.yml
```

---

## `build_files/base/setup-repos`

```bash
#!/usr/bin/env bash
# halcyon build step — setup-repos (RPM Fusion NVIDIA-excluded + negativo17)
#
# Repo lifecycle policy (bazzite pattern + TODO "remove non-fedora repos
# after use"): third-party repos are enabled ONLY inside the stage that
# consumes them and disabled immediately after; finalize deletes every
# leftover repo file. This stage only sets up the two repos that several
# stages share:
#   - RPM Fusion (steam, media, gaming). Its NVIDIA packages are EXCLUDED
#     here — this is the ublue-os/akmods partition: NVIDIA userland/modules
#     come from negativo17 ONLY, so the solver can never pull the
#     conflicting RPM Fusion nvidia chain (xorg-x11-drv-nvidia →
#     nvidia-kmod → akmod-nvidia).
#   - negativo17 fedora-nvidia (NVIDIA userland matching the p03 modules).
#
# COPRs and vendor repos (lionheartp, sneexy, ublue-os/packages, catpieleaf,
# terra, vscode, brave) are handled per-use in their own stages.
#
# jq is installed HERE and not later: packages-lib (sourced by every stage
# from Stage 02 onward, including remove-packages) parses packages.json with
# it. Relying on the base image to ship jq is an unstated dependency that
# breaks silently on a Fedora bump.
set -euo pipefail
echo "::group::setup-repos — build tooling bootstrap"
dnf5 -y --setopt=install_weak_deps=False install \
  dnf5-plugins \
  jq
command -v jq >/dev/null 2>&1 || { echo "  FAIL  jq missing after install — packages.json is unreadable"; exit 1; }
echo "  OK    dnf5-plugins + jq present ($(jq --version))"
echo "::endgroup::"

echo "::group::setup-repos — base external repos"
# RPM Fusion (keys ship in the release RPMs; --nogpgcheck per RPM Fusion practice)
dnf5 -y --setopt=install_weak_deps=False --nogpgcheck install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y --setopt=install_weak_deps=False install \
  rpmfusion-free-appstream-data \
  rpmfusion-nonfree-appstream-data \
  || true
# NVIDIA exclusion on every RPM Fusion repo file (akmods partition)
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
  grep -q '^excludepkgs=' "${f}" || \
    echo "excludepkgs=xorg-x11-drv-nvidia* akmod-nvidia kmod-nvidia* nvidia-settings nvidia-modprobe nvidia-persistenced nvidia-driver-NVML" >> "${f}"
done
# negativo17 NVIDIA userland — the only NVIDIA source in this image
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
echo "::endgroup::"
```

---

## `build_files/base/remove-packages`

```bash
#!/usr/bin/env bash
# halcyon build step — remove-packages (removals FIRST, main's removals.yml ordering)
#
# Removals run against the PRISTINE base before anything is installed:
# dnf computes the removal set from the full Requires graph (file requires,
# rich deps, per-subpackage edges — Fedora splits units into many subpackages
# so name-level reasoning cannot bound the transaction), and autoremove reads
# install-reason state that is least trustworthy late in a build. On the
# untouched base the blast radius is smallest and any cascade that hits core
# tooling fails the build at the very next dnf call — loud, immediate.
# Everything halcyon needs is (re)installed explicitly by later stages.
#
# HISTORY: this stage used to call four helper scripts inherited from the
# Bazzite-fork era (guarded-removals, file-footprint, gnome-extensions,
# fonts-cleanup). On a bare fedora-bootc base every one of their targets is
# absent — no GNOME shell, no Waydroid, no bazzite-bling, no unreferenced
# font RPMs — so they were ~400 lines of no-op whose header comments
# described an ordering that no longer held. The two parts that carried real
# value (the sddm/cage reverse-dependency gate and the must-not-survive
# hard-fail) are folded in below.
set -euo pipefail
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate

echo "::group::remove-packages — proven-present removals (packages.json exclude.all)"
# main pattern: the removal list lives in packages.json (all.exclude.all) and
# is resolved through rpm -qa first, so entries absent from the base are
# tolerated instead of failing the transaction.
readarray -t REMOVAL_CANDIDATES < <(packages_excludes)
PRESENT=()
if [ "${#REMOVAL_CANDIDATES[@]}" -gt 0 ]; then
  readarray -t PRESENT < <(rpm -qa --qf '%{NAME}\n' "${REMOVAL_CANDIDATES[@]}" 2>/dev/null | sort -u || true)
fi
# NOTE: ${#arr[@]} admits no :-default (bash 'bad substitution') — the
# array is initialized unconditionally above instead.
if [ "${#PRESENT[@]}" -gt 0 ]; then
  echo "  INFO  removing ${#PRESENT[@]} present package(s): ${PRESENT[*]}"
  # --no-autoremove here: the base orphan sweep below is the only autoremove
  dnf5 -y remove --no-autoremove "${PRESENT[@]}"
else
  echo "  INFO  nothing from the removal list is installed (clean base)"
fi
echo "::endgroup::"

echo "::group::remove-packages — reverse-dep gated removals (sddm, cage)"
# Display managers the base may pull in transitively. Remove only when
# nothing installed still requires them — halcyon logs in through greetd.
GATED=()
for p in sddm cage; do
  if ! rpm -q "$p" >/dev/null 2>&1; then
    echo "  SKIP  ${p} not installed"
    continue
  fi
  reqs="$(dnf5 -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
  if [ -n "${reqs}" ]; then
    echo "  GATE  keeping ${p} — required by:"
    # shellcheck disable=SC2001  # indenting multi-line output, not a substitution
    echo "${reqs}" | sed 's/^/          /'
  else
    echo "  GATE  removing ${p} — nothing installed requires it"
    GATED+=("$p")
  fi
done
if [ "${#GATED[@]}" -gt 0 ]; then
  dnf5 -y remove --no-autoremove "${GATED[@]}"
fi
echo "::endgroup::"

echo "::group::remove-packages — base orphan sweep"
# smallest graph the build will ever see
dnf5 -y autoremove || true
echo "::endgroup::"

echo "::group::remove-packages — hard-fail verification (must-be-gone)"
# These must NOT survive into the image under any circumstance. Unlike the
# tolerant list above this is a gate: a survivor means the removal
# transaction silently declined and a later stage would ship it.
rc=0
for p in gnome-shell gdm mutter nautilus firefox waydroid inputplumber; do
  if rpm -q "$p" >/dev/null 2>&1; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
    echo "  FAIL  ${p}-${ver} still installed after removals" >&2
    rc=1
  else
    echo "  PASS  ${p} — absent (correct)"
  fi
done
echo "::endgroup::"

# NOTE: keeper verification (steam/gamescope/scx/umu/bazaar/lutris/…) lives
# in final-verify — it must gate the FINAL state, and this stage runs before
# anything is installed.
exit "${rc}"
```

---

## `build_files/desktop/greetd/config.toml`

```toml
[terminal]
vt = 1

[default_session]
# noctalia-greeter: greetd must launch the wrapper (it starts the bundled
# wlroots compositor and runs the greeter inside it), by absolute path —
# per docs.noctalia.dev/greeter. Session list comes from wayland-sessions.
command = "/usr/bin/noctalia-greeter-session"
user = "greetd"
```

---

## `build_files/desktop/greetd/greetd.pam`

```
#%PAM-1.0
# PAM stack for greetd with gnome-keyring auto-unlock support.
auth       include      system-login
account    include      system-login
password   include      system-login
session    include      system-login
session    optional     pam_gnome_keyring.so auto_start
auth       optional     pam_gnome_keyring.so
```

---

## `build_files/desktop/configure-system`

```bash
#!/usr/bin/env bash
# halcyon build step — configure-system (units, services, greetd + chezmoi +
# brew wiring). The ujust machinery, the pyprland unit and the flatpak user
# unit are wired in their own stages; the brew payload is baked in the brew
# stage — this stage enables the seed/catch-up/update units.
set -euo pipefail

echo "::group::configure-system — greetd configuration (post-RPM)"
# These two files are RPM-owned paths (greetd ships /etc/greetd/config.toml
# and /etc/pam.d/greetd). system_files/shared is COPY'd BEFORE any package
# install, so shipping them there meant the Stage 04 greetd install could
# silently overwrite them. Installing from /ctx here — after the package
# exists — makes the final state deterministic instead of ordering-dependent.
install -Dm0644 /ctx/desktop/greetd/config.toml /etc/greetd/config.toml
install -Dm0644 /ctx/desktop/greetd/greetd.pam  /etc/pam.d/greetd
echo "  OK    /etc/greetd/config.toml + /etc/pam.d/greetd installed over the RPM defaults"
echo "::endgroup::"

echo "::group::configure-system — units + services"
# systemd units ship via the system_files overlay (usr/lib/systemd);
# this stage wires enablement only
# system services: greetd (+ tty2 escape hatch), nix (winter pattern: the
# /nix bind mount over the /var/nix store root)
systemctl enable greetd.service getty@tty2.service 2>/dev/null || true
systemctl enable var-nix.service nix.mount 2>/dev/null || true
# input stack: both packages are installed by the gaming group and are
# useless without their units running (bazzite enables both).
systemctl enable input-remapper.service 2>/dev/null || true
# brew: pre-login offline seeding at boot + the blue-build update/upgrade
# timers (payload is baked by build_files/brew/install-brew-bundle)
systemctl enable halcyon-brew-bundle.service 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/halcyon-brew-bundle.service /etc/systemd/system/multi-user.target.wants/halcyon-brew-bundle.service
systemctl enable brew-update.timer brew-upgrade.timer 2>/dev/null || {
  mkdir -p /etc/systemd/system/timers.target.wants
  ln -sf /usr/lib/systemd/system/brew-update.timer /etc/systemd/system/timers.target.wants/brew-update.timer
  ln -sf /usr/lib/systemd/system/brew-upgrade.timer /etc/systemd/system/timers.target.wants/brew-upgrade.timer
}
# masks (same as the BlueBuild services.yml)
for u in sddm.service gdm.service bazzite-autologin.service nvidia-persistenced.service nvidia-powerd.service; do
  ln -sf /dev/null /etc/systemd/system/"$u"
done
# --- global user unit wiring (enabled for every future user, like the
# BlueBuild modules' --global enablement) ---
mkdir -p /etc/systemd/user/default.target.wants /etc/systemd/user/timers.target.wants
# pyprland: Hyprland companion daemon
ln -sf /usr/lib/systemd/user/pyprland.service /etc/systemd/user/default.target.wants/pyprland.service 2>/dev/null || true
# ydotool: uinput daemon the ujust/gaming recipes drive
if [ -f /usr/lib/systemd/user/ydotool.service ]; then
  ln -sf /usr/lib/systemd/user/ydotool.service /etc/systemd/user/default.target.wants/ydotool.service
fi
# chezmoi: first-login init + update timer (blue-build chezmoi module wiring:
# `systemctl --global enable chezmoi-init.service chezmoi-update.timer`)
systemctl --global enable chezmoi-init.service chezmoi-update.timer 2>/dev/null || {
  ln -sf /usr/lib/systemd/user/chezmoi-init.service /etc/systemd/user/default.target.wants/chezmoi-init.service
  ln -sf /usr/lib/systemd/user/chezmoi-update.timer /etc/systemd/user/timers.target.wants/chezmoi-update.timer
}
# brew: per-user online catch-up fallback at first login
ln -sf /usr/lib/systemd/user/brew-bundle.service /etc/systemd/user/default.target.wants/brew-bundle.service
# flatpak: per-user flathub setup at first login (user repo ONLY)
ln -sf /usr/lib/systemd/user/halcyon-flatpak-setup.service /etc/systemd/user/default.target.wants/halcyon-flatpak-setup.service
echo "  INFO  global user-unit wiring:"
find /etc/systemd/user/default.target.wants /etc/systemd/user/timers.target.wants \
  -mindepth 1 -printf '        %p -> %l\n' 2>/dev/null | sort
echo "::endgroup::"
```

---

## `build_files/desktop/image-info`

```bash
#!/usr/bin/env bash
# halcyon build step — image-info (os-release identity + plymouth theme)
# assets. PRETTY_NAME reflects the actual base (MIGRATION-sanctioned
# divergence from main's "halcyon (Bazzite fork)"); HOME_URL matches main.
set -euo pipefail
echo "::group::image-info — os-release + plymouth"
sed -i 's|^NAME=.*|NAME=halcyon|; s|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Fedora bootc)"|' /usr/lib/os-release
if grep -q '^HOME_URL=' /usr/lib/os-release; then
  sed -i 's|^HOME_URL=.*|HOME_URL=https://github.com/aahsnr-work/halcyon|' /usr/lib/os-release
else
  echo 'HOME_URL=https://github.com/aahsnr-work/halcyon' >> /usr/lib/os-release
fi
# plymouth theme assets are generated from the baked astronaut wallpaper.
# NOTE: ctx is flat per build_files subfolder — build-plymouth-assets lives in
# desktop/ next to this script, NOT in branding/ (a stale /ctx/branding/ path
# here used to abort the whole build with `no such file or directory`).
/ctx/desktop/build-plymouth-assets
echo "::endgroup::"

echo "::group::image-info — image-info.json + sigstore policy assets"
# bazzite-steam / bazzite-steam-firstrun / 83-halcyon-audio read this file
install -d /usr/share/ublue-os
cat >/usr/share/ublue-os/image-info.json <<EOF
{ "image-name": "halcyon",
  "image-vendor": "aahsnr-work",
  "image-ref": "ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon",
  "image-tag": "latest",
  "base-image-name": "fedora-bootc",
  "fedora-version": "$(rpm -E %fedora)" }
EOF
chmod 0644 /usr/share/ublue-os/image-info.json

# Signed-rebase support (ublue-os/config pattern): ship the cosign public
# key plus a sigstore policy entry so `bootc switch
# --enforce-container-sigpolicy ostree-image-signed:...` verifies out of the box.
#
# IMPORTANT: the key goes in /etc/pki/containers, NOT /usr/etc. fedora-bootc
# ships a real /etc; creating a parallel /usr/etc tree is exactly what
# `bootc container lint` flags as etc-usretc, which is a FATAL lint and used
# to fail the build one stage after branding-verify passed.
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/halcyon.pub
install -d /etc/containers/registries.d
cat >/etc/containers/registries.d/halcyon.yaml <<'YAML'
docker:
  ghcr.io/aahsnr-work/halcyon:
    use-sigstore-attachments: true
YAML
# policy.json: require our sigstore signature for our image path, accept
# everything else (the bootc default)
cat >/etc/containers/policy.json <<'POLICY'
{
    "default": [{"type": "insecureAcceptAnything"}],
    "transports": {
        "docker": {
            "ghcr.io/aahsnr-work/halcyon": [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/halcyon.pub"}]
        }
    }
}
POLICY
echo "  OK    image-info.json + halcyon.pub + policy.json + registries.d written"
echo "::endgroup::"
```

---

## `build_files/desktop/branding-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — branding level (runs immediately after image-info).
# Adapted from main's branding-verify.sh.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::branding-verify — os-release + plymouth"
gate "os-release NAME=halcyon"           grep -q '^NAME=halcyon' /usr/lib/os-release
gate "os-release PRETTY_NAME"            grep -q '^PRETTY_NAME="halcyon' /usr/lib/os-release
gate "os-release HOME_URL"               grep -q '^HOME_URL=https://github.com/aahsnr-work/halcyon' /usr/lib/os-release
gate "image-info.json present"           test -s /usr/share/ublue-os/image-info.json
gate "sigstore pubkey shipped"           test -s /etc/pki/containers/halcyon.pub
# bootc's etc-usretc lint is fatal: a /usr/etc tree must never exist on a
# base that already ships a real /etc.
gate "no /usr/etc tree created"          sh -c '! test -e /usr/etc'
gate "sigstore policy entry"             grep -q '"type": "sigstoreSigned"' /etc/containers/policy.json
gate "policy keyPath matches shipped key" grep -q '"keyPath": "/etc/pki/containers/halcyon.pub"' /etc/containers/policy.json
gate "registries.d sigstore attachments" grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/halcyon.yaml
gate "plymouth theme selected"           grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "plymouth theme file"               test -f /usr/share/plymouth/themes/halcyon/theme.plymouth
gate "plymouth background asset"         test -f /usr/share/plymouth/themes/halcyon/background.png
gate "plymouth throbber frames"          sh -c 'ls /usr/share/plymouth/themes/halcyon/throbber-*.png >/dev/null 2>&1'
gate "wallpaper baked"                   test -f /usr/share/backgrounds/halcyon/astronaut.png
echo "::endgroup::"
[ "$fail" = 0 ] || { echo "::error::branding-verify failed"; exit 1; }
echo "--- branding-verify: all checks passed ---"
```

---

## `build_files/desktop/system-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — system level (runs immediately after configure-system).
# Adapted from main's files-verify.sh: global user-unit wiring, greetd stack,
# PATH guard regression, default shell.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::system-verify — global user unit wiring"
gate "chezmoi-init enabled --global"     test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer enabled"      test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
gate "brew-bundle fallback --global"     test -L /etc/systemd/user/default.target.wants/brew-bundle.service
gate "greetd enabled"                    systemctl is-enabled greetd.service
gate "tty2 escape hatch enabled"         systemctl is-enabled getty@tty2.service
gate "var-nix enabled"                   systemctl is-enabled var-nix.service
gate "nix.mount enabled"                 systemctl is-enabled nix.mount
gate "brew seeding unit enabled"         systemctl is-enabled halcyon-brew-bundle.service
gate "brew-update.timer enabled"         systemctl is-enabled brew-update.timer
gate "brew-upgrade.timer enabled"        systemctl is-enabled brew-upgrade.timer
gate "pyprland enabled --global"         test -L /etc/systemd/user/default.target.wants/pyprland.service
gate "flatpak setup enabled --global"    test -L /etc/systemd/user/default.target.wants/halcyon-flatpak-setup.service
echo "::endgroup::"

echo "::group::system-verify — greetd + login environment"
# greetd's own RPM owns both paths; configure-system reinstalls ours after
# the package lands, so gate the CONTENT, not merely the file's existence.
gate "greetd config present"             test -f /etc/greetd/config.toml
gate "greetd launches noctalia wrapper"  grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml
gate "greetd runs as greetd user"        grep -qE '^user = "greetd"' /etc/greetd/config.toml
gate "greetd PAM with keyring unlock"    sh -c 'grep -q pam_gnome_keyring.so /etc/pam.d/greetd'
gate "noctalia tmpfiles rule"            test -f /usr/lib/tmpfiles.d/noctalia-greeter-state.conf
gate "PATH guard present"                test -f /etc/profile.d/00-path-guard.sh
gate "halcyon helper PATH export"        grep -q '/usr/libexec/halcyon-image' /etc/profile.d/image-path.sh
gate "brew interactive shell hook"       test -f /etc/profile.d/brew.sh
gate "brew environment.d session PATH"   grep -q 'linuxbrew/.linuxbrew/bin' /etc/environment.d/10-homebrew.conf
gate "brew tmpfiles rules"               grep -q 'var/home/linuxbrew' /usr/lib/tmpfiles.d/zz-halcyon-homebrew.conf
gate "empty-PATH login regression"       env -i PATH= HOME=/root /bin/bash -lc 'command -v grep'
gate "zsh is the default shell"          grep -q 'SHELL=/bin/zsh' /etc/default/useradd
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::system-verify failed"; exit 1; }
echo "--- system-verify: all checks passed ---"
```

---

## `build_files/python-packages/rmi/src/rmi/__init__.py`

```python
"""rmi - Safe Removal Tool.

Python 3.13 port of the original ``rmi`` bash script.

Moves files and directories to the XDG trash directory instead of deleting
them. Name collisions are resolved with GNU-mv style numbered backups: the
item already present in the trash is renamed to ``name.~1~``, ``name.~2~``,
... and the newly trashed item keeps the plain name.
"""

import argparse
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import NoReturn
from urllib.parse import quote

SCRIPT_NAME: str = Path(sys.argv[0]).name or "rmi"
VERSION: str = "2.0.1"

_XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME") or str(
    Path.home() / ".local" / "share"
)
TRASH_DIR: Path = Path(_XDG_DATA_HOME) / "Trash" / "files"
TRASH_INFO_DIR: Path = Path(_XDG_DATA_HOME) / "Trash" / "info"

# Colors are only emitted when stdout is a terminal.
if sys.stdout.isatty():
    COLOR_RED = "\033[0;31m"
    COLOR_GREEN = "\033[0;32m"
    COLOR_YELLOW = "\033[0;33m"
    COLOR_RESET = "\033[0m"
else:
    COLOR_RED = COLOR_GREEN = COLOR_YELLOW = COLOR_RESET = ""

DESCRIPTION = f"""\
A safer alternative to 'rm' that moves files and directories to the XDG
Trash directory instead of permanently deleting them. Files can be restored
using your desktop environment's trash manager or manually from:
{TRASH_DIR}
"""

EPILOG = f"""\
EXAMPLES:
    # Interactive mode (default) - prompts for confirmation
    {SCRIPT_NAME} file.txt document.pdf

    # Force mode - no confirmation prompt
    {SCRIPT_NAME} -f unwanted_file.log

    # Verbose mode - shows where files are moved
    {SCRIPT_NAME} -v old_project/

    # Combined flags
    {SCRIPT_NAME} -f -v *.tmp

    # Trash multiple items at once
    {SCRIPT_NAME} file1.txt file2.txt directory/

    # Names starting with a dash need the end-of-options marker
    {SCRIPT_NAME} -- -weird-name.txt

NOTES:
    - Files are moved to: {TRASH_DIR}
    - If a file with the same name already exists in the trash, numbered
      backups are created (e.g. file.txt, file.txt.~1~, file.txt.~2~)
    - The trash directory itself cannot be trashed
    - Non-existent files are skipped with a warning

SEE ALSO:
    rm(1), mv(1), trash-cli, XDG Base Directory Specification
"""

BACKUP_SUFFIX = re.compile(r"\.~(\d+)~$")


class ArgumentParser(argparse.ArgumentParser):
    """ArgumentParser that exits with status 1 on usage errors.

    argparse exits with 2 by default; the shell version this replaces used 1.
    """

    def error(self, message: str) -> NoReturn:
        self.print_usage(sys.stderr)
        print(f"{self.prog}: error: {message}", file=sys.stderr)
        raise SystemExit(1)


def print_message(color: str, message: str) -> None:
    """Print a colored message to stdout."""
    print(f"{color}{message}{COLOR_RESET}")


def print_error(message: str) -> None:
    """Print a colored error message to stderr."""
    print(f"{COLOR_RED}{message}{COLOR_RESET}", file=sys.stderr)


def next_backup_path(destination: Path) -> Path:
    """Return the next free ``name.~N~`` path next to ``destination``."""
    highest = 0
    prefix = destination.name + ".~"
    try:
        entries = list(destination.parent.iterdir())
    except OSError:
        entries = []
    for entry in entries:
        if not entry.name.startswith(prefix):
            continue
        match = BACKUP_SUFFIX.search(entry.name[len(destination.name) :])
        if match:
            highest = max(highest, int(match.group(1)))
    return destination.parent / f"{destination.name}.~{highest + 1}~"


def write_trashinfo(original: Path, destination: Path) -> None:
    """Write the XDG .trashinfo companion so desktop trash managers can restore.

    The move has already succeeded by the time this runs; a failure here only
    costs restore-tooling support, never the user's data, so every error is
    reported and swallowed.
    """
    try:
        TRASH_INFO_DIR.mkdir(parents=True, exist_ok=True)
        info_path = TRASH_INFO_DIR / f"{destination.name}.trashinfo"
        suffix = 0
        while info_path.exists():
            suffix += 1
            info_path = TRASH_INFO_DIR / f"{destination.name}.~{suffix}~.trashinfo"
        escaped = quote(str(original), safe="/")
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        info_path.write_text(
            "[Trash Info]\n" f"Path={escaped}\n" f"DeletionDate={stamp}\n",
            encoding="utf-8",
        )
    except OSError as exc:
        print_error(
            f"Warning: could not write .trashinfo for '{destination.name}': {exc}"
        )


def move_to_trash(item: Path, verbose: bool) -> bool:
    """Move a single item into the trash, backing up any existing entry."""
    destination = TRASH_DIR / item.name

    # Resolve BEFORE the move: afterwards the original path no longer exists
    # and the .trashinfo Path= field would record the wrong location.
    try:
        original = item.resolve()
    except OSError:
        original = item.absolute()

    try:
        if destination.exists() or destination.is_symlink():
            backup = next_backup_path(destination)
            destination.rename(backup)
            if verbose:
                print(f"backed up '{destination}' -> '{backup}'")
        shutil.move(str(item), str(destination))
    except (OSError, shutil.Error) as exc:
        print_error(f"Error: Failed to move '{item}': {exc}")
        return False

    write_trashinfo(original, destination)

    if verbose:
        print(f"moved '{item}' -> '{destination}'")
    return True


def confirm(prompt: str) -> bool:
    """Ask a y/N question; anything but y/Y means no."""
    try:
        reply = input(prompt)
    except EOFError:
        print()
        return False
    return reply.strip().lower() in ("y", "yes")


def build_parser() -> argparse.ArgumentParser:
    parser = ArgumentParser(
        prog=SCRIPT_NAME,
        usage=f"{SCRIPT_NAME} [OPTIONS] <file1> [file2 ...]",
        description=f"{SCRIPT_NAME} - Safe Removal Tool (Version {VERSION})\n\n"
        + DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "paths",
        nargs="*",
        metavar="FILE",
        help="one or more files or directories to move to trash",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="skip confirmation prompt (non-interactive mode)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show detailed output of operations",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"{SCRIPT_NAME} version {VERSION}",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.paths:
        print_error("Error: No files or directories specified")
        print(f"Usage: {SCRIPT_NAME} [OPTIONS] <file1> [file2 ...]")
        print(f"Try '{SCRIPT_NAME} --help' for more information.")
        return 1

    try:
        TRASH_DIR.mkdir(parents=True, exist_ok=True)
        TRASH_INFO_DIR.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        print_error(f"Error: Cannot create trash directory: {exc}")
        return 1

    if args.verbose:
        print(f"Trash directory: {TRASH_DIR}")

    try:
        trash_realpath = TRASH_DIR.resolve(strict=True)
    except OSError as exc:
        print_error(f"Error: Cannot resolve trash directory: {exc}")
        return 1

    valid_targets: list[Path] = []
    for raw in args.paths:
        item = Path(raw)

        # '.', '..' and '/' have no usable base name; mv refuses these too,
        # and attempting the move would copy before failing.
        if item.name in ("", ".", ".."):
            print_message(
                COLOR_YELLOW,
                f"Warning: Refusing to trash '{raw}': please name the item "
                "explicitly, skipping",
            )
            continue

        # Path.exists() follows symlinks; a broken symlink must still be trashed.
        if not item.exists() and not item.is_symlink():
            print_message(COLOR_YELLOW, f"Warning: '{raw}' does not exist, skipping")
            continue

        try:
            item_realpath = item.resolve()
        except OSError as exc:
            print_message(COLOR_YELLOW, f"Warning: cannot resolve '{raw}': {exc}")
            continue

        if item_realpath == trash_realpath:
            print_message(
                COLOR_YELLOW,
                "Warning: Cannot trash the trash directory itself, skipping",
            )
            continue

        if item_realpath in trash_realpath.parents:
            print_message(
                COLOR_YELLOW,
                f"Warning: Cannot trash '{raw}': it contains the trash "
                "directory, skipping",
            )
            continue

        valid_targets.append(item)

    if not valid_targets:
        print_message(COLOR_YELLOW, "No valid items to trash")
        return 0

    print("Moving to trash:")
    for item in valid_targets:
        print(f"  - {item.name}")

    if not args.force and not confirm("Continue? [y/N]: "):
        print_message(COLOR_YELLOW, "Operation cancelled")
        return 0

    move_count = sum(move_to_trash(item, args.verbose) for item in valid_targets)

    if move_count > 0:
        print_message(
            COLOR_GREEN, f"✓ Successfully moved {move_count} item(s) to trash"
        )
        return 0

    print_error("✗ Failed to move any items")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        sys.exit(130)
```

---

## `build_files/python-packages/rmi/pyproject.toml`

```toml
[build-system]
requires = ["setuptools>=77"]
build-backend = "setuptools.build_meta"

[project]
name = "rmi"
version = "2.0.1"
description = "Safe removal to the XDG trash with collision handling."
requires-python = ">=3.10"
license = "Apache-2.0"

[project.optional-dependencies]
dev = ["pytest"]

[project.scripts]
rmi = "rmi:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

---

## `build_files/python-packages/rmi/tests/test_rmi.py`

```python
"""Tests for the rmi package.

These exist because `rmi -h` — the build-time smoke test — never reaches the
code that actually moves a file. A missing `datetime` import shipped in the
image for exactly that reason: the tool trashed the file, then died with a
NameError while writing the .trashinfo companion.
"""

from __future__ import annotations

from pathlib import Path

import pytest

import rmi


@pytest.fixture(autouse=True)
def isolated_trash(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Point the module's trash constants at a throwaway directory."""
    files = tmp_path / "Trash" / "files"
    info = tmp_path / "Trash" / "info"
    monkeypatch.setattr(rmi, "TRASH_DIR", files)
    monkeypatch.setattr(rmi, "TRASH_INFO_DIR", info)
    return files, info


def test_move_to_trash_writes_trashinfo(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)

    target = tmp_path / "doc.txt"
    target.write_text("hello\n", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "doc.txt").read_text(encoding="utf-8") == "hello\n"
    assert not target.exists()

    written = (info / "doc.txt.trashinfo").read_text(encoding="utf-8")
    assert written.startswith("[Trash Info]\n")
    assert "Path=" in written
    assert "DeletionDate=" in written


def test_trashinfo_records_the_original_path(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)

    nested = tmp_path / "sub"
    nested.mkdir()
    target = nested / "note.md"
    target.write_text("x", encoding="utf-8")
    original = str(target.resolve())

    rmi.move_to_trash(target, verbose=False)

    written = (info / "note.md.trashinfo").read_text(encoding="utf-8")
    # The path recorded must be where the file CAME FROM, not where it went.
    assert "sub" in written
    assert "Trash" not in written.split("Path=", 1)[1].splitlines()[0]
    assert original.endswith("sub/note.md")


def test_collision_creates_numbered_backup(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)
    (files / "dup.txt").write_text("old", encoding="utf-8")

    target = tmp_path / "dup.txt"
    target.write_text("new", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "dup.txt").read_text(encoding="utf-8") == "new"
    assert (files / "dup.txt.~1~").read_text(encoding="utf-8") == "old"


def test_main_refuses_dot_and_missing_paths(tmp_path: Path, isolated_trash):
    assert rmi.main(["-f", ".", str(tmp_path / "nope.txt")]) == 0


def test_main_with_no_arguments_returns_1():
    assert rmi.main([]) == 1
```

---

## `build_files/runtime/ujust-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — ujust level (runs immediately after setup-ujust).
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::ujust-verify — machinery + module registration"
gate "ujust wrapper present"             test -x /usr/bin/ujust
gate "ujust lib helpers present"         test -f /usr/lib/ujust/ujust.sh
gate "shared justfile present"           test -f /usr/share/ublue-os/justfile
gate "base modules present"              test -f /usr/share/ublue-os/just/00-default.just
gate "vendored halcyon modules present"  test -f /usr/share/ublue-os/just/80-halcyon.just
gate "60-custom import hook written"     test -f /usr/share/ublue-os/just/60-custom.just
gate "60-custom imports halcyon modules" grep -q 'halcyon-rebase.just' /usr/share/ublue-os/just/60-custom.just
gate "60-custom imports bazzite modules" grep -q '80-halcyon.just' /usr/share/ublue-os/just/60-custom.just
gate "justfile imports 60-custom"        grep -q '60-custom.just' /usr/share/ublue-os/justfile
gate "uupd installed"                    rpm -q uupd
gate "uupd.timer unit present"           test -f /usr/lib/systemd/system/uupd.timer
gate "ujust recipes resolve"             ujust --list >/dev/null 2>&1
echo "::endgroup::"

echo "::group::ujust-verify — interactive chooser (ujust --choose)"
# `ujust --choose` shells out to `just --choose`, whose default chooser is
# fzf. Gate the binary AND that the installed just understands the flag, so
# the first-boot menu can never come up broken.
gate "fzf installed (chooser)"           rpm -q fzf
gate "just supports --choose"            sh -c 'just --help 2>&1 | grep -q -- --choose'
# shellcheck disable=SC2016
gate "ujust list output non-empty"       sh -c '[ -n "$(ujust --list 2>/dev/null)" ]'
echo "::endgroup::"

echo "::group::ujust-verify — runtime binaries the recipes shell out to"
# ujust.sh defines Choose/ugum as WRAPPERS around the `gum` binary — the
# function shipping in ublue-os-just is not the same thing as gum being
# installed. Without these every interactive prompt in the image is a no-op
# or an error, which is not detectable from `ujust --list`.
gate "gum (Choose / ugum backend)"       command -v gum
gate "grubby (kernel-arg recipes)"       command -v grubby
gate "ethtool (wol recipe)"              command -v ethtool
gate "wget (audio HRTF download)"        command -v wget
gate "hostname (ssh recipe)"             command -v hostname
gate "fpaste (get-logs recipe)"          command -v fpaste
gate "wl-copy (get-logs recipe)"         command -v wl-copy
gate "zenity (steam wrappers)"           command -v zenity
gate "jq (image-info consumers)"         command -v jq
echo "::endgroup::"

echo "::group::ujust-verify — no rpm-ostree in any recipe (this is bootc)"
# shellcheck disable=SC2016
gate "recipes are rpm-ostree free"       sh -c '! grep -rln "rpm-ostree" /usr/share/ublue-os/just/*.just 2>/dev/null | grep -q .'
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::ujust-verify failed"; exit 1; }
echo "--- ujust-verify: all checks passed ---"
```

> Note: `80-halcyon.just`'s `get-logs` recipe falls back to `rpm-ostree status` only when `bootc` is absent, so the last gate will fail until that fallback branch is removed. Drop the `else` arm of that `command -v bootc` check — on this image `bootc` is always present and the fallback is dead code that trips the guard.

---

## `build_files/brew/brew-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — brew level (runs immediately after install-brew-bundle in
# the same RUN, so the payload install-brew-bundle bakes must already exist).
# Mirrors main's brew-verify.sh: Brewfile + baked payload + per-formula pour
# receipts + "no /var state in the layer" + unit/helper/env wiring.
set -euo pipefail

fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

PAYLOAD=/usr/share/halcyon/brew-bundle.tar.zst
BREWFILE=/usr/share/ublue-os/homebrew/Brewfile

echo "::group::brew-verify — Brewfile + baked payload"
gate "Brewfile staged"                    test -f "${BREWFILE}"
formula_count=$(grep -cE '^[[:space:]]*brew "?[^" ]+"?' "${BREWFILE}" || true)
echo "  INFO  ${BREWFILE}: ${formula_count} formulas"
gate "Brewfile non-empty"                 test "${formula_count}" -gt 0

gate "brew payload present"               test -s "${PAYLOAD}"
if [ -s "${PAYLOAD}" ]; then
  size=$(du -h "${PAYLOAD}" | cut -f1)
  PAYLIST="$(mktemp)"
  PAYLIST_LONG="$(mktemp)"
  trap 'rm -f "${PAYLIST}" "${PAYLIST_LONG}"' EXIT
  tar --zstd -tf "${PAYLOAD}" >"${PAYLIST}"
  tar --zstd -tvf "${PAYLOAD}" >"${PAYLIST_LONG}"
  entries=$(wc -l <"${PAYLIST}")
  echo "  INFO  payload: ${size}, ${entries} entries"
  gate "payload carries brew core"        grep -qF 'home/linuxbrew/.linuxbrew/bin/brew' "${PAYLIST}"

  # brew-update.service and brew-upgrade.service both gate on
  # ConditionPathIsSymbolicLink=/home/linuxbrew/.linuxbrew/bin/brew. If the
  # payload ever carries a regular file there, BOTH timers skip forever and
  # nothing ever reports it. Assert the link survives the pack.
  gate "bin/brew is a symlink in payload" \
    grep -qE '^l.*home/linuxbrew/\.linuxbrew/bin/brew ->' "${PAYLIST_LONG}"

  echo "--- Checking every Brewfile formula is inside the payload ---"
  # "Inside" means a COMPLETE pour: Cellar/<name>/<version>/INSTALL_RECEIPT.json.
  # NOTE: use grep -c (no -q, no early exit) for the two-stage match — a
  # `grep | grep -q` pipeline under pipefail can fail with SIGPIPE (141) when
  # the upstream grep is still emitting later matches after the -q grep has
  # already found its first match and exited. That false negative is exactly
  # what failed a main-branch CI run for btop/chafa/gnuplot.
  missing=0
  while IFS= read -r name; do
    [ -z "${name}" ] && continue
    receipts=$(grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | grep -cF "INSTALL_RECEIPT.json" || true)
    if [ "${receipts}" -gt 0 ]; then
      echo "  PASS  payload contains a complete pour of Cellar/${name} (${receipts} receipt(s))"
    else
      echo "  FAIL  Cellar/${name} not found (complete) in payload — payload entries for it:"
      grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | head -5 | sed 's/^/        /' || true
      missing=$((missing + 1))
    fi
  done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
  if [ "${missing}" -gt 0 ]; then
    echo "  FAIL  ${missing} formula(s) missing from the payload"
    fail=1
  fi
fi
echo "::endgroup::"

echo "::group::brew-verify — payload carries only what Fedora does not ship"
# The Brewfile is deliberately trimmed to formulas with no RPM in this image
# (bun/pixi/opencode). Anything else is poured, shipped and then shadowed on
# PATH forever, because environment.d APPENDS the brew dirs by design.
dupes=0
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  case "${name}" in
    bun|pixi|opencode) continue ;;
  esac
  echo "  WARN  ${name} is in the Brewfile but not on the no-RPM allowlist — confirm Fedora/Terra really lacks it"
  dupes=$((dupes + 1))
done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
[ "${dupes}" -eq 0 ] && echo "  OK    no RPM-shadowed formulas in the Brewfile"
echo "::endgroup::"

echo "::group::brew-verify — no /var state in the layer"
gate "no /home/linuxbrew in the layer"    test ! -e /home/linuxbrew
gate "no /var/home/linuxbrew in layer"    test ! -e /var/home/linuxbrew
gate "no build HOME residue"              test ! -e /var/tmp/brew-build-home
echo "::endgroup::"

echo "::group::brew-verify — units + runtime helpers + environment wiring"
gate "system seeding unit"                test -f /usr/lib/systemd/system/halcyon-brew-bundle.service
gate "user fallback unit"                 test -f /usr/lib/systemd/user/brew-bundle.service
gate "brew-update.service"                test -f /usr/lib/systemd/system/brew-update.service
gate "brew-update.timer"                  test -f /usr/lib/systemd/system/brew-update.timer
gate "brew-upgrade.service"               test -f /usr/lib/systemd/system/brew-upgrade.service
gate "brew-upgrade.timer"                 test -f /usr/lib/systemd/system/brew-upgrade.timer
gate "boot-time extractor shipped"        test -x /usr/libexec/halcyon-image/brew-bundle-extract
gate "login fallback shipped"             test -x /usr/libexec/halcyon-image/brew-bundle-install
gate "environment.d brew PATH"            grep -q 'HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew' /etc/environment.d/10-homebrew.conf
gate "profile.d interactive hook"         test -f /etc/profile.d/brew.sh
gate "tmpfiles rules"                     grep -q 'var/home/linuxbrew' /usr/lib/tmpfiles.d/zz-halcyon-homebrew.conf
echo "::endgroup::"

[ "${fail}" -eq 0 ] || { echo "::error::brew-verify failed"; exit 1; }
echo "--- brew-verify: all checks passed ---"
```

---

## `system_files/shared/usr/share/ublue-os/homebrew/Brewfile`

```ruby
# halcyon Brewfile — ONLY formulas Fedora and Terra do not ship.
#
# Everything else (bat, btop, cava, chafa, direnv, dust, eza, fd, fzf,
# gnuplot, lazygit, pandoc, ripgrep, starship, tealdeer, uv, yazi, zellij,
# atuin) is installed as an RPM by install-devtools / install-terra. The
# environment.d wiring APPENDS the brew bin dirs so RPMs keep PATH priority
# — a brewed duplicate can therefore never be the binary that runs. Pouring
# it anyway costs build time (22 pours × up to 3 retries) and payload size
# (~87k files extracted at every boot by halcyon-brew-bundle.service) for a
# binary nobody can reach.
#
# Before adding a formula here, run the verify-package-availability skill:
# if an RPM exists in Fedora or Terra, it belongs in packages.json instead.
brew "bun"
brew "pixi"
brew "opencode"
```

---

## `system_files/shared/usr/lib/systemd/system/brew-update.service`

```ini
[Unit]
Description=Auto-update Brew binary (formula metadata)
After=local-fs.target
After=network-online.target
# ublue-os/brew gates on bin/brew being a SYMLINK (into Homebrew/bin/brew).
# halcyon restores the prefix from a tarball via `cp -R -n`, which preserves
# links — brew-verify asserts the link survives the pack so this condition
# cannot silently skip forever. Executability is also required: a dangling
# link would satisfy the symlink test alone.
ConditionPathIsSymbolicLink=/home/linuxbrew/.linuxbrew/bin/brew
ConditionPathExists=/home/linuxbrew/.linuxbrew/bin/brew

[Service]
User=1000
Type=oneshot
Environment=HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
Environment=HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
Environment=HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
Environment=HOMEBREW_NO_ANALYTICS=1
Environment=HOMEBREW_NO_ENV_HINTS=1
ExecStart=/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew update"
```

---

## `system_files/shared/usr/lib/systemd/system/brew-upgrade.service`

```ini
[Unit]
Description=Auto-upgrade Brew packages
After=local-fs.target
After=network-online.target
# See brew-update.service for why both conditions are present.
ConditionPathIsSymbolicLink=/home/linuxbrew/.linuxbrew/bin/brew
ConditionPathExists=/home/linuxbrew/.linuxbrew/bin/brew

[Service]
User=1000
Type=oneshot
Environment=HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
Environment=HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
Environment=HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
Environment=HOMEBREW_NO_ANALYTICS=1
Environment=HOMEBREW_NO_ENV_HINTS=1
ExecStart=/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew upgrade"
# Unlink formulas that shadow system tools (ublue-os/brew design decision —
# the same ExecStartPost guards ship in ublue-os/brew's brew-upgrade.service):
# a brew-provided systemd/dbus/bash/rpm would otherwise override the Fedora
# binaries the image and its units rely on.
ExecStartPost=-/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew unlink systemd"
ExecStartPost=-/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew unlink dbus"
ExecStartPost=-/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew unlink gsettings"
ExecStartPost=-/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew unlink bash"
ExecStartPost=-/usr/bin/bash -c "/home/linuxbrew/.linuxbrew/bin/brew unlink rpm"
```

---

## `build_files/finish/final-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — FINAL cross-cutting gates. Stage-scoped checks live in
# their per-level companions (packages/nix/flatpaks/built-apps/ujust/system/
# branding-verify); this script gates what only the finished image can answer:
# the p03 kernel + NVIDIA end state, the third-party repo sweep, the gaming
# keeper set, and the baked package census.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::final-verify — p03 kernel + NVIDIA end state"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
# the COPR kmod package's %{VERSION} is the KERNEL version — the DRIVER
# version lives in the module metadata, which is what the userland must match
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"
gate "p03 kernel installed"              rpm -q kernel-p03
gate "nvidia-open built for p03"         rpm -q kernel-p03-nvidia-open
gate "stock kernel absent"               sh -c '! rpm -q kernel >/dev/null 2>&1'
gate "p03 vmlinuz"                       test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "p03 initramfs"                     test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "nvidia modules for p03"            sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config"          grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked"      sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
# NV_MOD_VER must be non-empty: `test "" = ""` would otherwise PASS when
# modinfo failed, turning the single most important NVIDIA gate into a no-op.
gate "nvidia module version readable"    test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules"   test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present"                test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs"         rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
echo "::endgroup::"

echo "::group::final-verify — gaming keeper set (final state)"
gate "gaming keeper packages"            sh -c 'rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal lutris gamescope input-remapper usbip'
gate "steam installed"                   rpm -q steam
gate "bazzite-steam wrapper"             test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam"    grep -q 'bazzite-steam' /usr/share/applications/steam.desktop
gate "devtools (terra + fedora)"         sh -c "rpm -q zed starship yazi zellij golang-github-jesseduffield-lazygit bat eza fzf pandoc-cli chezmoi"
gate "editors present"                   sh -c 'rpm -q neovim emacs-pgtk'
echo "::endgroup::"

echo "::group::final-verify — repo end state"
# finalize DELETES every third-party repo file, so the old
# "terra repos all disabled" gate matched an empty glob and could never fail.
# The single gate below is the real property: nothing but Fedora remains.
gate "only Fedora repo files remain"     sh -c '! ls /etc/yum.repos.d/ | grep -Eqi "copr|vscode|brave|terra|negativo|rpmfusion"'
gate "repo dir is non-empty (Fedora)"    sh -c 'ls /etc/yum.repos.d/ | grep -q fedora'
echo "::endgroup::"

echo "::group::final-verify — homebrew + chezmoi end state"
gate "brew payload baked in /usr"        test -s /usr/share/halcyon/brew-bundle.tar.zst
gate "brew seeding unit enabled"         systemctl is-enabled halcyon-brew-bundle.service
gate "brew helpers shipped"              sh -c 'test -x /usr/libexec/halcyon-image/brew-bundle-extract && test -x /usr/libexec/halcyon-image/brew-bundle-install'
gate "Brewfile shipped"                  sh -c 'test -f /usr/share/ublue-os/homebrew/Brewfile && grep -q "^brew " /usr/share/ublue-os/homebrew/Brewfile'
gate "chezmoi installed"                 rpm -q chezmoi
gate "chezmoi-init wired --global"       test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer wired"        test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

echo "::group::final-verify — bootc filesystem invariants"
# These mirror the fatal bootc lints. Catching them here names the offending
# path; catching them in Stage 17 only names the lint.
gate "no /usr/etc tree"                  sh -c '! test -e /usr/etc'
gate "/var/run is a symlink to /run"     sh -c 'test -L /var/run'
gate "/boot is empty"                    sh -c '[ -z "$(ls -A /boot 2>/dev/null)" ]'
gate "no /opt content"                   sh -c '[ ! -d /opt ] || [ -z "$(ls -A /opt 2>/dev/null)" ]'
echo "::endgroup::"

# --- package census (distinctively reported in CI; baked into the image) ---
echo "::group::final-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "  ############################################"
echo "  INFO  total installed RPM packages: ${TOTAL_PACKAGES}"
echo "  ############################################"
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
gate "package census baked"              test -s /usr/share/halcyon/package-count
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::final-verify failed"; exit 1; }
echo "--- final-verify: all checks passed ---"
```

---

## `build_files/finish/finalize`

```bash
#!/usr/bin/env bash
# halcyon build step — finalize (repo sweep + end-of-build hygiene).
#
# Mirrors bazzite's finalize: every consuming stage already disabled its
# third-party repos — this is the belt-and-braces sweep plus the end-of-build
# hygiene (keepcache=0, skip_if_unavailable, /tmp + log + /boot wipes for the
# bootc lints). The shipped image carries NO third-party repo files — updates
# arrive via image rebuilds (bootc); any repo can be re-enabled at runtime.
set -euo pipefail
echo "::group::finalize — third-party repo sweep"
rm -f /etc/yum.repos.d/_copr*:*.repo /etc/yum.repos.d/_copr*.repo \
      /etc/yum.repos.d/vscode.repo \
      /etc/yum.repos.d/brave-browser*.repo \
      /etc/yum.repos.d/terra*.repo \
      /etc/yum.repos.d/fedora-nvidia.repo \
      /etc/yum.repos.d/negativo17*.repo \
      /etc/yum.repos.d/rpmfusion-*.repo
echo "  INFO  remaining repo files (Fedora only):"
ls /etc/yum.repos.d/
echo "::endgroup::"

echo "::group::finalize — end-of-build hygiene (bazzite finalize pattern)"
dnf5 config-manager setopt keepcache=0
dnf5 config-manager setopt skip_if_unavailable=1
find /tmp -mindepth 1 -delete 2>/dev/null || true
rm -f /var/log/dnf5.log /var/log/dnf5.log.* || true
# find(1) instead of `rm -rf /boot/*` globs: identical end state (empty /boot),
# no dotted-glob edge cases, and shellcheck-clean
find /boot -mindepth 1 -delete 2>/dev/null || true
rm -rf /var/cache/libdnf5/* || true
# /var must be EMPTY in the layer. The previous version ended with
# `install -d -m1777 /var/tmp`, which put a directory back under /var with no
# matching tmpfiles.d entry — the var-tmpfiles lint. It only ever passed
# because the Containerfile runs `bootc container lint` without
# --fatal-warnings. The base's tmp.conf carries `q /var/tmp 1777 root root -`,
# so systemd-tmpfiles recreates it at boot with the right mode anyway.
rm -rf /var/tmp || true
rm -rf /var/cache/dnf || true
echo "  INFO  keepcache=0, skip_if_unavailable=1, /tmp + logs + /boot + caches + /var/tmp cleared"
echo "  INFO  remaining /var content (must be empty or tmpfiles-owned):"
find /var -mindepth 1 -maxdepth 2 2>/dev/null | sed 's/^/        /' || true
echo "::endgroup::"
```

---

## `build_files/apps/install-texlive`

Only the tail changed (`exit 1` instead of `exit 0`, and the log now names the real scheme), but here's the whole file:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-texlive — setup"
TEXLIVE_INSTALL_DIR="/usr/lib/texlive"
mkdir -p "${TEXLIVE_INSTALL_DIR}"
echo "  INFO  install dir: ${TEXLIVE_INSTALL_DIR}"

# Additional TeX Live packages to install via tlmgr at build time.
# Add any individual packages here that you would like baked into the immutable image.
EXTRA_TL_PACKAGES=(
  latexmk
  biber
)
echo "  INFO  extra tlmgr packages: ${EXTRA_TL_PACKAGES[*]}"

TEXLIVE_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${TEXLIVE_TMP}"; rm -rf "${TEXLIVE_TMP}"' EXIT
echo "::endgroup::"

echo "::group::install-texlive — download installer"
echo "--- Fetching install-tl-unx.tar.gz ---"
# install-tl verifies downloads against TeX Live's GPG signatures by default
# (install-tl manual) as long as gpg is present — keep it that way; never pass
# --no-verify-downloads. gnupg2 is an explicit packages.json entry for exactly
# this reason: without it the installer silently downgrades to unverified.
if ! command -v gpg >/dev/null 2>&1; then
  echo "  FAIL  gpg not found in PATH — install-tl would skip signature verification" >&2
  echo "        gnupg2 must be installed by install-packages before this stage" >&2
  echo "::endgroup::"
  exit 1
fi
# mirror.ctan.org is a redirector that lands on a RANDOM CTAN mirror; some
# mirrors intermittently serve broken TLS chains, which aborts curl with a
# certificate error (--retry does not retry those). Try pinned reliable
# mirrors in order instead. Keep this list in sync with the -repository used
# for the installer run below.
TEXLIVE_MIRRORS=(
  "https://mirrors.mit.edu/CTAN/systems/texlive/tlnet"
  "https://ftp.fau.de/ctan/systems/texlive/tlnet"
  "https://ctan.math.illinois.edu/systems/texlive/tlnet"
  "https://mirror.ctan.org/systems/texlive/tlnet"
)
TARBALL=""
TL_REPO=""
for mirror in "${TEXLIVE_MIRRORS[@]}"; do
  echo "  INFO  trying ${mirror}"
  if curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors --max-time 600 --progress-bar \
      "${mirror}/install-tl-unx.tar.gz" -o "${TEXLIVE_TMP}/install-tl-unx.tar.gz"; then
    if gzip -t "${TEXLIVE_TMP}/install-tl-unx.tar.gz" 2>/dev/null; then
      TARBALL="${TEXLIVE_TMP}/install-tl-unx.tar.gz"
      TL_REPO="${mirror}"
      echo "  OK    downloaded install-tl-unx.tar.gz from ${mirror}"
      break
    fi
    echo "  WARN  tarball from ${mirror} failed the gzip integrity check — trying next mirror"
  else
    echo "  WARN  download from ${mirror} failed — trying next mirror"
  fi
done
if [ -z "${TARBALL}" ] || [ -z "${TL_REPO}" ]; then
  echo "  FAIL  Could not download install-tl-unx.tar.gz from any TeX Live mirror" >&2
  echo "::endgroup::"
  exit 1
fi
size=$(du -h "${TEXLIVE_TMP}/install-tl-unx.tar.gz" | cut -f1)
echo "  OK    downloaded install-tl-unx.tar.gz (${size})"

tar -xzf "${TEXLIVE_TMP}/install-tl-unx.tar.gz" -C "${TEXLIVE_TMP}"
echo "  OK    installer archive extracted"

INSTALLER="$(find "${TEXLIVE_TMP}" -mindepth 2 -maxdepth 2 -name 'install-tl' -type f -perm /111 | head -n1)"
if [[ -z "${INSTALLER}" || ! -x "${INSTALLER}" ]]; then
  echo "  FAIL  install-tl executable not found under ${TEXLIVE_TMP}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    install-tl found at ${INSTALLER}"
echo "::endgroup::"

echo "::group::install-texlive — write profile & run install-tl"
TL_SCHEME="scheme-small"
cat >"${TEXLIVE_TMP}/texlive.profile" <<EOF
selected_scheme ${TL_SCHEME}
TEXDIR ${TEXLIVE_INSTALL_DIR}
TEXMFLOCAL ${TEXLIVE_INSTALL_DIR}/texmf-local
TEXMFSYSVAR ${TEXLIVE_INSTALL_DIR}/texmf-var
TEXMFSYSCONFIG ${TEXLIVE_INSTALL_DIR}/texmf-config
instopt_adjustpath 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
echo "  OK    texlive.profile written (${TL_SCHEME}, no docs/src)"

echo "--- Running install-tl (this may take several minutes) ---"
if "${INSTALLER}" \
  -profile "${TEXLIVE_TMP}/texlive.profile" \
  -no-interaction \
  -repository "${TL_REPO}"; then
  echo "  OK    install-tl completed successfully"
else
  echo "  FAIL  install-tl exited non-zero" >&2
  exit 1
fi
echo "::endgroup::"

echo "::group::install-texlive — tlmgr extras & PATH setup"
TEXLIVE_BINDIR="$(find "${TEXLIVE_INSTALL_DIR}" -maxdepth 3 -type d -name 'x86_64-linux' | head -n1)"
if [ -z "${TEXLIVE_BINDIR}" ]; then
  # HARD failure: built-apps-verify gates on
  # /usr/lib/texlive/bin/x86_64-linux/pdflatex and /etc/profile.d/texlive.sh,
  # so exiting 0 here just moved the failure one stage later where it looked
  # unrelated to TeX Live.
  echo "  FAIL  Could not locate x86_64-linux bin dir under ${TEXLIVE_INSTALL_DIR}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    TeX Live bin dir: ${TEXLIVE_BINDIR}"

if [ ${#EXTRA_TL_PACKAGES[@]} -gt 0 ]; then
  echo "--- Installing extra packages via tlmgr: ${EXTRA_TL_PACKAGES[*]} ---"
  if "${TEXLIVE_BINDIR}/tlmgr" \
    --repository "${TL_REPO}" \
    install "${EXTRA_TL_PACKAGES[@]}"; then
    echo "  OK    extra packages installed: ${EXTRA_TL_PACKAGES[*]}"
  else
    echo "  FAIL  tlmgr extra package install exited non-zero" >&2
    echo "::endgroup::"
    exit 1
  fi
fi

install -d /etc/profile.d
cat >/etc/profile.d/texlive.sh <<EOF
# TeX Live (installed under /usr/lib/texlive during image build)
export PATH="${TEXLIVE_BINDIR}:\$PATH"
export MANPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/man:\${MANPATH:-}"
export INFOPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/info:\${INFOPATH:-}"
EOF
chmod 644 /etc/profile.d/texlive.sh
echo "  OK    /etc/profile.d/texlive.sh written"

install_size=$(du -sh "${TEXLIVE_INSTALL_DIR}" | cut -f1)
echo "  OK    TeX Live (${TL_SCHEME}) installed to ${TEXLIVE_INSTALL_DIR} (${install_size})"
echo "--- install-texlive complete ---"
echo "::endgroup::"
```

---

## `build_files/apps/install-built-apps`

```bash
#!/usr/bin/env bash
# halcyon build step — install-built-apps (obsidian/zotero/pyprland/texlive/python)
# The BlueBuild build-scripts module equivalent; retired as halcyon-packages
# RPMs land (MIGRATION §8.2/8.5/8.6 and §8.7). The python-packages sources are
# staged from the ctx mount to the path install-python-packages expects (the
# build-scripts.yml equivalent of `files: python-packages -> /usr/src`),
# because /ctx is read-only and pip's egg_info step writes into the source tree.
set -euo pipefail
echo "::group::install-built-apps — obsidian/zotero/pyprland/texlive/python"
rm -rf /usr/src/python-packages
cp -a /ctx/python-packages /usr/src/python-packages
/ctx/apps/install-obsidian
/ctx/apps/install-zotero
/ctx/apps/install-pyprland
/ctx/apps/install-texlive
/ctx/apps/install-python-packages
rm -rf /usr/src/python-packages
echo "::endgroup::"
```

---

## `packages.json`

```json
{
  "_docs": {
    "purpose": "Single source of truth for every dnf-managed package in the image (ublue-os/main packages.json style, adapted to halcyon's per-use repo policy).",
    "how-to-add": "Add the package name to the group whose REPO WINDOW it resolves in — not the group whose subject matter it fits. The stage that consumes that group handles repo enable/disable and flags. Groups map 1:1 to build stage scripts (see build_files/packages-lib).",
    "groups": {
      "fedora-core": "Desktop/base packages from Fedora repos (install-packages). The @custom-environment comps group stays hardcoded in install-packages (comps groups are not catalog entries).",
      "fedora-hardware": "Firmware/microcode/audio/32-bit-GL support (install-packages).",
      "fedora-editors": "Editors and language runtimes from Fedora (install-packages). Split out of vendor-apps, which they were never resolved from — they only worked because they happened to install inside the vscode/brave repo window.",
      "hyprland-copr": "Resolved from COPR lionheartp/Hyprland (install-packages). Weak deps are OFF — list every stack weak dep explicitly.",
      "gaming": "RPM Fusion + Fedora gaming packages (install-packages).",
      "bazaar-copr": "Resolved from COPR ublue-os/packages (install-packages).",
      "zen-copr": "Resolved from COPR sneexy/zen-browser (install-packages).",
      "vendor-apps": "Resolved from the per-use vendor repos written inside install-packages (vscode, brave) — NOTHING ELSE belongs here.",
      "vendor-apps-optional": "Installed with skip-unavailable semantics (may be absent from the vendor repo).",
      "fedora-devtools": "Former brew formulas available in Fedora (install-devtools).",
      "nix": "Winter-pattern nix packages (install-nix).",
      "flatpak": "The flatpak stack itself (setup-flatpaks); libnotify covers notify-send.",
      "ujust-copr": "ublue-os-just machinery + uupd from COPR ublue-os/packages (setup-ujust).",
      "ujust-fedora": "Fedora companions of the ujust tooling (setup-ujust). gum backs Choose/ugum in ujust.sh; grubby + grub2-tools back every kernel-arg and GRUB recipe; ethtool backs wol; wget backs the audio HRTF download.",
      "terra": "Resolved EXCLUSIVELY from Terra repos (install-terra uses --disablerepo='*'). terra-release/-mesa/-multimedia are repo bootstrap and stay hardcoded there.",
      "exclude-all": "The 'exclude' block drives remove-packages (Stage 2); entries are resolved through rpm -qa first, so absent names are tolerated."
    },
    "build-tool-dependencies": "zstd, util-linux-core (setpriv), gcc-c++, git, curl and jq are hard preconditions of install-brew-bundle; gnupg2 is a hard precondition of install-texlive's signature verification. They are listed in fedora-core deliberately — do not remove them as 'unused'."
  },
  "all": {
    "include": {
      "fedora-core": [
        "accountsservice",
        "adw-gtk3-theme",
        "bleachbit",
        "bluez",
        "bluez-libs",
        "bluez-tools",
        "brightnessctl",
        "cargo",
        "cmake",
        "cronie",
        "curl",
        "ddcutil",
        "distrobox",
        "ethtool",
        "fail2ban",
        "fastfetch",
        "file-roller",
        "flatseal",
        "fontconfig",
        "fonts-filesystem",
        "gcc-c++",
        "git",
        "gnupg2",
        "go",
        "grim",
        "gsettings-desktop-schemas",
        "gtk4-layer-shell",
        "gzip",
        "hostname",
        "hunspell",
        "hunspell-en",
        "hunspell-en-GB",
        "hunspell-en-US",
        "ImageMagick",
        "imv",
        "inotify-tools",
        "jetbrains-mono-fonts",
        "google-noto-emoji-fonts",
        "google-noto-color-emoji-fonts",
        "just",
        "liberation-fonts",
        "libinput-utils",
        "logrotate",
        "lynis",
        "man-db",
        "mpv",
        "ninja-build",
        "pipx",
        "pkgconf-pkg-config",
        "plymouth",
        "plymouth-theme-spinner",
        "podman",
        "podman-sequoia",
        "policycoreutils-python-utils",
        "pymol",
        "python3-xlib",
        "qt5ct",
        "setroubleshoot-server",
        "setroubleshoot-plugins",
        "setools-console",
        "slurp",
        "sqlite",
        "swappy",
        "transmission-gtk",
        "udica",
        "udiskie",
        "util-linux-core",
        "wget",
        "xdg-desktop-portal",
        "xdg-user-dirs",
        "xdg-user-dirs-gtk",
        "xorg-x11-server-Xwayland",
        "xorg-x11-xauth",
        "zathura",
        "zathura-pdf-poppler",
        "zathura-plugins-all",
        "zstd",
        "zsh"
      ],
      "fedora-hardware": [
        "linux-firmware",
        "microcode_ctl",
        "amd-ucode-firmware",
        "amd-gpu-firmware",
        "intel-gpu-firmware",
        "nvidia-gpu-firmware",
        "atheros-firmware",
        "realtek-firmware",
        "iwlwifi-dvm-firmware",
        "iwlwifi-mvm-firmware",
        "alsa-firmware",
        "alsa-sof-firmware",
        "alsa-ucm",
        "NetworkManager-wifi",
        "wpa_supplicant",
        "pipewire",
        "pipewire-alsa",
        "pipewire-pulseaudio",
        "wireplumber",
        "pcsc-lite",
        "pcsc-lite-ccid",
        "mesa-dri-drivers",
        "mesa-vulkan-drivers",
        "mesa-libEGL",
        "mesa-libGL",
        "mesa-dri-drivers.i686",
        "mesa-vulkan-drivers.i686",
        "mesa-libEGL.i686",
        "mesa-libGL.i686"
      ],
      "fedora-editors": [
        "emacs-pgtk",
        "neovim",
        "nodejs",
        "npm",
        "tree-sitter-cli"
      ],
      "hyprland-copr": [
        "cliphist",
        "greetd",
        "gnome-keyring",
        "gnome-tweaks",
        "hyprland-git",
        "hyprland-guiutils",
        "hyprpwcenter",
        "hyprshutdown",
        "kitty",
        "kitty-shell-integration",
        "kitty-terminfo",
        "noctalia-git",
        "noctalia-greeter-git",
        "nwg-look",
        "papers",
        "papirus-icon-theme",
        "qt6ct",
        "Thunar",
        "thunar-archive-plugin",
        "thunar-media-tags-plugin",
        "thunar-vcs-plugin",
        "thunar-volman",
        "xdg-desktop-portal-gtk",
        "xdg-desktop-portal-hyprland"
      ],
      "gaming": [
        "evtest",
        "gamemode",
        "gamescope",
        "input-remapper",
        "lutris",
        "mangohud",
        "mangohud.i686",
        "steam",
        "steam-devices",
        "usbip",
        "ydotool",
        "zenity"
      ],
      "bazaar-copr": ["bazaar"],
      "zen-copr": ["zen-browser"],
      "vendor-apps": ["code", "brave-browser"],
      "vendor-apps-optional": ["brave-origin"],
      "fedora-devtools": [
        "atuin",
        "bat",
        "btop",
        "cava",
        "chafa",
        "chezmoi",
        "direnv",
        "du-dust",
        "eza",
        "fd-find",
        "fpaste",
        "fzf",
        "wl-clipboard",
        "gnuplot",
        "jq",
        "pandoc-cli",
        "python3",
        "perl",
        "ripgrep",
        "tealdeer",
        "uv"
      ],
      "nix": ["nix", "nix-daemon"],
      "flatpak": ["flatpak", "flatpak-selinux", "libnotify"],
      "ujust-copr": ["uupd", "ublue-os-just", "ublue-os-update-services"],
      "ujust-fedora": ["glow", "grub2-tools", "grubby", "gum", "stress-ng"],
      "terra": [
        "zed",
        "scx-scheds",
        "scx-tools",
        "umu-launcher",
        "umu-wrapper",
        "bazzite-portal",
        "bibata-cursor-theme",
        "jetbrainsmono-nerd-fonts",
        "nerdfontssymbolsonly-nerd-fonts",
        "golang-github-jesseduffield-lazygit",
        "starship",
        "yazi",
        "zellij"
      ]
    },
    "exclude": {
      "all": [
        "nautilus-gsconnect",
        "gnome-shell-extension-gsconnect",
        "gnome-shell-extension-user-theme",
        "gnome-search-yafti",
        "gnome-rounded-blur",
        "firewall-config",
        "ibus-mozc",
        "ibus-pinyin",
        "ibus-table-chinese-cangjie",
        "ibus-table-chinese-quick",
        "inputplumber",
        "steamos-manager-powerstation",
        "jupiter-fan-control",
        "jupiter-hw-support-btrfs",
        "galileo-mura",
        "steamdeck-dsp",
        "powerbuttond",
        "vpower",
        "sdgyrodsu",
        "hid-replay",
        "steamdeck-backgrounds",
        "steamdeck-gnome-presets",
        "waydroid",
        "firefox",
        "firefox-langpacks",
        "gnome-shell",
        "mutter",
        "gdm",
        "gnome-session",
        "gnome-session-wayland-session",
        "nautilus",
        "ptyxis",
        "gnome-control-center",
        "gnome-settings-daemon",
        "gjs",
        "xdg-desktop-portal-gnome",
        "nano",
        "nano-default-editor",
        "zram-generator-defaults"
      ]
    }
  },
  "flatpak": {
    "install": [
      "com.ranfdev.DistroShelf",
      "org.onlyoffice.desktopeditors",
      "com.bitwarden.desktop",
      "com.ticktick.TickTick"
    ],
    "remove": []
  }
}
```

Three deliberate changes beyond the regrouping: `xorg-x11-server-Xorg` is gone (Hyprland needs `Xwayland`, not a full X server); `fastfetch` was removed from `exclude.all` where it contradicted its own presence in `fedora-core`; and `nodejs24`/`nodejs24-npm` became `nodejs`/`npm` — **run `verify-package-availability` against F44 before trusting either spelling**, since `dnf5` aborts the whole transaction on one bad name.

---

## `build_files/packages/install-packages`

```bash
#!/usr/bin/env bash
# halcyon build step — install-packages (core + desktop + gaming + apps)
# Policy: --setopt=install_weak_deps=False on EVERY install; anything that
# used to arrive as a weak dep must be listed explicitly (e.g. flatpak-selinux
# in setup-flatpaks, hyprland-guiutils/xdg portals below).
# Package LISTS live in packages.json — this stage owns the repo windows and
# flags only.
set -euo pipefail
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate
echo "::group::install-packages — core + hardware + editors (Fedora)"

# --- core set (main core.yml parity; Fedora repos) ---
# The @custom-environment comps group stays here — comps groups are not
# catalog entries in packages.json.
dnf5 -y --setopt=install_weak_deps=False group-install \
  custom-environment \
  || true
readarray -t CORE_PKGS < <(packages_for fedora-core)
dnf5 -y --setopt=install_weak_deps=False install \
  "${CORE_PKGS[@]}"

# --- hardware support the Bazzite base used to provide (fedora-bootc is
# bare; rakuos-base installs the same classes explicitly) ---
readarray -t HW_PKGS < <(packages_for fedora-hardware)
dnf5 -y --setopt=install_weak_deps=False install \
  "${HW_PKGS[@]}"

# --- editors + language runtimes (Fedora). These used to live in the
# vendor-apps group and were installed inside the vscode/brave repo window,
# which was a lie about where they resolve from. They are plain Fedora
# packages and install here with no third-party repo enabled.
readarray -t EDITOR_PKGS < <(packages_for fedora-editors)
dnf5 -y --setopt=install_weak_deps=False install \
  "${EDITOR_PKGS[@]}"
echo "::endgroup::"

echo "::group::install-packages — desktop stack (COPR lionheartp/Hyprland)"
# NOTE: weak deps are OFF, so every Hyprland-stack weak dep we rely on must
# be listed in the group explicitly (hyprland-guiutils,
# xdg-desktop-portal-{hyprland,gtk}, qt6ct, nwg-look, ...).
dnf5 -y copr enable lionheartp/Hyprland
readarray -t HYPRLAND_PKGS < <(packages_for hyprland-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${HYPRLAND_PKGS[@]}"
dnf5 -y copr disable lionheartp/Hyprland
echo "::endgroup::"

echo "::group::install-packages — gaming (RPM Fusion + Fedora)"
# terra bits live in install-terra. gamescope + mangohud come from Fedora now
# (terra-gamescope/-mangohud were retired upstream — verified live
# 2026-09-19); mangohud.i686 covers 32-bit overlays for Steam/Proton.
readarray -t GAMING_PKGS < <(packages_for gaming)
dnf5 -y --setopt=install_weak_deps=False install \
  "${GAMING_PKGS[@]}"
echo "::endgroup::"

echo "::group::install-packages — bazaar (COPR ublue-os/packages)"
dnf5 -y copr enable ublue-os/packages
readarray -t BAZAAR_PKGS < <(packages_for bazaar-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${BAZAAR_PKGS[@]}"
dnf5 -y copr disable ublue-os/packages
echo "::endgroup::"

echo "::group::install-packages — browsers + vendor repos (per-use)"
# zen-browser (sneexy COPR per-use)
dnf5 -y copr enable sneexy/zen-browser
readarray -t ZEN_PKGS < <(packages_for zen-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${ZEN_PKGS[@]}"
dnf5 -y copr disable sneexy/zen-browser

# vscode/brave vendor repos: written, used, disabled and deleted inside this
# stage. Only packages that genuinely resolve from these repos may be in the
# vendor-apps group.
cat > /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
chmod 0644 /etc/yum.repos.d/vscode.repo
cat > /etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
chmod 0644 /etc/yum.repos.d/brave-browser.repo

readarray -t VENDOR_PKGS < <(packages_for vendor-apps)
dnf5 -y --setopt=install_weak_deps=False install \
  "${VENDOR_PKGS[@]}"
# brave-origin: skip-unavailable semantics (may not exist in the vendor repo)
readarray -t VENDOR_OPT_PKGS < <(packages_for vendor-apps-optional)
if [ "${#VENDOR_OPT_PKGS[@]}" -gt 0 ]; then
  dnf5 -y --setopt=install_weak_deps=False install \
    "${VENDOR_OPT_PKGS[@]}" \
    || true
fi
rm -f /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/brave-browser.repo
echo "::endgroup::"
```

---

## `build_files/packages/packages-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — packages level (runs immediately after install-packages):
# desktop stack, apps, and the third-party repo end state of that stage.
# Adapted from main's desktop-verify.sh + apps-verify.sh.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::packages-verify — desktop stack"
gate "hyprland-git installed"            rpm -q hyprland-git
gate "hyprland-guiutils installed"       rpm -q hyprland-guiutils
gate "noctalia-greeter-git installed"    rpm -q noctalia-greeter-git
gate "greetd installed"                  rpm -q greetd
gate "xdg-desktop-portal-hyprland"       rpm -q xdg-desktop-portal-hyprland
gate "xdg-desktop-portal-gtk"            rpm -q xdg-desktop-portal-gtk
gate "kitty + terminfo"                  rpm -q kitty kitty-terminfo
gate "thunar + archive plugin"           rpm -q Thunar thunar-archive-plugin
gate "greeter wrapper executable"        test -x /usr/bin/noctalia-greeter-session
gate "Xwayland present"                  rpm -q xorg-x11-server-Xwayland
# The full X server has no role on a Hyprland-only image; Xwayland is the one
# that matters. Gate its absence so it cannot creep back in via a weak dep.
gate "no full Xorg server"               sh -c '! rpm -q xorg-x11-server-Xorg >/dev/null 2>&1'
gate "fonts: jetbrains-mono"             rpm -q jetbrains-mono-fonts
gate "fonts: noto emoji + color emoji"   rpm -q google-noto-emoji-fonts google-noto-color-emoji-fonts
echo "::endgroup::"

echo "::group::packages-verify — build-tool preconditions for later stages"
# install-brew-bundle (Stage 07) and install-texlive (Stage 10) hard-fail
# without these. Catching it here names the missing package; catching it
# there names a stage that looks unrelated.
gate "zstd (brew payload packing)"       command -v zstd
gate "setpriv (brew uid drop)"           command -v setpriv
gate "gpg (texlive signature check)"     command -v gpg
gate "jq (packages-lib + runtime)"       command -v jq
gate "gcc (brew formula postinstall)"    command -v gcc
echo "::endgroup::"

echo "::group::packages-verify — apps + repo end state"
gate "vs code installed"                 rpm -q code
gate "brave-browser installed"           rpm -q brave-browser
gate "zen-browser installed"             rpm -q zen-browser
gate "neovim + emacs-pgtk"               rpm -q neovim emacs-pgtk
gate "vscode repo file removed"          sh -c '! test -f /etc/yum.repos.d/vscode.repo'
gate "brave repo file removed"           sh -c '! ls /etc/yum.repos.d/brave-browser* >/dev/null 2>&1'
gate "consumed COPR repos disabled"      sh -c '! grep -l "^enabled=1" /etc/yum.repos.d/_copr:*lionheartp* /etc/yum.repos.d/_copr:*sneexy* 2>/dev/null | grep -q .'
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::packages-verify failed"; exit 1; }
echo "--- packages-verify: all checks passed ---"
```

---

## `build_files/packages/install-devtools`

```bash
#!/usr/bin/env bash
# halcyon build step — install-devtools (Fedora brew-formula replacements)
# Fedora RPMs (MIGRATION §8.7). RPM copies keep PATH priority: the Homebrew
# payload (build_files/brew, next stage) APPENDS its bin dirs via
# environment.d + profile.d, so these RPMs win. The Brewfile is therefore
# trimmed to the three formulas Fedora and Terra do not ship at all
# (bun, pixi, opencode) — anything listed in both places is poured, shipped
# and then permanently shadowed.
# chezmoi comes from the official Fedora repo (2.72 in F44) — blue-build
# chezmoi module parity is provided by the systemd user units, not the
# install source.
set -euo pipefail
echo "::group::install-devtools — brew-formula replacements (Fedora RPMs)"
# NOTE: lazygit/starship/yazi/zellij are NOT in Fedora 44 (verified in the
# 2026-09-19 CI-equivalent build) — all four come from Terra via install-terra
# (lazygit ships there under its Go name golang-github-jesseduffield-lazygit).
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate
readarray -t DEV_PKGS < <(packages_for fedora-devtools)
echo "  INFO  installing ${#DEV_PKGS[@]} Fedora devtools: ${DEV_PKGS[*]}"
dnf5 -y --setopt=install_weak_deps=False install \
  "${DEV_PKGS[@]}"
echo "  OK    devtools rpm-verified"
for pkg in "${DEV_PKGS[@]}"; do
  rpm -q "${pkg%%.i686}" >/dev/null 2>&1 || {
    echo "  FAIL  devtools package not installed after transaction: ${pkg}"
    exit 1
  }
done
echo "::endgroup::"
```

---

## `build_files/packages/install-terra`

```bash
#!/usr/bin/env bash
# halcyon build step — install-terra (USER-EDITABLE Terra list, exclusive resolution)
#
# Repo lifecycle + exclusivity rules:
#   - every transaction here resolves from TERRA REPOS ONLY
#     (--disablerepo='*' --enablerepo='terra*'), never as a Fedora fallback;
#     a package missing from Terra fails the build loudly.
#   - Terra repos are enabled only for this stage and disabled immediately
#     after (finalize sweeps any leftover repo files).
#
# Ordering note: this stage runs after install-packages;
# final-verify (the authoritative keeper gate) expects
# scx-*/umu-launcher/bazzite-portal present.
#
# Fonts parity (main fonts.yml) is included here: jetbrainsmono-nerd-fonts +
# nerdfontssymbolsonly-nerd-fonts exist only in Terra; the Fedora-side fonts
# (google-noto-*, jetbrains-mono-fonts, liberation) install in install-packages.
set -euo pipefail
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate
echo "::group::install-terra — Terra packages"
FEDORA_MAJOR="$(rpm -E %fedora)"

# --- the list you edit lives in packages.json (group "terra") ---
# NOTE: terra-gamescope/terra-mangohud no longer exist in Terra (verified
# live 2026-09-19) — Fedora 44 provides gamescope + mangohud directly, and
# install-packages handles them (incl. mangohud.i686 for 32-bit overlays).
readarray -t TERRA_PKGS < <(packages_for terra)
# ---------------------------------------------------------------------------

# 1) enable Terra via repofrompath and install the release packages with
#    ONLY that repo enabled (no Fedora fallback for these either)
dnf5 -y --setopt=install_weak_deps=False install --nogpgcheck \
  --disablerepo='*' --enablerepo='terra' \
  --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
  terra-release
# 2) optional subrepo release packages (mesa/multimedia) — only needed if you
#    add packages from those subrepos to the terra group; they ship their
#    .repo files. Tolerated missing (|| true) because they are OPTIONAL repos.
dnf5 -y --setopt=install_weak_deps=False install --nogpgcheck \
  --disablerepo='*' --enablerepo='terra' \
  --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_MAJOR}" \
  terra-release-mesa \
  terra-release-multimedia \
  || true
# remove the hardcoded priority so repo options are effective
sed -i '/^priority=/d' /etc/yum.repos.d/terra*.repo 2>/dev/null || true

# 3) install the user list STRICTLY from Terra repos (the glob covers
#    terra, terra-mesa, terra-multimedia); a missing package FAILS the build
dnf5 -y --setopt=install_weak_deps=False install \
  --disablerepo='*' --enablerepo='terra*' \
  "${TERRA_PKGS[@]}"

# 4) hard verification: every listed package must now be in the rpmdb
for pkg in "${TERRA_PKGS[@]}"; do
  rpm -q "${pkg%%.i686}" >/dev/null 2>&1 || {
    echo "  FAIL  terra package not installed: ${pkg}"
    exit 1
  }
done

# 5) disable every terra repo immediately (repo lifecycle policy).
#    finalize deletes the files outright — this keeps the intermediate
#    layers honest so no later stage can resolve from Terra by accident.
dnf5 -y config-manager setopt "terra.enabled=0" 2>/dev/null || true
for f in /etc/yum.repos.d/terra*.repo; do
  [ -f "${f}" ] && sed -i 's/^enabled=1/enabled=0/' "${f}"
done
echo "::endgroup::"
```

---

## `build_files/runtime/install-nix`

```bash
#!/usr/bin/env bash
# halcyon build step — install-nix (winter pattern)
# https://github.com/fu5ha/winter recipes/modules/nix.yaml — the same files
# ship via the static tree: usr/lib/tmpfiles.d/zz-halcyon-nix.conf,
# etc/profile.d/01-nix-resolve-home-env.sh, systemd/{var-nix,nix.mount}).
set -euo pipefail
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate
echo "::group::install-nix — nix multi-user install"
readarray -t NIX_PKGS < <(packages_for nix)
dnf5 -y --setopt=install_weak_deps=False install \
  "${NIX_PKGS[@]}"
systemctl enable nix-daemon 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/nix-daemon.service /etc/systemd/system/multi-user.target.wants/nix-daemon.service
# /nix is a bind mount of /var/nix (var-nix.service creates it, nix.mount
# binds it) — enabled in configure-system like main's services.yml did.
echo "::endgroup::"
```

---

## `build_files/runtime/setup-flatpaks`

Only the shellcheck directive changed; the rest is byte-identical to what you have, so I'll show just the header block you need to edit:

```bash
#!/usr/bin/env bash
# halcyon build step — setup-flatpaks (flathub USER repo only)
# ... (unchanged comment block) ...
set -euo pipefail
# shellcheck source=../packages-lib
source /ctx/packages-lib
packages_validate
```

Apply the same one-line change (`source=build_files/packages-lib` → `source=../packages-lib`) in `build_files/runtime/setup-ujust`. With `-x`, ShellCheck resolves a relative `source=` against the _script's own_ directory, so the old repo-root-relative path never resolved and every one of these emitted a silent SC1091.

---

## `Containerfile`

```dockerfile
# halcyon — bootc Containerfile following the ublue-os/bazzite project
# structure (https://github.com/ublue-os/bazzite): scratch `ctx` stage with
# semantic unnumbered build helpers, whole-ctx bind mount per RUN, ARG-only
# configuration, per-RUN third-party repo enable→disable, /ctx/cleanup after
# every image-mutating RUN, bootc container lint as the hermetic final gate.
#
# Build locally:
#   podman build --pull -t localhost/halcyon:latest .
#
# Verification is per-level (main-branch pattern): every install stage is
# immediately followed by its <stage>-verify companion so failures surface at
# that level. Removals run FIRST (remove-packages) — main's removals.yml
# ordering — so dnf computes the removal set on the smallest, pristine graph;
# keeper packages are gated against the FINAL state in final-verify.
#
# Every stage RUN opens with a "████ STAGE nn/17 · name · summary ████" banner
# so a human scrolling a CI log can find stage boundaries instantly; the build
# scripts themselves emit ::group:: folds + OK/FAIL prefixes inside each stage.

ARG FEDORA_VERSION=44

# --- build context: semantic helpers, never baked into the image ---
FROM scratch AS ctx
COPY build_files /
COPY packages.json /
# cosign.pub is consumed by the branding stage (sigstore policy assets)
COPY cosign.pub /

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

# CI passes --build-arg for the two volatile values (bazzite convention:
# version = <fedora-major>.<yyyymmdd>, revision = git sha)
ARG IMAGE_VERSION="44.0"
ARG SOURCE_SHA="unknown"

# LICENSE at the repo root is Apache-2.0, as is every pyproject.toml in
# build_files/python-packages. The label set must agree with it — the
# Justfile's io.artifacthub.package.license is kept in sync.
LABEL org.opencontainers.image.title="halcyon" \
      org.opencontainers.image.description="Lean Hyprland gaming desktop — fedora-bootc + p03 kernel + NVIDIA open (negativo17 userland) + noctalia greeter + ujust/uupd" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_SHA}" \
      org.opencontainers.image.source="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.url="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.vendor="aahsnr-work" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.authors="aahsnr-work" \
      io.artifacthub.package.readme-url="https://raw.githubusercontent.com/aahsnr-work/halcyon/container/README.md" \
      halcyon.base="fedora-bootc-p03" \
      halcyon.desktop="hyprland-noctalia"

# static system tree (configs, units, ujust modules, theme, wallpaper)
# NOTE: this lands BEFORE any RPM install, so an RPM that owns the same path
# in a later stage overwrites it. Anything RPM-owned (greetd's config.toml,
# pam.d/greetd) is installed from /ctx in its consuming stage instead; drop-in
# files that could collide are zz-prefixed so they sort last.
COPY system_files/shared/ /

# dnf5 patience drop-in MUST land in the first RUN — it exists to survive
# Copr 504s during the very stages that follow (libdnf5 reads
# /etc/dnf/libdnf5.conf.d/ before the main config).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 00/17 · dnf5 patience drop-in ████" \
    && install -Dm0644 /ctx/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# ---- Stage 1: shared external repos + jq/dnf5-plugins bootstrap ------------
# Repos come first so the removals stage can read its list from packages.json;
# jq/dnf5-plugins are two tiny build tools and do not meaningfully change the
# pristine graph the removals run against. jq is NOT assumed present in the
# base — packages-lib cannot parse packages.json without it.
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 01/17 · setup-repos · base external repos + jq ████" \
    && /ctx/base/setup-repos && /ctx/cleanup

# ---- Stage 2: removals on the near-pristine base (JSON-driven, main ordering)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 02/17 · remove-packages · removals on pristine base ████" \
    && /ctx/base/remove-packages && /ctx/cleanup

# ---- Stage 3: p03 kernel + prebuilt nvidia-open modules (Stage K1) ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 03/17 · install-kernel · p03 + nvidia-open (Stage K1) ████" \
    && /ctx/kernel/install-kernel && /ctx/kernel/kernel-verify && /ctx/cleanup

# ---- Stage 4: core + hardware + editors + desktop + gaming + apps ----------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 04/17 · install-packages · core + desktop + gaming + apps ████" \
    && /ctx/packages/install-packages && /ctx/packages/packages-verify && /ctx/cleanup

# ---- Stage 5: Terra packages (user-editable list, exclusive resolution) ----
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 05/17 · install-terra · Terra-only resolution ████" \
    && /ctx/packages/install-terra && /ctx/cleanup

# ---- Stage 6: devtools (Fedora brew-formula replacements) ------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 06/17 · install-devtools · Fedora devtools ████" \
    && /ctx/packages/install-devtools && /ctx/cleanup

# ---- Stage 7: Homebrew (core + the three formulas Fedora/Terra lack, BAKED
#      into a /usr payload; halcyon-brew-bundle.service seeds it pre-login) --
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 07/17 · install-brew-bundle · Homebrew bake ████" \
    && /ctx/brew/install-brew-bundle && /ctx/brew/brew-verify && /ctx/cleanup

# ---- Stage 8: nix (winter pattern) ------------------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 08/17 · install-nix · winter pattern ████" \
    && /ctx/runtime/install-nix && /ctx/runtime/nix-verify && /ctx/cleanup

# ---- Stage 9: flatpak (flathub USER repo only) ------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 09/17 · setup-flatpaks · flathub user repo ████" \
    && /ctx/runtime/setup-flatpaks && /ctx/runtime/flatpaks-verify && /ctx/cleanup

# ---- Stage 10: built apps (obsidian/zotero/pyprland/texlive/python) --------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 10/17 · install-built-apps · obsidian/zotero/pyprland/texlive/python ████" \
    && /ctx/apps/install-built-apps && /ctx/apps/built-apps-verify && /ctx/cleanup

# ---- Stage 11: ujust machinery (ublue-os-just) + uupd -----------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 11/17 · setup-ujust · ublue-os-just + uupd ████" \
    && /ctx/runtime/setup-ujust && /ctx/runtime/ujust-verify && /ctx/cleanup

# ---- Stage 12: system config (greetd, services, chezmoi + brew wiring) -----
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 12/17 · configure-system · greetd + units + services ████" \
    && /ctx/desktop/configure-system && /ctx/desktop/system-verify && /ctx/cleanup

# ---- Stage 13: branding (os-release identity + plymouth theme) --------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 13/17 · image-info · os-release + plymouth ████" \
    && /ctx/desktop/image-info && /ctx/desktop/branding-verify && /ctx/cleanup

# ---- Stage 14: initramfs LAST (plymouth theme + nvidia hooks baked in) ------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 14/17 · build-initramfs · dracut for p03 ████" \
    && /ctx/finish/build-initramfs && /ctx/cleanup

# ---- Stage 15: finalize (repo sweep + end-of-build hygiene) -----------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 15/17 · finalize · repo sweep + hygiene ████" \
    && /ctx/finish/finalize

# ---- Stage 16: final cross-cutting verification ------------------------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 16/17 · final-verify · cross-cutting gates ████" \
    && /ctx/finish/final-verify

# ---- Final gate: hermetic bootc lint (bazzite pattern) -----------------------
# shell form here (not exec form) so the banner echo can share the RUN; bootc
# lint is short-lived so shell signal semantics are irrelevant.
# TODO: once final-verify's bootc-invariant group has been green for a few
# builds, add --fatal-warnings here so var-tmpfiles/sysusers cannot regress.
RUN --mount=type=tmpfs,target=/run --network=none \
    echo "████ STAGE 17/17 · bootc container lint · hermetic final gate ████" \
    && bootc container lint
```

---

## `Justfile`

```make
# halcyon — repo task runner (adapted from ublue-os/image-template's Justfile;
# ISO/bootc-image-builder recipes deliberately omitted — see MIGRATION.md).
set dotenv-filename := "halcyon.env"

export image_name := env_var("IMAGE_NAME")
export repo_organization := env_var("REPO_ORGANIZATION")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")
export image_logo_url := env_var("IMAGE_LOGO_URL")
export default_tag := env_var("DEFAULT_TAG")
export fedora_version := env_var("FEDORA_VERSION")

default:
    @just --list

# Check Justfile + all build_files scripts + recipe bodies + verify helpers
[group('Just')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile || status=1

    echo "::group::bash -n — build_files scripts"
    while read -r file; do
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done < <(find build_files -type f \
               ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
               ! -path "*desktop/greetd*" \
               ! -name "*.json" ! -name "*.toml" ! -name "README*")
    echo "::endgroup::"

    echo "::group::bash -n — verify/ helpers + workflow shell code"
    for file in verify/*.sh .github/log-helpers.sh; do
        [ -e "$file" ] || continue
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done
    echo "::endgroup::"

    echo "::group::py_compile — python helpers"
    # The build-time smoke test is `-h`/`--version`, which never reaches the
    # code paths that do real work. A missing `datetime` import shipped in the
    # image once for exactly that reason; compiling every module catches that
    # class of bug in seconds. Run `just test-python` for the real suites.
    while read -r file; do
        echo "Compiling: $file"
        python3 -m py_compile "$file" || status=1
    done < <(find build_files/python-packages -name "*.py" ! -path "*/.venv/*")
    echo "::endgroup::"

    echo "::group::recipe bodies — parse + bash -n (ujust runtime syntax)"
    for module in system_files/shared/usr/share/ublue-os/just/*.just; do
        just --justfile "$module" --list >/dev/null 2>&1 \
            || { echo "Recipe module does not parse: $module"; status=1; continue; }
        for recipe in $(just --justfile "$module" --summary); do
            body="$(just --justfile "$module" --show "$recipe" 2>/dev/null)" || continue
            # just --show prints attributes ([group(...)]), the recipe header,
            # then the body; bodies are bash shebang scripts — take everything
            # from the first `#!` line on (empty for non-script recipes, and
            # `bash -n` passes on empty input).
            if printf '%s\n' "$body" | awk 'f{print} /^#!/{f=1}' | bash -n; then
                echo "Checking recipe: $(basename "$module")::$recipe — OK"
            else
                echo "Recipe body FAILED bash -n: $(basename "$module")::$recipe"
                status=1
            fi
        done
    done
    echo "::endgroup::"

    exit "$status"

# Fix Justfile formatting
[group('Just')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile

# Lint every build_files script with shellcheck (extensionless bash)
[group('Just')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shellcheck >/dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    status=0
    # while-read + explicit status accumulation: `find -exec` would report
    # only the LAST invocation's exit code and silently mask earlier failures
    while read -r file; do
        # -x follows `# shellcheck source=` directives. Those directives are
        # written relative to the SCRIPT's directory (../packages-lib), which
        # is how ShellCheck resolves them; --source-path is the belt-and-
        # braces fallback for anything sourced by an absolute /ctx path.
        if shellcheck --shell=bash -x --source-path=build_files "$file"; then
            echo "shellcheck OK: $file"
        else
            echo "shellcheck FAILED: $file"
            status=1
        fi
    done < <(find build_files -type f \
        ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
        ! -path "*desktop/greetd*" \
        ! -name "*.json" ! -name "*.toml" ! -name "README*")
    exit "$status"

# Run the python helper test suites (not reached by check/lint)
[group('Just')]
test-python:
    #!/usr/bin/env bash
    set -euo pipefail
    cd build_files/python-packages
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    for pkg in dump-to-markdown rmi; do
        echo "::group::pytest — ${pkg}"
        .venv/bin/pip install --quiet -e "./${pkg}[dev]"
        .venv/bin/pytest "${pkg}"
        echo "::endgroup::"
    done

# Audit the .github tree (host-side; no image required)
[group('Just')]
check-github:
    #!/usr/bin/env bash
    set -euo pipefail
    bash verify/verify-github.sh

# Build the container image with the CI label scheme
[group('Build')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    BUILD_ARGS=()
    LABELS=()
    GIT_SHA=$(git rev-parse --short HEAD)
    # consumed by the Containerfile ARGs (bazzite convention:
    # version = <fedora-major>.<yyyymmdd>, revision = git sha)
    BUILD_ARGS+=("--build-arg" "FEDORA_VERSION=${fedora_version}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VERSION=${fedora_version}.$(date +%Y%m%d)")
    BUILD_ARGS+=("--build-arg" "SOURCE_SHA=${GIT_SHA}")

    if [[ -z "$(git status -s)" ]]; then
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ image_name }}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.version={{ default_tag }}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords={{ image_keywords }}")
    # Must match LICENSE and the Containerfile's org.opencontainers.image.licenses
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url={{ image_logo_url }}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description={{ image_desc }}")
    LABELS+=("--label" "org.opencontainers.image.title={{ image_name }}")
    LABELS+=("--label" "org.opencontainers.image.vendor={{ repo_organization }}")

    podman build "${BUILD_ARGS[@]}" "${LABELS[@]}" \
        --pull=newer --platform linux/amd64 \
        --tag "${target_image}:${tag}" --file Containerfile .

# Run the image-side verification suite against a built image
[group('Build')]
verify-image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    for checker in verify-brew.sh verify-chezmoi.sh verify-ujust.sh; do
        echo "::group::image-side — ${checker}"
        podman run --rm --entrypoint /bin/bash \
            -v "$PWD/verify:/verify:ro" \
            "${target_image}:${tag}" "/verify/${checker}" || status=1
        echo "::endgroup::"
    done
    exit "$status"

# Generate the full alias-tag set (template scheme)
# Image Name (template recipe — CI resolves the image name through it)
[group('Utility')]
[private]
image_name $target_image=image_name:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "${target_image}"

[group('Utility')]
generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    echo "${tag}"

[group('Utility')]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
        BUILD_TAGS+=("${DATE}-${GIT_SHA}")
    fi
    BUILD_TAGS+=("${DATE}")
    BUILD_TAGS+=("${tag}")
    BUILD_TAGS+=("${tag}-${DATE}")
    BUILD_TAGS+=("${fedora_version}")
    BUILD_TAGS+=("${DATE}-${fedora_version}")

    echo "${BUILD_TAGS[@]}"

# Re-tag one built image with the whole alias set
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -euox pipefail

    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done
    podman images

# Report the installed package count of a built image (mirrors the CI step)
[group('Utility')]
package-count $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    INFO=$(podman run --rm --entrypoint /bin/bash "${target_image}:${tag}" -c \
        'echo "count=$(rpm -qa | wc -l)"; echo "kernel=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-p03 2>/dev/null || echo n/a)"')
    COUNT=$(sed -n 's/^count=//p' <<< "${INFO}")
    KVER=$(sed -n 's/^kernel=//p' <<< "${INFO}")
    echo "total installed RPM packages: ${COUNT}"
    echo "p03 kernel: ${KVER}"
```

---

## `.github/workflows/build.yml`

```yaml
---
name: build
on:
  schedule:
    - cron: "00 08 * * *"
  push:
    branches: [container, main]
    paths-ignore:
      - "**/README.md"
      - "**/MIGRATION.md"
      - "**/TODO.md"
  pull_request:
  workflow_dispatch:

env:
  IMAGE_REGISTRY: "ghcr.io/${{ github.repository_owner }}" # do not edit

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  build_push:
    name: Build and push image
    runs-on: ubuntu-latest
    timeout-minutes: 180
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      # Colored stage banners for every step below. GitHub's log viewer
      # renders the ANSI escapes in .github/log-helpers.sh, giving each stage
      # a distinct visual block while scrolling the build log.
      - name: Log helpers
        run: |
          source .github/log-helpers.sh
          banner "halcyon build — run ${GITHUB_RUN_ID} on ${GITHUB_REF_NAME}"
          step "event: ${GITHUB_EVENT_NAME}; sha: ${GITHUB_SHA::7}"
          step "actions cache/runner ready"

      # Copr's download CDN intermittently 504s on repodata; poll until every
      # consumed COPR answers 200 (up to ~30 min) — consumed during the
      # transition (Hyprland/zen/desktop) AND for the p03 kernel (Stage K1).
      - name: Wait for Copr metadata availability
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 1/7 — Copr metadata availability"
          echo "::group::Polling consumed COPRs (up to 30 attempts × 60s)"
          URLS=(
            "https://download.copr.fedorainfracloud.org/results/lionheartp/Hyprland/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/catpieleaf/kernel-p03/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/ublue-os/packages/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/sneexy/zen-browser/fedora-44-x86_64/repodata/repomd.xml"
          )
          for i in $(seq 1 30); do
            ok_all=1
            for URL in "${URLS[@]}"; do
              code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 20 "$URL" || true)
              if [ "$code" = "200" ]; then
                printf '%s\n' "${H_GRN}  ✔ HTTP ${code}  ${URL}${H_RESET}"
              else
                printf '%s\n' "${H_YLW}  ⚠ HTTP ${code}  ${URL}${H_RESET}"
                ok_all=0
              fi
            done
            [ "$ok_all" = "1" ] && { ok "all Copr repodata reachable (attempt ${i})"; echo "::endgroup::"; exit 0; }
            step "attempt ${i}/30 not all green — sleeping 60s"
            sleep 60
          done
          echo "::endgroup::"
          die "Copr metadata still unavailable after 30 attempts — re-run later."

      - name: Report build space (before)
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 2/7 — Maximize build space"
          step "before:"
          df -h / /mnt | sed 's/^/      /'

      - name: Remove unwanted software
        uses: ublue-os/remove-unwanted-software@v9

      - name: Report freed space (after)
        if: always()
        run: |
          source .github/log-helpers.sh
          step "after:"
          df -h / /mnt | sed 's/^/      /'

      - name: Install just
        uses: extractions/setup-just@v4

      - name: Install shellcheck
        run: |
          set -euo pipefail
          sudo apt-get update -qq
          sudo apt-get install -y -qq shellcheck

      # Both syntax gates, not just `check`. A scheduled build used to be able
      # to go red on a shellcheck regression that landed via a path-ignored
      # push, because only lint.yml ran `just lint` and only on PR/push.
      - name: Check Just + shell syntax
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 3/7 — just check + just lint"
          just check && ok "just check passed"
          just lint && ok "just lint passed"

      - name: Image Name
        id: image-name
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 4/7 — Resolve image identity"
          IMAGE_NAME=$(just image_name)
          ok "IMAGE_NAME=${IMAGE_NAME}"
          echo "IMAGE_NAME=${IMAGE_NAME}" >> "$GITHUB_ENV"

      - name: Default Tag
        id: gen-default-tag
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          DEFAULT_TAG=$(just generate-default-tag)
          ok "DEFAULT_TAG=${DEFAULT_TAG}"
          echo "DEFAULT_TAG=${DEFAULT_TAG}" >> "$GITHUB_ENV"

      - name: Prepare environment
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          # Lowercase the image uri https://github.com/macbre/push-to-ghcr/issues/12
          echo "IMAGE_REGISTRY=${IMAGE_REGISTRY,,}" >> "${GITHUB_ENV}"
          echo "IMAGE_NAME=${IMAGE_NAME,,}" >> "${GITHUB_ENV}"
          ok "registry=${IMAGE_REGISTRY,,}  image=${IMAGE_NAME,,}"

      # This actually builds the container image
      - name: Build Image
        id: build-image
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 5/7 — podman build (all 18 stages)"
          echo "::group::just build ${IMAGE_NAME} ${DEFAULT_TAG}"
          just build \
            "${IMAGE_NAME}" \
            "${DEFAULT_TAG}"
          echo "::endgroup::"
          ok "image built"

      # The verify/ suite tests properties no in-build gate covers (chezmoi
      # --global wiring and timer semantics, the ujust --choose chooser
      # plumbing, the brew payload end state from OUTSIDE the build). It was
      # written, committed and then never executed by anything — wire it here.
      - name: Image-side verification suite
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 6/7 — Image-side verification (verify/)"
          just verify-image "${IMAGE_NAME}" "${DEFAULT_TAG}"
          ok "all image-side verifications passed"

      # Distinctive package census: run the freshly built image and write the
      # report to the run summary (GITHUB_STEP_SUMMARY) plus a ::notice::
      # annotation. The census is also baked into the image at
      # /usr/share/halcyon/package-count by build_files/finish/final-verify.
      - name: Package count report
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 7/7 — Package census + tags + push + sign"
          INFO=$(podman run --rm --entrypoint /bin/bash "${IMAGE_NAME}:${DEFAULT_TAG}" -c \
            'echo "count=$(rpm -qa | wc -l)"; echo "kernel=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-p03 2>/dev/null || echo n/a)"')
          COUNT=$(sed -n 's/^count=//p' <<< "$INFO")
          KVER=$(sed -n 's/^kernel=//p' <<< "$INFO")
          ok "${COUNT} RPMs installed, p03 kernel ${KVER}"
          {
            echo "## 📦 halcyon image package report"
            echo ""
            echo "| Metric | Value |"
            echo "|---|---|"
            echo "| **Total installed RPM packages** | **${COUNT}** |"
            echo "| p03 kernel | ${KVER} |"
            echo "| Homebrew payload | $(podman run --rm --entrypoint /bin/bash "${IMAGE_NAME}:${DEFAULT_TAG}" -c 'du -h /usr/share/halcyon/brew-bundle.tar.zst 2>/dev/null | cut -f1 || echo n/a') |"
            echo "| Source | \`${IMAGE_REGISTRY}/${IMAGE_NAME}:${GITHUB_SHA}\` |"
          } >> "$GITHUB_STEP_SUMMARY"
          echo "::notice title=halcyon package count::${COUNT} RPMs installed (p03 kernel ${KVER})"

      - name: Generate Build Tags
        id: gen-build-tags
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          alias_tags="$(just generate-build-tags \
                        "${IMAGE_NAME}" \
                        "${DEFAULT_TAG}")"
          step "Tags for this run:"
          for t in ${alias_tags}; do printf '%s\n' "${H_WHT}      🏷  ${t}${H_RESET}"; done
          echo "alias_tags=${alias_tags}" >> "$GITHUB_OUTPUT"

      - name: Tag Image
        id: tag-images
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          just tag-images \
            "${IMAGE_NAME}" \
            "${DEFAULT_TAG}" \
            "${ALIAS_TAGS}"
          ok "all alias tags applied"

      # Push + sign only on branch pushes (not PRs) — same semantics as the
      # BlueBuild era action had.
      - name: Login to GitHub Container Registry
        if: github.event_name == 'push'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ github.token }}

      - name: Push To GHCR
        if: github.event_name == 'push'
        id: push-image
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Push to GHCR"
          echo "::group::podman push (one tag at a time)"
          for tag in ${ALIAS_TAGS}; do
            step "pushing ${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
            podman push --quiet --digestfile=/tmp/digestfile "${IMAGE_NAME}:${tag}" \
              "${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
            ok "pushed ${tag}"
          done
          echo "::endgroup::"
          digest=$(< /tmp/digestfile)
          ok "manifest digest: ${digest}"
          echo "digest=${digest}" >> "$GITHUB_OUTPUT"
          {
            echo "## 🔖 Published tags"
            echo ""
            for tag in ${ALIAS_TAGS}; do echo "- \`${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}\`"; done
            echo ""
            echo "digest: \`${digest}\`"
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Install Cosign
        if: github.event_name == 'push'
        uses: sigstore/cosign-installer@v4

      # Sign the manifest digest once — every alias tag shares it.
      - name: Sign container image
        if: github.event_name == 'push'
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.SIGNING_SECRET }}
          COSIGN_PASSWORD: ""
          DIGEST: ${{ steps.push-image.outputs.digest }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Cosign sign"
          cosign sign --key env://COSIGN_PRIVATE_KEY --yes \
            "${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}"
          ok "signed ${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}"

      - name: Done
        if: always()
        run: |
          source .github/log-helpers.sh
          banner "halcyon build finished"
          step "conclusion: ${{ job.status }}"
```

I left every `uses:` pin at the major you had. Verify each against its releases page — `verify-github.sh` asserts the same numbers, so it confirms the workflow matches itself rather than that the version exists.

---

## `.github/workflows/lint.yml`

```yaml
---
name: lint
# PR gate modeled on bazzite's just-syntax-check.yml, widened to run every
# host-side gate the build workflow runs before podman, so PRs fail here in
# seconds instead of 40 minutes in.
on:
  pull_request:
  push:
    branches: [container, main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  check:
    name: Just + shell syntax
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Install just
        uses: extractions/setup-just@v4

      - name: Check Just + bash syntax
        run: |
          source .github/log-helpers.sh
          banner "just check"
          just check && ok "just check passed"

      - name: Shellcheck build_files
        run: |
          source .github/log-helpers.sh
          banner "just lint"
          just lint && ok "just lint passed"

  github-audit:
    name: .github audit
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Install PyYAML
        run: python3 -m pip install --quiet pyyaml

      # verify-github.sh checks required files, YAML parseability, cron
      # syntax, action pins and the log helpers. It was written and then
      # never run by anything — it is host-side and takes seconds.
      - name: Audit .github tree
        run: |
          source .github/log-helpers.sh
          banner "verify-github"
          bash verify/verify-github.sh

  python:
    name: Python helpers
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.13"

      # `just check` compiles every module (catches missing imports that the
      # `-h` smoke test never reaches); this job runs the real suites.
      - name: Compile + test python helpers
        run: |
          source .github/log-helpers.sh
          banner "python helpers"
          cd build_files/python-packages
          python3 -m venv .venv
          .venv/bin/pip install --quiet --upgrade pip
          status=0
          for pkg in dump-to-markdown rmi; do
            echo "::group::pytest — ${pkg}"
            .venv/bin/pip install --quiet -e "./${pkg}[dev]"
            .venv/bin/pytest "${pkg}" || status=1
            echo "::endgroup::"
          done
          exit "$status"
```

---

## `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"

  # The base image tag in the Containerfile is the single most impactful
  # dependency in the repo and was previously tracked by nothing: a Fedora
  # bump went unnoticed until a build broke.
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore"
```

---

## `.github/CODEOWNERS`

```
# Default owner for every path in the repo.
#
# NOTE: CODEOWNERS accepts a user (@name) or a team (@org/team) — a bare
# organization handle is silently ignored, which is what `* @aahsnr-work`
# was doing. Replace with the real user or a team under the org.
* @aahsnr
```

---

## `.containerignore`

```
# Content excluded from the build context — nothing here is needed by any
# build stage; keeping it out shrinks upload/transfer and prevents leaks.
.git
.github
.vscode
.idea
.zcode
.bluebuild-scripts_*
AGENTS.md
SKILLS.md
MIGRATION.md
TODO.md
README.md
notes/
verify/
*.log
*.tar
*.tar.gz
*.oci
*.iso
# python build artifacts (exist on disk from local dev, never needed in ctx)
**/__pycache__/
**/*.egg-info/
**/.venv/
**/.pytest_cache/
build_files/python-packages/**/build/
```

---

## `system_files/shared/usr/share/ublue-os/just/halcyon-rebase.just`

```make
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
        echo "halcyon is a bootc image — there is no rpm-ostree fallback." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Reboot into the new deployment:  systemctl reboot"
    echo "After reboot, switch to the signed tag (README: Install / rebase):"
    echo "  sudo bootc switch --enforce-container-sigpolicy ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "  (the image ships /etc/pki/containers/halcyon.pub + a sigstore policy entry — verification is enforced by policy.json)"
```

---

## `README.md`

````markdown
# halcyon

[![Build halcyon image](https://github.com/aahsnr-work/halcyon/actions/workflows/build.yml/badge.svg?branch=container)](https://github.com/aahsnr-work/halcyon/actions/workflows/build.yml)

A lean, Hyprland-first gaming desktop built as a **bootc Containerfile** in the
[ublue-os/bazzite](https://github.com/ublue-os/bazzite) project structure —
built on `quay.io/fedora/fedora-bootc` with the **p03 kernel**
([CatPieLeaf/linux-p03](https://github.com/CatPieLeaf/linux-p03)) and its
prebuilt **NVIDIA-open modules**, the NVIDIA userland from
[negativo17](https://negativo17.org) (no akmods/DKMS anywhere), the
**Hyprland + Noctalia** desktop with **greetd + noctalia-greeter** login, the
Bazzite gaming stack as native RPMs, and ujust/uupd machinery from
`ublue-os-just` — rebuilt daily, calm by definition.

> **Image:** `ghcr.io/aahsnr-work/halcyon:latest` (`linux/amd64`)
> **Verification:** `cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon`

---

## Install / rebase

**Rebase from an existing Atomic desktop (Bazzite/Silverblue/Bluefin/Kinoite):**

```bash
# 1. rebase to the unsigned image first
rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
# 2. after reboot, switch to the signed tag
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
```

On a bootc system: `sudo bootc switch ghcr.io/aahsnr-work/halcyon:latest`.
Or from the running system: `ujust rebase-to-custom`.

---

## What this image is

Boot → greetd/noctalia-greeter → Hyprland → Noctalia first-run wizard.

- **Kernel + GPU:** `kernel-p03` + `kernel-p03-nvidia-open` from COPR
  `catpieleaf/kernel-p03` (ABI-matched, zero akmods/DKMS); NVIDIA userland
  from negativo17 on the exact same 615.71.09 driver line — RPM Fusion repos
  **exclude NVIDIA packages** so the two conflicting driver chains can never
  mix (the ublue-os/akmods partition). SELinux stays **enforcing** (`p03`
  keeps `CONFIG_SECURITY_SELINUX=y`; `nvidia-driver-selinux` policy installed).
- **Desktop:** `hyprland-git`, `noctalia-git`, `noctalia-greeter-git`,
  `xdg-desktop-portal-{hyprland,gtk}` from COPR `lionheartp/Hyprland`;
  greetd login (tty2 escape hatch); kitty, thunar, papers, gnome-keyring.
  Xwayland only — no full Xorg server.
- **Gaming:** `steam` (with the bazzite-steam wrappers and desktop-entry
  wiring), `gamescope`, `mangohud` (+i686), `gamemode`, `lutris`,
  `scx-scheds`/`scx-tools`, `umu-launcher`, `bazaar`, `bazzite-portal`,
  `input-remapper`, `usbip`, 32-bit NVIDIA + mesa libraries.
- **Apps:** VS Code, Brave, zen-browser (per-use vendor/COPR repos — removed
  again at finalize), zed, emacs-pgtk, neovim; Obsidian, Zotero, Pyprland,
  TeX Live and a Python helper family baked at build time.
- **Tooling:** the former brew formulas as RPMs (bat, eza, fzf, lazygit,
  ripgrep, starship, yazi, zellij, …) **plus a small baked Homebrew payload**
  (only `bun`, `pixi` and `opencode` — the three formulas Fedora and Terra do
  not ship; brewed at build time into `/usr/share/halcyon/brew-bundle.tar.zst`,
  seeded pre-login offline by `halcyon-brew-bundle.service`), chezmoi (Fedora
  RPM) wired to
  [aahsnr-configs/dotfiles](https://github.com/aahsnr-configs/dotfiles)
  (first-login init + update timer, blue-build module semantics), nix via the
  [fu5ha/winter](https://github.com/fu5ha/winter) bind-mount pattern,
  and ujust/uupd (`ublue-os-just` + `uupd`) with curated Bazzite recipes.
- **Flatpak:** package + **flathub user repo only** (no system flathub, no
  Fedora flatpaks); four transition apps install per-user at first login —
  everything else is native RPM.

---

## Repo structure

`build_files/` is organized into one folder per build phase; the
**Containerfile is the single source of ordering truth** — the folders carry
no numbering of their own.

```
├── Containerfile              # 18 RUN stages + hermetic bootc lint
├── Justfile                   # check / fix / lint / test-python / build / verify-image
├── halcyon.env                # dotenv consumed by the Justfile
├── packages.json              # SINGLE SOURCE OF TRUTH for every dnf/flatpak package
├── cosign.pub                 # public signing key (shipped to /etc/pki/containers)
├── build_files/               # the `ctx` stage — never ends up in the image
│   ├── packages-lib           #   jq accessors the stages source (fail-fast)
│   ├── cleanup                #   end-of-RUN temp/log//boot wipe
│   ├── libdnf5.conf.d/        #   dnf5 retry drop-in (installed in Stage 00)
│   ├── base/                  #   setup-repos, remove-packages
│   ├── kernel/                #   install-kernel + kernel-verify (p03 + nvidia-open)
│   ├── packages/              #   install-packages / -terra / -devtools + packages-verify
│   ├── brew/                  #   install-brew-bundle + brew-verify
│   ├── runtime/               #   install-nix, setup-flatpaks, setup-ujust + verifies
│   ├── apps/                  #   obsidian/zotero/pyprland/texlive/python + verify
│   ├── desktop/               #   configure-system, image-info, plymouth, greetd/
│   ├── finish/                #   build-initramfs, finalize, final-verify
│   └── python-packages/       #   11 stdlib-only src-layout Python tools
├── system_files/
│   └── shared/                # root overlay COPYed into the image
│       ├── etc/               #   pam, profile.d, environment.d, …
│       └── usr/               #   units, tmpfiles, ujust modules, plymouth, /usr/bin
└── verify/                    # image-side suites run by CI against the built image
```

Build order and per-level verification are visible in `Containerfile`; every
third-party repo is enabled only inside the stage that consumes it and
disabled immediately after; `finalize` sweeps any leftovers so the shipped
image carries Fedora repos only.

---

## Adding or removing packages (packages.json)

**`packages.json` (repo root) is the single source of truth** for every
package in the image — dnf and flatpak alike, in the
[ublue-os/main](https://github.com/ublue-os/main) style. The build stages
never hardcode package lists: each stage sources `build_files/packages-lib`
and reads its group with jq, and the build **fails fast** if the JSON is
malformed.

Groups are keyed by **the repo a package resolves from**, not by what it does.

| Group                                  | Resolved from                                                 | Consumed by      |
| -------------------------------------- | ------------------------------------------------------------- | ---------------- |
| `fedora-core`                          | Fedora                                                        | install-packages |
| `fedora-hardware`                      | Fedora                                                        | install-packages |
| `fedora-editors`                       | Fedora                                                        | install-packages |
| `hyprland-copr`                        | COPR `lionheartp/Hyprland`                                    | install-packages |
| `gaming`                               | Fedora + RPM Fusion                                           | install-packages |
| `bazaar-copr`                          | COPR `ublue-os/packages`                                      | install-packages |
| `zen-copr`                             | COPR `sneexy/zen-browser`                                     | install-packages |
| `vendor-apps` / `vendor-apps-optional` | per-use vendor repos (VS Code, Brave)                         | install-packages |
| `fedora-devtools`                      | Fedora                                                        | install-devtools |
| `nix`                                  | Fedora                                                        | install-nix      |
| `flatpak`                              | Fedora                                                        | setup-flatpaks   |
| `ujust-copr` / `ujust-fedora`          | COPR `ublue-os/packages` / Fedora                             | setup-ujust      |
| `terra`                                | **Terra only** (`--disablerepo='*'`)                          | install-terra    |
| `all.exclude.all`                      | removals — resolved through `rpm -qa`, absent names tolerated | remove-packages  |
| `flatpak.install` / `flatpak.remove`   | Flathub (user repo, at first login)                           | setup-flatpaks   |

**To add a package:** put its name in the group matching the repo it resolves
from, then rebuild (`just build localhost/halcyon latest`). Only if a brand-new
repo is needed do you also add a group here and a matching enable→install→
disable window in the consuming stage. **To remove one:** delete it from its
group (and, if the base might ship it, add it to `all.exclude.all`).

Rules the stages enforce while consuming the catalog:

- weak deps are **off** on every install — list any former weak dep explicitly;
- `terra` groups resolve **exclusively** from Terra (`--disablerepo='*'`) —
  a missing package fails the build rather than silently falling back;
- third-party repos are enabled only inside the stage that consumes them,
  disabled immediately after, and deleted by `finalize`;
- the comps group `@custom-environment` and the Terra repo-bootstrap packages
  (`terra-release*`) stay in their scripts — they are not catalog entries;
- a few entries exist purely as **build-tool preconditions** (`zstd`,
  `util-linux-core`, `gnupg2`, `jq`, `gcc-c++`) — `packages-verify` gates
  them so they cannot be pruned as "unused".

---

## Build & CI

- `lint.yml` (PR, push, manual): `just check` + `just lint`, the `.github`
  audit (`verify/verify-github.sh`), and the Python helper test suites.
- `build.yml` (daily cron 08:00 UTC, push, PR, manual): polls the consumed
  COPRs for healthy metadata, frees runner disk, runs both syntax gates,
  builds with `podman build --pull`, runs the **image-side verify suite**
  (`verify/verify-{brew,chezmoi,ujust}.sh`) against the built image, writes a
  **package-count report** to the run summary, then signs with cosign
  (`SIGNING_SECRET`) and publishes to GHCR.
- Local test build: `just build localhost/halcyon latest`, then
  `just verify-image localhost/halcyon latest`.
- OCI labels (`org.opencontainers.image.*`) are set from
  `--build-arg IMAGE_VERSION=<fedora>.<date>` and `SOURCE_SHA=<git sha>`
  (CI supplies both). `bootc container lint` runs network-isolated as the
  final gate.

---

## Credits & licenses

Apache-2.0 — see `LICENSE`.

- [Universal Blue](https://universal-blue.org) & [Bazzite](https://bazzite.gg)
  (Apache-2.0) — the project structure this repo follows and the gaming stack.
- [CatPieLeaf/linux-p03](https://github.com/CatPieLeaf/linux-p03) — the p03
  kernel and its prebuilt NVIDIA-open modules.
- [negativo17](https://negativo17.org) — NVIDIA userland.
- [fu5ha/winter](https://github.com/fu5ha/winter) (Apache-2.0) — the nix
  bind-mount pattern.
- [lionheartp/Hyprland COPR](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
  — Hyprland, Noctalia and friends.
- [noctalia](https://github.com/noctalia-dev/noctalia) — the desktop and greeter.
- [blue-build/modules](https://github.com/blue-build/modules) — the
  default-flatpaks behavior our first-login flatpak setup mirrors.
- [greetd](https://git.sr.ht/~kennylevinsen/greetd).
````

---

## `AGENTS.md`

````markdown
# AGENTS.md — halcyon

Guidance for AI coding agents (and humans) working in this repository.
Branch of record: `container`.

Task-level procedures live in **`SKILLS.md`** — read this file first, then
consult `SKILLS.md` when your task matches one of its skills.

---

## 1. What this repo is

`halcyon` builds a **single bootc OCI image**: a lean Hyprland gaming desktop on
`quay.io/fedora/fedora-bootc:44`, with the `catpieleaf/kernel-p03` kernel,
prebuilt `nvidia-open` modules, negativo17 NVIDIA userland, the noctalia greeter
on greetd, and `ujust`/`uupd` for user-facing system tasks.

It is **not** a BlueBuild project and **not** layered on Bazzite. It borrows
Bazzite's _repo structure_ (scratch `ctx` stage, semantic unnumbered build
scripts, per-RUN bind mount, `cleanup` after every mutating RUN, `bootc
container lint` as the final gate) and vendors some Bazzite `.just` recipes and
Steam wrappers, but the base is plain `fedora-bootc`.

The GitHub workflow builds with `podman build` via the Justfile. There is no
BlueBuild action anywhere in `.github/` — if you find a reference to one, you
are looking at the `main` branch.

Output: `ghcr.io/aahsnr-work/halcyon:<tag>`, cosign-signed in CI.

---

## 2. Repository layout

```
Containerfile              # 18 RUN stages (banners 00–17) + hermetic bootc lint
Justfile                   # check / fix / lint / test-python / build / verify-image / tag
halcyon.env                # dotenv consumed by the Justfile (IMAGE_NAME, etc.)
packages.json              # single source of truth for every dnf/flatpak package
cosign.pub                 # public signing key, shipped to /etc/pki/containers
.containerignore           # keeps docs/artifacts/verify out of the build context

build_files/               # the `ctx` stage — NEVER ends up in the image
  packages-lib             # jq accessors every stage sources
  cleanup                  # end-of-RUN hygiene, called after every mutating RUN
  libdnf5.conf.d/          # dnf5 main-config drop-in (installed in Stage 00)
  base/                    # setup-repos, remove-packages
  kernel/                  # install-kernel, kernel-verify
  packages/                # install-packages, install-terra, install-devtools,
                           #   packages-verify
  brew/                    # install-brew-bundle, brew-verify
  runtime/                 # install-nix, setup-flatpaks, setup-ujust + *-verify
  apps/                    # install-built-apps and its five sub-installers,
                           #   built-apps-verify
  desktop/                 # configure-system, image-info, build-plymouth-assets,
                           #   system-verify, branding-verify, greetd/
  finish/                  # build-initramfs, finalize, final-verify
  python-packages/         # 11 stdlib-only src-layout Python tools

system_files/shared/       # static tree COPY'd to / BEFORE any RUN stage
  etc/  usr/               # units, profile.d, plymouth, ujust modules,
                           # /usr/libexec/halcyon-image/* helper scripts

verify/                    # image-side suites CI runs against the built image
```

**Naming:** build scripts are extensionless bash with `#!/usr/bin/env bash` and
`set -euo pipefail`. Verify scripts are named `<stage>-verify` and are invoked
in the same `RUN` as the stage they gate.

**Paths in scripts are `/ctx/<folder>/<script>`** — the ctx stage flattens
`build_files/` to `/`, so `build_files/apps/install-obsidian` is
`/ctx/apps/install-obsidian`.

---

## 3. Commands

```bash
just check          # just --fmt --check, bash -n over build_files + verify,
                    #   py_compile over python-packages, bash -n over recipe bodies
just lint           # shellcheck --shell=bash -x over every build_files script
just test-python    # pytest for the python helpers that have suites
just check-github   # host-side .github audit (verify/verify-github.sh)
just build          # podman build with the CI label/ARG scheme
just verify-image   # run verify/verify-{brew,chezmoi,ujust}.sh inside the image
just package-count  # run the built image, report RPM count + kernel version

podman build --pull -t localhost/halcyon:latest .   # plain local build
```

**Always run `just check` and `just lint` before proposing a change to anything
under `build_files/`.** A missing `fi` or an unquoted expansion in a build
script costs a full ~40-minute CI build.

---

## 4. Build architecture — rules that must not be broken

1. **Stage order is load-bearing.** `setup-repos` runs first (it bootstraps
   `jq`, without which `packages-lib` cannot read `packages.json`); removals
   run second, against the near-pristine base with the smallest dependency
   graph; the initramfs is built _last_ (so the plymouth theme and NVIDIA
   dracut hooks are baked in); `finalize` and `final-verify` close the build.
   Do not reorder without re-reading the comments in `Containerfile` and
   `base/remove-packages`.

2. **Every mutating `RUN` ends with `/ctx/cleanup`.** No exceptions — it wipes
   `/tmp`, dnf logs, `/boot` and the libdnf5 cache so they never reach a layer.

3. **`--setopt=install_weak_deps=False` on every `dnf5 install`.** Anything that
   used to arrive as a weak dependency must be listed explicitly (this is why
   `flatpak-selinux`, `hyprland-guiutils`, `xdg-desktop-portal-{hyprland,gtk}`,
   `qt6ct` and `nwg-look` are spelled out).

4. **Third-party repo lifecycle: enable → consume → disable, inside one stage.**
   COPRs use `dnf5 copr enable` / `dnf5 copr disable` around their install.
   Vendor repo files (vscode, brave) are written, used and `rm`'d in the same
   script. `finalize` is the belt-and-braces sweep; `final-verify` asserts that
   only Fedora repo files remain.

5. **NVIDIA comes from negativo17 only.** RPM Fusion's NVIDIA chain is excluded
   via `excludepkgs=` in `setup-repos`. Four negativo17 subpackages
   (`nvidia-driver`, `nvidia-driver-cuda`, `nvidia-settings`,
   `nvidia-kmod-common`) are dependency-entangled with a kmod package and are
   **payload-extracted via `rpm2cpio`**, not installed. Do not "fix" this by
   adding them to a `dnf5 install` line — it pulls `dkms-nvidia`, which
   `Conflicts` with `kernel-p03-nvidia-open`.

6. **Kernel and NVIDIA RPMs install with `--setopt=tsflags=noscripts`**, because
   RPM `%post` scriptlets fail inside a build container. `depmod` and `dracut`
   are then run explicitly (`install-kernel`, `build-initramfs`).

7. **Per-stage verification.** If you add a stage, add a `<stage>-verify`
   companion and wire it into the same `RUN`. Keep gates in the `gate "desc"
cmd…` form so failures are greppable in CI output. Cross-cutting checks that
   only the finished image can answer go in `final-verify`, not earlier.

8. **This is bootc, not rpm-ostree.** There is no `rpm-ostree` on the running
   system. Kernel arguments are changed with `grubby --update-kernel=ALL`.
   Kernel cmdline is read from `/proc/cmdline`. `bootc status` replaces
   `rpm-ostree status`. Any recipe that shells out to `rpm-ostree` is a bug,
   and `ujust-verify` now gates against it.

9. **A package a recipe shells out to must be in `packages.json`.** `gum`
   (behind `Choose`/`ugum`), `grubby`, `ethtool`, `wget`, `hostname`, `fpaste`,
   `wl-copy`, `zenity` and `jq` are all reachable from ujust recipes and are
   gated in `ujust-verify`. Shipping a recipe whose binary is absent produces a
   silent no-op at runtime that no build gate would otherwise catch.

---

## 5. bootc / image constraints

- `/var` must be effectively empty in the image. Content there without a
  matching `tmpfiles.d` entry triggers the `var-tmpfiles` lint warning, and
  anything you put there is only applied on _initial provisioning_ — later
  upgrades will not see it. Create runtime state with `tmpfiles.d` (see
  `usr/lib/tmpfiles.d/zz-halcyon-nix.conf`, `noctalia-greeter-state.conf`) or a
  oneshot unit (see `var-nix.service`).
- **Never create `/usr/etc`.** `fedora-bootc` ships a real `/etc`; a parallel
  `/usr/etc` tree is the fatal `etc-usretc` lint. The cosign public key lives
  at `/etc/pki/containers/halcyon.pub`, and both `branding-verify` and
  `final-verify` assert `/usr/etc` does not exist.
- `/var/run` must remain a symlink to `/run` — that lint is a hard failure.
- `/boot` must be empty; the kernel lives in `/usr/lib/modules/<kver>/`.
- No `/opt` or `/usr/local` writes; use `/usr/lib/<app>` plus a `/usr/bin`
  symlink (see `install-obsidian`, `install-zotero`, `install-pyprland`).
- The final `RUN … bootc container lint` runs with `--network=none` and a
  tmpfs `/run`. Anything needing the network must happen before it.

---

## 6. Conventions by file type

### Build scripts (`build_files/**`)

- `#!/usr/bin/env bash` + `set -euo pipefail` (use `set -uo pipefail` only when
  the script deliberately accumulates failures and returns its own `rc`).
- Wrap output in `echo "::group::<script> — <phase>"` / `echo "::endgroup::"`
  so GitHub Actions folds it. Use the `  OK  ` / `  WARN  ` / `  FAIL  ` /
  `  SKIP  ` / `  INFO  ` prefixes already in use.
- One package per line in `dnf5 install` lists, alphabetical within a block,
  with a comment naming the block's purpose.
- `# shellcheck source=../packages-lib` — the directive is resolved relative to
  the **script's own directory**, not the repo root.
- If a script tolerates failure (`|| true`), the corresponding verify gate must
  tolerate it too. Mismatches between "optional at install" and "required at
  verify" are a recurring source of red builds.

### Static tree (`system_files/shared/**`)

- This tree is COPY'd **before** any package install. An RPM installed in a
  later stage that owns the same path **will overwrite your file**. Two
  escapes, in order of preference:
  1. **Install it from `/ctx` in the consuming stage instead** — this is what
     `configure-system` does for `/etc/greetd/config.toml` and
     `/etc/pam.d/greetd`, whose source now lives in `build_files/desktop/greetd/`.
  2. For drop-in directories (`tmpfiles.d`, `sysusers.d`, `modprobe.d`), prefix
     so it cannot collide _and_ sorts later — `zz-halcyon-<topic>.conf` — and
     add a verify gate asserting the final content.
- Executable bits come from git. Anything under `usr/bin/` or
  `usr/libexec/halcyon-image/` needs mode `0755` committed
  (`git update-index --chmod=+x`), and should have a `test -x` gate.
- Helper scripts in `/usr/libexec/halcyon-image/` are on `$PATH` for all login
  shells via `etc/profile.d/image-path.sh`.

### profile.d ordering

`00-path-guard.sh` → `01-nix-resolve-home-env.sh` → `02-custom-environment.sh` →
`image-path.sh` → `texlive.sh` (generated). `00-path-guard.sh` uses only shell
builtins on purpose; never add an external command to it. The default login
shell is **zsh** (`/etc/default/useradd`), so confirm that anything you rely on
in `profile.d` is actually reached by zsh's `/etc/zprofile`.

### ujust recipes (`usr/share/ublue-os/just/*.just`)

- Start with `# vim: set ft=make :`, give every recipe a doc comment and a
  `[group("…")]`.
- Register new modules by adding the filename to the loop in
  `runtime/setup-ujust`, which writes `/usr/share/ublue-os/just/60-custom.just`.
- Interactive recipes `source /usr/lib/ujust/ujust.sh` and use `Choose`.
  `Choose`/`ugum` are **wrappers around the `gum` binary** — the function
  shipping in `ublue-os-just` is not the same thing as `gum` being installed,
  which is why `gum` is an explicit `ujust-fedora` entry.
- Recipe bodies are shell scripts, and `just --fmt --check` does **not** parse
  them. `just check` now runs `bash -n` over every body; keep it that way.
- Vendored Bazzite recipes must be de-Bazzited: no `rpm-ostree`, and every
  binary they call must be in `packages.json`.

### Python packages

Stdlib only, zero pip dependencies — the shared venv at
`/usr/lib/halcyon-python` has no dependency resolution safety net. Add the
package directory name to `EXPECTED` in `apps/install-python-packages`, to the
table in `build_files/python-packages/README.md`, and to the loop in
`apps/built-apps-verify`. Every tool must answer `-h` or `--version`
non-interactively; that is the build-time smoke test — **and it is not enough**.
`just check` compiles every module and `just test-python` runs the real suites,
because `-h` never reaches the code that does the work (a missing `datetime`
import once shipped in `rmi` for exactly that reason).

---

## 7. Known traps (read before touching these areas)

- **Verify gates must match what `systemctl enable` actually does.**
  `systemctl enable foo` in a container writes
  `/etc/systemd/system/<target>.wants/foo`, **not** `/usr/lib/systemd/...`.
  Gate with `systemctl is-enabled`, or test the `/etc` path.
- **Prove every new gate can fail.** Invert it temporarily and confirm the
  script exits 1. `final-verify` used to carry a "terra repos all disabled"
  gate that matched a glob `finalize` had already deleted — it could never
  fail. A gate that cannot fail is worse than no gate.
- **`install-pyprland`**: upstream _does_ ship `systemd-unit/pyprland.service`,
  so the `else` branch never runs. Anything that must apply to both the upstream
  and inline unit (the `ConditionEnvironment` drop-in) has to live **outside**
  that `if`.
- **`ConditionEnvironment=` on a user unit** reads the _systemd user manager's_
  environment. It only works if the session exports `XDG_CURRENT_DESKTOP` into
  it (`dbus-update-activation-environment --systemd` / `systemctl --user
import-environment`). Verify in the Hyprland config, not just in the unit.
- **The brew timers gate on a symlink.** `brew-update.service` and
  `brew-upgrade.service` use `ConditionPathIsSymbolicLink=…/bin/brew`. If the
  payload ever carries a regular file there, both skip forever and say nothing.
  `brew-verify` asserts the link survives the pack — keep that gate.
- **The Brewfile is deliberately three formulas.** `bun`, `pixi`, `opencode`.
  Anything with a Fedora or Terra RPM belongs in `packages.json`: the brew bin
  dirs are _appended_ to PATH, so a brewed duplicate can never be the binary
  that runs, and it still costs build time and payload size.
- **Package names change between Fedora releases.** Terra retired
  `terra-gamescope`/`terra-mangohud`; `lazygit` ships as
  `golang-github-jesseduffield-lazygit`; the `nodejs` module naming moves most
  releases. Before adding a package, verify it resolves for F44 from the repo
  you expect — `dnf5` aborts the _whole transaction_ on one bad name.
- **Build-tool preconditions are invisible dependencies.** `zstd`,
  `util-linux-core` (setpriv), `gnupg2`, `jq` and `gcc-c++` are consumed by
  later stages, not by the desktop. `packages-verify` gates them so they cannot
  be pruned as "unused".

---

## 8. CI

- `.github/workflows/lint.yml`: `just check` + `just lint`, the `.github` audit,
  and the Python helper suites. Runs on PR and push.
- `.github/workflows/build.yml`: polls the consumed COPR repodata (Copr's CDN
  intermittently 504s), runs both syntax gates, `just build`, the image-side
  `verify/` suite, the package-count report, tagging, push to GHCR and cosign
  signing. Push and sign only run on branch pushes, not PRs.
- `.github/workflows/clean.yml`: weekly GHCR pruning.

If you add a COPR that the build consumes, add its `repomd.xml` URL to the
`URLS` array in the "Wait for Copr metadata availability" step.

---

## 9. Checklist before proposing a change

- [ ] `just check` and `just lint` pass.
- [ ] `just test-python` passes if you touched `build_files/python-packages/`.
- [ ] Recipe bodies syntax-checked if you touched a `.just` file.
- [ ] New install stage has a `<stage>-verify` companion wired into the same RUN.
- [ ] Every new gate has been inverted once and confirmed to fail.
- [ ] New `dnf5 install` uses `--setopt=install_weak_deps=False`.
- [ ] Any third-party repo enabled is disabled in the same stage.
- [ ] Every binary a new recipe calls is in `packages.json` and gated.
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/opt`, `/usr/local` or `/boot`.
- [ ] New files in `system_files/shared/usr/bin` or `usr/libexec` are mode 0755.
- [ ] No new path collides with an RPM-owned path installed in a later stage.
- [ ] Comments that describe _why_ (upstream bug, dependency conflict, ordering
      constraint) are preserved — this repo's comments are its design docs.
````

---

## `SKILLS.md` — corrected sections

The file is ~700 lines and most of it is still accurate. These are the blocks that are now wrong; replace them in place rather than rewriting the whole registry.

**Replace the `add-build-stage` → Steps 1, 2 and 4:**

````markdown
1. **Name the script** `build_files/<folder>/<verb>-<subject>`, extensionless,
   matching the existing vocabulary: `install-*`, `setup-*`, `configure-*`,
   `build-*`, `remove-*`. Pick the folder by build phase — `base/ kernel/
packages/ brew/ runtime/ apps/ desktop/ finish/`. Commit it executable:

   ```bash
   git add build_files/runtime/install-foo
   git update-index --chmod=+x build_files/runtime/install-foo
   ```

2. **Skeleton** (copy the shape of `runtime/install-nix`, the smallest real
   example). Note the shellcheck directive is relative to the SCRIPT's
   directory, not the repo root:

   ```bash
   #!/usr/bin/env bash
   # halcyon build step — install-foo (one line on WHY this stage exists)
   set -euo pipefail
   # shellcheck source=../packages-lib
   source /ctx/packages-lib
   packages_validate
   echo "::group::install-foo — <phase>"
   readarray -t FOO_PKGS < <(packages_for foo)
   dnf5 -y --setopt=install_weak_deps=False install \
     "${FOO_PKGS[@]}"
   echo "::endgroup::"
   ```

3. **Insert the `RUN` block** in `Containerfile` at the correct position, with
   a stage banner. Use this form verbatim when the stage calls `dnf5`:

   ```dockerfile
   # ---- Stage N: foo ----------------------------------------------------------
   RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
       --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
       echo "████ STAGE NN/17 · install-foo · <summary> ████" \
       && /ctx/runtime/install-foo && /ctx/runtime/install-foo-verify && /ctx/cleanup
   ```

   Drop the `type=cache` mount if the stage never touches `dnf5`.
````

**Replace the `add-verify-gate` → "Gate forms that are wrong in this environment" list:**

```markdown
- **`test -e /usr/lib/systemd/system/<target>.wants/<unit>`** — `systemctl
enable` inside a build container writes to **`/etc/systemd/system/…`**.
  Use `systemctl is-enabled <unit>`, which is path-agnostic.
- **A gate whose glob a later stage deletes.** `final-verify` carried
  `! grep -l "^enabled=1" /etc/yum.repos.d/terra*.repo | grep -q .` — but
  `finalize` deletes those files, so the glob matched nothing and the gate
  passed unconditionally. Gate the property that survives.
- **`test "${VAR}" = "$(...)"` where VAR may be empty.** If both sides fail to
  produce a value, `test "" = ""` PASSES. The NVIDIA userland/module version
  gate needs a companion `test -n "${NV_MOD_VER}"` in front of it.
- **Gating a package that was installed with `|| true`.** Either the package is
  required (drop the `|| true`) or it is optional (drop the gate).
- **Gating a path inside a directory that may not exist** — `grep -rq pattern
/some/dir/` returns non-zero for "directory missing" _and_ "pattern absent".
  Add a `test -d` gate alongside it.
- **Gating a file's existence when an RPM may rewrite its content.** Gate the
  content (`grep -q` for the line that matters), or install the file from
  `/ctx` after the RPM lands — see `configure-system`'s greetd handling.
```

**Replace the `add-rpm-package` → Step 2 table:**

```markdown
| Source                           | File                                                | How                                           |
| -------------------------------- | --------------------------------------------------- | --------------------------------------------- |
| Fedora (core/hardware)           | `packages.json` → `fedora-core` / `fedora-hardware` | alphabetical in the group                     |
| Fedora (editors/runtimes)        | `packages.json` → `fedora-editors`                  | alphabetical                                  |
| Fedora (CLI dev tooling)         | `packages.json` → `fedora-devtools`                 | alphabetical                                  |
| Fedora (ujust recipe dependency) | `packages.json` → `ujust-fedora`                    | and add a `command -v` gate to `ujust-verify` |
| Terra                            | `packages.json` → `terra`                           | resolves exclusively from Terra               |
| A COPR                           | `packages.json` → that COPR's group                 | the stage owns `copr enable`/`disable`        |
| Vendor repo (MS, Brave)          | `packages.json` → `vendor-apps`                     | ONLY if it truly resolves from that repo      |
```

**Replace the `remove-package-or-file` → "Caveat on the inherited removal machinery" section entirely:**

```markdown
### The inherited removal machinery is gone

`guarded-removals`, `file-footprint`, `gnome-extensions` and `fonts-cleanup`
were written when halcyon was layered on Bazzite. On a bare `fedora-bootc`
base every one of their targets is absent, so they were ~400 lines of no-op
whose header comments described an ordering that no longer held. They have
been deleted.

The two parts that carried real value now live in `base/remove-packages`:
the **reverse-dependency gate** (used for `sddm`/`cage`) and the
**must-not-survive hard-fail loop**. Add to those rather than resurrecting
the old scripts.

For file-level removal of something no RPM owns, write the removal inline in
the stage that creates the condition — there is no longer a general-purpose
file-footprint script to extend.
```

**Replace the `bump-fedora-release` → step 5:**

```markdown
5. `Justfile`: nothing to change — `fedora_version` comes from `halcyon.env`
   and flows into both `generate-build-tags` and the `IMAGE_VERSION` build
   arg. (The old hardcoded `"44"` entries and the `rpm -E %fedora` call on the
   runner were removed in D20.) Change `FEDORA_VERSION` in `halcyon.env`.
```

And in **"Where this file lives"**, the `.containerignore` note is now satisfied — `AGENTS.md`, `SKILLS.md` and `verify/` are all excluded.

---

## `build_files/python-packages/README.md`

````markdown
# halcyon Python packages

Staged into the image at build time by `build_files/apps/install-built-apps`
(→ `/usr/src/python-packages`) and installed by
`build_files/apps/install-python-packages` into one shared venv at
`/usr/lib/halcyon-python`. Every console script is symlinked separately into
`/usr/bin`, so each tool is its own binary on PATH. All packages are
stdlib-only (zero pip dependencies) and build-verified by
`build_files/apps/built-apps-verify`.

| Package            | Binary             | Purpose                                                                         |
| ------------------ | ------------------ | ------------------------------------------------------------------------------- |
| `dump-to-markdown` | `dump-to-markdown` | Dump a project tree into one Markdown document (headings + fenced code blocks). |
| `fconf`            | `fconf`            | Fuzzy configuration finder/editor (fd \| fzf \| bat \| `$EDITOR`).              |
| `fe`               | `fe`               | Fuzzy edit — pick a file with fd/fzf, open in `$EDITOR`.                        |
| `ff`               | `ff`               | Fast file finder wrapping `fd` with a `find` fallback.                          |
| `fkill`            | `fkill`            | Fuzzy process killer (`ps` \| fzf, SIGTERM/SIGKILL).                            |
| `fp`               | `fp`               | Fuzzy file/directory previewer (fd \| fzf, composable stdout).                  |
| `fssh`             | `fssh`             | Fuzzy SSH launcher driven by `~/.ssh/config`.                                   |
| `rmi`              | `rmi`              | Safe removal to the XDG trash with collision handling.                          |
| `rmtmp`            | `rmtmp`            | Root-only secure cleanup of old files in `/tmp` and `/var/tmp`.                 |
| `screenshot`       | `screenshot`       | Wayland screenshot helper (`grim` \| swappy; slurp region, niri window).        |
| `se`               | `se`               | Search & edit — ripgrep \| fzf \| `$EDITOR` at the matched line.                |

Runtime tool dependencies (`fd`, `fzf`, `bat`, `rg`, `grim`, `swappy`, `slurp`)
are provided by the image's RPM layer; each tool checks for its own
dependencies at startup and exits with a clear message if missing.

## Registering a new package

Three places, all required:

1. the `EXPECTED` array in `build_files/apps/install-python-packages`
2. the table above
3. the `for b in …` loop in `build_files/apps/built-apps-verify`

## Development and tests

Each directory is a standalone src-layout package.

```sh
python3 -m venv .venv && .venv/bin/pip install -e './dump-to-markdown[dev]'
.venv/bin/pytest dump-to-markdown
```
````

`dump-to-markdown` and `rmi` have suites; `just test-python` runs both.

**The build-time smoke test (`-h` / `--version`) is not sufficient on its
own.** It never reaches the code that does real work — a missing `datetime`
import shipped in `rmi` and only surfaced when a user actually trashed a file.
`just check` now runs `python3 -m py_compile` over every module, which catches
that class of bug; add a `tests/` directory for anything with meaningful
side effects.

````

---

## `build_files/python-packages/dump-to-markdown/README.md`

```markdown
# dump-to-markdown

Walk every file and folder under a project root and produce a single
Markdown document containing, for every file found, a heading with its
project-relative path (e.g. `myproject/src/main.py`) followed by a fenced
code block holding that file's contents. Fence language hints are chosen
from extension, exact filename, or shebang, so blocks get sensible syntax
highlighting wherever the Markdown is rendered.

Only `.git` is skipped by default; everything else — including dotfiles —
is included. Stdlib-only: no third-party runtime dependencies.

## Install

halcyon bakes this into the built image (`/usr/bin/dump-to-markdown`) at
build time via `build_files/apps/install-python-packages`, which installs
every helper into the shared venv at `/usr/lib/halcyon-python`. For use on a
dev machine, install it from this directory:

```sh
uv tool install ./build_files/python-packages/dump-to-markdown
# or
pipx install ./build_files/python-packages/dump-to-markdown
# or
python3 -m pip install --user ./build_files/python-packages/dump-to-markdown
````

## Usage

```sh
dump-to-markdown
dump-to-markdown --root /path/to/project --output dump.md
dump-to-markdown --exclude-dir node_modules --exclude-dir .venv
dump-to-markdown --max-size 500000
dump-to-markdown --follow-symlinks
dump-to-markdown -v
python3 -m dump_to_markdown   # module form
```

## Options

| Option                  | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `--root PATH`           | Root directory to scan (default: current directory)                 |
| `--output, -o PATH`     | Markdown file to write (default: `./project_dump.md`)               |
| `--exclude-dir DIRNAME` | Extra excluded dir name (repeatable; `.git` always excluded)        |
| `--max-size BYTES`      | Skip embedding files larger than this many bytes                    |
| `--follow-symlinks`     | Descend into symlinked dirs (a symlink cycle hangs, like `find -L`) |
| `-v, --verbose`         | Debug-level logging                                                 |
| `--version`             | Print version and exit                                              |

Exit codes: `0` success · `1` bad root or write failure · `130` interrupted.

## Development

```sh
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
.venv/bin/pytest
```

Or from the repo root: `just test-python`.

Apache-2.0 — see the repo root `LICENSE`.

```

---

## Suggested order of work

1. **#1, #2, #3, #4** — unblock the build.
2. **#5, #6** — one-line fixes with user-visible impact.
3. **#11, #13** — wire the verification you already wrote; it will catch the next round for you.
4. **#12, #17** — delete dead weight (~400 lines of scripts, 19 redundant formulas).
5. **#14, #15, #16** — metadata and docs, so the next audit starts from an accurate map.
6. Everything else as cleanup.

Two things to check before you commit any of this: the action majors in `build.yml` (I left them untouched and can't verify them), and the `nodejs`/`npm` package names on F44 — run the `verify-package-availability` skill on both.
```
