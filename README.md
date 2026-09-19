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
- **Gaming:** `steam` (with the bazzite-steam wrappers and desktop-entry
  wiring), `gamescope`, `mangohud` (+i686), `gamemode`, `lutris`,
  `scx-scheds`/`scx-tools`, `umu-launcher`, `bazaar`, `bazzite-portal`,
  `input-remapper`, `usbip`, 32-bit NVIDIA + mesa libraries.
- **Apps:** VS Code, Brave, zen-browser (per-use vendor/COPR repos — removed
  again at finalize), zed, emacs-pgtk, neovim; Obsidian, Zotero, Pyprland,
  TeX Live and a Python helper family baked at build time.
- **Tooling:** the former brew formulas as RPMs (bat, eza, fzf, lazygit,
  ripgrep, starship, yazi, zellij, …), chezmoi (Fedora RPM) wired to
  [aahsnr-configs/dotfiles](https://github.com/aahsnr-configs/dotfiles)
  (first-login init + daily update), nix via the
  [fu5ha/winter](https://github.com/fu5ha/winter) bind-mount pattern,
  and ujust/uupd (`ublue-os-just` + `uupd`) with curated Bazzite recipes.
- **Flatpak:** package + **flathub user repo only** (no system flathub, no
  Fedora flatpaks); four transition apps install per-user at first login —
  everything else is native RPM.

---

## Repo structure (bazzite template)

```
├── Containerfile            # the single source of build-order truth
├── build_files/             # semantic unnumbered helpers (never in the image)
│   ├── packages.json        # SINGLE SOURCE OF TRUTH for every dnf/flatpak package
│   ├── packages-lib         # jq accessors the stages source (fail-fast validation)
│   ├── remove-packages      #   removals SECOND — JSON-driven, rpm-resolved
│   ├── setup-repos          #   FIRST — jq/dnf5-plugins bootstrap + RPM Fusion
│   │                        #   (NVIDIA-excluded) + negativo17
│   ├── install-kernel       #   p03 + nvidia-open (COPR per-use)
│   ├── install-packages     #   core/desktop/gaming/apps (repos per-use)
│   ├── install-terra        #   USER-EDITABLE Terra list (Terra-exclusive)
│   ├── install-devtools / install-nix / setup-flatpaks / install-built-apps
│   ├── setup-ujust / configure-system / image-info / build-initramfs
│   ├── finalize             #   third-party repo sweep + end-of-build hygiene
│   ├── *-verify             #   per-level gates (fail fast at that level)
│   ├── cleanup              #   end-of-RUN temp/log//boot wipe
│   └── python-packages/     #   build-time staged Python helper sources
└── system_files/
    └── shared/              # root overlay COPYed into the image
        ├── etc/             #   greetd, pam, profile.d, environment.d, …
        └── usr/             #   units, tmpfiles, ujust modules, plymouth, /usr/bin
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

| Group | Resolved from | Consumed by |
|---|---|---|
| `fedora-core` | Fedora | install-packages |
| `fedora-hardware` | Fedora | install-packages |
| `hyprland-copr` | COPR `lionheartp/Hyprland` | install-packages |
| `gaming` | Fedora + RPM Fusion | install-packages |
| `bazaar-copr` | COPR `ublue-os/packages` | install-packages |
| `zen-copr` | COPR `sneexy/zen-browser` | install-packages |
| `vendor-apps` / `vendor-apps-optional` | per-use vendor repos (VS Code, Brave) | install-packages |
| `fedora-devtools` | Fedora | install-devtools |
| `nix` | Fedora | install-nix |
| `flatpak` | Fedora | setup-flatpaks |
| `ujust-copr` / `ujust-fedora` | COPR `ublue-os/packages` / Fedora | setup-ujust |
| `terra` | **Terra only** (`--disablerepo='*'`) | install-terra |
| `all.exclude.all` | removals — resolved through `rpm -qa`, absent names tolerated | remove-packages |
| `flatpak.install` / `flatpak.remove` | Flathub (user repo, at first login) | setup-flatpaks |

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
  (`terra-release*`) stay in their scripts — they are not catalog entries.

---

## Build & CI

- `build.yml` (daily cron 08:00 UTC, push, PR, manual): polls the consumed
  COPRs for healthy metadata, frees runner disk, builds with
  `podman build --pull`, writes a **package-count report** to the run summary,
  then signs with cosign (`SIGNING_SECRET`) and publishes to GHCR.
- Local test build: `just build localhost/halcyon latest` (equivalent to CI,
  including the OCI/artifacthub label scheme)
- OCI labels (`org.opencontainers.image.*`) are set from
  `--build-arg IMAGE_VERSION=<fedora>.<date>` and `SOURCE_SHA=<git sha>`
  (CI supplies both). `bootc container lint` runs network-isolated as the
  final gate.

---

## Credits & licenses

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
