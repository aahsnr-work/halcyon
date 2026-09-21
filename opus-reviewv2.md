I rechecked my last answer against current sources and found several errors, some of which would have failed your build. I've rewritten everything below with corrections, and the `.github` audit now covers a real problem in `build.yml`: signed rebases would fail.

## 1. What I got wrong last time

| #   | What I said                                                                                                                                                                | What's true                                                                                                                                                                                                                                                                                        | Action                                                                |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| 1   | Change `# shellcheck source=build_files/packages-lib` to `../packages-lib`, because paths resolve relative to the script and SC1091 "only" gives exit 0                    | ShellCheck's man page says by default, only ShellCheck's working directory is included in the source search path. Your original directive works from the repo root. Mine would have made `just lint` fail.                                                                                         | Reverted everywhere.                                                  |
| 2   | `py_compile` "catches that class of bug" (the missing `datetime` import in `rmi`)                                                                                          | `py_compile` only checks syntax. A missing import is an undefined name.                                                                                                                                                                                                                            | Replaced with `ruff --select E9,F821,F822,F823` (`just lint-python`). |
| 3   | `gum` is missing, so every ujust prompt breaks. Add `gum` and `grub2-tools`.                                                                                               | `ugum` checks whether gum is present and falls back to fzf as its menu handler, and fzf is installed. Also, Universal Blue builds gum in its own staging COPR, which suggests it isn't in Fedora, so the name could abort the whole dnf transaction. `grubby` already hard-requires `grub2-tools`. | Removed `gum` and `grub2-tools`. Kept `grubby`.                       |
| 4   | `nodejs24` and `nodejs24-npm` need renaming                                                                                                                                | You said the originals are correct.                                                                                                                                                                                                                                                                | Reverted, and I dropped the "verify" caveat.                          |
| 5   | Remove `xorg-x11-server-Xorg` and add a gate that forbids it                                                                                                               | `MIGRATION.md` D20 records that removal as deliberately rejected. My gate could also fail on a transitive dependency.                                                                                                                                                                              | Reverted.                                                             |
| 6   | Add "no `/opt` content" and other filesystem gates                                                                                                                         | The Brave RPM installs into `/opt`, so that gate would fail. bootc lint already covers the rest.                                                                                                                                                                                                   | Removed.                                                              |
| 7   | Add a "no `rpm-ostree` in recipes" gate                                                                                                                                    | Shipped recipes mention it in comments and in a fallback branch, so the gate fails on day one.                                                                                                                                                                                                     | Removed.                                                              |
| 8   | `finalize` re-creating `/var/tmp` triggers `var-tmpfiles`                                                                                                                  | The base's `tmp.conf` already has a `q /var/tmp` rule, so no lint fires.                                                                                                                                                                                                                           | `finalize` left unchanged.                                            |
| 9   | Greetd config could be overwritten, so move it into `configure-system`                                                                                                     | I overrated this. Existing gates catch a content change, and config files are usually `noreplace`.                                                                                                                                                                                                 | Reverted, no move.                                                    |
| 10  | `CODEOWNERS` `@aahsnr-work` is a bare org handle. Use `@aahsnr`.                                                                                                           | The `aahsnr-work@users.noreply.github.com` address in your repo implies `aahsnr-work` is a personal account, so the file is valid. I invented `@aahsnr`.                                                                                                                                           | No change.                                                            |
| 11  | Add a Dependabot `docker` ecosystem                                                                                                                                        | Dependabot's docker support has been tracked as not recognising a file named Containerfile. I found no evidence this changed. Renovate handles Containerfiles by default.                                                                                                                          | Reverted.                                                             |
| 12  | Delete `artifacthub-repo.yml`; make tlmgr extras fatal; edit the brew service units; drop `fastfetch` from `exclude.all`; remove the rebase recipe's `rpm-ostree` fallback | Unnecessary churn or behaviour changes nobody asked for.                                                                                                                                                                                                                                           | All reverted.                                                         |
| 13  | jq, zstd and setpriv were "P0, will break the build"                                                                                                                       | Earlier successful builds reached those stages, so the tools exist in the base. The change is defensive only.                                                                                                                                                                                      | Downgraded to P2.                                                     |
| 14  | `input-remapper` and `ydotool` should be enabled "as Bazzite does"                                                                                                         | I stated that without verifying it.                                                                                                                                                                                                                                                                | Moved to a decision for you, no code.                                 |

`bootc`'s own docs say the `/usr/etc` tree is an internal implementation detail, that you shouldn't put files there, and that `bootc container lint` checks for it. So the `/etc/pki/containers` fix stands.

## 2. `.github` audit: verdict per file

| File                                             | Verdict                                                                                                                                                                                                                                |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workflows/build.yml`                            | **Changes needed.** Signing format, runner pin, publish gate, permissions. See §3.                                                                                                                                                     |
| `workflows/lint.yml`                             | **Changes needed.** Pin the runner, add a Python lint job, add actionlint, run `verify-github.sh`.                                                                                                                                     |
| `workflows/clean.yml`                            | Pin the runner only.                                                                                                                                                                                                                   |
| `semantic.yml`                                   | **Delete.** It configures the probot service. Its maintainer shut the hosted service down after the April 2022 Heroku incident and recommends GitHub Actions instead, so it enforces nothing. Replaced by `workflows/semantic-pr.yml`. |
| `dependabot.yml`                                 | Add grouping and a semantic commit prefix. It also overlaps with Renovate (see below).                                                                                                                                                 |
| `pull_request_template.md`                       | Fix the relative link, drop the false "semantic.yml enforces", update the checklist.                                                                                                                                                   |
| `renovate.json5`, `CODEOWNERS`, `log-helpers.sh` | No change.                                                                                                                                                                                                                             |
| `verify/verify-github.sh`                        | Rewrite. It hardcoded action majors, so Renovate's SHA pinning would have turned it red, and it defined a function twice.                                                                                                              |

Pins I confirmed are valid:

- `actions/checkout@v7` (latest v7.0.1, July 2026)
- `docker/login-action@v4` (v4.6.0)
- `extractions/setup-just@v4` (current README uses v4)
- `sigstore/cosign-installer@v4`
- `amannn/action-semantic-pull-request@v6` (current README)
- `actions/setup-python@v6`. I couldn't confirm the current major; the latest release I saw is 6.3.0.
- `ublue-os/remove-unwanted-software@v9` is valid only on Ubuntu 24.04 (see B below).

**I can't produce commit-SHA pins here.** Renovate's `config:best-practices` will open those PRs.

## 3. New findings (verified)

**A. Signed rebases are broken (P0).**

- `cosign-installer` v4 installs Cosign v3. v3.x of the installer cannot install Cosign v3, so v4 is required.
- Cosign 3 defaults `--new-bundle-format` to true, writing signatures as OCI 1.1 referrers.
- containers/image, the library behind podman, skopeo and `bootc switch`, only finds signatures via the legacy `.sig` tag.
- Your image ships a `sigstoreSigned` policy with `use-sigstore-attachments: true`, so `bootc switch --enforce-container-sigpolicy` would reject every image. `cosign verify` still passes, which is why CI would never notice.
- Fix: pass the legacy flags. Universal Blue's documented strict-policy example uses `--new-bundle-format=false --use-signing-config=false --registry-referrers-mode=legacy`.
- Also add a verify step that forces legacy lookup, and pin Cosign to `v3.1.3`. The latest release I could confirm is 3.1.3, checked 2026-09-02. Cosign v3.1 keeps the legacy flags, but Cosign v4 will remove deprecated functionality.
- Already-published images stay unsigned in the format bootc reads until you rebuild them.

**B. `ubuntu-latest` changes underneath you (P0 in about a month).** GitHub announced that `ubuntu-latest` migrates from 24.04 to 26.04 gradually between October 19 and November 19, 2026, and that you can pin `ubuntu-24.04` to stay put. The old `remove-unwanted-software` commit is no longer compatible with 26.04 runners. `image-template` moved to an untagged commit ahead of v9. I pinned all workflows to `ubuntu-24.04`. Testing 26.04 is a separate change.

**C. The daily cron never publishes, and may not run at all.**

- `push`, `login` and `sign` are gated on `github.event_name == 'push'`, so scheduled and manual runs build and discard. That contradicts the README's "rebuilt daily".
- Scheduled workflows run on the latest commit on the default branch. If `main` is your default branch, the cron runs `main`'s workflow and never this one. That may be why you saw BlueBuild in your workflow runs.
- `image-template` publishes when the event isn't a pull request and the ref is the default branch. I replaced the `push`-only gate with an explicit `PUBLISH_BRANCH: container` gate that logs its decision.
- If `main` still publishes `halcyon:latest`, the two branches race for that tag. Either make `container` the default branch or give one of the images a different name. That's your call, so I made no change.

**D. Signature identity in `policy.json`.** cosign signs by digest, but bootc pulls by tag. Without `signedIdentity: matchRepository`, containers/image's default identity match can reject the signature. The `image-template` maintainers' documented strict policy includes it (their example is in issue #215). I added it to `image-info`. I'm relying on the containers policy semantics plus that example, and I haven't tested it against a live bootc switch.

**E. Smaller.**

- Drop `id-token: write`. Key-based signing needs no OIDC.
- Add `persist-credentials: false` on checkout.
- Dependabot and Renovate both update actions. If the Renovate app is installed, delete `dependabot.yml`. I couldn't confirm which is active.

## 4. Files

### Deletions

```bash
git rm build_files/base/guarded-removals build_files/base/file-footprint \
       build_files/base/gnome-extensions build_files/base/fonts-cleanup
git rm .github/semantic.yml
```

### `.github/workflows/build.yml`

```yaml
---
name: build
on:
  schedule:
    - cron: "00 08 * * *"
  push:
    branches: [container, main]
    paths-ignore:
      - "**/README.md"
      - "**/MIGRATION.md"
      - "**/TODO.md"
  pull_request:
  workflow_dispatch:

