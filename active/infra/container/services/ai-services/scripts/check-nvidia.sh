#!/usr/bin/env bash
set -euo pipefail

# NVIDIA GPU runtime readiness check for Ollama containers
# Usage:
#   ./check-nvidia.sh            # shallow checks (no image pulls)
#   ./check-nvidia.sh --deep     # also runs a CUDA container to validate GPU access
# Exit codes:
#   0 = OK, GPU runtime ready
#   1 = Missing dependencies or misconfiguration
#   2 = Deep check failed (CUDA/nvidia-smi inside container)

info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
err()  { printf "[ERROR] %s\n" "$*"; }

DEEP_CHECK=${1:-}

info "Checking host NVIDIA driver (nvidia-smi)"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  err "nvidia-smi not found. Install NVIDIA drivers on the host."
  exit 1
fi
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || { err "nvidia-smi failed"; exit 1; }

info "Checking Docker + NVIDIA runtime integration"
if ! command -v docker >/dev/null 2>&1; then
  err "docker not found. Install Docker."
  exit 1
fi

# Look for GPU support in docker info (varies across versions)
if ! docker info 2>/dev/null | grep -qiE "Runtimes:.*nvidia|nvidia-container-runtime|NVIDIA"; then
  warn "NVIDIA runtime not detected by Docker."
  warn "Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
  warn "Then restart Docker and re-run this script."
  exit 1
fi

info "Shallow checks passed."

if [ "$DEEP_CHECK" = "--deep" ]; then
  info "Running CUDA test container (this may pull an image)"
  set +e
  docker run --rm --gpus all --pull=always nvidia/cuda:12.3.2-base-ubuntu22.04 \
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    err "Deep GPU test failed inside container. Ensure NVIDIA driver and toolkit versions are compatible."
    exit 2
  fi
  info "Deep GPU container test passed."
fi

info "NVIDIA GPU runtime appears ready for Ollama."
