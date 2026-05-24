#!/bin/sh

# Entry point for rust-sidecar
# This script ensures Rust toolchain is available on the shared volume

set -e

echo "Starting rust-sidecar entrypoint..."

# Check if Rust is already initialized on the shared volume (check for cargo in .cargo or .rustup)
if [ ! -f "/home/cuser/.cargo/.initialized" ] && [ ! -f "/home/cuser/.rustup/.initialized" ]; then
    echo "Rust toolchain not found on shared volume, extracting from archive..."
    
    # Ensure the shared volume directories exist
    mkdir -p /home/cuser/.cargo/registry
    mkdir -p /home/cuser/.cargo/git
    mkdir -p /home/cuser/.rustup
    
    # Extract Rust toolchain from archive if archive exists
    if [ -f "/rust-sidecar/tmp/rust-toolchain-archive.tar.zstd" ]; then
        echo "Extracting Rust toolchain archive to shared volume..."
        # The archive contains both .cargo and .rustup directories
        zstd -dc /rust-sidecar/tmp/rust-toolchain-archive.tar.zstd | tar -xf - -C /home/cuser/
        echo "Archive extraction complete"
    else
        echo "No archive found, initializing empty Rust directories..."
    fi
    
    # Create initialization marker
    touch /home/cuser/.cargo/.initialized
    touch /home/cuser/.rustup/.initialized
    echo "Rust toolchain initialization complete"
else
    echo "Rust toolchain already available on shared volume"
fi

# Ensure cache directories exist
mkdir -p /home/cuser/.cache/rust
mkdir -p /home/cuser/.cargo/registry/cache
mkdir -p /home/cuser/.cargo/registry/src

# Ensure proper permissions
chown -R 1000:1000 /home/cuser/.cargo 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.rustup 2>/dev/null || true
chown -R 1000:1000 /home/cuser/.cache/rust 2>/dev/null || true

# Create symlinks for rust tools if needed
for tool in rustc cargo rustup rustdoc; do
    if [ -f "/home/cuser/.cargo/bin/${tool}" ] && [ ! -f "/usr/local/bin/${tool}" ]; then
        echo "Creating ${tool} symlink..."
        ln -sf /home/cuser/.cargo/bin/${tool} /usr/local/bin/${tool} || true
    fi
done

# Test that cargo is working
if command -v cargo >/dev/null 2>&1; then
    echo "cargo version: $(cargo --version)"
elif [ -f "/home/cuser/.cargo/bin/cargo" ]; then
    echo "cargo found at: /home/cuser/.cargo/bin/cargo"
else
    echo "WARNING: cargo command not available in PATH"
fi

echo "rust-sidecar initialization complete. Keeping container alive..."

# Keep the container running
exec "$@"
