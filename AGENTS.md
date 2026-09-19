# AGENTS.md

Instructions for AI coding agents (e.g. GLM-5.3-Flash) working in this repository.

## What this repo is

**halcyon** — a lean, Hyprland-first gaming desktop as a **bootc OCI image**
(`ghcr.io/aahsnr-work/halcyon`), built from `quay.io/fedora/fedora-bootc:44`
with the **p03 kernel** (COPR `catpieleaf/kernel-p03`) + its prebuilt
**nvidia-open** modules and the **negativo17** NVIDIA userland (no akmods/DKMS
anywhere). The `container` branch replaces the old BlueBuild recipe set (still
on `main`) with a plain Containerfile following the
[ublue-os/image-template](https://github.com/ublue-os/image-template) /
[bazzite](https://github.com/ublue-os/bazzite) conventions. The full migration
plan and every architectural decision (D1–D19) live in **MIGRATION.md** — read
it before making structural changes.

## Commands

```bash
just check            # Justfile fmt-check + bash -n across every build_files helper
just lint             # shellcheck on all build_files helpers (extensionless bash)
just build            # full image build: podman build + OCI/artifacthub labels
                      #   (= exactly what CI runs; ~40 min, needs network)
just package-count    # run the built image, print total RPMs + p03 kernel
just image_name       # echo the image name from halcyon.env (CI uses this)

podman run --rm --entrypoint /bin/bash localhost/halcyon:latest -c 'rpm -qa | wc -l'
                      # smoke-test anything inside the built image
```

Quick validation without a full build (do this before every commit):

```bash
just check && just lint
grep -rn "dnf5 -y install" build_files/ | grep -v install_weak_deps | grep -vE "remove|download|# |copr|config-manager"
```

The grep must return nothing — every `dnf5 install` carries
`--setopt=install_weak_deps=False`.

## Layout

- `Containerfile` — the ONLY ordering source. Scratch `ctx` stage (build
  helpers are bind-mounted, never baked into the image), one RUN per stage,
  each followed by `/ctx/cleanup`, hermetic final `bootc container lint
  --network=none`.
- `build_files/` — semantic, unnumbered helpers. Install stages are followed
  by their `*-verify` companion (e.g. `install-packages` → `packages-verify`);
  `remove-packages` runs FIRST (pristine-base removals, main's ordering);
  `build-initramfs` runs LAST before `finalize`/`final-verify`. Shared things:
  `cleanup`, `libdnf5.conf.d/`, `scripts/` (build-time per-app installers),
  `python-packages/` (staged to `/usr/src` and installed by
  `install-python-packages`).
- `system_files/shared/` — static overlay copied verbatim onto `/` by the
  rootfs stage. ujust modules live at
  `system_files/shared/usr/share/ublue-os/just/`, systemd units at
  `.../usr/lib/systemd/{system,user}/`.
- `Justfile` + `halcyon.env` — CI task runner + image parameters.
- `.github/workflows/build.yml` — Justfile-driven CI: Copr health-wait →
  `just check` → `just build` → package-count report (run summary +
  `::notice::`) → tag/push → cosign-sign the manifest digest.

## Hard conventions (violations have broken builds before)

1. **`--setopt=install_weak_deps=False` on EVERY `dnf5 install`.** One package
   per line in install lists. Anything that used to arrive as a weak dep must
   be listed explicitly (e.g. `flatpak-selinux`, `pcsc-lite`,
   `hyprland-guiutils`).
2. **Repo lifecycle:** third-party repos (COPRs, terra, vscode, brave) are
   enabled only inside the stage consuming them and disabled immediately
   after; `finalize` deletes every third-party repo file. The image ships
   Fedora repos only.
3. **Terra is exclusive:** transactions in `install-terra` use
   `--disablerepo='*' --enablerepo='terra*'` — no Fedora fallback, no
   `--skip-unavailable`; a missing package must fail the build. `TERRA_PKGS`
   is the user-editable list.
4. **NVIDIA partitioning:** NVIDIA packages come ONLY from negativo17; every
   RPM Fusion repo file excludes `xorg-x11-drv-nvidia* akmod-nvidia
   kmod-nvidia* nvidia-*`. The four kmod-entangled negativo17 subpackages
   (`nvidia-driver`, `nvidia-driver-cuda`, `nvidia-settings`,
   `nvidia-kmod-common`) are payload-extracted via `rpm2cpio`, never installed.
5. **Kernel stage:** install with `tsflags=noscripts` (RPM scriptlets fail in
   containers), remove the stock kernel with an installed-only list and
   `remove --no-autoremove` (dnf5 arg order: options that belong to a
   subcommand come AFTER the subcommand), keep the
   `CONFIG_SECURITY_SELINUX=y` gate, run `semodule -i` for
   `nvidia-driver-selinux` explicitly, `depmod` only — dracut is deferred to
   `build-initramfs` (plymouth theme + nvidia hooks must exist first).
6. **Never vendor rpm-owned files.** `10-update.just` and `justfile` are owned
   by the `ublue-os-just` RPM; halcyon modules register through the
   `60-custom.just` hook in `setup-ujust`. File names in that import list must
   match `system_files/shared/usr/share/ublue-os/just/` exactly.
7. **Keeper gates live in `final-verify`** (they gate the final state). Use
   full package names — Terra's Go packages rename things
   (`golang-github-jesseduffield-lazygit`, not `lazygit`).
8. **determinism:** no unpinned downloads; if an upstream publishes no
   checksums, say so in a comment (see `scripts/install-zotero`).

## Verification before you commit

1. `just check && just lint`
2. The install-flag grep above returns nothing.
3. If you touched ujust modules: import list ↔ files ↔ `ujust-verify` gates
   all agree.
4. If you touched packages: every new package resolves in the repo you claim
   it comes from (check live repodata — package names die quietly:
   `terra-gamescope` no longer exists).
5. Commit with conventional messages (`feat!:`, `fix:`, `docs:`), push to the
   `container` branch, and watch the workflow run. A local full build is
   `just build localhost/halcyon latest`.

## Known pitfalls

- The ctx pattern means **any `build_files/` change re-runs all stages** in a
  local rebuild; CI always builds fresh.
- dracut errors are fatal with `--no-hostonly` (`Module 'pcsc' cannot be
  installed` fails the build) — satisfy or omit the module deliberately.
- `dnf5 remove` aborts the whole transaction on one absent argument — filter
  the list by `rpm -q` first (see `install-kernel`).
- COPR metadata 504s: CI polls repodata before building; dnf5 retries are
  configured in `build_files/libdnf5.conf.d/`.
- `notes/` is the owner's private scratch space — never commit it.
