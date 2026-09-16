# halcyon

An atomic Linux desktop image booting directly into Hyprland with NVIDIA open drivers, a gaming kernel, and curated developer tooling. Rebuilt daily — calm, by definition.

Published to: `ghcr.io/aahsnr-work/halcyon:latest`

---

## 1. Overview & Identity

**halcyon** is a lean, custom fork of `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:latest`. It preserves Bazzite's gaming stack, kernel optimizations, and NVIDIA driver layers, while removing GNOME entirely in favor of a pure **Hyprland** (`hyprland-git`) + **Noctalia** (`noctalia-git`) environment managed by **greetd** and **tuigreet**.

### Base & Tag Policy
- **Upstream Base**: `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:latest` (Fedora Silverblue/Atomic base with akmods NVIDIA open drivers)
- **Image Version**: `latest`
- **Architectures**: `linux/amd64`

---

## 2. Component Auditing: Removed vs. Kept vs. Added

### Removed Components
halcyon aggressively strips desktop bloat, handheld/Deck daemons, and redundant runtimes:
- **GNOME Core & Desktop Apps**: `gnome-shell`, `mutter`, `gdm`, `gnome-session`, `gnome-session-wayland-session`, `nautilus`, `ptyxis`, `gnome-control-center`, `gnome-settings-daemon`, `gjs`, `xdg-desktop-portal-gnome`, and all desktop utilities (`gnome-terminal`, `gnome-calculator`, `gnome-calendar`, `evince`, `loupe`, `totem`, `snapshot`, etc.).
- **GNOME Extensions**: Both RPM packages (`gnome-shell-extension-user-theme`, `gnome-shell-extension-gsconnect`, `nautilus-gsconnect`, `gnome-search-yafti`, `gnome-rounded-blur`) and the 12 directory-installed extensions under `/usr/share/gnome-shell/extensions` (`logomenu`, `compiz-*`, `hotedge`, `blur-my-shell`, `burn-my-windows`, etc.).
- **Display Manager**: `sddm` (masked or removed if dependency-free) and `gdm` (masked) replaced by `greetd` + `tuigreet`.
- **Handheld & Steam Deck Stack**: `inputplumber`, `steamos-manager-powerstation`, `jupiter-fan-control`, `jupiter-hw-support-btrfs`, `galileo-mura`, `steamdeck-dsp`, `powerbuttond`, `vpower`, `sdgyrodsu`, `hid-replay`, `steamdeck-backgrounds`, `steamdeck-gnome-presets`, and `bazzite-autologin.service`.
- **Android Integration**: `waydroid` RPM, launcher wrappers, polkit rules, and helper units.
- **Stock Firefox**: `firefox` and `firefox-langpacks` RPMs, plus Flatpak `org.mozilla.firefox`.
- **Bling & Fastfetch Stack**: `fastfetch` RPM, `/usr/libexec/bazzite-bling-fastfetch`, `/etc/profile.d/bazzite-neofetch.sh`, and the `bazzite-cli` recipe inside `80-bazzite.just`.
- **Base Fonts**: Non-essential CJK/lato font RPMs swept via reverse-dependency-filtered script, leaving core fontconfig and DejaVu fallbacks.
- **Base GNOME Flatpaks**: Removed at first boot via `default-flatpaks@v1` (`org.gnome.*`, `ExtensionManager`, `protontricks`, `Warehouse`, `MissionCenter`, `ProtonPlus`, `Refine`).

