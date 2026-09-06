#!/bin/bash

set -e

ISO="./output/spaceos.iso"
DISK="./output/iso-test/disk.qcow2"
VARS="./output/iso-test/OVMF_VARS_4M.fd"

mkdir -p ./output/iso-test

if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" 40G
fi

if [ ! -f "$VARS" ]; then
    cp /usr/share/OVMF/OVMF_VARS_4M.fd "$VARS"
fi

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 8192 \
    -device virtio-vga,xres=2560,yres=1440 \
    -display gtk,zoom-to-fit=on \
    -boot once=d \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive if=virtio,format=qcow2,file="$DISK" \
    -cdrom "$ISO"
