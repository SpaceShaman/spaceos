#!/usr/bin/env bash

set -euo pipefail

IMAGE="localhost/spaceos:latest"

ROOT_DEV="/dev/ton618-vg/spaceos"
BOOT_DEV="/dev/nvme0n1p4"

TARGET="/mnt/spaceos"

echo "==> Mount filesystems"
sudo mkdir -p "$TARGET"
sudo mountpoint -q "$TARGET" || sudo mount "$ROOT_DEV" "$TARGET"

sudo mkdir -p "$TARGET/boot"
sudo mountpoint -q "$TARGET/boot" || sudo mount "$BOOT_DEV" "$TARGET/boot"

echo "==> Installing SpaceOS"

sudo podman run --rm --privileged \
    --pid=host \
    --ipc=host \
    --security-opt label=type:unconfined_t \
    -v /dev:/dev \
    -v /var/lib/containers:/var/lib/containers \
    -v /mnt/spaceos:/target \
    localhost/spaceos:latest \
    bootc install to-filesystem \
        --bootloader=none \
        --root-mount-spec=UUID=4bdaed21-f975-4a5c-b7f5-d416c1c6c38f \
        --boot-mount-spec=UUID=45732a95-d474-46d0-959c-510766943380 \
        --karg="rd.luks.uuid=luks-aff7985f-0301-454e-8479-9feead5c2f58" \
        --karg="rd.lvm.lv=ton618-vg/spaceos" \
        /target

echo "==> Installation finished"
