# Freenet peer node (freenet-core)

Locally-built Docker image for the [freenet-core](https://github.com/freenet/freenet-core)
peer node — the Rust P2P decentralized app platform.

## What this runs

The `freenet network` daemon in peer (non-gateway) mode:

- Exposes a WebSocket API on port `7509` (the `fdev` tooling and browser UI connect here)
- Stores contract state, delegate state, and node identity under `/root/.cache/freenet`
- Joins the Freenet network by bootstrapping from the public gateway list

This is **not** the legacy Java Freenet darknet node. It is the new Rust
freenet-core platform — the same one documented in the 2ndbrain vault notes
at `Computer/Medium/Freenet/Freenet.md`.

## Build

The Dockerfile is multi-stage: a `rust:1-bookworm` builder compiles
`freenet-core` from source, then the binary is copied into a
`debian:bookworm-slim` runtime image.

Target platform is `linux/amd64` (the deployment target is Windows Docker
Desktop). The repo-wide `build-and-push-images.sh` defaults to `linux/arm64`
for the OCI server, so override `PLATFORM`:

```bash
PLATFORM=linux/amd64 scripts/build-and-push-images.sh localnet-p2p-freenet
```

To pin a specific upstream release, set `FREENET_CORE_REF` (default `main`):

```bash
docker build --build-arg FREENET_CORE_REF=v0.0.42 \
  -t localnet-p2p-freenet:latest \
  -f docker/Dockerfile.freenet ..
```

## Local test

```bash
docker compose -f docker-compose.freenet.yml up
# WS API now on http://localhost:7509
```

## Deployment

Deployed by the `p2p-freenet` Ansible role via
`playbooks/deploy-freenet.yml`, targeting the `windows_docker_hosts` group
(host `dtop202311`). Access is Tailscale-only — no public domain, no Traefik
routing. Reach the WS API at `http://dtop202311.tale-grouper.ts.net:7509`.

## Files

- `docker/Dockerfile.freenet` — multi-stage build
- `docker/freenet-node-startup.sh` — entrypoint (runs `freenet network`)
- `docker-compose.freenet.yml` — reference only, not deployed
