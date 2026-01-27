## Nix Strategy

Nix robust "waterfall" of caches that prioritizes **speed first** (local LAN), then **reliability** (regional proxy), and finally **completeness** (internet/cloud).

Here is the breakdown of why this works and how to configure the priorities (lower number = higher priority) to achieve exactly what you described.

## Multi-User Nix Architecture (Recommended)

### Why Multi-User Nix is Preferred

For containerized environments, multi-user Nix provides superior security, isolation, and performance compared to single-user setups:

- **Security**: Proper build sandboxing with `nixbld1-32` users
- **Isolation**: Per-user profiles prevent package conflicts
- **Performance**: Shared package store with isolated build caches
- **Scalability**: Easy to add more containers without conflicts

### Critical Architecture Note: External Volume Mounts

Nearly all Nix based containers mount shared volumes as external Docker volumes. The shared volumes monitored and optimized by `nix-sidecar`. This means:

1. **Package installation must happen at runtime** in the entrypoint script, NOT in the Dockerfile
2. **The flake.nix must be executed after volume mounts are available** to install required packages
3. **Dockerfile only sets up the base structure** - all package installation happens dynamically

### Shared Volume Strategy

```yaml
volumes:
  nix-store:           # Shared package store
  nix-config:          # Shared configuration
  nix-cache-root:      # Shared daemon cache
  nix-cache-user-a:    # User-specific cache (heavy builds)
  nix-cache-user-b:    # User-specific cache (heavy builds)

services:
  any-container:
    volumes:
      - nix-store:/nix:rw              # Shared packages
      - nix-config:/etc/nix:ro         # Shared config
      - nix-cache-root:/root/.cache/nix:rw  # Shared daemon cache
      - nix-cache-user-a:/home/user-a/.cache/nix:rw  # User cache
```

### Volume Ownership and Permissions

#### Nix Store (`/nix`)
- **Owner**: `root:root` (755)
- **Purpose**: Shared package storage
- **Access**: All containers via shared volume

#### Configuration (`/etc/nix`)
- **Owner**: `root:root` (644)
- **Purpose**: Shared Nix configuration
- **Content**: `build-users-group = nixbld`, substituters, etc.

#### Root Cache (`/root/.cache/nix`)
- **Owner**: `root:root` (755)
- **Purpose**: Daemon operations, downloads, GC
- **Shared**: Across all containers

#### User Caches (`/home/username/.cache/nix`)
- **Owner**: `username:nixbld` (755)
- **Purpose**: User-specific builds, heavy build isolation
- **Isolated**: Per user for heavy build processes

### Build Users Configuration

Multi-user Nix requires proper build user setup:

```bash
# Required in each container
groupadd -g 30000 nixbld
for i in {1..32}; do
    useradd -M -G nixbld nixbld$i
done

# Configuration in /etc/nix/nix.conf
build-users-group = nixbld
sandbox = true
```

### User Profile Isolation

```bash
# Each container/user gets isolated profiles
/nix/var/nix/profiles/per-user/container-a/profile
/nix/var/nix/profiles/per-user/container-b/profile
/nix/var/nix/profiles/per-user/heavy-build/profile

# No conflicts between containers
```

### Heavy Build Process Considerations

For containers running heavy build processes (Rust, C++, Go projects):

1. **User-specific cache volumes** prevent cache thrashing
2. **Proper volume sizing** (50-100GB per heavy build container)
3. **Resource allocation** (memory, CPU cores per container)
4. **Cache management** for large build artifacts

```yaml
# Example heavy build container
heavy-builder:
  volumes:
    - nix-store:/nix:rw
    - nix-cache-root:/root/.cache/nix:rw
    - nix-cache-heavy:/home/build-user/.cache/nix:rw  # 100GB volume
  environment:
    - USERNAME=build-user
    - PUID=1001
  deploy:
    resources:
      limits:
        memory: 32G
      reservations:
        memory: 16G
```

### Required Runtime Package Installation for nix-sidecar

In the entrypoint script, after volume mounts are available:

```bash
# Install required packages for user management
nix profile install nixpkgs#shadow nixpkgs#gosu nixpkgs#supercronic
```

This ensures packages are available in the mounted Nix store for the container to use.

### Container Security and User Management

#### Permission Dropping Strategy

Containers should drop privileges as early as possible:

```bash
# In entrypoint script
if [ -n "${USERNAME:-}" ] && [ -n "${PUID:-}" ]; then
    # Create user with specific UID
    useradd -u "$PUID" -m "$USERNAME"

    # Drop privileges immediately
    exec gosu "$USERNAME" "$@"
fi
```

