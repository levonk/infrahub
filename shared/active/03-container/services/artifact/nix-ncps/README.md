# NCPS (Nix Cache Proxy Server) Docker Image

This directory contains a Nix Flake to build a Docker image for `ncps`, a high-performance local binary cache proxy for Nix.

## Features
- **Zero Configuration**: Proxies and caches requests to `cache.nixos.org` by default.
- **Local Cache**: Stores artifacts locally to speed up subsequent builds on the LAN.
- **Nix Built**: Reproducible and minimal image using `dockerTools.buildLayeredImage`.

## Building the Image

```bash
# Build the Docker image tarball
nix build .#

# Load into Docker
docker load < result
```

The image will be tagged `ncps:latest`.

## Usage

Run `ncps` and mount a volume for the cache storage.

```yaml
services:
  ncps:
    image: ncps:latest
    container_name: localnet-proxy-ncps
    restart: unless-stopped
    ports:
      - "5000:8080"
    volumes:
      - ncps-data:/data
    # Optional: Configure upstreams or other settings via flags if needed, 
    # but defaults often work for standard upstream proxying.
    # command: ["--upstream", "https://cache.nixos.org"]

volumes:
  ncps-data:
```

## Configuring Nix Clients

On your Nix machines, configure `nix.conf`:

```conf
substituters = http://<LAN-IP-OF-NCPS>:5000 https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

Note: `ncps` typically proxies the upstream signature, so you use the upstream public key.

## References
- Source: [kalbasit/ncps](https://github.com/kalbasit/ncps)
