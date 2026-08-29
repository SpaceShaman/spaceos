#!/bin/bash

set -e

sudo podman build \
  --network=host \
  -t localhost/spaceos:latest \
  .

sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=missing \
    --security-opt label=type:unconfined_t \
    -v ./config.toml:/config.toml:ro \
    -v ./output:/output \
    -v spaceos-osbuild-store:/store \
    -v spaceos-rpmmd-cache:/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --rootfs btrfs \
    localhost/spaceos:latest
