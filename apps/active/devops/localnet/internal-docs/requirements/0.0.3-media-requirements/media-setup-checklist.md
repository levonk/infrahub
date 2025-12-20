# Media Setup Remediation Checklist

## Compose and orchestration hygiene
- [x] Fix the `TZ` environment variable syntax in `services/media/docker-compose.media.yml` so it exports `TZ=${TIMEZONE}` correctly.
- [x] Golden-fix `services/media/jellyfin` (add `.copier-answers.yml`, remove template placeholders, and ensure the standalone `docker-compose.yml` runs).
- [x] Validate `apps/active/devops/localnet/docker-compose.localnet.yml` with media includes enabled to confirm `docker compose config` succeeds without placeholders.
- [ ] Resolve Docker daemon unavailability on host (install/start dockerd or fix context) to enable runtime checks (`make health-check`).
- [ ] Run `make health-check` with media enabled to confirm all remediated services pass liveness tests.
- [ ] Ensure `rg -n "{{\\s*_service_" apps/active/devops/localnet/services` returns no matches.
- [ ] Add `.copier-answers.yml` for every remediated service so regeneration is reproducible.
- [x] Document any remaining blockers or nonstandard configurations in `internal-docs/requirements/0.0.3-media-requirements/media-setup.md`.
- [x] Upgrade host Nix to >= 2.18 to unblock docker-nix builds (qbittorrent-enhanced).

## File-xfer category golden fixes
- [x] Golden-fix `services/file-xfer/alt-sendme`.
- [x] Golden-fix `services/file-xfer/bentopdf`.
- [x] Golden-fix `services/file-xfer/duplicati`.
- [x] Golden-fix `services/file-xfer/enclosed`.
- [x] Golden-fix `services/file-xfer/file-browser`.
- [ ] Golden-fix `services/file-xfer/file-cloud`.
- [ ] Golden-fix `services/file-xfer/metube`.
- [ ] Golden-fix `services/file-xfer/microbin`.
- [ ] Golden-fix `services/file-xfer/nextcloud`.
- [ ] Golden-fix `services/file-xfer/paperless-ai`.
- [ ] Golden-fix `services/file-xfer/paperless-ngx`.
- [x] Golden-fix `services/file-xfer/qbittorrent`.
- [ ] Golden-fix `services/file-xfer/rclone-gui`.
- [ ] Golden-fix `services/file-xfer/sabnzbd`.
- [ ] Golden-fix `services/file-xfer/syncthing`.
- [ ] Golden-fix `services/file-xfer/zerobytes`.
- [ ] Decide whether to create `services/file-xfer/docker-compose.file-xfer.yml` or fold file-xfer services into another category.

## Media category golden fixes
- [ ] Golden-fix `services/media/audiobookshelf`.
- [ ] Golden-fix `services/media/bazarr`.
- [ ] Golden-fix `services/media/deduparr`.
- [ ] Golden-fix `services/media/flaresolverr`.
- [ ] Golden-fix `services/media/flexget`.
- [x] Golden-fix `services/media/jellyfin`.
- [ ] Golden-fix `services/media/jellyfintv`.
- [ ] Golden-fix `services/media/kapowarr`.
- [ ] Golden-fix `services/media/lidarr`.
- [ ] Golden-fix `services/media/mediamanager`.
- [ ] Golden-fix `services/media/mydia`.
- [ ] Golden-fix `services/media/plex`.
- [ ] Golden-fix `services/media/prowlarr`.
- [ ] Golden-fix `services/media/radarr`.
- [ ] Golden-fix `services/media/recyclarr`.
- [ ] Golden-fix `services/media/romm`.
- [ ] Golden-fix `services/media/sonarr`.
- [ ] Golden-fix `services/media/tdarr`.
- [ ] Golden-fix `services/media/unpackarr`.
- [ ] Golden-fix `services/media/whisparr`.

## VPN category golden fixes
- [ ] Golden-fix `services/vpn/cloudflare-warp`.
- [ ] Golden-fix `services/vpn/headscale`.
- [ ] Golden-fix `services/vpn/nebula`.
- [x] Golden-fix `services/vpn/netbird`.
- [ ] Golden-fix `services/vpn/netmaker`.
- [x] Golden-fix `services/vpn/tailscale`.
- [x] Golden-fix `services/vpn/twingate`.
- [ ] Golden-fix `services/vpn/wireguard-direct`.
- [ ] Golden-fix `services/vpn/wireguard-transparent`.
- [ ] Golden-fix `services/vpn/zerotier`.

## Artifact category golden fixes
- [ ] Golden-fix `services/artifact/nexus`.
- [ ] Golden-fix `services/artifact/nix-attic`.
- [ ] Golden-fix `services/artifact/nix-harmonia`.
- [ ] Golden-fix `services/artifact/nix-ncps`.
- [ ] Golden-fix `services/artifact/nix-snapshotter`.
- [ ] Golden-fix `services/artifact/verdaccio`.

## NTP category golden fixes
- [ ] Golden-fix `services/ntp/chronyd`.

## Cross-cutting decisions and validation
- [ ] Decide and document how to upgrade Nix from 2.8.0 to >= 2.18 or pin nixpkgs appropriately for docker-nix workflows.
- [ ] Decide the canonical home for qBittorrent (either `services/home/docker-compose.home.yml` or `services/file-xfer/qbittorrent`) and remove duplicates.
- [ ] Align gluetun port exposure list with the actual set of services that must route through it.
- [ ] Confirm whether docker-nix scaffolding remains the long-term template or if select services switch to upstream images, and codify that in documentation.
- [ ] Reconcile `README.md` vs `docs/README.md` regarding host prerequisites and document the authoritative guidance.
- [ ] Fix any remaining env var syntax bugs (e.g., `TZ-${TIMEZONE}` style issues) discovered during remediation.
- [ ] Produce a final report of any services still missing concrete image references or requiring follow-up.