### Kept Components (Gaming Core & Platform Managers)
halcyon deliberately preserves Bazzite's verified gaming and hardware machinery:
- **Gaming Core**: `steam` (patched, desktop files rewired to `/usr/bin/bazzite-steam`), `umu-launcher`, `umu-wrapper`, `terra-gamescope`, `gamescope-session-ogui-steam`, `gamemode` + `gamemode-news-hook`, `terra-mangohud`, `lutris`, and `bazaar` (RPM).
- **System Managers & sched_ext**: `steamos-manager` (system and user units kept; platform.toml patched to `desktop = "hyprland.desktop"`), `scx-scheds`, `scx-tools`.
- **Peripheral & Hardware Tooling**: `usbip`, `xwiimote-ng`, `evtest`, `ydotool`, `input-remapper`, distrobox, podman, and the `ujust install-openrazer` recipe.
- **NVIDIA Machinery**: `ublue-nvidia-flatpak-runtime-sync`, `ublue-nvidia-flatpak-runtime-verify`, `ublue-nvctk-cdi`, akmods kmods.
- **DistroShelf Support**: Base skel preconfiguration (`/etc/skel/.var/app/com.ranfdev.DistroShelf/`), `distroshelf-helper`, and `mineapps.list` kept to support the system Flatpak.
- **System Repos**: Base repo files (`terra`, `terra-extras`, `che/nerd-fonts`, etc.) are left in their default disabled state.

### Added Components
- **Desktop Environment**:
  - Hyprland (`hyprland-git`) + Noctalia Shell (`noctalia-git`) from COPR `lionheartp/Hyprland`.
  - `greetd` + `greetd-tuigreet` (configured with `user = "greetd"` and cached session persistence).
  - Portals: `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, and `qt6-qtwayland`.
  - `hyprpolkitagent` and `hyprland-qt-support`.
- **Applications (via DNF)**:
  - `code` (Visual Studio Code official Microsoft repository).
  - `brave-browser` and `brave-origin` (Brave official repository).
  - `zen-browser` (COPR `sneexy/zen-browser`).
  - `zed` (installed via temporary enable of base `terra` repository).
  - `emacs-pgtk` (Fedora official, supporting Doom Emacs).
- **Baked Tooling (Build-time Installers)**:
  - `Obsidian`: Extracted AppImage baked to `/usr/lib/obsidian` with system desktop integration.
  - `Zotero`: Official tarball installed to `/usr/lib/zotero` with `DisableAppUpdate` policy.
  - `Pyprland`: Built into dedicated Python virtualenv `/usr/lib/pyprland`, compiled C-client helper, and global user systemd service `pyprland.service`.
  - `TeX Live`: `scheme-medium` installed via `install-tl` into `/usr/lib/texlive` with `latexmk` and `biber` baked in.
- **System Flatpaks (First-Boot `default-flatpaks@v1`)**:
  - `com.ranfdev.DistroShelf`
  - `com.github.tchx84.Flatseal`
  - `org.onlyoffice.desktopeditors`
  - `com.bitwarden.desktop`
  - `com.ticktick.TickTick`
- **Declarative Nix Stack**: fu5ha/winter pattern with multi-user `nix-daemon`, `/var/nix` bind mount to `/nix`, and home-resolution profile scripts.
- **Homebrew Automation**: First-login one-shot user service (`halcyon-brew-bundle.service`) installing 21 formulas from `halcyon.Brewfile`.
- **Dotfiles**: `chezmoi` integrated with `https://github.com/aahsnr-configs/dots` (`file-conflict-policy: replace`).
- **Helpers**: Fuzzy config finder (`fconf`) and fuzzy file editor (`fe`) in `/usr/libexec/halcyon-image` exported to `$PATH`.
- **Custom Just Recipes**: `ujust doom-setup` and `ujust home-manager-setup`.

---

## 3. Critical Architectural Rules & Pitfalls

### The `--repoid` Dependency Confinement Trap (§1.21)
> [!WARNING]
> **Never use `repo:`-scoped package definitions in BlueBuild DNF modules.**
>
> BlueBuild executes `repo:`-scoped entries using `dnf5 -y --setopt=install_weak_deps=False install --repoid <repo> <pkg>`. In DNF5, `--repoid` confines the **entire transaction, including dependency resolution**, strictly to that single repository. Fedora and updates repos become invisible, causing DNF to fail resolving system libraries (SDL2, X11, glib, qt6) and fall back to broken multilib candidates.
>
> **Policy**: halcyon always enables repositories for the whole unscoped transaction using unique package names (`code`, `brave-browser`, `zen-browser`, `zed`, `hyprland-git`), cleans up repo files immediately afterwards, and enforces provenance post-install via `dnf -q repoquery --installed --qf '%{name} from %{reponame}'`.

