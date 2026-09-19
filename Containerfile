# halcyon — bootc Containerfile following the ublue-os/bazzite project
# structure (https://github.com/ublue-os/bazzite): scratch `ctx` stage with
# semantic unnumbered build helpers, whole-ctx bind mount per RUN, ARG-only
# configuration, per-RUN third-party repo enable→disable, /ctx/cleanup after
# every image-mutating RUN, bootc container lint as the hermetic final gate.
#
# Build locally:
#   podman build --pull -t localhost/halcyon:latest .
#
# Verification is per-level (main-branch pattern): every install stage is
# immediately followed by its <stage>-verify companion so failures surface at
# that level. Removals run FIRST (remove-packages) — main's removals.yml
# ordering — so dnf computes the removal set on the smallest, pristine graph;
# keeper packages are gated against the FINAL state in final-verify.

ARG FEDORA_VERSION=44

# --- build context: semantic helpers, never baked into the image ---
FROM scratch AS ctx
COPY build_files /

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

# CI passes --build-arg for the two volatile values (bazzite convention:
# version = <fedora-major>.<yyyymmdd>, revision = git sha)
ARG IMAGE_VERSION="44.0"
ARG SOURCE_SHA="unknown"

LABEL org.opencontainers.image.title="halcyon" \
      org.opencontainers.image.description="Lean Hyprland gaming desktop — fedora-bootc + p03 kernel + NVIDIA open (negativo17 userland) + noctalia greeter + ujust/uupd" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_SHA}" \
      org.opencontainers.image.source="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.url="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.vendor="aahsnr-work" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="aahsnr-work" \
      io.artifacthub.package.readme-url="https://raw.githubusercontent.com/aahsnr-work/halcyon/container/README.md" \
      halcyon.base="fedora-bootc-p03" \
      halcyon.desktop="hyprland-noctalia"

# static system tree (configs, units, ujust modules, theme, wallpaper)
COPY system_files/shared/ /

# dnf5 patience drop-in MUST land in the first RUN — it exists to survive
# Copr 504s during the very stages that follow (libdnf5 reads
# /etc/dnf/libdnf5.conf.d/ before the main config).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    install -Dm0644 /ctx/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# ---- Stage 1: removals FIRST — pristine-base blast radius (main ordering) --
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/remove-packages && /ctx/cleanup

# ---- Stage 2: shared external repos (RPM Fusion NVIDIA-excluded + negativo17)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/setup-repos && /ctx/cleanup

# ---- Stage 3: p03 kernel + prebuilt nvidia-open modules (Stage K1) ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-kernel && /ctx/cleanup

# ---- Stage 4: core + desktop + gaming + apps -------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-packages && /ctx/packages-verify && /ctx/cleanup

# ---- Stage 5: Terra packages (user-editable list, exclusive resolution) ----
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-terra && /ctx/cleanup

# ---- Stage 6: devtools (Fedora brew-formula replacements) ------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-devtools && /ctx/cleanup

# ---- Stage 7: nix (winter pattern) ------------------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-nix && /ctx/nix-verify && /ctx/cleanup

# ---- Stage 8: flatpak (flathub USER repo only) ------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/setup-flatpaks && /ctx/flatpaks-verify && /ctx/cleanup

# ---- Stage 9: built apps (obsidian/zotero/pyprland/texlive/python) ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/install-built-apps && /ctx/built-apps-verify && /ctx/cleanup

# ---- Stage 10: ujust machinery (ublue-os-just) + uupd -----------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/setup-ujust && /ctx/ujust-verify && /ctx/cleanup

# ---- Stage 11: system config (services, tmpfiles, chezmoi wiring) ----------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/configure-system && /ctx/system-verify && /ctx/cleanup

# ---- Stage 12: branding (os-release identity + plymouth theme) --------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/image-info && /ctx/branding-verify && /ctx/cleanup

# ---- Stage 13: initramfs LAST (plymouth theme + nvidia hooks baked in) ------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/build-initramfs && /ctx/cleanup

# ---- Stage 14: finalize (repo sweep + end-of-build hygiene) -----------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/finalize

# ---- Stage 15: final cross-cutting verification ------------------------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    /ctx/final-verify

# ---- Final gate: hermetic bootc lint (bazzite pattern) -----------------------
RUN --mount=type=tmpfs,target=/run --network=none ["bootc","container","lint"]
