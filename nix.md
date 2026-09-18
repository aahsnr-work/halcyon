# nix.md — how RakuOS sets up Nix (research notes)

This document only **explains** how the RakuOS project handles Nix. Nothing
in it is implemented in halcyon — halcyon already runs Nix via the
fu5ha/winter bind-mount pattern (see `recipes/modules/nix.yml` and the
README's Nix section).

## RakuOS in one paragraph

RakuOS (by CatPieLeaf, of the P03 kernel) is a **hybrid atomic** Fedora
distribution: an immutable base image with a **persistent overlay mounted on
`/usr`**, so native packages can be installed with `dnf` (or RakuOS's own
`rum` package manager) and survive updates. Editions: KDE, GNOME, niri,
COSMIC — plus NVIDIA variants. It defaults to the **P03 kernel**
(CatPieLeaf's patched kernel, also packaged for plain Fedora via the
`catpieleaf/kernel-p03` COPR).

## How Nix is set up

RakuOS's base image repo (`RakuOS/rakuos-base` on GitHub/GitLab, generated
from `ublue-os/image-template`) seeds the Nix mountpoint at build time:

```dockerfile
RUN mkdir -p /var/nix && ln -s /var/nix /nix
```

That is the **only Nix-specific line** in its build. Everything else comes
from the runtime model:

1. `/var` is the persistent half of a hybrid-atomic system, so
   `/var/nix` (reached through the `/nix` symlink) survives updates and
   rebases.
2. RakuOS's overlay unit stack (`rakuos-overlay-mount`,
   `rakuos-overlay-sync`, `rakuos-overlay-services`,
   `rakuos-overlay-sync` Plymouth messages, `rakuos-cache-clean.timer`)
   keeps the overlay consistent across upgrades.
3. Nix itself is then installed **at runtime** by the user (Determinate
   Nix installer or Fedora's `nix` package) — the distribution does not
   bake a Nix store into the image, and no first-boot Nix service ships in
   the base repo.

So RakuOS's approach is: **prepare the mountpoint in the image, let the
user bring Nix, persist through `/var`**.

## Comparison with halcyon

| | RakuOS | halcyon |
| --- | --- | --- |
| Mountpoint seeding | `ln -s /var/nix /nix` in the Containerfile | empty `/nix` dir + `nix.mount` bind unit (`var-nix.service` creates `/var/nix`) |
| Persistence | overlay on `/usr` + `/var` | `/var/nix` bind-mounted on `/nix` |
| Store dir tmpfiles | — (store arrives at runtime) | `nix.conf` tmpfiles entries for `/nix/store`, `/nix/var` |
| Profile hook | — | `files/nix-profile/00-nix-resolve-home-env.sh` |
| Nix packages | runtime install | `nix` + `nix-daemon` RPMs baked, `nix-daemon` enabled |

The two designs converge on the same core idea — real state under `/var`,
immutable tooling under `/usr` — but halcyon ships a working Nix daemon
out of the box, while RakuOS treats Nix as an optional runtime add-on.

## What was deliberately not ported

- RakuOS's **Containerfile build system** — halcyon stays on BlueBuild.
- **rum** — RakuOS's Rust `dnf` replacement (`packages/rakuos` on their
  GitLab); it exists to drive their overlay system, which halcyon does not
  use.

## Sources

- `RakuOS/rakuos-base` — `Containerfile` (nix mountpoint line), overlay
  units enabled in `build_files/build.sh`.
- [rakuos.org](https://rakuos.org/) / [download](https://rakuos.org/download)
  — editions, P03 default, native-gaming statement.
- [catpieleaf/kernel-p03 COPR](https://copr.fedorainfracloud.org/coprs/catpieleaf/kernel-p03/)
  and [CatPieLeaf/linux-p03](https://github.com/CatPieLeaf/linux-p03) — P03
  kernel.
