# media-stack

Deploys the Jellyfin + *arr media pipeline to Windows Docker Desktop (dtop202311,
nl region) via the SSH-tunneled Docker CLI pattern.

## Services

| Service | Image | Port | Domain |
|---------|-------|------|--------|
| jellyfin | `jellyfin/jellyfin` | 8096 | jellyfin.nl.levonk.com |
| jellyseerr | `fallenbagel/jellyseerr` | 5055 | jellyseerr.nl.levonk.com |
| radarr | `lscr.io/linuxserver/radarr` | 7878 | radarr.nl.levonk.com |
| sonarr | `lscr.io/linuxserver/sonarr` | 8989 | sonarr.nl.levonk.com |
| lidarr | `lscr.io/linuxserver/lidarr` | 8686 | lidarr.nl.levonk.com |
| bazarr | `lscr.io/linuxserver/bazarr` | 6767 | bazarr.nl.levonk.com |
| prowlarr | `lscr.io/linuxserver/prowlarr` | 9696 | prowlarr.nl.levonk.com |
| kapowarr | `mrcas/kapowarr` | 5656 | kapowarr.nl.levonk.com |
| audiobookshelf | `ghcr.io/advplyr/audiobookshelf` | 13378 | audiobooks.nl.levonk.com |
| romm | `rommapp/romm` | 8091 | romm.nl.levonk.com |
| kavita | `lscr.io/linuxserver/kavita` | 5060 | kavita.nl.levonk.com |
| calibre-web | `lscr.io/linuxserver/calibre-web` | 8087 | calibre-web.nl.levonk.com |
| komga | `gotson/komga` | 25600 | komga.nl.levonk.com |
| postgres | `postgres:17-alpine` | 5439 | (shared, via db-postgres role) |
| qbittorrent | `lscr.io/linuxserver/qbittorrent` | 8080 (VPN) | qbittorrent.nl.levonk.com |
| sabnzbd | `lscr.io/linuxserver/sabnzbd` | 8081 (VPN) | sabnzbd.nl.levonk.com |
| flaresolverr | `ghcr.io/flaresolverr/flaresolverr` | 8191 | (internal) |
| recyclarr | `ghcr.io/recyclarr/recyclarr` | — | (cron) |
| unpackarr | `ghcr.io/unpackarr/unpackarr` | — | (sidecar) |

## Deployment

```bash
just ansible-deploy-media-stack
```

## Architecture

All containers run on dtop202311 (Windows Docker Desktop) behind Traefik.
The SSH-tunneled Docker CLI pattern is used because `community.docker` modules
cannot run on Windows (Ansible core `basic.py` imports `grp`, Unix-only).

## Database

A single shared PostgreSQL container (`localnet-db-postgres`, deployed by the
`db-postgres` role) serves all DB-capable services — no per-service sidecars:

| Service | Databases | Config mechanism |
|---------|-----------|------------------|
| radarr | `radarr_main`, `radarr_log` | `RADARR__POSTGRES__*` env vars |
| sonarr | `sonarr_main`, `sonarr_log` | `SONARR__POSTGRES__*` env vars |
| lidarr | `lidarr_main`, `lidarr_log` | `LIDARR__POSTGRES__*` env vars |
| prowlarr | `prowlarr_main`, `prowlarr_log` | `PROWLARR__POSTGRES__*` env vars |
| bazarr | `bazarr` | `POSTGRES_*` env vars |
| romm | `romm` | `ROMM_DB_DRIVER=postgresql` |

All other services use embedded sqlite. Consumers connect by container name
on `traefik-windows-network`; the host port (5439) is published for tailnet
debugging only. Passwords come from `vault_media_postgres_*` vault vars;
the superuser password is `vault_db_postgres_admin_password`.

Set `media_stack_postgres_enabled: false` to fall back to embedded sqlite
(RomM is skipped in that mode — it has no sqlite backend).

See `shared/docs/pipelines/media/PIPELINE-MEDIA.md` for the full pipeline documentation.
