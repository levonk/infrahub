# Local Watch Party

Synchronized movie watching with friends — self-hosted web app with real-time
playback sync, dual-language subtitles, and WebRTC voice chat.

Upstream: https://github.com/smSamani/Local-Watch-Party

## License

PolyForm Noncommercial License 1.0.0
Copyright (C) Soroush Mohammadi Samani (smSamani)

## Container

- **Image**: Locally built (multi-stage: node:20-alpine + ffmpeg)
- **Dockerfile**: `docker/Dockerfile.watch-party`
- **Container port**: 3001
- **Health check**: `GET /api/health`

## Source modifications

The upstream source has been patched to support configurable ICE servers for
WebRTC voice chat:

1. **`server/index.js`**: Added `GET /api/config` endpoint that returns ICE
   server config from the `ICE_SERVERS` env var (JSON array of RTCIceServer
   objects). Falls back to Google STUN if not configured.
2. **`src/App.jsx`**: Added `useEffect` to fetch ICE servers from `/api/config`
   on mount. The `RTCPeerConnection` now uses the fetched ICE servers instead
   of the hardcoded Google STUN server.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `3001` | Server listen port |
| `NODE_ENV` | — | Set to `production` to serve built frontend |
| `ICE_SERVERS` | `[]` | JSON array of RTCIceServer objects for WebRTC |

## Volumes

- `uploads/` — uploaded movie files (persistent)
- `hls-cache/` — HLS transcoding cache (persistent)

## Monitoring

- **Health endpoint**: `GET /api/health` → `{ ok: true, port, lanIps, hostname }`
- **Config endpoint**: `GET /api/config` → `{ iceServers: [...] }`
- **Pipeline**: none (standalone media service)
