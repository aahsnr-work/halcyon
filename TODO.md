# TODO

- [ ] ghcr.io/aahsnr-work/halcyon.

- [ ] The recipe.yml file in recipes folder should be called `halcyon.yml` and this should be reflected in the build.yml in .github.

- [ ] I don't want a single monolithic recipe yml file Instead I want something like the multiple yml files like from the following yml code block:

```yml
modules:
  # -------------------------------------------------------------------------
  # Modular build: these from-file includes are an exact 1:1 split of the
  # inline modules below. To switch to the modular layout, delete the inline
  # entries and uncomment the from-file lines here (paths are relative to
  # recipes/): https://blue-build.org/how-to/multiple-files/
  - from-file: bazzfin-base.yml
  - from-file: bazzfin-kernel.yml
  - from-file: bazzfin-packages-core.yml
  - from-file: bazzfin-packages-terra.yml
  - from-file: bazzfin-packages-system.yml
  - from-file: bazzfin-desktop.yml
  - from-file: bazzfin-apps.yml
  - from-file: bazzfin-flatpaks.yml
  - from-file: bazzfin-services.yml
```

Keep in mind that the final multiple yml files will not be the same yml files as the above yml code block but they must be located within the modules subfolder of the recipes folder containing halcyon.yml file.

- [ ] Certain list of dnf packages must be removed first in the halcyon.yml file before any other packages are installed using dnf

- [ ] For all the dnf modules, `install-weak-deps` must be set to `false` in the recipe files at all times.

- [ ] The flatpak list is in the following yml code block screenshot and it should use the system scope.

```yml
- type: default-flatpaks
    configurations:
      - scope: system
        notify: true
        install:
          - com.github.tchx84.Flatseal
          - org.onlyoffice.desktopeditors
          - com.bitwarden.desktop
          - com.ticktick.TickTick
      - scope: system
        notify: true
        install: []
```

- [ ] Confirm that the bazzite base image I am using does not have fedora flatpak repo.

- [ ] I will also need to remove all the flatpaks installed in the base bazzite image using the flatpaks module from https://github.com/blue-build/modules

- [ ] I need the nix setup from https://github.com/fu5ha/winter . Study that repository carefully.

- [ ] First determine if the base bazzite image I will be using will have justfiles intetegation or not. If not, then I need justfiles module integration from https://github.com/blue-build/modules as well custom justfiles like the following justfiles integrated into my custom image:

```just
# vim: set ft=make :

# Set up Doom Emacs after first login
[group("doom")]
doom-setup:
    #!/usr/bin/bash
    set -euo pipefail

    if [[ -e "$HOME/.config/doom" ]]; then
        echo "~/.config/doom already exists; aborting to avoid clobbering it." >&2
        exit 1
    fi

    echo "Cloning Doom Emacs configuration..."
    git clone git@github.com:aahsnr-configs/doom.git "$HOME/.config/doom"
    echo "(doom! :config literate)" > "$HOME/.config/doom/init.el"
    git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"

    echo "Installing Doom Emacs..."
    "$HOME/.config/emacs/bin/doom" install
    "$HOME/.config/emacs/bin/doom" sync --gc

    echo
    echo "Doom Emacs is set up. Start it with: emacs"

```

```just
# vim: set ft=make :

# Bootstrap Nix Home Manager (standalone) after first login
[group("nix")]
home-manager-setup:
    #!/usr/bin/bash
    set -euo pipefail

    CONFIG_DIR="$HOME/.config/home-manager"

    if [[ -e "${CONFIG_DIR}" ]]; then
        echo "${CONFIG_DIR} already exists; Home Manager looks like it's already set up." >&2
        echo "To update it instead, run: home-manager switch" >&2
        exit 1
    fi

    if ! command -v nix >/dev/null 2>&1; then
        echo "nix not found on PATH; is the nix/nix-daemon module enabled?" >&2
        exit 1
    fi

    echo "Bootstrapping Home Manager via nix run home-manager/master..."
    nix run home-manager/master -- init --switch

    echo
    echo "Home Manager is installed and activated. Future updates:"
    echo "  home-manager switch"

```

