# CastSponsorSkip — Service Research & Deployment Requirements

> Research date: 2026-11-07
> Upstream: https://github.com/gabe565/CastSponsorSkip
> Latest release: **v0.8.3** (2026-03-17) — actively maintained, 366 commits, ~559 stars, single primary maintainer with Renovate-driven dependency updates.

## What It Does

CastSponsorSkip is a single-binary Go daemon that watches **all Google Cast devices on the local LAN** and:

1. **Skips sponsored segments** in YouTube videos — when a Cast device plays a YouTube video, it fetches segment data from the [SponsorBlock](https://sponsor.ajay.app) API and sends a *seek* command to the device when playback reaches a sponsored segment. It uses SponsorBlock's privacy-enhanced endpoint (video ID is SHA-256 hashed; only the first 4 hash chars are sent, so SponsorBlock never learns which video is playing).
2. **Skips skippable YouTube ads** — detects ad breaks and presses the skip button when it becomes available.
3. **Mutes ads** (default on, `CSS_MUTE_ADS=true`) — mutes device volume for the duration of ad breaks, including non-skippable ads.

### Supported apps / devices

- **Only the YouTube app on devices that speak the Google Cast protocol**: Chromecast (all gens), Chromecast with Google TV, Google TV / Android TV streamers and TVs, Google Home / Nest speakers and displays. Anything discoverable via `_googlecast._tcp` mDNS.
- **Not supported**: other streaming apps (Netflix, Tubi, etc. — confirmed out of scope in issue #152), YouTube played in a browser, Apple TV / Roku / Fire TV native apps (those use different protocols — see iSponsorBlockTV in [alternatives.md](alternatives.md)).
- Ad muting/skipping only works while the Cast YouTube app reports ad state; only *skippable* ads can actually be skipped — unskippable ads are merely muted.

## Container Image

| Property | Value |
|---|---|
| Registry / path | `ghcr.io/gabe565/castsponsorskip` (GHCR only — **no Docker Hub image**) |
| Tags | `latest`, `0.8.3`, `0.8`, `0` (semver rolling tags), plus per-arch tags `0.8.3-amd64`, `-armv6`, `-armv7`, `-arm64v8` |
| Architectures | `linux/amd64`, `linux/arm64`, `linux/arm/v6`, `linux/arm/v7` (multi-arch manifest) |
| Base / size | `alpine:3.23.3` + static Go binary (~6.5 MB binary → image est. ~15–20 MB). Scratch-of-light size. |
| User | Runs as non-root UID/GID `1000` (`castsponsorskip` user) |
| Entrypoint | `CMD ["./castsponsorskip"]` from `/app` |
| Digest (0.8.3 manifest) | `sha256:f556d274aab94c3140058e9f192396bc75e04d8e075769223c1edfc8c4f4daa4` |

**Recommended pin:** `ghcr.io/gabe565/castsponsorskip:0.8.3` (or `:0.8` for minor auto-updates via watchtower-style tooling).

## Required Configuration

**None.** The container works zero-config: it discovers every Cast device on the LAN and skips the `sponsor` category.

See [configuration.md](configuration.md) for the complete env/flag/config-file reference. Notable knobs:

| Env | Default | Purpose |
|---|---|---|
| `CSS_CATEGORIES` | `sponsor` | SponsorBlock categories to skip (add e.g. `selfpromo,interaction,intro,outro`) |
| `CSS_YOUTUBE_API_KEY` | *(empty)* | YouTube Data API v3 key — **optional fallback** for devices that don't report a video ID over the Cast protocol (notably Chromecast with Google TV). Without it those devices log `Video ID not set` and sponsor-skipping won't work for them (ad muting/skipping still does). |
| `CSS_MUTE_ADS` | `true` | Mute device during ads |
| `CSS_DEVICES` | `[]` | Static device IP list — disables mDNS discovery entirely |
| `CSS_PLAYING_INTERVAL` / `CSS_PAUSED_INTERVAL` | `500ms` / `1m` | Device status poll cadence |
| `CSS_LOG_FORMAT` / `CSS_LOG_LEVEL` | `auto` / `info` | `json` format available for log aggregation |

### YouTube Data API v3 key (the only possible secret)

- **Required?** No — only needed if your Cast device doesn't expose the video ID. Chromecast with Google TV and some smart-TV YouTube cast apps only report artist+title metadata; the daemon then falls back to a YouTube `Search.list` query (`"artist" intitle:"title"`) to resolve the video ID (see `internal/youtube/youtube.go`).
- **Quota:** each lookup costs **100 quota units**; free tier is 10,000 units/day (~100 video lookups/day). Sufficient for typical households but monitor if many devices/videos.
- **How to obtain:** Google Cloud Console → create/select project → *APIs & Services → Library* → enable **YouTube Data API v3** → *Credentials → Create Credentials → API key*. Restrict the key to the YouTube Data API v3. (Upstream link: https://developers.google.com/youtube/registering_an_application)
- **Storage:** this is the only credential — store as an Ansible vault variable (e.g. `vault_castsponsorskip_youtube_api_key`) and inject via `CSS_YOUTUBE_API_KEY`. Do **not** commit it. Upstream issue #66 shows a user leaking one in an issue — treat as a real secret.

## Networking

| Aspect | Requirement |
|---|---|
| **Network mode** | **`network_mode: host` is effectively mandatory.** Device discovery uses mDNS multicast (`_googlecast._tcp`, UDP 5353 → 224.0.0.251), which does not traverse Docker's NAT. |
| **LAN/VLAN placement** | The container **must be on the same L2 broadcast/multicast domain as the Cast devices** (or on a network where an mDNS reflector, e.g. Avahi, relays `_googlecast._tcp`). If Chromecasts live on an IoT VLAN, run the container on a host interface/VLAN that can receive that multicast, or set `CSS_NETWORK_INTERFACE` to pin the interface. Discovery over VPN does not work (issue #79). |
| **Outbound to devices** | TCP **8009** to each Cast device (Google Cast control protocol via `go-chromecast`). Firewalls between server and devices must allow this. |
| **Outbound to internet** | HTTPS to `sponsor.ajay.app` (SponsorBlock API) on every video; HTTPS to `googleapis.com` only if a YouTube API key is configured. |
| **Listening ports** | **None.** No web UI, no API, no metrics endpoint, no health endpoint. |
| **Partial alternative to host mode** | With `CSS_DEVICES=<ip1,ip2,...>` discovery is skipped entirely; only outbound TCP 8009 is needed, so a bridge/macvlan network *could* work — but upstream docs still say `host` and static IPs for Chromecasts are fragile (DHCP). Prefer host networking. |

## Runtime Behavior

- Discovery: mDNS browse restarted every `CSS_DISCOVER_INTERVAL` (5 min); new devices picked up automatically.
- Polling: per-device status poll every **500 ms while playing**, **1 min while paused/idle** — deliberately lightweight.
- Resource use (author benchmark, 12 Cast devices): **~1 mCPU, ~10 MiB RAM** — vs. 75 mCPU / 70 MiB for the original sponsorblockcast shell script. Safe to run unconstrained; a `memory: 128M` limit is generous.
- Stateless: no volumes, no persistence. `restart: always`/`unless-stopped` appropriate.
- Logging: slog to stdout; `CSS_LOG_FORMAT=json`, `CSS_LOG_LEVEL=debug|info|warn|error|none`.
- **No Prometheus metrics, no `/healthz`, no web endpoint.**

## Health Check Options (no HTTP endpoint)

The Alpine image ships busybox, so these work inside the container:

```yaml
healthcheck:
  test: ["CMD", "pidof", "castsponsorskip"]
  interval: 60s
  timeout: 5s
  retries: 3
  start_period: 10s
```

Notes:
- `pidof`/`pgrep` only proves the process lives — it can't detect a deadlocked discovery loop. A pragmatic deep check is grepping recent log output, but that's not feasible in a `HEALTHCHECK`; rely on `pidof` + `restart: unless-stopped`.
- External monitoring: point uptime monitoring (e.g. Uptime Kuma "Docker container" monitor) at the container, or alert on absence of log lines such as `Connected to cast device` / recurring discovery errors.
- There is no readiness concept — it connects to devices lazily as they appear.

## Gotchas

- **Chromecast with Google TV / smart-TV YouTube cast apps** often don't report the video ID → `Video ID not set. Please configure a YouTube API key.` (issues #66, #112). Plan to provision `CSS_YOUTUBE_API_KEY` from the start if the fleet includes these.
- **YouTube app changes break detection periodically.** Issue #202 (Apr–May 2026): YouTube app v7.03.300 reported "Idle" while playing → skips stopped working until YouTube-side fix; resolved itself. Similar incident in issue #71 (2024). This is an inherent cat-and-mouse dependency — monitor after YouTube app updates.
- **`CSS_DEVICES` quirks:** setting it disables all discovery; an empty/whitespace value caused parse errors before v0.8.3 (fixed, issue #153). Don't set it at all unless needed.
- **TV power-off:** historically caused a panic requiring restart (#47, closed 2023); `restart: always` covers residual cases.
- **Ad edge cases:** issue #78 (open) — "when ad plays it skips back to end of first segment." Occasional seek weirdness possible.
- **mDNS + Docker:** `network_mode: host` on a multi-homed host may pick the wrong interface — use `CSS_NETWORK_INTERFACE`/`--network-interface` to pin it. IPv6 interface failures fixed in #54.
- **License note:** repo is tagged Apache-2.0, but goreleaser package metadata says GPL-3.0 — cosmetic upstream inconsistency, no practical impact.
- **SponsorBlock categories default is `sponsor` only** — most deployments will want to widen it (e.g. `sponsor,selfpromo,interaction`).

## Alternatives Assessment — TL;DR

**CastSponsorSkip is the right choice for this fleet** if the target devices are Chromecasts / Google Cast receivers. See [alternatives.md](alternatives.md) for the full comparison.

- `nichobi/sponsorblockcast` — **archived 2023-08**, author redirects to CastSponsorSkip.
- `dmunozv04/iSponsorBlockTV` — the serious alternative (6.7k★, Python): covers Android TV, Apple TV, Roku, Samsung/LG, **and** Chromecasts by pairing with the YouTube TV app's lounge/screen-ID. Heavier, needs per-device pairing + YouTube API key mandatory, and also suffers YouTube-side breakage (see its "new screen ID format" wiki). Choose it only if the fleet includes non-Cast TV platforms; the two can coexist.
- CastBlock — the abandoned predecessor of sponsorblockcast.

Last upstream release v0.8.3 (2026-03-17); commits and Renovate dependency PRs are active through mid/late-2026. Maintenance is single-maintainer but responsive (issue triage visible, e.g. #202, #177).

## Sample Compose (upstream)

```yaml
services:
  castsponsorskip:
    image: ghcr.io/gabe565/castsponsorskip:0.8.3
    network_mode: host
    restart: always
    environment:
      TZ: UTC
      # CSS_YOUTUBE_API_KEY:   # from vault, if needed
      # CSS_CATEGORIES: sponsor,selfpromo
    healthcheck:
      test: ["CMD", "pidof", "castsponsorskip"]
      interval: 60s
      timeout: 5s
      retries: 3
```

## Sources

- README: https://github.com/gabe565/CastSponsorSkip (raw)
- Env reference: `docs/envs.md`; CLI reference: `docs/castsponsorskip.md`
- `Dockerfile`, `docker-compose.yaml`, `.goreleaser.yaml` (tags/arches)
- GHCR package page: https://github.com/gabe565/CastSponsorSkip/pkgs/container/castsponsorskip
- Issues reviewed: #46, #47, #54, #66, #71, #78, #79, #112, #152, #153, #202
- Source reviewed: `internal/config/config.go`, `internal/device/dns.go`, `internal/youtube/youtube.go`, `main.go`
