# Attic Server (Nix Binary Cache) Docker Image

This directory contains a Nix Flake to build a Docker image for `attic-server`, a multi-tenant Nix binary cache.

## Features
- **Multi-tenant**: Supports multiple caches and users.
- **S3 Compatible**: Can use S3 or local storage (this image is agnostic, configure via `attic.toml`).
- **Nix Built**: Reproducible image using `zhaofengli/attic`.

## Building the Image

```bash
# Build the Docker image tarball
nix build .#

# Load into Docker
docker load < result
```

The image will be tagged `attic-server:latest`.

## Usage

Attic requires a configuration file `attic.toml`.

### Docker Compose Example

```yaml
services:
  attic:
    image: attic-server:latest
    container_name: localnet-artifact-attic
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config/attic.toml:/data/config.toml
      - attic-data:/data
    command: ["-f", "/data/config.toml"]
    # Ensure you set up database URL in config or ENV
    environment:
      - ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=<YOUR_SECRET>

volumes:
  attic-data:
```

### Configuration (`attic.toml`)

Minimal example:
```toml
listen = "[::]:8080"

[database]
url = "sqlite:///data/server.db"

# Storage: Local or S3
[storage]
type = "local"
path = "/data/storage"

[chunking]
nar-size-threshold = 65536
min-size = 16384
avg-size = 65536
max-size = 262144
```

## References
- Source: [zhaofengli/attic](https://github.com/zhaofengli/attic)
