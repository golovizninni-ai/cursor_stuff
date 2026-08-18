#!/usr/bin/env bash
set -euo pipefail

# NVENC smoke test from Tdarr docs. Requires NVIDIA driver + Container Toolkit.
docker run --rm \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e NVIDIA_VISIBLE_DEVICES=all \
  --gpus=all \
  ghcr.io/haveagitgat/tdarr_node:latest \
  /bin/bash -e -c 'curl -o /tmp/sample.mkv -L https://samples.tdarr.io/api/v1/samples/sample__1080__libx264__aac__30s__video.mkv; ffmpeg -i /tmp/sample.mkv -c:v:0 hevc_nvenc /tmp/sample-out.mkv'

echo "NVENC test finished successfully."
