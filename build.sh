#!/bin/bash

sudo podman build \
  --network=host \
  --tag localhost/spaceos:latest \
  --cap-add=all \
  --security-opt=label=type:container_runtime_t \
  --device /dev/fuse \
  .
