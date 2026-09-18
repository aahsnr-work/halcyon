# ANDAMAN-MIGRATION.md — halcyon package pipeline migration plan

**Status:** plan (not yet executed)
**Date:** 2026-09-19
**Scope:** replace the COPR dependencies (`lionheartp/Hyprland`, later `sneexy/zen-browser`) with a personal RPM monorepo built with fyralabs' **anda** toolchain on GitHub Actions, served from **GitHub Pages**, and consumed by this image instead of COPR.
**Decisions locked:** serving = GitHub Pages · builds = anda in Actions · scope = Hyprland stack first, rest later · monorepo = `aahsnr-work/halcyon-packages`.

---

## 1. Why (goals & non-goals)

**Goals**

- Remove the build's dependency on `download.copr.fedorainfracloud.org`, which intermittently 504s at the CDN edge (see the dnf5 retry drop-in and CI health-wait step shipped in `ae6cb64` — both are mitigations, not cures).
- Own the full pipeline: spec files, version bumps, build, signing, publishing — no third-party maintainer latency (e.g. waiting for `lionheartp` to rebuild `noctalia-greeter-git` after a Hyprland ABI bump).
- Keep the provenance guarantees this image already enforces, but pointed at our own signing identity instead of a COPR vendor string.

**Non-goals**

- No change to packages that already come from Fedora proper (cliphist, qt6ct, nwg-look\*, greetd, kitty, thunar, papers, gnome-keyring/tweaks, papirus-icon-theme, xdg-desktop-portal-gtk) — they stay on Fedora repos.
- No change to vendor repos that work: brave (S3 repo), code (Microsoft), zed (Terra repo — already consumed as a plain `files:` repo, the exact pattern we will copy).
- No koji, no Fyra Labs infrastructure — Subatomic's public instance is employees-only (see §3.3).

\* nwg-look is currently installed alongside the COPR set; confirm its origin with `rpm -q --qf '%{VENDOR}' nwg-look` before Phase 4 and keep it on whichever repo actually ships it.

---

## 2. TL;DR target architecture

```
aahsnr-work/halcyon-packages (monorepo, anda manifests + specs + update scripts)
        │  push / PR  →  GitHub Actions
        ▼
anda ci  →  build matrix (changed packages)
        ▼
anda build  in ghcr.io/terrapkg/builder:f44 (privileged mock container)
        ▼
rpmsign (GPG)  →  createrepo_c  →  gpg detach-sign repomd.xml
        ▼
GitHub Pages  https://aahsnr-work.github.io/halcyon-packages/fedora/44/x86_64/
        ▼
halcyon-packages.repo  (staged by files/dnf/ in this repo, baseurl + gpgcheck + repo_gpgcheck)
        ▼
desktop.yml dnf block installs the 7 packages from OUR repo, not COPR
```

---

## 3. Research findings (what shaped this plan)

### 3.1 "Andaman" is now **anda** — and it is a local CLI, not a service

