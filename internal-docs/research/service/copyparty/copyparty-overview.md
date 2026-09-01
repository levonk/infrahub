# copyparty — Research Overview

**Citations are to URLs fetched from the upstream repo, Docker Hub, and community docs.**

## 1. What it is

copyparty is a portable, Python-based self-hosted **file sharing / file server**. It turns almost any device into an HTTP(S) file server with resumable chunked uploads, deduplication, media indexing/thumbnails, search, WebDAV, and several other protocols (SFTP, FTP/FTPS, TFTP, SMB/CIFS). It can be distributed as a single-file `copyparty-sfx.py`, a PyPI package, or as an official Docker image.

*Category:* HTTP file server / personal file sharing hub.
*Primary purpose:* Make local directories browsable and uploadable through a web UI and standard file-transfer protocols.

Sources:
- https://github.com/9001/copyparty
- https://pypi.org/project/copyparty/

## 2. Upstream image

copyparty publishes **official multi-arch Docker images** on both Docker Hub and the GitHub Container Registry (GHCR).

| Edition | Docker Hub | GHCR | Approx. size (uncompressed / gz) |
|---------|------------|------|----------------------------------|
| `min`   | `copyparty/min`   | `ghcr.io/9001/copyparty-min`   | ~57 MiB / ~20 MiB |
| `im`    | `copyparty/im`    | `ghcr.io/9001/copyparty-im`    | ~70 MiB / ~25 MiB |
| `ac`    | `copyparty/ac`    | `ghcr.io/9001/copyparty-ac`    | ~163 MiB / ~56 MiB |
| `iv`    | `copyparty/iv`    | `ghcr.io/9001/copyparty-iv`    | ~211 MiB / ~73 MiB |
| `dj`    | `copyparty/dj`    | `ghcr.io/9001/copyparty-dj`    | ~309 MiB / ~104 MiB |

- **Recommended image for most users:** `copyparty/ac` or `ghcr.io/9001/copyparty-ac`.
- **Tags:** `latest`, `beta`, and version-tagged releases.
- **Multi-arch support (min/im/ac):** `x86`, `x86_64`, `armhf`, `aarch64`, `ppc64le`, `s390x`. `iv` and `dj` are limited to `x86_64` and `aarch64` (and `x86`/`armhf` for `iv` per docs).
- **Dockerfile in repo:** `scripts/docker/Dockerfile.*` (e.g. `Dockerfile.min`, `Dockerfile.ac`) built on `alpine:latest`.
  - https://github.com/9001/copyparty/tree/hovudstraum/scripts/docker
  - https://github.com/9001/copyparty/blob/8c7cdf85/scripts/docker/Dockerfile.min
  - https://hub.docker.com/r/copyparty/ac

## 3. Ports

- **HTTP/HTTPS default:** `3923` (TCP).
- Optional protocol ports (all default-disabled except HTTP):
  - FTP: `3921`
  - SFTP: `3922`
  - FTPS: `3990`
  - TFTP: `69` (UDP) and `3969` (UDP)
  - SMB/CIFS: `3945`
  - mDNS: `5353` (UDP)
  - SSDP: `1900` (UDP)
  - Passive FTP range: `12000-12099`
- Ports are configurable via `-p <ports>` or the `p:` global config setting.

Sources:
- https://github.com/9001/copyparty
- https://mintlify.wiki/9001/copyparty/cli/copyparty

## 4. Configuration

copyparty is configured through a combination of:

1. **CLI flags** (highest priority)
2. **Config file(s)** loaded with `-c <file>` or the `PRTY_CONFIG` environment variable
3. **Environment variables** such as `PRTY_CONFIG`, `XDG_CONFIG_HOME`, `PRTY_NO_TLS`, `LD_PRELOAD`, `TZ`, `PYTHONUNBUFFERED`

Config file format uses pseudo-YAML sections:

