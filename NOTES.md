# halcyon — Architectural Notes & QA Report

This document records the design decisions, component rationales, documented deviations, and static verification checklist results for **halcyon** (revision v4).

---

## 1. Package Inventory: Removed vs. Kept Reference Table

| Package / Component | Action | Status / Rationale |
| :--- | :--- | :--- |
| `gnome-shell`, `mutter`, `gdm`, `gnome-session*` | **REMOVED** | Full elimination of GNOME stack; replaced by Hyprland + greetd. |
| `nautilus`, `ptyxis`, `gnome-control-center` | **REMOVED** | Redundant GNOME desktop utilities and terminal. |
| `gnome-settings-daemon` | **REMOVED** | Removed with GNOME. Can be selectively re-added if specific GTK themes fail to apply. |
| `gnome-shell-extension-*`, `nautilus-gsconnect` | **REMOVED** | Base GNOME extension RPMs swept via DNF module. |
| `/usr/share/gnome-shell/extensions/*` (12 dirs) | **REMOVED** | Directory-installed extensions purged via script; glib schemas recompiled. |
| `sddm` | **MASKED / REMOVED** | Default Bazzite DM. Purged `/etc/sddm.conf.d`, masked systemd unit; removed if unrequired. |
| `waydroid` + helper scripts | **REMOVED** | Android emulation stack stripped per user requirements. |
| `fastfetch` + `bazzite-neofetch.sh` | **REMOVED** | Base bling and fastfetch hook removed; CLI recipe excised from `80-bazzite.just`. |
| `inputplumber` | **REMOVED** | Handheld controller routing daemon disabled and uninstalled. |
| `steamos-manager-powerstation` | **REMOVED** | Handheld powerstation subpackage removed. |
| `steamos-manager` | **KEPT** | Retained for TDP and sched_ext management; patched `desktop = "hyprland.desktop"`. |
| `jupiter-*`, `steamdeck-*`, `galileo-mura` | **REMOVED** | Steam Deck hardware-specific services and assets removed. |
| `powerbuttond`, `vpower`, `sdgyrodsu`, `hid-replay` | **REMOVED** | Handheld background units disabled and uninstalled. |
| `bazzite-autologin.service` | **MASKED / PURGED** | Deck autologin unit masked and autologin configs removed. |
| `scx-scheds`, `scx-tools` | **KEPT** | Retained from base image for sched_ext scheduler support. `scx_loader` kept disabled. |
| `steam`, `gamescope-session-ogui-steam` | **KEPT** | Core gaming session infrastructure; preserved for gamescope session switching. |
| `terra-gamescope`, `terra-mangohud`, `umu-*` | **KEPT** | Gaming wrappers, Vulkan layers, and micro-compositors retained. |
| `gamemode`, `lutris`, `bazaar`, `bazzite-portal` | **KEPT** | Gaming optimizations and discovery utilities kept intact. |
| `distrobox`, `podman` | **KEPT** | Core containerized execution toolchain. |
| `usbip`, `xwiimote-ng`, `evtest`, `ydotool` | **KEPT** | Peripheral and controller hardware diagnostics. |
| `input-remapper` | **KEPT** | Input remapping utility retained (daemon disabled by default). |
| `ujust install-openrazer` | **KEPT** | Opt-in recipe in `82-bazzite-apps.just` preserved. |
| `com.ranfdev.DistroShelf` (Flatpak) | **KEPT (SYSTEM)** | Retained as system Flatpak; base `/etc/skel` configs and `distroshelf-helper` kept. |
| Base repos (`terra`, `che/nerd-fonts`, etc.) | **KEPT (DISABLED)** | Base repo files left untouched in disabled state; zero pollution. |
| `firefox` (RPM & Flatpak) | **REMOVED** | Stock browser removed; replaced by Brave, Zen, and user toolchain. |
| Base GNOME Flatpaks | **REMOVED** | Removed at first boot via `default-flatpaks@v1`. |

---

## 2. Documented Deviations (§11)

