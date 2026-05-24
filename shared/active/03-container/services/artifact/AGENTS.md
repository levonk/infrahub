# Artifact Sidecar Containers - Architecture Guide

## Overview

The artifact sidecar containers in `/services/artifact/*-sidecar/` are designed to leverage shared volumes to prevent redundant downloads, caches, and disk space across containers. This architecture enables efficient package management and build tool sharing.

## Two Primary Scenarios

### 1. Build Cache Sidecars (Simple Pattern)
**Examples**: `bazel-sidecar`, `turborepo-sidecar`

These containers provide build tool caches that are loaded into the sidecar to check repository integrity. The tools are typically installed during build time and don't require runtime downloads.

**Pattern**: Single-stage Dockerfile with tools installed at build time, shared volume mounted at runtime.

### 2. Package Installation Sidecars (Archive Pattern)
**Examples**: `dotnet-sidecar`, `nix-sidecar`, `mise-sidecar`

These containers involve downloading/installing large package datasets during initialization. The challenge is that shared volumes are only available at runtime, not during Docker build time.

## Archive Pattern Implementation

### Problem
When packages need to be downloaded/installed at runtime, the shared volume isn't available during Docker build. Installing packages in the entrypoint script every time is inefficient.

### Solution: Multi-Stage Archive Pattern

#### Stage 1: Build Stage
- Downloads and installs the complete package
- Archives the installed package to `/*-sidecar/tmp/*-archive.tar.zstd`
- Uses high-compression ratio (zstd recommended) for optimal space

#### Stage 2: Sidecar Stage  
- Also installs the package base (but deletes the large components that will be replaced by shared volume)
- Copies the compressed archive from build stage
- Entrypoint script extracts archive **only if necessary** (when shared volume is empty)

#### Runtime Logic
```bash
# In entrypoint-*-sidecar.sh
if [ ! -f "/shared/volume/package/installed" ]; then
    echo "Extracting package archive to shared volume..."
    tar -xzf /tmp/package-archive.tar.zstd -C /shared/volume/
else
    echo "Package already available on shared volume"
fi
```

## Current Implementation Status

### Fixed (Archive Pattern)
- **dotnet-sidecar**: Uses multi-stage build with archive extraction in entrypoint
- **nix-sidecar**: Implements archive pattern for Nix package store
- **mise-sidecar**: Uses build stage for mise binary, runtime extraction
- **pnpm-sidecar**: Multi-stage build with pnpm archive, entrypoint extraction to shared volume
- **conda-sidecar**: Multi-stage build with conda archive, entrypoint extraction to shared volume
- **rust-sidecar**: Multi-stage build with Rust toolchain archive, entrypoint extraction
- **asdf-sidecar**: Multi-stage build with asdf archive, entrypoint extraction to shared volume

### Need Archive Pattern Implementation
- **dart-sidecar**: Could benefit from SDK archive
- **elixir-sidecar**: Mix/Hex packages could be archived
- **gradle-sidecar**: Gradle wrapper and dependencies
- **haskell-sidecar**: Stack/Cabal packages
- **java-sidecar**: JDK/Maven packages
- **nvm-sidecar**: Node.js versions
- **php-sidecar**: Composer packages
- **poetry-sidecar**: Python dependencies
- **pyenv-sidecar**: Python versions
- **python-sidecar**: pip packages
- **ruby-sidecar**: RubyGems
- **sdkman-sidecar**: Java SDKs

### Simple Pattern (Already Optimized)
- **go-sidecar**: Alpine package install (small)
- **python-sidecar**: Alpine package install (small)

## Implementation Guidelines

### When to Use Archive Pattern
- Package managers with large download sizes (>50MB)
- Tools that download additional components during first run
- SDKs that include multiple versions or large libraries
- When initialization time is significant (>30 seconds)

### Critical: Avoid Wasted Space in Sidecar Image

