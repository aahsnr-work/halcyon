# AGENTS.md — halcyon

Guidance for AI coding agents (and humans) working in this repository.
Branch of record: `container`.

---

## 1. What this repo is

`halcyon` builds a **single bootc OCI image**: a lean Hyprland gaming desktop on
`quay.io/fedora/fedora-bootc:44`, with the `catpieleaf/kernel-p03` kernel,
prebuilt `nvidia-open` modules, negativo17 NVIDIA userland, the noctalia greeter
on greetd, and `ujust`/`uupd` for user-facing system tasks.

It is **not** a BlueBuild project and **not** layered on Bazzite. It borrows
Bazzite's *repo structure* (scratch `ctx` stage, semantic unnumbered build
scripts, per-RUN bind mount, `cleanup` after every mutating RUN, `bootc
container lint` as the final gate) and vendors some Bazzite `.just` recipes and
Steam wrappers, but the base is plain `fedora-bootc`.

Output: `ghcr.io/aahsnr-work/halcyon:<tag>`, cosign-signed in CI.

---

## 2. Repository layout

```
Containerfile              # 15 numbered stages + hermetic bootc lint
Justfile                   # check / fix / lint / build / tag / package-count
halcyon.env                # dotenv consumed by the Justfile (IMAGE_NAME, etc.)
cosign.pub                 # public signing key (see §7 "signing gap")
.containerignore           # keep docs/artifacts out of the build context

build_files/               # the `ctx` stage — NEVER ends up in the image
  cleanup                  # end-of-RUN hygiene, called after every mutating RUN
  libdnf5.conf.d/          # dnf5 main-config drop-in (see §7)
  python-packages/         # 11 stdlib-only src-layout Python tools
  base/                    # repos + removals: setup-repos, remove-packages,
                           #   guarded-removals, file-footprint, gnome-extensions,
                           #   fonts-cleanup
  kernel/                  # install-kernel (p03 + NVIDIA)
  packages/                # install-packages + packages-verify, install-terra,
                           #   install-devtools
  apps/                    # install-built-apps + built-apps-verify and the
                           #   per-app installers (obsidian, zotero, pyprland,
                           #   texlive, python-packages)
  runtime/                 # install-nix + nix-verify, setup-flatpaks +
                           #   flatpaks-verify, setup-ujust + ujust-verify
  desktop/                 # configure-system + system-verify, image-info,
                           #   build-plymouth-assets + branding-verify
  finish/                  # build-initramfs, finalize, final-verify

Scripts are extensionless bash at `<folder>/<verb>-<subject>`; verify
companions live next to the stage they gate inside the same folder.

system_files/shared/       # static tree COPY'd to / BEFORE any RUN stage
  etc/…  usr/…             # units, profile.d, greetd, plymouth, ujust modules,
                           # /usr/libexec/halcyon-image/* helper scripts
```

**Naming:** build scripts are extensionless bash with `#!/usr/bin/env bash` and
`set -euo pipefail`. Verify scripts are named `<stage>-verify` and are invoked
in the same `RUN` as the stage they gate.

---

## 3. Commands

```bash
just check          # just --fmt --check + bash -n on every build_files script
just lint           # shellcheck --shell=bash on every build_files script
just build          # podman build with the CI label/ARG scheme
just package-count  # run the built image, report RPM count + kernel version

podman build --pull -t localhost/halcyon:latest .   # plain local build
```

Python packages (each is standalone, src-layout, stdlib-only):

```bash
cd build_files/python-packages
python3 -m venv .venv && .venv/bin/pip install -e './dump-to-markdown[dev]'
.venv/bin/pytest dump-to-markdown
```

`dump-to-markdown` is the only package with a test suite. If you add tests
elsewhere, add `[project.optional-dependencies] dev = ["pytest"]` and a
`[tool.pytest.ini_options] testpaths = ["tests"]` block to its `pyproject.toml`
to match.

**Always run `just check` and `just lint` before proposing a change to anything
under `build_files/`.** A missing `fi` or an unquoted expansion in a build
script costs a full ~40-minute CI build.

