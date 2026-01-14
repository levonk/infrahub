#!/bin/bash
set -euo pipefail

# Verify pnpm command exists
if ! command -v pnpm > /dev/null 2>&1; then
    echo "pnpm not found"
    exit 1
fi

# Verify pnpm store integrity
if ! pnpm store status > /dev/null 2>&1; then
    echo "PNPM store integrity check failed"
    exit 1
fi

# Basic responsiveness check
if ! command -v node > /dev/null 2>&1; then
    echo "Node.js not responsive"
    exit 1
fi

exit 0
