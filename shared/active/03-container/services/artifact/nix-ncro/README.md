# ncro — Nix Cache Route Optimizer

Nix cache racing proxy that sits in front of upstream caches, races them in parallel, and returns the fastest response. Stateless — no NAR storage (streams directly from upstreams).

Upstream: https://github.com/manic-systems/ncro

## Architecture

ncro sits behind ncps in the cache chain:

```
Nix client → ncps (cache.nl.levonk.com) → ncro (127.0.0.1:4525) → races upstreams
                                                        ├→ Harmonia (local /nix/store)
                                                        ├→ cache.nixos.org
                                                        ├→ cache.garnix.io
                                                        └→ nix-community.cachix.org
```

On a narinfo lookup, ncro:
1. Checks the SQLite route cache for a known-fast upstream
2. On miss, races HEAD requests to all upstreams in parallel
3. The fastest upstream wins; the route is cached with a TTL
4. NAR data is streamed directly from the winning upstream (no local storage)

## Building

Build on a Nix-capable x86_64-linux machine (dtop202311 with nix-sidecar):

```bash
make build        # production image
make build-debug  # debug image with extra tools
```

The image is tagged as `localnet-nix-ncro:latest`.

## Configuration

ncro is configured via a TOML file at `/config/config.toml` (rendered by Ansible).
Key settings:

- `server.listen` — listen address (default: `0.0.0.0:8081`)
- `upstreams` — list of upstream caches with priority and public_key
- `cache.ttl` — route cache TTL (default: `2h`)
- `cache.negative_ttl` — negative cache TTL (default: `15m`)

The SQLite route cache is stored at `/data/routes.db` (set via `NCRO_DB_PATH` env var).
