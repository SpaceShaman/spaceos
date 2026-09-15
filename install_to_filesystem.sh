#!/usr/bin/env bash

sudo podman run --rm --privileged \
  --pid=host \
  --ipc=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  -v /mnt/spaceos:/target \
  localhost/spaceos:latest \
  bootc install to-filesystem \
    --bootloader=grub \
    --root-mount-spec=UUID=b0bd8ed1-8357-4f11-a35c-48b64334f97a \
    --boot-mount-spec=UUID=79328864-8db2-42e3-82b8-9760a1da02d1 \
    --karg='rd.luks.uuid=luks-aff7985f-0301-454e-8479-9feead5c2f58' \
    --karg='rd.lvm.lv=ton618-vg/spaceos' \
    /target
