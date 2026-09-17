# PROMPT v4 — Build "halcyon": A Custom Bazzite Fork Using the BlueBuild Template

> **Audience:** an AI coding agent (or engineer) with shell + internet access, working on the **already-created** GitHub repo **`aahsnr-work/halcyon`**.
> **Generated:** 2026-09-16, revision v4. Every schema, package name, path, service, repo ID and behavior below was verified the same day directly against primary sources: `blue-build/modules` (module.yml + TypeSpec + module source: dnf.nu, dnf_interface.nu, script, files, systemd, chezmoi, justfiles, default-flatpaks v1/v2, signing.sh, os-release.nu, gnome-extensions.sh, fonts sources), `blue-build/template` (tree, recipe.yml, build.yml), `blue-build/cli` releases, `ublue-os/bazzite` (full `Containerfile` line-audit, `system_files/**` tree, `build_files/*`, `installer/*`, justfiles), `ublue-os/brew` (Containerfile + units + profile scripts), `fu5ha/winter`, Fedora `greetd.spec` (rawhide), GHCR tag API, COPR APIs, brave/terra **repodata**, GitHub releases APIs, blue-build.org docs. Items marked ⚠VERIFY could not be confirmed from the research sandbox and carry explicit build-time gates.
> **Changes in v4 (user directives):** repo already exists — NO bootstrap from template; **deliver files only — never `git push`, never open PRs**; user-supplied `.github/workflows/build.yml`, `.github/dependabot.yml`, `.gitignore` are FINAL (embedded verbatim in §3 — do not modify); cosign.pub + `SIGNING_SECRET` already configured; **`repo:`-scoped dnf installs are BANNED** (the `--repoid` dependency-confinement trap, §1.21); module files renamed without the `halcyon-` prefix; **DistroShelf switches from stage-built RPM to the system Flatpak** (stage + spec removed entirely).
> **Self-contained:** every user-supplied script/justfile/config is embedded verbatim in §6.

---

## 0. Mission & delivery mode

The repo `aahsnr-work/halcyon` exists and already contains: `.github/workflows/build.yml` (§3.1), `.github/dependabot.yml` (§3.2), `.gitignore` (§3.3), `cosign.pub` (pushed), and the `SIGNING_SECRET` Actions secret (set from `cosign.key`).

Produce the **complete remaining file tree** (§3.4) implementing **halcyon**: a lean Hyprland gaming fork of `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:latest` — GNOME fully removed; Hyprland (`hyprland-git`) + Noctalia (`noctalia-git`) from COPR `lionheartp/Hyprland`; greetd+tuigreet login; handheld/Deck/Android bloat stripped; user toolchain layered in (Nix à la fu5ha/winter, 21 Homebrew formulas at first login, chezmoi dotfiles, custom ujust recipes, baked apps: VSCode, Brave ± Origin, Zen, Zed, emacs-pgtk, Obsidian, Zotero, Pyprland, TeX Live; DistroShelf + 3 other apps as system Flatpaks); cosign-signed via the stock template CI; single-image ISO workflow.

**Delivery: create/present files only.** No `git add/commit/push`, no PRs, no GHCR interactions. The user reviews and publishes themselves. Local validation via `bluebuild build recipes/halcyon.yml` (podman) is encouraged if the environment allows; otherwise deliver static verification per §10.

---

## 1. Verified ground truth (primary sources, 2026-09-16)

### Base image (ublue-os/bazzite `Containerfile` + `system_files/`, audited line-by-line)

