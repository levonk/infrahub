## Nix Strategy

Nix robust "waterfall" of caches that prioritizes **speed first** (local LAN), then **reliability** (regional proxy), and finally **completeness** (internet/cloud).

Here is the breakdown of why this works and how to configure the priorities (lower number = higher priority) to achieve exactly what you described.

### Critical Architecture Note: External Volume Mounts

Nearly all Nix based containers mount `/nix` and `/etc/nix` as external Docker volumes. Monitored and optimized by `nix-sidecar`. This means:

1. **Package installation must happen at runtime** in the entrypoint script, NOT in the Dockerfile
2. **The flake.nix must be executed after volume mounts are available** to install required packages
3. **Dockerfile only sets up the base structure** - all package installation happens dynamically

### Required Runtime Package Installation for nix-sidecar

In the entrypoint script, after volume mounts are available:

```bash
# Install required packages for user management
nix profile install nixpkgs#shadow nixpkgs#gosu nixpkgs#supercronic
```

This ensures packages are available in the mounted Nix store for the container to use.

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

## References

- [[Cross Platform To Install]]
