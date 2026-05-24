# Harmonia (Nix Binary Cache) Docker Image

This directory contains a Nix Flake to build a Docker image for `harmonia`, a "smart" Nix binary cache.

## Features
- **Serves Local Store**: Exposes the host's `/nix/store` (or a volume) as a binary cache.
- **Priority Handling**: Can be used as a high-priority LAN cache.
- **Nix Built**: Reproducible image using `nix-community/harmonia`.

## Building the Image

```bash
# Build the Docker image tarball
nix build .#

# Load into Docker
docker load < result
```

The image will be tagged `harmonia:latest`.

## Usage

Harmonia requires access to a Nix store to serve packages, and a private key to sign them (unless serving unsigned).

### Docker Compose Example

```yaml
services:
  harmonia:
    image: harmonia:latest
    container_name: localnet-proxy-harmonia
    restart: unless-stopped
    ports:
      - "5000:5000"
    environment:
      - HARMONIA_SIGN_KEY_PATH=/data/secret-key.sec
    volumes:
      # Mount the host Nix store RO so harmonia can serve it
      - /nix/store:/nix/store:ro
      # Data volume for keys
      - harmonia-data:/data
    # You might need to run as root to access /nix/store depending on host perms,
    # or ensure the container user has read access.
    # user: "0:0"

volumes:
  harmonia-data:
```

### Generating a Key
You need a secret key to sign the paths.
```bash
nix-store --generate-binary-cache-key my-harmonia-cache-1 secret-key.sec public-key.pub
```
Mount `secret-key.sec` into the container at `HARMONIA_SIGN_KEY_PATH`.

## Client Configuration
On client machines:
```conf
substituters = http://<LAN-IP>:5000 https://cache.nixos.org
trusted-public-keys = my-harmonia-cache-1:<PUBLIC-KEY-CONTENT> cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```
