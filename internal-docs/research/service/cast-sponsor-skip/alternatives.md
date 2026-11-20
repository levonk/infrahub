# Alternatives to CastSponsorSkip

Assessment for choosing a SponsorBlock-based skip service for the fleet. Date: 2026-11-07.

## Comparison

| Project | Status | Approach | Devices covered | Secrets | Verdict |
|---|---|---|---|---|---|
| **gabe565/CastSponsorSkip** | Active; v0.8.3 (2026-03-17); 366 commits; Renovate | mDNS discovery + Cast protocol seek/skip/mute | Google Cast devices running YouTube cast app | Optional YouTube API key | **Best fit** for Chromecast/Google TV fleet — tiny (≈10 MiB, ≈1 mCPU), zero-config, Docker + host net |
| **nichobi/sponsorblockcast** | **Archived 2023-08-21**; author: "superseded by CastSponsorSkip" | POSIX shell + go-chromecast + jq/bc | Chromecasts | None | Dead — do not use |
| **dmunozv04/iSponsorBlockTV** | Active; 6.7k★, 664 commits; Python | Pairs with YouTube **TV app** via lounge/screen-ID; remote-control API | Android TV, Google TV, Apple TV, Roku, Samsung Tizen, LG webOS, **and** Chromecast devices (paired mode) | **Mandatory** YouTube API key + per-device pairing/config file | Serious alternative. Covers far more device types, but heavier setup (device pairing wizard, config file, API key required) and subject to the same YouTube-side breakage (its "new screen ID format" incident, mid-2026). Choose if fleet includes Apple TV/Roku/smart-TV YouTube apps. |
| **CastBlock** (original) | Abandoned | Cast protocol | Chromecasts | None | Historical — inspired sponsorblockcast; superseded |
| SponsorBlock browser ext. / ReVanced / SmartTube | Active | Client-side | Browsers / Android phone / Android TV sideload | None | Not a service — per-client solutions; orthogonal, can coexist |

## Notes

- CastSponsorSkip was written explicitly to replace sponsorblockcast: ~75× lower CPU, 7× lower memory, privacy-preserving SponsorBlock endpoint, single static binary.
- CastSponsorSkip and iSponsorBlockTV **can coexist**: CSS auto-discovers Cast devices; iSponsorBlockTV pairs explicitly with TV YouTube apps. If the household has mixed device types, deploying both is a legitimate pattern.
- **Common fragility:** every tool in this space depends on YouTube not changing its cast/lounge behavior. Incidents observed in both CastSponsorSkip (#71, #202) and iSponsorBlockTV (screen-ID format change) — expect periodic breakage regardless of choice, and prefer tools with responsive maintainers (both qualify).

## Recommendation

Deploy **CastSponsorSkip** on the Docker host that sits on the same LAN/VLAN as the Cast devices, with `network_mode: host`, pinned to `ghcr.io/gabe565/castsponsorskip:0.8.3`. Provision a YouTube Data API v3 key in the vault if any Chromecast-with-Google-TV-type devices are present. Revisit iSponsorBlockTV only if non-Cast TV platforms need coverage.