- [ ] I need proper chezmoi integration with dotfiles pointing to https://github.com/aahsnr-configs/dots . The files will be modified later and chezmoi integration will be done at a later stage. Determine if the bazzite base image already has chezmoi integration. If not, you must use the chezmoi module from https://github.com/blue-build/modules . The dotfiles must be ready to be used when the user first logs in after a rebase.

- [ ] Safely remove any and all the fonts installed using dnf in the base bazzite image and instead use the fonts module from https://github.com/blue-build/modules exactly like the following yml code block:

```yml
- type: fonts
  fonts:
    nerd-fonts:
      - JetBrainsMono
      - NerdFontsSymbolsOnly
    google-fonts:
      - JetBrains Mono
      - Noto Emoji
      - Noto Color Emoji
```

- [ ] I am not sure if the siging module from https://github.com/blue-build/modules would be needed since I am using a bazzite image as the base image in halcyon.yml file.

- [ ] sched_ext/BORE preferences and packages should be used if the base bazzite image I am using has it.

- [ ] Vscode, brave-browser and brave-origin browsers must be baked into the custom image using their official install instructions below:

`vscode`

```sh
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
sudo dnf install code
```

`brave* packages`

```sh
sudo dnf install dnf-plugins-core

sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

sudo dnf install brave-browser brave-origin
```

However you must not use a script to install vscode, and the brave-browsers but instead use the dnf module in halcyon.yml with the appropriate and correct method.

- [ ] zen-browser must be installed from the `sneexy/zen-browser` fedora copr in the dnf module using the package name `zen-browser`

- [ ] zed editor should be installed from the terra repo in the dnf module using the package name `zed`

- [ ] search the web and any of the browsers mentioned so far install their binaries in /opt directory in a normal fedora workstation distribution because /opt does not exist in any fedora based immutable distribution. You need to implement a fix before any of these browsers are installed.

- [ ] all copr repos, repos for vscode and brave browsers and the terra repo must be removed right after their respective packages are installed

- [ ] I am aware the base bazzite image uses the ublue-os/brew image, so using the brew module from https://github.com/blue-build/modules might be redundant as the base bazzite image I am using will be setting up brew. Nevertheless, I need the following brew packages available to me when I login to my custom image for the 1st time after rebasing to it:

```txt
atuin
bat
btop
bun
cava
chafa
direnv
dust
eza
fd
fzf
gnuplot
lazygit
pandoc
pixi
ripgrep
starship
tealdeer
uv
yazi
zellij
```

- [ ] The following bash scripts must be executed at build time in github workflow to install the respective packages at build time and bake them into the custom image:

`install-obsidian.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Obsidian from AppImage into /usr/lib/obsidian ==="
OBSIDIAN_TMP="$(mktemp -d)"
trap 'rm -rf "${OBSIDIAN_TMP}"' EXIT

cd "${OBSIDIAN_TMP}"

# Query GitHub API for the latest Obsidian AppImage URL, with fallback.
APPIMAGE_URL="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null |
  jq -r '.assets[] | select(.name | test("(?i)\\.appimage$")) | .browser_download_url' |
  head -n1 || true)"

if [ -z "${APPIMAGE_URL}" ] || [ "${APPIMAGE_URL}" = "null" ]; then
  # Fallback known release URL
  APPIMAGE_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.7/Obsidian-1.8.7.AppImage"
fi

echo "Downloading Obsidian AppImage from ${APPIMAGE_URL}..."
curl -fsSL "${APPIMAGE_URL}" -o obsidian.AppImage
chmod +x obsidian.AppImage

echo "Extracting AppImage contents..."
./obsidian.AppImage --appimage-extract

INSTALL_DIR="/usr/lib/obsidian"
mkdir -p "${INSTALL_DIR}"
cp -rf squashfs-root/* "${INSTALL_DIR}/"

ln -sf "${INSTALL_DIR}/obsidian" /usr/bin/obsidian

if [ -f "${INSTALL_DIR}/obsidian.desktop" ]; then
  install -Dm644 "${INSTALL_DIR}/obsidian.desktop" /usr/share/applications/obsidian.desktop
  sed -i 's|^Exec=.*|Exec=/usr/bin/obsidian %U|' /usr/share/applications/obsidian.desktop
  sed -i 's|^Icon=.*|Icon=obsidian|' /usr/share/applications/obsidian.desktop
fi

for icon in "${INSTALL_DIR}"/usr/share/icons/hicolor/*/apps/obsidian.png "${INSTALL_DIR}/obsidian.png"; do
  if [ -f "${icon}" ]; then
    install -Dm644 "${icon}" /usr/share/icons/hicolor/512x512/apps/obsidian.png
    break
  fi
done

update-desktop-database /usr/share/applications &>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor &>/dev/null || true

echo "Obsidian successfully baked into /usr/lib/obsidian"
```

