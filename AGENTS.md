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
