#!/bin/bash
IMAGE_NAME="fedora-builder:latest"
docker run --rm --privileged -v "$(pwd):/workspace" "$IMAGE_NAME" \
  livemedia-creator \
  --make-iso \
  --iso-only \
  --iso-name=VibeOS-UEFI.iso \
  --ks=/workspace/vibeos.ks \
  --project="Custom Fedora" \
  --releasever=39 \
  --volid="VibeOS" \
  --macboot \
  --tmp=/workspace/tmp \
  --resultdir=/workspace/out
