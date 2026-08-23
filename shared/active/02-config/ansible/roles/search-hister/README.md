# search-hister

Deploys [Hister](https://github.com/asciimoo/hister), a self-hosted search engine
for browsing history and documents, as a Docker container on Windows Docker
Desktop (dtop202311, nl region).

## Architecture

- **Image**: `ghcr.io/asciimoo/hister:latest` (upstream, AMD64)
- **Port**: 4433 (host and container)
- **Domain**: `hister.nl.levonk.com` (via Traefik on Windows)
- **Auth**: Authelia SSO (forward-auth middleware in Traefik)
- **Storage**: Docker named volume `localnet-hister-data-volume` at `/hister/data`
- **Database**: SQLite (stored in data volume)

## Deployment Pattern

Uses the SSH-tunneled Docker CLI pattern (`DOCKER_HOST: ssh://` +
`delegate_to: localhost`) because `community.docker` modules can't run on
Windows (Ansible core `basic.py` imports `grp`, Unix-only).

## Configuration

Hister is configured entirely via environment variables — no config files:

| Variable | Purpose |
|----------|---------|
| `HISTER__SERVER__ADDRESS` | Listen address (`0.0.0.0:4433`) |
| `HISTER__SERVER__BASE_URL` | Public URL (`https://hister.nl.levonk.com`) |
| `HISTER__APP__TITLE` | Web UI title |
| `HISTER__APP__LOG_LEVEL` | Log verbosity (`info`) |

## Variables

All variables reference `infra_*` infrastructure variables with safe defaults.
See `defaults/main.yml` for the full list.
