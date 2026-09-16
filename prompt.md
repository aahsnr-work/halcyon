# PROMPT — Build "halcyon": A Custom Bazzite Fork Using the BlueBuild Template

> **Audience of this prompt:** an AI coding agent (or engineer) with shell access, internet access, and a GitHub account context for `aahsnr-work`.
> **Generated:** 2026-09-16. All facts below were verified against live sources on this date (BlueBuild docs/template, Bazzite repo & GHCR, COPR pages, fu5ha/winter repo, ublue-os/brew Containerfile). Volatile facts (package versions, tags, module schemas) MUST be re-verified at implementation time — instructions for doing so are included.
> **Self-contained:** every script, justfile, unit file and config the user supplied is embedded verbatim in §7 below — no external files are required to execute this prompt.

---

## 0. Mission

Create a GitHub repository **`aahsnr-work/halcyon`** from the template **https://github.com/blue-build/template** ("Use this template"), and implement a custom Fedora Atomic (bootc/OSTree) image named **halcyon**, published to **`ghcr.io/aahsnr-work/halcyon`**.

halcyon is a **true Bazzite fork**:

- **Base image:** `ghcr.io/ublue-os/bazzite-gnome-nvidia-open`, tag **`latest`** (Fedora 44-generation as of Sep 2026; verified actively built, cosign-signed).
- **Identity:** a lean, desktop-PC gaming image for **Intel CPU + NVIDIA GPU (nvidia-open drivers, inherited from base)** that **replaces GNOME with Hyprland + Noctalia shell**, strips handheld/Steam-Deck/Android bloat, and layers the user's personal toolchain (Nix, Homebrew formulas, chezmoi dotfiles, custom justfiles, baked apps).
- **Build system:** BlueBuild CLI + `blue-build/github-action` (v1.11+) in GitHub Actions, cosign-signed, single recipe, multi-file module layout.

Do NOT fork/modify the Bazzite repository itself; all customization happens declaratively through BlueBuild recipe modules on top of Bazzite's published image.

---

## 1. Non-negotiable global constraints