**DO NOT install packages directly to the shared volume mount path in the sidecar stage.**

When a shared volume is mounted at runtime, it overlays (masks) any data that exists at that path in the container image. Files installed during build to the shared volume path become inaccessible and waste disk space.

**Wrong Pattern (Wastes Space):**
```dockerfile
# Sidecar stage - DON'T DO THIS
FROM localnet-base-sidecar:latest
RUN curl -sSL https://example.com/package.tar.gz | tar -xz -C /var/lib/package
# ^ Files here will be hidden by shared volume mount at runtime - WASTED SPACE
```

**Correct Pattern (Archive Only):**
```dockerfile
# Build stage - Create archive
FROM localnet-base-sidecar:latest as package-builder
RUN curl -sSL https://example.com/package.tar.gz | tar -xz -C /tmp/package && \
    tar -I "zstd -19" -cf /tmp/package-archive.tar.zstd -C /tmp/package .

# Sidecar stage - Only copy archive, not extracted files
FROM localnet-base-sidecar:latest
COPY --from=package-builder /tmp/package-archive.tar.zst /package-sidecar/tmp/
# ^ Only the archive exists in image, extracted to shared volume at runtime
```

**Key Rule - Separation of Concerns:**

| Component | Location | Purpose |
|-----------|----------|---------|
| **Package Manager Tools** (nix, pnpm, npm, cargo, pip, etc.) | Install in sidecar image at `/usr/local/bin` or `/opt` | Provides CLI for users to investigate package repositories, query packages, run installs |
| **Package Data/Store** (nix store, npm cache, cargo registry, pip packages) | Extract from archive to shared volume at runtime | Large package datasets that would waste space if duplicated in every container |

**What goes in the sidecar stage:**
- Package manager binaries (nix, pnpm, npm, cargo, pip, etc.)
- The compressed archive of package data (`/*-sidecar/tmp/*-archive.tar.zstd`)
- Minimal runtime dependencies
- Entrypoint scripts

**What goes on the shared volume:**
- nix store (`/nix/store/*`)
- npm global packages and cache (`~/.npm`, `~/.cache/pnpm`)
- Cargo registry (`~/.cargo/registry/*`)
- pip packages (`~/.local/lib/python*/site-packages`)
- Any other large package datasets

**Never** extract package data to the shared volume mount path during the sidecar stage build - only copy the archive.
```dockerfile
# In build stage
RUN tar -I "zstd -19" -cf /tmp/package-archive.tar.zstd /path/to/package
```

### Entrypoint Extraction Logic
```bash
# Check if shared volume needs population
if [ ! -f "/shared/volume/.initialized" ]; then
    echo "Initializing shared volume from archive..."
    mkdir -p /shared/volume
    tar -I "zstd -d" -xf /tmp/package-archive.tar.zstd -C /shared/volume/
    touch /shared/volume/.initialized
    echo "Archive extraction complete"
else
    echo "Shared volume already initialized"
fi
```

### Compression Recommendations
- **zstd**: Best compression ratio and speed (`zstd -19` for maximum)
- **Alternative**: xz (`-9` flag) if zstd unavailable
- **Location**: Store archives in `/*-sidecar/tmp/` to be cleaned up after extraction

## Benefits

1. **Reduced Network Usage**: Packages downloaded once during build, reused at runtime
2. **Faster Startup**: Archive extraction faster than re-downloading
3. **Consistent Environment**: Same package versions across container restarts
4. **Shared Resource**: Multiple containers can use the same package installation

## Migration Checklist

For sidecars needing archive pattern implementation:

- [ ] Identify package download/installation locations
- [ ] Create multi-stage Dockerfile with build stage
- [ ] Add archive creation step with compression
- [ ] Modify sidecar stage to copy archive
- [ ] Implement entrypoint extraction logic
- [ ] Test with fresh shared volume
- [ ] Test with existing shared volume
- [ ] Verify cleanup of temporary archives
