#!/usr/bin/bash
set -euo pipefail

if [[ -z "${VERSION:-}" ]]; then
    tag=$(scripts/latest-release-tag.sh)
    version=${tag#v}
else
    version=$VERSION
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'VERSION must use the MAJOR.MINOR.PATCH format.\n' >&2
    exit 2
fi

installer_version=${version%.*}
base_image=${BASE_IMAGE:-quay.io/fedora/fedora-bootc:44}
payload_image=${PAYLOAD_IMAGE:-ghcr.io/spaceshaman/spaceos:auto}
builder_image=${BUILDER_IMAGE:-ghcr.io/osbuild/image-builder-cli:latest}
output_dir=${OUTPUT_DIR:-"$PWD/output/installer-v${version}"}

mkdir -p "$output_dir"
output_dir=$(realpath "$output_dir")

sudo podman pull "$payload_image"
sudo podman build \
    --network=host \
    --build-arg "BASE_IMAGE=$base_image" \
    --build-arg "SPACEOS_VERSION=$version" \
    --build-arg "SPACEOS_DISTRO_VERSION=$installer_version" \
    --build-arg SPACEOS_BUILD_ID=local \
    --file Containerfile.installer \
    --tag "localhost/spaceos-installer:v$version" \
    .

printf '%s\n' '{"customizations":{"installer":{"kickstart":{"contents":""}},"kernel":{"append":"inst.graphical"}}}' \
    | sudo podman run \
        --rm \
        --interactive \
        --privileged \
        --security-opt label=type:unconfined_t \
        --volume "$output_dir:/output" \
        --volume /var/lib/containers/storage:/var/lib/containers/storage \
        "$builder_image" \
        build \
        --output-dir /output \
        --output-name spaceos \
        --blueprint - \
        --bootc-ref "localhost/spaceos-installer:v$version" \
        --bootc-installer-payload-ref "$payload_image" \
        --bootc-default-fs btrfs \
        bootc-installer

sudo chown --recursive "$(id -u):$(id -g)" "$output_dir"
source_iso=$(find "$output_dir" -type f -name '*.iso' -print -quit)
if [[ -z "$source_iso" ]]; then
    printf 'Image Builder did not produce an ISO.\n' >&2
    exit 1
fi

iso="$output_dir/SpaceOS-v${version}-x86_64.iso"
if [[ "$source_iso" != "$iso" ]]; then
    mv "$source_iso" "$iso"
fi
(cd "$output_dir" && sha256sum "${iso##*/}" >"${iso##*/}.sha256")

printf 'Installer ISO: %s\n' "$iso"
printf 'Checksum: %s.sha256\n' "$iso"
