# Media Setup

## Localnet re-materialization: intern onboarding + "full deployment" runbook

## 🎯 Goal (what success looks like)
- **End state**: `apps/active/devops/localnet` deploys cleanly with Docker Compose; every service directory that was created from a boilerplate has **no Jinja placeholders**, has a **real `docker-compose.yml`** files for each service, and can be run:
  - **Standalone** from its own service directory; and
  - **Integrated** via the category compose files that get included by `docker-compose.localnet.yml`.
- **Acceptance checks**:
  - **No template leftovers**: `rg -n "\{\{\s*_service_" apps/active/devops/localnet/services` returns nothing.
  - **No broken images**: no `image: :latest`, no `image: {{ ... }}` anywhere.
  - **Compose validates**: `docker compose -f apps/active/devops/localnet/docker-compose.localnet.yml config` succeeds.
  - **Health**: `make health-check` succeeds for enabled categories.

## 🧭 Where everything lives (map of the repo)
- **Localnet root**: `apps/active/devops/localnet/`
- **Main orchestrator**: `apps/active/devops/localnet/docker-compose.localnet.yml`
  - **How it works**: it defines shared `networks:` and `volumes:`; then it uses Compose `include:` to load category compose files under `services/*/docker-compose.*.yml`.
- **Category compose files** (examples):
  - `services/security/docker-compose.security.yml`
  - `services/vpn/docker-compose.vpn.yml` (contains `gluetun`)
  - `services/media/docker-compose.media.yml`
  - `services/home/docker-compose.home.yml`
- **Service directories**: `apps/active/devops/localnet/services/<category>/<service>/`
  - These contain per-service mounts, configs, scripts, and a standalone `docker-compose.yml` once "golden fixed."

## ✅ Where we are now (current status)
- **Localnet core stack exists** and has documented entrypoints:
  - `apps/active/devops/localnet/README.md`
  - `apps/active/devops/localnet/docs/README.md`
- **We found the real root issue**:
  - Many service dirs contain raw template placeholders like `{{ _service_name_slug }}` inside files that were renamed away from `.jinja2`, but **never actually rendered**.
  - That makes those services not runnable, and some produce broken Compose like `image: :latest`.
- **We have a full inventory of affected directories**:
  - **39 directories** under `apps/active/devops/localnet/services` still contain `{{ _service_... }}` placeholders and need a "golden fix."
- **qbittorrent decision is made**:
  - Use **`qbittorrent-enhanced`**.
  - Blocker: local machine has **Nix 2.8.0**, but nixpkgs `25.11` requires **Nix >= 2.18**, which blocks `nix eval` / docker-nix workflows.

## 🏁 What "golden fix" means (definition)
For each affected service directory, a "golden fix" means:
- **Materialize templates**: remove *all* `{{ ... }}` placeholders by re-materializing from the correct boilerplate in `boilerplage/apps/infrastructure/docker-nix`; preserve functionality.
- **Own the config**: add a service-local `.copier-answers.yml` so regeneration is repeatable.
- **Stand-alone runnable**: `docker compose up` from the service directory works.
- **Integrated runnable**: service is added to the correct `services/<category>/docker-compose.<category>.yml` and works when brought up through `docker-compose.localnet.yml`.
- **Env + mounts are real**: ports, volumes, env vars match localnet conventions; secrets stay out of git.

## 📋 Affected service dirs (must golden-fix)
### file-xfer
- **Services**:
  - `file-xfer/alt-sendme`
  - `file-xfer/bentopdf`
  - `file-xfer/duplicati`
  - `file-xfer/enclosed`
  - `file-xfer/file-browser`
  - `file-xfer/file-cloud`
  - `file-xfer/metube`
  - `file-xfer/microbin`
  - `file-xfer/nextcloud`
  - `file-xfer/paperless-ai`
  - `file-xfer/qbittorrent`
  - `file-xfer/rclone-gui`
  - `file-xfer/sabnzbd`
  - `file-xfer/syncthing`