`install-zotero.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Zotero to /usr/lib/zotero ==="
ZOTERO_INSTALL_DIR="/usr/lib/zotero"
ZOTERO_TMP="$(mktemp -d)"
trap 'rm -rf "${ZOTERO_TMP}"' EXIT

if curl -fsSL 'https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64' -o "${ZOTERO_TMP}/zotero.tar.archive"; then
  mkdir -p "${ZOTERO_INSTALL_DIR}"
  tar -xf "${ZOTERO_TMP}/zotero.tar.archive" -C "${ZOTERO_INSTALL_DIR}" --strip-components=1
  "${ZOTERO_INSTALL_DIR}/set_launcher_icon" || true
  if [ -f "${ZOTERO_INSTALL_DIR}/zotero.desktop" ]; then
    install -Dm644 "${ZOTERO_INSTALL_DIR}/zotero.desktop" /usr/share/applications/zotero.desktop
  fi
  ln -sf "${ZOTERO_INSTALL_DIR}/zotero" /usr/bin/zotero
  install -d "${ZOTERO_INSTALL_DIR}/distribution"
  cat >"${ZOTERO_INSTALL_DIR}/distribution/policies.json" <<'POLICY'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
POLICY
  echo "Zotero successfully installed to ${ZOTERO_INSTALL_DIR}"
else
  echo "WARNING: Failed to download Zotero tarball" >&2
fi
```

`install-pyprland.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Pyprland from GitHub Releases into /usr/lib/pyprland ==="

PYPR_TMP="$(mktemp -d)"
trap 'rm -rf "${PYPR_TMP}"' EXIT

cd "${PYPR_TMP}"

# Query GitHub API for latest release tag with fallback
LATEST_TAG="$(curl --fail --retry 5 --retry-delay 2 -sSL \
  https://api.github.com/repos/hyprland-community/pyprland/releases/latest 2>/dev/null |
  jq -r '.tag_name // empty' || true)"

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  LATEST_TAG="3.4.4"
  echo "GitHub API unavailable or rate-limited; using fallback version ${LATEST_TAG}."
else
  echo "Resolved latest Pyprland release: ${LATEST_TAG}"
fi

TARBALL_URL="https://github.com/hyprland-community/pyprland/archive/refs/tags/${LATEST_TAG}.tar.gz"
echo "Downloading Pyprland source from ${TARBALL_URL}..."
curl -fsSL "${TARBALL_URL}" -o pyprland.tar.gz

tar -xzf pyprland.tar.gz
cd "pyprland-${LATEST_TAG}"

# Create isolated Python virtualenv in /usr/lib/pyprland
INSTALL_DIR="/usr/lib/pyprland"
rm -rf "${INSTALL_DIR}"
python3 -m venv "${INSTALL_DIR}"

"${INSTALL_DIR}/bin/pip" install --no-cache-dir --upgrade pip setuptools wheel hatchling
"${INSTALL_DIR}/bin/pip" install --no-cache-dir .

# Compile fast C client if gcc is available
if [ -f "client/pypr-client.c" ] && command -v gcc &>/dev/null; then
  echo "Compiling pypr-client C helper..."
  gcc -O3 client/pypr-client.c -o /usr/bin/pypr-client || true
fi

# Link pypr CLI binaries to /usr/bin
ln -sf "${INSTALL_DIR}/bin/pypr" /usr/bin/pypr
ln -sf "${INSTALL_DIR}/bin/pypr-quickstart" /usr/bin/pypr-quickstart
[ -f "${INSTALL_DIR}/bin/pypr-gui" ] && ln -sf "${INSTALL_DIR}/bin/pypr-gui" /usr/bin/pypr-gui

# Install a systemd user service (used instead of exec-once in Hyprland config)
mkdir -p /usr/lib/systemd/user
if [ -f "systemd-unit/pyprland.service" ]; then
  install -Dm644 "systemd-unit/pyprland.service" /usr/lib/systemd/user/pyprland.service
else
  cat > /usr/lib/systemd/user/pyprland.service <<'UNIT'
[Unit]
Description=Starts pyprland daemon
After=graphical-session.target
Wants=graphical-session.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
ExecStartPre=/bin/sh -c '[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] || exit 0'
ExecStart=/usr/bin/pypr
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT
fi

echo "Pyprland ${LATEST_TAG} successfully installed to ${INSTALL_DIR} and linked to /usr/bin/pypr."
```