---

## 4. Build architecture — rules that must not be broken

1. **Stage order is load-bearing.** Removals run *first* (against the pristine
   base, smallest dependency graph); the initramfs is built *last* (so the
   plymouth theme and NVIDIA dracut hooks are baked in); `finalize` and
   `final-verify` close the build. Do not reorder without re-reading the
   comments in `Containerfile` and `remove-packages`.

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
   only Fedora repo files remain. **The shipped image carries no third-party
   repo files** — updates arrive as image rebuilds.

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
   `rpm-ostree status`. Any recipe that shells out to `rpm-ostree` is a bug.

---

## 5. bootc / image constraints

- `/var` must be effectively empty in the image. Content there without a
  matching `tmpfiles.d` entry triggers the `var-tmpfiles` lint warning, and
  anything you put there is only applied on *initial provisioning* — later
  upgrades will not see it. Create runtime state with `tmpfiles.d` (see
  `usr/lib/tmpfiles.d/zz-halcyon-nix.conf`, `noctalia-greeter-state.conf`) or a oneshot
  unit (see `var-nix.service`).
- `/var/run` must remain a symlink to `/run` — that lint is a hard failure.
- `/boot` must be empty; the kernel lives in `/usr/lib/modules/<kver>/`.
- No `/opt` or `/usr/local` writes; use `/usr/lib/<app>` plus a `/usr/bin`
  symlink (see `install-obsidian`, `install-zotero`, `install-pyprland`).
- The final `RUN … ["bootc","container","lint"]` runs with `--network=none` and
  a tmpfs `/run`. Anything needing the network must happen before it.

---

## 6. Conventions by file type

### Build scripts (`build_files/*`)
- `#!/usr/bin/env bash` + `set -euo pipefail` (use `set -uo pipefail` only when
  the script deliberately accumulates failures and returns its own `rc`).
- Wrap output in `echo "::group::<script> — <phase>"` / `echo "::endgroup::"`
  so GitHub Actions folds it. Use the `  OK  ` / `  WARN  ` / `  FAIL  ` /
  `  SKIP  ` / `  INFO  ` prefixes already in use.
- One package per line in `dnf5 install` lists, alphabetical within a block,
  with a comment naming the block's purpose.
- If a script tolerates failure (`|| true`), the corresponding verify gate must
  tolerate it too. Mismatches between "optional at install" and "required at
  verify" are a recurring source of red builds.

### Static tree (`system_files/shared/**`)
- This tree is COPY'd **before** any package install. An RPM installed in a
  later stage that owns the same path **will overwrite your file**. When
  shipping a file that an RPM may also own (`tmpfiles.d`, `sysusers.d`,
  `/etc/<pkg>/…`), prefix it so it cannot collide *and* sorts later —
  e.g. `usr/lib/tmpfiles.d/zz-halcyon-nix.conf` — and add a verify gate
  asserting the final content.
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
- Register new modules by adding the filename to the loop in `setup-ujust`,
  which writes `/usr/share/ublue-os/just/60-custom.just`; the ublue-os-just
  justfile picks it up via `import? "/usr/share/ublue-os/just/60-custom.just"`.
- Interactive recipes `source /usr/lib/ujust/ujust.sh` and use `Choose`.
  **Prefer `Choose` over `ugum`** — `ugum` is a `gum` wrapper and `gum` is not
  an explicit install in this image.
- Recipe bodies are shell scripts, and `just --fmt --check` does **not** parse
  them. Syntax-check a new recipe body by hand:
  `just --show <recipe> | tail -n +2 | bash -n -`.
- Vendored Bazzite recipes must be de-Bazzited: no `rpm-ostree`, no
  `/usr/libexec/bazzite-boot-remount`, no `fpaste`/`wl-copy`/`zenity` unless the
  package is actually installed by `install-packages`.