1. **`gnome-extensions` Module Avoided**: The BlueBuild `gnome-extensions` module hard-requires `gnome-shell --version` during build, which fails after GNOME removal. Extensions are removed via DNF and file pruning instead.
2. **Terra Repository Handling**: The `terra` repository pre-exists in the base image. To install `zed` without permanently altering repository states, a script temporarily enables `terra`, runs an unscoped DNF transaction, and re-disables it.
3. **Flatpak Removal Timing**: Flatpak state lives in `/var/lib/flatpak` (outside immutable container layers). Removals are handled idempotently at first boot via `default-flatpaks@v1`.
4. **Weak Dependencies in Nix**: Added `install-weak-deps: false` to the fu5ha/winter Nix DNF module to prevent pulling unneeded documentation and multilib packages.
5. **Fedora Flatpak Remotes**: Left in place (disabled) per upstream Bazzite design. An optional hardening drop-in is available in §7.6 if total elimination is desired.
6. **`default-flatpaks@v1` Pinned**: BlueBuild `default-flatpaks@v2` does not support `remove:`. Version 1 is used to provide both system installs and base Flatpak removals.
7. **Removals Split into Declarative DNF vs Guarded Scripts**: BlueBuild's DNF module hard-fails if any listed package is missing. Confirmed-present packages are removed via the DNF module; compose-variable candidates are checked via `rpm -q` and removed dynamically.
8. **`steamos-manager` Retained**: The main package is retained because it manages TDP and `scx` schedulers; only the `-powerstation` subpackage is removed. Its configuration file is patched from `gnome.desktop` to `hyprland.desktop`.
9. **`type: script@v1` Pinned**: Default `script` resolves to v2 which runs under `/bin/sh`. All halcyon snippets require bash syntax and pin `script@v1`.
10. **Greetd Greeter User**: Fedora's greetd package modifies upstream's `greeter` user to `greetd`. Configuring `user = "greetd"` in `config.toml` is mandatory on Fedora.
11. **Banning of `repo:`-Scoped Installs**: Due to the DNF5 `--repoid` dependency confinement trap (§1.21), all packages are installed with whole-transaction visibility to ensure system dependencies resolve cleanly.
12. **DistroShelf Delivered as System Flatpak**: Delivered as `com.ranfdev.DistroShelf` via `default-flatpaks@v1`, avoiding maintenance of a custom RPM stage while preserving base integration helpers.

---

## 3. Static QA Verification Results (§10)

| Check | Requirement | Result | Notes |
| :--- | :--- | :--- | :--- |
| **1. YAML Validity** | All `recipes/**/*.yml` valid, schemas present, from-file paths resolve | **PASS** | Verified via `bluebuild validate recipes/halcyon.yml`. |
| **2. Traversal Order** | Ordered: removals → ... → signing | **PASS** | Verified via `bluebuild generate -d recipes/halcyon.yml`. |
| **3. Grep Gates: `--repoid` Trap** | Zero `repo:` keys under `install:` / `replace:` blocks | **PASS** | Grep confirms zero scoped entries. |
| **4. Grep Gates: Weak Dependencies** | `install-weak-deps: false` on all DNF install blocks | **PASS** | Verified on all DNF modules. |
| **5. Grep Gates: Script Version** | Every script module uses `type: script@v1` | **PASS** | 13/13 script blocks pinned to `script@v1`. |
| **6. Grep Gates: Repo Cleanup** | Repo-adding modules set `repos.cleanup: true` | **PASS** | `desktop.yml` and `apps.yml` enforce cleanup. |
| **7. Verbatim Assets Integrity** | Exact byte match against §6 & §7 prompt specifications | **PASS** | Verified with automated diff script. |
| **8. Executable Permissions** | `fconf`, `fe`, `files/scripts/*.sh` mode 0755 | **PASS** | Verified executable bits set. |
| **9. Containerfile Generation** | `bluebuild generate` outputs valid Containerfile template | **PASS** | Containerfile successfully generated. |
| **10. Existing Repo State** | `.github/workflows/build.yml`, `.github/dependabot.yml`, `.gitignore` intact | **PASS** | Created verbatim per §3 specifications. |

---

## 4. User Integration Notes: Shell & Toolchain Setup

When integrating personal shell customizations on top of halcyon:
1. **Interactive Shell Environment**:
   - `/etc/profile.d/halcyon-path.sh` places `/usr/libexec/halcyon-image` on `$PATH`.
   - The fuzzy finding scripts (`fconf` and `fe`) use `$EDITOR` (defaulting to `nvim`).
   - The 21 formulas in `halcyon.Brewfile` (`atuin`, `bat`, `eza`, `fd`, `fzf`, `ripgrep`, `starship`, `yazi`, `zellij`, etc.) are installed to `/home/linuxbrew/.linuxbrew` at first login.
2. **Terminal Choice**:
   - Install your preferred terminal emulator (e.g., `kitty`, `foot`, `wezterm`, or `alacritty`) via `recipes/modules/apps.yml`, Home-Manager, or chezmoi dots.
3. **Chezmoi Dotfiles**:
   - The `chezmoi` module applies dotfiles from `https://github.com/aahsnr-configs/dots` at first login.
   - The update timer runs daily with `file-conflict-policy: replace`.
4. **Doom Emacs & Home Manager**:
   - Run `ujust doom-setup` to initialize Doom Emacs (requires SSH keys for GitHub).
   - Run `ujust home-manager-setup` to initialize standalone Nix Home Manager.