`install-texlive.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing TeX Live (scheme-medium) to /usr/lib/texlive ==="
TEXLIVE_INSTALL_DIR="/usr/lib/texlive"
mkdir -p "${TEXLIVE_INSTALL_DIR}"

# Additional TeX Live packages to install via tlmgr at build time.
# Add any individual packages here that you would like baked into the immutable image.
EXTRA_TL_PACKAGES=(
  latexmk
  biber
)

TEXLIVE_TMP="$(mktemp -d)"
trap 'rm -rf "${TEXLIVE_TMP}"' EXIT

if curl -fsSL https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz -o "${TEXLIVE_TMP}/install-tl-unx.tar.gz"; then
  tar -xzf "${TEXLIVE_TMP}/install-tl-unx.tar.gz" -C "${TEXLIVE_TMP}"
  cat >"${TEXLIVE_TMP}/texlive.profile" <<EOF
selected_scheme scheme-medium
TEXDIR ${TEXLIVE_INSTALL_DIR}
TEXMFLOCAL ${TEXLIVE_INSTALL_DIR}/texmf-local
TEXMFSYSVAR ${TEXLIVE_INSTALL_DIR}/texmf-var
TEXMFSYSCONFIG ${TEXLIVE_INSTALL_DIR}/texmf-config
instopt_adjustpath 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
  INSTALLER="$(find "${TEXLIVE_TMP}" -mindepth 2 -maxdepth 2 -name 'install-tl' -type f -perm /111 | head -n1)"
  if [[ -n "${INSTALLER}" && -x "${INSTALLER}" ]]; then
    "${INSTALLER}" \
      -profile "${TEXLIVE_TMP}/texlive.profile" \
      -no-interaction || echo "WARNING: install-tl exited non-zero" >&2
  else
    echo "ERROR: install-tl installer executable not found under ${TEXLIVE_TMP}" >&2
    exit 1
  fi

  TEXLIVE_BINDIR="$(find "${TEXLIVE_INSTALL_DIR}" -maxdepth 3 -type d -name 'x86_64-linux' | head -n1)"
  if [ -n "${TEXLIVE_BINDIR}" ]; then
    # Install additional TeX Live packages via tlmgr during image build
    if [ ${#EXTRA_TL_PACKAGES[@]} -gt 0 ]; then
      echo "Installing additional TeX Live packages via tlmgr: ${EXTRA_TL_PACKAGES[*]}..."
      "${TEXLIVE_BINDIR}/tlmgr" install "${EXTRA_TL_PACKAGES[@]}" || echo "WARNING: tlmgr package installation exited non-zero" >&2
    fi

    install -d /etc/profile.d
    cat >/etc/profile.d/texlive.sh <<EOF
# TeX Live (installed under /usr/lib/texlive during image build)
export PATH="${TEXLIVE_BINDIR}:\$PATH"
export MANPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/man:\${MANPATH:-}"
export INFOPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/info:\${INFOPATH:-}"
EOF
    chmod 644 /etc/profile.d/texlive.sh
    echo "TeX Live successfully installed to ${TEXLIVE_INSTALL_DIR}"
  else
    echo "WARNING: Could not locate TeX Live bin directory." >&2
  fi
else
  echo "WARNING: Could not download install-tl-unx.tar.gz from CTAN" >&2
fi
```