### media
- **Services**:
  - `media/audiobookshelf`
  - `media/bazarr`
  - `media/deduparr`
  - `media/flaresolverr`
  - `media/flexget`
  - `media/jellyfin`
  - `media/jellyfintv`
  - `media/kapowarr`
  - `media/lidarr`
  - `media/mediamanager`
  - `media/mydia`
  - `media/plex`
  - `media/prowlarr`
  - `media/radarr`
  - `media/recyclarr`
  - `media/romm`
  - `media/sonarr`
  - `media/tdarr`
  - `media/unpackarr`
  - `media/whisparr`

### vpn
- **Services**:
  - `vpn/netbird`
  - `vpn/nebula`
  - `vpn/netmaker`
  - `vpn/headscale`
  - `vpn/tailscale`
  - `vpn/zerotier`
  - `vpn/twingate`

### artifact
- **Services**:
  - `artifact/nix-snapshotter`

## 🚀 How to deploy localnet today (intern quickstart)
- **Step 1; prerequisites**:
  - Docker Engine >= 24.0
  - Docker Compose >= 2.20 (required for `include:` support)
  - Make (`make up`, `make health-check` are referenced in docs)
- **Step 2; configure env**:
  - In `apps/active/devops/localnet/`, create `.env` from the repo’s example (docs reference `.env.example`; there is also `env.template`).
  - Set at least: `HOST_IP`, `TIMEZONE`, plus any VPN creds if enabling VPN.
- **Step 3; start core stack**:
  - `make up`
  - `make health-check`
- **Step 4; enable more categories**:
  - In `docker-compose.localnet.yml`, some `include:` entries are commented out (example: `vpn`, `media`, `home`); enable intentionally.

## 🔧 How to execute the remediation work (intern workflow)
- **Phase A; pick the build strategy per service**:
  - **Preferred**: upstream image if widely supported and configurable (ports, volumes, gluetun integration).
  - **Preferred for qbittorrent**: docker-nix using nixpkgs `qbittorrent-enhanced`.
  - **Fallback**: docker-linux if upstream is insufficient and nix isn’t viable.
- **Phase B; regenerate and verify**:
  - Add `.copier-answers.yml`.
  - Re-materialize so there are no placeholders.
  - Run `docker compose config` on both:
    - The service’s standalone compose; and
    - `docker-compose.localnet.yml`.
- **Phase C; integrate**:
  - Add service definitions to the correct category compose file.
  - Confirm port collisions; confirm `gluetun` port exposure if service routes through it.

## ❓ questions
## ❓ answered questions
- **[⭐ Nix upgrade decision]** Upgrade Nix from **2.8.0** to **>= 2.18** so docker-nix can evaluate nixpkgs `25.11` for `qbittorrent-enhanced`
- **[⭐ Canonical qbittorrent location]** qBittorrent currently exists in `services/home/docker-compose.home.yml` (upstream linuxserver image) and also as an intended standalone service dir `services/file-xfer/qbittorrent`
	- canonical qbittorrent is file-xfer
- **[☑️ file-xfer category integration]** make a `services/file-xfer/docker-compose.file-xfer.yml`
- **[☑️ gluetun ownership + port list]** `services/vpn/docker-compose.vpn.yml` exposes ports for *many* media apps (radarr, sonarr, etc.);
	- Any service that uses any sort of torrent or usenet tool tracker in any way must live behind gluetun, my ISP does not allow inbound connections
- **[☑️ "golden fix" template choice]** For security, build minimal nix packages, that have a layer that doesnt' get deployed by default of all the debugging tools
- **[⚠️ Known bug to confirm]** `services/media/docker-compose.media.yml` has `TZ-${TIMEZONE}` (missing `=`); OBVIOUSLY FIX SYNTAX ERRORS WITHOUT ASKING ME

## ❓ Open questions (must answer to finish)
- **[⚠️ Docs mismatch]** `README.md` says no host mods needed, but `docs/README.md` says run `sudo ./scripts/setup-host.sh`; decide which is current truth (likely depends on transparent vs direct mode).

## ✅ "Done" checklist (intern final validation)
- **No placeholders remain** in `apps/active/devops/localnet/services`.
- **All enabled categories boot** via `docker-compose.localnet.yml`.
- **Health checks pass** for enabled services.
- **Secrets stay uncommitted**; only `.env` or secret tooling contains VPN keys/tokens.
- **A final report exists** listing any remaining services with missing/placeholder image references.
