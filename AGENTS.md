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
BlueBuild action anywhere in `.github/` of this branch. If you see one, you are
on `main`, or a scheduled run is executing `main`'s workflow (scheduled
workflows run from the repository's **default** branch).

Output: `ghcr.io/aahsnr-work/halcyon:<tag>`, cosign-signed in CI.

---

## 2. Repository layout

```
Containerfile              # 18 RUN stages (banners 00–17) + hermetic bootc lint
Justfile                   # check / lint / lint-python / test-python / build / verify-image
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
  apps/                    # install-built-apps + sub-installers, built-apps-verify
  desktop/                 # configure-system, image-info, build-plymouth-assets,
                           #   system-verify, branding-verify
  finish/                  # build-initramfs, finalize, final-verify
  python-packages/         # 11 stdlib-only src-layout Python tools

system_files/shared/       # static tree COPY'd to / BEFORE any RUN stage
verify/                    # image-side suites CI runs against the built image
.github/                   # build / lint / clean / semantic-pr workflows + helpers
```

**Paths in scripts are `/ctx/<folder>/<script>`** — the ctx stage flattens
`build_files/` to `/`, so `build_files/apps/install-obsidian` is
`/ctx/apps/install-obsidian`.

---

## 3. Commands

```bash
just check          # just --fmt --check, bash -n over build_files + verify + recipe bodies
just lint           # shellcheck --shell=bash -x over every build_files script
just lint-python    # ruff: undefined names + syntax errors in the python helpers
just test-python    # pytest for the python helpers that have suites
just check-github   # host-side .github audit (verify/verify-github.sh)
just build          # podman build with the CI label/ARG scheme
just verify-image   # run verify/verify-{brew,chezmoi,ujust}.sh inside the image
just package-count  # run the built image, report RPM count + kernel version
```

**Always run `just check` and `just lint` before proposing a change to anything
under `build_files/`.** A missing `fi` or an unquoted expansion in a build
script costs a full ~40-minute CI build.

---

## 4. Build architecture — rules that must not be broken

1. **Stage order is load-bearing.** `setup-repos` runs first (it bootstraps
   `jq`, which `packages-lib` needs to read `packages.json`); removals run
   second against the near-pristine base; the initramfs is built _last_ (so the
   plymouth theme and NVIDIA dracut hooks are baked in); `finalize` and
   `final-verify` close the build.

2. **Every mutating `RUN` ends with `/ctx/cleanup`.** No exceptions.

3. **`--setopt=install_weak_deps=False` on every `dnf5 install`.** Anything that
   used to arrive as a weak dependency must be listed explicitly.

4. **Third-party repo lifecycle: enable → consume → disable, inside one stage.**
   `finalize` is the belt-and-braces sweep; `final-verify` asserts that only
   Fedora repo files remain.

5. **NVIDIA comes from negativo17 only.** Four negativo17 subpackages
   (`nvidia-driver`, `nvidia-driver-cuda`, `nvidia-settings`,
   `nvidia-kmod-common`) are dependency-entangled with a kmod package and are
   **payload-extracted via `rpm2cpio`**, not installed. Do not "fix" this by
   adding them to a `dnf5 install` line — it pulls `dkms-nvidia`, which
   `Conflicts` with `kernel-p03-nvidia-open`.

6. **Kernel and NVIDIA RPMs install with `--setopt=tsflags=noscripts`**;
   `depmod` and `dracut` are run explicitly.

7. **Per-stage verification.** Every new stage gets a `<stage>-verify` companion
   in the same `RUN`. Cross-cutting checks that only the finished image can
   answer go in `final-verify`.

8. **This is bootc, not rpm-ostree.** Kernel arguments are changed with
   `grubby`; the cmdline is read from `/proc/cmdline`; `bootc status` replaces
   `rpm-ostree status`.