```yaml
[global]
  p: 3923
  e2dsa  # enable file indexing
  e2ts   # enable media tag indexing
  hist: /cfg/hists

[accounts]
  admin: yourpassword

[/]
  /w
  accs:
    r: *
    rwmda: admin
```

- `[global]` section = CLI flag equivalents.
- Inline comments require **two spaces before `#`**.
- Volume sections are declared with `[/urlpath]`.
- `PRTY_CONFIG` can point to the default config file.
- The `XDG_CONFIG_HOME=/cfg` env var is set in the Dockerfiles, so `/cfg/*.conf` is the typical container config location.

Sources:
- https://github.com/9001/copyparty/blob/8c7cdf85/copyparty/__main__.py (PRTY_CONFIG, XDG_CONFIG_HOME)
- https://mintlify.wiki/9001/copyparty/config/server-setup
- https://github.com/9001/copyparty/blob/hovudstraum/docs/examples/docker/basic-docker-compose/docker-compose.yml

## 5. Volumes / data

Inside the container:

| Container path | Purpose | Notes |
|----------------|---------|-------|
| `/w`           | Default shared data folder | Mount the host directory you want to serve. |
| `/cfg`         | Config files (`.conf`) | Optional; set via `-v ./config:/cfg` and `XDG_CONFIG_HOME`. |
| `/state`       | Working directory in newer images | Not usually bind-mounted. |
| `.hist/` (inside each volume by default) | SQLite index, thumbnails, audio transcodes, markdown history | Created automatically in each served directory unless `hist:` is overridden. |

To avoid `.hist` folders being created in every shared volume, set a global `hist:` path in `[global]` (e.g. `hist: /cfg/hists`). For just the DB, use `dbpath:`.

Sources:
- https://github.com/9001/copyparty#database-location
- https://mintlify.wiki/9001/copyparty/config/server-setup

## 6. Authentication

- **Built-in basic username/password auth** with per-volume permissions.
- **Multi-user / multi-volume permissions** via `[accounts]` and `accs:` blocks.
- **Groups** (`@su`, `@acct`, etc.).
- **IP-based auto-login** (`ipa:`).
- **Password hashing** with `--ah-alg argon2` or bcrypt.
- **External IdP / reverse-proxy auth** via headers: `X-IdP-User`, `X-IdP-Group` (or custom header names) and optionally a secret header `idp-h-key`.
- **OAuth/OIDC/LDAP/SAML** are supported *via a reverse proxy / middleware* (e.g. Authelia, Authentik, Keycloak) that sends headers to copyparty, plus some direct `--idp github` / `--idp oidc,…` support.

Sources:
- https://github.com/9001/copyparty/blob/hovudstraum/docs/idp.md
- https://mintlify.wiki/9001/copyparty/guides/authentication
- https://github.com/9001/copyparty/blob/hovudstraum/docs/examples/docker/idp/copyparty.conf

## 7. Reverse proxy / Traefik compatibility

copyparty works well behind a reverse proxy.

Important settings:

| Config | Meaning |
|--------|---------|
| `xff-hdr: X-Forwarded-For` | Header to read real client IP from. |
| `xff-src: lan` or `192.168.x.x` | CIDR of trusted reverse proxies. |
| `rproxy: 1` | How many proxies in front (or `-1` for closest). |
| `rp-loc: /files` | Base URL path when proxying under a subpath. |
| `i: 127.0.0.1` or `unix:770:www:/dev/shm/party.sock` | Bind to localhost or a Unix socket so it is not reachable directly. |

For **Traefik**:
- Use normal Docker labels to route to the copyparty container on port `3923`.
- The repo includes a Traefik static config example at `contrib/traefik/copyparty.yaml`.
- A full Authelia/Authentik + Traefik + copyparty docker-compose example is in `docs/examples/docker/idp-authelia-traefik/` and `idp-authentik-traefik/`.
- Disable buffering on the proxy for large uploads; pass `X-Forwarded-For`, `X-Forwarded-Proto`, and `Host` headers.