- [ ] The following bash scripts must be baked into the custom image itself (unlike the above bash scripts that installed packages) and these new bash scripts must not contain a .sh extension. They should likely be placed in `files/system/usr/libexec/halcyon-image` of the root folder of the halcyon project. These bash scripts should be executable and be named exactly as the heading before their respective sh code blocks name them:

`fconf`

```sh
#!/usr/bin/env bash
# fconf
# Strict Mode:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PATHS...]

Description:
  A fuzzy configuration finder and editor. Searches for hidden files and regular
  files in specified directories (or defaults to current directory and home),
  previews them with syntax highlighting, and opens your selection in your
  preferred editor.

Arguments:
  PATHS...          Optional directories to search. If provided, only these paths
                    will be searched. If omitted, defaults to current directory (.)
                    and home directory (\$HOME).

                    Examples:
                      fconf                    # Search . and \$HOME
                      fconf /etc               # Search only /etc
                      fconf /etc ~/.config     # Search /etc and ~/.config

Options:
  -h, --help        Show this help message and exit

Environment Variables:
  EDITOR            The editor to use for opening files (default: nvim)
                    You can override this by setting EDITOR in your shell:
                      export EDITOR=nano
                      export EDITOR=emacs
                      export EDITOR=code

Required Dependencies:
  The following CLI tools must be installed and available in your PATH:

  1. fd    - A simple, fast and user-friendly alternative to 'find'
             Install: https://github.com/sharkdp/fd

  2. fzf   - A command-line fuzzy finder
             Install: https://github.com/junegunn/fzf

  3. bat   - A cat clone with syntax highlighting (used for file previews)
             Install: https://github.com/sharkdp/bat

  If any of these tools are missing, the script will fail. Please install them
  using your system's package manager (apt, dnf, brew, pacman, etc.).

Examples:
  # Search current directory and home with default editor (nvim)
  fconf

  # Search only /etc directory
  fconf /etc

  # Search multiple custom directories
  fconf ~/.config /etc/nginx

  # Use a different editor for this session
  EDITOR=nano fconf

  # Use a different editor permanently (add to ~/.bashrc or ~/.zshrc)
  export EDITOR=emacs
  fconf

How It Works:
  1. fd finds all files (including hidden ones) in the search paths
  2. fzf presents an interactive fuzzy finder interface
  3. bat provides syntax-highlighted previews as you navigate
  4. Your selected file opens in nvim (or your configured EDITOR)

Tips:
  - In the fzf interface, just start typing to filter files
  - Use arrow keys or Ctrl-j/k to navigate
  - Press Enter to select and open a file
  - Press Esc or Ctrl-c to cancel without opening anything
  - The preview window shows file contents with syntax highlighting

EOF
}

main() {
    # Parse command-line arguments
    local search_paths=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Use -h or --help for usage information." >&2
                exit 1
                ;;
            *)
                # It's a path argument
                search_paths+=("$1")
                ;;
        esac
        shift
    done

    # If no paths provided, use defaults
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        search_paths=("." "$HOME")
    fi

    # Run fd to find files and pipe to fzf
    # fd: --type f (files only), --hidden (include hidden files), . (match all)
    # fzf: Interactive fuzzy finder with preview using bat
    # The '|| true' prevents 'set -e' from terminating if user cancels (exit code 130)
    local selected
    selected=$(fd --type f --hidden . "${search_paths[@]}" 2>/dev/null | \
        fzf --height=60% \
            --layout=reverse \
            --border=rounded \
            --prompt="Edit Config > " \
            --no-multi \
            --preview 'bat --style=numbers --color=always {}' || true)

    # Check if user cancelled or no file was selected
    if [[ -z "$selected" ]]; then
        echo "No file selected. Exiting."
        exit 0
    fi

    # Open the selected file with the configured editor (default: nvim)
    echo "Opening: $selected"
    "${EDITOR:-nvim}" "$selected"
}

main "$@"
```

