#!/usr/bin/env bash

set -euo pipefail

IMAGE="localhost/spaceos:latest"

ROOT_DEV="/dev/ton618-vg/spaceos"
BOOT_DEV="/dev/nvme0n1p4"
ROOT_UUID="4bdaed21-f975-4a5c-b7f5-d416c1c6c38f"

TARGET="/mnt/spaceos"

echo "WARNING: This will erase all data on $ROOT_DEV."
read -r -p "Type 'spaceos' to continue: " confirmation

if [[ "$confirmation" != "spaceos" ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo "==> Erasing existing SpaceOS filesystem"
sudo umount "$TARGET/boot" 2>/dev/null || true
sudo umount "$TARGET" 2>/dev/null || true
sudo mkfs.ext4 -F -U "$ROOT_UUID" "$ROOT_DEV"

echo "==> Mount filesystems"
sudo mkdir -p "$TARGET"
sudo mountpoint -q "$TARGET" || sudo mount "$ROOT_DEV" "$TARGET"

sudo mkdir -p "$TARGET/boot"
sudo mountpoint -q "$TARGET/boot" || sudo mount "$BOOT_DEV" "$TARGET/boot"

echo "==> Removing stale SpaceOS boot entries"
sudo find "$TARGET/boot/ostree" \
    -mindepth 1 -maxdepth 1 -type d -name 'default-*' \
    -exec rm -rf -- {} + 2>/dev/null || true

for entries_dir in "$TARGET/boot/loader.0/entries" "$TARGET/boot/loader.1/entries"; do
    if [[ -d "$entries_dir" ]]; then
        sudo find "$entries_dir" \
            -maxdepth 1 -type f -name 'ostree-*.conf' -delete
    fi
done

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
        --root-mount-spec="UUID=$ROOT_UUID" \
        --boot-mount-spec=UUID=45732a95-d474-46d0-959c-510766943380 \
        --karg="rd.luks.uuid=luks-aff7985f-0301-454e-8479-9feead5c2f58" \
        --karg="rd.lvm.lv=ton618-vg/spaceos" \
        /target

echo "==> Installation finished"
