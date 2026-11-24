---
# Product Requirements Document (PRD)

feature_slug: cast-sponsor-skip
created: 2026-11-07
completed:
last-activity: 2026-11-12
status: todo
tech_context:
  package_manager: devbox/just        # infrahub repo
  deploy_tool: ansible                # community.docker via podman compat socket
  target_host: minime01               # RPi2 DietPi, armv7, 192.168.12.234
  container_runtime: podman           # rootful, /run/docker.sock compat symlink
  upstream_image: ghcr.io/gabe565/castsponsorskip:0.8.3   # multi-arch incl. armv7
  never_use: [docker compose, source: build, hardcoded IPs/ports, Traefik domain]
---

# Product Requirements Document (PRD)

## Introduction / Overview

- **Feature name:** CastSponsorSkip deployment on minime01
- **Summary:** Run [CastSponsorSkip](https://github.com/gabe565/CastSponsorSkip)
  (gabe565) as a host-networked container on `minime01` (Raspberry Pi 2,
  DietPi Trixie, armv7, `192.168.12.234`) so YouTube videos cast to Google
  Cast devices get sponsor segments skipped (SponsorBlock) and ads muted.
- **Context:**
  - Requires real `network_mode: host` — mDNS `_googlecast._tcp` discovery
    (UDP 5353 → 224.0.0.251) does not traverse container NAT. Excludes
    Docker Desktop targets (dtop202311) and the OCI cloud server (no LAN).
  - minime01 runs **Podman**, not Docker — the `container-podman` role
    provides the runtime plus a `/run/docker.sock` → `/run/podman/podman.sock`
    compat symlink so `community.docker` modules work unchanged.
  - A container was first deployed manually on 2026-11-14; this feature
    brings it under Ansible management (PR #34, commit `1085eea1`).
  - Research: `internal-docs/research/service/cast-sponsor-skip/`
    (overview, configuration, alternatives).

## Goals

- `cast-sponsor-skip` container running on minime01 via
  `deploy-cast-sponsor-skip.yml` (`--limit minime01`), adopted idempotently
  by `community.docker` through the podman compat socket.
- Env parity with the manual deployment: `CSS_ACTION_TYPES=skip,mute`,
  `CSS_MUTE_ADS=true`, `CSS_CATEGORIES=sponsor,selfpromo,interaction`,
  `CSS_LOG_FORMAT=json`, `CSS_LOG_LEVEL=info`, `TZ=UTC`; optional
  `CSS_YOUTUBE_API_KEY` fed from `vault_castsponsorskip_youtube_api_key`.
- Service cataloged in `services.yml` (machine `minime01`, no Traefik —
  internal headless daemon, no ports, no domain).
- `levonk-deploy-cast-sponsor-skip{,-check}` just recipes.

## Non-Goals

- No public domain, no Traefik router, no DNS record, no published ports.
- No persistent volumes (service is stateless).
- No metrics endpoint (upstream exposes none; health = `pidof` healthcheck).
- No backup job (no stateful data).
- No changes to kccinai/dtop202311/OCI.

## Requirements

- FR-1: Podman installed + API socket + docker.sock compat on minime01
  (`container-podman` role, Debian-family only).
- FR-2: `media-cast-sponsor-skip` role deploys the upstream image with
  `network_mode: host`, `restart_policy: always`, `pidof` healthcheck,
  json-file logs, optional 128m memory cap (skipped when the kernel cgroup
  memory controller is disabled — DietPi ships `cgroup_disable=memory`).
- FR-3: All tuning via env vars with empty-means-omit semantics
  (`CSS_DEVICES`, `CSS_NETWORK_INTERFACE`, intervals, `CSS_SKIP_DELAY`).
- FR-4: Catalog entry + regenerated `SERVICES.md` (client) and repo-root
  `SERVICES.md`.
- FR-5: Vault handoff for optional `vault_castsponsorskip_youtube_api_key`
  (only needed for Chromecast-with-Google-TV devices that don't report
  video IDs over the Cast protocol).

## Known Issues / Open Questions

- **Device discovery**: the container logs show zero discovered devices.
  mDNS probes from both this Mac and minime01 on `192.168.12.0/24` find no
  `_googlecast._tcp` devices — the Chromecasts appear to be on a different
  L2 segment/VLAN than the Pi. Resolution requires either moving a host
  onto the cast segment, an mDNS reflector, or `CSS_DEVICES` static IPs
  (which still need L2 reachability for the Cast control protocol on
  TCP 8009). Confirm which VLAN/SSID the cast devices use.
- kckinai (the other LAN Docker host) is offline and on `192.168.2.x` —
  not a fallback target.

## Vault Handoff

Optional secret — only if cast devices need the YouTube Data API v3
fallback lookup:

```bash
scripts/edit-vault.sh
# add: vault_castsponsorskip_youtube_api_key: "<YouTube Data API v3 key>"
```

Create the key: Google Cloud Console → enable **YouTube Data API v3** →
Credentials → Create API key. Quota: 10,000 units/day free; each fallback
lookup costs 100.