#### Health Check Verification

The healthcheck verifies all multi-user components:

```bash
# Comprehensive checks in healthcheck-nix-sidecar.sh
- /nix ownership (root:root, 755)
- nixbld group (GID 30000)
- nixbld1-32 users (proper configuration)
- User profiles (correct ownership)
- Configuration (/etc/nix/nix.conf)
- Current user context
```

#### Security Best Practices

- **Run as non-root**: All operations run as `$USERNAME`
- **Sandbox builds**: Uses `nixbld` users for build isolation
- **Minimal privileges**: Only necessary capabilities granted
- **Volume permissions**: Proper ownership on all shared volumes

### The Logic Flow

1.  **Garnix (The Builder):**
    - **Action:** Compiles code $\rightarrow$ **Pushes** to Attic (and/or Cachix).
    - _Note:_ Garnix also has its own cache URL (`cache.garnix.io`), which you can use as a backup.

2.  **Client Request (e.g., K8s Node/Nix Snapshotter):**
    - **Priority 30: Harmonia** (Regional "Smart" Store)
      - _Check:_ "Does the regional server _already have this running/installed_?"
      - _Hit:_ Instant LAN transfer. **Zero duplication** on the regional server.
    - **Priority 40: ncps** (Regional Proxy)
      - _Check:_ "Has anyone on my LAN downloaded this recently?"
      - _Hit:_ Fast LAN transfer.
      - _Miss:_ `ncps` goes out to download it from Attic/Garnix, caches it, and serves it to you.
    - **Priority 50+: Cloud Sources** (Attic / Cachix / Garnix)
      - _Check:_ "I'm desperate, go to the internet."
      - _Role:_ Final fallback if your regional server is down or broken.

### How to Configure It

#### 1. On the Regional Server (The "Hub")

You run **both** Harmonia and `ncps` here.

- **Harmonia:** Expose on port `5000`. No upstream config needed (it just reads `/nix/store`).
- **ncps:** Expose on port `5001`. Configure its **upstreams** to be your cloud sources.
  ```toml
  # ncps config.toml
  [upstream]
  # This allows ncps to fetch from your cloud sources when local clients ask
  substituters = [
    "https://attic.your-domain.com",
    "https://cache.garnix.io",
    "https://cache.nixos.org"
  ]
  ```

#### 2. On the Client (K8s Node / Laptop)

You configure the `nix.conf` (or Nix Operator) with the priority order.

```nix
# /etc/nix/nix.conf or NixOS config
substituters = [
  # 1. Check Regional "Active" Store (Fastest, deduplicated)
  "http://regional-server:5000?priority=30"

  # 2. Check Regional Proxy (Fast, cached from previous fetches)
  "http://regional-server:5001?priority=40"

  # 3. Fallback: Go direct to Cloud (Slow, internet bandwidth)
  "https://attic.your-domain.com?priority=50"
  "https://cache.garnix.io?priority=60"
  "https://cache.nixos.org?priority=80"
]
```

### Why this is the "Gold Standard"

- **Harmonia First:** Ensures that if your Regional Server is running a `postgres` database, your K8s nodes pull _that exact binary_ from the server's store without making the server download a second copy into a cache folder.
- **ncps Second:** Handles the "long tail" of packages. If a K8s node needs a weird library that the Regional Server _isn't_ using itself, `ncps` fetches and caches it so the _next_ K8s node gets it fast.
- **Cloud Last:** Resilience. If your office/regional internet is flaky or the server crashes, your builds/deployments still work (just slower).

## Implementation References

- **Health Check**: `/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh`
  - Comprehensive multi-user verification
  - Ownership and permissions checking
  - Build user validation
- **Entry Point**: `/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh`
  - User creation and privilege dropping
  - Volume mount handling
  - Runtime package installation
- **Dockerfile**: `/services/base/nix-sidecar/Dockerfile.nix-sidecar`
  - Multi-user base image setup with minimal packages
  - Security hardening and user creation
  - Volume configuration for runtime mounts
  - **Critical**: Almost no packages installed - relies on shared `/nix` volume mounted at runtime

## Best Practices Summary

1. **Always use multi-user Nix** for containerized environments
2. **Share `/nix` and `/etc/nix`** across containers for efficiency
3. **Share `/root/.cache/nix`** for daemon operations
4. **Use user-specific caches** for heavy build processes
5. **Proper permission dropping** to non-root users
6. **Comprehensive health checks** for all components
7. **Volume sizing** appropriate to build workloads

## References

- [[Cross Platform To Install]]
- [[Multi-User Nix Configuration]]
- [[Container Security Best Practices]]