env:
  IMAGE_REGISTRY: "ghcr.io/${{ github.repository_owner }}" # do not edit
  # Only this branch pushes and signs. Every other ref builds and verifies.
  PUBLISH_BRANCH: container

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  build_push:
    name: Build and push image
    # Pinned on purpose: ubuntu-latest migrates to 26.04 between 2026-10-19 and
    # 2026-11-19, and ublue-os/remove-unwanted-software@v9 breaks there.
    runs-on: ubuntu-24.04
    timeout-minutes: 180
    permissions:
      contents: read
      packages: write
      # No id-token: signing is key-based, there is no OIDC exchange.
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Log helpers
        run: |
          source .github/log-helpers.sh
          banner "halcyon build — run ${GITHUB_RUN_ID} on ${GITHUB_REF_NAME}"
          step "event: ${GITHUB_EVENT_NAME}; sha: ${GITHUB_SHA::7}"

      # Explicit and logged, so "why did nothing get pushed?" is answered at the
      # top of the run instead of by reading `if:` expressions.
      - name: Decide whether this run publishes
        id: publish
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Publish gate"
          if [ "${GITHUB_EVENT_NAME}" != "pull_request" ] && [ "${GITHUB_REF}" = "refs/heads/${PUBLISH_BRANCH}" ]; then
            ok "event=${GITHUB_EVENT_NAME} ref=${GITHUB_REF} → this run pushes and signs"
            echo "publish=true" >> "${GITHUB_OUTPUT}"
          else
            warn "event=${GITHUB_EVENT_NAME} ref=${GITHUB_REF} → build only (publish branch: ${PUBLISH_BRANCH})"
            echo "publish=false" >> "${GITHUB_OUTPUT}"
          fi

      - name: Wait for Copr metadata availability
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 1/7 — Copr metadata availability"
          echo "::group::Polling consumed COPRs (up to 30 attempts × 60s)"
          URLS=(
            "https://download.copr.fedorainfracloud.org/results/lionheartp/Hyprland/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/catpieleaf/kernel-p03/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/ublue-os/packages/fedora-44-x86_64/repodata/repomd.xml"
            "https://download.copr.fedorainfracloud.org/results/sneexy/zen-browser/fedora-44-x86_64/repodata/repomd.xml"
          )
          for i in $(seq 1 30); do
            ok_all=1
            for URL in "${URLS[@]}"; do
              code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 20 "$URL" || true)
              if [ "$code" = "200" ]; then
                printf '%s\n' "${H_GRN}  ✔ HTTP ${code}  ${URL}${H_RESET}"
              else
                printf '%s\n' "${H_YLW}  ⚠ HTTP ${code}  ${URL}${H_RESET}"
                ok_all=0
              fi
            done
            [ "$ok_all" = "1" ] && { ok "all Copr repodata reachable (attempt ${i})"; echo "::endgroup::"; exit 0; }
            step "attempt ${i}/30 not all green — sleeping 60s"
            sleep 60
          done
          echo "::endgroup::"
          die "Copr metadata still unavailable after 30 attempts — re-run later."

      - name: Report build space (before)
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 2/7 — Maximize build space"
          step "before:"
          df -h / /mnt | sed 's/^/      /'

      - name: Remove unwanted software
        uses: ublue-os/remove-unwanted-software@v9

      - name: Report freed space (after)
        if: always()
        run: |
          source .github/log-helpers.sh
          step "after:"
          df -h / /mnt | sed 's/^/      /'

      - name: Install just
        uses: extractions/setup-just@v4

      - name: Check Just + shell syntax
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 3/7 — just check + just lint"
          command -v shellcheck >/dev/null 2>&1 || {
            step "shellcheck not preinstalled — installing"
            sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
          }
          just check && ok "just check passed"
          just lint && ok "just lint passed"

      - name: Image Name
        id: image-name
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          IMAGE_NAME=$(just image_name)
          ok "IMAGE_NAME=${IMAGE_NAME}"
          echo "IMAGE_NAME=${IMAGE_NAME}" >> "$GITHUB_ENV"

      - name: Default Tag
        id: gen-default-tag
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          DEFAULT_TAG=$(just generate-default-tag)
          ok "DEFAULT_TAG=${DEFAULT_TAG}"
          echo "DEFAULT_TAG=${DEFAULT_TAG}" >> "$GITHUB_ENV"

      - name: Prepare environment
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          # Lowercase the image uri https://github.com/macbre/push-to-ghcr/issues/12
          echo "IMAGE_REGISTRY=${IMAGE_REGISTRY,,}" >> "${GITHUB_ENV}"
          echo "IMAGE_NAME=${IMAGE_NAME,,}" >> "${GITHUB_ENV}"
          ok "registry=${IMAGE_REGISTRY,,}  image=${IMAGE_NAME,,}"

      - name: Build Image
        id: build-image
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 4/7 — podman build (all 18 stages)"
          echo "::group::just build ${IMAGE_NAME} ${DEFAULT_TAG}"
          just build \
            "${IMAGE_NAME}" \
            "${DEFAULT_TAG}"
          echo "::endgroup::"
          ok "image built"

      # verify/ tests properties no in-build gate covers (chezmoi --global wiring,
      # ujust --choose plumbing, the brew payload seen from outside the build).
      - name: Image-side verification suite
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 5/7 — Image-side verification (verify/)"
          just verify-image "${IMAGE_NAME}" "${DEFAULT_TAG}"
          ok "all image-side verifications passed"

      - name: Package count report
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 6/7 — Package census + tags"
          INFO=$(podman run --rm --entrypoint /bin/bash "${IMAGE_NAME}:${DEFAULT_TAG}" -c \
            'echo "count=$(rpm -qa | wc -l)"; echo "kernel=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-p03 2>/dev/null || echo n/a)"')
          COUNT=$(sed -n 's/^count=//p' <<< "$INFO")
          KVER=$(sed -n 's/^kernel=//p' <<< "$INFO")
          ok "${COUNT} RPMs installed, p03 kernel ${KVER}"
          {
            echo "## 📦 halcyon image package report"
            echo ""
            echo "| Metric | Value |"
            echo "|---|---|"
            echo "| **Total installed RPM packages** | **${COUNT}** |"
            echo "| p03 kernel | ${KVER} |"
            echo "| Homebrew payload | $(podman run --rm --entrypoint /bin/bash "${IMAGE_NAME}:${DEFAULT_TAG}" -c 'du -h /usr/share/halcyon/brew-bundle.tar.zst 2>/dev/null | cut -f1 || echo n/a') |"
            echo "| Source | \`${IMAGE_REGISTRY}/${IMAGE_NAME}:${GITHUB_SHA}\` |"
          } >> "$GITHUB_STEP_SUMMARY"
          echo "::notice title=halcyon package count::${COUNT} RPMs installed (p03 kernel ${KVER})"

      - name: Generate Build Tags
        id: gen-build-tags
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          alias_tags="$(just generate-build-tags \
                        "${IMAGE_NAME}" \
                        "${DEFAULT_TAG}")"
          step "Tags for this run:"
          for t in ${alias_tags}; do printf '%s\n' "${H_WHT}      🏷  ${t}${H_RESET}"; done
          echo "alias_tags=${alias_tags}" >> "$GITHUB_OUTPUT"

      - name: Tag Image
        id: tag-images
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          just tag-images \
            "${IMAGE_NAME}" \
            "${DEFAULT_TAG}" \
            "${ALIAS_TAGS}"
          ok "all alias tags applied"

      - name: Login to GitHub Container Registry
        if: steps.publish.outputs.publish == 'true'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ github.token }}

      - name: Push To GHCR
        if: steps.publish.outputs.publish == 'true'
        id: push-image
        env:
          ALIAS_TAGS: ${{ steps.gen-build-tags.outputs.alias_tags }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Stage 7/7 — Push to GHCR"
          echo "::group::podman push (one tag at a time)"
          for tag in ${ALIAS_TAGS}; do
            step "pushing ${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
            podman push --quiet --digestfile=/tmp/digestfile "${IMAGE_NAME}:${tag}" \
              "${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
            ok "pushed ${tag}"
          done
          echo "::endgroup::"
          digest=$(< /tmp/digestfile)
          ok "manifest digest: ${digest}"
          echo "digest=${digest}" >> "$GITHUB_OUTPUT"
          {
            echo "## 🔖 Published tags"
            echo ""
            for tag in ${ALIAS_TAGS}; do echo "- \`${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}\`"; done
            echo ""
            echo "digest: \`${digest}\`"
          } >> "$GITHUB_STEP_SUMMARY"

      # Cosign 3 writes signatures as OCI referrers by default. containers/image
      # (podman, skopeo, bootc) only reads the legacy sha256-<digest>.sig tag, so a
      # default cosign 3 signature is invisible to `bootc switch` even though
      # `cosign verify` passes. The release is pinned so a future default (or the
      # removal of these flags in Cosign 4) cannot change behaviour silently.
      - name: Install Cosign
        if: steps.publish.outputs.publish == 'true'
        uses: sigstore/cosign-installer@v4
        with:
          cosign-release: "v3.1.3"

      - name: Sign container image (legacy sigstore attachment)
        if: steps.publish.outputs.publish == 'true'
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.SIGNING_SECRET }}
          COSIGN_PASSWORD: ""
          DIGEST: ${{ steps.push-image.outputs.digest }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Cosign sign"
          cosign sign --yes \
            --new-bundle-format=false \
            --use-signing-config=false \
            --registry-referrers-mode=legacy \
            --key env://COSIGN_PRIVATE_KEY \
            "${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}"
          ok "signed ${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}"

      # Default `cosign verify` accepts BOTH formats, so it cannot detect this
      # regression. Forcing the legacy lookup proves the signature exists where
      # bootc will look, and that SIGNING_SECRET matches the cosign.pub shipped
      # in the image.
      - name: Verify signature in the format bootc reads
        if: steps.publish.outputs.publish == 'true'
        env:
          DIGEST: ${{ steps.push-image.outputs.digest }}
        run: |
          set -euo pipefail
          source .github/log-helpers.sh
          banner "Cosign verify (legacy format, repo cosign.pub)"
          cosign verify --key cosign.pub --new-bundle-format=false \
            "${IMAGE_REGISTRY}/${IMAGE_NAME}@${DIGEST}"
          ok "legacy signature verified against cosign.pub"

      - name: Done
        if: always()
        run: |
          source .github/log-helpers.sh
          banner "halcyon build finished"
          step "conclusion: ${{ job.status }}"
```

### `.github/workflows/lint.yml`

```yaml
---
name: lint
# PR gate: every host-side check, so PRs fail here in seconds instead of
# 40 minutes into the image build.
on:
  pull_request:
  push:
    branches: [container, main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  check:
    name: Just + shell syntax
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Install just
        uses: extractions/setup-just@v4

      - name: Ensure shellcheck
        run: |
          command -v shellcheck >/dev/null 2>&1 || {
            sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
          }

      - name: Check Just + bash syntax
        run: |
          source .github/log-helpers.sh
          banner "just check"
          just check && ok "just check passed"

      - name: Shellcheck build_files
        run: |
          source .github/log-helpers.sh
          banner "just lint"
          just lint && ok "just lint passed"

  github-audit:
    name: .github audit
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Install PyYAML
        run: python3 -m pip install --quiet pyyaml

      - name: Audit .github tree
        run: |
          source .github/log-helpers.sh
          banner "verify-github"
          bash verify/verify-github.sh

  actionlint:
    name: actionlint
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      # Expression/syntax/input checking only. Shell inside `run:` is skipped
      # (-shellcheck=) because our steps deliberately word-split and source
      # log-helpers.sh, which would produce noise, not signal.
      - name: Lint workflows
        run: |
          docker run --rm -v "${PWD}:/repo" --workdir /repo \
            rhysd/actionlint:1.7.12 -color -shellcheck= -pyflakes=

  python:
    name: Python helpers
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: "3.13"

      - name: Install just
        uses: extractions/setup-just@v4

      # ruff catches undefined names; the -h smoke test and py_compile cannot.
      - name: Static-check helpers
        run: |
          source .github/log-helpers.sh
          banner "just lint-python"
          just lint-python && ok "no undefined names / syntax errors"

      - name: Run helper test suites
        run: |
          source .github/log-helpers.sh
          banner "just test-python"
          just test-python && ok "python suites passed"
```

### `.github/workflows/semantic-pr.yml` (new)

```yaml
---
name: semantic-pr
# Replaces .github/semantic.yml, which configured a hosted service that no
# longer runs. This validates the PR TITLE only and never checks out PR code,
# which is what makes pull_request_target safe here.
on:
  pull_request_target:
    types: [opened, reopened, edited, synchronize]

permissions:
  pull-requests: read

jobs:
  title:
    name: Validate PR title
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### `.github/workflows/clean.yml`

```yaml
---
name: clean
# GHCR housekeeping: prune image versions older than 90 days (keeping the
# newest 7 tagged) and orphaned untagged layers, so the package does not grow
# without bound from the daily builds.
on:
  schedule:
    - cron: "15 0 * * 0" # 0015 UTC on Sundays
  workflow_dispatch:

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}

jobs:
  delete-older-than-90:
    name: Prune old GHCR versions
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    permissions:
      packages: write
    steps:
      - name: Delete Images Older Than 90 Days
        uses: dataaxiom/ghcr-cleanup-action@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          packages: halcyon
          older-than: 90 days
          delete-orphaned-images: true
          keep-n-tagged: 7
          keep-n-untagged: 7
```

### `.github/dependabot.yml`

```yaml
# If the Renovate app is installed on this repo, delete this file: both bots
# would open competing PRs for the same actions. Renovate (renovate.json5) also
# tracks the Containerfile base image, which Dependabot's docker ecosystem has
# historically not recognised under the name "Containerfile".
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
    # One PR instead of one per action.
    groups:
      github-actions:
        patterns: ["*"]
    # semantic-pr.yml rejects titles like "Bump x from y to z".
    commit-message:
      prefix: "chore(deps)"
```

### `.github/pull_request_template.md`

```markdown
## halcyon — lean Hyprland gaming desktop on fedora-bootc

Thank you for contributing!

- Read [AGENTS.md](https://github.com/aahsnr-work/halcyon/blob/container/AGENTS.md)
  first — it documents the build architecture rules (stage order, repo
  lifecycle, per-stage verification, bootc constraints) every change must respect.
- Run `just check` and `just lint` locally before opening the PR; if you touched
  `build_files/python-packages/`, also `just lint-python` and `just test-python`.
- Use a [semantic](https://www.conventionalcommits.org) PR title (`feat:`, `fix:`,
  `refactor:`, `docs:`, `chore:`, …). `.github/workflows/semantic-pr.yml`
  enforces it on the title.
- Changes under `build_files/` cost a full ~40-minute CI build on mistake —
  double-check package names against `packages.json` groups.

### Checklist

- [ ] `just check` / `just lint` pass locally
- [ ] Every new gate was inverted once and confirmed to fail
- [ ] New install stage has a `<stage>-verify` companion wired into the same RUN
- [ ] Third-party repos enabled and disabled within the same stage
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`
- [ ] Every binary a new ujust recipe calls is in `packages.json`
- [ ] Workflow changes: no `@main`/`@master` pins, no `ubuntu-latest`
- [ ] Comments explaining _why_ are preserved
```

### `verify/verify-github.sh`

```bash
#!/usr/bin/env bash
# verify/verify-github.sh — HOST-side audit of the .github folder.
# Checks: required files, retired files stay retired, YAML parses, cron syntax,
# every `uses:` is pinned (vN tag or full SHA — Renovate rewrites tags to SHAs,
# so no specific major is hardcoded here), runners are pinned, the cosign
# legacy-format guard is present, and the log helper sources cleanly.
# Optional: runs actionlint if it is on PATH.
set -uo pipefail

fail=0
pass()  { printf '  PASS  %s\n' "$1"; }
failf() { printf '  FAIL  %s\n' "$1"; fail=1; }
info()  { printf '  INFO  %s\n' "$1"; }
warnf() { printf '  WARN  %s\n' "$1"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GH="${ROOT}/.github"
WF=("${GH}"/workflows/*.yml)

echo "::group::verify-github — required files"
for f in workflows/build.yml workflows/lint.yml workflows/clean.yml \
         workflows/semantic-pr.yml dependabot.yml renovate.json5 \
         log-helpers.sh pull_request_template.md CODEOWNERS; do
  if [ -f "${GH}/${f}" ]; then pass ".github/${f}"; else failf ".github/${f} missing"; fi
done
if [ -e "${GH}/semantic.yml" ]; then
  failf ".github/semantic.yml present — it configures a service that no longer runs; use workflows/semantic-pr.yml"
else
  pass "no dead .github/semantic.yml"
fi
echo "::endgroup::"

echo "::group::verify-github — YAML parse + workflow structure"
if python3 -c 'import yaml' 2>/dev/null; then
  for wf in "${WF[@]}"; do
    name="$(basename "${wf}")"
    if python3 - "${wf}" <<'PY'
import sys, yaml
docs = list(yaml.safe_load_all(open(sys.argv[1])))
sys.exit(0 if docs and docs[0] else 1)
PY
    then pass "${name}: YAML parses"; else failf "${name}: YAML does not parse"; fi
    grep -q '^name:' "${wf}" || failf "${name}: missing name:"
    grep -q '^on:'   "${wf}" || failf "${name}: missing on: trigger"
    grep -q '^jobs:' "${wf}" || failf "${name}: missing jobs:"
  done
else
  info "PyYAML unavailable — skipped parse checks (pip install pyyaml)"
fi
echo "::endgroup::"

echo "::group::verify-github — cron expressions"
cron_ok() {
  python3 - "$1" <<'PY'
import re, sys
c = sys.argv[1].split()
sys.exit(0 if len(c) == 5 and all(re.fullmatch(r'[\d*,/\-A-Za-z]+', f) for f in c) else 1)
PY
}
while IFS= read -r c; do
  if cron_ok "${c}"; then pass "cron '${c}' well-formed"; else failf "cron '${c}' malformed"; fi
done < <(grep -hoP 'cron:[[:space:]]*"\K[^"#]*' "${WF[@]}" | sed 's/[[:space:]]*$//')
echo "::endgroup::"

echo "::group::verify-github — action references + runners"
while IFS= read -r ref; do
  case "${ref}" in ./*|docker://*) continue ;; esac
  if [[ "${ref}" =~ ^[^@]+@([0-9a-f]{40}|v[0-9]+(\.[0-9]+){0,2})$ ]]; then
    pass "${ref}"
  else
    failf "${ref} — pin to a vN tag or a full commit SHA, never a branch"
  fi
done < <(grep -hoP 'uses:\s*\K[^\s#]+' "${WF[@]}" | sort -u)

if grep -nE 'runs-on:[[:space:]]*ubuntu-latest' "${WF[@]}" >/dev/null; then
  failf "runs-on: ubuntu-latest found — pin ubuntu-24.04 (latest migrates to 26.04 Oct–Nov 2026)"
else
  pass "no unpinned ubuntu-latest runners"
fi
if grep -nE 'uses:[[:space:]]*blue-build/' "${WF[@]}" >/dev/null; then
  failf "a workflow uses the blue-build action — this branch builds with podman via the Justfile"
else
  pass "no blue-build action in workflows"
fi
echo "::endgroup::"

echo "::group::verify-github — build.yml invariants"
B="${GH}/workflows/build.yml"
if grep -q -- '--new-bundle-format=false' "${B}"; then
  pass "cosign signs in the legacy format containers/image reads"
else
  failf "build.yml lacks --new-bundle-format=false — signed rebases will not verify"
fi
grep -q 'cosign verify --key cosign.pub --new-bundle-format=false' "${B}" \
  && pass "legacy-format verify step present" \
  || failf "legacy-format verify step missing (default verify accepts both formats and cannot catch this)"
grep -q 'PUBLISH_BRANCH' "${B}" \
  && pass "explicit publish gate present" \
  || failf "publish gate missing — scheduled/dispatch runs would not push"
if grep -q 'id-token:[[:space:]]*write' "${B}"; then
  failf "id-token: write present — key-based signing needs no OIDC"
else
  pass "no unnecessary id-token permission"
fi
for copr in "catpieleaf/kernel-p03" "lionheartp/Hyprland" "ublue-os/packages" "sneexy/zen-browser"; do
  grep -q "${copr}" "${B}" && pass "monitors ${copr}" || failf "missing COPR monitor for ${copr}"
done
echo "::endgroup::"

echo "::group::verify-github — default branch (informational)"
# Scheduled workflows run only from the repository's default branch.
default_ref="$(git -C "${ROOT}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
if [ -z "${default_ref}" ]; then
  info "default branch unknown locally — confirm it is 'container' (Settings → Branches), or the daily cron will not run this workflow"
elif [ "${default_ref}" = "origin/container" ]; then
  pass "default branch is container — cron and manual dispatch use this workflow"
else
  warnf "default branch is ${default_ref#origin/}: the daily cron runs THAT branch's workflow, not this one"
fi
echo "::endgroup::"

echo "::group::verify-github — log helpers"
if bash -n "${GH}/log-helpers.sh" 2>/dev/null; then pass "log-helpers.sh: bash -n clean"; else failf "log-helpers.sh: bash -n FAILED"; fi
if bash -c 'source "'"${GH}"'/log-helpers.sh" && banner t && step s && ok o && warn w >/dev/null 2>&1'; then
  pass "log-helpers.sh sources and helpers are callable"
else
  failf "log-helpers.sh: sourcing failed"
fi
echo "::endgroup::"

echo "::group::verify-github — actionlint (optional)"
if command -v actionlint >/dev/null 2>&1; then
  if actionlint -color=never -shellcheck= "${WF[@]}"; then pass "actionlint clean"; else failf "actionlint reported problems"; fi
else
  info "actionlint not installed — skipped"
fi
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-github: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-github FAILED"
exit 1
```

### `build_files/base/setup-repos`

```bash
#!/usr/bin/env bash
# halcyon build step — setup-repos (RPM Fusion NVIDIA-excluded + negativo17)
#
# Repo lifecycle policy (bazzite pattern + TODO "remove non-fedora repos
# after use"): third-party repos are enabled ONLY inside the stage that
# consumes them and disabled immediately after; finalize deletes every
# leftover repo file. This stage only sets up the two repos that several
# stages share:
#   - RPM Fusion (steam, media, gaming). Its NVIDIA packages are EXCLUDED
#     here — this is the ublue-os/akmods partition: NVIDIA userland/modules
#     come from negativo17 ONLY, so the solver can never pull the
#     conflicting RPM Fusion nvidia chain (xorg-x11-drv-nvidia →
#     nvidia-kmod → akmod-nvidia).
#   - negativo17 fedora-nvidia (NVIDIA userland matching the p03 modules).
#
# COPRs and vendor repos (lionheartp, sneexy, ublue-os/packages, catpieleaf,
# terra, vscode, brave) are handled per-use in their own stages.
#
# jq is installed HERE because packages-lib (sourced from Stage 02 onward)
# parses packages.json with it. The base image happens to ship jq today; this
# makes that an explicit dependency instead of an accident that would break
# silently on a base change.
set -euo pipefail
echo "::group::setup-repos — build tooling bootstrap"
dnf5 -y --setopt=install_weak_deps=False install \
  dnf5-plugins \
  jq
command -v jq >/dev/null 2>&1 || { echo "  FAIL  jq missing after install — packages.json is unreadable"; exit 1; }
echo "  OK    dnf5-plugins + jq present ($(jq --version))"
echo "::endgroup::"

echo "::group::setup-repos — base external repos"
# RPM Fusion (keys ship in the release RPMs; --nogpgcheck per RPM Fusion practice)
dnf5 -y --setopt=install_weak_deps=False --nogpgcheck install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 -y --setopt=install_weak_deps=False install \
  rpmfusion-free-appstream-data \
  rpmfusion-nonfree-appstream-data \
  || true
# NVIDIA exclusion on every RPM Fusion repo file (akmods partition)
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
  grep -q '^excludepkgs=' "${f}" || \
    echo "excludepkgs=xorg-x11-drv-nvidia* akmod-nvidia kmod-nvidia* nvidia-settings nvidia-modprobe nvidia-persistenced nvidia-driver-NVML" >> "${f}"
done
# negativo17 NVIDIA userland — the only NVIDIA source in this image
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
echo "::endgroup::"
```

### `build_files/base/remove-packages`

```bash
#!/usr/bin/env bash
# halcyon build step — remove-packages (removals FIRST, main's removals.yml ordering)
#
# Removals run against the PRISTINE base before anything is installed:
# dnf computes the removal set from the full Requires graph (file requires,
# rich deps, per-subpackage edges — Fedora splits units into many subpackages
# so name-level reasoning cannot bound the transaction), and autoremove reads
# install-reason state that is least trustworthy late in a build. On the
# untouched base the blast radius is smallest and any cascade that hits core
# tooling fails the build at the very next dnf call — loud, immediate.
# Everything halcyon needs is (re)installed explicitly by later stages.
#
# HISTORY: this stage used to call four helpers inherited from the Bazzite-fork
# era (guarded-removals, file-footprint, gnome-extensions, fonts-cleanup). On a
# bare fedora-bootc base every target of those scripts is absent, so they were
# ~400 lines of no-op whose comments described an ordering that no longer held.
# The two parts with real value — the sddm/cage reverse-dependency gate and the
# must-not-survive hard-fail — live below.
set -euo pipefail
# shellcheck source=build_files/packages-lib
source /ctx/packages-lib
packages_validate

echo "::group::remove-packages — proven-present removals (packages.json exclude.all)"
# The removal list lives in packages.json (all.exclude.all) and is resolved
# through rpm -qa first, so entries absent from the base are tolerated
# instead of failing the transaction.
readarray -t REMOVAL_CANDIDATES < <(packages_excludes)
PRESENT=()
if [ "${#REMOVAL_CANDIDATES[@]}" -gt 0 ]; then
  readarray -t PRESENT < <(rpm -qa --qf '%{NAME}\n' "${REMOVAL_CANDIDATES[@]}" 2>/dev/null | sort -u || true)
fi
# NOTE: ${#arr[@]} admits no :-default (bash 'bad substitution') — the
# array is initialized unconditionally above instead.
if [ "${#PRESENT[@]}" -gt 0 ]; then
  echo "  INFO  removing ${#PRESENT[@]} present package(s): ${PRESENT[*]}"
  # --no-autoremove here: the orphan sweep below is the only autoremove
  dnf5 -y remove --no-autoremove "${PRESENT[@]}"
else
  echo "  INFO  nothing from the removal list is installed (clean base)"
fi
echo "::endgroup::"

echo "::group::remove-packages — reverse-dep gated removals (sddm, cage)"
# Display managers the base may pull in transitively. Remove only when
# nothing installed still requires them — halcyon logs in through greetd.
GATED=()
for p in sddm cage; do
  if ! rpm -q "$p" >/dev/null 2>&1; then
    echo "  SKIP  ${p} not installed"
    continue
  fi
  reqs="$(dnf5 -q repoquery --installed --whatrequires "$p" 2>/dev/null | grep -Ev "^${p}(-[0-9])?" || true)"
  if [ -n "${reqs}" ]; then
    echo "  GATE  keeping ${p} — required by:"
    # shellcheck disable=SC2001  # indenting multi-line output, not a substitution
    echo "${reqs}" | sed 's/^/          /'
  else
    echo "  GATE  removing ${p} — nothing installed requires it"
    GATED+=("$p")
  fi
done
if [ "${#GATED[@]}" -gt 0 ]; then
  dnf5 -y remove --no-autoremove "${GATED[@]}"
fi
echo "::endgroup::"

echo "::group::remove-packages — base orphan sweep"
# smallest graph the build will ever see
dnf5 -y autoremove || true
echo "::endgroup::"

echo "::group::remove-packages — hard-fail verification (must-be-gone)"
# A survivor means the removal transaction silently declined and a later stage
# would ship it.
rc=0
for p in gnome-shell gdm mutter nautilus firefox waydroid inputplumber; do
  if rpm -q "$p" >/dev/null 2>&1; then
    ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || echo "?")
    echo "  FAIL  ${p}-${ver} still installed after removals" >&2
    rc=1
  else
    echo "  PASS  ${p} — absent (correct)"
  fi
done
echo "::endgroup::"

# NOTE: keeper verification (steam/gamescope/scx/umu/bazaar/lutris/…) lives in
# final-verify — it must gate the FINAL state, and this stage runs before
# anything is installed.
exit "${rc}"
```

### `build_files/desktop/image-info`

```bash
#!/usr/bin/env bash
# halcyon build step — image-info (os-release identity + plymouth theme)
# assets. PRETTY_NAME reflects the actual base (MIGRATION-sanctioned
# divergence from main's "halcyon (Bazzite fork)"); HOME_URL matches main.
set -euo pipefail
echo "::group::image-info — os-release + plymouth"
sed -i 's|^NAME=.*|NAME=halcyon|; s|^PRETTY_NAME=.*|PRETTY_NAME="halcyon (Fedora bootc)"|' /usr/lib/os-release
if grep -q '^HOME_URL=' /usr/lib/os-release; then
  sed -i 's|^HOME_URL=.*|HOME_URL=https://github.com/aahsnr-work/halcyon|' /usr/lib/os-release
else
  echo 'HOME_URL=https://github.com/aahsnr-work/halcyon' >> /usr/lib/os-release
fi
# plymouth theme assets are generated from the baked astronaut wallpaper.
# NOTE: ctx is flat per build_files subfolder — build-plymouth-assets lives in
# desktop/ next to this script, NOT in branding/.
/ctx/desktop/build-plymouth-assets
echo "::endgroup::"

echo "::group::image-info — image-info.json + sigstore policy assets"
# bazzite-steam / bazzite-steam-firstrun / 83-halcyon-audio read this file
install -d /usr/share/ublue-os
cat >/usr/share/ublue-os/image-info.json <<EOF
{ "image-name": "halcyon",
  "image-vendor": "aahsnr-work",
  "image-ref": "ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon",
  "image-tag": "latest",
  "base-image-name": "fedora-bootc",
  "fedora-version": "$(rpm -E %fedora)" }
EOF
chmod 0644 /usr/share/ublue-os/image-info.json

# Signed-rebase support: ship the cosign public key plus a sigstore policy
# entry so `bootc switch --enforce-container-sigpolicy ostree-image-signed:...`
# verifies out of the box.
#
# The key goes in /etc/pki/containers, NOT /usr/etc: /usr/etc is bootc's
# client-side view of the default /etc, must not be populated by images, and is
# checked by `bootc container lint`.
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/halcyon.pub
install -d /etc/containers/registries.d
cat >/etc/containers/registries.d/halcyon.yaml <<'YAML'
docker:
  ghcr.io/aahsnr-work/halcyon:
    use-sigstore-attachments: true
YAML
# policy.json: require our sigstore signature for our image path, accept
# everything else (the bootc default).
#
# signedIdentity matchRepository is REQUIRED: cosign signs by digest
# (repo@sha256:...) so the signed identity is the repository, but bootc pulls by
# tag (repo:latest). The default matcher wants an exact identity match for
# tag-referenced images and would reject the signature.
cat >/etc/containers/policy.json <<'POLICY'
{
    "default": [{"type": "insecureAcceptAnything"}],
    "transports": {
        "docker": {
            "ghcr.io/aahsnr-work/halcyon": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "/etc/pki/containers/halcyon.pub",
                    "signedIdentity": {"type": "matchRepository"}
                }
            ]
        }
    }
}
POLICY
echo "  OK    image-info.json + halcyon.pub + policy.json + registries.d written"
echo "::endgroup::"
```

### `build_files/desktop/branding-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — branding level (runs immediately after image-info).
# Adapted from main's branding-verify.sh.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::branding-verify — os-release + plymouth"
gate "os-release NAME=halcyon"           grep -q '^NAME=halcyon' /usr/lib/os-release
gate "os-release PRETTY_NAME"            grep -q '^PRETTY_NAME="halcyon' /usr/lib/os-release
gate "os-release HOME_URL"               grep -q '^HOME_URL=https://github.com/aahsnr-work/halcyon' /usr/lib/os-release
gate "image-info.json present"           test -s /usr/share/ublue-os/image-info.json
gate "sigstore pubkey shipped"           test -s /etc/pki/containers/halcyon.pub
gate "no /usr/etc tree created"          sh -c '! test -e /usr/etc'
gate "sigstore policy entry"             grep -q '"type": "sigstoreSigned"' /etc/containers/policy.json
gate "policy keyPath matches shipped key" grep -q '"keyPath": "/etc/pki/containers/halcyon.pub"' /etc/containers/policy.json
gate "policy matches signatures by repo" grep -q '"type": "matchRepository"' /etc/containers/policy.json
gate "registries.d sigstore attachments" grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/halcyon.yaml
gate "plymouth theme selected"           grep -q 'Theme=halcyon' /etc/plymouth/plymouthd.conf
gate "plymouth theme file"               test -f /usr/share/plymouth/themes/halcyon/theme.plymouth
gate "plymouth background asset"         test -f /usr/share/plymouth/themes/halcyon/background.png
gate "plymouth throbber frames"          sh -c 'ls /usr/share/plymouth/themes/halcyon/throbber-*.png >/dev/null 2>&1'
gate "wallpaper baked"                   test -f /usr/share/backgrounds/halcyon/astronaut.png
echo "::endgroup::"
[ "$fail" = 0 ] || { echo "::error::branding-verify failed"; exit 1; }
echo "--- branding-verify: all checks passed ---"
```

### `build_files/runtime/ujust-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — ujust level (runs immediately after setup-ujust).
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::ujust-verify — machinery + module registration"
gate "ujust wrapper present"             test -x /usr/bin/ujust
gate "ujust lib helpers present"         test -f /usr/lib/ujust/ujust.sh
gate "shared justfile present"           test -f /usr/share/ublue-os/justfile
gate "base modules present"              test -f /usr/share/ublue-os/just/00-default.just
gate "vendored halcyon modules present"  test -f /usr/share/ublue-os/just/80-halcyon.just
gate "60-custom import hook written"     test -f /usr/share/ublue-os/just/60-custom.just
gate "60-custom imports halcyon modules" grep -q 'halcyon-rebase.just' /usr/share/ublue-os/just/60-custom.just
gate "60-custom imports bazzite modules" grep -q '80-halcyon.just' /usr/share/ublue-os/just/60-custom.just
gate "justfile imports 60-custom"        grep -q '60-custom.just' /usr/share/ublue-os/justfile
gate "uupd installed"                    rpm -q uupd
gate "uupd.timer unit present"           test -f /usr/lib/systemd/system/uupd.timer
gate "ujust recipes resolve"             ujust --list >/dev/null 2>&1
echo "::endgroup::"

echo "::group::ujust-verify — interactive chooser (ujust --choose)"
# `ujust --choose` shells out to `just --choose`, whose default chooser is fzf.
# ugum also falls back to fzf when the gum binary is absent, so fzf is the one
# hard requirement for every interactive prompt.
gate "fzf installed (chooser)"           rpm -q fzf
gate "just supports --choose"            sh -c 'just --help 2>&1 | grep -q -- --choose'
# shellcheck disable=SC2016
gate "ujust list output non-empty"       sh -c '[ -n "$(ujust --list 2>/dev/null)" ]'
echo "::endgroup::"

echo "::group::ujust-verify — binaries the shipped recipes shell out to"
gate "grubby (kernel-arg recipes)"       command -v grubby
gate "ethtool (wol recipe)"              command -v ethtool
gate "wget (audio HRTF download)"        command -v wget
gate "hostname (ssh recipe)"             command -v hostname
gate "fpaste (get-logs recipe)"          command -v fpaste
gate "wl-copy (get-logs recipe)"         command -v wl-copy
gate "zenity (steam wrappers)"           command -v zenity
gate "jq (image-info consumers)"         command -v jq
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::ujust-verify failed"; exit 1; }
echo "--- ujust-verify: all checks passed ---"
```

### `build_files/brew/brew-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — brew level (runs immediately after install-brew-bundle in
# the same RUN, so the payload install-brew-bundle bakes must already exist).
# Mirrors main's brew-verify.sh: Brewfile + baked payload + per-formula pour
# receipts + "no /var state in the layer" + unit/helper/env wiring.
set -euo pipefail

fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }

PAYLOAD=/usr/share/halcyon/brew-bundle.tar.zst
BREWFILE=/usr/share/ublue-os/homebrew/Brewfile

echo "::group::brew-verify — Brewfile + baked payload"
gate "Brewfile staged"                    test -f "${BREWFILE}"
formula_count=$(grep -cE '^[[:space:]]*brew "?[^" ]+"?' "${BREWFILE}" || true)
echo "  INFO  ${BREWFILE}: ${formula_count} formulas"
gate "Brewfile non-empty"                 test "${formula_count}" -gt 0

gate "brew payload present"               test -s "${PAYLOAD}"
if [ -s "${PAYLOAD}" ]; then
  size=$(du -h "${PAYLOAD}" | cut -f1)
  PAYLIST="$(mktemp)"
  PAYLIST_LONG="$(mktemp)"
  trap 'rm -f "${PAYLIST}" "${PAYLIST_LONG}"' EXIT
  tar --zstd -tf "${PAYLOAD}" >"${PAYLIST}"
  tar --zstd -tvf "${PAYLOAD}" >"${PAYLIST_LONG}"
  entries=$(wc -l <"${PAYLIST}")
  echo "  INFO  payload: ${size}, ${entries} entries"
  gate "payload carries brew core"        grep -qF 'home/linuxbrew/.linuxbrew/bin/brew' "${PAYLIST}"

  # brew-update.service / brew-upgrade.service gate on
  # ConditionPathIsSymbolicLink=/home/linuxbrew/.linuxbrew/bin/brew. If the
  # payload ever carries a regular file there, BOTH timers skip forever without
  # reporting anything. Assert the link survives the pack.
  gate "bin/brew is a symlink in payload" \
    grep -qE '^l.*home/linuxbrew/\.linuxbrew/bin/brew ->' "${PAYLIST_LONG}"

  echo "--- Checking every Brewfile formula is inside the payload ---"
  # "Inside" means a COMPLETE pour: Cellar/<name>/<version>/INSTALL_RECEIPT.json.
  # grep -c (no -q, no early exit) for the two-stage match: `grep | grep -q`
  # under pipefail can die with SIGPIPE (141) — a false negative seen live.
  missing=0
  while IFS= read -r name; do
    [ -z "${name}" ] && continue
    receipts=$(grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | grep -cF "INSTALL_RECEIPT.json" || true)
    if [ "${receipts}" -gt 0 ]; then
      echo "  PASS  payload contains a complete pour of Cellar/${name} (${receipts} receipt(s))"
    else
      echo "  FAIL  Cellar/${name} not found (complete) in payload — payload entries for it:"
      grep -F "Cellar/${name}/" "${PAYLIST}" 2>/dev/null | head -5 | sed 's/^/        /' || true
      missing=$((missing + 1))
    fi
  done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
  if [ "${missing}" -gt 0 ]; then
    echo "  FAIL  ${missing} formula(s) missing from the payload"
    fail=1
  fi
fi
echo "::endgroup::"

echo "::group::brew-verify — Brewfile carries only what Fedora/Terra do not ship"
# environment.d APPENDS the brew dirs to PATH, so an RPM always wins. A formula
# that also has an RPM is poured, shipped and permanently shadowed. Warn only:
# a new no-RPM formula is legitimate, add it to the allowlist below.
dupes=0
while IFS= read -r name; do
  [ -z "${name}" ] && continue
  case "${name}" in
    bun|pixi|opencode) continue ;;
  esac
  echo "  WARN  ${name} is in the Brewfile but not on the no-RPM allowlist — confirm Fedora/Terra really lack it"
  dupes=$((dupes + 1))
done < <(sed -nE 's/^[[:space:]]*brew "?([^" ]+)"?.*/\1/p' "${BREWFILE}" | sed 's|^.*/||')
[ "${dupes}" -eq 0 ] && echo "  OK    no RPM-shadowed formulas in the Brewfile"
echo "::endgroup::"

echo "::group::brew-verify — no /var state in the layer"
gate "no /home/linuxbrew in the layer"    test ! -e /home/linuxbrew
gate "no /var/home/linuxbrew in layer"    test ! -e /var/home/linuxbrew
gate "no build HOME residue"              test ! -e /var/tmp/brew-build-home
echo "::endgroup::"

echo "::group::brew-verify — units + runtime helpers + environment wiring"
gate "system seeding unit"                test -f /usr/lib/systemd/system/halcyon-brew-bundle.service
gate "user fallback unit"                 test -f /usr/lib/systemd/user/brew-bundle.service
gate "brew-update.service"                test -f /usr/lib/systemd/system/brew-update.service
gate "brew-update.timer"                  test -f /usr/lib/systemd/system/brew-update.timer
gate "brew-upgrade.service"               test -f /usr/lib/systemd/system/brew-upgrade.service
gate "brew-upgrade.timer"                 test -f /usr/lib/systemd/system/brew-upgrade.timer
gate "boot-time extractor shipped"        test -x /usr/libexec/halcyon-image/brew-bundle-extract
gate "login fallback shipped"             test -x /usr/libexec/halcyon-image/brew-bundle-install
gate "environment.d brew PATH"            grep -q 'HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew' /etc/environment.d/10-homebrew.conf
gate "profile.d interactive hook"         test -f /etc/profile.d/brew.sh
gate "tmpfiles rules"                     grep -q 'var/home/linuxbrew' /usr/lib/tmpfiles.d/zz-halcyon-homebrew.conf
echo "::endgroup::"

[ "${fail}" -eq 0 ] || { echo "::error::brew-verify failed"; exit 1; }
echo "--- brew-verify: all checks passed ---"
```

### `system_files/shared/usr/share/ublue-os/homebrew/Brewfile`

```ruby
# halcyon Brewfile — ONLY formulas Fedora and Terra do not ship.
#
# Everything else (bat, btop, cava, chafa, direnv, dust, eza, fd, fzf, gnuplot,
# lazygit, pandoc, ripgrep, starship, tealdeer, uv, yazi, zellij, atuin) is an
# RPM from install-devtools / install-terra. environment.d APPENDS the brew bin
# dirs to PATH so RPMs keep priority — a brewed duplicate can never be the
# binary that runs, yet still costs build time (22 pours × up to 3 retries) and
# boot-time extraction of the payload. install-devtools already documents this
# intent ("brew only backfills what Fedora does not ship").
#
# Before adding a formula: if an RPM exists in Fedora or Terra, it belongs in
# packages.json instead.
brew "bun"
brew "pixi"
brew "opencode"
```

### `build_files/finish/final-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — FINAL cross-cutting gates. Stage-scoped checks live in
# their per-level companions (packages/nix/flatpaks/built-apps/ujust/system/
# branding-verify); this script gates what only the finished image can answer:
# the p03 kernel + NVIDIA end state, the third-party repo sweep, the gaming
# keeper set, and the baked package census.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::final-verify — p03 kernel + NVIDIA end state"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03)"
# the COPR kmod package's %{VERSION} is the KERNEL version — the DRIVER
# version lives in the module metadata, which is what the userland must match
NV_KO="$(find "/usr/lib/modules/${KVER}" -name 'nvidia.ko*' 2>/dev/null | head -1)"
NV_MOD_VER="$(modinfo -F version "${NV_KO}" 2>/dev/null || true)"
gate "p03 kernel installed"              rpm -q kernel-p03
gate "nvidia-open built for p03"         rpm -q kernel-p03-nvidia-open
gate "stock kernel absent"               sh -c '! rpm -q kernel >/dev/null 2>&1'
gate "p03 vmlinuz"                       test -f "/usr/lib/modules/${KVER}/vmlinuz"
gate "p03 initramfs"                     test -f "/usr/lib/modules/${KVER}/initramfs.img"
gate "nvidia modules for p03"            sh -c "find /usr/lib/modules/${KVER} -name 'nvidia.ko*' | grep -q ."
gate "p03 keeps SELinux config"          grep -q '^CONFIG_SECURITY_SELINUX=y' "/usr/lib/modules/${KVER}/config"
gate "nvidia SELinux policy linked"      sh -c 'semodule -lfull 2>/dev/null | grep -q nvidia-driver'
# Without this, `test "" = ""` PASSES when modinfo failed, turning the single
# most important NVIDIA gate into a no-op.
gate "nvidia module version readable"    test -n "${NV_MOD_VER}"
gate "nvidia userland matches modules"   test "${NV_MOD_VER}" = "$(rpm -q --qf '%{VERSION}' nvidia-driver-libs.x86_64)"
gate "nvidia-smi present"                test -x /usr/bin/nvidia-smi
gate "32-bit nvidia + mesa libs"         rpm -q nvidia-driver-libs.i686 mesa-libGL.i686
echo "::endgroup::"

echo "::group::final-verify — gaming keeper set (final state)"
gate "gaming keeper packages"            sh -c 'rpm -q scx-scheds scx-tools umu-launcher umu-wrapper bazaar bazzite-portal lutris gamescope input-remapper usbip'
gate "steam installed"                   rpm -q steam
gate "bazzite-steam wrapper"             test -x /usr/bin/bazzite-steam
gate "steam desktop -> bazzite-steam"    grep -q 'bazzite-steam' /usr/share/applications/steam.desktop
gate "devtools (terra + fedora)"         sh -c "rpm -q zed starship yazi zellij golang-github-jesseduffield-lazygit bat eza fzf pandoc-cli chezmoi"
echo "::endgroup::"

echo "::group::final-verify — repo end state"
# finalize DELETES every third-party repo file (including terra*.repo), so a
# "terra repos all disabled" glob gate would match nothing and could never fail.
# This single gate is the property that survives.
gate "only Fedora repo files remain"     sh -c '! ls /etc/yum.repos.d/ | grep -Eqi "copr|vscode|brave|terra|negativo|rpmfusion"'
echo "::endgroup::"

echo "::group::final-verify — homebrew + chezmoi end state"
gate "brew payload baked in /usr"        test -s /usr/share/halcyon/brew-bundle.tar.zst
gate "brew seeding unit enabled"         systemctl is-enabled halcyon-brew-bundle.service
gate "brew helpers shipped"              sh -c 'test -x /usr/libexec/halcyon-image/brew-bundle-extract && test -x /usr/libexec/halcyon-image/brew-bundle-install'
gate "Brewfile shipped"                  sh -c 'test -f /usr/share/ublue-os/homebrew/Brewfile && grep -q "^brew " /usr/share/ublue-os/homebrew/Brewfile'
gate "chezmoi installed"                 rpm -q chezmoi
gate "chezmoi-init wired --global"       test -L /etc/systemd/user/default.target.wants/chezmoi-init.service
gate "chezmoi-update.timer wired"        test -L /etc/systemd/user/timers.target.wants/chezmoi-update.timer
echo "::endgroup::"

# --- package census (distinctively reported in CI; baked into the image) ---
echo "::group::final-verify — package census"
TOTAL_PACKAGES="$(rpm -qa | wc -l)"
echo "  ############################################"
echo "  INFO  total installed RPM packages: ${TOTAL_PACKAGES}"
echo "  ############################################"
echo "::notice title=halcyon package count::${TOTAL_PACKAGES} RPMs installed"
echo "  INFO  per-vendor breakdown (repo provenance):"
rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/        /'
install -d -m0755 /usr/share/halcyon
{
  echo "halcyon image package census (generated at build time)"
  echo "date_utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "kernel_p03: $(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-p03 2>/dev/null || echo unknown)"
  echo "total_packages: ${TOTAL_PACKAGES}"
  echo
  echo "per-vendor:"
  rpm -qa --qf '%{VENDOR}\n' | sed 's/^$/  (no vendor)/' | sort | uniq -c | sort -rn | sed 's/^/  /'
} > /usr/share/halcyon/package-count
chmod 0644 /usr/share/halcyon/package-count
gate "package census baked"              test -s /usr/share/halcyon/package-count
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::final-verify failed"; exit 1; }
echo "--- final-verify: all checks passed ---"
```

### `build_files/packages/install-packages`

```bash
#!/usr/bin/env bash
# halcyon build step — install-packages (core + desktop + gaming + apps)
# Policy: --setopt=install_weak_deps=False on EVERY install; anything that
# used to arrive as a weak dep must be listed explicitly (e.g. flatpak-selinux
# in setup-flatpaks, hyprland-guiutils/xdg portals below).
# Package LISTS live in packages.json — this stage owns the repo windows and
# flags only.
set -euo pipefail
# shellcheck source=build_files/packages-lib
source /ctx/packages-lib
packages_validate
echo "::group::install-packages — core + hardware + editors (Fedora)"

# --- core set (main core.yml parity; Fedora repos) ---
# The @custom-environment comps group stays here — comps groups are not
# catalog entries in packages.json.
dnf5 -y --setopt=install_weak_deps=False group-install \
  custom-environment \
  || true
readarray -t CORE_PKGS < <(packages_for fedora-core)
dnf5 -y --setopt=install_weak_deps=False install \
  "${CORE_PKGS[@]}"

# --- hardware support the Bazzite base used to provide (fedora-bootc is
# bare; rakuos-base installs the same classes explicitly) ---
readarray -t HW_PKGS < <(packages_for fedora-hardware)
dnf5 -y --setopt=install_weak_deps=False install \
  "${HW_PKGS[@]}"

# --- editors + language runtimes (Fedora). These used to sit in vendor-apps
# and install inside the vscode/brave repo window, which misdescribed where
# they resolve from. Plain Fedora packages: no third-party repo needed.
readarray -t EDITOR_PKGS < <(packages_for fedora-editors)
dnf5 -y --setopt=install_weak_deps=False install \
  "${EDITOR_PKGS[@]}"
echo "::endgroup::"

echo "::group::install-packages — desktop stack (COPR lionheartp/Hyprland)"
# NOTE: weak deps are OFF, so every Hyprland-stack weak dep we rely on must
# be listed in the group explicitly (hyprland-guiutils,
# xdg-desktop-portal-{hyprland,gtk}, qt6ct, nwg-look, ...).
dnf5 -y copr enable lionheartp/Hyprland
readarray -t HYPRLAND_PKGS < <(packages_for hyprland-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${HYPRLAND_PKGS[@]}"
dnf5 -y copr disable lionheartp/Hyprland
echo "::endgroup::"

echo "::group::install-packages — gaming (RPM Fusion + Fedora)"
# terra bits live in install-terra. gamescope + mangohud come from Fedora now
# (terra-gamescope/-mangohud were retired upstream); mangohud.i686 covers
# 32-bit overlays for Steam/Proton.
readarray -t GAMING_PKGS < <(packages_for gaming)
dnf5 -y --setopt=install_weak_deps=False install \
  "${GAMING_PKGS[@]}"
echo "::endgroup::"

echo "::group::install-packages — bazaar (COPR ublue-os/packages)"
dnf5 -y copr enable ublue-os/packages
readarray -t BAZAAR_PKGS < <(packages_for bazaar-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${BAZAAR_PKGS[@]}"
dnf5 -y copr disable ublue-os/packages
echo "::endgroup::"

echo "::group::install-packages — browsers + vendor repos (per-use)"
# zen-browser (sneexy COPR per-use)
dnf5 -y copr enable sneexy/zen-browser
readarray -t ZEN_PKGS < <(packages_for zen-copr)
dnf5 -y --setopt=install_weak_deps=False install \
  "${ZEN_PKGS[@]}"
dnf5 -y copr disable sneexy/zen-browser

# vscode/brave vendor repos: written, used, disabled and deleted inside this
# stage. Only packages that genuinely resolve from these repos belong in the
# vendor-apps group.
install -Dm0644 /dev/null /etc/yum.repos.d/vscode.repo
cat > /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
install -Dm0644 /dev/null /etc/yum.repos.d/brave-browser.repo
cat > /etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
type=rpm-md
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
readarray -t VENDOR_PKGS < <(packages_for vendor-apps)
dnf5 -y --setopt=install_weak_deps=False install \
  "${VENDOR_PKGS[@]}"
# brave-origin: skip-unavailable semantics (may not exist in the vendor repo)
readarray -t VENDOR_OPT_PKGS < <(packages_for vendor-apps-optional)
if [ "${#VENDOR_OPT_PKGS[@]}" -gt 0 ]; then
  dnf5 -y --setopt=install_weak_deps=False install \
    "${VENDOR_OPT_PKGS[@]}" \
    || true
fi
rm -f /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/brave-browser.repo
echo "::endgroup::"
```

### `build_files/packages/packages-verify`

```bash
#!/usr/bin/env bash
# halcyon verify — packages level (runs immediately after install-packages):
# desktop stack, apps, and the third-party repo end state of that stage.
# Adapted from main's desktop-verify.sh + apps-verify.sh.
set -euo pipefail
fail=0
gate() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi; }
echo "::group::packages-verify — desktop stack"
gate "hyprland-git installed"            rpm -q hyprland-git
gate "hyprland-guiutils installed"       rpm -q hyprland-guiutils
gate "noctalia-greeter-git installed"    rpm -q noctalia-greeter-git
gate "greetd installed"                  rpm -q greetd
gate "xdg-desktop-portal-hyprland"       rpm -q xdg-desktop-portal-hyprland
gate "xdg-desktop-portal-gtk"            rpm -q xdg-desktop-portal-gtk
gate "kitty + terminfo"                  rpm -q kitty kitty-terminfo
gate "thunar + archive plugin"           rpm -q Thunar thunar-archive-plugin
gate "greeter wrapper executable"        test -x /usr/bin/noctalia-greeter-session
gate "greetd launches noctalia"          grep -qF 'noctalia-greeter-session' /etc/greetd/config.toml
gate "fonts: jetbrains-mono"             rpm -q jetbrains-mono-fonts
gate "fonts: noto emoji + color emoji"   rpm -q google-noto-emoji-fonts google-noto-color-emoji-fonts
echo "::endgroup::"

echo "::group::packages-verify — build-tool preconditions for later stages"
# install-brew-bundle (Stage 07) and install-texlive (Stage 10) hard-fail
# without these. Catching it here names the missing package; catching it there
# names a stage that looks unrelated.
gate "zstd (brew payload packing)"       command -v zstd
gate "setpriv (brew uid drop)"           command -v setpriv
gate "gpg (texlive signature check)"     command -v gpg
gate "jq (packages-lib + runtime)"       command -v jq
gate "gcc (brew formula postinstall)"    command -v gcc
echo "::endgroup::"

echo "::group::packages-verify — apps + repo end state"
gate "vs code installed"                 rpm -q code
gate "brave-browser installed"           rpm -q brave-browser
gate "zen-browser installed"             rpm -q zen-browser
gate "neovim + emacs-pgtk"               rpm -q neovim emacs-pgtk
gate "vscode repo file removed"          sh -c '! test -f /etc/yum.repos.d/vscode.repo'
gate "brave repo file removed"           sh -c '! ls /etc/yum.repos.d/brave-browser* >/dev/null 2>&1'
gate "consumed COPR repos disabled"      sh -c '! grep -l "^enabled=1" /etc/yum.repos.d/_copr:*lionheartp* /etc/yum.repos.d/_copr:*sneexy* 2>/dev/null | grep -q .'
echo "::endgroup::"

[ "$fail" = 0 ] || { echo "::error::packages-verify failed"; exit 1; }
echo "--- packages-verify: all checks passed ---"
```

### `build_files/apps/install-texlive`

The first build after this change will exercise TeX Live's GPG signature verification for the first time, because `gnupg2` is now installed. If it fails, fix the mirror or key. Don't remove `gnupg2`.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "::group::install-texlive — setup"
TEXLIVE_INSTALL_DIR="/usr/lib/texlive"
mkdir -p "${TEXLIVE_INSTALL_DIR}"
echo "  INFO  install dir: ${TEXLIVE_INSTALL_DIR}"

# Additional TeX Live packages to install via tlmgr at build time.
# Add any individual packages here that you would like baked into the immutable image.
EXTRA_TL_PACKAGES=(
  latexmk
  biber
)
echo "  INFO  extra tlmgr packages: ${EXTRA_TL_PACKAGES[*]}"

TEXLIVE_TMP="$(mktemp -d)"
trap 'echo "  INFO  cleaning up ${TEXLIVE_TMP}"; rm -rf "${TEXLIVE_TMP}"' EXIT
echo "::endgroup::"

echo "::group::install-texlive — download installer"
echo "--- Fetching install-tl-unx.tar.gz ---"
# install-tl verifies downloads against TeX Live's GPG signatures by default as
# long as gpg is present — keep it that way; never pass --no-verify-downloads.
# gnupg2 is an explicit packages.json entry for exactly this reason: without it
# the installer silently downgrades to unverified.
if ! command -v gpg >/dev/null 2>&1; then
  echo "  FAIL  gpg not found in PATH — install-tl would skip signature verification" >&2
  echo "        gnupg2 must be installed by install-packages before this stage" >&2
  echo "::endgroup::"
  exit 1
fi
# mirror.ctan.org is a redirector that lands on a RANDOM CTAN mirror; some
# mirrors intermittently serve broken TLS chains, which aborts curl with a
# certificate error (--retry does not retry those). Try pinned reliable
# mirrors in order instead. Keep this list in sync with the -repository used
# for the installer run below.
TEXLIVE_MIRRORS=(
  "https://mirrors.mit.edu/CTAN/systems/texlive/tlnet"
  "https://ftp.fau.de/ctan/systems/texlive/tlnet"
  "https://ctan.math.illinois.edu/systems/texlive/tlnet"
  "https://mirror.ctan.org/systems/texlive/tlnet"
)
TARBALL=""
TL_REPO=""
for mirror in "${TEXLIVE_MIRRORS[@]}"; do
  echo "  INFO  trying ${mirror}"
  if curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors --max-time 600 --progress-bar \
      "${mirror}/install-tl-unx.tar.gz" -o "${TEXLIVE_TMP}/install-tl-unx.tar.gz"; then
    if gzip -t "${TEXLIVE_TMP}/install-tl-unx.tar.gz" 2>/dev/null; then
      TARBALL="${TEXLIVE_TMP}/install-tl-unx.tar.gz"
      TL_REPO="${mirror}"
      echo "  OK    downloaded install-tl-unx.tar.gz from ${mirror}"
      break
    fi
    echo "  WARN  tarball from ${mirror} failed the gzip integrity check — trying next mirror"
  else
    echo "  WARN  download from ${mirror} failed — trying next mirror"
  fi
done
if [ -z "${TARBALL}" ] || [ -z "${TL_REPO}" ]; then
  echo "  FAIL  Could not download install-tl-unx.tar.gz from any TeX Live mirror" >&2
  echo "::endgroup::"
  exit 1
fi
size=$(du -h "${TEXLIVE_TMP}/install-tl-unx.tar.gz" | cut -f1)
echo "  OK    downloaded install-tl-unx.tar.gz (${size})"

tar -xzf "${TEXLIVE_TMP}/install-tl-unx.tar.gz" -C "${TEXLIVE_TMP}"
echo "  OK    installer archive extracted"

INSTALLER="$(find "${TEXLIVE_TMP}" -mindepth 2 -maxdepth 2 -name 'install-tl' -type f -perm /111 | head -n1)"
if [[ -z "${INSTALLER}" || ! -x "${INSTALLER}" ]]; then
  echo "  FAIL  install-tl executable not found under ${TEXLIVE_TMP}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    install-tl found at ${INSTALLER}"
echo "::endgroup::"

echo "::group::install-texlive — write profile & run install-tl"
TL_SCHEME="scheme-small"
cat >"${TEXLIVE_TMP}/texlive.profile" <<EOF
selected_scheme ${TL_SCHEME}
TEXDIR ${TEXLIVE_INSTALL_DIR}
TEXMFLOCAL ${TEXLIVE_INSTALL_DIR}/texmf-local
TEXMFSYSVAR ${TEXLIVE_INSTALL_DIR}/texmf-var
TEXMFSYSCONFIG ${TEXLIVE_INSTALL_DIR}/texmf-config
instopt_adjustpath 0
tlpdbopt_autobackup 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF
echo "  OK    texlive.profile written (${TL_SCHEME}, no docs/src)"

echo "--- Running install-tl (this may take several minutes) ---"
if "${INSTALLER}" \
  -profile "${TEXLIVE_TMP}/texlive.profile" \
  -no-interaction \
  -repository "${TL_REPO}"; then
  echo "  OK    install-tl completed successfully"
else
  echo "  FAIL  install-tl exited non-zero" >&2
  exit 1
fi
echo "::endgroup::"

echo "::group::install-texlive — tlmgr extras & PATH setup"
TEXLIVE_BINDIR="$(find "${TEXLIVE_INSTALL_DIR}" -maxdepth 3 -type d -name 'x86_64-linux' | head -n1)"
if [ -z "${TEXLIVE_BINDIR}" ]; then
  # built-apps-verify gates on /usr/lib/texlive/bin/x86_64-linux/pdflatex and
  # /etc/profile.d/texlive.sh, so exiting 0 here only moved the failure one
  # stage later, where it looked unrelated to TeX Live.
  echo "  FAIL  Could not locate x86_64-linux bin dir under ${TEXLIVE_INSTALL_DIR}" >&2
  echo "::endgroup::"
  exit 1
fi
echo "  OK    TeX Live bin dir: ${TEXLIVE_BINDIR}"

if [ ${#EXTRA_TL_PACKAGES[@]} -gt 0 ]; then
  echo "--- Installing extra packages via tlmgr: ${EXTRA_TL_PACKAGES[*]} ---"
  if "${TEXLIVE_BINDIR}/tlmgr" \
    --repository "${TL_REPO}" \
    install "${EXTRA_TL_PACKAGES[@]}"; then
    echo "  OK    extra packages installed: ${EXTRA_TL_PACKAGES[*]}"
  else
    echo "  WARN  tlmgr extra package install exited non-zero" >&2
  fi
fi

install -d /etc/profile.d
cat >/etc/profile.d/texlive.sh <<EOF
# TeX Live (installed under /usr/lib/texlive during image build)
export PATH="${TEXLIVE_BINDIR}:\$PATH"
export MANPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/man:\${MANPATH:-}"
export INFOPATH="${TEXLIVE_INSTALL_DIR}/texmf-dist/doc/info:\${INFOPATH:-}"
EOF
chmod 644 /etc/profile.d/texlive.sh
echo "  OK    /etc/profile.d/texlive.sh written"

install_size=$(du -sh "${TEXLIVE_INSTALL_DIR}" | cut -f1)
echo "  OK    TeX Live (${TL_SCHEME}) installed to ${TEXLIVE_INSTALL_DIR} (${install_size})"
echo "--- install-texlive complete ---"
echo "::endgroup::"
```

### `packages.json`

Differences from your original: `fedora-editors` group split out of `vendor-apps`; `ethtool`, `gnupg2`, `hostname`, `util-linux-core`, `wget`, `zstd` added to `fedora-core`; `grubby` added to `ujust-fedora`. `nodejs24`, `nodejs24-npm`, `xorg-x11-server-Xorg` and the `fastfetch` exclude are unchanged.

```json
{
  "_docs": {
    "purpose": "Single source of truth for every dnf-managed package in the image (ublue-os/main packages.json style, adapted to halcyon's per-use repo policy).",
    "how-to-add": "Add the package name to the group whose REPO WINDOW it resolves in — not the group whose subject matter it fits. The stage that consumes that group handles repo enable/disable and flags. Groups map 1:1 to build stage scripts (see build_files/packages-lib).",
    "groups": {
      "fedora-core": "Desktop/base packages from Fedora repos (install-packages). The @custom-environment comps group stays hardcoded in install-packages (comps groups are not catalog entries).",
      "fedora-hardware": "Firmware/microcode/audio/32-bit-GL support (install-packages).",
      "fedora-editors": "Editors and language runtimes from Fedora (install-packages). Split out of vendor-apps, which they were never resolved from — they only worked because they installed inside the vscode/brave repo window.",
      "hyprland-copr": "Resolved from COPR lionheartp/Hyprland (install-packages). Weak deps are OFF — list every stack weak dep explicitly.",
      "gaming": "RPM Fusion + Fedora gaming packages (install-packages).",
      "bazaar-copr": "Resolved from COPR ublue-os/packages (install-packages).",
      "zen-copr": "Resolved from COPR sneexy/zen-browser (install-packages).",
      "vendor-apps": "Resolved from the per-use vendor repos written inside install-packages (vscode, brave) — NOTHING ELSE belongs here.",
      "vendor-apps-optional": "Installed with skip-unavailable semantics (may be absent from the vendor repo).",
      "fedora-devtools": "Former brew formulas available in Fedora (install-devtools).",
      "nix": "Winter-pattern nix packages (install-nix).",
      "flatpak": "The flatpak stack itself (setup-flatpaks); libnotify covers notify-send.",
      "ujust-copr": "ublue-os-just machinery + uupd from COPR ublue-os/packages (setup-ujust).",
      "ujust-fedora": "Fedora companions of the ujust tooling (setup-ujust). grubby backs the kernel-arg recipes (and hard-requires grub2-tools). ugum falls back to fzf when gum is absent, so gum is NOT required.",
      "terra": "Resolved EXCLUSIVELY from Terra repos (install-terra uses --disablerepo='*'). terra-release/-mesa/-multimedia are repo bootstrap and stay hardcoded there.",
      "exclude-all": "The 'exclude' block drives remove-packages (Stage 2); entries are resolved through rpm -qa first, so absent names are tolerated."
    },
    "build-tool-dependencies": "zstd, util-linux-core (setpriv), gcc-c++, git, curl and jq are hard preconditions of install-brew-bundle; gnupg2 is a hard precondition of install-texlive's signature verification. They are in fedora-core deliberately and gated by packages-verify — do not remove them as 'unused'."
  },
  "all": {
    "include": {
      "fedora-core": [
        "accountsservice",
        "adw-gtk3-theme",
        "bleachbit",
        "bluez",
        "bluez-libs",
        "bluez-tools",
        "brightnessctl",
        "cargo",
        "cmake",
        "cronie",
        "curl",
        "ddcutil",
        "distrobox",
        "ethtool",
        "fail2ban",
        "fastfetch",
        "file-roller",
        "flatseal",
        "fontconfig",
        "fonts-filesystem",
        "gcc-c++",
        "git",
        "gnupg2",
        "go",
        "grim",
        "gsettings-desktop-schemas",
        "gtk4-layer-shell",
        "gzip",
        "hostname",
        "hunspell",
        "hunspell-en",
        "hunspell-en-GB",
        "hunspell-en-US",
        "ImageMagick",
        "imv",
        "inotify-tools",
        "jetbrains-mono-fonts",
        "google-noto-emoji-fonts",
        "google-noto-color-emoji-fonts",
        "just",
        "liberation-fonts",
        "libinput-utils",
        "logrotate",
        "lynis",
        "man-db",
        "mpv",
        "ninja-build",
        "pipx",
        "pkgconf-pkg-config",
        "plymouth",
        "plymouth-theme-spinner",
        "podman",
        "podman-sequoia",
        "policycoreutils-python-utils",
        "pymol",
        "python3-xlib",
        "qt5ct",
        "setroubleshoot-server",
        "setroubleshoot-plugins",
        "setools-console",
        "slurp",
        "sqlite",
        "swappy",
        "transmission-gtk",
        "udica",
        "udiskie",
        "util-linux-core",
        "wget",
        "xdg-desktop-portal",
        "xdg-user-dirs",
        "xdg-user-dirs-gtk",
        "xorg-x11-server-Xorg",
        "xorg-x11-server-Xwayland",
        "xorg-x11-xauth",
        "zathura",
        "zathura-pdf-poppler",
        "zathura-plugins-all",
        "zstd",
        "zsh"
      ],
      "fedora-hardware": [
        "linux-firmware",
        "microcode_ctl",
        "amd-ucode-firmware",
        "amd-gpu-firmware",
        "intel-gpu-firmware",
        "nvidia-gpu-firmware",
        "atheros-firmware",
        "realtek-firmware",
        "iwlwifi-dvm-firmware",
        "iwlwifi-mvm-firmware",
        "alsa-firmware",
        "alsa-sof-firmware",
        "alsa-ucm",
        "NetworkManager-wifi",
        "wpa_supplicant",
        "pipewire",
        "pipewire-alsa",
        "pipewire-pulseaudio",
        "wireplumber",
        "pcsc-lite",
        "pcsc-lite-ccid",
        "mesa-dri-drivers",
        "mesa-vulkan-drivers",
        "mesa-libEGL",
        "mesa-libGL",
        "mesa-dri-drivers.i686",
        "mesa-vulkan-drivers.i686",
        "mesa-libEGL.i686",
        "mesa-libGL.i686"
      ],
      "fedora-editors": [
        "emacs-pgtk",
        "neovim",
        "nodejs24",
        "nodejs24-npm",
        "tree-sitter-cli"
      ],
      "hyprland-copr": [
        "cliphist",
        "greetd",
        "gnome-keyring",
        "gnome-tweaks",
        "hyprland-git",
        "hyprland-guiutils",
        "hyprpwcenter",
        "hyprshutdown",
        "kitty",
        "kitty-shell-integration",
        "kitty-terminfo",
        "noctalia-git",
        "noctalia-greeter-git",
        "nwg-look",
        "papers",
        "papirus-icon-theme",
        "qt6ct",
        "Thunar",
        "thunar-archive-plugin",
        "thunar-media-tags-plugin",
        "thunar-vcs-plugin",
        "thunar-volman",
        "xdg-desktop-portal-gtk",
        "xdg-desktop-portal-hyprland"
      ],
      "gaming": [
        "evtest",
        "gamemode",
        "gamescope",
        "input-remapper",
        "lutris",
        "mangohud",
        "mangohud.i686",
        "steam",
        "steam-devices",
        "usbip",
        "ydotool",
        "zenity"
      ],
      "bazaar-copr": ["bazaar"],
      "zen-copr": ["zen-browser"],
      "vendor-apps": ["code", "brave-browser"],
      "vendor-apps-optional": ["brave-origin"],
      "fedora-devtools": [
        "atuin",
        "bat",
        "btop",
        "cava",
        "chafa",
        "chezmoi",
        "direnv",
        "du-dust",
        "eza",
        "fd-find",
        "fpaste",
        "fzf",
        "wl-clipboard",
        "gnuplot",
        "jq",
        "pandoc-cli",
        "python3",
        "perl",
        "ripgrep",
        "tealdeer",
        "uv"
      ],
      "nix": ["nix", "nix-daemon"],
      "flatpak": ["flatpak", "flatpak-selinux", "libnotify"],
      "ujust-copr": ["uupd", "ublue-os-just", "ublue-os-update-services"],
      "ujust-fedora": ["glow", "grubby", "stress-ng"],
      "terra": [
        "zed",
        "scx-scheds",
        "scx-tools",
        "umu-launcher",
        "umu-wrapper",
        "bazzite-portal",
        "bibata-cursor-theme",
        "jetbrainsmono-nerd-fonts",
        "nerdfontssymbolsonly-nerd-fonts",
        "golang-github-jesseduffield-lazygit",
        "starship",
        "yazi",
        "zellij"
      ]
    },
    "exclude": {
      "all": [
        "nautilus-gsconnect",
        "gnome-shell-extension-gsconnect",
        "gnome-shell-extension-user-theme",
        "gnome-search-yafti",
        "gnome-rounded-blur",
        "firewall-config",
        "ibus-mozc",
        "ibus-pinyin",
        "ibus-table-chinese-cangjie",
        "ibus-table-chinese-quick",
        "inputplumber",
        "steamos-manager-powerstation",
        "jupiter-fan-control",
        "jupiter-hw-support-btrfs",
        "galileo-mura",
        "steamdeck-dsp",
        "powerbuttond",
        "vpower",
        "sdgyrodsu",
        "hid-replay",
        "steamdeck-backgrounds",
        "steamdeck-gnome-presets",
        "waydroid",
        "fastfetch",
        "firefox",
        "firefox-langpacks",
        "gnome-shell",
        "mutter",
        "gdm",
        "gnome-session",
        "gnome-session-wayland-session",
        "nautilus",
        "ptyxis",
        "gnome-control-center",
        "gnome-settings-daemon",
        "gjs",
        "xdg-desktop-portal-gnome",
        "nano",
        "nano-default-editor",
        "zram-generator-defaults"
      ]
    }
  },
  "flatpak": {
    "install": [
      "com.ranfdev.DistroShelf",
      "org.onlyoffice.desktopeditors",
      "com.bitwarden.desktop",
      "com.ticktick.TickTick"
    ],
    "remove": []
  }
}
```

### `Containerfile`

```dockerfile
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
#
# Every stage RUN opens with a "████ STAGE nn/17 · name · summary ████" banner
# so a human scrolling a CI log can find stage boundaries instantly; the build
# scripts themselves emit ::group:: folds + OK/FAIL prefixes inside each stage.

ARG FEDORA_VERSION=44

# --- build context: semantic helpers, never baked into the image ---
FROM scratch AS ctx
COPY build_files /
COPY packages.json /
# cosign.pub is consumed by the branding stage (sigstore policy assets)
COPY cosign.pub /

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

# CI passes --build-arg for the two volatile values (bazzite convention:
# version = <fedora-major>.<yyyymmdd>, revision = git sha)
ARG IMAGE_VERSION="44.0"
ARG SOURCE_SHA="unknown"

# The repo LICENSE and every pyproject.toml are Apache-2.0; the label set must
# agree (the Justfile's io.artifacthub.package.license is kept in sync).
LABEL org.opencontainers.image.title="halcyon" \
      org.opencontainers.image.description="Lean Hyprland gaming desktop — fedora-bootc + p03 kernel + NVIDIA open (negativo17 userland) + noctalia greeter + ujust/uupd" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_SHA}" \
      org.opencontainers.image.source="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.url="https://github.com/aahsnr-work/halcyon" \
      org.opencontainers.image.vendor="aahsnr-work" \
      org.opencontainers.image.licenses="Apache-2.0" \
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
    echo "████ STAGE 00/17 · dnf5 patience drop-in ████" \
    && install -Dm0644 /ctx/libdnf5.conf.d/99-halcyon-retries.conf \
      /etc/dnf/libdnf5.conf.d/99-halcyon-retries.conf

# ---- Stage 1: shared external repos + jq/dnf5-plugins bootstrap ------------
# Repos come first so the removals stage can read its list from packages.json;
# jq is installed explicitly because packages-lib cannot parse it without.
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 01/17 · setup-repos · base external repos + jq ████" \
    && /ctx/base/setup-repos && /ctx/cleanup

# ---- Stage 2: removals on the near-pristine base (JSON-driven, main ordering)
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 02/17 · remove-packages · removals on pristine base ████" \
    && /ctx/base/remove-packages && /ctx/cleanup

# ---- Stage 3: p03 kernel + prebuilt nvidia-open modules (Stage K1) ---------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 03/17 · install-kernel · p03 + nvidia-open (Stage K1) ████" \
    && /ctx/kernel/install-kernel && /ctx/kernel/kernel-verify && /ctx/cleanup

# ---- Stage 4: core + hardware + editors + desktop + gaming + apps ----------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 04/17 · install-packages · core + desktop + gaming + apps ████" \
    && /ctx/packages/install-packages && /ctx/packages/packages-verify && /ctx/cleanup

# ---- Stage 5: Terra packages (user-editable list, exclusive resolution) ----
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 05/17 · install-terra · Terra-only resolution ████" \
    && /ctx/packages/install-terra && /ctx/cleanup

# ---- Stage 6: devtools (Fedora brew-formula replacements) ------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 06/17 · install-devtools · Fedora devtools ████" \
    && /ctx/packages/install-devtools && /ctx/cleanup

# ---- Stage 7: Homebrew (core + the formulas Fedora/Terra lack, BAKED into a
#      /usr payload; halcyon-brew-bundle.service seeds it pre-login at boot) --
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 07/17 · install-brew-bundle · Homebrew bake ████" \
    && /ctx/brew/install-brew-bundle && /ctx/brew/brew-verify && /ctx/cleanup

# ---- Stage 8: nix (winter pattern) ------------------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 08/17 · install-nix · winter pattern ████" \
    && /ctx/runtime/install-nix && /ctx/runtime/nix-verify && /ctx/cleanup

# ---- Stage 9: flatpak (flathub USER repo only) ------------------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 09/17 · setup-flatpaks · flathub user repo ████" \
    && /ctx/runtime/setup-flatpaks && /ctx/runtime/flatpaks-verify && /ctx/cleanup

# ---- Stage 10: built apps (obsidian/zotero/pyprland/texlive/python) --------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 10/17 · install-built-apps · obsidian/zotero/pyprland/texlive/python ████" \
    && /ctx/apps/install-built-apps && /ctx/apps/built-apps-verify && /ctx/cleanup

# ---- Stage 11: ujust machinery (ublue-os-just) + uupd -----------------------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 11/17 · setup-ujust · ublue-os-just + uupd ████" \
    && /ctx/runtime/setup-ujust && /ctx/runtime/ujust-verify && /ctx/cleanup

# ---- Stage 12: system config (services, tmpfiles, chezmoi + brew wiring) ----
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 12/17 · configure-system · units + services ████" \
    && /ctx/desktop/configure-system && /ctx/desktop/system-verify && /ctx/cleanup

# ---- Stage 13: branding (os-release identity + plymouth theme + sigstore) ---
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 13/17 · image-info · os-release + plymouth + sigstore policy ████" \
    && /ctx/desktop/image-info && /ctx/desktop/branding-verify && /ctx/cleanup

# ---- Stage 14: initramfs LAST (plymouth theme + nvidia hooks baked in) ------
RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 14/17 · build-initramfs · dracut for p03 ████" \
    && /ctx/finish/build-initramfs && /ctx/cleanup

# ---- Stage 15: finalize (repo sweep + end-of-build hygiene) -----------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 15/17 · finalize · repo sweep + hygiene ████" \
    && /ctx/finish/finalize

# ---- Stage 16: final cross-cutting verification ------------------------------
RUN --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
    echo "████ STAGE 16/17 · final-verify · cross-cutting gates ████" \
    && /ctx/finish/final-verify

# ---- Final gate: hermetic bootc lint (bazzite pattern) -----------------------
# shell form here (not exec form) so the banner echo can share the RUN; bootc
# lint is short-lived so shell signal semantics are irrelevant.
RUN --mount=type=tmpfs,target=/run --network=none \
    echo "████ STAGE 17/17 · bootc container lint · hermetic final gate ████" \
    && bootc container lint
```

### `Justfile`

`check` and `lint` are unchanged from your original. New recipes: `lint-python`, `test-python`, `check-github`, `verify-image`. The license label is now Apache-2.0.

```make
# halcyon — repo task runner (adapted from ublue-os/image-template's Justfile;
# ISO/bootc-image-builder recipes deliberately omitted — see MIGRATION.md).
set dotenv-filename := "halcyon.env"

export image_name := env_var("IMAGE_NAME")
export repo_organization := env_var("REPO_ORGANIZATION")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")
export image_logo_url := env_var("IMAGE_LOGO_URL")
export default_tag := env_var("DEFAULT_TAG")
export fedora_version := env_var("FEDORA_VERSION")

default:
    @just --list

# Check Justfile + all build_files scripts + recipe bodies + verify helpers
[group('Just')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile || status=1

    echo "::group::bash -n — build_files scripts"
    while read -r file; do
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done < <(find build_files -type f \
               ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
               ! -name "*.json" ! -name "README*")
    echo "::endgroup::"

    echo "::group::bash -n — verify/ helpers + workflow shell code"
    for file in verify/*.sh .github/log-helpers.sh; do
        [ -e "$file" ] || continue
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done
    echo "::endgroup::"

    echo "::group::recipe bodies — parse + bash -n (ujust runtime syntax)"
    for module in system_files/shared/usr/share/ublue-os/just/*.just; do
        just --justfile "$module" --list >/dev/null 2>&1 \
            || { echo "Recipe module does not parse: $module"; status=1; continue; }
        for recipe in $(just --justfile "$module" --summary); do
            body="$(just --justfile "$module" --show "$recipe" 2>/dev/null)" || continue
            # just --show prints attributes ([group(...)]), the recipe header,
            # then the body; bodies are bash shebang scripts — take everything
            # from the first `#!` line on (empty for non-script recipes, and
            # `bash -n` passes on empty input).
            if printf '%s\n' "$body" | awk 'f{print} /^#!/{f=1}' | bash -n; then
                echo "Checking recipe: $(basename "$module")::$recipe — OK"
            else
                echo "Recipe body FAILED bash -n: $(basename "$module")::$recipe"
                status=1
            fi
        done
    done
    echo "::endgroup::"

    exit "$status"

# Fix Justfile formatting
[group('Just')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile

# Lint every build_files script with shellcheck (extensionless bash)
[group('Just')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shellcheck >/dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    status=0
    # while-read + explicit status accumulation: `find -exec` would report
    # only the LAST invocation's exit code and silently mask earlier failures.
    # -x follows `# shellcheck source=` directives. ShellCheck resolves those
    # relative to its WORKING DIRECTORY (the repo root, where this recipe runs),
    # which is why the directives read build_files/packages-lib.
    while read -r file; do
        if shellcheck --shell=bash -x "$file"; then
            echo "shellcheck OK: $file"
        else
            echo "shellcheck FAILED: $file"
            status=1
        fi
    done < <(find build_files -type f \
        ! -path "*libdnf5.conf.d*" ! -path "*python-packages*" \
        ! -name "*.json" ! -name "README*")
    exit "$status"

# Static-check the python helpers for undefined names and syntax errors
[group('Just')]
lint-python:
    #!/usr/bin/env bash
    set -euo pipefail
    cd build_files/python-packages
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip ruff
    # F821/F822/F823 = undefined names — the bug class that shipped in `rmi`
    # (a missing `datetime` import). The build-time `-h` smoke test never
    # reaches that code and py_compile only checks syntax, so neither sees it.
    # E9 = syntax errors.
    .venv/bin/ruff check --select E9,F821,F822,F823 .

# Run the python helper test suites (not reached by check/lint)
[group('Just')]
test-python:
    #!/usr/bin/env bash
    set -euo pipefail
    cd build_files/python-packages
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    for pkg in dump-to-markdown rmi; do
        echo "::group::pytest — ${pkg}"
        .venv/bin/pip install --quiet -e "./${pkg}[dev]"
        .venv/bin/pytest "${pkg}"
        echo "::endgroup::"
    done

# Audit the .github tree (host-side; no image required)
[group('Just')]
check-github:
    #!/usr/bin/env bash
    set -euo pipefail
    bash verify/verify-github.sh

# Build the container image with the CI label scheme
[group('Build')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    BUILD_ARGS=()
    LABELS=()
    GIT_SHA=$(git rev-parse --short HEAD)
    # consumed by the Containerfile ARGs (bazzite convention:
    # version = <fedora-major>.<yyyymmdd>, revision = git sha)
    BUILD_ARGS+=("--build-arg" "FEDORA_VERSION=${fedora_version}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VERSION=${fedora_version}.$(date +%Y%m%d)")
    BUILD_ARGS+=("--build-arg" "SOURCE_SHA=${GIT_SHA}")

    if [[ -z "$(git status -s)" ]]; then
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ image_name }}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.version={{ default_tag }}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords={{ image_keywords }}")
    # Must match LICENSE and the Containerfile's org.opencontainers.image.licenses
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url={{ image_logo_url }}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description={{ image_desc }}")
    LABELS+=("--label" "org.opencontainers.image.title={{ image_name }}")
    LABELS+=("--label" "org.opencontainers.image.vendor={{ repo_organization }}")

    podman build "${BUILD_ARGS[@]}" "${LABELS[@]}" \
        --pull=newer --platform linux/amd64 \
        --tag "${target_image}:${tag}" --file Containerfile .

# Run the image-side verification suite against a built image
[group('Build')]
verify-image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    for checker in verify-brew.sh verify-chezmoi.sh verify-ujust.sh; do
        echo "::group::image-side — ${checker}"
        podman run --rm --entrypoint /bin/bash \
            -v "$PWD/verify:/verify:ro" \
            "${target_image}:${tag}" "/verify/${checker}" || status=1
        echo "::endgroup::"
    done
    exit "$status"

# Generate the full alias-tag set (template scheme)
# Image Name (template recipe — CI resolves the image name through it)
[group('Utility')]
[private]
image_name $target_image=image_name:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "${target_image}"

[group('Utility')]
generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    echo "${tag}"

[group('Utility')]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
        BUILD_TAGS+=("${DATE}-${GIT_SHA}")
    fi
    BUILD_TAGS+=("${DATE}")
    BUILD_TAGS+=("${tag}")
    BUILD_TAGS+=("${tag}-${DATE}")
    BUILD_TAGS+=("${fedora_version}")
    BUILD_TAGS+=("${DATE}-${fedora_version}")

    echo "${BUILD_TAGS[@]}"

# Re-tag one built image with the whole alias set
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -euox pipefail

    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done
    podman images

# Report the installed package count of a built image (mirrors the CI step)
[group('Utility')]
package-count $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    INFO=$(podman run --rm --entrypoint /bin/bash "${target_image}:${tag}" -c \
        'echo "count=$(rpm -qa | wc -l)"; echo "kernel=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-p03 2>/dev/null || echo n/a)"')
    COUNT=$(sed -n 's/^count=//p' <<< "${INFO}")
    KVER=$(sed -n 's/^kernel=//p' <<< "${INFO}")
    echo "total installed RPM packages: ${COUNT}"
    echo "p03 kernel: ${KVER}"
```

### `.containerignore`

```
# Content excluded from the build context — nothing here is needed by any
# build stage; keeping it out shrinks upload/transfer and prevents leaks.
.git
.github
.vscode
.idea
.zcode
.bluebuild-scripts_*
AGENTS.md
SKILLS.md
MIGRATION.md
TODO.md
README.md
notes/
verify/
*.log
*.tar
*.tar.gz
*.oci
*.iso
# python build artifacts (exist on disk from local dev, never needed in ctx)
**/__pycache__/
**/*.egg-info/
**/.venv/
**/.pytest_cache/
build_files/python-packages/**/build/
```

### `system_files/shared/usr/share/ublue-os/just/halcyon-rebase.just`

Only the closing echo changed. It now names `/etc/pki/containers`, and the `rpm-ostree` fallback is kept.

```make
# vim: set ft=make :

# Rebase the current system to the published halcyon image
# (README: Install / rebase — unsigned first, signed tag after reboot)
[group("system")]
rebase-to-custom tag="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "Rebasing system to ${IMAGE}..."
    if command -v bootc >/dev/null 2>&1; then
        sudo bootc switch "${IMAGE}"
    elif command -v rpm-ostree >/dev/null 2>&1; then
        sudo rpm-ostree rebase "ostree-unverified-registry:${IMAGE}"
    else
        echo "Neither bootc nor rpm-ostree was detected on this system." >&2
        exit 1
    fi
    echo "Rebase prepared successfully!"
    echo "Reboot into the new deployment:  systemctl reboot"
    echo "After reboot, switch to the signed tag (README: Install / rebase):"
    echo "  sudo bootc switch --enforce-container-sigpolicy ostree-image-signed:docker://ghcr.io/aahsnr-work/halcyon:{{tag}}"
    echo "  (the image ships /etc/pki/containers/halcyon.pub + a sigstore policy entry — verification is enforced by policy.json)"
```

### `build_files/python-packages/rmi/src/rmi/__init__.py`

```python
"""rmi - Safe Removal Tool.

Python 3.13 port of the original ``rmi`` bash script.

Moves files and directories to the XDG trash directory instead of deleting
them. Name collisions are resolved with GNU-mv style numbered backups: the
item already present in the trash is renamed to ``name.~1~``, ``name.~2~``,
... and the newly trashed item keeps the plain name.
"""

import argparse
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import NoReturn
from urllib.parse import quote

SCRIPT_NAME: str = Path(sys.argv[0]).name or "rmi"
VERSION: str = "2.0.1"

_XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME") or str(
    Path.home() / ".local" / "share"
)
TRASH_DIR: Path = Path(_XDG_DATA_HOME) / "Trash" / "files"
TRASH_INFO_DIR: Path = Path(_XDG_DATA_HOME) / "Trash" / "info"

# Colors are only emitted when stdout is a terminal.
if sys.stdout.isatty():
    COLOR_RED = "\033[0;31m"
    COLOR_GREEN = "\033[0;32m"
    COLOR_YELLOW = "\033[0;33m"
    COLOR_RESET = "\033[0m"
else:
    COLOR_RED = COLOR_GREEN = COLOR_YELLOW = COLOR_RESET = ""

DESCRIPTION = f"""\
A safer alternative to 'rm' that moves files and directories to the XDG
Trash directory instead of permanently deleting them. Files can be restored
using your desktop environment's trash manager or manually from:
{TRASH_DIR}
"""

EPILOG = f"""\
EXAMPLES:
    # Interactive mode (default) - prompts for confirmation
    {SCRIPT_NAME} file.txt document.pdf

    # Force mode - no confirmation prompt
    {SCRIPT_NAME} -f unwanted_file.log

    # Verbose mode - shows where files are moved
    {SCRIPT_NAME} -v old_project/

    # Combined flags
    {SCRIPT_NAME} -f -v *.tmp

    # Trash multiple items at once
    {SCRIPT_NAME} file1.txt file2.txt directory/

    # Names starting with a dash need the end-of-options marker
    {SCRIPT_NAME} -- -weird-name.txt

NOTES:
    - Files are moved to: {TRASH_DIR}
    - If a file with the same name already exists in the trash, numbered
      backups are created (e.g. file.txt, file.txt.~1~, file.txt.~2~)
    - The trash directory itself cannot be trashed
    - Non-existent files are skipped with a warning

SEE ALSO:
    rm(1), mv(1), trash-cli, XDG Base Directory Specification
"""

BACKUP_SUFFIX = re.compile(r"\.~(\d+)~$")


class ArgumentParser(argparse.ArgumentParser):
    """ArgumentParser that exits with status 1 on usage errors.

    argparse exits with 2 by default; the shell version this replaces used 1.
    """

    def error(self, message: str) -> NoReturn:
        self.print_usage(sys.stderr)
        print(f"{self.prog}: error: {message}", file=sys.stderr)
        raise SystemExit(1)


def print_message(color: str, message: str) -> None:
    """Print a colored message to stdout."""
    print(f"{color}{message}{COLOR_RESET}")


def print_error(message: str) -> None:
    """Print a colored error message to stderr."""
    print(f"{COLOR_RED}{message}{COLOR_RESET}", file=sys.stderr)


def next_backup_path(destination: Path) -> Path:
    """Return the next free ``name.~N~`` path next to ``destination``."""
    highest = 0
    prefix = destination.name + ".~"
    try:
        entries = list(destination.parent.iterdir())
    except OSError:
        entries = []
    for entry in entries:
        if not entry.name.startswith(prefix):
            continue
        match = BACKUP_SUFFIX.search(entry.name[len(destination.name) :])
        if match:
            highest = max(highest, int(match.group(1)))
    return destination.parent / f"{destination.name}.~{highest + 1}~"


def write_trashinfo(original: Path, destination: Path) -> None:
    """Write the XDG .trashinfo companion so desktop trash managers can restore.

    The move has already succeeded by the time this runs; a failure here only
    costs restore-tooling support, never the user's data, so every error is
    reported and swallowed.
    """
    try:
        TRASH_INFO_DIR.mkdir(parents=True, exist_ok=True)
        info_path = TRASH_INFO_DIR / f"{destination.name}.trashinfo"
        suffix = 0
        while info_path.exists():
            suffix += 1
            info_path = TRASH_INFO_DIR / f"{destination.name}.~{suffix}~.trashinfo"
        escaped = quote(str(original), safe="/")
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        info_path.write_text(
            "[Trash Info]\n" f"Path={escaped}\n" f"DeletionDate={stamp}\n",
            encoding="utf-8",
        )
    except OSError as exc:
        print_error(
            f"Warning: could not write .trashinfo for '{destination.name}': {exc}"
        )


def move_to_trash(item: Path, verbose: bool) -> bool:
    """Move a single item into the trash, backing up any existing entry."""
    destination = TRASH_DIR / item.name

    # Resolve BEFORE the move: afterwards the original path no longer exists
    # and the .trashinfo Path= field would record the wrong location.
    try:
        original = item.resolve()
    except OSError:
        original = item.absolute()

    try:
        if destination.exists() or destination.is_symlink():
            backup = next_backup_path(destination)
            destination.rename(backup)
            if verbose:
                print(f"backed up '{destination}' -> '{backup}'")
        shutil.move(str(item), str(destination))
    except (OSError, shutil.Error) as exc:
        print_error(f"Error: Failed to move '{item}': {exc}")
        return False

    write_trashinfo(original, destination)

    if verbose:
        print(f"moved '{item}' -> '{destination}'")
    return True


def confirm(prompt: str) -> bool:
    """Ask a y/N question; anything but y/Y means no."""
    try:
        reply = input(prompt)
    except EOFError:
        print()
        return False
    return reply.strip().lower() in ("y", "yes")


def build_parser() -> argparse.ArgumentParser:
    parser = ArgumentParser(
        prog=SCRIPT_NAME,
        usage=f"{SCRIPT_NAME} [OPTIONS] <file1> [file2 ...]",
        description=f"{SCRIPT_NAME} - Safe Removal Tool (Version {VERSION})\n\n"
        + DESCRIPTION,
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "paths",
        nargs="*",
        metavar="FILE",
        help="one or more files or directories to move to trash",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="skip confirmation prompt (non-interactive mode)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show detailed output of operations",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"{SCRIPT_NAME} version {VERSION}",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.paths:
        print_error("Error: No files or directories specified")
        print(f"Usage: {SCRIPT_NAME} [OPTIONS] <file1> [file2 ...]")
        print(f"Try '{SCRIPT_NAME} --help' for more information.")
        return 1

    try:
        TRASH_DIR.mkdir(parents=True, exist_ok=True)
        TRASH_INFO_DIR.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        print_error(f"Error: Cannot create trash directory: {exc}")
        return 1

    if args.verbose:
        print(f"Trash directory: {TRASH_DIR}")

    try:
        trash_realpath = TRASH_DIR.resolve(strict=True)
    except OSError as exc:
        print_error(f"Error: Cannot resolve trash directory: {exc}")
        return 1

    valid_targets: list[Path] = []
    for raw in args.paths:
        item = Path(raw)

        # '.', '..' and '/' have no usable base name; mv refuses these too,
        # and attempting the move would copy before failing.
        if item.name in ("", ".", ".."):
            print_message(
                COLOR_YELLOW,
                f"Warning: Refusing to trash '{raw}': please name the item "
                "explicitly, skipping",
            )
            continue

        # Path.exists() follows symlinks; a broken symlink must still be trashed.
        if not item.exists() and not item.is_symlink():
            print_message(COLOR_YELLOW, f"Warning: '{raw}' does not exist, skipping")
            continue

        try:
            item_realpath = item.resolve()
        except OSError as exc:
            print_message(COLOR_YELLOW, f"Warning: cannot resolve '{raw}': {exc}")
            continue

        if item_realpath == trash_realpath:
            print_message(
                COLOR_YELLOW,
                "Warning: Cannot trash the trash directory itself, skipping",
            )
            continue

        if item_realpath in trash_realpath.parents:
            print_message(
                COLOR_YELLOW,
                f"Warning: Cannot trash '{raw}': it contains the trash "
                "directory, skipping",
            )
            continue

        valid_targets.append(item)

    if not valid_targets:
        print_message(COLOR_YELLOW, "No valid items to trash")
        return 0

    print("Moving to trash:")
    for item in valid_targets:
        print(f"  - {item.name}")

    if not args.force and not confirm("Continue? [y/N]: "):
        print_message(COLOR_YELLOW, "Operation cancelled")
        return 0

    move_count = sum(move_to_trash(item, args.verbose) for item in valid_targets)

    if move_count > 0:
        print_message(
            COLOR_GREEN, f"✓ Successfully moved {move_count} item(s) to trash"
        )
        return 0

    print_error("✗ Failed to move any items")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        sys.exit(130)
```

### `build_files/python-packages/rmi/pyproject.toml`

```toml
[build-system]
requires = ["setuptools>=77"]
build-backend = "setuptools.build_meta"

[project]
name = "rmi"
version = "2.0.1"
description = "Safe removal to the XDG trash with collision handling."
requires-python = ">=3.10"
license = "Apache-2.0"

[project.optional-dependencies]
dev = ["pytest"]

[project.scripts]
rmi = "rmi:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### `build_files/python-packages/rmi/tests/test_rmi.py`

```python
"""Tests for the rmi package.

`rmi -h` — the build-time smoke test — never reaches the code that actually
moves a file. A missing `datetime` import shipped in the image for exactly that
reason: the tool trashed the file, then died with a NameError while writing the
.trashinfo companion.
"""

from __future__ import annotations

from pathlib import Path

import pytest

import rmi


@pytest.fixture(autouse=True)
def isolated_trash(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Point the module's trash constants at a throwaway directory."""
    files = tmp_path / "Trash" / "files"
    info = tmp_path / "Trash" / "info"
    monkeypatch.setattr(rmi, "TRASH_DIR", files)
    monkeypatch.setattr(rmi, "TRASH_INFO_DIR", info)
    files.mkdir(parents=True)
    info.mkdir(parents=True)
    return files, info


def test_move_to_trash_writes_trashinfo(tmp_path: Path, isolated_trash):
    files, info = isolated_trash

    target = tmp_path / "doc.txt"
    target.write_text("hello\n", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "doc.txt").read_text(encoding="utf-8") == "hello\n"
    assert not target.exists()

    written = (info / "doc.txt.trashinfo").read_text(encoding="utf-8")
    assert written.startswith("[Trash Info]\n")
    assert "Path=" in written
    assert "DeletionDate=" in written


def test_trashinfo_records_where_the_file_came_from(tmp_path: Path, isolated_trash):
    _files, info = isolated_trash

    nested = tmp_path / "sub"
    nested.mkdir()
    target = nested / "note.md"
    target.write_text("x", encoding="utf-8")

    rmi.move_to_trash(target, verbose=False)

    written = (info / "note.md.trashinfo").read_text(encoding="utf-8")
    path_line = next(l for l in written.splitlines() if l.startswith("Path="))
    # The original location, not the trash location the file moved to.
    assert path_line.endswith("/sub/note.md")


def test_collision_creates_numbered_backup(tmp_path: Path, isolated_trash):
    files, _info = isolated_trash
    (files / "dup.txt").write_text("old", encoding="utf-8")

    target = tmp_path / "dup.txt"
    target.write_text("new", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "dup.txt").read_text(encoding="utf-8") == "new"
    assert (files / "dup.txt.~1~").read_text(encoding="utf-8") == "old"


def test_main_skips_dot_and_missing_paths(tmp_path: Path):
    assert rmi.main(["-f", ".", str(tmp_path / "nope.txt")]) == 0


def test_main_with_no_arguments_returns_1():
    assert rmi.main([]) == 1
```

### `README.md`

````markdown
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

**Signatures.** Images are signed with Cosign in the _legacy_ `.sig`
attachment format, because that is the only format containers/image (podman,
skopeo, bootc) can discover. Cosign 3 defaults to a newer referrer format that
`cosign verify` accepts but `bootc` cannot see; the workflow forces the legacy
format and verifies it after signing. The image ships the public key at
`/etc/pki/containers/halcyon.pub` and a `sigstoreSigned` policy for
`ghcr.io/aahsnr-work/halcyon`.

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
  ripgrep, starship, yazi, zellij, …) **plus a small baked Homebrew payload**
  — only `bun`, `pixi` and `opencode`, the formulas Fedora and Terra do not
  ship — brewed at build time into `/usr/share/halcyon/brew-bundle.tar.zst`
  and seeded pre-login, offline, by `halcyon-brew-bundle.service`. chezmoi
  (Fedora RPM) is wired to
  [aahsnr-configs/dotfiles](https://github.com/aahsnr-configs/dotfiles)
  (first-login init + update timer, blue-build module semantics), nix via the
  [fu5ha/winter](https://github.com/fu5ha/winter) bind-mount pattern, and
  ujust/uupd (`ublue-os-just` + `uupd`) with curated Bazzite recipes.
- **Flatpak:** package + **flathub user repo only** (no system flathub, no
  Fedora flatpaks); four transition apps install per-user at first login —
  everything else is native RPM.

---

## Repo structure

`build_files/` has one folder per build phase; the **Containerfile is the
single source of ordering truth** — the folders carry no numbering.

```
├── Containerfile              # 18 RUN stages (banners 00–17) + hermetic bootc lint
├── Justfile                   # check / lint / lint-python / test-python / build / verify-image
├── halcyon.env                # dotenv consumed by the Justfile
├── packages.json              # SINGLE SOURCE OF TRUTH for every dnf/flatpak package
├── cosign.pub                 # public signing key (shipped to /etc/pki/containers)
├── build_files/               # the `ctx` stage — never ends up in the image
│   ├── packages-lib           #   jq accessors the stages source (fail-fast)
│   ├── cleanup                #   end-of-RUN temp/log//boot wipe
│   ├── libdnf5.conf.d/        #   dnf5 retry drop-in (installed in Stage 00)
│   ├── base/                  #   setup-repos, remove-packages
│   ├── kernel/                #   install-kernel + kernel-verify (p03 + nvidia-open)
│   ├── packages/              #   install-packages / -terra / -devtools + packages-verify
│   ├── brew/                  #   install-brew-bundle + brew-verify
│   ├── runtime/               #   install-nix, setup-flatpaks, setup-ujust + verifies
│   ├── apps/                  #   obsidian/zotero/pyprland/texlive/python + verify
│   ├── desktop/               #   configure-system, image-info, plymouth + verifies
│   ├── finish/                #   build-initramfs, finalize, final-verify
│   └── python-packages/       #   11 stdlib-only src-layout Python tools
├── system_files/shared/       # root overlay COPYed into the image
└── verify/                    # image-side suites CI runs against the built image
```

Every third-party repo is enabled only inside the stage that consumes it and
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

Groups are keyed by **the repo a package resolves from**, not by what it does.

| Group                                  | Resolved from                                                 | Consumed by      |
| -------------------------------------- | ------------------------------------------------------------- | ---------------- |
| `fedora-core`                          | Fedora                                                        | install-packages |
| `fedora-hardware`                      | Fedora                                                        | install-packages |
| `fedora-editors`                       | Fedora                                                        | install-packages |
| `hyprland-copr`                        | COPR `lionheartp/Hyprland`                                    | install-packages |
| `gaming`                               | Fedora + RPM Fusion                                           | install-packages |
| `bazaar-copr`                          | COPR `ublue-os/packages`                                      | install-packages |
| `zen-copr`                             | COPR `sneexy/zen-browser`                                     | install-packages |
| `vendor-apps` / `vendor-apps-optional` | per-use vendor repos (VS Code, Brave)                         | install-packages |
| `fedora-devtools`                      | Fedora                                                        | install-devtools |
| `nix`                                  | Fedora                                                        | install-nix      |
| `flatpak`                              | Fedora                                                        | setup-flatpaks   |
| `ujust-copr` / `ujust-fedora`          | COPR `ublue-os/packages` / Fedora                             | setup-ujust      |
| `terra`                                | **Terra only** (`--disablerepo='*'`)                          | install-terra    |
| `all.exclude.all`                      | removals — resolved through `rpm -qa`, absent names tolerated | remove-packages  |
| `flatpak.install` / `flatpak.remove`   | Flathub (user repo, at first login)                           | setup-flatpaks   |

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
  (`terra-release*`) stay in their scripts — they are not catalog entries;
- a few entries exist purely as **build-tool preconditions** (`zstd`,
  `util-linux-core`, `gnupg2`, `jq`, `gcc-c++`) — `packages-verify` gates them
  so they cannot be pruned as "unused".

---

## Build & CI

- `lint.yml` (PR, push, manual): `just check` + `just lint`, the `.github`
  audit (`verify/verify-github.sh`), actionlint, ruff (undefined names) and the
  Python helper test suites.
- `semantic-pr.yml`: validates PR titles against Conventional Commits.
- `build.yml` (daily cron 08:00 UTC, push, PR, manual): polls the consumed
  COPRs, frees runner disk, runs both syntax gates, builds with
  `podman build --pull`, runs the **image-side verify suite**
  (`verify/verify-{brew,chezmoi,ujust}.sh`), writes a package-count report, and
  — only on the `container` branch and never on PRs — pushes to GHCR, signs
  with Cosign (legacy format) and verifies the signature.
- **Scheduled runs only fire from the repository's default branch.** For the
  daily rebuild to run _this_ workflow, `container` must be the default branch
  (Settings → Branches).
- Workflows are pinned to `ubuntu-24.04`. `ubuntu-latest` migrates to 26.04
  between 2026-10-19 and 2026-11-19; test `ubuntu-26.04` deliberately first.
- Local test build: `just build localhost/halcyon latest`, then
  `just verify-image localhost/halcyon latest`.
- OCI labels (`org.opencontainers.image.*`) come from
  `--build-arg IMAGE_VERSION=<fedora>.<date>` and `SOURCE_SHA=<git sha>`.
  `bootc container lint` runs network-isolated as the final gate.

---

## Credits & licenses

Apache-2.0 — see `LICENSE`.

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
````

### `AGENTS.md`

````markdown
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
````

### `SKILLS.md`: replacement sections

The file is about 700 lines and mostly still accurate. Replace these blocks in place.

**`add-build-stage` → steps 1, 2 and 4**

````markdown
1. **Name the script** `build_files/<folder>/<verb>-<subject>`, extensionless,
   matching the existing vocabulary (`install-*`, `setup-*`, `configure-*`,
   `build-*`, `remove-*`). Pick the folder by build phase — `base/ kernel/
packages/ brew/ runtime/ apps/ desktop/ finish/`. Commit it executable:

   ```bash
   git add build_files/runtime/install-foo
   git update-index --chmod=+x build_files/runtime/install-foo
   ```

2. **Skeleton** (copy `runtime/install-nix`). The shellcheck directive is
   resolved relative to ShellCheck's WORKING DIRECTORY (the repo root, where
   `just lint` runs), so it names `build_files/packages-lib`:

   ```bash
   #!/usr/bin/env bash
   # halcyon build step — install-foo (one line on WHY this stage exists)
   set -euo pipefail
   # shellcheck source=build_files/packages-lib
   source /ctx/packages-lib
   packages_validate
   echo "::group::install-foo — <phase>"
   readarray -t FOO_PKGS < <(packages_for foo)
   dnf5 -y --setopt=install_weak_deps=False install \
     "${FOO_PKGS[@]}"
   echo "::endgroup::"
   ```

3. **Insert the `RUN` block** in `Containerfile` with a stage banner:

   ```dockerfile
   # ---- Stage N: foo ----------------------------------------------------------
   RUN --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
       --mount=type=bind,from=ctx,source=/,target=/ctx,ro \
       echo "████ STAGE NN/17 · install-foo · <summary> ████" \
       && /ctx/runtime/install-foo && /ctx/runtime/install-foo-verify && /ctx/cleanup
   ```

   Drop the `type=cache` mount if the stage never touches `dnf5`.
````

**`add-verify-gate` → "Gate forms that are wrong in this environment"**

```markdown
- **`test -e /usr/lib/systemd/system/<target>.wants/<unit>`** — `systemctl
enable` in a build container writes to `/etc/systemd/system/…`. Use
  `systemctl is-enabled <unit>`.
- **A gate whose glob a later stage deletes.** `final-verify` once had
  `! grep -l "^enabled=1" /etc/yum.repos.d/terra*.repo | grep -q .` — but
  `finalize` deletes those files, so it passed unconditionally.
- **`test "${VAR}" = "$(...)"` where VAR may be empty.** `test "" = ""` PASSES.
  The NVIDIA version gate needs `test -n "${NV_MOD_VER}"` in front of it.
- **Gating "directory X is empty" without checking who writes there.** Brave's
  RPM installs into `/opt`.
- **A `grep` over shipped recipe files.** Comments and fallback branches match.
  Gate behaviour, not prose.
- **Gating a package installed with `|| true`.** Either it is required (drop the
  `|| true`) or optional (drop the gate).
- **`grep -rq pattern /some/dir/`** returns non-zero for "directory missing" and
  "pattern absent" alike. Add a `test -d` gate alongside it.
```

**`add-rpm-package` → step 2 table**

```markdown
| Source                           | Where                                               | How                                           |
| -------------------------------- | --------------------------------------------------- | --------------------------------------------- |
| Fedora (core/hardware)           | `packages.json` → `fedora-core` / `fedora-hardware` | alphabetical in the group                     |
| Fedora (editors/runtimes)        | `packages.json` → `fedora-editors`                  | alphabetical                                  |
| Fedora (CLI dev tooling)         | `packages.json` → `fedora-devtools`                 | alphabetical                                  |
| Fedora (ujust recipe dependency) | `packages.json` → `ujust-fedora`                    | and add a `command -v` gate to `ujust-verify` |
| Terra                            | `packages.json` → `terra`                           | resolves exclusively from Terra               |
| A COPR                           | `packages.json` → that COPR's group                 | the stage owns `copr enable`/`disable`        |
| Vendor repo (MS, Brave)          | `packages.json` → `vendor-apps`                     | ONLY if it truly resolves from that repo      |
```

**`add-python-tool` → step 6**

```markdown
6. **The build-time smoke test is `-h` or `--version`, and it is not enough.**
   It never reaches the code that does the work, and `py_compile` only checks
   syntax — a missing import is invisible to both (it shipped in `rmi`).
   `just lint-python` runs ruff for undefined names (F821) and syntax errors.
   Add a `tests/` directory for anything with side effects, and list the package
   in the `for pkg in …` loop of the `test-python` recipe.
```

**`remove-package-or-file` → replace "Caveat on the inherited removal machinery"**

```markdown
### The inherited removal machinery is gone

`guarded-removals`, `file-footprint`, `gnome-extensions` and `fonts-cleanup`
were written when halcyon was layered on Bazzite. On a bare `fedora-bootc` base
every one of their targets is absent, so they were ~400 lines of no-op whose
comments described an ordering that no longer held. They have been deleted.

The parts with real value now live in `base/remove-packages`: the
**reverse-dependency gate** (used for `sddm`/`cage`) and the
**must-not-survive hard-fail loop**. Extend those rather than resurrecting the
old scripts.
```

**`diagnose-failed-build` → add a row to the classification table**

```markdown
| `A signature was required, but no signature exists` on `bootc switch` / `bootc upgrade` | signature stored in the Cosign 3 referrer format, which containers/image cannot see | `build.yml` must sign with `--new-bundle-format=false --use-signing-config=false --registry-referrers-mode=legacy`; rebuild to re-sign |
| `Signature for identity … is not accepted` | `policy.json` lacks `signedIdentity: matchRepository` (cosign signs by digest, bootc pulls by tag) | `desktop/image-info` |
```

**`bump-fedora-release` → step 5**

```markdown
5. `Justfile`: nothing to change — `fedora_version` comes from `halcyon.env` and
   flows into both `generate-build-tags` and the `IMAGE_VERSION` build arg.
   Change `FEDORA_VERSION` in `halcyon.env`.
```

**New skill: `ci-signing-and-runners`**

```markdown
## skill: ci-signing-and-runners

**Use when:** touching `.github/workflows/`, bumping Cosign, or changing runners.

1. **Signing format.** Cosign 3 writes signatures as OCI 1.1 referrers by
   default; containers/image (podman, skopeo, bootc) only reads the legacy
   `sha256-<digest>.sig` tag. `cosign verify` accepts BOTH, so it cannot detect
   the regression. Keep `--new-bundle-format=false --use-signing-config=false
--registry-referrers-mode=legacy` on `cosign sign`, keep the
   `--new-bundle-format=false` verify step, and keep `cosign-release` pinned
   (Cosign 4 is expected to remove these flags).
2. **Runners.** Pin `ubuntu-24.04`. `ubuntu-latest` migrates to 26.04 between
   2026-10-19 and 2026-11-19. To move: switch one workflow to `ubuntu-26.04`, and
   bump `ublue-os/remove-unwanted-software` past v9 (there is no v10 tag; use the
   commit `ublue-os/image-template` pins).
3. **Publishing.** Only `PUBLISH_BRANCH` (`container`) pushes. Scheduled and
   dispatch runs execute from the repository default branch — if that is not
   `container`, the daily rebuild never runs this workflow.
4. **Actions.** Pin to a `vN` tag or a full SHA, never a branch. Renovate
   rewrites tags to SHAs; `verify-github.sh` accepts both.
5. Run `just check-github` after any workflow edit.
```

### `build_files/python-packages/README.md`

````markdown
# halcyon Python packages

Staged into the image at build time by `build_files/apps/install-built-apps`
(→ `/usr/src/python-packages`) and installed by
`build_files/apps/install-python-packages` into one shared venv at
`/usr/lib/halcyon-python`. Every console script is symlinked separately into
`/usr/bin`, so each tool is its own binary on PATH. All packages are
stdlib-only (zero pip dependencies) and build-verified by
`build_files/apps/built-apps-verify`.

| Package            | Binary             | Purpose                                                                         |
| ------------------ | ------------------ | ------------------------------------------------------------------------------- |
| `dump-to-markdown` | `dump-to-markdown` | Dump a project tree into one Markdown document (headings + fenced code blocks). |
| `fconf`            | `fconf`            | Fuzzy configuration finder/editor (fd \| fzf \| bat \| `$EDITOR`).              |
| `fe`               | `fe`               | Fuzzy edit — pick a file with fd/fzf, open in `$EDITOR`.                        |
| `ff`               | `ff`               | Fast file finder wrapping `fd` with a `find` fallback.                          |
| `fkill`            | `fkill`            | Fuzzy process killer (`ps` \| fzf, SIGTERM/SIGKILL).                            |
| `fp`               | `fp`               | Fuzzy file/directory previewer (fd \| fzf, composable stdout).                  |
| `fssh`             | `fssh`             | Fuzzy SSH launcher driven by `~/.ssh/config`.                                   |
| `rmi`              | `rmi`              | Safe removal to the XDG trash with collision handling.                          |
| `rmtmp`            | `rmtmp`            | Root-only secure cleanup of old files in `/tmp` and `/var/tmp`.                 |
| `screenshot`       | `screenshot`       | Wayland screenshot helper (`grim` \| swappy; slurp region, niri window).        |
| `se`               | `se`               | Search & edit — ripgrep \| fzf \| `$EDITOR` at the matched line.                |

Runtime tool dependencies (`fd`, `fzf`, `bat`, `rg`, `grim`, `swappy`, `slurp`)
are provided by the image's RPM layer; each tool checks for its own
dependencies at startup and exits with a clear message if missing.

## Registering a new package

Three places, all required:

1. the `EXPECTED` array in `build_files/apps/install-python-packages`
2. the table above
3. the `for b in …` loop in `build_files/apps/built-apps-verify`

## Development and tests

Each directory is a standalone src-layout package.

```sh
just lint-python    # ruff: undefined names + syntax errors
just test-python    # pytest for the packages that have suites
```
````

`dump-to-markdown` and `rmi` have suites.

**The build-time smoke test (`-h` / `--version`) is not sufficient.** It never
reaches the code that does real work, and a syntax check cannot see an
undefined name — a missing `datetime` import shipped in `rmi` and only surfaced
when someone trashed a file. `lint-python` catches that class of bug; add a
`tests/` directory for anything with meaningful side effects.

````

### `build_files/python-packages/dump-to-markdown/README.md`

```markdown
# dump-to-markdown

Walk every file and folder under a project root and produce a single
Markdown document containing, for every file found, a heading with its
project-relative path (e.g. `myproject/src/main.py`) followed by a fenced
code block holding that file's contents. Fence language hints are chosen
from extension, exact filename, or shebang, so blocks get sensible syntax
highlighting wherever the Markdown is rendered.

Only `.git` is skipped by default; everything else — including dotfiles —
is included. Stdlib-only: no third-party runtime dependencies.

## Install

halcyon bakes this into the built image (`/usr/bin/dump-to-markdown`) via
`build_files/apps/install-python-packages`, which installs every helper into the
shared venv at `/usr/lib/halcyon-python`. On a dev machine, install it from this
repo:

```sh
uv tool install ./build_files/python-packages/dump-to-markdown
# or
pipx install ./build_files/python-packages/dump-to-markdown
# or
python3 -m pip install --user ./build_files/python-packages/dump-to-markdown
````

## Usage

```sh
dump-to-markdown
dump-to-markdown --root /path/to/project --output dump.md
dump-to-markdown --exclude-dir node_modules --exclude-dir .venv
dump-to-markdown --max-size 500000
dump-to-markdown --follow-symlinks
dump-to-markdown -v
python3 -m dump_to_markdown   # module form
```

## Options

| Option                  | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `--root PATH`           | Root directory to scan (default: current directory)                 |
| `--output, -o PATH`     | Markdown file to write (default: `./project_dump.md`)               |
| `--exclude-dir DIRNAME` | Extra excluded dir name (repeatable; `.git` always excluded)        |
| `--max-size BYTES`      | Skip embedding files larger than this many bytes                    |
| `--follow-symlinks`     | Descend into symlinked dirs (a symlink cycle hangs, like `find -L`) |
| `-v, --verbose`         | Debug-level logging                                                 |
| `--version`             | Print version and exit                                              |

Exit codes: `0` success · `1` bad root or write failure · `130` interrupted.

## Development

```sh
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
.venv/bin/pytest
```

Or from the repo root: `just test-python`.

Apache-2.0 — see the repo root `LICENSE`.

```

## 5. Files from my last answer that you should NOT apply

If you already applied anything from the previous response, revert these:

- All `# shellcheck source=../packages-lib` edits, and the `--source-path=build_files` flag in the `Justfile`.
- The greetd move (`build_files/desktop/greetd/`), and the matching `configure-system` and `system-verify` edits.
- The `finalize` edit.
- `gum` and `grub2-tools` in `packages.json`.
- The `nodejs`/`npm` renames.
- The `xorg-x11-server-Xorg` removal and its gates.
- The `/opt`, `/var/run`, `/boot`, "empty repo dir" and "no rpm-ostree" gates.
- The `CODEOWNERS` change.
- The Dependabot `docker` entry.
- The `brew-update.service` and `brew-upgrade.service` edits.
- The `install-built-apps`, `install-devtools`, `install-nix` and `install-terra` edits.
- Deleting `artifacthub-repo.yml`.

## 6. Decisions and checks only you can make

- **Default branch.** Confirm `container` is the default branch (Settings → Branches). Otherwise the cron never runs this workflow, and `clean.yml` is affected the same way.
- **Tag race.** If `main` still publishes `ghcr.io/aahsnr-work/halcyon:latest`, the two branches overwrite each other. Rename one image or retire the other.
- **Re-sign existing images.** Anything already pushed from this branch since `cosign-installer@v4` landed is probably signed in the format bootc can't read. The next publishing build fixes that for new tags.
- **Cosign pin.** I used `v3.1.3` from a dated third-party version manifest. Check it on the Cosign releases page.
- **Unverified package names.** I couldn't confirm `wget` (Fedora may serve it as a provide of `wget2-wget`) or `grubby` on Fedora 44. If `dnf5` rejects either, that's the build failure to expect.
- **Not enabled at build time.** `input-remapper` and `ydotool` are installed but never enabled. Decide whether you want them enabled and check each package's unit names first.
- **Bots.** Choose Renovate or Dependabot for actions, not both.
- **Formula duplicates.** I couldn't confirm that all 19 removed brew formulas have RPMs in your image. `brew-verify` warns on any non-allowlisted formula, so it will tell you.

## Suggested order of work

1. **Signing (`build.yml` legacy flags + verify step, `image-info` `signedIdentity` and `/etc/pki` path)** — signed rebases don't work without it. Rebuild afterwards so published images get re-signed.
2. **Pin `runs-on: ubuntu-24.04` in all workflows** — do it before the 26.04 migration begins on October 19.
3. **Confirm the default branch, and the publish gate** — otherwise the daily rebuild never publishes.
4. **`rmi` import fix, `lint-python`, `test-python`, `lint.yml` Python job** — the fix is one line, and the gate stops the bug class from coming back.
5. **`setup-repos` (jq), `packages.json` (build-tool preconditions, `fedora-editors`), `install-texlive` (gnupg2)** — expect TeX Live signature verification to run for the first time.
6. **Wire in `verify/` (`just verify-image`, `verify-github.sh`, actionlint)** — you wrote these and nothing ran them.
7. **Delete dead weight** — the four inherited removal scripts (folded into `remove-packages`), and the 19 shadowed brew formulas.
8. **`semantic-pr.yml`, dependabot/Renovate decision, PR template, `.containerignore`, licence labels** — hygiene.
9. **Docs (`README.md`, `AGENTS.md`, `SKILLS.md` sections, python READMEs)** — do this last so the next audit starts from an accurate map.
```
