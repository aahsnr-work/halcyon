# halcyon — plain Containerfile (bootc), replacing the BlueBuild recipe set.
# Build locally:  podman build --pull -t localhost/halcyon:latest .
#
# Base: quay.io/fedora/fedora-bootc (standard; MIGRATION.md §2) — clean slate,
# no kernel assumptions. Stage 2 replaces the stock kernel with p03
# (COPR catpieleaf/kernel-p03, Stage K1) + its prebuilt nvidia-open modules;
# the NVIDIA userland comes from negativo17 (same 615.71.09 driver line —
# the ublue-os/akmods partition: NVIDIA sourced ONLY from negativo17, and the
# RPM Fusion repos exclude NVIDIA packages so the solver can never mix the
# two), so no akmods/DKMS anywhere.
#
# Repo lifecycle policy (bazzite pattern + TODO "remove non-fedora repos
# after use"): every third-party repo — COPRs, terra, vscode, brave — is
# enabled ONLY inside the stage that consumes it and disabled immediately
# after; 80-finalize.sh removes all leftover repo files so the shipped image
# carries none. Updates arrive via image rebuilds (bootc).
#
# Build scripts never enter the image: they live in the `ctx` scratch stage
# and are bind-mounted into the RUN steps that need them (bazzite pattern).
# Every image-mutating RUN ends with /ctx/build.d/cleanup.

ARG FEDORA_VERSION=44

# --- build context: never baked into the image ---
FROM scratch AS ctx
COPY build.d /build.d
COPY files /files

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

LABEL org.opencontainers.image.title="halcyon" \
      org.opencontainers.image.description="Lean Hyprland gaming desktop — fedora-bootc + p03 kernel + NVIDIA open (negativo17 userland) + noctalia greeter + ujust/uupd" \
      org.opencontainers.image.source="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.vendor="aahsnr-work" \
      org.opencontainers.image.licenses="MIT" \
      halcyon.base="fedora-bootc-p03" \
      halcyon.desktop="hyprland-noctalia"

# static system tree (configs, units, theme, wallpaper, helper scripts)
COPY files/system/ /

# dnf5 retry/timeout drop-in (keeps external repos patient during builds)
RUN --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    install -Dm0644 /ctx/build.d/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# Stage 1 — shared external repos: RPM Fusion (NVIDIA-excluded) + negativo17
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/01-repos.sh && /ctx/build.d/cleanup

# Stage 2 — p03 kernel + nvidia-open (MIGRATION §4.2 Stage K1)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/02-kernel.sh && /ctx/build.d/cleanup

# Stage 3 — core + desktop + gaming + apps (COPRs/vendor repos per-use)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/10-packages.sh && /ctx/build.d/cleanup

# Stage 4 — Terra packages (user-editable list; repo per-use, then disabled)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/11-terra.sh && /ctx/build.d/cleanup

# Stage 5 — prune, AFTER packages (guarded-removals keepers need them)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    --mount=type=bind,from=ctx,source=/files,target=/ctx/files,ro \
    /ctx/build.d/30-prune.sh && /ctx/build.d/cleanup

# Stage 6 — devtools (Fedora brew-formula replacements; monorepo RPMs later)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/40-devtools.sh && /ctx/build.d/cleanup

# Stage 6a — nix (winter pattern: RPM + nix.mount/var-nix, profile+tmpfiles
# via the static tree) — before devtools so ~ 40-devtools can assume nix
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/32-nix.sh && /ctx/build.d/cleanup

# Stage 7 — flatpak: package + flathub USER repo only (no system flathub,
# no fedora flatpaks); the four apps install at first login
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/21-flatpak-setup.sh && /ctx/build.d/cleanup

# Stage 8 — built apps (obsidian/zotero/pyprland/texlive/python; MIGRATION §8)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    --mount=type=bind,from=ctx,source=/files,target=/ctx/files,ro \
    /ctx/build.d/41-built-apps.sh && /ctx/build.d/cleanup

# Stage 9 — ujust machinery (ublue-os-just) + uupd + vendored recipes
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    --mount=type=bind,from=ctx,source=/files,target=/ctx/files,ro \
    /ctx/build.d/50-ujust.sh && /ctx/build.d/cleanup

# Stage 10 — system config: units, services, tmpfiles, chezmoi wiring
RUN --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    --mount=type=bind,from=ctx,source=/files,target=/ctx/files,ro \
    /ctx/build.d/50-system.sh && /ctx/build.d/cleanup

# Stage 11 — branding: os-release identity + plymouth theme assets
RUN --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    --mount=type=bind,from=ctx,source=/files,target=/ctx/files,ro \
    /ctx/build.d/60-branding.sh && /ctx/build.d/cleanup

# Stage 12 — initramfs LAST (plymouth theme + nvidia hooks baked in)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/70-initramfs.sh && /ctx/build.d/cleanup

# Stage 13 — finalize: remove every third-party repo file (bazzite pattern)
RUN --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/80-finalize.sh

# Stage 14 — verification gates (same semantics as the BlueBuild-era scripts)
RUN --mount=type=bind,from=ctx,source=/build.d,target=/ctx/build.d,ro \
    /ctx/build.d/90-verify.sh

# Final check — same one ublue/base-main runs
RUN ["bootc", "container", "lint"]
