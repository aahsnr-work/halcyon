# halcyon — plain Containerfile (bootc), replacing the BlueBuild recipe set.
# Build locally:  podman build --pull -t localhost/halcyon:latest .
# Base: quay.io/fedora/fedora-bootc — clean slate, no kernel assumptions
# (MIGRATION.md §2). Stage 2 replaces the stock kernel with p03
# (COPR catpieleaf/kernel-p03, Stage K1) + its prebuilt nvidia-open modules;
# the NVIDIA userland comes from negativo17 (same 615.71.09 driver line —
# the rakuos-base pattern), so no akmods/DKMS anywhere.
FROM quay.io/fedora/fedora-bootc:44

COPY build.d /tmp/build.d
COPY files/system/ /
COPY files/scripts/ /tmp/build.d/scripts/
COPY files/justfiles/ /tmp/build.d/justfiles/
COPY files/systemd/ /tmp/build.d/systemd/

# dnf5 retry/timeout drop-in (keeps external repos — COPR/negativo17/Terra —
# patient during builds)
RUN install -Dm0644 /tmp/build.d/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# Stage 1 — repositories: RPM Fusion, negativo17 (nvidia userland), halcyon
# COPRs (transitional), vendor repos
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/01-repos.sh

# Stage 2 — p03 kernel + nvidia-open (MIGRATION §4.2 Stage K1)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/02-kernel.sh

# Stage 3 — prune what fedora-bootc ships that halcyon rejects
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/02-prune.sh

# Stage 4 — core + desktop + gaming + apps packages (transitional: COPRs)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/10-packages.sh

# Stage 5 — devtools (Fedora brew-formula replacements; monorepo RPMs later)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/40-devtools.sh

# Stage 6 — flatpak transition (first-boot installer; RPM conversion is later)
RUN /tmp/build.d/21-flatpak-setup.sh

# Stage 7 — built apps (obsidian/zotero/pyprland/texlive/python; MIGRATION §8)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    /tmp/build.d/41-built-apps.sh

# Stage 8 — system config: units, services, tmpfiles, ujust shim, branding
RUN /tmp/build.d/50-system.sh
RUN /tmp/build.d/60-branding.sh

# Stage 9 — initramfs (last, so the p03 initrd bakes in plymouth + the
# halcyon theme + the NVIDIA driver hooks — rakuos-base ordering)
RUN /tmp/build.d/70-initramfs.sh

# Stage 10 — verification gates (same semantics as the BlueBuild-era scripts)
RUN /tmp/build.d/90-verify.sh

# Final check — same one ublue/base-main runs
RUN ["bootc", "container", "lint"]
