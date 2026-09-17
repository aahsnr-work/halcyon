# halcyon

A lean, Hyprland-first gaming fork of [Bazzite](https://bazzite.gg), built with
[BlueBuild](https://blue-build.org). GNOME is fully removed; the desktop is
**Hyprland (`hyprland-git`) + Noctalia (`noctalia-git`)** with **greetd + tuigreet**
login. NVIDIA open drivers, the Bazzite gaming stack, and a curated dev toolchain
are baked in — rebuilt daily, calm by definition.

> **Image:** `ghcr.io/aahsnr-work/halcyon:latest` (tracks `bazzite-gnome-nvidia-open:latest`; `linux/amd64` only)
> **Recipe:** [`recipes/halcyon.yml`](recipes/halcyon.yml) (multi-file: ordered `from-file:` includes under `recipes/modules/`)

---

## Install / rebase

**Fresh ISO:** run the `build-iso` workflow (Actions → build-iso → Run workflow)
after a green image build, then download the `halcyon-iso` artifact. This is a
**bootable, installable ISO in the same spirit as the Fedora Workstation ISO**:
it boots (BIOS + UEFI) into a graphical **Anaconda** installer
(`bluebuild generate-iso` runs
[JasonN3/build-container-installer](https://github.com/JasonN3/build-container-installer)
under the hood — the workflow uses the BlueBuild CLI, which drives JasonN3's
installer image `v1.4.0`) and installs the exact published
`ghcr.io/aahsnr-work/halcyon` bootc image onto the chosen disk via Anaconda's
`ostreecontainer` path — partitioning, user creation and all. It is an
installer, not a package-based live install, so what lands on disk is
byte-identical to the published image. A `halcyon.iso-CHECKSUM` file is
generated alongside. Caveats: the ISO is large (the compressed base image is
embedded, ~6+ GB) and too big for free GitHub Releases hosting → delivered as
a workflow artifact; the GHCR package must be public (or the runner
authenticated) for the pull to succeed; on Secure Boot systems, enroll the
Universal Blue MOK after first boot for the NVIDIA akmods — see Bazzite's
Secure Boot docs. Locally you can also run:
`sudo bluebuild generate-iso --iso-name halcyon.iso image ghcr.io/aahsnr-work/halcyon`

**Rebase from an existing Atomic desktop (Bazzite/Silverblue/Bluefin/Kinoite):**

```bash
# 1. rebase to the unsigned image first
rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
# 2. after reboot, switch to the signed tag
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
```

**Verify a build:**

```bash
cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon
```

**Secure Boot:** the base's ublue akmods NVIDIA modules require the Universal
Blue MOK key enrolled when Secure Boot is on — see
[Bazzite's Secure Boot documentation](https://secureblue.dev/install-with-secureboot
and the Bazzite docs) for enrollment steps.

---

## What this image is

Boot → greetd/tuigreet → Hyprland → Noctalia first-run wizard. The base image is
`ghcr.io/ublue-os/bazzite-gnome-nvidia-open:latest`, so everything below is
*relative to Bazzite's GNOME NVIDIA-open image*.

### Removed

- **GNOME core & apps** — gnome-shell, mutter, gdm, gnome-session(+wayland), nautilus,
  ptyxis, gnome-control-center, gnome-settings-daemon, gjs, xdg-desktop-portal-gnome,
  firefox RPM (+langpacks), plus the compose-variable GNOME app set
  (evince/loupe/totem/gnome-calculator/… — removed via rpm-filtered script with
  hard verification, not a brittle declarative list).
- **GNOME extensions** — the RPM ones (`gnome-shell-extension-{gsconnect,user-theme}`,
  yafti, rounded-blur, …) via dnf; the 12 directory-installed ones
  (`blur-my-shell`, `burn-my-windows`, `desktop-cube`, `dash-to-dock`-style set,
  `appindicator`, …) via `rm -rf /usr/share/gnome-shell/extensions` + gschema
  recompile. The BlueBuild `gnome-extensions` module is intentionally NOT used
  (it hard-requires `gnome-shell --version` at build time — see NOTES §deviation 1).
- **GNOME config footprint** — dconf `distro.d` bazzite databases, the 5
  silverblue gschema overrides, gnome-background-properties, default wallpaper
  symlinks, dconf-update.service, GNOME mimeapps handlers, Ptyxis skel,
  gnome-ssh-askpass, GNOME motd tip, firefox GNOME config.
- **Display manager** — SDDM config purged (`/etc/sddm.conf.d`), sddm/gdm services
  masked; replaced by greetd + tuigreet (see Added).
- **Handheld / Deck stack** — inputplumber, steamos-manager-powerstation,
  jupiter-fan-control, jupiter-hw-support-btrfs, galileo-mura, steamdeck-dsp,
  powerbuttond, vpower, sdgyrodsu, hid-replay, steamdeck-backgrounds,
  steamdeck-gnome-presets, and their dangling service symlinks.
- **Android** — Waydroid packages + its full file footprint (launchers, polkit
  policy/rules, waydroid ujust recipe).
- **Bling/fastfetch stack** — fastfetch RPM, `/usr/libexec/bazzite-bling-fastfetch`,
  `bazzite-neofetch.sh` profile hook, `bazzite-cli/bling.{sh,fish}`, and the
  `bazzite-cli` ujust recipe (excised from `80-bazzite.just`).
- **Base Flatpak app set** — removed at first boot via `default-flatpaks@v1`
  remove list (firefox, Extension Manager, Protontricks, Warehouse, Mission
  Center, ProtonPlus, the org.gnome.* app set, Refine). **Except** Flatseal and
  DistroShelf, which are kept/re-added (see Flatpak policy).
- **Base font RPMs** — Bazzite's `twitter-twemoji-fonts`,
  `google-noto-sans-cjk-fonts`, `lato-fonts`, `fira-code-fonts`, `nerd-fonts` are
  removed via a reverse-dependency-filtered script. Replaced by the fonts module
  (below). ⚠ **CJK coverage is lost** — re-add `google-noto-sans-cjk-fonts` in
  `removals`-adjacent dnf step if you need CJK glyphs.

### Kept (the Bazzite gaming core)

- **sched_ext / performance:** `scx-scheds`, `scx-tools` (`scx_loader.service`
  stays disabled by default — see sched_ext note). ⚠ **Base variance:** the
  published `bazzite-gnome-nvidia-open:latest` stable image at delivery time
  (2026-09-17) does **not** ship `steamos-manager`/its `-powerstation` subpackage
  contents beyond what main's audit described, `gamemode`, or
  `gamescope-session-ogui-steam` (the stable channel lags bazzite main, which
  does have them). The removal logic treats them as conditional keepers —
  if a future base re-adds them, they are kept (only the `-powerstation`
  subpackage is removed and the stale `desktop = "gnome.desktop"` patched to
  `hyprland.desktop` when present). See NOTES.md §5 for the full variance table;
  use the TODO app list if you want them re-added explicitly.
- **Gaming:** `steam` (bazzite-patched, `/usr/bin/bazzite-steam`), `terra-gamescope`
  (+libs), `terra-mangohud` (x86_64+i686), `umu-launcher`/`umu-wrapper`, `lutris`,
  `bazaar` (RPM), `bazzite-portal`, `bbrew`, `distroshelf-helper` (kept file).
- **Peripherals:** `usbip`, `xwiimote-ng`, `evtest`, `ydotool`, `input-remapper`
  (service disabled in base — unchanged), opt-in `ujust install-openrazer`.
- **Containers:** distrobox + podman (+ user podman socket), `/etc/distrobox`.
- **DistroShelf** — kept as the **system Flatpak** `com.ranfdev.DistroShelf`
  (v4 decision; no stage build), including the base's skel preconfig and
  `/usr/bin/distroshelf-helper`.
- **NVIDIA userland glue:** `ublue-nvidia-flatpak-runtime-sync`/`-verify`,
  `ublue-nvctk-cdi`, akmods COPR repo re-enabled at the end (base behavior).
- **Base repo files** — every repo file Bazzite ships stays, in its final
  enabled/disabled state. halcyon adds and removes its own repos cleanly
  (see the --repoid trap).
- All other stock ujust recipes (`10-update`, `81-fixes`, `82-apps`, `82-beesd`,
  `82-cockpit`, `82-sunshine`, `83-audio`, `84-virt`, `85-image`, `86-windows`,
  `87-framegen`, `88-webapps`, `89-mesa-git`, `90-picker`, `92-verify`,
  `93-update`, `94-protonplus`, `95-bazzite-nvidia`), minus the waydroid/decky/
  deck-session/de ones that reference removed subsystems.

### Added

- **Desktop stack** (from COPR `lionheartp/Hyprland`, install is *unscoped* —
  plain package names with the COPR enabled for the whole transaction, provenance
  verified after, COPR repo file purged):
  `hyprland-git`, `noctalia-git`, `hyprpolkitagent`, `hyprland-qt-support`,
  `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `qt6-qtwayland`.
- **Login:** `greetd` + `tuigreet` (Fedora binary package `tuigreet`; greeter user
  is `greetd`). Config in `/etc/greetd/config.toml`; session list from
  `/usr/share/wayland-sessions`; cache dir `/var/cache/tuigreet` created via
  tmpfiles (tuigreet's hardcoded cache location — it has no `--cache` flag).
- **Browsers/editors (dnf module, repos cleaned up after):** `code` (Microsoft
  repo), `brave-browser` + `brave-origin` (Brave repo), `zen-browser`
  (**COPR `sneexy/zen-browser`, by user directive** — installed in a COPR-only
  transaction so terra, which also packages it, can't win dnf's arbitration),
  `zed` (from the base's pre-existing disabled `terra` repo via
  enable→install→re-disable), `emacs-pgtk` (Fedora).
- **Baked apps (build-time scripts):** Obsidian (AppImage → `/usr/lib/obsidian`),
  Zotero (`/usr/lib/zotero`, auto-update disabled), Pyprland (pip venv →
  `/usr/lib/pyprland`, user service), TeX Live scheme-medium (+latexmk, biber →
  `/usr/lib/texlive`, from a pinned CTAN mirror for reproducible builds). `gcc`,
  `perl`, `jq`, `python3` are deliberately kept (emacs-pgtk native-comp requires
  gcc at runtime; tlmgr/jq/venv runtime needs — see NOTES.md §4 S).
- **First-boot system Flatpaks:** DistroShelf, Flatseal, OnlyOffice DesktopEditors,
  Bitwarden, TickTick.
- **Nix** (pattern from [fu5ha/winter](https://github.com/fu5ha/winter), Apache-2.0):
  `nix` + `nix-daemon` RPMs, `/var/nix` bind-mounted on `/nix` (`var-nix.service`
  + `nix.mount`), tmpfiles for store dirs, profile hook. Home-Manager is NOT
  baked — run `ujust home-manager-setup` after first login.
- **Homebrew:** the base's bare brew payload is untouched; curated formulas
  (`files/brew/Brewfile`: atuin bat btop bun cava chafa direnv dust eza fd
  fzf gnuplot lazygit opencode pandoc pixi ripgrep starship tealdeer uv yazi
  zellij) are baked at build time into `/usr/share/halcyon/brew-bundle.tar.zst`
  and seeded at boot — pre-login and offline — by `halcyon-brew-bundle.service`,
  so they are available immediately after login on fresh installs *and*
  rebases (`/var` is not reseeded on rebase, hence the `/usr` payload). The
  `brew-bundle.service` user unit remains as an online catch-up fallback.
  `ujust bazzite-cli` is gone; these are the CLI tools of the image.
- **Dotfiles:** BlueBuild `chezmoi` module →
  `https://github.com/aahsnr-configs/dots`, `file-conflict-policy: replace`,
  applied at first login for every user (and updated daily).
- **ujust recipes:** `ujust doom-setup` (clones your Doom config via SSH and
  installs Doom Emacs — needs your SSH keys) and `ujust home-manager-setup`
  (bootstraps standalone Home Manager) — shipped via the `justfiles` module,
  surfaced through `/usr/share/ublue-os/just/60-custom.just`.
- **Helpers:** `fconf` and `fe` (fuzzy fd/fzf/bat file finders) in
  `/usr/libexec/halcyon-image/`, on PATH via `/etc/profile.d/image-path.sh`.
- **Fonts:** Nerd Fonts `JetBrainsMono` + `NerdFontsSymbolsOnly`; Google
  `JetBrains Mono`, `Noto Emoji`, `Noto Color Emoji`.

---

## Flatpak policy

`default-flatpaks@v1` (v2 has no `remove:` support). Install/remove lists apply
**at first boot, idempotently** (flatpak state lives in `/var`, outside OSTree
commits — a build-time flatpak module does not exist). `bazzite-flatpak-manager`
stays enabled; it installs nothing, it only enforces remotes/blocklist/EOL
cleanup. The `fedora`/`fedora-testing` flatpak remotes exist-but-disabled — that
is the base's deliberate design (unit `flatpak-add-fedora-repos.service` adds
flathub + the fedora remotes disabled); they are left as-is.

## sched_ext status

`sched_ext` is in the base kernel with `scx-scheds`/`scx_tools` kept and
`scx_loader.service` disabled by default (as shipped). Use `scxctl` or enable
`scx_loader.service` to try schedulers. ⚠ `BORE` is a CachyOS kernel patch and is
NOT on Fedora kernels — the nearest sched_ext equivalent is `scx_bpfland`.

## Known caveats

- **XDG autostart:** Hyprland does not run `/etc/xdg/autostart` natively. Let
  Noctalia handle XDG autostart or add `exec-once` lines in your Hyprland config.
  (The base's `/etc/xdg/autostart/steam.desktop` autostart entry is absent in
  the current stable base — launch Steam from Noctalia/your own autostart.)
- **Base-channel variance:** the published stable base lags bazzite main — it
  currently ships no `gamemode`, no `gamescope-session-plus` sessions, and no
  `steamos-manager`. The recipes keep them if a future base re-adds them
  (removal logic is conditional); see NOTES.md §5 for the full variance table
  and how to re-add them explicitly via the TODO app list if you want them now.
- **No terminal is baked** — GNOME Terminal/Console/Ptyxis are gone by design and
  none is invented for you. Your chezmoi dots + Brewfile own this; add one via
  the TODO extension point in `apps.yml` if you want a GUI terminal in the image.
- **Obsidian version:** Obsidian's GitHub `releases/latest` is periodically
  mobile-only (no AppImage). `install-obsidian.sh` handles this by falling back
  to a known-good pinned release (v1.8.7). Update the fallback URL when you
  refresh the image, or edit the script to query the desktop release channel.
- **TODO(user) extension points:** personal shell setup (chezmoi repo), branding
  assets (`files/system/usr/share/plymouth/themes/halcyon/`,
  `files/system/usr/share/backgrounds/halcyon/`, motd), extra apps
  (`recipes/modules/apps.yml` bottom section), optional Hyprland companion apps
  (`recipes/modules/desktop.yml` comment).

## The `--repoid` trap — read before editing

BlueBuild's `dnf` module executes every `repo:`-scoped install entry as
`dnf5 --repoid <repo> install <pkg>` — and dnf5's `--repoid` confines the
**entire transaction, dependency resolution included**, to that single
repository. Fedora/updates become invisible to the solver and installs fail with
broken i686 multilib candidates. **Never use `repo:`-scoped entries in this
repo.** Install plain package names with the needed repos enabled for the whole
transaction (unique names make provenance unambiguous), then verify provenance
with `rpm -q --qf '%{name} (vendor: %{VENDOR})' <pkgs>` — COPR builds stamp
`Fedora Copr - user <name>` as their vendor (dnf5's from-repo history is
unavailable on rpm-ostree-based images). The recipes
enforce `install-weak-deps: false` everywhere and post-install provenance guards.

## Build & CI

- `build.yml` (daily cron 08:00 UTC, push, PR) → `blue-build/github-action@v1.12`
  → signs with cosign (`SIGNING_SECRET`) and publishes to GHCR.
- `build-iso.yml` (manual) → ISO artifact from the published image.
- dependabot keeps the actions current (daily).
- Local test build: `bluebuild build recipes/halcyon.yml` (podman).

## Repo tooling

- `files/dump-to-markdown/` — a packaged, stdlib-only CLI that dumps a whole
  project tree into one Markdown document (heading + language-tagged fenced
  code block per file). It is baked into the image as `/usr/bin/dump-to-markdown`
  (staged via `build-scripts.yml` → installed by `install-dump-to-markdown.sh`
  into a venv at `/usr/lib/dump-to-markdown`) and verified by
  `build-scripts-verify.sh`. For dev use: `uv tool install ./files/dump-to-markdown`.

## Credits & licenses

- [Universal Blue](https://universal-blue.org) & [Bazzite](https://bazzite.gg)
  (Apache-2.0) — base image and the gaming stack.
- [BlueBuild](https://blue-build.org) — build system, modules, CI action.
- [fu5ha/winter](https://github.com/fu5ha/winter) (Apache-2.0) — the nix
  bind-mount pattern (`var-nix.service`, `nix.mount`, tmpfiles, profile hook).
- [lionheartp/Hyprland COPR](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
  — `hyprland-git`, `noctalia-git` & friends.
- [noctalia-shell](https://github.com/noctalia-dev/noctalia-shell) — the desktop.
- [DistroShelf](https://github.com/ranfdev/DistroShelf) — Flatpak app.
- [JasonN3/build-container-installer](https://github.com/JasonN3/build-container-installer)
  — underlies `bluebuild generate-iso`.
- [tuigreet](https://github.com/apognu/tuigreet) / [greetd](https://git.sr.ht/~kennylevinsen/greetd).