1. **Display manager = SDDM** (installed + `systemctl enable sddm.service`; `gdm.service` explicitly disabled; gdm RPM still present from the silverblue compose). halcyon replaces it with **greetd + tuigreet** and masks sddm/gdm.
2. **Handheld/Deck stack is baked into ALL images** (post Oct-2025 flavor merge), confirmed installs: `inputplumber` (+ `inputplumber.service` **enabled**, LOG_LEVEL debug-patched), `steamos-manager-powerstation` (`powerstation.service` installed disabled), `jupiter-fan-control` (svc disabled), `jupiter-hw-support-btrfs`, `galileo-mura`, `steamdeck-dsp`, `powerbuttond`, `vpower` (svc disabled), `sdgyrodsu` (user svc `--global` disabled), `hid-replay`, `steamdeck-backgrounds`, `steamdeck-gnome-presets` (GNOME variant), `/usr/libexec/jupiter-dock-updater`, Steam-Deck-patched `upower` (COPR swap + versionlock), `gamescope-session-plus` + `bootstrap_steam.tar.gz`, `qt6-qtvirtualkeyboard`, `xorg-x11-server-Xvfb`, `python-vdf`, `python-crcmod`, `newt`. `jupiter-sd-mounting-btrfs` + `ds-inhibit` are installed then **removed again by Bazzite itself** (absent from final image). **Decky = ujust recipe only** (`91-bazzite-decky.just`); **HHD/BlueBubbles absent**; `bazzite-autologin.service` is **deck-images only** (writes SDDM autologin confs → purge `/etc/sddm.conf.d` + mask the unit anyway).
3. **KEEP — `steamos-manager`** (system + 3 user units enabled `--global`): it is the scx/TDP manager — `/usr/share/steamos-manager/platform.toml` carries `[scx] scx_service = "scx_loader.service"` and (GNOME variant) a stale `desktop = "gnome.desktop"` line → sed to `hyprland.desktop`. Remove only the `-powerstation` subpackage. Delete the Containerfile-created wants symlink `/usr/lib/systemd/user/gamescope-session-plus@ogui-steam.service.wants/steamos-powerbuttond.service` together with `powerbuttond`.
4. **sched_ext IS in the base:** `scx-scheds` + `scx-tools` (from COPR `bieszczaders/kernel-cachyos-addons`, disabled post-build); `scx_loader.service` **disabled** by default; loader config ships deck-only. → Keep packages + manager, keep loader disabled, document `scxctl`. **BORE** = CachyOS kernel patch, NOT on Fedora kernels; nearest = `scx_bppland` (README note).
5. **Brew:** `FROM ghcr.io/ublue-os/brew` → `/usr/share/homebrew.tar.zst` = **bare brew** (wolfi builder, tarred from `/home/linuxbrew/.linuxbrew`); `brew-setup.service` (enabled) extracts to `/home/linuxbrew` on first boot (marker `/etc/.linuxbrew`, chown 1000:1000); `brew-update`/`brew-upgrade` timers maintain it; `/etc/profile.d/brew.sh` **appends** brew to PATH in interactive shells only (system binaries always win — no conflict with `/usr/bin/chezmoi`). Bazzite formulas install ONLY via opt-in `ujust bazzite-cli` → `brew bundle --file /usr/share/ublue-os/homebrew/bazzite-cli.Brewfile` (verified contents: atuin, bat, bash-preexec, bbrew, chezmoi, direnv, dysk, eza, fd, gh, glab, rg, starship, shellcheck, stress-ng, tealdeer, trash-cli, television, ugrep, yq, zoxide) + "bling" hooks (`/usr/share/bazzite-cli/bling.{sh,fish}` → starship/fastfetch). **halcyon mechanism: ship `halcyon.Brewfile` (21 formulas) + first-login user service — NO `brew` module, NO tarball surgery.**
6. **"zsh+fastfetch/starship setup" concretely =** `fastfetch` RPM, `/usr/libexec/bazzite-bling-fastfetch`, `/usr/share/ublue-os/bazzite/fastfetch.jsonc`, `/usr/share/bazzite-cli/bling.{sh,fish}`, the **auto-hook `/etc/profile.d/bazzite-neofetch.sh`**, and the `bazzite-cli` recipe inside `80-bazzite.just` (only bling-bearing recipe; `81/85/90-picker/92/93/82-apps` scans came back clean). NO zsh/starship RPMs in the base.
7. **Flatpaks are runtime-only** (state in `/var`, never in OSTree commits): the GNOME set (`installer/gnome_flatpaks/flatpaks`) is baked into Bazzite's **ISO environment** and rsynced to `/var/lib/flatpak` by anaconda post-script `install-flatpaks.ks` — never in the OCI image (halcyon's own ISO won't preinstall them; the remove list matters for **rebases from Bazzite**). `bazzite-flatpak-manager.service` (enabled; KEEP) **installs nothing** — verified: ensures flathub, disables `fedora`/`fedora-testing` remotes, applies `/usr/share/ublue-os/flatpak-blocklist`, unpins EOL (`bazzite-flatpak-eol`), uninstalls yafti leftovers + `--unused` runtimes, sets overrides (incl. NVIDIA VA-API env). Base override unit `flatpak-add-fedora-repos.service` adds flathub + adds `fedora`/`fedora-testing` **disabled** → **T7 answered: fedora remotes exist-but-disabled by design; keep as-is** (optional hardening drop-in §7.6).
8. **Base GNOME flatpak list** (`installer/gnome_flatpaks/flatpaks`): apps `org.mozilla.firefox`, `com.mattjakeman.ExtensionManager`, `com.github.Matoking.protontricks`, `com.ranfdev.DistroShelf`, `com.github.tchx84.Flatseal`, `io.github.flattool.Warehouse`, `io.missioncenter.MissionCenter`, `com.vysp3r.ProtonPlus`, `org.gnome.{Calculator,Calendar,Characters,Contacts,Papers,Logs,Loupe,NautilusPreviewer,TextEditor,Weather,baobab,clocks,font-viewer,Showtime,Firmware}`, `page.tesk.Refine` + Vulkan-layer runtimes (MangoHud, vkBasalt, OBSVkCapture — modules don't manage runtimes; leave).
9. **GNOME extensions in base:** (a) RPMs — `gnome-shell-extension-user-theme`, `gnome-shell-extension-gsconnect`, `nautilus-gsconnect`, `gnome-search-yafti`, `gnome-rounded-blur` (Bazzite pre-removes gnome-software, gnome-classic-session, gnome-tour, gnome-extensions-app, gnome-system-monitor, gnome-initial-setup, 5 stock extensions, malcontent-control); (b) **directory-installed** by `build_files/build-gnome-extensions` (verified): `logomenu@aryan_k`, `compiz-windows-effect@hermes83.github.com`, `compiz-alike-magic-lamp-effect@hermes83.github.com`, `hotedge@jonathan.jdoda.ca`, `restartto@tiagoporsch.github.io`, `appindicatorsupport@rgcjonas.gmail.com`, `add-to-steam@pupper.space`, `caffeine@patapon.info`, `burn-my-windows@schneegans.github.com`, `desktop-cube@schneegans.github.com`, `blur-my-shell@aunetx`, `bazaar-integration@kolunmi.github.io`. GNOME-variant config footprint (`system_files/desktop/silverblue/**`, tree-verified): `/etc/dconf/db/distro.d/{00-bazzite-desktop-silverblue-global,01-…-folders,locks/00-…-global-lock}`, 5× `/usr/share/glib-2.0/schemas/zz0-0{0..4}-bazzite-desktop-silverblue-*.gschema.override`, `/usr/share/gnome-background-properties/*.xml` (7), `/usr/share/backgrounds/default{,-dark}.jxl` symlinks, `dconf-update.service` (enabled), skel items (`gnome-initial-setup-done`, `org.gnome.Ptyxis/palettes/*`), `/usr/share/applications/gnome-ssh-askpass.desktop`, `/usr/share/ublue-os/firefox-config/03-bazzite-gnome.js`, `/usr/share/ublue-os/motd/tips/30-gnome.md`, `/etc/xdg/mimeapps.list` (org.gnome.* handlers). **KEEP** (DistroShelf flatpak is retained per v4 directive): `/etc/skel/.var/app/com.ranfdev.DistroShelf/**`, `/usr/bin/distroshelf-helper`, `/etc/xdg/mineapps.list`; also KEEP `gamescope.desktop`, `ntfs-nag.service`, `80-gpu-reset.rules`, steam sound theme, wallpaper image files, `50-efibootmgr.rules`, `flatpak-blocklist`.
10. **Font RPMs added by Bazzite:** `twitter-twemoji-fonts`, `google-noto-sans-cjk-fonts`, `lato-fonts`, `fira-code-fonts`, `nerd-fonts` (COPR `che/nerd-fonts`), over Fedora-compose fonts. (CJK removal tradeoff → README.)
11. **Repos in the FINAL image** (verified: `build_files/cleanup` only clears `/tmp`, `/var/log/dnf5.log`, `/boot`): files persist for terra (`terra`, `terra-mesa`, `terra-extras` — from `dnf5 install --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release…`), `ublue-os/staging`, `ublue-os/bazzite{,-multilib}`, `ublue-os/packages`, `che/nerd-fonts`, `ycollet/audinux`, `negativo17*`, `bieszczaders/…`, `fedora-cisco-openh264`, `tailscale` — but the finalize layers **disable them all** (`sed enabled=1→0`; `dnf5 copr disable`), EXCEPT `_copr_ublue-os-akmods.repo` **re-enabled** at the very end, and `fedora`/`updates`. → halcyon policy: **never touch base repos**; `zed` installs from pre-existing (disabled) `terra` via an enable→install→re-disable sandwich (§5.3); repos halcyon adds are removed via `cleanup: true` + explicit COPR file deletion (§1.19d).
12. **Gaming core to KEEP** (verified names): `steam` (patched; desktop files rewired to `/usr/bin/bazzite-steam`; autostart at **`/etc/xdg/autostart/steam.desktop`** — finalize layer moves it from skel), `umu-launcher` + `umu-wrapper` (terra), `terra-gamescope{,.libs}` (x86_64+i686), `gamescope-session-ogui-steam` (+ gamescope-session-plus machinery), `gamemode` + `gamemode-news-hook` (user unit `--global` enabled), `terra-mangohud` (x86_64+i686), `scx-scheds`/`scx-tools`/`steamos-manager` (items 3-4), `bazaar` (**RPM**), `bazzite-portal` (RPM; skel autostart), `lutris` (RPM; protobuf-python-patched desktop file), `dmemcg-booster` + `uresourced-dmemcg` (terra-extras swap, GNOME variant), distrobox/podman (+ `/etc/distrobox/*.ini`), `bbrew`, peripheral tooling **actually present**: `usbip`, `xwiimote-ng`, `evtest`, `ydotool`, `input-remapper` (unit disabled in finalize — package kept), opt-in `ujust install-openrazer` recipe in `82-bazzite-apps.just` (**NOT** baked: openrazer/oversteer/xpadneo/steam-devices RPMs absent). KEEP ujust: `10-update`, `80-bazzite` (minus bling recipe), `81-fixes`, `82-apps`, `82-beesd`, `82-cockpit`, `82-sunshine`, `83-audio`, `84-virt`, `85-image`, `86-windows`, `87-framegen`, `88-webapps`, `89-mesa-git`, `90-picker`, `92-verify`, `93-update`, `94-protonplus`, `95-bazzite-nvidia`. KEEP services (verified enabled): `brew-setup`, `bazzite-flatpak-manager`, `bazzite-hardware-setup`, `bazzite-iwd-migration`, `incus-workaround`, `greenboot-healthcheck`, `dev-hugepages1G.mount`, `wireplumber-workaround/-sysconf`, `pipewire-workaround/-sysconf`, `bazzite-user-setup` (user `--global`), `podman.socket` (user), `systemd-tmpfiles-setup` (user), `ublue-nvidia-flatpak-runtime-sync/-verify`, `ublue-nvctk-cdi` (per user rule, CUDA-ish bits already in base stay as-is); tuned/ppd remapping (`balanced-bazzite` etc.), `pulseaudio→/usr/bin/true` shim, `/etc/dnf/dnf.conf`, zram-generator, beesd overrides, `uupd` package (timer disabled in finalize).
13. **NVIDIA stage facts:** `nvidia-gpu-firmware` removed; `egl-wayland{,2}` x86_64+i686; akmods kmods via `nvidia-install.sh`; nouveau ICDs removed; **`nvidia-powerd.service` ENABLED**, **`nvidia-persistenced.service` DISABLED** (units from driver RPMs) → masking both is a real change; `nvidia-deck.conf` removed for non-deck; terra-mesa + staging re-disabled at the end; final `bootc container lint` gate.
14. **ujust integration:** recipes in `/usr/share/ublue-os/just/*.just`, imported from `/usr/share/ublue-os/justfile` via appended `import` lines (full list verified). BlueBuild `justfiles` module (source-verified): copies `files/justfiles/**.just` → `/usr/share/bluebuild/justfiles/` and — since `/usr/bin/ujust` exists — appends imports to **`/usr/share/ublue-os/just/60-custom.just`** → recipes surface in `ujust`. Use `install: false` (base has `just`).
15. **COPR `lionheartp/Hyprland`** (Project 205252; full 56-package list retrieved via API): aquamarine, awww, breakpad, cliphist, glaze, gpu-screen-recorder, hyprcursor, hyprgraphics, hypridle, hyprland, hyprland-contrib, **hyprland-git** (0.56.2^56, auto-rebuilt), hyprland-guiutils, hyprland-plugins(-git), hyprland-protocols, hyprland-qt-support, hyprlang, hyprlauncher, hyprlock, hyprpaper, hyprpicker, hyprpolkitagent, hyprpwcenter, hyprqt6engine, hyprshot, hyprshutdown, hyprsunset, hyprsysteminfo, hyprtoolkit, hyprutils, hyprwayland-scanner, hyprwire, kitty, matugen, mpvpaper, **noctalia-git** (5.1.0^7, auto-rebuilt), noctalia-greeter-git, noctalia-hyprland-meta, noctalia-qs(-legacy), noctalia-shell(-legacy/-v5), nwg-look, python-imageio-ffmpeg, python-screeninfo, qt6ct, quickshell, uwsm, waybar-git, wayland-protocols, waypaper, wlroots, xcur2png, xdg-desktop-portal-hyprland. Chroots fedora-43/44/45/rawhide × x86_64/aarch64. **Pitfall (upstream-documented):** never mix `hyprland-git` with *stable* companion libs (hyprgraphics/hyprlang ABI breaks) → single transaction + provenance guard (§5.2).
16. **COPR `sneexy/zen-browser`** exists; package **`zen-browser`** confirmed via COPR API. ⚠VERIFY fedora-44 chroot coverage at implementation time (`dnf copr enable` fails loudly if missing). **DistroShelf** (github.com/ranfdev/DistroShelf): **installed as system Flatpak `com.ranfdev.DistroShelf` (Flathub) per v4 user directive** — no stage build, no spec, no RPM; the base's skel preconfig + `distroshelf-helper` are therefore KEPT (§1.9).
17. **Repo/package confirmations:** Brave repodata = repo ID `[brave-browser]` containing exactly `brave-browser`, `brave-keyring`, **`brave-origin`**; key `brave-core.asc`. VSCode repo ID `[code]`, key `microsoft.asc` (user-supplied .repo = MS official). **`zed` confirmed in terra44 repodata** (also `zed-cli`). `emacs-pgtk`, `greetd`, `greetd-tuigreet`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `qt6-qtwayland`, `nix`, `hyprpolkitagent`, `fastfetch` all confirmed in Fedora repos.
18. **Fedora greetd packaging (rawhide spec fetched):** v0.10.3; **greeter user is `greetd`, NOT `greeter`** (spec seds the username); ships sysusers.d/greetd.conf, tmpfiles.d, PAM (`/usr/lib/pam.d/greetd{,-greeter}`), default `/etc/greetd/config.toml` as `%config(noreplace)`, `agreety`, SELinux subpackage, `Provides: service(graphical-login)`. tuigreet flags `--time --remember --remember-user-session --asterisks --sessions --cmd` verified in tuigreet README; **`--remember*` requires a cache directory** → `/var/cache/tuigreet` via tmpfiles.d + `--cache` flag (§7.1/§7.2).
19. **BlueBuild module truths (source-verified):** official modules = akmods, apk, apt, bling, brew, chezmoi, default-flatpaks, dnf, files, fonts, gnome-extensions, gschema-overrides, initramfs, justfiles, kargs, os-release, pacman, rpm-ostree, script, signing, soar, systemd, yafti, zypper (**no `flatpaks` module exists**). Critical behaviors: **(a)** bare `type: script` = **v2** (snippets run in **`/bin/sh`**); v1 = bash → **halcyon pins `type: script@v1` for every snippet module**; `scripts:` (both versions) executes `files/scripts/*` under `$CONFIG_DIRECTORY/scripts` with each file's shebang. **(b)** `default-flatpaks` **v2 has NO `remove:`** (TypeSpec: notify/scope/repo/install only); **v1** supports `notify` + `system.{install,remove}`; v1/v2 must not be mixed (shared `system-flatpak-setup.{service,timer}`); v1 bakes lists to `/usr/share/bluebuild/default-flatpaks/{system,user}/{install,remove}` + `repo-info.json`, enables `system-flatpak-setup.timer` + `user-flatpak-setup.timer --global`, and **validates install IDs against Flathub at build time**. **(c)** `dnf` module `remove:` passes the list **raw** to `dnf5 -y remove` and `exit 1`s on any missing package (`DnfRemove = {packages, auto-remove=true}` only) → removal lists contain only **proven-present** packages; uncertain ones go through rpm-q-filtered scripts. **(d)** `repos: cleanup: true` → **deletes** repo files it added (via `dnf repo info … repo_file_path`) and **`dnf copr disable`s** COPRs (files remain, disabled) → halcyon explicitly `rm -f /etc/yum.repos.d/_copr_*` for its COPRs afterward (full T17 compliance). **(e)** `repos.files`: URLs or bare filenames resolved from `files/dnf/`; `%OS_VERSION%` supported. **(f)** `install-weak-deps` (default true), `skip-unavailable`, `skip-broken`, `allow-erasing`, `no-gpgchecks`, `exclude` valid on install/group-install/replace. **(g)** `files` module: `cp -rf files/<source>/* <destination>`. **(h)** `systemd` module: `system|user × enabled|disabled|masked|unmasked`; user ops = `systemctl --global`; copies `files/systemd/{system,user}/**` → `/usr/lib/systemd/{system,user}/` preserving structure. **(i)** `chezmoi`: latest binary → `/usr/bin/chezmoi`; `chezmoi-init.service` applies repo at FIRST LOGIN (only if `~/.local/share/chezmoi` absent); `chezmoi-update.{service,timer}` (`run-every` default 1d); `all-users` default **true** (`--global` enable); `file-conflict-policy: replace` → `chezmoi update --no-tty --force`. **(j)** `signing`: requires CLI-placed `/etc/pki/containers/aahsnr-work_halcyon.pub` (from repo-root `cosign.pub` — already committed ✓); writes `/etc/containers/policy.json` + registries.d for signed rebases. **(k)** `os-release`: updates/inserts only listed `properties:` in `/etc/os-release` — set NAME/PRETTY_NAME/HOME_URL, leave ID/VERSION_ID intact. **(l)** `gnome-extensions` module runs `gnome-shell --version` unconditionally → **unusable once GNOME is removed** (its README also defers PM-installed extensions to the PM) → dnf + script removal instead (§11 #1). **(m)** `fonts` module: nerd-fonts from `https://github.com/ryanoasis/nerd-fonts/releases/latest/download/<Name>.tar.xz` → `JetBrainsMono`, `NerdFontsSymbolsOnly` valid; google-fonts handles spaced names. **(n)** `stages` (unused in v4): only copy/script/files/containerfile modules work inside. **(o)** `/opt`-installing RPMs (brave): automatic with **BlueBuild CLI ≥ v0.9.23** (rpm-ostree relocates to `/usr/lib/opt` + per-package tmpfiles.d symlinks — coreos/rpm-ostree#233); CLI latest **v0.9.37** ✓. **(p)** `rpm-ostree install --idempotent` valid (unused in v4).
20. **Ecosystem versions:** repo's `build.yml` is user-final (§3.1: cron `00 08 * * *`, action **v1.12** — dependabot daily will offer bumps; do not hand-edit). `blue-build/github-action` latest = v1.13.0 (2026-09-14) — informational only. `from-file:` paths are relative to `recipes/` (docs + winter verified). `bluebuild generate-iso`: modes `image <ghcr-ref>` / `recipe <path>`, flag `--iso-name`; ISOs too large for free GitHub Releases hosting (template README) → workflow artifact.
21. **⚠ THE `--repoid` TRAP (user-reported field failure + module-source-consistent):** BlueBuild's `dnf` module executes every `repo:`-scoped entry as
    `dnf5 -y --setopt=install_weak_deps=False install --repoid <repo> <pkg>` —
    and **dnf5 `--repoid` confines the ENTIRE transaction, dependency resolution included, to that single repository**. Fedora/updates (and other repos) are invisible during solving, so any package whose dependencies live in Fedora (SDL2, X11, glib, qt6, mesa, …) becomes unresolvable; the solver then falls through to broken i686 multilib candidates from the third-party repo (`nothing provides libSDL2-2.0.so.0 … i686`). **Therefore `repo:`-scoped package entries are BANNED in every halcyon recipe file.** Install plain package names with the needed repos enabled for the whole (unscoped) transaction — unique package names (`code`, `brave-browser`, `brave-origin`, `zen-browser`, `zed`, `hyprland-git`, `noctalia-git`, …) make provenance unambiguous — and verify origin afterwards with `dnf -q repoquery --installed --qf '%{name} %{reponame}' <pkgs>`. This also applies to any future packages the user adds to the TODO sections.

---

## 2. Global constraints (non-negotiable)

1. Repo exists; `.github/workflows/build.yml`, `.github/dependabot.yml`, `.gitignore`, `cosign.pub`, `SIGNING_SECRET` are FINAL (§3) — do not modify, recreate, or "fix" them (including the build.yml cron comment/value mismatch — user's file, verbatim).
2. **Files-only delivery:** create the tree in the working copy and present it. NEVER `git push`, tag, release, or touch GHCR.
3. Recipe at `recipes/halcyon.yml` (build.yml matrix already points at it).
4. **Multi-file recipe:** `halcyon.yml` = metadata + ordered `from-file:` includes; module configs live in **`recipes/modules/*.yml`** named **without** a `halcyon-` prefix: `removals.yml`, `desktop.yml`, `apps.yml`, `fonts.yml`, `flatpaks.yml`, `nix.yml`, `brew.yml`, `build-scripts.yml`, `files.yml`, `services.yml`, `branding.yml` (11 files). Each starts with `---` + `# yaml-language-server: $schema=https://schema.blue-build.org/module-list-v1.json` + `modules:` list form.
5. **Removals run first** (module order), before any installs.
6. **`install-weak-deps: false`** on every dnf `install:`/`group-install:`/`replace:` block.
7. **NEVER use `repo:`-scoped package entries** (§1.21). Plain names + whole-transaction resolution + post-install provenance guards.
8. **Repo hygiene:** every repo/COPR/key halcyon adds (lionheartp, sneexy, vscode, brave) is removed right after its installs: `repos: cleanup: true` + explicit `rm -f /etc/yum.repos.d/_copr_*.repo` for the two COPRs (§1.19d). Base repos untouched (§1.11); `terra` toggled enable→install→re-disable for `zed`.
9. Browsers/editors install **only** via the `dnf` module (no shell-installer scripts).
10. **Every `script` module is `type: script@v1`** (bash snippets — §1.19a). The four build-time installer scripts run via the `scripts:` key (`files/scripts/*.sh`).
11. Keep the `signing` module (already-wired keys). Do **not** use `initramfs`, `akmods`, or `brew` modules (§1.5/§1.13 cover them). No `stages:` in v4 (DistroShelf = Flatpak).
12. `platforms: [linux/amd64]` only.
13. User-managed areas stay `# TODO(user)` stubs (personal shell setup, extra helper scripts, branding assets, additional app list) — never invent content.
14. Removal lists: proven-present packages via dnf module; uncertain ones via rpm-q-filtered scripts with **hard post-verification** (build fails if a confirmed removal survived or a confirmed keeper died).
15. Deviations from the user's literal TODO wording (§11) documented in README + delivery notes.

---

## 3. Existing repo state (FINAL — do not modify) and target tree

### 3.1 `.github/workflows/build.yml` (already in repo, verbatim — DO NOT MODIFY)

```yaml
name: bluebuild
on:
  schedule:
    - cron:
        "00 08 * * *" # build at 06:00 UTC every day
        # (20 minutes after last ublue images start building)
  push:
    paths-ignore: # don't rebuild if only documentation has changed
      - "**.md"

  pull_request:
  workflow_dispatch: # allow manually triggering builds
concurrency:
  # only run one build at a time
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true
jobs:
  bluebuild:
    name: Build Custom Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    strategy:
      fail-fast: false # stop GH from cancelling all matrix builds if one fails
      matrix:
        recipe:
          - halcyon.yml
    steps:
      # the build is fully handled by the reusable github action
      - name: Build Custom Image
        uses: blue-build/github-action@v1.12
        with:
          recipe: ${{ matrix.recipe }}
          cosign_private_key: ${{ secrets.SIGNING_SECRET }}
          registry_token: ${{ github.token }}
          pr_event_number: ${{ github.event.number }}

          # enabled by default, disable if your image is small and you want faster builds
          maximize_build_space: true
```

### 3.2 `.github/dependabot.yml` (already in repo, verbatim — DO NOT MODIFY)

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
```

### 3.3 `.gitignore` (must exist EXACTLY as follows)

```
cosign.key
cosign.private
/Containerfile
*.build
*.log
/tmp/
/dist/
*.tar
*.tar.gz
*.oci
.vscode/
.idea/
*.swp
/.bluebuild-scripts_*
__pycache__/
*.pyc
*.iso
*.iso-CHECKSUM
.obsidian/
```

### 3.4 Files to CREATE (the deliverable)

```
halcyon/                                   (existing repo)
├── .github/workflows/build-iso.yml        # NEW — §8.2
├── recipes/
│   ├── halcyon.yml                        # §4
│   └── modules/
│       ├── removals.yml                   # 1st — §5.1
│       ├── desktop.yml                    # 2nd — §5.2
│       ├── apps.yml                       # 3rd — §5.3
│       ├── fonts.yml                      # 4th — §5.4
│       ├── flatpaks.yml                   # 5th — §5.5
│       ├── nix.yml                        # 6th — §5.6
│       ├── brew.yml                       # 7th — §5.7
│       ├── build-scripts.yml              # 8th — §5.8
│       ├── files.yml                      # 9th — §5.9
│       ├── services.yml                   # 10th — §5.10
│       └── branding.yml                   # 11th — §5.11
├── files/
│   ├── dnf/vscode.repo                    # §7.5
│   ├── justfiles/{doom-setup,home-manager-setup}.just   # §6.2
│   ├── nix-profile/00-nix-resolve-home-env.sh           # §6.4
│   ├── nix-tmpfiles/nix.conf                            # §6.4
│   ├── scripts/install-{obsidian,zotero,pyprland,texlive}.sh  # §6.3
│   ├── systemd/
│   │   ├── system/{var-nix.service, nix.mount}          # §6.4
│   │   └── user/halcyon-brew-bundle.service             # §7.3
│   └── system/                            # → image / via files module
│       ├── etc/{greetd/config.toml, profile.d/halcyon-path.sh, motd.d/halcyon-motd.txt}
│       └── usr/
│           ├── lib/tmpfiles.d/halcyon-greetd.conf       # §7.2
│           ├── libexec/halcyon-image/{fconf,fe}         # §6.1
│           └── share/{ublue-os/homebrew/halcyon.Brewfile, plymouth/themes/halcyon/, backgrounds/halcyon/}
├── README.md                              # §9
└── (keep existing: cosign.pub, LICENSE, .gitignore, .github/*, root modules/.gitkeep if present)
```

---

## 4. `recipes/halcyon.yml`

```yaml
---
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
# image will be published to ghcr.io/aahsnr-work/halcyon
name: halcyon
description: >-
  Lean Hyprland gaming desktop forked from Bazzite (GNOME removed;
  Hyprland + Noctalia; NVIDIA open drivers inherited; curated dev tooling).

base-image: ghcr.io/ublue-os/bazzite-gnome-nvidia-open
image-version: latest
platforms:
  - linux/amd64

labels:
  halcyon.base: bazzite-gnome-nvidia-open
  halcyon.desktop: hyprland-noctalia

modules:
  # ORDER IS SIGNIFICANT — removals first (constraint 5), services/branding last.
  - from-file: modules/removals.yml
  - from-file: modules/desktop.yml
  - from-file: modules/apps.yml
  - from-file: modules/fonts.yml
  - from-file: modules/flatpaks.yml
  - from-file: modules/nix.yml
  - from-file: modules/brew.yml
  - from-file: modules/build-scripts.yml
  - from-file: modules/files.yml
  - from-file: modules/services.yml
  - from-file: modules/branding.yml
  - type: signing
```

---

## 5. Module files (`recipes/modules/*.yml`)

All files: `---` + `# yaml-language-server: $schema=https://schema.blue-build.org/module-list-v1.json` + `modules:` list. All script modules: **`type: script@v1`**. **No `repo:`-scoped installs anywhere (§1.21).**

### 5.1 `removals.yml` (FIRST)

**Step A — detection (script@v1):** log to build output + `/tmp/halcyon-inventory.txt`:
`rpm -qa` greps for all bloat candidates (§1.2/§1.9 lists); `rpm -qa '*fonts*'`; `ls /etc/yum.repos.d/`; `dnf5 repolist --enabled`; `ls /etc/flatpak/remotes.d/`; `rpm -q bazaar bazzite-portal scx-scheds scx-tools steamos-manager jq perl python3`; `systemctl is-enabled` for {sddm, gdm, nvidia-powerd, nvidia-persistenced, scx_loader, inputplumber, bazzite-autologin, brew-setup, bazzite-flatpak-manager}; `ls /usr/share/homebrew*`; `grep ^SHELL /etc/default/useradd`; non-RPM dirs under `/usr/share/gnome-shell/extensions/`; `dnf -q repoquery --installed --whatrequires` for {sddm, cage, steamos-manager, gnome-settings-daemon}.

**Step B — confirmed removals (dnf module; every entry proven present via §1 sources):**

```yaml
- type: dnf
  remove:
    auto-remove: true          # sweep orphaned deps
    packages:
      # Bazzite GNOME additions (§1.9a)
      - nautilus-gsconnect
      - gnome-shell-extension-gsconnect
      - gnome-shell-extension-user-theme
      - gnome-search-yafti
      - gnome-rounded-blur
      - firewall-config
      # input-method extras (§1.9a)
      - ibus-mozc
      - ibus-pinyin
      - ibus-table-chinese-cangjie
      - ibus-table-chinese-quick
      # handheld/Deck stack, all-image bake (§1.2)
      - inputplumber
      - steamos-manager-powerstation
      - jupiter-fan-control
      - jupiter-hw-support-btrfs
      - galileo-mura
      - steamdeck-dsp
      - powerbuttond
      - vpower
      - sdgyrodsu
      - hid-replay
      - steamdeck-backgrounds
      - steamdeck-gnome-presets
      # Android + bling (§1.2, §1.6)
      - waydroid
      - fastfetch
      # silverblue-compose certainties (GNOME core + firefox)
      - firefox
      - firefox-langpacks
      - gnome-shell
      - mutter
      - gdm
      - gnome-session
      - gnome-session-wayland-session
      - nautilus
      - ptyxis
      - gnome-control-center
      - gnome-settings-daemon   # §11 note: re-add if GTK apps misbehave under Hyprland
      - gjs
      - xdg-desktop-portal-gnome
```

**Step C — guarded removals + hard verification (script@v1):** rpm-q-filtered candidates (compose-variance / expected-absent): gnome-classic-session(-xsession), gnome-terminal, gnome-console, gnome-text-editor, evince, loupe, snapshot, totem, gnome-calculator/calendar/characters/clocks/connections/contacts/font-viewer/logs/maps/remote-desktop/system-monitor/tour/weather/initial-setup/extensions-app/software, baobab, simple-scan, yelp, malcontent-control, gnome-bluetooth, jupiter-sd-mounting-btrfs, ds-inhibit, plasma-login-manager, hhd(-ui), decky-loader, bluebubbles, the 5 stock gnome-shell-extension-* names, mozilla-filesystem. Reverse-dep gates: **sddm** (remove only if `repoquery --whatrequires sddm` shows no keeper; else keep → masked §5.10) and **cage** (same gate). Then:
- `dnf -y remove "${present[@]}"` for filtered survivors.
- **Hard-fail verification:** assert ABSENT: gnome-shell, gdm, mutter, waydroid, fastfetch, firefox, inputplumber, steamos-manager-powerstation, steamdeck-gnome-presets, jupiter-fan-control; assert PRESENT: steamos-manager, bazaar, bazzite-portal, steam, gamescope-session-ogui-steam, terra-gamescope, umu-launcher, lutris, gamemode, scx-scheds, scx-tools, usbip, xwiimote-ng, input-remapper, distroshelf-helper.

**Step D — file footprint + service/justfile pruning (script@v1):**
- Waydroid set (§1.12): `/etc/default/waydroid-launcher`, `/usr/bin/waydroid-launcher`, `/usr/bin/waydroid-choose-gpu`, `/usr/libexec/waydroid-container-{start,stop,restart}`, `/usr/libexec/waydroid-fix-controllers`, `/usr/share/applications/Waydroid*` (+art dir), `/usr/share/applications/waydroid-container-restart.desktop`, `/usr/share/polkit-1/actions/org.bazzite.waydroid.policy`, `/usr/share/polkit-1/rules.d/30-waydroid.rules`.
- Bling set (§1.6): `/usr/libexec/bazzite-bling-fastfetch`, `/usr/share/ublue-os/bazzite/fastfetch.jsonc`, `/usr/share/bazzite-cli/bling.sh`, `/usr/share/bazzite-cli/bling.fish`, **`/etc/profile.d/bazzite-neofetch.sh`**; excise the `bazzite-cli` recipe block from `/usr/share/ublue-os/just/80-bazzite.just` (from its `# Enable a Bluefin-style CLI experience` header to the next `[group(` header).
- GNOME config footprint (§1.9): the two `/etc/dconf/db/distro.d/0*-bazzite-desktop-silverblue-*` files + `locks/` entry; all five `/usr/share/glib-2.0/schemas/zz0-0*-bazzite-desktop-silverblue-*.gschema.override`; `/usr/share/gnome-background-properties/` (dir); symlinks `/usr/share/backgrounds/default.jxl` + `default-dark.jxl` (keep the actual wallpaper images); `/usr/lib/systemd/system/dconf-update.service`; `/usr/share/ublue-os/motd/tips/30-gnome.md`; `/usr/share/applications/gnome-ssh-askpass.desktop`; `/usr/share/ublue-os/firefox-config/03-bazzite-gnome.js`; skel items `/etc/skel/.config/gnome-initial-setup-done` + `/etc/skel/.local/share/org.gnome.Ptyxis/`; scrub `org.gnome.*` handler lines from `/etc/xdg/mimeapps.list` (guarded sed). **KEEP** `/etc/skel/.var/app/com.ranfdev.DistroShelf/`, `/usr/bin/distroshelf-helper`, `/etc/xdg/mineapps.list` (DistroShelf flatpak retained — §1.16).
- SDDM/autologin: `rm -rf /etc/sddm.conf.d`.
- Dangling service hygiene (all `|| true`): `systemctl disable inputplumber.service powerstation.service jupiter-fan-control.service vpower.service jupiter-biosupdate.service jupiter-controller-update.service sdgyrodsu.service waydroid-container.service bazzite-autologin.service dconf-update.service`; `systemctl --global disable sdgyrodsu.service steamos-powerbuttond.service`; `rm -f /usr/lib/systemd/user/gamescope-session-plus@ogui-steam.service.wants/steamos-powerbuttond.service`; prune dangling wants symlinks: `find /etc/systemd /usr/lib/systemd -name '*.wants' -type d -exec find {} -xtype l -delete \; 2>/dev/null || true`.
- Justfiles: delete `82-bazzite-waydroid.just`, `91-bazzite-decky.just`, `95-bazzite-deck-session.just`, `90-bazzite-de.just` (+ deck-variant copies if present) **and their `import` lines** in `/usr/share/ublue-os/justfile`; then `grep -l 'gnome-shell\|gdm\|sddm\|waydroid\|decky' /usr/share/ublue-os/just/*.just` → patch/remove only affected recipes (KEEP `82-bazzite-apps.just` — `install-openrazer`; `94-bazzite-protonplus.just`; `95-bazzite-nvidia.just`; all others per §1.12).
- steamos-manager patch: `sed -i 's/desktop = "gnome.desktop"/desktop = "hyprland.desktop"/' /usr/share/steamos-manager/platform.toml` (guarded).
- `grep -q '^SHELL=/bin/bash' /etc/default/useradd || sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd`.

**Step E — directory-installed GNOME extensions (script@v1)** (replaces the `gnome-extensions` module — §11 #1):

```bash
set -euo pipefail
rm -rf /usr/share/gnome-shell/extensions     # the 12 dirs from §1.9b (not RPM-owned)
glib-compile-schemas /usr/share/glib-2.0/schemas || true
rm -f /etc/dconf/db/local.d/*bazzite* /etc/dconf/db/local.d/*gnome* 2>/dev/null || true
[ -d /etc/dconf/db/local.d ] && dconf update || true
```

**Step F — fonts, safe removal (script@v1):** reverse-dependency-filtered loop over `rpm -qa '*fonts*'` (protect regex `fontconfig|fontpackages|dejavu-sans-fonts|dejavu-sans-mono-fonts`), `rpm -e --nodeps` only zero-requiring packages, log kept/removed; expect the five Bazzite font RPMs (§1.10) to go; `fc-cache -f`. README notes the CJK-coverage tradeoff (fonts module restores Noto Emoji + JetBrains Mono; user may re-add CJK later).

### 5.2 `desktop.yml` — Hyprland + Noctalia + greetd (UNSCOPED installs, §1.21)

```yaml
modules:
  - type: dnf
    repos:
      cleanup: true                      # disables the COPR after install; file purged below
      copr:
        - lionheartp/Hyprland
    install:
      install-weak-deps: false
      skip-unavailable: true
      packages:                          # PLAIN names — deps resolve from fedora+updates+COPR
        - hyprland-git                   # only in lionheartp COPR
        - noctalia-git                   # only in lionheartp COPR
        - hyprpolkitagent
        - hyprland-qt-support
        - greetd
        - greetd-tuigreet
        - xdg-desktop-portal-hyprland
        - xdg-desktop-portal-gtk
        - qt6-qtwayland

  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        rm -f /etc/yum.repos.d/_copr_lionheartp_Hyprland.repo   # full T17 hygiene (§1.19d)
        rpm -q hyprland-git noctalia-git greetd greetd-tuigreet xdg-desktop-portal-hyprland
        # -git stack ABI consistency guard (§1.15):
        ldd /usr/bin/Hyprland 2>/dev/null | grep -i 'not found' && { echo 'ERROR: hyprland -git ABI break'; exit 1; } || true
        # provenance guard: hyprland-git's companion libs must come from the COPR, not Fedora stable
        dnf -q repoquery --installed --qf '%{name} from %{reponame}' \
          hyprland-git noctalia-git hyprgraphics hyprlang aquamarine hyprcursor hyprutils || true
        for p in hyprgraphics hyprlang aquamarine hyprcursor; do
          rpm -q "$p" >/dev/null 2>&1 || continue
          dnf -q repoquery --installed --qf '%{reponame}' "$p" | grep -q 'lionheartp' \
            || { echo "ERROR: $p resolved outside lionheartp COPR — mixed -git stack risk (§1.15). Remediation: re-run with the COPR repo file priority raised (dnf5 config-manager setopt '*lionheartp*'.priority=1) between copr-enable and install, via two dnf module entries + interleaved script."; exit 1; }
        done
        test -f /usr/share/wayland-sessions/hyprland.desktop
        id greetd    # Fedora greetd sysusers (spec-verified §1.18); hard gate for §7.1 config
        dnf5 repolist --enabled | grep -Ei 'lionheartp' && { echo 'ERROR: COPR still enabled'; exit 1; } || true
```

- greetd config ships as `files/system/etc/greetd/config.toml` (§7.1) — **`user = "greetd"`** (Fedora packaging fact §1.18; overwriting the RPM's `%config(noreplace)` default at build time is fine; later rpm updates 3-way-merge).
- No user-level Hyprland config baked (Noctalia first-run wizard + chezmoi dots own `~/.config/hypr`); optional ≤10-line `/etc/skel/.config/hypr/hyprland.conf` stub only if `rpm -ql noctalia-git` shows the wizard needs one — mark `# TODO(user)`.
- Optional COPR extras the user may add later to the §5.3 TODO section (available per §1.15): hyprshot, hypridle, hyprlock, hyprpaper, cliphist, kitty, waybar-git, matugen, uwsm, noctalia-greeter-git, nwg-look, qt6ct.
- sched_ext: nothing to install (§1.4) — README documents `scxctl`/`scx_loader` + BORE caveat.

### 5.3 `apps.yml` — browsers/editors via dnf module (UNSCOPED; repos cleaned up)

`files/dnf/vscode.repo` per §7.5. Terra pre-exists (disabled) → sandwich:

```yaml
modules:
  - type: script@v1
    snippets:
      - dnf5 config-manager setopt terra.enabled=1   # pre-existing base repo, temporarily enabled (§1.11)

  - type: dnf
    repos:
      cleanup: true
      files:
        - vscode.repo            # resolved from files/dnf/vscode.repo
        - https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
      keys:
        - https://packages.microsoft.com/keys/microsoft.asc
        - https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
      copr:
        - sneexy/zen-browser
    install:
      install-weak-deps: false
      skip-unavailable: true     # guards brave-origin availability windows
      packages:                  # PLAIN names only (§1.21) — all six are unique across enabled repos
        - code
        - brave-browser
        - brave-origin
        - zen-browser
        - zed
        - emacs-pgtk             # Fedora official (doom-setup needs Emacs)

  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        dnf5 config-manager setopt terra.enabled=0    # restore base state (§1.11)
        rm -f /etc/yum.repos.d/_copr_sneexy_zen-browser.repo
        command -v code brave zen-browser zed emacs
        # provenance (§1.21): each package from its intended repo
        dnf -q repoquery --installed --qf '%{name} from %{reponame}' code brave-browser zen-browser zed emacs-pgtk
        rpm -q brave-origin || echo 'NOTE: brave-origin unavailable this run (skip-unavailable)'
        # /opt auto-relocation check (CLI >= v0.9.23, §1.19o):
        ls -d /usr/lib/opt/brave.com 2>/dev/null || ls -d /opt/brave.com 2>/dev/null \
          || { echo 'ERROR: brave /opt content missing — check BlueBuild CLI version'; exit 1; }
        ls /usr/lib/tmpfiles.d/ | grep -i brave || true
        # repo hygiene gates
        dnf5 repolist --enabled | grep -Ei 'brave|^code|zen|terra' && { echo 'ERROR: repo cleanup failed'; exit 1; } || true
        ls /etc/yum.repos.d/ | grep -Ei 'brave|vscode|_copr_sneexy' && { echo 'ERROR: repo file left behind'; exit 1; } || true
```

> `# TODO(user): additional apps` — clearly-marked empty `packages:` extension point at the bottom (user's own app list; **plain names only — never `repo:`-scoped**, §1.21).

### 5.4 `fonts.yml`

```yaml
modules:
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

### 5.5 `flatpaks.yml` — `default-flatpaks@v1` (v2 has no remove — §1.19b); DistroShelf KEPT as Flatpak (v4 directive)

```yaml
modules:
  - type: default-flatpaks@v1
    notify: true
    system:
      # repo-url/repo-name omitted → Flathub defaults (tsp-verified)
      install:
        - com.ranfdev.DistroShelf          # v4: system flatpak replaces the stage-built RPM
        - com.github.tchx84.Flatseal
        - org.onlyoffice.desktopeditors
        - com.bitwarden.desktop
        - com.ticktick.TickTick
      remove:                        # base GNOME set (§1.8) minus Flatseal & DistroShelf
        - org.mozilla.firefox
        - com.mattjakeman.ExtensionManager
        - com.github.Matoking.protontricks
        - io.github.flattool.Warehouse
        - io.missioncenter.MissionCenter
        - com.vysp3r.ProtonPlus
        - org.gnome.Calculator
        - org.gnome.Calendar
        - org.gnome.Characters
        - org.gnome.Contacts
        - org.gnome.Papers
        - org.gnome.Logs
        - org.gnome.Loupe
        - org.gnome.NautilusPreviewer
        - org.gnome.TextEditor
        - org.gnome.Weather
        - org.gnome.baobab
        - org.gnome.clocks
        - org.gnome.font-viewer
        - org.gnome.Showtime
        - org.gnome.Firmware
        - page.tesk.Refine
```

Runtime semantics (every boot, idempotent); install IDs are Flathub-validated at build time (§1.19b); `bazzite-flatpak-manager` stays enabled (§1.7); Vulkan-layer runtimes untouched; the base's DistroShelf skel preconfig + `distroshelf-helper` are KEPT (§1.9/§1.16); the empty duplicate `configuration` in the original TODO (template leftover) stays dropped; user's v2-style config translated to v1 with identical intent (§11 #6).

### 5.6 `nix.yml` — fu5ha/winter verbatim (Apache-2.0; credit in README)

```yaml
modules:
  - type: files
    files:
      - source: nix-tmpfiles
        destination: /usr/lib/tmpfiles.d/
      - source: nix-profile
        destination: /etc/profile.d/

  - type: systemd
    system:
      enabled:
        - var-nix.service
        - nix.mount

  - type: dnf
    install:
      install-weak-deps: false     # winter omits this; halcyon constraint #6 adds it (§11 #4)
      packages:
        - nix
        - nix-daemon               # nix multi-user/systemd install

  - type: systemd
    system:
      enabled:
        - nix-daemon
```

Support files verbatim in §6.4. Home-Manager NOT baked — bootstrapped post-login by `ujust home-manager-setup` (§6.2) against the chezmoi dots.

### 5.7 `brew.yml` — 21 formulas via Brewfile + first-login user service (verification only)

Assets ship via §5.9's `files` module (`files/system/usr/share/ublue-os/homebrew/halcyon.Brewfile` → image) and the systemd module's unit copy (`files/systemd/user/halcyon-brew-bundle.service` → `/usr/lib/systemd/user/`). One home per asset, no duplicates.

```yaml
modules:
  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        test -f /usr/share/homebrew.tar.zst                      # base brew payload intact (untouched!)
        test -f /usr/share/ublue-os/homebrew/halcyon.Brewfile
        test "$(grep -c '^brew ' /usr/share/ublue-os/homebrew/halcyon.Brewfile)" -eq 21
        test -f /usr/lib/systemd/user/halcyon-brew-bundle.service
```

Service enabled `--global` in §5.10. `brew bundle --no-lock` (Brewfile on read-only `/usr`); runs as the logging-in user after base `brew-setup.service` extracts brew (§1.5); overlap with `bazzite-cli.Brewfile` is idempotent-harmless.

### 5.8 `build-scripts.yml` — the four build-time installers (§6.3), baked results

```yaml
modules:
  - type: dnf
    install:
      install-weak-deps: false
      skip-unavailable: true
      packages:
        - gcc        # pyprland's optional C helper (removed again below)
        - perl       # tlmgr — NOT in base (Containerfile audit); KEPT for runtime tlmgr
        - jq         # install-obsidian.sh / install-pyprland.sh — base presence unconfirmed; KEPT (tiny)
        - python3    # venv base (python3-pip IS in base → likely present; idempotent)

  - type: script@v1
    scripts:           # official mechanism: executes files/scripts/*.sh ($CONFIG_DIRECTORY/scripts)
      - install-obsidian.sh
      - install-zotero.sh
      - install-pyprland.sh
      - install-texlive.sh

  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        test -x /usr/bin/obsidian && test -f /usr/share/applications/obsidian.desktop
        ldd /usr/lib/obsidian/obsidian 2>/dev/null | grep -i 'not found' && { echo 'ERROR: obsidian electron deps missing'; exit 1; } || true
        test -x /usr/bin/zotero && grep -q DisableAppUpdate /usr/lib/zotero/distribution/policies.json
        test -x /usr/bin/pypr && test -f /usr/lib/systemd/user/pyprland.service
        test -d /usr/lib/texlive && test -f /etc/profile.d/texlive.sh
        dnf -y remove gcc || true          # build-only tooling
        rpm -q perl python3 jq             # deliberately KEPT (documented in README)
```

> TeX Live (`scheme-medium`) adds multi-GB build traffic and image weight — intended by the user; keep `EXTRA_TL_PACKAGES=(latexmk biber)` exactly as scripted.

### 5.9 `files.yml` — files, justfiles, chezmoi

```yaml
modules:
  - type: files
    files:
      - source: system
        destination: /          # files/system/** → /** (template+winter verified)

  - type: justfiles
    install: false              # just/ujust in base
    validate: false
    # files/justfiles/*.just → /usr/share/bluebuild/justfiles/
    # + imports appended to /usr/share/ublue-os/just/60-custom.just → visible in `ujust` (§1.14)

  - type: chezmoi
    repository: https://github.com/aahsnr-configs/dots
    file-conflict-policy: replace     # repo = source of truth (user decision)
    # all-users default true → --global enable chezmoi-init.service + chezmoi-update.timer;
    # chezmoi-init applies dots at FIRST LOGIN (only if ~/.local/share/chezmoi absent)

  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        chmod 0755 /usr/libexec/halcyon-image/*
        test -f /etc/profile.d/halcyon-path.sh
        command -v chezmoi
        grep -q 'doom-setup' /usr/share/ublue-os/just/60-custom.just
        grep -q 'home-manager-setup' /usr/share/ublue-os/just/60-custom.just
```

### 5.10 `services.yml` — systemd (AFTER §5.8 so pyprland.service exists)

```yaml
modules:
  - type: systemd
    system:
      enabled:
        - greetd.service
      masked:
        - sddm.service                 # base DM (§1.1); RPM may survive if dep-gated (§5.1C) — mask covers both
        - gdm.service                  # base already disables; mask hardens
        - bazzite-autologin.service    # deck-only unit (§1.2); mask in case files linger
        - nvidia-persistenced.service  # user requirement (disabled in base)
        - nvidia-powerd.service        # user requirement (ENABLED in base — real change, §1.13)
    user:                              # systemctl --global
      enabled:
        - pyprland.service             # from install-pyprland.sh (§6.3)
        - halcyon-brew-bundle.service  # §7.3
```

### 5.11 `branding.yml`

```yaml
modules:
  - type: os-release
    properties:
      NAME: halcyon
      PRETTY_NAME: halcyon (Bazzite fork)
      HOME_URL: https://github.com/aahsnr-work/halcyon
      # ID/ID_LIKE intentionally untouched (fedora-compatible; §1.19k)

  - type: script@v1
    snippets:
      - |
        set -euo pipefail
        grep -q 'PRETTY_NAME="halcyon' /etc/os-release
        if command -v plymouth-set-default-theme >/dev/null 2>&1; then
          plymouth-set-default-theme halcyon || plymouth-set-default-theme spinner || true
        fi
        test -f /etc/motd.d/halcyon-motd.txt
        test -d /usr/share/backgrounds/halcyon
```

Plymouth theme files + motd + backgrounds README are `TODO(user)` placeholders (§7.7). No invented logos/wallpapers.

---

## 6. Verbatim user assets (transcribe EXACTLY — do not reformat, rename or "improve")

### 6.1 `files/system/usr/libexec/halcyon-image/fconf` (mode 0755, no extension)

```bash
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

### 6.1b `files/system/usr/libexec/halcyon-image/fe` (mode 0755, no extension)

```bash
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

> The user will add more helpers here later — the files module + §5.9 chmod handle any new drop-in. Deps: fd/fzf/bat from the §7.2b Brewfile at first login; `$EDITOR` defaults to nvim (user's dots provide it).

### 6.2 `files/justfiles/doom-setup.just`

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

### 6.2b `files/justfiles/home-manager-setup.just`

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

> README notes: `doom-setup` clones via **SSH** (`git@github.com:aahsnr-configs/doom.git`) — user SSH keys must exist at run time; `emacs-pgtk` (§5.3), `git` (base), `fd`/`rg` (Brewfile) are present. `home-manager-setup` requires the §5.6 nix stack (its error message references it).

### 6.3 `files/scripts/install-{obsidian,zotero,pyprland,texlive}.sh` — executed at BUILD time via the `script@v1` module's `scripts:` key (§5.8)

```bash
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

```bash
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

```bash
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

```bash
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

> Transcribe character-for-character (URLs, fallback versions v1.8.7/3.4.4, traps, heredocs must not drift). `perl` kept for runtime `tlmgr`; `python3` kept for the pyprland venv.

### 6.4 winter nix files (fu5ha/winter @ main, Apache-2.0 — attribute in README)

**`files/nix-tmpfiles/nix.conf`** → `/usr/lib/tmpfiles.d/nix.conf`:

```
# Directories needed by Nix after /var/nix is bind-mounted on /nix.
# The Fedora nix RPM creates these in the image /nix, but that content is
# hidden once nix.mount is active on an existing bootc/rpm-ostree system.
d /nix/store             1775 root nixbld - -
d /nix/var/nix           0775 root nixbld - -
d /nix/var/log/nix/drvs  0775 root nixbld - -
```

**`files/nix-profile/00-nix-resolve-home-env.sh`** → `/etc/profile.d/00-nix-resolve-home-env.sh`:

```bash
# Nix does not like home being a symlink, use the real path instead
HOME=$(readlink -f "$HOME")
export HOME

# Make sure XDG_DATA_HOME and XDG_CONFIG_HOME set, needed for CI
[ -z "$XDG_DATA_HOME" ] && export XDG_DATA_HOME="$HOME/.local/share"
[ -z "$XDG_CONFIG_HOME" ] && export XDG_CONFIG_HOME="$HOME/.config"
```

**`files/systemd/system/var-nix.service`**:

```ini
[Unit]
Description=Create backing directory for /nix bind mount
DefaultDependencies=no
After=systemd-remount-fs.service
Before=nix.mount
Before=local-fs.target
RequiresMountsFor=/var

[Service]
Type=oneshot
ExecStart=/usr/bin/install -d -m 0755 -o root -g root /var/nix
RemainAfterExit=yes

[Install]
RequiredBy=nix.mount
```

**`files/systemd/system/nix.mount`**:

```ini
[Unit]
Description=Bind mount /var/nix to /nix
Requires=var-nix.service
After=var-nix.service

[Mount]
What=/var/nix
Where=/nix
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
```

---

## 7. Authored supporting assets (content fixed)

### 7.1 `files/system/etc/greetd/config.toml`

```toml
[terminal]
vt = 1

[general]
source_profile = true

[default_session]
command = "tuigreet --time --remember --remember-user-session --asterisks --cache /var/cache/tuigreet --sessions /usr/share/wayland-sessions --cmd Hyprland"
user = "greetd"
```
`user = "greetd"` is **required** on Fedora (spec seds upstream `greeter`→`greetd`; sysusers + PAM shipped by the package — §1.18). `--cache` directory provided by §7.2 (tuigreet `--remember*` requires it). Session picker lists hyprland + kept gamescope-session entries. ⚠VERIFY `--asterisks` against `tuigreet --help` at implementation time.

### 7.2 `files/system/usr/lib/tmpfiles.d/halcyon-greetd.conf`

```
d /var/cache/tuigreet 0700 greetd greetd - -
```

### 7.2b `files/system/usr/share/ublue-os/homebrew/halcyon.Brewfile`

```ruby
brew "atuin"
brew "bat"
brew "btop"
brew "bun"
brew "cava"
brew "chafa"
brew "direnv"
brew "dust"
brew "eza"
brew "fd"
brew "fzf"
brew "gnuplot"
brew "lazygit"
brew "pandoc"
brew "pixi"
brew "ripgrep"
brew "starship"
brew "tealdeer"
brew "uv"
brew "yazi"
brew "zellij"
```

### 7.3 `files/systemd/user/halcyon-brew-bundle.service`

```ini
[Unit]
Description=Install halcyon Homebrew formulas (once, at first login)
Wants=network-online.target
After=network-online.target
ConditionPathExists=/home/linuxbrew/.linuxbrew/bin/brew
ConditionPathExists=!%h/.config/halcyon/.brew-bundle-done

[Service]
Type=oneshot
Environment=HOMEBREW_NO_AUTO_UPDATE=1
Environment=HOMEBREW_NO_ANALYTICS=1
Environment=HOMEBREW_NO_ENV_HINTS=1
ExecStartPre=/usr/bin/mkdir -p %h/.config/halcyon
ExecStart=/home/linuxbrew/.linuxbrew/bin/brew bundle --no-lock --file /usr/share/ublue-os/homebrew/halcyon.Brewfile
ExecStartPost=/usr/bin/touch %h/.config/halcyon/.brew-bundle-done

[Install]
WantedBy=default.target
```

### 7.4 `files/system/etc/profile.d/halcyon-path.sh`

```bash
# halcyon helper scripts (fconf, fe, ...)
export PATH="/usr/libexec/halcyon-image:${PATH}"
```

### 7.5 `files/dnf/vscode.repo`

```ini
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
```

### 7.6 OPTIONAL hardening — `files/systemd/system/flatpak-add-fedora-repos.service.d/10-halcyon.conf` (only if the user wants the disabled fedora remote definitions gone; default = leave base behavior, §1.7):

```ini
[Unit]
Description=halcyon: flathub only (fedora flatpak remotes not added)

[Service]
ExecStart=
ExecStart=/usr/bin/flatpak remote-add --system --if-not-exists flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
ExecStartPost=
ExecStartPost=/usr/bin/touch /var/lib/flatpak/.ublue-initialized
```

### 7.7 Branding placeholders — `files/system/usr/share/plymouth/themes/halcyon/halcyon.plymouth`:

```ini
[Plymouth Theme]
Name=halcyon
Description=halcyon boot theme (TODO(user): replace with branded assets)
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/halcyon
```
+ minimal `halcyon.script` (or reuse base spinner assets); `files/system/etc/motd.d/halcyon-motd.txt` and `files/system/usr/share/backgrounds/halcyon/README.md` as `TODO(user)` text placeholders.

---

## 8. CI/CD

### 8.1 `build.yml` — EXISTS, FINAL (§3.1). Do not modify. (Cron `00 08 * * *`, action v1.12, matrix `halcyon.yml`, `SIGNING_SECRET`, `maximize_build_space: true`; dependabot handles action bumps.)

### 8.2 NEW `build-iso.yml` — ISO for the ONE image (manual trigger)

```yaml
name: build-iso
on:
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  generate-iso:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v4

      - name: Install BlueBuild CLI (>= v0.9.23 required for /opt handling; latest v0.9.37)
        run: |
          curl -fsSL https://raw.githubusercontent.com/blue-build/cli/main/install.sh | sudo bash
          bluebuild --version

      - name: Generate ISO from the published halcyon image (run after a green build.yml)
        run: |
          sudo bluebuild generate-iso --iso-name halcyon.iso image ghcr.io/aahsnr-work/halcyon

      - name: Upload ISO artifact
        uses: actions/upload-artifact@v4
        with:
          name: halcyon-iso
          path: halcyon.iso
          if-no-files-found: error
```

⚠VERIFY on first run: `generate-iso` (JasonN3/build-container-installer under the hood; docs https://blue-build.org/how-to/generate-iso/) needs rootful podman on the runner; if GitHub-hosted runners refuse, document the local command (`sudo bluebuild generate-iso --iso-name halcyon.iso image ghcr.io/aahsnr-work/halcyon`, or `recipe recipes/halcyon.yml` offline) in README instead of failing silently. ISOs exceed GitHub Releases' free hosting (template README) → artifact + external-hosting note. (This file is part of the deliverable but is only committed/pushed by the USER.)

### 8.3 Signing — already configured (cosign.pub committed; SIGNING_SECRET set). The signing module expects the CLI-placed `/etc/pki/containers/aahsnr-work_halcyon.pub` and writes `/etc/containers/policy.json` + registries.d (§1.19j). README rebase flow: `rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest` → reboot → `rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest` → reboot. Verification: `cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon`. Secure Boot section covers both states (base's ublue akmods NVIDIA modules need the ublue MOK key enrolled under SB — link Bazzite's Secure Boot docs).

---

## 9. README.md must cover

Identity + base/tag policy (`latest`); **removed** (GNOME core+apps+extensions incl. the 12 directory-installed ones, SDDM→greetd, gdm, handheld/jupiter/steamdeck/powerstation/inputplumber/powerbuttond/sdgyrodsu/vpower/galileo-mura/hid-replay set, waydroid, firefox RPM+flatpak, fastfetch/bling stack incl. `bazzite-neofetch.sh`, base flatpak app set at runtime (minus Flatseal/DistroShelf), base font RPMs) and **kept** (§1.12 list — explicitly: steamos-manager + scx packages, steam/umu/gamescope(+session)/gamemode/mangohud/lutris/bazaar/portal/bbrew, usbip/xwiimote-ng/evtest/ydotool/input-remapper + the `install-openrazer` ujust recipe, distrobox/podman, DistroShelf flatpak + its skel preconfig + `distroshelf-helper`, nvidia flatpak-runtime sync + nvctk-cdi, base repo files untouched); **added** (hyprland-git/noctalia-git/hyprpolkitagent via lionheartp COPR — unscoped installs with provenance guard, COPR file purged post-install; greetd+tuigreet (user `greetd`, `/var/cache/tuigreet`); portals; code/brave-browser/brave-origin/zen-browser/zed/emacs-pgtk with full repo cleanup incl. terra enable→install→re-disable; obsidian/zotero/pyprland/texlive build-time bakes; DistroShelf + Flatseal + OnlyOffice + Bitwarden + TickTick as first-boot system flatpaks; nix stack à la winter; 21 brew formulas at first login via halcyon.Brewfile + user service; chezmoi→aahsnr-configs/dots `replace`; doom-setup + home-manager-setup ujust recipes; fconf/fe in /usr/libexec/halcyon-image on PATH); flatpak policy (v1 remove+install lists; fedora remotes exist-disabled by base design; manager kept); sched_ext status (§1.4 + scxctl + BORE caveat); XDG-autostart caveat (Hyprland doesn't run /etc/xdg/autostart natively — Steam autostart entry kept; user's hyprland conf should `exec-once` Steam or rely on Noctalia); no terminal baked after GNOME removal (user-managed apps — flagged); the **`--repoid` trap** (§1.21) so future edits never reintroduce `repo:`-scoped installs; **all §11 deviations**; signing/verification/rebase/ISO/Secure Boot; credits — Universal Blue & Bazzite (Apache-2.0), BlueBuild, fu5ha/winter (Apache-2.0), lionheartp/Hyprland COPR, noctalia-shell, DistroShelf, JasonN3/build-container-installer; `TODO(user)` inventory.

---

## 10. QA checklist (static + optional local build; record results in delivery notes/README)

**Static (always, files-only mode):**
1. YAML validity: every `recipes/**/*.yml` parses; schema headers present; `from-file` targets exist; module order in `halcyon.yml` = removals → … → signing.
2. Grep gate: **zero `repo:` keys under any dnf `install:`/`builddep:`/`replace:` block** (§1.21); every dnf install/group-install/replace block carries `install-weak-deps: false`; every script module is `script@v1`; every repo-adding dnf module has `repos.cleanup: true`.
3. Verbatim assets byte-identical to §6 (diff against this prompt).
4. `files/dnf/vscode.repo`, `files/system/**` paths match §3.4 tree; `fconf`/`fe` mode 0755; units parse (`systemd-analyze verify` if available).
5. Existing files untouched: build.yml, dependabot.yml, .gitignore, cosign.pub (diff against §3).

**If a local `bluebuild build recipes/halcyon.yml` is possible (podman):**
6. Inventory log `/tmp/halcyon-inventory.txt` captured.
7. `dnf -q repoquery --unsatisfied` → empty.
8. Absent: `rpm -qa | grep -Ei 'gnome-shell|^gdm|sddm|waydroid|firefox|fastfetch|inputplumber|powerstation|jupiter-|steamdeck-|galileo|powerbuttond|sdgyrodsu|vpower|ptyxis|nautilus'` → empty (log deliberate keeps: steamos-manager, gamescope-session*).
9. Present: `rpm -q hyprland-git noctalia-git hyprpolkitagent greetd greetd-tuigreet xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6-qtwayland code brave-browser zen-browser zed emacs-pgtk nix nix-daemon chezmoi perl jq python3 distroshelf-helper` (brave-origin: log if skip-unavailable triggered); `ldd /usr/bin/Hyprland` clean; provenance guard output shows hypr* libs from the lionheartp COPR.
10. Repos: `dnf5 repolist --enabled` = fedora, updates, `_copr_ublue-os-akmods` (+base-enabled only); no brave/code/zen/lionheartp/terra; `/etc/yum.repos.d/` free of brave/vscode files and `_copr_lionheartp*`/`_copr_sneexy*`; base repo files still present & disabled.
11. `/usr/lib/opt/brave.com` (+ tmpfiles entry) exists; `brave --version` runs.
12. `/usr/share/gnome-shell/extensions` absent; the 5 `zz0-*-silverblue-*.gschema.override` absent; dconf distro.d bazzite files absent; gschema db recompiles clean.
13. Fonts: only protected/fallback RPMs remain; `fc-list | grep -i jetbrains` + Noto Emoji present.
14. Brew: `/usr/share/homebrew.tar.zst` untouched; both Brewfiles present (halcyon = 21 lines); `halcyon-brew-bundle.service` installed.
15. Helpers: `/usr/libexec/halcyon-image/{fconf,fe}` 0755; `/etc/profile.d/halcyon-path.sh`; `60-custom.just` imports both custom justfiles; pruned justfiles + import lines gone; `82-bazzite-apps.just`/`94-bazzite-protonplus.just`/`95-bazzite-nvidia.just` present; `80-bazzite.just` bling-free.
16. Units: greetd enabled; masked: sddm, gdm, bazzite-autologin, nvidia-persistenced, nvidia-powerd; enabled: brew-setup, bazzite-flatpak-manager, nix-daemon, var-nix, nix.mount, steamos-manager (+3 `--global` user units), ublue-nvidia-flatpak-runtime-sync/-verify, ublue-nvctk-cdi; `--global` enabled: pyprland.service, halcyon-brew-bundle.service, chezmoi-init.service, chezmoi-update.timer; no dangling wants symlinks.
17. Bakes: obsidian/zotero/pyprland/texlive artifacts per §5.8 verification; gcc absent; perl/python3/jq present.
18. Login: `/etc/greetd/config.toml` has `user = "greetd"`; `id greetd`; `/var/cache/tuigreet` tmpfiles entry; `/usr/share/wayland-sessions/` has hyprland.desktop + gamescope-session entries; `/etc/xdg/autostart/steam.desktop` kept; `/etc/sddm.conf.d` absent.
19. default-flatpaks@v1: `/usr/share/bluebuild/default-flatpaks/system/{install,remove}` match §5.5 (install INCLUDES com.ranfdev.DistroShelf; remove EXCLUDES it and Flatseal); `system-flatpak-setup.timer` + `user-flatpak-setup.timer` enabled; Flathub ID validation passed in build log.
20. Branding: `/etc/os-release` PRETTY_NAME=halcyon (ID untouched); plymouth theme; motd/backgrounds placeholders.
21. Signing: `/etc/pki/containers/aahsnr-work_halcyon.pub`, `/etc/containers/policy.json`, registries.d entry.
22. No stage leftovers: `rpm -q rust cargo meson` → absent (no stage exists in v4).

**First boot (user acceptance, post-publish):** tuigreet → Hyprland → Noctalia wizard; DistroShelf + the 4 flatpaks installed (notification), base flatpak set removed; `brew list` shows 21 formulas after `halcyon-brew-bundle`; chezmoi applied dots; `ujust` lists doom-setup/home-manager-setup (+ install-openrazer etc.); Steam launches on NVIDIA; gamescope-session selectable; pyprland user service active; nix works.

---

## 11. Mandatory documented deviations (README + delivery notes)

1. **`gnome-extensions` module NOT used** (user originally requested): it hard-requires `gnome-shell --version` at build time (source-verified) and its README defers PM-installed extensions to the PM. Bazzite's extensions are RPMs (→ dnf remove) or build-script directories (→ `rm -rf` + gschema recompile). Intent — zero GNOME extensions — fully achieved.
2. **Terra not added/removed by halcyon** (T17 assumed we add it): terra repo files are pre-baked (disabled) in the base. zed installs via scripted enable→unscoped-install→re-disable; base repo state ends exactly as found. All repos halcyon DOES add are cleaned (files deleted; COPRs disabled **and their repo files explicitly deleted**).
3. **Flatpak removal happens at first boot, not build time:** flatpak state lives in `/var` (outside OSTree commits); no build-time flatpak module exists; `default-flatpaks@v1 remove:` is the supported idempotent mechanism.
4. **`install-weak-deps: false` added to the winter-verbatim nix dnf block** (user constraint overrides byte-verbatim replication).
5. **`fedora` flatpak remotes left in place (disabled):** base design; optional drop-in §7.6 removes them entirely if preferred.
6. **`default-flatpaks@v1` instead of the user's v2-style config:** v2 lacks `remove:` (TypeSpec-verified) and v1/v2 can't coexist; v1 preserves the exact intent (system scope, notify, Flathub default, same installs) + removals. The empty duplicate configuration in the original TODO (template leftover) stays dropped.
7. **Removals split dnf-module vs guarded scripts:** the dnf module hard-fails on missing packages (§1.19c); several named targets are provably absent (hhd, decky-loader, bluebubbles, jupiter-sd-mounting-btrfs, ds-inhibit) and compose-dependent GNOME apps vary by Fedora generation. Confirmed-present → declarative module; uncertain → rpm-q-filtered scripts + hard verification. Removals still run FIRST.
8. **`steamos-manager` KEPT** (only `-powerstation` removed): it's the base's scx/TDP manager, which the sched_ext requirement says to keep when present; stale `desktop = "gnome.desktop"` sed-patched to `hyprland.desktop`.
9. **`type: script@v1` pinned everywhere:** bare `script` defaults to v2 whose snippets run under `/bin/sh` (source-verified); all halcyon snippets are bash.
10. **greetd `user = "greetd"`** (not upstream's `greeter`): Fedora packaging seds the username — spec-verified; using `greeter` would break login.
11. **`repo:`-scoped dnf installs banned** (user-reported `--repoid` dependency-confinement trap, §1.21): all installs are unscoped plain names with repos enabled for the whole transaction; provenance verified post-install via `repoquery --qf '%{reponame}'`. This supersedes v2/v3's repo-scoped blocks.
12. **DistroShelf delivered as system Flatpak** (v4 user directive; supersedes the earlier stage-built-RPM decision): stage + `specs/distroshelf.spec` removed from the project; base skel preconfig + `distroshelf-helper` + `mineapps.list` retained; `com.ranfdev.DistroShelf` added to the default-flatpaks@v1 install list and dropped from its remove list.

---

## 12. Deliverables (files only — NO git push, NO PRs, NO GHCR writes)

1. The complete new-file tree of §3.4 in the local working copy of `aahsnr-work/halcyon`, all §4–§8 content committed-ready (verbatim assets byte-exact), existing §3.1–3.3 files untouched.
2. Static QA report per §10 items 1–5 (+ 6–22 if a local build was possible), recorded in delivery notes.
3. `README.md` per §9 and a `NOTES.md` (or README section) with the exact removed-vs-kept package table + all §11 deviations + every variance discovered between §1 facts and the actual base image at build time (Step A inventory diffs) — for the user's follow-up work ("integrate the bazzite setup on top of my own shell setup").

**End of prompt v4.**
