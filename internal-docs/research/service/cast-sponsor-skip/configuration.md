# CastSponsorSkip — Configuration Reference

Sources: `docs/envs.md`, `docs/castsponsorskip.md`, `internal/config/config.go` @ `main` (v0.8.3).

## Configuration Methods (precedence)

CLI flags > environment variables > config file. Any flag becomes an env by uppercasing, replacing `-` with `_`, prefixing `CSS_` (e.g. `--paused-interval=1m` → `CSS_PAUSED_INTERVAL=1m`). Config file path set with `--config` (YAML keys match flag names, e.g. `paused-interval:`).

Legacy `sponsorblockcast` env names are still accepted and log a deprecation warning with the new key — no removal planned.

## Complete Environment Variable Reference

| Env | Default | Description |
|---|---|---|
| `CSS_CATEGORIES` | `sponsor` | Comma-separated SponsorBlock categories to skip. Valid: `sponsor`, `selfpromo`, `interaction`, `intro`, `outro`, `preview`, `filler`, `music_offtopic` (see https://wiki.sponsor.ajay.app/w/Types#Category) |
| `CSS_ACTION_TYPES` | `skip,mute` | SponsorBlock action types to handle; short segments overlapping content can be muted instead of skipped |
| `CSS_SKIP_SPONSORS` | `true` | Master toggle for SponsorBlock segment skipping (if `false`, only YouTube ad handling runs) |
| `CSS_MUTE_ADS` | `true` | Mute device while an ad is playing |
| `CSS_YOUTUBE_API_KEY` | *(empty)* | YouTube Data API v3 key — fallback video-ID resolution; **required on devices that don't report video ID** (Chromecast with Google TV, some smart-TV cast apps) |
| `CSS_DEVICES` | *(empty)* | Comma-separated static device addresses (e.g. `192.168.1.10,192.168.1.11`). **Disables mDNS discovery entirely.** Only use if discovery fails. |
| `CSS_DISCOVER_INTERVAL` | `5m0s` | Interval to restart the mDNS discovery client (also re-announce cadence for static devices) |
| `CSS_PLAYING_INTERVAL` | `500ms` | Poll interval for Cast status while playing |
| `CSS_PAUSED_INTERVAL` | `1m0s` | Poll interval while paused/idle |
| `CSS_SKIP_DELAY` | `0s` | Delay before skipping into a segment |
| `CSS_IGNORE_SEGMENT_DURATION` | `1m0s` | After a skip, ignore the same segment for this long (lets you rewind to watch it) |
| `CSS_NETWORK_INTERFACE` | all interfaces | Pin one NIC for mDNS discovery (`-i` flag) — use on multi-homed hosts/VLAN setups |
| `CSS_LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error`, `none` |
| `CSS_LOG_FORMAT` | `auto` | `auto`, `color`, `plain`, `json` — use `json` for Loki/ELK ingestion |

## YouTube Data API v3 Key — Details

**When needed:** the Cast protocol normally reports the video ID in media status. On Chromecast with Google TV and some TV built-in cast targets only artist/title metadata is reported; the daemon then searches YouTube (`"artist" intitle:"title"`, `Search.list`) to resolve the ID before querying SponsorBlock. Logs `Video ID not set. Please configure a YouTube API key.` (or falls back to retries) without it.

**Quota math:** `search.list` = 100 units/call; default free quota = 10,000 units/day → ~100 resolved videos/day per key. Only incurred for devices lacking native video-ID reporting, and only once per new video.

**Provisioning:**
1. https://console.cloud.google.com → create/select project
2. APIs & Services → Library → enable **YouTube Data API v3**
3. Credentials → Create Credentials → **API key**
4. (Recommended) restrict key: API restrictions → YouTube Data API v3 only
5. Store as Ansible vault variable (suggest `vault_castsponsorskip_youtube_api_key`), inject as `CSS_YOUTUBE_API_KEY` env at deploy time

## Secrets Inventory

| Secret | Required | Notes |
|---|---|---|
| `CSS_YOUTUBE_API_KEY` | Conditional | Only if any Cast device fails to report video IDs. Sole secret; everything else is non-sensitive tuning. |

## Recommended Production Env Set

```yaml
environment:
  TZ: "{{ infra_timezone | default('UTC') }}"
  CSS_LOG_FORMAT: json
  CSS_CATEGORIES: "sponsor,selfpromo,interaction"   # tune to taste
  CSS_MUTE_ADS: "true"
  # CSS_YOUTUBE_API_KEY: "{{ vault_castsponsorskip_youtube_api_key }}"  # if needed
  # CSS_NETWORK_INTERFACE: "{{ infra_iface_iot }}"                     # if multi-homed
```
