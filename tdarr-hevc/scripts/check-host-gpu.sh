#!/usr/bin/env bash
set -euo pipefail

echo "== nvidia-smi =="
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found. Install the proprietary NVIDIA driver first." >&2
  exit 1
fi
nvidia-smi

echo
echo "== Docker GPU runtime =="
if docker info 2>/dev/null | grep -qi nvidia; then
  echo "Docker reports an NVIDIA runtime."
else
  echo "Docker does not report an NVIDIA runtime yet."
  echo "Run: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
fi

echo
echo "== NVIDIA Container Toolkit =="
if command -v nvidia-ctk >/dev/null 2>&1; then
  nvidia-ctk --version
else
  echo "nvidia-ctk not found. Install NVIDIA Container Toolkit."
fi
