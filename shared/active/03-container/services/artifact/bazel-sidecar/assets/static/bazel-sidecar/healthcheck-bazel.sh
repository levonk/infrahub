#!/bin/bash
set -euo pipefail

# Check if Bazel binary exists at expected location
if [ ! -f "/opt/bazel/bazel" ]; then
  echo "Bazel binary not found at /opt/bazel/bazel"
  exit 1
fi

# Check if Bazel is executable
if [ ! -x "/opt/bazel/bazel" ]; then
  echo "Bazel binary is not executable"
  exit 1
fi

# Run Bazel version check
/opt/bazel/bazel version >/dev/null 2>&1 || true
