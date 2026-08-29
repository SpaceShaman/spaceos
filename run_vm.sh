#!/bin/bash

VARS="./OVMF_VARS_4M.fd"

if [ ! -f "$VARS" ]; then
    cp /usr/share/OVMF/$VARS "$VARS"
fi

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 2 \
    -m 4096 \
    -device virtio-vga,xres=1920,yres=1080 \
    -display gtk,zoom-to-fit=on \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive if=virtio,format=qcow2,file=output/qcow2/disk.qcow2
