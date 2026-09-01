# copyparty vs. Self-Hostable File Sharing / Sync / Media Server Alternatives

> Generated with the `project-comparison` skill.
> Date: 2026-08 (web-sourced; re-run `scripts/gather_github_metadata.py` for exact GitHub metrics).

## Category & Scope

**Target category:** self-hostable file sharing / web file manager / lightweight media server.
**Use case:** personal / family file sharing behind **Traefik** on a single OCI cloud host.

**Excluded from the matrix:** [Hauk](https://github.com/bilde2910/Hauk) — it is a real-time *location* sharing service, not a file sharing tool, so it does not compete in this category.

**Cross-category note:** [Syncthing](https://github.com/syncthing/syncthing) is primarily a sync tool and [MinIO](https://github.com/minio/minio) is an S3-compatible object store. They are included because they are often considered alongside file servers, but their category mismatch is flagged below.

## Icon Legend

- **Features:** 🏆 best · ✅ good · ➖ neutral · ⚠️ bad · ❌ missing
- **License:** ⭐ FOSS (OSI) · ☑️ OSS (non-OSI / mixed) · ⚠️ free (non-OSI) · ❌ paid

## Feature Matrix

| Feature | [copyparty](https://github.com/9001/copyparty) | [Nextcloud](https://github.com/nextcloud/server) | [Seafile](https://github.com/haiwen/seafile) | [FileBrowser](https://github.com/filebrowser/filebrowser) | [Syncthing](https://github.com/syncthing/syncthing) | [MinIO](https://github.com/minio/minio) | [ownCloud oCIS](https://github.com/owncloud/ocis) |
|---|---|---|---|---|---|---|---|
| **Meta** | | | | | | | |
| Primary category | file share / media server | share/collab platform | sync + share | web file manager | continuous sync | S3 object store | sync + share |
| License | ⭐ MIT | ⭐ AGPL-3.0 | ☑️ mixed (AGPL/Apache/GPL) | ⭐ Apache-2.0 | ⭐ MPL-2.0 | ⭐ AGPL-3.0 | ⭐ Apache-2.0 |
| Last release / push | 2026-08-17 | 2026-08-13 | 2026-08-12 | 2026-07-27 (final) | 2026-08-05 | 2026-04-25 (archived) | 2026-08-21 |
| Stars | 46.3k | 36.5k | 15.1k | 35.7k | 87.9k | 61.4k | 2.1k |
| Forks | 1.9k | 5.1k | 1.7k | 4.0k | 5.4k | 7.7k | 0.3k |
| Open issues | 254 | 3.5k | 90 | 48 | 376 | 80 | 615 |
| Year introduced | 2019 | 2016 | 2012 | 2015 | 2013 | 2015 | 2019 |
| Container image | ✅ official multi-edition | ✅ official | ✅ `seafileltd/seafile-mc` | ✅ official | ✅ official | ✅ official (source-only now) | ✅ official |
| Image size (compressed) | ✅ 25–104 MB | ⚠️ ~527 MB | ⚠️ ~530 MB | ✅ ~31 MB | ✅ ~40 MB | ✅ ~60 MB | ✅ ~79 MB |
| Multi-arch | ✅ x86/amd64/armv7/arm64/ppc64le/s390x | ✅ amd64/arm64 | ✅ amd64/arm64 | ✅ amd64/arm64/armv7 | ✅ many | ✅ amd64/arm64/ppc64le | ✅ amd64/arm64 |
| Setup Difficulty | ✅ < 5 min | ⚠️ > 1 hr | ⚠️ > 1 hr | ✅ < 30 min | ✅ < 30 min | ➖ < 1 hr | ➖ < 1 hr |
| Community | ✅ very active | 🏆 very active | ✅ active | ⚠️ winding down | 🏆 very active | ❌ archived | ✅ active |
| **Maintainability** | 🏆 | ✅ | ✅ | ⚠️ | 🏆 | ❌ | ✅ |
| **Deployment** | | | | | | | |
| Container model | ✅ single image / SFX | ⚠️ DB + web + cron + redis | ⚠️ DB + search + multi-svc | ✅ single container | ✅ single container | ➖ single container, build from source | ✅ single binary, multi-service |
| Traefik examples | ✅ (Authelia/Authentik) | ✅ (many docs) | ➖ (Nginx-focused) | ✅ | ⚠️ not designed for it | ➖ (S3 API) | ✅ (official docs) |
| X-Forwarded headers | ✅ (`xff-hdr`, `rproxy`) | ➖ (needs overrides) | ➖ | ✅ | ➖ | ➖ | ✅ |
| Base / subpath support | ✅ (`--rp-loc`) | ⚠️ (subpath is painful) | ➖ | ✅ (`baseURL`) | ❌ | ➖ | ✅ |
| **Resource Footprint** | | | | | | | |
| RAM (typical) | ✅ < 512 MB | ⚠️ 2–4 GB | ⚠️ 2–4 GB | ✅ < 512 MB | ✅ < 500 MB | ✅ ~1 GB | ➖ 512 MB min, 4 GB rec |
| CPU | ✅ low | ⚠️ 2–4 cores | ⚠️ 2–4 cores | ✅ low | ✅ low | ✅ low | ➖ multi-core |
| **Authentication** | | | | | | | |
| Local users | ✅ | ✅ | ✅ | ✅ | ✅ (web UI) | ✅ (IAM) | ✅ |
| OIDC / OAuth | ✅ via IdP headers | ✅ (apps) | ➖ (Pro/limited) | ❌ (proxy only) | ❌ | ✅ | ✅ |
| LDAP / AD | ✅ via IdP headers | ✅ (app) | ✅ | ❌ | ❌ | ✅ | ✅ |
| Shared password / links | ✅ | ✅ | ✅ | ✅ | ❌ | ➖ (presigned URLs) | ✅ |
| Anonymous | ✅ (volume perms) | ✅ (public links) | ✅ | ✅ (public shares) | ❌ | ➖ (public bucket) | ✅ |
| **File Sharing** | | | | | | | |
| WebDAV | ✅ read-write | ✅ | ✅ (seafdav) | ❌ | ❌ | ❌ (S3 API) | ✅ |
| Deduplication | ✅ (symlink-based) | ❌ | ✅ (block-level) | ❌ | ❌ | ❌ | ❌ |
| Thumbnails | ✅ (image/video/audio) | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Search | ✅ (file index/media) | ✅ (apps) | ✅ (SeaSearch/ES) | ✅ | ❌ | ❌ (without extra tools) | ✅ |
| Upload links | ✅ (write-only, upget) | ✅ | ✅ | ✅ (share) | ❌ | ➖ (presigned) | ✅ |
| Expiry / lifetime | ✅ (shares + lifetime) | ✅ (shares) | ✅ | ✅ (shares) | ❌ | ✅ (presigned) | ✅ |
| **Sync Features** | | | | | | | |
| Desktop client | ➖ (mount via WebDAV) | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| Selective sync | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| Conflict resolution | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| **Backup Story** | | | | | | | |
| Backup model | ✅ plain files + optional metadata | ⚠️ DB + data + config | ⚠️ DB + `seafile-data` | ✅ SQLite + files | ✅ files + config | ➖ object buckets | ✅ POSIX files + config |

## Per-Project Notes

- **copyparty** — Single Python process that exposes existing folders over HTTP/FTP/WebDAV/SMB/SFTP. Very low resource use, excellent upload handling, media indexing, and many reverse-proxy/IdP examples.
- **Nextcloud** — Full collaboration suite (files, talk, office, calendar). Very capable but heavy: needs a database, redis, and regular cron/background jobs. Overkill for a simple family share on a small OCI instance.
- **Seafile** — Mature block-level sync and share. Strong dedup, but the CE Docker stack is heavy and usually needs a separate search/indexer.
- **FileBrowser** — Very simple web file manager, but the upstream project is winding down and the repo will be archived on **2026-09-01** with no further security fixes. Not recommended for new deployments.
- **Syncthing** — Best-in-class continuous sync. Not a web file sharing server; use only if sync is the only requirement.
- **MinIO** — `minio/minio` was archived on **2026-04-25** and is now source-only / unmaintained. Avoid for new self-hosting.
- **ownCloud oCIS** — Modern Go rewrite, single binary, Apache-2.0, with a native sync client. Good for sync+share, but 600+ open issues and a 4 GB RAM recommendation for production.

## Maintainability Scores

| Candidate | Activity | Community | Combined | Score /10 |
|---|---|---|---|---|
| copyparty | 🏆 (weekly releases) | ✅ | 🏆 | 9.0 |
| Nextcloud | ✅ | 🏆 | ✅ | 8.5 |
| Seafile | ✅ | ✅ | ✅ | 8.0 |
| FileBrowser | ⚠️ (archiving 2026-09-01) | ➖ | ⚠️ | 4.5 |
| Syncthing | 🏆 | 🏆 | 🏆 | 9.0 |
| MinIO | ❌ (archived 2026-04-25) | ❌ | ❌ | 3.0 |
| ownCloud oCIS | ✅ | ➖ (615 open issues) | ✅ | 7.5 |

## Recommendation

For a **personal / family file-sharing server behind Traefik on a single OCI cloud host**, the answer depends on whether you need a native sync client:

- **If the goal is simple sharing / WebDAV / upload links with the smallest footprint**: **copyparty is the best choice**. It is the only candidate that is tiny, single-container, stores data as plain files, supports base-path proxying, and still provides WebDAV, dedup, thumbnails, search, and expiring upload links.
- **If you also need desktop sync and can afford 2–4 GB RAM**: consider **ownCloud oCIS** (modern, Apache-2.0, single Go binary, Traefik docs) or **Seafile** (proven, block-level sync).
- **If only continuous sync matters, not a web share**: **Syncthing** is best-in-class.
- **Avoid for new deployments**: **FileBrowser** (winding down) and **MinIO** (archived, S3 category mismatch).
- **Nextcloud** is overkill unless you also want office, chat, calendar, etc.

## Final Verdict

**copyparty is the right default choice** for the stated single-host, Traefik-proxied, personal/family file sharing scenario. It matches the required feature set with the lowest resource and backup complexity. Move to **oCIS** or **Seafile** only if you outgrow it and need native sync clients.
