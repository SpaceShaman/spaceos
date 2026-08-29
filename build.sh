#!/bin/bash

podman build \
  --tag spaceos:latest \
  --cap-add=all \
  --security-opt=label=type:container_runtime_t \
  --device /dev/fuse \
  .