9. **A package a recipe shells out to must be in `packages.json`.** `ugum`
   falls back to fzf when `gum` is absent, so `gum` is _not_ required — but
   `grubby`, `ethtool`, `wget`, `hostname`, `fpaste`, `wl-copy`, `zenity` and
   `jq` are, and `ujust-verify` gates them.

10. **Image signatures use the legacy sigstore format.** Cosign 3 defaults to a
    referrer-based bundle that `cosign verify` accepts but containers/image
    (podman, skopeo, bootc) cannot see. `build.yml` signs with
    `--new-bundle-format=false --use-signing-config=false
--registry-referrers-mode=legacy` and then verifies with
    `--new-bundle-format=false`. Never remove either step.

---

## 5. bootc / image constraints

- `/var` must be effectively empty in the image. Content there without a
  matching `tmpfiles.d` entry triggers the `var-tmpfiles` lint warning, and is
  only applied on _initial provisioning_. Create runtime state with `tmpfiles.d`
  or a oneshot unit (see `var-nix.service`).
- **Never create `/usr/etc`.** It is bootc's client-side view of the default
  `/etc`, `bootc container lint` checks it, and `branding-verify` asserts it does
  not exist. The cosign key lives at `/etc/pki/containers/halcyon.pub`.
- `/var/run` must remain a symlink to `/run` — that lint is a hard failure.
- `/boot` must be empty; the kernel lives in `/usr/lib/modules/<kver>/`.
- No `/usr/local` writes; use `/usr/lib/<app>` plus a `/usr/bin` symlink. (Brave
  installs under `/opt` via its RPM; do not gate `/opt` as empty.)
- The final `bootc container lint` runs with `--network=none` and a tmpfs
  `/run`. Anything needing the network must happen before it.

---

## 6. Conventions by file type

### Build scripts (`build_files/**`)

- `#!/usr/bin/env bash` + `set -euo pipefail` (use `set -uo pipefail` only when
  the script deliberately accumulates failures and returns its own `rc`).
- Wrap output in `echo "::group::<script> — <phase>"` / `echo "::endgroup::"`;
  use the `  OK  ` / `  WARN  ` / `  FAIL  ` / `  SKIP  ` / `  INFO  ` prefixes.
- One package per line in `dnf5 install` lists; package lists live in
  `packages.json`.
- **`# shellcheck source=build_files/packages-lib`** — ShellCheck resolves
  `source=` relative to its _working directory_ (the repo root, where
  `just lint` runs), not the script's directory. Do not rewrite these to
  `../packages-lib`; that fails `just lint`.
- If a script tolerates failure (`|| true`), the corresponding verify gate must
  tolerate it too.

### Static tree (`system_files/shared/**`)

- COPY'd **before** any package install. An RPM installed later that owns the
  same path can replace or shadow your file. For drop-in directories
  (`tmpfiles.d`, `sysusers.d`, `modprobe.d`) prefix `zz-halcyon-<topic>.conf` so
  it cannot collide and sorts later, and gate the final content. For RPM-owned
  config, gate the content right after the package install (see
  `packages-verify` for greetd).
- Executable bits come from git (`git update-index --chmod=+x`), plus a
  `test -x` gate.

### profile.d ordering

`00-path-guard.sh` → `01-nix-resolve-home-env.sh` → `02-custom-environment.sh` →
`image-path.sh` → `texlive.sh` (generated). `00-path-guard.sh` uses only shell
builtins on purpose. The default login shell is **zsh**; confirm zsh's
`/etc/zprofile` reaches anything you rely on.

### ujust recipes (`usr/share/ublue-os/just/*.just`)

- Start with `# vim: set ft=make :`; every recipe gets a doc comment and a
  `[group("…")]`.
- Register new modules in the loop in `runtime/setup-ujust`.
- Interactive recipes `source /usr/lib/ujust/ujust.sh` and use `Choose`.
- `just --fmt --check` does not parse recipe bodies; `just check` runs
  `bash -n` over every body.

### Python packages

