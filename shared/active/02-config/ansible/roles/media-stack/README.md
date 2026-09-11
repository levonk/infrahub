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

See `shared/docs/pipelines/media/PIPELINE-MEDIA.md` for the full pipeline documentation.