1. **Recipe file:** `recipes/halcyon.yml` — and `.github/workflows/build.yml` matrix updated from `recipe.yml` to `halcyon.yml`.
2. **Multi-file layout:** `halcyon.yml` must be a thin top-level file whose `modules:` list is entirely `from-file:` includes pointing at YAML files in **`recipes/modules/`** (pattern proven by `fu5ha/winter`: `recipes/winter.yaml` + `recipes/modules/*.yaml`). No monolithic recipe.
3. **Removals first:** the FIRST module file executed must perform all dnf package removals (bloat/GNOME/fonts), before any installs.
4. **`install-weak-deps: false`** on EVERY `dnf` module `install:` / `group-install:` / `replace:` block, everywhere, always.
5. **Repo hygiene:** every repo/COPR/key added for an install (lionheartp/Hyprland COPR, sneexy/zen-browser COPR, Microsoft VSCode repo, Brave repo, Terra repo) must be removed immediately after its packages are installed — use the `dnf` module's `repos: cleanup: true` (verified feature: "Cleans up the repos added in the same step after packages are installed"). After the build, `/etc/yum.repos.d/` must contain no third-party repos.
6. **No script-based installs for vscode/brave/zen/zed:** these MUST be installed through the `dnf` module (declarative repos + packages), not shell snippets.
7. **`/opt` handling:** BlueBuild CLI **≥ v0.9.23** handles `/opt`-installing RPMs automatically (the `optfix` option is deprecated/no-op; rpm-ostree relocates `/opt` content to `/usr/lib/opt` with per-package `tmpfiles.d` symlinks — see coreos/rpm-ostree#233). Ensure the build uses a current CLI (template default `latest-installer`), install `/opt`-based apps (brave) via the dnf module, then **verify** `/usr/lib/opt/` contents and matching `/usr/lib/tmpfiles.d/` entries exist in the built image.
8. **Architecture:** `linux/amd64` only (set `platforms: ["linux/amd64"]` explicitly or rely on the amd64 runner; do not build arm64).
9. **Signing:** KEEP the `signing` module. The base image's signature does not transfer to derived images; halcyon needs its own cosign keypair so users can rebase via `ostree-image-signed:`.
10. **Do not use** the `initramfs` module (base Bazzite ships a working initramfs; the module is only for custom dracut args) and **do not use** the `akmods` module (nvidia-open kmods are already in the base image).
11. Everything the user marked "I will add/modify later" (personal shell setup, dotfile contents, extra helper scripts, branding assets) must be left as clearly-marked, functional placeholders — never invented content.

---

## 2. Repository bootstrap

1. Create `aahsnr-work/halcyon` from `blue-build/template` (GitHub → "Use this template"). Keep the template's `.github/` folder **as-is** (including `build.yml`'s stock triggers/schedule: cron `00 06 * * *` daily at 06:00 UTC, push with `paths-ignore: **.md`, `pull_request`, `workflow_dispatch`, concurrency group, `blue-build/github-action@v1.11`, `maximize_build_space: true`) — only edit the matrix recipe name (constraint #1).
2. Generate a NEW cosign keypair (do not keep the template's `cosign.pub`):
   ```bash
   cosign generate-key-pair   # or: podman run --rm ghcr.io/blue-build/cli:latest-installer generate-key-pair
   ```
   - Commit the public key as `cosign.pub` (repo root, overwriting the template's).
   - Store the private key as repo secret **`SIGNING_SECRET`** (Settings → Secrets and variables → Actions).
3. Keep `.gitignore` as shipped (the template already ignores generated ISO/checksum files since Jun 2026).
4. Set the GHCR package to public after first successful push (or document the `packages: write` + visibility steps in README).

Final repo layout to implement:

```
halcyon/
├── .github/workflows/
│   ├── build.yml            # template stock, matrix → halcyon.yml
│   └── build-iso.yml        # NEW — single-image ISO workflow (§8)
├── cosign.pub               # halcyon's own key
├── recipes/
│   ├── halcyon.yml          # thin top-level recipe (§4)
│   └── modules/             # all module config files (§5)
│       ├── halcyon-removals.yml
│       ├── halcyon-desktop.yml
│       ├── halcyon-apps.yml
│       ├── halcyon-fonts.yml
│       ├── halcyon-flatpaks.yml
│       ├── halcyon-nix.yml
│       ├── halcyon-brew.yml
│       ├── halcyon-distroshelf.yml
│       ├── halcyon-build-scripts.yml
│       ├── halcyon-files.yml
│       ├── halcyon-services.yml
│       └── halcyon-branding.yml
├── files/
│   ├── dnf/                 # vscode.repo, terra repo file (§5.3)
│   ├── justfiles/           # doom-setup.just, home-manager-setup.just (§7.2)
│   ├── nix-profile/         # 00-nix-resolve-home-env.sh (§7.4)
│   ├── nix-tmpfiles/        # nix.conf (§7.4)
│   ├── scripts/             # install-{obsidian,zotero,pyprland,texlive}.sh (§7.3) + build-time helpers
│   ├── systemd/
│   │   ├── system/          # greetd drop-ins if needed
│   │   └── user/            # (pyprland.service is created by install-pyprland.sh; see §5.9)
│   └── system/              # copied to image / by the files module (§5.10)
│       ├── etc/
│       │   ├── greetd/config.toml
│       │   ├── profile.d/halcyon.sh
│       │   └── motd.d/halcyon-motd.txt
│       └── usr/
│           ├── libexec/halcyon-image/{fconf,fe}   # §7.1, no .sh extension, executable
│           ├── share/plymouth/themes/halcyon/     # branding placeholders (§5.12)
│           └── share/backgrounds/halcyon/         # branding placeholders (§5.12)
├── specs/distroshelf.spec   # §6
├── README.md                # §9
└── LICENSE                  # keep template's (Apache-2.0)
```

---

## 3. Verified environment facts (re-verify before building)

| Fact | Value (verified 2026-09-16) |
|---|---|
| Base image | `ghcr.io/ublue-os/bazzite-gnome-nvidia-open` — published ~1h before verification; tags include `latest`, `stable`, `gts`, `testing`, `testing-44`, versioned (`44`, `stable-44` …); cosign `.sig` tags present |
| Fedora generation | Base `latest` tracks the newest Fedora (F44 as of Sep 2026); use `dnf5` syntax assumptions (BlueBuild `dnf` module is dnf5-based) |
| Hyprland COPR | `lionheartp/Hyprland` (Project ID 205252). `hyprland-git` 0.56.2^56.git92b82c0-1; `noctalia-git` 5.1.0^7.9f35ead-1; 56 companion packages (aquamarine, glaze, hyprgraphics, hyprlang, hyprcursor, hyprland-protocols, hyprland-qt-support, hyprqt6engine, hyprpolkitagent, hyprlock, hypridle, hyprpaper, hyprpicker, cliphist, gpu-screen-recorder, awww, noctalia-hyprland-meta …); chroots fedora-43/44/45/rawhide, x86_64+aarch64 |
| ⚠ COPR pitfall | Do NOT mix `hyprland-git` with *stable* companion libs (documented hyprgraphics/hyprlang/hyprpaper ABI breakage, Fedora Discussion Nov 2025). Install the -git stack as one transaction from the COPR and verify library consistency afterwards |
| Zen COPR | `sneexy/zen-browser` exists; package `zen-browser` |
| Bazzite tooling in base | `ujust` (justfiles module appends imports to `/usr/share/ublue-os/just/60-custom.just`); Homebrew via ublue-os/brew mechanism: **bare brew** tarball at `/usr/share/homebrew.tar.zst` + `brew-setup.service` extracts to `/home/linuxbrew/.linuxbrew` on first boot (NO formulae baked — verify exact path in base with `ls /usr/share/homebrew*` and `systemctl cat brew-setup.service`); Bazzite Portal (RPM); Bazaar (**user states it is an RPM in the base**, not a flatpak — verify `rpm -q bazaar`; if a flatpak Bazaar is ever found, re-add `io.github.kolunmi.bazaar` to default-flatpaks to honor the "keep Bazaar" requirement); patched Steam RPM; umu-launcher; gamescope + gamescope-session; Lutris as RPM |
| sched_ext/BORE | Presence of scx packages in the base could NOT be confirmed via web research → detect at build time (§5.1 step 0). BORE is a CachyOS kernel patch and is NOT available on Fedora kernels; nearest equivalent is `scx_bppland`. If base has scx tooling: keep it and document `scxctl` usage; if not: no-op (per user's conditional requirement) |
| `/opt` on atomic | Handled automatically by rpm-ostree + BlueBuild CLI ≥ v0.9.23 (see constraint #7) |
| winter nix setup | `fu5ha/winter` (Apache-2.0), based on `ghcr.io/ublue-os/bazzite-nvidia-open` `stable-44`: dnf `nix`+`nix-daemon`, systemd `var-nix.service` + `nix.mount` + `nix-daemon`, tmpfiles `nix.conf`, profile.d script — full contents embedded in §7.4 |

---

## 4. `recipes/halcyon.yml` (top-level recipe)

```yaml
---
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
# image will be published to ghcr.io/aahsnr-work/halcyon
name: halcyon
description: >-
  A lean Hyprland gaming desktop forked from Bazzite (GNOME removed,
  Hyprland + Noctalia shell, NVIDIA open drivers, curated tooling).

base-image: ghcr.io/ublue-os/bazzite-gnome-nvidia-open
image-version: latest
platforms:
  - linux/amd64

labels:
  halcyon.base: bazzite-gnome-nvidia-open
  halcyon.desktop: hyprland-noctalia

stages:
  - name: distroshelf
    from: docker.io/library/fedora:latest   # pin to the Fedora generation matching base `latest` at build time (e.g. fedora:44)
    modules:
      - type: script
        snippets:
          - |
            set -euxo pipefail
            dnf install -y dnf-plugins-core rpm-build rust cargo meson ninja-build gcc gcc-c++ git curl \
              gtk4-devel libadwaita-devel desktop-file-utils appstream gettext
            mkdir -p /root/rpmbuild/{SPECS,SOURCES,BUILD,RPMS,SRPMS}
          - |
            set -euxo pipefail
            # PINNED RELEASE TAG — bump deliberately:
            DS_VERSION="${DS_VERSION:-0.5.2}"
            curl -fLsS --retry 5 -o /root/rpmbuild/SOURCES/distroshelf-"${DS_VERSION}".tar.gz \
              "https://github.com/ranfdev/DistroShelf/archive/refs/tags/v${DS_VERSION}.tar.gz"
            cp /tmp/files/../specs/distroshelf.spec /root/rpmbuild/SPECS/ 2>/dev/null || true
          - |
            set -euxo pipefail
            # NOTE: the spec is provided via the repo's specs/ directory. If $CONFIG_DIRECTORY
            # is unavailable inside stages, inline the spec with a heredoc (see §6 for full spec).
            cp "${CONFIG_DIRECTORY:-/tmp/files}/../specs/distroshelf.spec" /root/rpmbuild/SPECS/ || true
            rpmbuild -bb /root/rpmbuild/SPECS/distroshelf.spec
            mkdir -p /out
            find /root/rpmbuild/RPMS -name 'distroshelf-*.rpm' -exec cp {} /out/ \;
            test -n "$(ls -A /out)"

modules:
  # --- order is significant: removals FIRST, installs after, services last ---
  - from-file: modules/halcyon-removals.yml
  - from-file: modules/halcyon-desktop.yml
  - from-file: modules/halcyon-apps.yml
  - from-file: modules/halcyon-fonts.yml
  - from-file: modules/halcyon-flatpaks.yml
  - from-file: modules/halcyon-nix.yml
  - from-file: modules/halcyon-brew.yml
  - from-file: modules/halcyon-distroshelf.yml
  - from-file: modules/halcyon-build-scripts.yml
  - from-file: modules/halcyon-files.yml
  - from-file: modules/halcyon-services.yml
  - from-file: modules/halcyon-branding.yml
  - type: signing
```

> Verify the exact `from-file` semantics (paths relative to `recipes/`) against https://blue-build.org/how-to/multiple-files/ and the `stages`/`copy` module reference (https://blue-build.org/reference/stages/, https://blue-build.org/reference/modules/copy/) before committing. If the spec cannot be reached inside the stage via `$CONFIG_DIRECTORY`, inline the §6 spec into the stage snippet with a heredoc — the stage must end with the RPM in `/out/`.

---

## 5. Module files (`recipes/modules/*.yml`) — contents & intent

Each file starts with:
```yaml
---
# yaml-language-server: $schema=https://schema.blue-build.org/module-list-v1.json
```

Before writing any module config, **verify the current schema** of each module at `https://blue-build.org/reference/modules/<name>/` (dnf, flatpaks, default-flatpaks, fonts, nix-adjacent units, chezmoi, justfiles, systemd, files, script, copy, gnome-extensions, signing). Schemas below were verified on 2026-09-16 unless flagged "verify".

### 5.0 Step zero (inside `halcyon-removals.yml`, first script snippet) — inventory & detection

Run a script module FIRST that records (to build log) and acts on:

1. `rpm -qa | grep -Ei 'gnome|jupiter|steamdeck|waydroid|bluebubbles|decky|powerstation|hhd|inputplumber|firefox|zsh|starship|fastfetch' | sort` — the actual removal candidates present in this base variant.
2. `rpm -qa '*fonts*' | sort` — installed font packages.
3. `flatpak list --app --system --columns=application` and `flatpak remotes -d --show-details` — base flatpaks + remotes (**verify presence/absence of a `fedora` flatpak remote** — user requirement T7; remove it if present, keep `flathub`).
4. `rpm -q bazaar bazzite-portal` — confirm Bazaar/Portal are RPMs (expected: yes).
5. `rpm -q scx-scheds scx_loader scx-schedsc 2>/dev/null; ls /usr/bin/scx* 2>/dev/null` — sched_ext detection (see §3).
6. `ls /usr/share/homebrew* ; systemctl cat brew-setup.service` — confirm brew tarball path & service name for §5.7.
7. `grep -E '^(NAME|SHELL)' /etc/passwd ; echo $SHELL ; ls /etc/skel` — confirm default shell is bash and locate bazzite zsh/skel customizations to purge.

### 5.1 `halcyon-removals.yml` — REMOVE (runs before any install)

Use `type: dnf` with `remove:` (set `auto-remove: true` for the GNOME sweep so orphaned deps go too; use `skip-unavailable: true` so the build never fails on packages absent from this variant). Removal groups (enumerate from §5.0 inventory; the list below is the required target set):

- **GNOME (per requirement: Hyprland is the only session):** `gnome-shell`, `gdm`, `mutter`, `gnome-session`, `gnome-session-wayland-session`, `gnome-classic-session*`, `gnome-shell-extension-*` (all), `nautilus`, `gnome-terminal`, `gnome-text-editor`, `gnome-console`, `gnome-software*`, `gnome-tour`, `gnome-initial-setup`, `yelp`, `loupe`, `totem`, `snapshot`, `evince`, `gnome-calculator`, `gnome-calendar`, `gnome-characters`, `gnome-clocks`, `gnome-connections`, `gnome-contacts`, `gnome-font-viewer`, `gnome-logs`, `gnome-maps`, `gnome-remote-desktop`, `gnome-system-monitor`, `gnome-weather`, `baobab`, `simple-scan`, `xdg-desktop-portal-gnome`, `gjs`, `adwaita-cursor-theme` — **KEEP** (do not remove): `gsettings-desktop-schemas`, `dconf`, `gtk3`, `gtk4`, `adwaita-icon-theme*`, `gnome-themes-extra`, `pipewire*`, `wireplumber`, `xdg-desktop-portal` (core), `udisks2`, `NetworkManager*`, `polkit*`. Adjust against the §5.0 inventory; never remove anything that a KEEP package or Steam/gamescope depends on (`dnf repoquery --installed --whatrequires <pkg>` before each ambiguous removal).
- **GNOME extensions (user requirement):** for extensions installed **as RPMs**, removal happens via the dnf list above (`gnome-shell-extension-*`). Additionally include the blue-build **`gnome-extensions`** module with `uninstall:` entries for any extension directories NOT owned by an RPM (found via: `find /usr/share/gnome-shell/extensions -maxdepth 1 -mindepth 1 | while read -r d; do rpm -qf "$d" >/dev/null 2>&1 || echo "$d"; done`). Extension names are case-sensitive (module README: https://github.com/blue-build/modules/tree/main/modules/gnome-extensions). **Verify the exact `uninstall:` schema key** in the module docs before writing. Then, via script module, purge stale dconf/gsettings state: `dconf reset -f /org/gnome/shell/` equivalents baked as `/etc/dconf` db overrides removal — i.e., delete bazzite GNOME dconf override files under `/etc/dconf/db/` referencing removed extensions and re-run `dconf update` if the db directory still exists.
- **Handheld/Deck (remove everything jupiter/steamdeck related EXCEPT keep gamescope + gamescope-session):** `decky-loader` (any package name form, e.g. `decky`), `bazzite-powerstation`/`powerstation`, `hhd`, `hhd-ui`, `inputplumber`, `jupiter-theme`, `jupiter-hw-support*`, `steamdeck*` (e.g. `steamdeck-dsp`, `steamdeck-gamescope` deck configs) — from inventory. **Verify** `gamescope-session*` packages survive: `rpm -q gamescope gamescope-session` after removal; if a gamescope-session package hard-requires `gdm` or `gnome-shell`, prefer keeping the minimal gdm-less path working: gamescope sessions must remain launchable via greetd/tuigreet session picker (see §5.2) — document any trade-off in README. Do NOT remove `gamescope`, `steam`, `steam-devices*`, `xpadneo*`, `openrazer*`, `oversteer`, controller/udev packages (USB peripherals explicitly kept).
- **Android/iMessage:** `waydroid*` (+ script cleanup: `rm -rf /var/lib/waydroid /usr/share/waydroid* /etc/waydroid*`, disable/mask leftover units), `bluebubbles*` (+ units).
- **Browser:** `firefox`, `firefox-langpacks`, `mozilla-filesystem` (only if nothing else requires it) — removed entirely, NO replacement browser here (browsers are installed in §5.3 per explicit user choice).
- **Shell customization (user will bring their own):** `zsh`, `zsh-*`, `starship`, `fastfetch`, `neofetch` (RPMs added by bazzite, if present) + script cleanup of `/etc/skel/.zshrc`, `/etc/skel/.config/zsh`, `/etc/skel/.config/fastfetch`, `/etc/skel/.config/starship.toml`, bazzite zsh/bash theming files under `/etc/skel` and `/usr/share/bazzite*` shell bits; ensure default user shell remains `/bin/bash` (`grep -q '/bin/bash' /etc/default/useradd || sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd`).
- **Fonts (safe removal):** script-driven: for every package from `rpm -qa '*fonts*'`, check reverse deps (`dnf repoquery --installed --whatrequires "$p"`); remove only those with no remaining requirers (excluding other removable font packages); NEVER remove `fontconfig*`, `fontpackages-filesystem`, or fonts required by kept packages (qt6-*, gtk3/gtk4, steam, noctalia). Log kept/removed lists. The replacement fonts arrive in §5.4.
- **Prune broken ujust recipes:** script module scanning `/usr/share/ublue-os/just/*.just` for recipes invoking removed components (waydroid, decky, hhd, powerstation, gnome/gdm, firefox, jupiter/steamdeck); delete those recipe files or comment out the affected recipes (keep everything else, including brew/distrotbx/gaming recipes). Log every pruned file.

### 5.2 `halcyon-desktop.yml` — Hyprland + Noctalia + greetd (ADD)

```yaml
modules:
  # Hyprland -git stack + Noctalia from COPR lionheartp/Hyprland (single transaction,
  # COPR-pinned so the -git stack stays internally consistent; repo removed after: cleanup)
  - type: dnf
    repos:
      cleanup: true
      copr:
        - lionheartp/Hyprland
    install:
      install-weak-deps: false
      packages:
        - repo: copr:copr.fedorainfracloud.org:lionheartp:Hyprland
          packages:
            - hyprland-git
            - noctalia-git
            - hyprpolkitagent
        # functional plumbing (user maintains their own app list elsewhere):
        - greetd
        - greetd-tuigreet
        - xdg-desktop-portal-hyprland
        - xdg-desktop-portal-gtk
        - qt6-qtwayland
        - hyprland-qt-support   # if not auto-pulled by noctalia-git; skip-unavailable guard ok

  # Post-install consistency check (-git pitfall guard)
  - type: script
    snippets:
      - |
        set -euo pipefail
        # Ensure the hypr* library stack resolves to a single consistent ABI set
        rpm -q hyprland-git hyprgraphics hyprlang aquamarine hyprcursor
        ldd /usr/bin/Hyprland | grep -i 'not found' && { echo 'BROKEN hyprland deps'; exit 1; } || true
        test -f /usr/share/wayland-sessions/hyprland.desktop
```

- greetd config: `files/system/etc/greetd/config.toml` (§5.10 copies it) with tuigreet launching Hyprland and offering session selection:
  ```toml
  [terminal]
  vt = 1

  [general]
  source_profile = true

  [default_session]
  command = "tuigreet --time --remember --remember-user-session --asterisks --sessions /usr/share/wayland-sessions --cmd Hyprland"
  user = "greeter"
  ```
- `greetd.service` enabled in §5.11. Ensure `/etc/greetd/config.toml` greeter user exists (`greetd` RPM creates it) and that removing `gdm` did not remove `greetd` deps.
- Noctalia first-run: noctalia-git provides the shell; on first login its setup wizard creates `~/.config/hypr` config. Do NOT bake user-level hyprland configs (user's chezmoi dots own those). Optionally ship a minimal `/etc/skel/.config/hypr/hyprland.conf` that just launches noctalia — mark it `# TODO(user)` and keep it ≤10 lines.
- sched_ext (conditional, per §3): if detected in base, leave packages in place and add a README section documenting `scxctl`/`scx_loader` usage + the BORE caveat; do not install anything new.

### 5.3 `halcyon-apps.yml` — browsers/editors via dnf module (repos cleaned up after)

Create `files/dnf/vscode.repo` (verbatim from the user's official-instructions translation):

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

Create `files/dnf/terra.repo` — download the current Terra repo file from https://terra.fyralabs.com (installation section) at implementation time (Fyra Labs repos host; commonly `https://repos.fyralabs.com/terra-release/terra-release.repo` — **verify URL** before committing).

```yaml
modules:
  - type: dnf
    repos:
      cleanup: true
      files:
        - vscode.repo          # resolved from files/dnf/vscode.repo
        - terra.repo           # resolved from files/dnf/terra.repo
        - https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
      keys:
        - https://packages.microsoft.com/keys/microsoft.asc
        - https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
      copr:
        - sneexy/zen-browser
    install:
      install-weak-deps: false
      skip-unavailable: true    # guards brave-origin availability per release
      packages:
        - repo: code
          packages:
            - code
        - repo: brave-browser
          packages:
            - brave-browser
            - brave-origin
        - repo: copr:copr.fedorainfracloud.org:sneexy:zen-browser
          packages:
            - zen-browser
        - repo: terra
          packages:
            - zed
        # Fedora official repo (no extra repo needed):
        - emacs-pgtk
        - jq                    # build-time need of §5.9 scripts; see removal note below

  # emacs-pgtk is a user requirement (doom-setup justfile needs Emacs on PATH).
  # jq is required by install-obsidian.sh/install-pyprland.sh; keep it (tiny) or
  # remove after §5.9 runs — keep by default, document choice.

  # /opt verification (constraint #7): brave installs under /opt on classic Fedora
  - type: script
    snippets:
      - |
        set -euo pipefail
        ls -d /usr/lib/opt/brave.com 2>/dev/null || ls -d /opt/brave.com 2>/dev/null || {
          echo 'ERROR: brave /opt content not relocated — check BlueBuild CLI >= v0.9.23'; exit 1; }
        ls /usr/lib/tmpfiles.d/ | grep -i brave || true
        command -v brave || command -v brave-browser
        command -v code && command -v zen-browser && command -v zed && command -v emacs
```

### 5.4 `halcyon-fonts.yml` — fonts module (verbatim user config)

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

### 5.5 `halcyon-flatpaks.yml` — strip base flatpaks, then declare defaults

```yaml
modules:
  # 1) Build-time removal of EVERY flatpak shipped in the base image (user requirement).
  #    Populate `remove:` from the §5.0 inventory (flatpak list --app --system).
  #    Also drop a `fedora` flatpak remote IF the inventory found one (T7).
  - type: flatpaks
    configurations:
      - scope: system
        notify: false
        remotes:
          remove:
            - fedora            # only if present per §5.0; delete line otherwise
        remove:
          - <EVERY app ID found in base image inventory>
  # Verify schema at https://blue-build.org/reference/modules/flatpaks/ before committing.

  # 2) First-boot installs (user config verbatim; the empty duplicate
  #    configuration from the TODO was dropped as a template leftover):
  - type: default-flatpaks
    configurations:
      - scope: system
        notify: true
        install:
          - com.github.tchx84.Flatseal
          - org.onlyoffice.desktopeditors
          - com.bitwarden.desktop
          - com.ticktick.TickTick
```

Note: `flathub` remote must exist at first boot for default-flatpaks (base provides it; if §5.0 found it missing, add it in the `flatpaks` module `remotes.add`).

### 5.6 `halcyon-nix.yml` — replicate fu5ha/winter nix setup VERBATIM (Apache-2.0; credit in README)

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
      install-weak-deps: false
      packages:
        - nix
        - nix-daemon   # nix multi-user/systemd install

  - type: systemd
    system:
      enabled:
        - nix-daemon
```

The four supporting files are embedded verbatim in §7.4 (`files/nix-tmpfiles/nix.conf`, `files/nix-profile/00-nix-resolve-home-env.sh`, `files/systemd/system/var-nix.service`, `files/systemd/system/nix.mount`). Home-Manager itself is NOT baked — it is bootstrapped post-login by the user's `home-manager-setup` justfile (§7.2) using the user's chezmoi dots.

### 5.7 `halcyon-brew.yml` — build-time bake of 21 formulas into the base brew tarball

The base's brew (ublue-os/brew mechanism) is **bare** — to guarantee the formulas exist at first login, bake them into the tarball that `brew-setup.service` extracts (mirrors how ublue-os/brew builds its tarball: non-root user, `HOME=/home/linuxbrew`, `NONINTERACTIVE=1`, `tar --zstd`):

```yaml
modules:
  - type: script
    snippets:
      - |
        set -euo pipefail
        # --- verify layout first (paths may differ slightly between bazzite builds) ---
        TARBALL="$(ls /usr/share/homebrew.tar.zst 2>/dev/null || true)"
        if [ -z "$TARBALL" ] && [ -d /usr/share/homebrew ]; then TARBALL_DIR=/usr/share/homebrew; fi
        FORMULAE="atuin bat btop bun cava chafa direnv dust eza fd fzf gnuplot lazygit pandoc pixi ripgrep starship tealdeer uv yazi zellij"

        # gcc/zstd already present in bazzite; add if missing:
        rpm -q gcc >/dev/null 2>&1 || dnf install -y gcc
        rpm -q zstd >/dev/null 2>&1 || dnf install -y zstd

        WORK="$(mktemp -d)"
        if [ -n "${TARBALL:-}" ]; then
          tar --zstd -xf "$TARBALL" -C "$WORK"        # → $WORK/home/linuxbrew/.linuxbrew
          mv "$WORK/home/linuxbrew/.linuxbrew" /home/linuxbrew_tmp_lbrew
          mkdir -p /home/linuxbrew
          mv /home/linuxbrew_tmp_lbrew /home/linuxbrew/.linuxbrew
        else
          cp -a "$TARBALL_DIR" /home/linuxbrew        # directory variant
        fi

        useradd -M -d /home/linuxbrew brewbake
        chown -R brewbake:brewbake /home/linuxbrew
        touch /.dockerenv   # same trick ublue-os/brew builder uses
        su brewbake -s /bin/bash -c "
          export HOME=/home/linuxbrew
          export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 NONINTERACTIVE=1
          /home/linuxbrew/.linuxbrew/bin/brew install $FORMULAE
          /home/linuxbrew/.linuxbrew/bin/brew cleanup -s
        "
        rm -f /.dockerenv

        # re-tar exactly like ublue-os/brew: tar of /home/linuxbrew/.linuxbrew rooted at /home
        cd /home && tar --zstd -cf /tmp/homebrew.tar.zst linuxbrew/.linuxbrew
        install -Dm0644 /tmp/homebrew.tar.zst /usr/share/homebrew.tar.zst
        # (if base used the directory variant, replace $TARBALL_DIR contents instead)
        rm -rf /home/linuxbrew /tmp/homebrew.tar.zst "$WORK"
        userdel brewbake

        # sanity: formulas must be visible inside the tarball
        tar --zstd -tf /usr/share/homebrew.tar.zst | grep -m1 'Cellar/atuin' >/dev/null
```

If the base's `brew-setup.service` expects a different tarball path/name (check §5.0 step 6), adapt the `install -D` destination accordingly. Fallback (document in README, do not implement unless build-time bake proves impossible on the runner): ship a Brewfile + oneshot service ordered `After=brew-setup.service` running `brew bundle` as UID 1000.

### 5.8 `halcyon-distroshelf.yml` — install the stage-built RPM (stage defined in §4/§6)

```yaml
modules:
  - type: copy
    from: distroshelf
    src: /out/
    dest: /tmp/distroshelf-rpms/

  - type: script
    snippets:
      - |
        set -euo pipefail
        rpm-ostree install --idempotent /tmp/distroshelf-rpms/distroshelf-*.rpm
        rm -rf /tmp/distroshelf-rpms
        rpm -q distroshelf
```

(If `copy` of a directory with glob is unsupported, copy the exact filename the stage produced — adjust stage to output a deterministic name.)

### 5.9 `halcyon-build-scripts.yml` — build-time app installers (§7.3 scripts, run in CI, results baked in)

```yaml
modules:
  - type: dnf
    install:
      install-weak-deps: false
      skip-unavailable: true
      packages: [jq, gcc, python3, python3-pip, perl]   # build/runtime needs of the four scripts

  - type: script
    snippets:
      - |
        set -euo pipefail
        bash "${CONFIG_DIRECTORY}/scripts/install-obsidian.sh"
        bash "${CONFIG_DIRECTORY}/scripts/install-zotero.sh"
        bash "${CONFIG_DIRECTORY}/scripts/install-pyprland.sh"
        bash "${CONFIG_DIRECTORY}/scripts/install-texlive.sh"
```

`$CONFIG_DIRECTORY` is the module run environment's path to the repo `files/` tree (verify per https://blue-build.org/reference/module/ — "Module run environment"; if it maps to `files/`, scripts live at `files/scripts/install-*.sh` and the paths above are correct). The four scripts are embedded verbatim in §7.3 — store them at `files/scripts/` with executable bits, unmodified.

Post-run verification snippet (same module file):
- `/usr/bin/obsidian`, `/usr/share/applications/obsidian.desktop`, `/usr/lib/obsidian/` exist.
- `/usr/bin/zotero`, `/usr/lib/zotero/distribution/policies.json` exists (DisableAppUpdate).
- `/usr/bin/pypr` symlink resolves; `/usr/lib/systemd/user/pyprland.service` installed.
- `/usr/lib/texlive` present; `/etc/profile.d/texlive.sh` present; `tlmgr` ran for latexmk+biber (warn-only per script).
- Then: `dnf remove -y gcc` ONLY if nothing else needs it (keep `python3` — the pyprland venv links to it; keep `perl` — tlmgr needs it; keep `jq` per §5.3 note). Document final decisions in README.

### 5.10 `halcyon-files.yml` — files, justfiles, chezmoi

```yaml
modules:
  - type: files
    files:
      - source: system
        destination: /          # files/system/** → /** (winter-proven pattern)

  - type: justfiles
    install: false              # `just`/ujust already in base
    validate: false
    # picks up files/justfiles/*.just → /usr/share/bluebuild/justfiles/
    # + appends imports to /usr/share/ublue-os/just/60-custom.just → visible in `ujust`

  - type: chezmoi
    repository: https://github.com/aahsnr-configs/dots
    file-conflict-policy: replace
    # installs chezmoi binary at build time; chezmoi-init.service (user unit) applies
    # the dotfiles on FIRST LOGIN; chezmoi-update.timer keeps them updated (default 1d)

  - type: script
    snippets:
      - |
        set -euo pipefail
        chmod 0755 /usr/libexec/halcyon-image/*
        # expose helpers on PATH:
        cat > /etc/profile.d/halcyon-path.sh <<'EOF'
        # halcyon helper scripts
        export PATH="/usr/libexec/halcyon-image:$PATH"
        EOF
        chmod 0644 /etc/profile.d/halcyon-path.sh
        command -v chezmoi
```

`files/system/etc/greetd/config.toml` (§5.2), `files/system/usr/libexec/halcyon-image/{fconf,fe}` (§7.1), branding placeholders (§5.12) all ride along via the `source: system → /` mapping.

### 5.11 `halcyon-services.yml` — systemd (runs AFTER build scripts so pyprland.service exists)

```yaml
modules:
  - type: systemd
    system:
      enabled:
        - greetd.service
      masked:
        - nvidia-persistenced.service
        - nvidia-powerd.service
      disabled:
        - gdm.service            # belt-and-braces; gdm RPM already removed
    user:                        # applied with systemctl --global
      enabled:
        - pyprland.service       # installed by install-pyprland.sh (§7.3)
```

Verify unit names exist before enabling/masking (`systemctl list-unit-files | grep -E 'greetd|nvidia-persistenced|nvidia-powerd|pyprland'`); if `nvidia-powerd.service` is absent from the base, keep it masked anyway (masking a nonexistent unit is safe) but note it in README.

### 5.12 `halcyon-branding.yml` — full rebrand with user-supplied-asset placeholders

```yaml
modules:
  - type: script
    snippets:
      - |
        set -euo pipefail
        # os-release rebrand (preserve VERSION_ID / ostree fields):
        sed -i \
          -e 's|^NAME=.*|NAME="halcyon"|' \
          -e 's|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Bazzite fork)"|' \
          -e 's|^HOME_URL=.*|HOME_URL="https://github.com/aahsnr-work/halcyon"|' \
          -e 's|^LOGO=.*|LOGO=halcyon|' \
          /usr/lib/os-release
        # Plymouth: text-based theme now; drop-in logo when user provides assets
        if command -v plymouth-set-default-theme >/dev/null 2>&1; then
          plymouth-set-default-theme halcyon || plymouth-set-default-theme spinner
        fi
```

Ship `files/system/usr/share/plymouth/themes/halcyon/halcyon.plymouth` + `halcyon.script` (minimal spinner/text theme; mark `# TODO(user): replace with halcyon logo assets`), empty `files/system/usr/share/backgrounds/halcyon/` with a `README.md` stating where the user drops wallpapers, and `/etc/motd.d/halcyon-motd.txt` placeholder ("Welcome to halcyon — TODO(user): motd"). Do NOT invent logos/wallpapers.

---

## 6. `specs/distroshelf.spec` (stage-built RPM; DistroShelf = GTK4 GUI for distrobox, github.com/ranfdev/DistroShelf, GPL-3.0-or-later; NO existing Fedora RPM/COPR as of Sep 2026 — hence the stage build)

```spec
# Adjust Version to the pinned release tag used by the stage (§4).
# Verify BuildRequires/%files against the project's meson.build at that tag.
Name:           distroshelf
Version:        0.5.2
Release:        1%{?dist}
Summary:        GTK4/libadwaita graphical manager for Distrobox containers
License:        GPL-3.0-or-later
URL:            https://github.com/ranfdev/DistroShelf
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  rust cargo meson ninja-build gcc gcc-c++ pkgconf-pkg-config
BuildRequires:  gtk4-devel libadwaita-devel desktop-file-utils appstream
BuildRequires:  gettext

%description
DistroShelf is a graphical interface for managing Distrobox containers:
create/manage containers, install packages, manage exported apps, open
terminal sessions, upgrade, clone and delete containers.

%prep
%autosetup -n DistroShelf-%{version}

%build
%cargo_prep
%meson
%meson_build

%install
%meson_install
%find_lang %{name} || true

%files
%{_bindir}/%{name}
%{_datadir}/applications/com.ranfdev.DistroShelf.desktop
%{_datadir}/metainfo/com.ranfdev.DistroShelf.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/com.ranfdev.DistroShelf.svg
%{_datadir}/glib-2.0/schemas/com.ranfdev.DistroShelf.gschema.xml
# expand/adjust to actual installed paths

%changelog
* Tue Sep 16 2026 halcyon build <halcyon@localhost> - 0.5.2-1
- Stage-built RPM for halcyon image (pinned release tarball)
```

---

## 7. Verbatim assets (user-provided + research — transcribe EXACTLY, do not modify)

### 7.1 `files/system/usr/libexec/halcyon-image/fconf` and `fe` (no .sh extension, mode 0755)

**`fconf`:**

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

  1. fd    - A simple, fast, and user-friendly alternative to 'find'
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
    # fd: --type f (files only), --hidden (include hidden files), . (search paths)
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

    # Check if user cancelled or didn't select a file
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

**`fe`:**

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

> These are only the first two of the user's helper scripts — the directory `files/system/usr/libexec/halcyon-image/` must stay trivially extensible (the user will add more; the files module + chmod script already handle any new file dropped in).

### 7.2 `files/justfiles/doom-setup.just` and `files/justfiles/home-manager-setup.just` (verbatim)

**`doom-setup.just`:**

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

> Note (document in README): the clone uses SSH (`git@github.com:aahsnr-configs/doom.git`) — the user's SSH agent/keys must be configured at run time. `emacs-pgtk` is baked in (§5.3); `git`, `ripgrep`, `fd` come from base/brew.

**`home-manager-setup.just`:**

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

### 7.3 Build-time installer scripts — store VERBATIM at `files/scripts/` (executed in CI, results baked into the image)

**`files/scripts/install-obsidian.sh`** — Obsidian AppImage → `/usr/lib/obsidian`, `/usr/bin/obsidian` symlink, .desktop + icon install:

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

**`files/scripts/install-zotero.sh`** — Official Zotero tarball → `/usr/lib/zotero`, launcher icon, .desktop, `/usr/bin/zotero`, `DisableAppUpdate` policy:

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

**`files/scripts/install-pyprland.sh`** — pyprland release tarball → venv at `/usr/lib/pyprland`, `pypr` CLI symlinks, systemd USER unit `pyprland.service:

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

**`files/scripts/install-texlive.sh`** — TeX Live scheme-medium → `/usr/lib/texlive`, `tlmgr install latexmk biber`, `/etc/profile.d/texlive.sh`:

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

**Transcribe these four scripts character-for-character** (exact URLs, fallback versions, trap/cleanup logic and heredocs must not drift). Runtime dependency notes: keep `python3` (pyprland venv interpreter) and `perl` (tlmgr); ensure Electron runtime deps for Obsidian exist (bazzite base ships gtk3/nss/alsa-lib — verify with `ldd /usr/lib/obsidian/obsidian | grep 'not found'`).

### 7.4 winter nix support files (verbatim from fu5ha/winter @ main, Apache-2.0 — credit required in README)

**`files/nix-tmpfiles/nix.conf`** (→ `/usr/lib/tmpfiles.d/nix.conf`):

```
# Directories needed by Nix after /var/nix is bind-mounted on /nix.
# The Fedora nix RPM creates these in the image /nix, but that content is
# hidden once nix.mount is active on an existing bootc/rpm-ostree system.
d /nix/store             1775 root nixbld - -
d /nix/var/nix           0775 root nixbld - -
d /nix/var/log/nix/drvs  0775 root nixbld - -
```

**`files/nix-profile/00-nix-resolve-home-env.sh`** (→ `/etc/profile.d/00-nix-resolve-home-env.sh`):

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

## 8. CI/CD

### 8.1 `build.yml` (edit template's copy minimally)

Only change: matrix `recipe: [ halcyon.yml ]`. Keep everything else stock (schedule `00 06 * * *`, triggers, `blue-build/github-action@v1.11`, `cosign_private_key: ${{ secrets.SIGNING_SECRET }}`, `registry_token: ${{ github.token }}`, `maximize_build_space: true`). Allow dependabot to bump the action.

### 8.2 NEW `build-iso.yml` — single-image ISO generation (manual trigger)

Per https://blue-build.org/how-to/generate-iso/ (`bluebuild generate-iso`, built on JasonN3/build-container-installer). Generate for the ONE image only (halcyon). Note the template README's warning: ISOs are too large for free GitHub Releases hosting → upload as a workflow artifact and document external hosting options.

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
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install BlueBuild CLI
        run: |
          curl -fsSL https://raw.githubusercontent.com/blue-build/cli/main/install.sh | sudo bash
          bluebuild --version   # must be >= v0.9.23 for automatic /opt handling

      - name: Generate ISO from the halcyon recipe
        run: |
          sudo bluebuild generate-iso --iso-name halcyon.iso recipe recipes/halcyon.yml

      - name: Upload ISO artifact
        uses: actions/upload-artifact@v4
        with:
          name: halcyon-iso
          path: halcyon.iso
          if-no-files-found: error
```

Adjust runner needs (podman/root) per the generate-iso docs at implementation time; if GitHub-hosted runners cannot complete it, document the local command (`sudo bluebuild generate-iso --iso-name halcyon.iso recipe recipes/halcyon.yml`) in README instead of failing silently.

### 8.3 First-run checklist (README)

Enable Actions on the new repo; ensure `SIGNING_SECRET` is set; first workflow run creates the GHCR package `aahsnr-work/halcyon`; set package visibility to public; rebase instructions:

```bash
# from an existing atomic Fedora / ublue install:
rpm-ostree rebase ostree-unverified-registry:ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
# then switch to signed:
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:latest
systemctl reboot
```

Include Secure Boot guidance (R6): the base's ublue akmods NVIDIA modules require the ublue akmods MOK key enrollment under Secure Boot — link Bazzite's Secure Boot docs and ship a README section covering both Secure Boot ON (enrollment steps) and OFF.

---

## 9. README.md requirements

Cover: what halcyon is (Bazzite GNOME+NVIDIA-open fork → Hyprland/Noctalia lean gaming desktop); base image & tag policy (`latest`); what was removed (GNOME+extensions, handheld stack, Waydroid, BlueBubbles, Firefox, jupiter/steamdeck, zsh-setup) and kept (Steam patched RPM, umu-launcher, gamescope + gamescope-session, USB/controller peripheral stack incl. OpenRazer/Oversteer/xpadneo, Bazzite Portal, Bazaar (RPM), MangoHud/gamemode/ProtonUp-Qt/Lutris lean-gamer set, distrobox/podman); added software matrix (Hyprland-git/Noctalia-git via lionheartp/Hyprland COPR, greetd+tuigreet, vscode/brave±origin/zen/zed/emacs-pgtk, obsidian/zotero/pyprland/texlive, DistroShelf stage RPM, nix per winter, 21 brew formulas, chezmoi→aahsnr-configs/dots (replace policy), custom ujust recipes); Flatpak policy (base flatpaks stripped; first-boot: Flatseal, OnlyOffice, Bitwarden, TickTick; fedora remote check); repo-cleanup policy; `/opt` relocation note; signing/verification (`cosign verify --key cosign.pub ghcr.io/aahsnr-work/halcyon`); ISO workflow; sched_ext detection result; **credits/attribution:** Universal Blue/Bazzite (Apache-2.0), BlueBuild, fu5ha/winter (Apache-2.0, nix setup), lionheartp/Hyprland COPR, noctalia-shell upstream, DistroShelf upstream; TODO(user) markers list (branding assets, extra helper scripts, personal shell setup).

---

## 10. Implementation-time verification & QA checklist

**Static (before push):**
1. Validate every recipe/module YAML against the JSON schemas (`# yaml-language-server:` comments) and `bluebuild` CLI validation.
2. Confirm module option keys against live docs for: dnf, flatpaks, default-flatpaks, fonts, gnome-extensions, chezmoi, justfiles, systemd, files, script, copy, signing.
3. Confirm COPR `lionheartp/Hyprland` + `sneexy/zen-browser` have chroots matching the base's Fedora release; confirm Terra repo file URL; confirm `brave-origin` package availability (skip-unavailable guard is in place).
4. Pin DistroShelf stage to an existing release tag; dry-run `rpmbuild` spec sanity locally if possible.

**Build (local):** `bluebuild build recipes/halcyon.yml` (podman). Then inside the built image (`podman run --rm -it <image> bash` / `bootc`-aware inspection):
5. `rpm-ostree status` — deployment lists expected layered packages; no removals failed.
6. `dnf repoquery --unsatisfied` (or `dnf5 check`) — zero broken deps.
7. `/etc/yum.repos.d/` — only Fedora/updates (+base) repos; ALL third-party repos gone.
8. `rpm -qa | grep -Ei 'gnome-shell|gdm|waydroid|bluebubbles|decky|hhd|inputplumber|powerstation|jupiter|firefox'` — empty (except intentional keeps like gamescope-session; document).
9. `rpm -q hyprland-git noctalia-git greetd greetd-tuigreet xdg-desktop-portal-hyprland code brave-browser zen-browser zed emacs-pgtk distroshelf nix nix-daemon chezmoi` — all installed; `ldd /usr/bin/Hyprland` clean.
10. `/usr/lib/opt/brave.com` (or `/opt` symlink path) + tmpfiles entries exist; `brave --version` runs.
11. `flatpak list --app --system` — empty; `flatpak remotes` — flathub present, no fedora remote.
12. `tar --zstd -tf /usr/share/homebrew.tar.zst | grep Cellar` — shows the 21 formulas.
13. `/usr/libexec/halcyon-image/{fconf,fe}` executable; `/usr/share/ublue-os/just/60-custom.just` imports doom-setup + home-manager-setup; `ujust --summary` lists them (in-image just invocation).
14. `systemctl is-enabled greetd nix-daemon nix.mount var-nix; systemctl is-enabled --global pyprland.service; systemctl is-masked nvidia-persistenced nvidia-powerd` — all correct.
15. `/usr/lib/obsidian/obsidian`, `/usr/lib/zotero/zotero`, `/usr/bin/pypr`, `/usr/lib/texlive` + `/etc/profile.d/texlive.sh` present.
16. Fonts: `fc-list | grep -i jetbrains` + Noto Emoji present; removed-font log in build output.
17. os-release NAME=halcyon; plymouth theme set; motd placeholder present.

**CI:** push → build.yml green → image on GHCR with `.sig` (cosign verify passes with repo's cosign.pub) → run build-iso.yml manually → artifact downloadable.

**First boot (user acceptance, document in README):** tuigreet → Hyprland → Noctalia wizard; `brew list` shows 21 formulas; chezmoi-init applied aahsnr-configs/dots; `ujust doom-setup` / `ujust home-manager-setup` work; pyprland user service active; the four default-flatpaks install (notification); Steam/gamescope functional on NVIDIA.

---

## 11. Known pitfalls (hard-won during requirements research — respect all)

1. **hyprland-git ABI consistency:** never let stable `hyprland`/`hyprgraphics`/`hyprlang`/`hyprpaper` from Fedora repos satisfy deps of `hyprland-git` (documented breakage). Single COPR-pinned transaction + `ldd` verification (already in §5.2).
2. **GDM removal vs gamescope-session:** removing `gnome-shell` forces removing `gdm` (its greeter IS gnome-shell). Check `gamescope-session*` package deps; ensure it can launch via greetd/tuigreet session list; if a hard gdm dependency exists, resolve by keeping the minimal required bits or adjusting the gamescope-session entry — document the outcome.
3. **`/opt`:** automatic in CLI ≥ v0.9.23 — but VERIFY per constraint #7; never hand-roll /opt symlinks unless verification fails.
4. **Brew tarball paths:** bazzite's layout may be `/usr/share/homebrew.tar.zst` (ublue-os/brew) or an extracted dir — §5.0 step 6 detects; §5.7 handles both.
5. **Flatpak removal timing:** `flatpaks` module removals happen at build time; `default-flatpaks` installs at FIRST BOOT (runtime). Ordering between the two module files does not create conflicts, but both must be present for the user's clean-slate policy.
6. **skip-unavailable everywhere in remove/install lists** touching variant-dependent packages (bazzite desktop vs deck package sets differ).
7. **chezmoi `replace` policy** means the dots repo wins over local edits daily — intended (user confirmed).
8. **doom-setup SSH clone** requires the user's SSH keys at runtime — README note, no image-side fix.
9. **Secure Boot:** nvidia akmods come signed via ublue keys from the base; enrollment instructions belong in README (both Secure Boot states), not in the image build.
10. **Don't touch** pipewire/wireplumber, NetworkManager, polkit, steam/gamescope packages, xpadneo/openrazer/oversteer, usb/controller udev rules, Bazzite Portal, Bazaar RPM, distrobox/podman — all explicitly kept.

---

## 12. Deliverables

1. Complete `aahsnr-work/halcyon` repository per §2 tree, all files committed (assets verbatim per §7).
2. First CI build green; image published to `ghcr.io/aahsnr-work/halcyon:latest` (cosign-signed).
3. `build-iso.yml` present and manually verified (or documented fallback per §8.2).
4. README per §9, including QA results summary from §10 (items 5–17 run against the first built image) and every detected variance from assumptions in §3 (flatpak inventory, fedora remote, scx presence, Bazaar packaging, brew layout).
5. A `NOTES.md` (or README section) listing the exact packages removed vs kept with justifications, for the user's future "integrate my own shell setup on top" work.

**End of prompt.**
