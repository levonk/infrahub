# Local-Watch-Party Research

Research for deploying [Local-Watch-Party](https://github.com/smSamani/Local-Watch-Party) (aka "LAN Cinema") on the OCI ARM64 cloud server, accessible publicly via Traefik with Authelia SSO, with coturn for WebRTC voice chat.

---

## Architecture Summary

**Local-Watch-Party** is a Node.js/Express + React/Vite app for synchronized movie watching with friends.

- **Backend**: Single Express server (`server/index.js`, ~800 lines) that serves both the API and the built React frontend in production mode
- **Frontend**: React 18 SPA (`src/App.jsx`, ~1600 lines) built with Vite
- **Real-time sync**: Socket.IO for play/pause/seek synchronization
- **Voice chat**: WebRTC peer-to-peer mesh (RTCPeerConnection) with signaling over Socket.IO
- **Video streaming**: HTTP byte-range serving + HLS on-demand transcoding via FFmpeg
- **File uploads**: Multer diskStorage to `uploads/` directory
- **Public tunnel**: Optional Cloudflare tunnel via `cloudflared` (NOT used in our deployment — Traefik handles exposure)

### Single-process model

The server is a single Node.js process (`server/index.js`) that:
1. Creates an Express app + HTTP server
2. Attaches Socket.IO to the same HTTP server
3. In production mode (`NODE_ENV=production`), serves the built `dist/` directory
4. Listens on `0.0.0.0:PORT` (default 3001)

No separate frontend server — the Express app serves the built React assets in production.

---

## Port and Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `3001` | Server listen port |
| `NODE_ENV` | — | Set to `production` to serve built frontend from `dist/` |
| `PUBLIC_TUNNEL` | — | Set to `1` to start Cloudflare tunnel (NOT used — Traefik handles this) |

**No other env vars are read by the app.** The WebRTC STUN server is hardcoded in the frontend source.

---

## WebRTC / STUN / TURN Configuration

### Current state (hardcoded)

In `src/App.jsx:421`:
```js
const pc = new RTCPeerConnection({
  iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
});
```

Only Google's public STUN server is configured. No TURN server. This means:
- STUN works for peers behind simple NATs
- No relay fallback for peers behind symmetric NAT or strict firewalls
- Voice chat will fail for peers behind restrictive NATs

### Required patch

The app needs modification to support configurable ICE servers:

1. **Add `/api/config` endpoint** to `server/index.js` that returns ICE server config from env vars:
   ```js
   app.get("/api/config", (_req, res) => {
     res.json({
       iceServers: JSON.parse(process.env.ICE_SERVERS || "[]")
     });
   });
   ```

2. **Patch `src/App.jsx`** to fetch ICE servers from `/api/config` on startup and use them in `RTCPeerConnection`:
   ```js
   const [iceServers, setIceServers] = useState([{ urls: "stun:stun.l.google.com:19302" }]);
   useEffect(() => {
     fetch("/api/config").then(r => r.json()).then(c => {
       if (c.iceServers?.length) setIceServers(c.iceServers);
     }).catch(() => {});
   }, []);
   // Then in ensurePeerConnection:
   const pc = new RTCPeerConnection({ iceServers });
   ```

3. **Set `ICE_SERVERS` env var** in the container to include our coturn server:
   ```json
   [{"urls":"stun:watch.levonk.com:3487"},{"urls":"turn:watch.levonk.com:3487","username":"watchparty","credential":"SECRET"}]
   ```

### Alternative: window injection

Instead of an API endpoint, inject a `<script>` tag in `index.html` that sets `window.__ICE_SERVERS__`. Simpler but less flexible. The API endpoint approach is cleaner.

---

## Socket.IO Configuration

- **Path**: Default `/socket.io/` (no custom path)
- **CORS**: `cors: { origin: true, methods: ["GET", "POST"] }` — allows all origins
- **Transport**: WebSocket with polling fallback

### Reverse proxy notes

Socket.IO through Traefik works with standard HTTPS routing. No special configuration needed:
- WebSocket upgrade is handled by Traefik automatically
- No sticky sessions needed (single server instance)
- The `passHostHeader: true` in Traefik service config is sufficient

---

## File Uploads (Multer)

- **Storage**: `multer.diskStorage` to `uploads/` directory
- **Filename**: `${timestamp}-${randomHex}-${sanitizedOriginalName}`
- **Max file size**: No explicit limit in multer config. Express JSON body limit is 30mb but that applies to JSON bodies, not multipart uploads
- **Upload endpoint**: `POST /api/rooms/:roomId/media-upload` (multipart form, field name `movie`)

### Traefik body size limit

Traefik has no default body size limit for file uploads, but we should add `buffering` middleware with `maxRequestBodyBytes` to prevent abuse. For movie files, set a generous limit (e.g., 10GB) or rely on the app-level limit.

### Storage

Uploads go to `uploads/` and HLS segments to `hls-cache/`. Both need persistent volumes.

---

## FFmpeg / HLS Transcoding

- **Binary**: `ffmpeg` (via `spawn("ffmpeg", ...)`)
- **Usage**: On-demand HLS transcoding for browser compatibility (MKV → HLS segments)
- **Working directory**: `hls-cache/`
- **Segment duration**: 10 seconds (`HLS_SEGMENT_SECONDS = 10`)
- **Pre-generated segments**: 3 ahead (`HLS_AHEAD_SEGMENTS = 3`)

### Container requirement

The container MUST have `ffmpeg` installed. Use a multi-stage Dockerfile:
- Build stage: Node.js with npm to build the frontend
- Runtime stage: Node.js slim + ffmpeg

---

## Health Check

**Endpoint**: `GET /api/health`

**Response**:
```json
{
  "ok": true,
  "port": 3001,
  "lanIps": ["..."],
  "hostname": "...",
  "publicUrl": null
}
```

This is a proper health check endpoint. Use `curl -fsS http://127.0.0.1:3001/api/health` for container healthcheck.

---

## Dockerfile Strategy

### Multi-stage build (mandatory per AGENTS.md Invariant #2)

```dockerfile
# Stage 1: Build frontend
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Runtime
FROM node:20-alpine AS runtime
RUN apk add --no-cache ffmpeg
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
COPY server/ ./server/
EXPOSE 3001
CMD ["npm", "start"]
```

### Architecture support

- `node:20-alpine` supports both `amd64` and `arm64`
- `ffmpeg` from Alpine packages supports both architectures
- Build with `docker buildx` for multi-arch (mandatory per `container-image-build` skill)

### Volumes

- `uploads/` — uploaded movie files (persistent)
- `hls-cache/` — HLS transcoding cache (can be ephemeral, but persistent avoids re-transcoding)

---

## Security Considerations

### No built-in authentication

The app has NO authentication. Anyone with the URL can:
- Create rooms
- Upload files
- Join any room
- Access voice chat

**Mitigation**: Authelia SSO middleware in Traefik. All access requires Authelia login.

### CORS wide open

`cors: { origin: true }` allows all origins. Behind Traefik with Authelia, this is less of a concern, but ideally should be restricted to the configured domain.

### File upload abuse

No file size limit. A malicious user (post-auth) could upload very large files and fill disk.
**Mitigation**: Add Traefik buffering middleware with max body size, or patch the app to add a multer file size limit.

### FFmpeg resource usage

Transcoding is CPU-intensive. On the OCI ARM64 host, this could impact other services.
**Mitigation**: Add Docker resource limits (CPU/memory) to the container.

### WebRTC IP leakage

WebRTC reveals local IP addresses to peers. Behind Authelia, only authenticated users see this, but it's worth noting.

---

## License

**PolyForm Noncommercial License 1.0.0**

- Noncommercial use only
- Required attribution: "Copyright © Soroush Mohammadi Samani (smSamani)"
- Attribution must remain with every copy, modified version, and redistribution

Since this is a personal/friends deployment (noncommercial), the license permits use. The attribution must be preserved in the source code and any documentation.

---

## Deployment Summary

| Aspect | Value |
|--------|-------|
| **Image** | Locally built (multi-stage, node:20-alpine + ffmpeg) |
| **Architecture** | arm64 (OCI) + amd64 (if needed) |
| **Container port** | 3001 |
| **Host port** | 3137 (free in port allocation) |
| **Domain** | `watch.levonk.com` |
| **Traefik** | Yes — standard dynamic config with Authelia middleware |
| **Auth** | Authelia SSO |
| **Health check** | `GET /api/health` |
| **Volumes** | `uploads/` (persistent), `hls-cache/` (persistent) |
| **Env vars** | `PORT=3001`, `NODE_ENV=production`, `ICE_SERVERS=<JSON>` |
| **Secrets** | coturn credential (in vault) |
| **Source patch** | Add `/api/config` endpoint + patch `src/App.jsx` iceServers |

### Companion service: coturn

| Aspect | Value |
|--------|-------|
| **Image** | `coturn/coturn:4.17.2-alpine` (upstream, multi-arch) |
| **STUN/TURN port** | 3487 (host) → 3478 (container) — 3478 is taken by NetBird |
| **Relay port range** | 49000-49050 UDP (50 ports, sufficient for 5-10 users) |
| **Config** | `turnserver.conf` with static user credentials |
| **Secrets** | `vault_media_watch_party_turn_password` |
| **Traefik** | No — direct port exposure (UDP relay incompatible with Traefik) |
| **Firewall** | Open 3487/tcp+udp and 49000-49050/udp on public zone |