Stdlib only, zero pip dependencies. Register a new package in `EXPECTED` in
`apps/install-python-packages`, in `python-packages/README.md`, and in the loop
in `apps/built-apps-verify`. Every tool must answer `-h` or `--version`
non-interactively — but **that smoke test never reaches the code that does the
work**, and neither does a syntax check. A missing `datetime` import once
shipped in `rmi`. `just lint-python` (ruff F821 undefined names) and
`just test-python` exist for exactly that.

---

## 7. Known traps

- **Verify gates must match what `systemctl enable` actually does.** In a
  container it writes `/etc/systemd/system/<target>.wants/…`. Gate with
  `systemctl is-enabled`.
- **Prove every new gate can fail.** Invert it once and confirm exit 1.
  `final-verify` once carried a "terra repos all disabled" gate whose glob
  `finalize` had already deleted — it could never fail. Also beware
  `test "${VAR}" = "$(...)"` when both sides can be empty.
- **Do not gate what you have not checked exists.** No `/opt` gate (Brave), no
  comment-sensitive `grep` over shipped recipes.
- **`install-pyprland`**: upstream ships `systemd-unit/pyprland.service`, so an
  `else` branch never runs. Anything that must apply to both units (the
  `ConditionEnvironment` drop-in) lives **outside** that `if`.
- **`ConditionEnvironment=` on a user unit** reads the _systemd user manager's_
  environment; the session must export `XDG_CURRENT_DESKTOP` into it.
- **The brew timers gate on a symlink** (`ConditionPathIsSymbolicLink`).
  `brew-verify` asserts the payload keeps `bin/brew` a symlink.
- **The Brewfile is deliberately three formulas** (`bun`, `pixi`, `opencode`).
  Brew dirs are appended to PATH, so a brewed duplicate of an RPM can never run.
- **Package names change between Fedora releases** (`terra-gamescope` retired;
  lazygit ships as `golang-github-jesseduffield-lazygit`). `dnf5` aborts the
  _whole transaction_ on one bad name — verify before adding, and do not assume
  a tool exists in Fedora because it exists upstream (`gum` is built in a ublue
  staging COPR).
- **Build-tool preconditions are invisible dependencies** (`zstd`,
  `util-linux-core`, `gnupg2`, `jq`, `gcc-c++`); `packages-verify` gates them.
- **CI runners are pinned to `ubuntu-24.04`.** `ubuntu-latest` migrates to 26.04
  between 2026-10-19 and 2026-11-19, and `ublue-os/remove-unwanted-software@v9`
  is not compatible with 26.04.
- **Scheduled workflows run only from the default branch**, and `build.yml`
  publishes only from `PUBLISH_BRANCH` (`container`).

---

## 8. CI

- `lint.yml`: `just check`, `just lint`, `.github` audit, actionlint, ruff, pytest.
- `semantic-pr.yml`: PR-title Conventional Commits check (title only).
- `build.yml`: publish gate → COPR wait → both syntax gates → `just build` →
  `verify/` suite → census → tags → (publish branch only) push, sign, verify.
- `clean.yml`: weekly GHCR pruning.

If you add a COPR the build consumes, add its `repomd.xml` URL to the `URLS`
array in the "Wait for Copr metadata availability" step.

---

## 9. Checklist before proposing a change

- [ ] `just check` and `just lint` pass.
- [ ] `just lint-python` / `just test-python` pass if you touched python helpers.
- [ ] New install stage has a `<stage>-verify` companion in the same RUN.
- [ ] Every new gate has been inverted once and confirmed to fail.
- [ ] New `dnf5 install` uses `--setopt=install_weak_deps=False`.
- [ ] Any third-party repo enabled is disabled in the same stage.
- [ ] Every binary a new recipe calls is in `packages.json` and gated.
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`.
- [ ] New files in `usr/bin` / `usr/libexec` are mode 0755.
- [ ] Workflows: no branch pins, no `ubuntu-latest`, signing flags untouched.
- [ ] Comments that describe _why_ are preserved — they are the design docs.