### Flatpak Policy & Fedora Remotes
- Flatpaks live in `/var/lib/flatpak`, outside OSTree commits. They cannot be pruned at container build time.
- Removals and additions are handled idempotently at first boot via `default-flatpaks@v1`.
- Bazzite includes disabled Fedora Flatpak remotes by default (`flatpak-add-fedora-repos.service`). halcyon retains this base design. For users desiring total elimination of Fedora Flatpak remote definitions, an optional systemd drop-in is provided in `files/systemd/system/flatpak-add-fedora-repos.service.d/10-halcyon.conf` (see §7.6 of `prompt.md`).

### Sched_ext & BORE Kernel Caveat
- `scx-scheds` and `scx-tools` are kept from the base image. `scx_loader.service` is disabled by default.
- Users can inspect and toggle schedulers via `scxctl`.
- **BORE** (Burst-Oriented Response Enhancer) is a CachyOS custom kernel patch and is **not** present in Fedora/Bazzite kernels. Users desiring equivalent responsiveness should explore sched_ext schedulers such as `scx_bppland` or `scx_lavd`.

### XDG Autostart under Hyprland
- Hyprland does not natively parse or execute `/etc/xdg/autostart/*.desktop` files.
- While Steam's autostart desktop file is preserved at `/etc/xdg/autostart/steam.desktop`, users should configure autostart in their Hyprland configuration (e.g. `exec-once = bazzite-steam -silent %U`) or rely on Noctalia's session startup.

### Terminal Notice
- With the removal of `ptyxis` and `gnome-terminal`, no terminal emulator is baked into the base image by default.
- Users should ensure their chezmoi dotfiles, Home-Manager configuration, or additional DNF packages install their preferred terminal (e.g. `kitty`, `foot`, `alacritty`, or `wezterm`).

---

## 4. Mandatory Documented Deviations (§11)

1. **`gnome-extensions` Module Avoided**: The BlueBuild `gnome-extensions` module unconditionally executes `gnome-shell --version` during build, causing immediate failure once GNOME is removed. Extensions are cleanly removed via DNF and directory purging.
2. **Terra Repository Handling**: The `terra` repository already exists (disabled) in the base image. halcyon does not add or delete terra repo files; instead, it uses an enable → install (`zed`) → disable sandwich.
3. **Flatpak Removal Timing**: Flatpak states reside in `/var` and cannot be modified inside immutable image layers. `default-flatpaks@v1` handles removals at first boot.
4. **Weak Dependencies in Nix**: Added `install-weak-deps: false` to the fu5ha/winter Nix DNF module to adhere to halcyon's strict lean packaging rules.
5. **Fedora Flatpak Remotes**: Left in place (disabled) per upstream Bazzite design; optional hardening unit available.
6. **`default-flatpaks@v1` Pinned**: BlueBuild `default-flatpaks@v2` lacks `remove:` support. Version 1 is used to provide both system installs and base GNOME Flatpak removals.
7. **Removals Split into DNF vs Guarded Scripts**: BlueBuild's DNF module hard-fails on missing packages. Confirmed packages are removed declaratively; compose-variable candidates are handled via `rpm -q`-guarded scripts with hard assertion testing.
8. **`steamos-manager` Retained**: Kept because it manages TDP and `scx` schedulers; its desktop configuration is patched from `gnome.desktop` to `hyprland.desktop`.
9. **`type: script@v1` Pinned**: Plain `type: script` resolves to v2 which runs under `/bin/sh`. All halcyon snippets require bash and pin `script@v1`.
10. **Greetd User Set to `greetd`**: Fedora's greetd package modifies upstream's `greeter` user to `greetd`. Configuring `greeter` would fail authentication.
11. **Banning of `repo:`-Scoped Installs**: Due to the DNF5 `--repoid` dependency resolution trap (§1.21), all packages are installed with whole-transaction visibility.
12. **DistroShelf as System Flatpak**: Delivered as `com.ranfdev.DistroShelf` from Flathub via `default-flatpaks@v1`, avoiding fragile custom RPM packaging while keeping base helper integrations.

