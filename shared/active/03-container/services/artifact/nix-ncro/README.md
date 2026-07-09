# ncro (Parallel Racing Nix Cache Proxy) Docker Image

This directory contains a Nix Flake to build a Docker image for `ncro`, a parallel racing Nix cache proxy.

## Features
- **Parallel Racing**: Races all upstream caches in parallel instead of sequential waterfall, reducing latency on cache misses.
- **EMA Latency Tracking**: Learns which upstream is fastest via exponential moving average latency tracking stored in a small SQLite DB.
- **No NAR Storage**: Streams NARs directly — does not store them (ncps handles local NAR caching).
- **Nix Built**: Reproducible and minimal image using `dockerTools.buildLayeredImage` from `github:feel-co/ncro`.

## Building the Image

```bash
# Build the Docker image tarball
nix build .#docker-prod

# Load into Docker
docker load < result
```

The image will be tagged `ncro:latest`.

A debug image with network tools is also available:

```bash
nix build .#docker-debug
docker load < result
```

The debug image will be tagged `ncro-debug:latest` and includes curl, wget, iproute2, jq, and other troubleshooting tools.

## Usage

ncro binds to `127.0.0.1` only — only the regional ncps instance talks to it directly. It races all configured upstream caches in parallel and returns the first successful response.

### Docker Compose Example

```yaml
services:
  ncro:
    image: ncro:latest
    container_name: localnet-proxy-ncro
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8081"
    volumes:
      # SQLite DB for EMA latency tracking
      - ncro-data:/data
    # Config file mounted at runtime (templated by Ansible)
    command: ["--config", "/data/config.toml"]

volumes:
  ncro-data:
```

## Configuration

ncro uses a TOML config file. See `config.toml` in this directory for a reference configuration with all upstreams listed.

### Key Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `server.listen` | Listen address (bind to `127.0.0.1`) | `:8080` |
| `upstreams` | List of upstream caches to race in parallel | — |
| `upstreams[].priority` | Lower = preferred in race engine | — |
| `upstreams[].public_key` | Optional narinfo signature verification key | — |
| `cache.db_path` | SQLite DB path for EMA latency tracking | `/var/lib/ncro/routes.db` |
| `cache.ttl` | How long a successful route decision is trusted | `1h` |
| `cache.negative_ttl` | TTL for failed lookups (avoid immediate retry) | `10m` |
| `cache.latency_alpha` | EMA smoothing factor (smaller = smoother) | `0.3` |
| `logging.level` | Log level: trace, debug, info, warn, error | `info` |
| `logging.format` | Log format: json, text | `json` |

### Upstreams

The reference config includes:
- **All 5 Harmonia instances** (lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm) via Tailscale
- **Attic on OCI** (cloud binary cache)
- **cache.nixos.org** (public NixOS cache, last resort)

The actual config is templated by the Ansible role (Story 02-003) with infrastructure variables.

## Health Endpoint

ncro exposes a `/health` JSON endpoint that returns upstream status:

```bash
curl http://127.0.0.1:8081/health
```

ncro also exposes Prometheus metrics for observability.

## License

ncro is licensed under the [EUPL 1.2](https://github.com/feel-co/ncro) (European Union Public License).

## References
- Source: [feel-co/ncro](https://github.com/feel-co/ncro)
- Configuration reference: [docs/configuration.md](https://github.com/feel-co/ncro/blob/main/docs/configuration.md)