### Python packages
Stdlib only, zero pip dependencies — the shared venv at
`/usr/lib/halcyon-python` has no dependency resolution safety net. Add the
package directory name to `EXPECTED` in `install-python-packages`, to the table
in `build_files/python-packages/README.md`, and to the loop in
`built-apps-verify`. Every tool must answer `-h` or `--version` non-interactively;
that is the build-time smoke test.

---

## 7. Known traps (read before touching these areas)

- **The `ctx` stage is FLAT.** `COPY build_files /` puts helpers at
  `/ctx/<name>` (e.g. `/ctx/install-packages`, `/ctx/libdnf5.conf.d/…`) —
  **not** `/ctx/build_files/<name>`. A nested path fails with
  `install: cannot stat`.
- **`rpm -q` is case-sensitive** while dnf is not: the Fedora package is
  `Thunar` (capital T) — `dnf install thunar` succeeds and `rpm -q thunar`
  fails. Query gates with the exact upstream name.
- **`just --list` does not parse recipe bodies.** Recipe-body syntax is
  covered by `just check` (bash -n) — extend that check, don't trust
  `--list`, and run `just --show <recipe>` when editing a recipe.
- **Verify gates must match what `systemctl enable` actually does.**
  `systemctl enable foo` in a container writes
  `/etc/systemd/system/<target>.wants/foo`, **not** `/usr/lib/systemd/...`.
  Gate with `systemctl is-enabled`, or test the `/etc` path.
- **`install-pyprland`**: upstream *does* ship `systemd-unit/pyprland.service`,
  so the `else` branch (inline unit) never runs. Anything that must apply to
  both paths (the `ConditionEnvironment` drop-in) lives **outside** that `if`.
- **`ConditionEnvironment=` on a user unit** reads the *systemd user manager's*
  environment. It only works if the session exports `XDG_CURRENT_DESKTOP` into
  it (`dbus-update-activation-environment --systemd` / `systemctl --user
  import-environment`). Verify in the Hyprland config, not just in the unit.
- **Signing**: `ostree-image-signed:docker://…` verification requires the
  pubkey **inside the image** plus matching `policy.json`/`registries.d`
  entries — `image-info` ships all three; keep them in sync.
- **The removals machinery is largely inherited from the Bazzite-fork era.**
  `guarded-removals`, `file-footprint`, `gnome-extensions` and `fonts-cleanup`
  mostly no-op on a bare `fedora-bootc` base and several of their comments
  describe an ordering that no longer holds. Treat their comments as historical.
- **Package names change between Fedora releases.** Terra retired
  `terra-gamescope`/`terra-mangohud`; `lazygit` ships as
  `golang-github-jesseduffield-lazygit`. Before adding a package, verify it
  resolves for F44 from the repo you expect:
  `dnf5 repoquery --repo=<id> --qf '%{name}\n' <name>`.

---

## 8. CI

`.github/workflows/build.yml`: polls the consumed COPR repodata (Copr's CDN
intermittently 504s), then `just check` → `just build` → package-count report →
tag → push to GHCR → cosign sign the manifest digest. Push and sign only run on
branch pushes, not PRs.

If you add a COPR that the build consumes, add its `repomd.xml` URL to the
`URLS` array in the "Wait for Copr metadata availability" step.

---

## 9. Checklist before proposing a change

- [ ] `just check` and `just lint` pass.
- [ ] Recipe bodies syntax-checked (`bash -n`) if you touched a `.just` file.
- [ ] New install stage has a `<stage>-verify` companion wired into the same RUN.
- [ ] New `dnf5 install` uses `--setopt=install_weak_deps=False`.
- [ ] Any third-party repo enabled is disabled in the same stage.
- [ ] Nothing new lands in `/var`, `/opt`, `/usr/local` or `/boot`.
- [ ] New files in `system_files/shared/usr/bin` or `usr/libexec` are mode 0755.
- [ ] No new path collides with an RPM-owned path installed in a later stage.
- [ ] Comments that describe *why* (upstream bug, dependency conflict, ordering
      constraint) are preserved — this repo's comments are its design docs.
- [ ] No `rpm-ostree`, no Bazzite-only binary, no unlisted runtime dependency.