---

## 5. Deployment, Verification & Rebase Flow

### Rebase to halcyon
To switch an existing Fedora Silverblue or Bazzite installation to halcyon:

1. **Unverified Rebase** (first boot to pull public key and container policies):
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
   systemctl reboot
   ```

2. **Signed Verification Rebase** (enforcing cosign signature verification):
   ```bash
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
   systemctl reboot
   ```

### Verifying Image Signatures Locally
```bash
cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon:latest
```

### Secure Boot Enrollment
halcyon inherits NVIDIA kernel modules signed by Universal Blue's akmods keys. If Secure Boot is enabled on your machine:
1. Ensure the Universal Blue MOK key is enrolled in your UEFI firmware (`/etc/pki/akmods/certs/akmods-ublue.der`).
2. Follow Bazzite's official [Secure Boot Guide](https://docs.bazzite.gg/Installing_and_Managing_Software/Secure_Boot/) to enroll the key via `mokutil`.

### ISO Generation
To create a bootable standalone ISO from the published container image:
- Trigger the `.github/workflows/build-iso.yml` workflow manually in GitHub Actions, or
- Run locally with rootful Podman:
  ```bash
  sudo bluebuild generate-iso --iso-name halcyon.iso image ghcr.io/aahsnr-work/halcyon
  ```

---

## 6. User Setup & Extension Points (`TODO(user)`)

- **Custom Application RPMs**: Add additional packages directly to the designated `TODO(user)` block in [`recipes/modules/apps.yml`](recipes/modules/apps.yml) (plain names only).
- **Dotfiles**: Managed automatically via [aahsnr-configs/dots](https://github.com/aahsnr-configs/dots) using chezmoi.
- **Doom Emacs**: After first login, run:
  ```bash
  ujust doom-setup
  ```
  *(Requires user SSH keys configured for GitHub).*
- **Nix Home Manager**: After first login, bootstrap Home Manager via:
  ```bash
  ujust home-manager-setup
  ```
- **Branding Assets**:
  - Replace Plymouth theme graphics in [`files/system/usr/share/plymouth/themes/halcyon/`](files/system/usr/share/plymouth/themes/halcyon/).
  - Customize MOTD text in [`files/system/etc/motd.d/halcyon-motd.txt`](files/system/etc/motd.d/halcyon-motd.txt).
  - Add wallpaper images to [`files/system/usr/share/backgrounds/halcyon/`](files/system/usr/share/backgrounds/halcyon/).

---

## 7. Credits & Upstream Attribution

- **Universal Blue & Bazzite**: [bazzite.gg](https://bazzite.gg) / [ublue-os/bazzite](https://github.com/ublue-os/bazzite) (Apache-2.0).
- **BlueBuild**: [blue-build.org](https://blue-build.org) (Apache-2.0).
- **fu5ha/winter**: Declarative Nix on OSTree integration patterns (Apache-2.0).
- **lionheartp/Hyprland COPR**: Upstream Hyprland and Noctalia packaging for Fedora.
- **sneexy/zen-browser COPR**: Zen Browser RPM packaging.
- **DistroShelf**: [ranfdev/DistroShelf](https://github.com/ranfdev/DistroShelf) (GPL-3.0).
- **JasonN3/build-container-installer**: Underlying engine for BlueBuild ISO generation.
