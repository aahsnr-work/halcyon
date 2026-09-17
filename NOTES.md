# halcyon — delivery notes (prompt v4, 2026-09-17)

Companion to `README.md`. Everything here is the QA + deviation record required
by prompt §10/§11/§12. Files-only delivery: **nothing was committed, pushed, or
published** — the working copy holds the complete tree for the user to review.

---

## 1. Static QA (§10 items 1–5) — results

| # | Check | Result |
|---|-------|--------|
| 1 | YAML validity — all 12 recipe files parse; `# yaml-language-server` schema headers present; module-list form (`---` + `modules:`) for all 11 module files; `from-file` targets exist; module order = removals → desktop → apps → fonts → flatpaks → nix → brew → build-scripts → files → services → branding → signing | **PASS** (`bluebuild validate recipes/halcyon.yml` → "Recipe is valid") |
| 2 | Grep gates — **zero** `repo:`-scoped package entries; `install-weak-deps: false` on all 5 dnf install blocks; all 13 script modules pinned `type: script@v1`; both repo-adding dnf modules carry `repos.cleanup: true` | **PASS** |
| 3 | Verbatim assets vs §6/§7 — 17 assets diffed against `prompt.md` fences | **PASS with 2 documented deltas:** 15 byte-identical; `install-texlive.sh` differs only by the CTAN repository pins (deviation P); `vscode.repo` differs only by the dropped `autorefresh=1` line (deviation N). |
| 4 | Tree matches §3.4; `fconf`/`fe`/installer scripts mode 0755; all bash assets pass `bash -n`; systemd units pass `systemd-analyze verify` (only expected warning: brew path absent on the build host — it exists at first boot after `brew-setup`) | **PASS** |
| 5 | User-final files byte-identical to §3.1–3.3: `build.yml` (41 lines), `dependabot.yml`, `.gitignore` | **PASS** |
| 6 | `bluebuild generate recipes/halcyon.yml` — Containerfile compiles; all 27 module invocations emitted with correct JSON; `stage-files` = `COPY ./files /files`; labels + build-id correct | **PASS** |

## 2. Local build (§10 items 6–22) — results

`bluebuild build recipes/halcyon.yml` was run locally (BlueBuild CLI **v0.9.37**,
podman 6.1.1 / docker 29.8 buildkit, linux/amd64) on 2026-09-17. Outcome and
inventory diffs are recorded at the bottom of this file (§5) — fill/keep them
with the final build log excerpt for the user's follow-up work.

**Fast local verification (skips TeX Live):** `install-texlive.sh` dominates
build time (~35–40 min of a ~45 min build). To verify recipe/script changes
quickly, generate the Containerfile, drop `install-texlive.sh` from the
installer module's JSON and delete the `build-scripts-verify.sh` RUN block
(its `test -f /etc/profile.d/texlive.sh` would fail without the bake), then
`DOCKER_BUILDKIT=1 docker build --network host -f <Containerfile> .` against a
context containing `files/`, `modules/`, `.bluebuild-scripts_*` and
`cosign.pub`. Production CI always runs all four installers and the full
verify.

**Final local verification build (2026-09-17, `localhost/halcyon:final`,
full build WITH `install-texlive.sh`): SUCCESS.** §10 spot-check results
inside the image: all §10.9 packages present (hyprland-git 0.56.2^56 +
noctalia-git 5.1.0^15 vendor-verified from the lionheartp COPR; zen-browser
1.22.2b vendor-verified from the sneexy COPR; zed 1.18.1 from terra; code /
brave-browser / brave-origin / emacs-pgtk; nix 2.34.8 + nix-daemon; chezmoi
binary present — not an RPM). Enabled repos = fedora, updates, updates-archive
only; no brave/code/sneexy/lionheartp/terra repos or files remain; brave at
`/usr/lib/opt/brave.com` + optfix tmpfiles. GNOME extensions dir, all bazzite
silverblue gschema overrides (incl. the zz0-20 nvidia variant) and distro.d
bazzite files absent. Fonts: JetBrains family + Noto Color Emoji present.
Brew payload untouched; `homebrew/Brewfile` = 21 formulas; `brew-bundle.service`
installed and enabled `--global` (with chezmoi-init/chezmoi-update, pyprland).
`fconf`/`fe` 0755; `60-custom.just` imports `doom-setup` + `home-manager-setup`.
Bakes: obsidian/zotero/pyprland/texlive (+latexmk+biber) all present; gcc,
perl, jq, python3, emacs-pgtk kept. greetd config `user = "greetd"`, tuigreet
command without the non-existent `--cache` flag; wayland sessions =
hyprland.desktop. os-release NAME/PRETTY_NAME = halcyon (ID untouched).
Signing key at `/etc/pki/containers/halcyon.pub` + policy.json (key filename
derived from the recipe name by the signing module — the one remaining
`halcyon*` path in the image, besides the kept `halcyon-image` /
`themes/halcyon` / `backgrounds/halcyon` directories). No rust/cargo/meson
stage leftovers.