Sources:
- https://github.com/9001/copyparty/blob/8c7cdf85/docs/xff.md
- https://github.com/9001/copyparty/blob/hovudstraum/contrib/traefik/copyparty.yaml
- https://github.com/9001/copyparty/blob/8c7cdf85/docs/examples/docker/idp-authelia-traefik/docker-compose.yml

## 8. Secrets

- **Admin/user passwords:** placed in config under `[accounts]`. Can be plaintext or hashed (`$argon2id$…` / `$2b$…`).
- **TLS certificate and key** (optional) when using `--cert` / `--key` and HTTPS.
- **IdP shared secret:** optional `idp-h-key` header name for reverse-proxy trust.
- **Volume `filekey`/`dirkey` keys:** per-volume URL access keys (managed by copyparty, stored in `.hist`).
- No dedicated secret-mount convention; secrets are in the config file or certificate files.

Sources:
- https://mintlify.wiki/9001/copyparty/deployment/security
- https://github.com/9001/copyparty/blob/hovudstraum/docs/examples/docker/idp/copyparty.conf

## 9. Health check

copyparty does **not** expose a dedicated `/health` endpoint by default. Recommended checks:

- Simple liveness: `GET /` on `http://localhost:3923/`. Returns `200` when the server is up (or `401` if authentication is required).
- If `--stats` is enabled, `GET /.cpr/metrics` returns OpenMetrics/Prometheus data, but it requires an admin or `stats-u` user; not ideal for a plain liveness probe.
- Example Dockerfile/Compose healthcheck:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3923/ >/dev/null 2>&1 || exit 1
```

If the root volume is read-protected, the probe will need a valid `?pw=` or basic-auth header.

Sources:
- https://github.com/9001/copyparty/issues/49 (metrics endpoint)
- https://copyparty/metrics.py (OpenMetrics `/.cpr/metrics`)
- https://docs.klutch.sh/guides/open-source-software/copyparty/ (example healthcheck)

## 10. Resource footprint

- **Image size:** `min` ~57 MiB (20 MiB gz); `ac` ~163 MiB (56 MiB gz).
- **Idle RAM:** roughly 27–57 MiB depending on edition and indexing options.
- **Spikes:** thumbnail / transcoding (especially video, animated AVIF, RAW images) can consume significant RAM and CPU. Example reported: animated AVIF thumbnail used ~7 GB.
- **CPU:** generally low except during indexing/transcoding.
- **Tips:** `LD_PRELOAD: /usr/lib/libmimalloc-secure.so.2` can improve speed at the cost of ~2× RAM.

Sources:
- https://hub.docker.com/r/copyparty/ac
- https://github.com/9001/copyparty/blob/8c7cdf85/scripts/docker/README.md
- https://github.com/9001/copyparty/discussions/1310
- https://github.com/9001/copyparty/issues/1556

## 11. Maintenance / activity

- **Latest release:** `v1.20.21` (published 2026-08-17).
- **Release cadence:** very active; ~1–2 releases per month, with near-weekly builds for `beta`.
- **License:** MIT.
- **GitHub stars:** ~46,000.
- **Open issues:** ~254 (per GitHub header at time of fetch).
- **Maintainer responsiveness:** single primary maintainer (`ed` / `9001`), very active, quick bugfixes and security releases (e.g. FTP vuln fixed in v1.20.19, 2026-07-27).

Sources:
- https://github.com/9001/copyparty
- https://github.com/9001/copyparty/releases

## 12. Licensing

- **MIT License** — permissive, free for personal and commercial use, with the standard MIT attribution requirement.
- https://github.com/9001/copyparty/blob/HEAD/LICENSE

## 13. Notable features

- Resumable, chunked, multithreaded uploads via `up2k`.
- Content-addressable deduplication (symlink / hardlink / reflink) with `--e2dsa --dedup`.
- WebDAV, SFTP, FTP/FTPS, TFTP, SMB/CIFS support.
- In-browser media gallery, image/video/audio thumbnails, audio transcoding.
- Full-text and metadata search, including ID3/EXIF.
- "Unpost" (undo upload), write-only folders, self-destruct links, file URL keys.
- mDNS/SSDP/UPnP, QR code, Android app / iOS Shortcuts.
- Prometheus/OpenMetrics endpoint (`--stats` → `/.cpr/metrics`).
- Cross-platform: Windows, Linux, macOS, Android, iOS, FreeBSD, ARM, PPC, s390x.

Sources:
- https://github.com/9001/copyparty
- https://github.com/9001/copyparty/issues/49

## 14. Deployment gotchas

1. **Default is wide open.** `copyparty` with no config gives everyone read/write access to `/w`. Add `[accounts]` and `accs:` blocks before exposing to a network.
2. **Run as a matching UID/GID.** Set `user: "1000:1000"` (or your host owner). The image does **not** use `PUID`/`PGID` env vars; the process runs as the container user you specify.
3. **SELinux:** append `:z` to volume mounts when running on SELinux-enabled hosts.
4. **Rootless Podman:** the docs say to remove the `-u 1000` option when running rootless.
5. **Stop grace period:** `stop_grace_period: 15s` is recommended because thumbnailer child processes need time to finish.
6. **`.hist` placement:** do not put the SQLite index/thumbnails on a network/SMB/NFS share; use `hist:` or `dbpath:` to keep them on local storage.
7. **mimalloc:** set `LD_PRELOAD: /usr/lib/libmimalloc-secure.so.2` for a speed boost at the cost of more RAM; `…NOPE` disables it.
8. **Reverse-proxy path prefix:** if proxying under a subpath, use `--rp-loc` and be careful not to strip the prefix.
9. **Subdomain proxying is recommended** over subpath; Unix sockets are faster than TCP.
10. **Unix socket permissions:** when using `-i unix:770:www:/dev/shm/party.sock`, ensure the reverse-proxy user is in the `www` group.

Sources:
- https://github.com/9001/copyparty/blob/hovudstraum/scripts/docker/README.md
- https://github.com/9001/copyparty/blob/8c7cdf85/docs/examples/docker/basic-docker-compose/docker-compose.yml
- https://github.com/9001/copyparty/blob/8c7cdf85/docs/xff.md
- https://github.com/9001/copyparty/blob/hovudstraum/contrib/traefik/copyparty.yaml

## Concise summary for the orchestrator

- **Image:** `copyparty/ac:latest` (or `ghcr.io/9001/copyparty-ac:latest`). Multi-arch.
- **HTTP port:** `3923` TCP.
- **Container volumes to mount:**
  - `/w` — data/shared files (default share root)
  - `/cfg` — optional config files (`*.conf`)
- **Config:** config file(s) in `/cfg`, or `PRTY_CONFIG`, or CLI flags; main sections are `[global]`, `[accounts]`, and per-volume blocks.
- **Secrets:** admin/user passwords in the config file (`[accounts]`); TLS certs if using HTTPS; optional IdP secret header.
- **Auth:** built-in basic auth, groups, IP-based auth, plus reverse-proxy/IdP header auth (supports Authelia/Authentik/Keycloak/OAuth/LDAP/SAML).
- **Reverse proxy:** set `xff-hdr`, `xff-src`, `rproxy`; use `--rp-loc` for subpath; Traefik examples in `contrib/traefik` and `docs/examples/docker/idp-*-traefik/`.
- **Healthcheck:** no dedicated health endpoint; use `GET /` on `3923` (or `/.cpr/metrics` if `--stats` enabled and accessible).
- **Gotchas:** default open to read/write; run as `user: 1000:1000` (not `PUID`/`PGID`); set `stop_grace_period: 15s`; keep `.hist` database on local storage; use `:z` on SELinux; mimalloc can double RAM.