- `terrapkg/andaman` no longer exists; the tool is [`FyraLabs/anda`](https://github.com/FyraLabs/anda) (docs call it "Anda (also known as andaman)"). It is a Rust meta-build toolchain "designed for monorepos": it reads an `anda.hcl` manifest per package and drives **mock** (default) or `rpmbuild`, and can also build OCI images and Flatpaks.
- **There is no remote build service and no `ada submit`.** Terra's FAQ/history: an early BuildKit-based CI server was abandoned; older `umpkg` submitted to Koji and was dropped. The current CLI is `anda {build,ci,update,run,init,list,clean}`.
- Terra's CI (copyable verbatim) lives in [`terrapkg/packages/.github/workflows/`](https://github.com/terrapkg/packages): `autobuild.yml` runs `anda ci` to emit a JSON build matrix of changed packages, then `json-build.yml` runs `anda build -D "vendor Terra" -c terra-<ver>-<arch>` inside `container: ghcr.io/terrapkg/builder:f<version>` with `--cap-add=SYS_ADMIN --privileged` (mock needs it), uploads RPM/SRPM artifacts, and publishes on success.
- Version bumps: per-package `update.rhai` scripts executed by `anda update` (Terra runs ~200 of them in under a second) in their `update.yml`.

### 3.2 Terra's monorepo layout (the template for ours)

`terrapkg/packages` root: a minimal `anda.hcl`; packages at `anda/<category>/<name>/` with one `anda.hcl` manifest (`project pkg { rpm { spec = "<name>.spec" } }` — block name must be `pkg`), the spec (must be named exactly like the package — mock limitation), sources/patches, and optional `update.rhai`. Categories include `desktops`, `apps`, `tools`, etc.

### 3.3 Subatomic is not available to us

[`FyraLabs/subatomic`](https://github.com/FyraLabs/subatomic) is fyralabs' RPM repo server (Rust, kiritan repodata generator, API-driven, Postgres + storage). The public instance `subatomic.fyralabs.com` is **employees-only**: Terra's FAQ states publishing requires a JWT "only trusted employees of Fyra Labs have access". Third parties contribute by PR into `terrapkg/packages` — not what we want (we want our own repo). Self-hosting is possible (Dockerfile + `.env.example`: Postgres, `JWT_SECRET`, `STORAGE_DIR`) but v1 is explicitly "work in progress". → Decision: **GitHub Pages static repo** (§4), with self-hosted Subatomic documented as the upgrade path (§8).

### 3.4 GitHub Pages is the right serving layer

- Proven patterns: [ewpratten's dist repo](https://ewpratten.com/blog/simple-dnf-repo), [atsign/noports-rpm](https://github.com/atsign-foundation/noports-rpm) (createrepo_c per-arch, prune old versions, `gpg --detach-sign repodata/repomd.xml`, push to Pages), and the turnkey [sirredbeard/github-pages-rpm-repo](https://github.com/sirredbeard/github-pages-rpm-repo) template.
- Limits: **1 GB site, 100 GB/month soft bandwidth, 10 builds/hour** (Pages) — a latest-only 7-package repo is ~100–300 MB; we will be far under.
- **Releases are the wrong shape**: assets are not replaceable, and since 2025-10-28 "immutable releases" GA makes that permanent — a rolling `repodata/` tree cannot live there. Releases remain useful as the _archive_ of build artifacts (Terra-style), with Pages carrying the live repo.
- One-time gotcha: the Actions `GITHUB_TOKEN` often cannot _create_ the Pages site first time (`Resource not accessible by integration`) — enable Settings → Pages → Source: GitHub Actions manually once.

### 3.5 Signing must be modern (Fedora 44 = RPM 6 / rpm-sequoia)

Fedora 44 rejects SHA-1 signatures and legacy keys ("Signature not supported" — rpm-sequoia strictness; third-party repos hit this in 2026). The monorepo must generate a **fresh RSA (≥3072) or Ed25519** key with SHA-2 digests. RPM signing via `rpmsign --addsign` with `%_gpg_name`; metadata via `gpg --detach-sign --armor repodata/repomd.xml` (only repomd.xml is detach-signed; clients verify with `repo_gpgcheck=1`). Client `.repo` imports the public key via `gpgkey=<URL>`.

### 3.6 What a `-git` package spec needs

Verified against `solopasha/hyprlandRPM` (the most-maintained Hyprland COPR): specs pin **exact upstream commits** (`%global commit <sha>`), fetch codeload tarballs as `Source0`, use `Release: %autorelease` (rpmautospec) so rebuilds get rising NVRs, and use `%forgemeta`/`%forgeautosetup` (shipped by Fedora's `redhat-rpm-config`). Hyprland additionally pins **subproject commits** (aquamarine, hyprlang, hyprutils, hyprgraphics, hyprcursor, udis86, libxkbcommon) — this is the expensive part of self-building. An `update.rhai`/`update.sh` automation does the bumping.

---

## 4. Decision record

| #   | Decision                                                                       | Alternatives rejected                | Why                                                                                                                                                                                                                        |
| --- | ------------------------------------------------------------------------------ | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Serve the repo from **GitHub Pages**                                           | Self-hosted Subatomic; Releases-only | No server to run; in-place repodata updates; proven community patterns; 1 GB is ample. Subatomic = Postgres + always-on host + "work in progress" v1. Releases = immutable assets, no stable `baseurl` for a rolling repo. |
| D2  | Build with **anda** (`anda ci` + `anda build`) in Terra's public builder image | Plain mock without anda; Koji; Copr  | User directive ("built using andaman"); anda adds monorepo change-detection (`anda ci`) and update automation (`anda update` + rhai) for free; Terra's workflow is public and battle-tested.                               |
| D3  | Publish with **createrepo_c + rpmsign + detach-signed repomd**                 | Subatomic self-host now; unsigned    | Standard RPM practice; works on Pages; subatomic later if we outgrow Pages (§8).                                                                                                                                           |
| D4  | Scope: **Hyprland stack (7 packages) first**, zen-browser in a later phase     | Moving everything at once            | zen-browser wraps upstream prebuilt tarballs (different packaging style); isolate risk; land the pipeline with the packages that hurt the most (Copr 504s + greeter latency).                                              |
| D5  | Monorepo: **`aahsnr-work/halcyon-packages`**, separate from halcyon            | Subdirectory of halcyon              | Separate concerns: package CI re-runs independently of image CI; halcyon consumes a versioned repo URL, not a moving subdirectory.                                                                                         |
| D6  | Fedora 44 (x86_64) only at first; `$releasever/$basearch` layout from day one  | Multi-release matrix; aarch64        | Follow the base image; the URL layout means adding f45/aarch64 later is config, not redesign.                                                                                                                              |

---

## 5. Target monorepo: `aahsnr-work/halcyon-packages`

### 5.1 Repository layout

```
halcyon-packages/
├── anda.hcl                      # root: project { } (per Terra convention)
├── anda/
│   └── desktops/
│       ├── hyprland-git/
│       │   ├── anda.hcl          # project pkg { rpm { spec = "hyprland-git.spec" } }
│       │   ├── hyprland-git.spec
│       │   └── update.rhai       # bump %global commit pins (upstream + subprojects)
│       ├── hyprland-guiutils/
│       ├── hyprpwcenter/
│       ├── hyprshutdown/
│       ├── noctalia-git/
│       ├── noctalia-greeter-git/
│       └── xdg-desktop-portal-hyprland/
├── .github/workflows/
│   ├── autobuild.yml             # push/PR: anda ci → matrix → anda build → upload artifact
│   ├── publish.yml               # after autobuild: sign, createrepo_c, deploy Pages
│   └── update.yml                # cron: anda update → PR bumps
└── repo/
    └── halcyon-packages.repo     # client .repo file (also served on Pages)
```

### 5.2 Build workflow (modeled on Terra's `json-build.yml`)

1. Trigger: push/PR touching `anda/**` (and manual dispatch).
2. Job 1: `anda ci` (in the builder image) → emits JSON matrix of changed packages.
3. Job 2 (matrix): `container: ghcr.io/terrapkg/builder:f44`, options `--privileged` (mock requirement — Terra runs exactly this on public GitHub runners); `dnf5 builddep`; `anda build -D "vendor halcyon" -c f44-x86_64 <pkg>`; upload RPM/SRPM artifacts.
   - The `-D "vendor halcyon"` flag is what our provenance gate will later assert.
4. Secrets: none for building. `GPG_PRIVATE_KEY` (+ passphrase) only in the publish job.

### 5.3 Publish workflow

1. Download the run's RPMs (artifact or `gh release download` if archiving to Releases).
2. Import the GPG key: `echo "${{ secrets.GPG_PRIVATE_KEY }}" | base64 -d | gpg --batch --import`.
3. `rpmsign --addsign *.rpm` (define `%_gpg_name`).
4. rsync RPMs into the Pages worktree under `fedora/44/x86_64/`, prune to N most recent versions per package (keep ≥2 so `dnf downgrade` works).
5. `createrepo_c fedora/44/x86_64/` then `gpg --detach-sign --armor repodata/repomd.xml`.
6. Commit + push the Pages branch (actions/deploy-pages also works; the git-push pattern is the proven one — noports).
7. Publish/update `halcyon-packages.repo` + `RPM-GPG-KEY-halcyon-packages` at the Pages root.

### 5.4 Client `.repo` file (this is what halcyon will consume)

```ini
[halcyon-packages]
name=halcyon-packages
baseurl=https://aahsnr-work.github.io/halcyon-packages/fedora/$releasever/$basearch/
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://aahsnr-work.github.io/halcyon-packages/RPM-GPG-KEY-halcyon-packages
```

Key generation (once, locally, where pinentry works): `gpg --quick-generate-key "halcyon packages <repo@halcyon>" rsa3072 sign` — export armored private key base64-encoded into the `GPG_PRIVATE_KEY` secret, public key into the Pages root. Do **not** reuse an old DSA/SHA-1 key (§3.5).

### 5.5 Update automation

Per-package `update.rhai` scripts (anda's update runner) that: fetch the upstream repo's latest commit for pinned `-git` versions, rewrite the `%global commit`/`Version` lines, and open a PR (or direct-push on a branch) — mirroring Terra's `update.yml`. Cadence: daily cron, matching the image's daily build.

---

## 6. Package migration inventory & effort

| Package                     | Upstream                           | Effort   | Notes                                                                                                                                                                                                                                            |
| --------------------------- | ---------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| hyprland-git                | hyprwm/Hyprland (git)              | **High** | Pins 5+ subproject commits (aquamarine, hyprlang, hyprutils, hyprgraphics, hyprcursor + udis86/libxkbcommon); meson/C++ build ~10–15 min; this package sets the ABI that the rest follows. Reference spec: `solopasha/hyprlandRPM/hyprland-git`. |
| hyprland-guiutils           | hyprwm/hyprland-guiutils           | Low      | Successor of hyprland-qtutils; small Qt apps (dialog, welcome, update-screen).                                                                                                                                                                   |
| hyprpwcenter                | (COPR-spec upstream)               | Low      | Small utility; mirror the lionheartp spec, update sources.                                                                                                                                                                                       |
| hyprshutdown                | (COPR-spec upstream)               | Low      | Same class as hyprpwcenter.                                                                                                                                                                                                                      |
| xdg-desktop-portal-hyprland | hyprwm/xdg-desktop-portal-hyprland | Low–Med  | Must build against the same hyprland ABI generation; version-coupled to hyprland-git.                                                                                                                                                            |
| noctalia-git                | noctalia-dev/noctalia              | Medium   | Single source tarball; QML/shell — watch node/qml toolchain bits in the COPR spec.                                                                                                                                                               |
| noctalia-greeter-git        | noctalia-dev/noctalia-greeter      | Medium   | wlroots-based greeter; runtime deps already known from the COPR spec (greetd, dbus, wlroots ≥ 0.20); remember to keep dropping the `greeter`-hardcoded tmpfiles rule the COPR spec drops.                                                        |

**Sequencing rule:** hyprland-git first (pilot, Phase 1) — it proves the pipeline on the hardest package and fixes the ABI generation; the remaining six then build against that same generation in one or two runs.

**Stays where it is:** cliphist, qt6ct, nwg-look\*, greetd, kitty(+shell-integration/terminfo), gnome-keyring, gnome-tweaks, papers, papirus-icon-theme, thunar-\* (Fedora); brave-browser/brave-origin (Brave S3 repo); code (Microsoft); zed (Terra repo); zen-browser (sneexy COPR — **Phase 7**).

---

## 7. halcyon-side changes (executed only in Phase 4)

Every touchpoint, with current file:line (as of this plan):

1. **`recipes/modules/desktop.yml:6-8`** — remove the `copr: [lionheartp/Hyprland]` block; move the 7 migrated packages into a new dnf block (or the same one) using:
   ```yaml
   repos:
     cleanup: true
     files:
       - halcyon-packages.repo
   ```
   staged from `files/dnf/halcyon-packages.repo` (the same pattern as `files/dnf/vscode.repo`, consumed by the existing `files:` mechanism). Keep `skip-unavailable: false`.
2. **`files/dnf/halcyon-packages.repo`** — new file, content per §5.4.
3. **`files/scripts/desktop-verify.sh:8-17`** — COPR repo-file purge glob extended to also purge `_copr*lionheartp*` (already there) **and** to purge any stale `halcyon-packages.repo` if we ever retire it; repolist gate (`:101-109`) changes from `lionheartp` → assert our repo IS enabled during install and cleaned after (`cleanup: true` disables it; adjust the gate to the cleanup reality).
4. **`files/scripts/desktop-verify.sh:42-65` (provenance guard)** — the vendor expectation flips from `lionheartp` to our signing identity: COPR stamps `Fedora Copr - user lionheartp`; our builds stamp `vendor halcyon` (set via `anda build -D`), so the gate becomes `grep -qi 'halcyon'`. Keep the same mixed-ABI-stack failure semantics — that guard is what protects the -git stack from version skew, and it matters more, not less, once we self-build.
5. **`files/scripts/desktop-verify.sh:20-30`** — package list unchanged (same 7 names + the Fedora ones).
6. **`.github/workflows/build.yml:31-46`** — retire the "Wait for Copr metadata availability" step once COPR is fully dropped (the `libdnf5.conf.d` retries drop-in **stays** — it still protects the brave/vscode/terra fetches).
7. **`README.md`** — sections at lines 139–144 (desktop stack), 145–151 (login), 152–157 (browsers — zen phase only), 372–384 (`--repoid` trap: vendor stamp text changes), 412–413 (credits): swap COPR references for the monorepo.
8. **`recipes/modules/apps.yml:13-14, 59-66`** — untouched in this phase; zen-browser migration (Phase 7) would drop `sneexy/zen-browser` and flip the vendor gate from `sneexy`.

---

## 8. Phased rollout

**Phase 0 — scaffold (½ day)**

- [ ] Create `aahsnr-work/halcyon-packages`; push root `anda.hcl` + `.github/workflows/` skeleton; enable Settings → Pages → Source: GitHub Actions (the one manual step).
- [ ] Generate the repo GPG key (RSA-3072, SHA-2); store `GPG_PRIVATE_KEY` (base64) secret; publish public key to the Pages root.
- [ ] Empty Pages repo live with just `halcyon-packages.repo` + `RPM-GPG-KEY-*`.

**Phase 1 — pilot: hyprland-git (1–2 days)**

- [ ] Port the spec (start from lionheartp's, add `update.rhai`); get a green `anda build` in Actions.
- [ ] Publish pipeline end-to-end: signed RPM visible on Pages, `dnf5 --repofrompath` smoke-test installs it into a container.

**Phase 2 — remaining six (1–2 days)**

- [ ] Port guiutils → hyprpwcenter/hyprshutdown → xdg-desktop-portal-hyprland → noctalia pair, each against the hyprland-git ABI generation; `anda update` scripts for each.

**Phase 3 — repo hardening (½ day)**

- [ ] Prune policy (keep last 2–3 NVRs), repomd signing verified, first `dnf5 makecache --repo halcyon-packages` from a container, metadata refresh timing.

**Phase 4 — switch halcyon (½ day)**

- [ ] Apply §7 changes in a branch; build; prove provenance gates green; parallel-run one full image build against BOTH repos (COPR block on a branch) before switching.
- [ ] Merge; push; CI builds and publishes a signed image that consumes zero COPR repos.

**Phase 5 — verification (½ day)**

- [ ] `rpm -q --qf '%{VENDOR}'` on the whole 7-package stack + deps; repolist clean; boot test (greeter, portals, session); `ujust` smoke.

**Phase 6 — COPR retirement**

- [ ] Delete the Copr health-wait step in `build.yml`; remove remaining lionheartp mentions; unsubscribe/watch notes for upstream ABI bumps now land as OUR build failures.

**Phase 7 (later) — zen-browser + self-hosted Subatomic upgrade path**

- [ ] zen-browser spec wraps upstream release tarballs (like the sneexy COPR does) — no source builds.
- [ ] If Pages limits ever bind (unlikely), stand up Subatomic (Docker, Postgres, JWT) and repoint `.repo` baseurl — the monorepo's anda manifests need no changes.

**Rollback:** the pre-migration `desktop.yml` (COPR block) is preserved on a `copr-fallback` branch; reverting halcyon to it + a rebuild restores the exact prior image. The monorepo is additive — nothing COPR-side is destroyed.

---

## 9. Risks & mitigations

| Risk                                                | Mitigation                                                                                                                                                                                                                        |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mock needs privileged containers on Actions runners | Terra's public CI runs `container: ghcr.io/terrapkg/builder` with `--privileged` on standard runners today — verified pattern. Fallback: `anda build --rpm-builder=rpmbuild` (no container) or `podman run --privileged` locally. |
| Hyprland upstream ABI churn breaks our stack        | Already guarded: the provenance vendor gate + pinning subproject commits; self-building makes us the maintainer — budget for fix-up builds after upstream bumps.                                                                  |
| RPM 6 (F44) rejects legacy signatures               | Fresh RSA-3072 key with SHA-2; never reuse old keys (§3.5).                                                                                                                                                                       |
| Pages first-time enablement fails from Actions      | Enable Pages once manually in repo settings (documented gotcha).                                                                                                                                                                  |
| Build time (hyprland ~10–15 min + 6 more)           | `anda ci` matrix parallelizes per-package; runner time is free on public repos.                                                                                                                                                   |
| Transition window still needs COPR                  | Phases 0–3 run entirely alongside COPR; the switch (Phase 4) is one merge.                                                                                                                                                        |
| Single-maintainer bus factor for 7 packages         | `update.rhai` automation + Terra's specs as reference; worst case a package stalls and the COPR block on the fallback branch covers it.                                                                                           |

## 10. Open questions

1. Track `f44` only, or also build f43/rawhide chroots? (Default: f44 only — matches the base image; layout already supports more.)
2. aarch64 builds (GitHub provides arm runners) — needed only if a halcyon arm image ever exists. Default: no.
3. Publish debuginfo? Default: no (size).
4. Sign the _repo_ with the same key as the packages (simplest) or separate keys? Default: same key.
5. Should `hyprpolkitagent` ever be added if noctalia drops its built-in agent? (Out of scope; noctalia-git `Provides: PolicyKit-authentication-agent`.)

## 11. References

- anda: https://github.com/FyraLabs/anda · https://wiki.fyralabs.com/Andaman
- Terra monorepo + CI: https://github.com/terrapkg/packages (`autobuild.yml`, `json-build.yml`, `update.yml`) · https://docs.terrapkg.com/contributing/getting-started/ · https://docs.terrapkg.com/general/infrastructure
- Builder image / mock configs: https://github.com/terrapkg/builder · https://github.com/terrapkg/mock-configs
- Subatomic (and its access policy): https://github.com/FyraLabs/subatomic · https://docs.terrapkg.com/reference/faq/
- Pages repo patterns: https://github.com/atsign-foundation/noports-rpm · https://ewpratten.com/blog/simple-dnf-repo · https://github.com/sirredbeard/github-pages-rpm-repo
- Limits: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits · https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- Signing: https://www.redhat.com/en/blog/how-sign-rpm-packages-gpg-key · https://blog.packagecloud.io/eng/2014/11/24/howto-gpg-sign-verify-rpm-packages-yum-repositories/ · https://man.kuoi.io/fedora/dnf5.conf.5.html (gpgkey/repo_gpgcheck)
- RPM 6 strictness: https://github.com/rpm-software-management/rpm-sequoia/issues/22 · https://discussion.fedoraproject.org/t/zoom-signature-keys-are-not-good-for-fedora-44/
- Reference -git spec: https://github.com/solopasha/hyprlandRPM (`hyprland-git` — pinned commits, %autorelease, %forgeautosetup)
- Hyprland 0.53 packaging note: https://hypr.land/news/update53/
