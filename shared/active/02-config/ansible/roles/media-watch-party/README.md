# media-watch-party

Deploy [Local Watch Party](https://github.com/smSamani/Local-Watch-Party) — a self-hosted
web app for synchronized movie watching with friends, with real-time playback sync,
dual-language subtitles, and WebRTC voice chat.

## Container

- **Image**: Locally built (`localnet-media-watch-party`, multi-stage: node:20-alpine + ffmpeg)
- **Container port**: 3001
- **Health check**: `GET /api/health`
- **Volumes**: `uploads/` (persistent), `hls-cache/` (persistent)

## Traefik

- **Domain**: `watch.<base>` (e.g., `watch.levonk.com`)
- **Middleware**: Authelia SSO
- **Network**: `traefik-network`

## WebRTC / Voice Chat

The app uses WebRTC for voice chat. ICE servers (STUN+TURN) are configured via
the `ICE_SERVERS` env var, which is populated from the coturn role's credentials.

## Monitoring

- **Health endpoint**: `GET /api/health` → `{ ok: true, port, lanIps, hostname }`
- **Config endpoint**: `GET /api/config` → `{ iceServers: [...] }`
- **Pipeline**: none (standalone media service)

## License

PolyForm Noncommercial License 1.0.0 — Copyright (C) Soroush Mohammadi Samani (smSamani)