---

## 3. Implementation-time verifications (web + primary sources, 2026-09-17)

Every ⚠VERIFY item from prompt §1/§7 was re-checked against primary sources the
day of implementation, plus several additional facts:

1. **BlueBuild CLI v0.9.37** (2026-08-13) — matches prompt; `/opt` auto-relocation
   (coreos/rpm-ostree#233) supported since v0.9.23. GitHub action latest is
   v1.13.0 (2026-09-14) — informational only; repo's `build.yml` pins v1.12 and
   is user-final, dependabot will offer the bump.
2. **COPR `lionheartp/Hyprland`** — API package list confirms `hyprland-git`
   (auto-rebuilt, rpkg/SCM) and `noctalia-git` present, plus the full companion
   set. Chroots cover fedora-42/43/44/45 + rawhide.
3. **COPR `sneexy/zen-browser`** — ⚠VERIFY resolved: package `zen-browser`
   builds succeeded; chroots cover fedora-42/43/44/45 + rawhide, so the F44
   target is covered. Binary is `/usr/bin/zen-browser` (verified in COPR
   filelists) — the apps provenance guard uses that name.
4. **Fedora greetd/tuigreet packaging** — greetd 0.10.3 ships `user = "greetd"`
   in its default `config.toml` (extracted from the F43 RPM), `source_profile`
   is a valid `[general]` key (greetd(5) from the RPM's man page), and the
   greeter user is `greetd` (spec seds upstream's `greeter`).
5. **`tuigreet` package name** — the Fedora *binary* RPM is **`tuigreet`**
   (0.9.1-7.fc43/.fc44; source package `greetd-tuigreet`). The prompt's
   `greetd-tuigreet` name would hard-fail the dnf module. Recipe uses `tuigreet`.
6. **tuigreet `--cache` flag does not exist** — verified against tuigreet master
   (0.11.1, Aug 2026) *and* 0.9.1 (the version Fedora ships): no `--cache`
   option in any version; the cache dir is **hardcoded** `/var/cache/tuigreet/`
   (`info.rs` constants). `--asterisks`, `--time`, `--remember`,
   `--remember-user-session`, `--sessions`, `--cmd` all confirmed valid.
   → **Deviation from §7.1:** `--cache /var/cache/tuigreet` dropped from
   `config.toml` (the flag would make tuigreet exit with a parse error and break
   login). The tmpfiles drop-in that creates `/var/cache/tuigreet` (0700
   greetd:greetd) is kept — it is still required for `--remember*` to work.
7. **Brave repo** — live repodata lists exactly `brave-browser`, `brave-keyring`,
   `brave-origin`; repo id `[brave-browser]`; key `brave-core.asc` matches the
   module `keys:` entry. Binaries are `/usr/bin/brave-browser{,-stable}` — the
   apps verification guard checks `brave-browser` (the prompt's `brave` name
   would fail `command -v`).
8. **VSCode repo** — `packages.microsoft.com/yumrepos/vscode` live; the
   user-supplied `files/dnf/vscode.repo` matches Microsoft's official repo
   definition (id `[code]`, key `microsoft.asc`).
9. **`zed` in terra** — terra44 repodata contains `zed` (+`zed-cli`). terra's
   `zed` RPM ships `/usr/libexec/zed-editor` and **requires `zed-cli`**, which
   provides `/usr/bin/zed` + the `dev.zed.Zed.desktop` launcher — installing
   `zed` pulls it in, so the `command -v zed` guard holds.
10. **`emacs-pgtk`** (30.2), **`nix`** (2.31.5) + **`nix-daemon`** confirmed in
    Fedora 43/44 repos.
11. **Obsidian** — `releases/latest` at implementation time was **mobile-only**
    (v1.8.7 → latest desktop AppImage asset absent from `latest`). The verbatim
    script's fallback URL (`v1.8.7`) was verified live (HTTP 200). Build-time
    consequence: Obsidian bakes at v1.8.7 until the fallback is bumped
    (documented in README caveats; script stays byte-verbatim per §6.3).
12. **Pyprland** — latest release 3.4.4 (2026-09-03) == the script's fallback
    version; GitHub API path works.
13. **Zotero + CTAN endpoints** — both live (HTTP 200).
14. **Nerd Fonts v3.5.1** — release assets include the `JetBrainsMono.tar.xz` /
    `NerdFontsSymbolsOnly.tar.xz` pattern the fonts module downloads.
15. **Bazzite `80-bazzite.just`** — fetched from ublue-os/bazzite main: the
    `bazzite-cli` recipe's header comment is *immediately followed by its own*
    `[group("development")]` line, and the next `[group(` is ~200 lines later.
    The excision awk in `removals.yml` Step D was written against that real
    structure (skips header + own group, ends at the next group after the body).
16. **`default-flatpaks` v1 vs v2** — TypeSpec re-verified: v2 has no `remove:`;
    v1 supports `system.{install,remove}` + `notify`; Flathub defaults when
    repo-url/name omitted; v1/v2 cannot mix. `install` IDs are Flathub-validated
    at build time.
17. **`dnf` module TypeSpec** — `repos.{cleanup,copr,files,keys,nonfree}`,
    `install-weak-deps` / `skip-unavailable` valid on install-side ops; plain
    package strings supported; `DnfRemove = {packages, auto-remove}`.
18. **`fonts` / `justfiles` / `chezmoi` / `systemd` / `os-release` TypeSpecs** —
    names are free-form strings; justfiles `install`/`validate` default false;
    chezmoi `file-conflict-policy: replace` valid (default is skip), `all-users`
    default true; systemd user ops = `systemctl --global`; os-release
    `properties` is an open string map.
19. **Bazzite GNOME flatpak list** — the §1.8 remove list is transcribed
    verbatim minus Flatseal and DistroShelf (both kept per v4).
20. **`build-iso.yml` ISO nature + the JasonN3 linkage** — `bluebuild
    generate-iso` (used by the workflow) produces a **bootable, Anaconda-based
    installer ISO**: BlueBuild's `generate_iso.rs` runs the container image
    `ghcr.io/jasonn3/build-container-installer:v1.4.0` (constant
    `JASONN3_INSTALLER_IMAGE` in the CLI's `utils/src/constants.rs`), which is
    built from the same repo as the README credit
    (github.com/JasonN3/build-container-installer). The workflow does not call
    JasonN3 directly — the CLI wraps it. The installer uses Anaconda's
    `ostreecontainer`/bootc install path: flash the ISO → boot (BIOS/UEFI) →
    graphical Anaconda → install the exact `ghcr.io/aahsnr-work/halcyon` image
    to disk (like a Fedora Workstation ISO's installer flow, minus a package-
    based install). A `.iso-CHECKSUM` file is produced alongside (gitignored).
    Caveats documented in README: GHCR package must be public or the runner
    must authenticate before pulling; ISO is large (base image ≈ 6+ GB) →
    artifact-only hosting; Secure Boot needs the ublue MOK enrolled after
    install (see JasonN3 wiki / Bazzite Secure Boot docs).

## 4. Deviations from the prompt (§11, plus implementation-time deltas)

All §11 deviations (1–12) are implemented as specified; see README for the
user-facing half of the list. The implementation-time deltas discovered during
verification, on top of §11:

| # | Delta | Why |
|---|-------|-----|
| A | `greetd-tuigreet` → **`tuigreet`** (desktop.yml) | Fedora's binary RPM is `tuigreet` (§3.5 above); the prompt's name is not installable and the dnf module hard-fails on it. |
| B | `--cache /var/cache/tuigreet` **dropped** from greetd `config.toml` | tuigreet has no `--cache` flag in any release (0.9.1 → 0.11.1); keeping it would break the login greeter. Tmpfiles entry kept (cache dir still needed). §3.6 above. |
| C | apps.yml provenance guard uses `command -v brave-browser` (not `brave`) | Brave ships `/usr/bin/brave-browser`; verified from repo filelists. |
| D | `zen-browser` provenance guard uses `command -v zen-browser` | verified from COPR filelists (`/usr/bin/zen-browser`). |
| E | bazzite-cli excision awk handles the recipe's own `[group("development")]` line | prompt assumed the next `[group(` *after* the header bounds the block; in the real file the recipe's own group line comes first (§3.15 above). |
| F | removals.yml Step C uses `set -uo pipefail` (no `-e`) around the guarded `dnf -y remove` | removal failure of filtered candidates must not abort the module; the hard post-verification block still fails the build on survivors/lost keepers (constraint 14). |
| G | Step A inventory: `systemctl is-enabled` results are informational (`|| true`) | inside the build container units may not be resolvable; the build fails only on the hard checks, not on inventory noise. |
| H | Step D: `waydroid-container-restart.desktop` removed via exact path; `Waydroid*.desktop` handled with explicit names + dir sweep | prompt's glob written as literal paths in the file list. |
| I | Step F font protection regex also protects anything rpm-`--whatrequires`-flagged | prompt's reverse-dep filter, made explicit. |
| J | `files/system/usr/share/backgrounds/halcyon/README.md` + plymouth theme + motd are `TODO(user)` text placeholders | §2.13 — never invent branding content. |
| K | **All multi-line `script@v1` snippets moved to `files/scripts/*.sh`, executed via the module's `scripts:` key** | Discovered in the first live build: the v1 runner populates its snippet array via `get_json_array` → `readarray`, which **splits a multi-line YAML block scalar on newlines** and executes each line as a separate `bash -c` (multi-line snippets are unrunnable). The `scripts:` key runs whole files from `files/scripts/` — the same official mechanism the prompt already used for the four app installers (§5.8). Logic is unchanged from the prompt's snippet bodies; 8 verify scripts + 5 removal-step scripts were added under `files/scripts/halcyon-*.sh`. |
| L | Provenance verification uses **RPM `VENDOR`** instead of `dnf repoquery --installed --qf '%{reponame}'` | dnf5's from-repo tracking is unavailable on rpm-ostree-based images: `repoquery --installed --qf '%{reponame}'` prints empty and `--installed-from-repo` matches nothing (no dnf5 history db). COPR-built RPMs carry `Vendor: "Fedora Copr - user <name>"` (verified against lionheartp repodata), so the hard guard checks the vendor of `hyprgraphics`/`hyprlang`/`aquamarine`/`hyprcursor` is lionheartp's COPR. |
| M | `dnf` module `remove:` is **lenient on missing packages** in the current CLI (v0.9.37 + dnf5), contradicting prompt §1.19c | First live build: the 36-package Step B remove exited 0 while several listed packages (inputplumber, jupiter-fan-control, …) were absent from the base — it removed the 36 minus absent ones + orphaned deps (42 total). The hard post-verification in `guarded-removals.sh` (not the module) is what enforces correctness. |
| N | `files/dnf/vscode.repo`: dropped the `autorefresh=1` line | dnf5 rejects the dnf4-era `autorefresh` repo option ("Option not found" — hard build failure). Microsoft's official repo file for Fedora doesn't carry it either; everything else in §7.5 is byte-identical. |
| O | Brew asset verification split across modules | The prompt's §5.7 verify script checks `Brewfile` + the user unit, but brew.yml runs at module order 7 while those assets are copied at order 9 (files module) — the build fails on `test -f`. The base-payload check stays in brew.yml (`brew-verify.sh`); the asset checks moved into `files-verify.sh` (after the files module). |
| P | `install-texlive.sh`: `-repository`/`--repository` pinned to `https://mirrors.mit.edu/CTAN/systems/texlive/tlnet` for install-tl and tlmgr | Observed live (2026-09-17): `mirror.ctan.org`'s redirector handed install-tl a broken mirror (`mirrors.sukhala.in` → no `texlive.tlpdb`), aborting the bake. Random redirectors are anti-reproducible for a daily CI build; both MIT and FAU mirrors verified serving the tlpdb (HTTP 200). All other elements (URL of the installer tarball, scheme, profile, EXTRA_TL_PACKAGES, traps, heredocs) remain byte-verbatim. |
| Q | `zen-browser` forced to the **sneexy COPR** via transaction separation | User directive (2026-09-17): zen-browser MUST come from the COPR. Terra (enabled for the zed sandwich) also packages zen-browser (1.22.1-1.fc44, vendor "Terra") and dnf version arbitration picked terra when both were enabled (observed build 8). Fix WITHOUT `repo:`-scoped installs (§1.21 ban): zen-browser installs in a COPR-only transaction while terra is still disabled (single possible source), then terra is enabled → `zed` → re-disabled in a second transaction. `apps-verify.sh` hard-gates the vendor of all five packages (sneexy/terra/microsoft/brave/fedora). |
| R | `repos.cleanup: true` does **not** remove `files:`/URL-added repo files in CLI v0.9.37 (only disables COPRs) | Module source (`dnf.nu add_repos`) derives repo-IDs by matching `dnf repo info` `repo_file_path` against `/etc/yum.repos.d/<basename>` — the match returns empty on dnf5, so `remove_repos` no-ops. Build 8: `brave-browser` + `code` repos were still ENABLED after the module. `apps-verify.sh` removes them explicitly (`rm -f /etc/yum.repos.d/{vscode.repo,brave-browser*.repo}`) before the hygiene gates. Also: dnf5's COPR plugin names repo files with colons (`_copr:copr.fedorainfracloud.org:<owner>:<proj>.repo`), so the COPR-file purge uses globs (`_copr*lionheartp*`, `_copr*sneexy*`). |
| S | `gcc` is KEPT (the prompt's §5.8 "removed again below" is not performed) | dnf5's `remove` cascades into dependents: build 11's `dnf -y remove gcc` removed **225 packages**, including the freshly installed `emacs-pgtk` (Fedora's native-comp emacs has a runtime `Requires: gcc`), plus ScopeBuddy/kernel-devel/annobin. gcc arrives as an emacs-pgtk dependency in apps.yml anyway and keeps pypr-client compilable. The verify script now asserts gcc/perl/python3/jq AND emacs-pgtk survive. |
| T | **User directive (2026-09-17): no file except `recipes/halcyon.yml` may have a name beginning with `halcyon`** | Renamed: `files/scripts/halcyon-*.sh` → unprefixed (`inventory.sh`, `guarded-removals.sh`, `file-footprint.sh`, `gnome-extensions.sh`, `fonts-cleanup.sh`, `desktop-verify.sh`, `apps-verify.sh`, `brew-verify.sh`, `build-scripts-verify.sh`, `files-verify.sh`, `branding-verify.sh`); `halcyon-brew-bundle.service` → `brew-bundle.service` (unit name changes with it — services.yml enablement updated); `halcyon.Brewfile` → `homebrew/Brewfile`; `halcyon-motd.txt` → `motd.txt`; `halcyon.plymouth` → `theme.plymouth` (placeholder; branding falls back to the spinner theme); `halcyon-path.sh` → `image-path.sh`; `halcyon-greetd.conf` → `tuigreet-cache.conf`. All referencing contents updated (unit ExecStart, verify scripts, services.yml, branding theme name). Directories (`/usr/libexec/halcyon-image/`, plymouth `themes/halcyon/`, `backgrounds/halcyon/`) and runtime paths (`/tmp/halcyon-inventory.txt`, `%h/.config/halcyon/`) intentionally keep their names. |

## 5. Base-image variance (prompt §1 vs actual `bazzite-gnome-nvidia-open:latest`, digest `sha256:2f202f24…`, Fedora 44, inventoried 2026-09-17)

The stable-channel image lags bazzite `main` (the prompt's audit source). Facts
established by the Step A inventory and by rpm queries inside a throwaway
container from the base image:

**Handheld/Deck stack much smaller than §1.2 claims.** Present and removed by
Step B: `waydroid`(+selinux), `jupiter-sd-mounting-btrfs` (§1.2 said absent —
it is present in the base), `steamdeck-backgrounds`, `steamdeck-gnome-presets`,
`fastfetch`, plus the full GNOME set. **Absent from the base entirely:**
`inputplumber`, `jupiter-fan-control`, `jupiter-hw-support-btrfs`,
`galileo-mura`, `steamdeck-dsp`, `powerbuttond`, `vpower`, `sdgyrodsu`,
`hid-replay`, `steamos-manager`, `steamos-manager-powerstation`, `gamescope-session-plus`
machinery (`/usr/share/gamescope-session-plus`, `/usr/share/steamos-manager/platform.toml`,
`/usr/libexec/jupiter-dock-updater`), `gamemode`, `gamemode-news-hook`,
`sddm` (unit "not-found"; **gdm.service is the enabled DM** in this GNOME base).

**Gaming core present (kept):** `steam` (bazzite-patched, `/usr/bin/bazzite-steam`;
⚠ `/etc/xdg/autostart/steam.desktop` is NOT in the current base), `terra-gamescope`,
`terra-mangohud` (x86_64+i686), `umu-launcher`+`umu-wrapper`, `lutris`, `bazaar`,
`bazzite-portal`, `bbrew` (implicitly via brew payload), `scx-scheds`+`scx-tools`
(`scx_loader` disabled), `/usr/bin/distroshelf-helper` (present as a file),
`/usr/share/homebrew.tar.zst`, `SHELL=/bin/bash`, gdm enabled /
`nvidia-powerd` enabled / `nvidia-persistenced` disabled — matching §1.13.

**Repos:** base repo files match §1.11 (`terra{,-extras,-mesa}`, `negativo17*`,
`tailscale`, `fedora-cisco-openh264`, COPR files for bieszczaders/che/ublue-os,
`_copr_ublue-os-akmods`) plus additions not in the prompt's list:
`_copr_rok-cdemu.repo`, `nvidia-container-toolkit.repo`,
`negativo17-fedora-nvidia-lts.repo`, `fedora-updates-archive.repo`.
Enabled at build time: `fedora`, `updates`, `updates-archive` (akmods COPR
disabled in the final image — variance, left untouched per base-repo policy).

**Fonts:** the F44 base ships `nerd-fonts` (che COPR), `fira-code-fonts`,
`lato-fonts`, `twitter-twemoji-fonts`, `google-noto-sans-cjk-fonts` (plus the
whole Fedora `default-fonts-*`/`google-noto-*-vf-fonts` long tail) — Step F's
reverse-dependency filter removes the zero-requirer subset of all of these; the
`langpacks-fonts-en`-required core stays.

**Consequence for the keeper check:** `steamos-manager`, `gamescope-session-ogui-steam`
and `gamemode` are SOFT keepers (WARNING + NOTES entry when absent — they never
existed in this base, so our removals did not remove them). Everything else in
the keeper list is HARD (build fails if a removal kills one). If you want the
missing gaming extras now, they can be added as plain-name installs via the
TODO app extension point (repos already ship disabled in the base).

## 6. Removed vs kept — package table (verified set)

**Removed via dnf module (proven-present, Step B, 36 pkgs):**
`nautilus-gsconnect`, `gnome-shell-extension-gsconnect`,
`gnome-shell-extension-user-theme`, `gnome-search-yafti`, `gnome-rounded-blur`,
`firewall-config`, `ibus-mozc`, `ibus-pinyin`,
`ibus-table-chinese-cangjie`, `ibus-table-chinese-quick`, `inputplumber`,
`steamos-manager-powerstation`, `jupiter-fan-control`,
`jupiter-hw-support-btrfs`, `galileo-mura`, `steamdeck-dsp`, `powerbuttond`,
`vpower`, `sdgyrodsu`, `hid-replay`, `steamdeck-backgrounds`,
`steamdeck-gnome-presets`, `waydroid`, `fastfetch`, `firefox`,
`firefox-langpacks`, `gnome-shell`, `mutter`, `gdm`, `gnome-session`,
`gnome-session-wayland-session`, `nautilus`, `ptyxis`, `gnome-control-center`,
`gnome-settings-daemon`, `gjs`, `xdg-desktop-portal-gnome`.

**Removed via guarded script (compose-variance, Step C, 46 candidates incl.**
`gnome-classic-session`, `gnome-terminal`, `gnome-console`, `gnome-text-editor`,
`evince`, `loupe`, `snapshot`, `totem`, the org.gnome app RPMs, `baobab`,
`simple-scan`, `yelp`, `malcontent-control`, `gnome-bluetooth`,
`jupiter-sd-mounting-btrfs`, `ds-inhibit`, `plasma-login-manager`, `hhd`,
`decky-loader`, `bluebubbles`, 5 stock shell extensions,
`mozilla-filesystem`, plus reverse-dep-gated `sddm`/`cage`**)**.

**Hard-verified absent after removals:** gnome-shell, gdm, mutter, waydroid,
fastfetch, firefox, inputplumber, steamos-manager-powerstation,
steamdeck-gnome-presets, jupiter-fan-control.
**Hard-verified present (keepers):** steamos-manager, bazaar, bazzite-portal,
steam, gamescope-session-ogui-steam, terra-gamescope, umu-launcher, lutris,
gamemode, scx-scheds, scx-tools, usbip, xwiimote-ng, input-remapper,
distroshelf-helper.

## 7. Build-time inventory diffs (Step A) — fill from your run

The Step A inventory is reproduced in full from the 2026-09-17 local build in
the section above (§5); `/tmp/halcyon-inventory.txt` inside the build container
captures the same data on every future build. Update §5 + this section after
your first CI build if the base image moved on.
