#!/bin/bash

set -e

sudo podman build \
  --network=host \
  -t localhost/spaceos:latest \
  .

sudo podman build \
  --network=host \
  -f Containerfile.installer \
  -t localhost/spaceos-installer:latest \
  .

printf '%s\n' '{"customizations":{"installer":{"kickstart":{"contents":""}},"kernel":{"append":"inst.graphical"}}}' | sudo podman run \
  --rm \
  -i \
  --privileged \
  --security-opt label=type:unconfined_t \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  ghcr.io/osbuild/image-builder-cli:latest \
  build \
  --output-dir /output \
  --output-name spaceos \
  --blueprint - \
  --bootc-ref localhost/spaceos-installer:latest \
  --bootc-installer-payload-ref localhost/spaceos:latest \
  --bootc-default-fs btrfs \
  bootc-installer
