# halcyon — repo task runner (adapted from ublue-os/image-template's Justfile;
# ISO/bootc-image-builder recipes deliberately omitted — see MIGRATION.md).
set dotenv-filename := "halcyon.env"

export image_name := env_var("IMAGE_NAME")
export repo_organization := env_var("REPO_ORGANIZATION")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")
export image_logo_url := env_var("IMAGE_LOGO_URL")
export default_tag := env_var("DEFAULT_TAG")

default:
    @just --list

# Check Justfile + all build_files scripts
[group('Just')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile
    status=0
    while read -r file; do
        echo "Checking syntax: $file"
        bash -n "$file" || status=1
    done < <(find build_files -maxdepth 1 -type f ! -name libdnf5.conf.d)
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
    find build_files -maxdepth 1 -type f ! -name libdnf5.conf.d \
        -exec shellcheck --shell=bash {} ';'

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
    BUILD_ARGS+=("--build-arg" "IMAGE_VERSION=$(rpm -E %fedora).$(date +%Y%m%d)")
    BUILD_ARGS+=("--build-arg" "SOURCE_SHA=${GIT_SHA}")

    if [[ -z "$(git status -s)" ]]; then
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ image_name }}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.version={{ default_tag }}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords={{ image_keywords }}")
    LABELS+=("--label" "io.artifacthub.package.license=MIT")
    LABELS+=("--label" "io.artifacthub.package.logo-url={{ image_logo_url }}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description={{ image_desc }}")
    LABELS+=("--label" "org.opencontainers.image.title={{ image_name }}")
    LABELS+=("--label" "org.opencontainers.image.vendor={{ repo_organization }}")

    podman build "${BUILD_ARGS[@]}" "${LABELS[@]}" \
        --pull=newer --platform linux/amd64 \
        --tag "${target_image}:${tag}" --file Containerfile .

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
    BUILD_TAGS+=("44")
    BUILD_TAGS+=("${DATE}-44")

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