`fe`

```sh
#!/usr/bin/env bash
#
# fe - Fuzzy Edit
# Interactive file finder and editor using fd, fzf, and bat
#

set -euo pipefail

# ============================================================================
# Help Function
# ============================================================================

show_help() {
    cat << EOF
fe - Fuzzy Edit

DESCRIPTION
    Interactive file finder and editor that combines fd, fzf, and bat to
    provide a fast, user-friendly way to search and edit files.

USAGE
    fe [OPTIONS] [QUERY]

ARGUMENTS
    QUERY               Optional search query to pre-populate fzf's search.
                        If provided, fzf will start with this query already
                        entered. If there's exactly one match, it will be
                        automatically selected. If there are no matches, the
                        script exits without opening an editor.

OPTIONS
    -h, --help          Display this help message and exit

DEPENDENCIES
    This script requires the following tools to be installed:

    - fd                Fast file finder (https://github.com/sharkdp/fd)
    - fzf               Command-line fuzzy finder (https://github.com/junegunn/fzf)
    - bat               Syntax-highlighted cat clone (https://github.com/sharkdp/bat)
    - nvim              Neovim text editor (default, can be overridden)

ENVIRONMENT VARIABLES
    EDITOR              Text editor to use. Defaults to 'nvim' if not set.
                        Examples: vim, emacs, nano, code

EXAMPLES
    # Open fe with no initial query
    fe

    # Pre-populate search with "config"
    fe config

    # Search for files containing "test"
    fe test

    # Use a different editor for this session
    EDITOR=vim fe

    # Search for README files
    fe README

FEATURES
    - Recursively searches files in the current directory
    - Follows symbolic links
    - Excludes .git directories
    - Shows file previews with syntax highlighting (first 500 lines)
    - Auto-selects if only one match found
    - Exits gracefully if no matches found
    - Supports cancellation with ESC or Ctrl-C

KEY BINDINGS (in fzf)
    Ctrl-K/Up           Move selection up
    Ctrl-J/Down         Move selection down
    Enter               Open selected file in editor
    ESC / Ctrl-C        Cancel and exit
    Ctrl-/              Toggle preview window

EXIT CODES
    0                   Success (file selected and opened, or no match with query)
    1                   Error occurred
    130                 User cancelled (ESC or Ctrl-C)

EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Get the optional query argument
QUERY="${1:-}"

# ============================================================================
# Main Execution
# ============================================================================

# Run fd piped to fzf with the query
# --select-1: Auto-select if only one match
# --exit-0: Exit with 0 if no match (prevents fzf from starting)
SELECTED=$(fd --type f --hidden --follow --exclude .git . | fzf \
    --height "80%" \
    --layout "reverse" \
    --info "inline" \
    --border "rounded" \
    --preview 'bat --style=numbers --color=always --line-range :500 {}' \
    --query="${QUERY}" \
    --select-1 \
    --exit-0 \
    --no-multi) || true

# Open the file in the editor if one was selected
# The || true prevents the script from exiting on cancel (exit code 130)
if [[ -n "${SELECTED}" ]]; then
    "${EDITOR:-nvim}" "${SELECTED}"
fi
```

The above bash scripts `fe` and `fconf` are only some of the bash scripts that I have that must be baked into my custom image. I will add the rest myself

- [ ] The systemd user service `pyprland.service` must be enabled and be available when I first login after a rebase. And the following systemd system services `nvidia-persistenced.service`, `nvidia-powerd.service` must be masked

- [ ] I am not sure if the initramfs module must be used from https://github.com/blue-build/modules since I am using the bazzite image as the base.
