# ADR-20260629001: Start / Launch Page Dashboards for Levonk

## Status

**Accepted** - 2026-06-29

## Context

The Levonk homelab runs services across multiple machines (OCI cloud server, isolation VM) with Traefik as the reverse proxy, Authelia for SSO, CrowdSec for IP reputation, and GeoBlock for US-only access. Services are spread across containers and there is no centralized "launch page" or startpage to discover and access them. The user needs a flexible, easy-to-manage dashboard that surfaces all services — with a strong preference for **auto-discovery off of Traefik** so the dashboard stays in sync with the reverse proxy without hand-editing YAML for every new container.

### Projects Evaluated

| Project | Repo | Category |
|---|---|---|
| [Homer](https://github.com/bastienwirtz/homer) | bastienwirtz/homer | Static startpage (YAML-only, no discovery) |
| [Glance](https://github.com/glanceapp/glance) | glanceapp/glance | Widget dashboard (RSS/weather/feeds, not a service catalog) |
| [Glances](https://github.com/nicolargo/glances) | nicolargo/glances | System monitor (top/htop, not a launch page) |
| [Homepage](https://github.com/gethomepage/homepage) | gethomepage/homepage | Application dashboard with Docker label discovery + 100+ service widgets |
| [TraLa](https://github.com/dannybouwers/trala) | dannybouwers/trala | Traefik-native dashboard (auto-discovers HTTP routers from Traefik API) |
| [Compass](https://github.com/adinhodovic/compass) | adinhodovic/compass | Multi-source discovery (Docker/K8s/Tailscale/Headscale) |

### Feature Comparison Summary

Icons: 🏆 best · ✅ good · ➖ neutral · ⚠️ weak · ❌ worst.

| Feature | Homer | Glance | Glances | Homepage | TraLa | Compass |
|---|---|---|---|---|---|---|
| **Traefik API auto-discovery** | ❌ | ❌ | ❌ | ❌ (K8s IngressRoute only) | 🏆 yes | ❌ |
| Docker label discovery | ❌ | ❌ | ❌ | 🏆 yes | ❌ | ✅ |
| Tailscale discovery | ❌ | ❌ | ❌ | ❌ | ❌ | 🏆 yes |
| Service widgets (100+) | ➖ | ✅ feeds | ✅ metrics | 🏆 100+ | ➖ status | ✅ panels |
| System metrics (CPU/mem) | ❌ | ✅ | 🏆 full | ✅ | ❌ | ➖ |
| OIDC/password login | ❌ | ❌ | ✅ password | 🏆 OIDC+password | ❌ | ❌ |
| Stars | 11.4k | 35.5k | 33k | 31.2k | new | 44 |
| Setup difficulty | ✅ YAML | ✅ YAML | ✅ pip | ✅ YAML/labels | 🏆 env-only | ✅ YAML |
| Tech stack | Vue.js | Go | Python | Next.js | Go | Go+HTMX |

**Key finding**: No single project does **both** Traefik auto-discovery **and** rich service widgets. TraLa is the only project purpose-built to read the Traefik API and auto-discover routed services. Homepage is the most mature all-rounder with Docker label discovery and 100+ service widgets but cannot infer `href` from Traefik labels on plain Docker (see [homepage discussion #2823](https://github.com/gethomepage/homepage/discussions/2823)).

### Why Not a Single Tool?

- **TraLa alone** — no service widgets (only router name/URL/status). No OIDC login.
- **Homepage alone** — requires per-container `homepage.*` Docker labels; no Traefik API discovery on plain Docker.
- **Compass** — compelling Tailscale discovery but very new (44 stars, May 2026). Early adopter risk.
- **Glances** — system monitor, not a launch page. Pairs *with* a startpage, doesn't replace one.

## Decision

Deploy a **three-tool stack** on the OCI cloud server, each behind Traefik with the Authelia/CrowdSec/GeoBlock middleware chain:

### 1. Homepage — `start.levonk.com`
- **Role**: Primary startpage with rich service widgets and OIDC login via Authelia.
- **Image**: `ghcr.io/gethomepage/homepage:latest`
- **Discovery**: Docker label-based (`homepage.group`, `homepage.href`, `homepage.icon`, `homepage.widget.*`). Add labels to containers you want surfaced with live stats.
- **Port**: Host `8084` → Container `3000`
- **Config**: YAML files in a config volume (`services.yaml`, `settings.yaml`, `bookmarks.yaml`, `docker.yaml`, `kubernetes.yaml`).

### 2. TraLa — `start2.levonk.com`
- **Role**: Live Traefik service catalog. Auto-discovers all HTTP routers from the Traefik API — zero per-service config.
- **Image**: `ghcr.io/dannybouwers/trala:latest`
- **Discovery**: Reads `TRAEFIK_API_HOST=http://traefik:8080` and fetches all HTTP routers. Services appear/disappear as Traefik routes them.
- **Port**: Host `8085` → Container `8080`
- **Config**: Environment variables only (`TRAEFIK_API_HOST`, optional grouping/icon settings).

### 3. Glances — per-host system monitor (future phase)
- **Role**: System metrics (CPU/mem/disk/net/processes) per host. Linked from Homepage.
- **Deferred**: Not part of this ADR's implementation. Will be added as a per-host monitor in a follow-up.

### Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           Cloudflare DNS                 │
                    │  start.levonk.com  → 100.90.22.85       │
                    │  start2.levonk.com → 100.90.22.85       │
                    └──────────────────┬──────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────────┐
                    │           Traefik (443)                  │
                    │  GeoBlock → CrowdSec → Authelia          │
                    └──────┬───────────────────┬──────────────┘
                           │                   │
              ┌────────────▼──────┐  ┌─────────▼──────────┐
              │   Homepage:3000   │  │   TraLa:8080        │
              │  start.levonk.com │  │  start2.levonk.com  │
              │                   │  │                     │
              │  Docker socket    │  │  TRAEFIK_API_HOST   │
              │  (label discovery)│  │  =http://traefik:8080│
              └───────────────────┘  └─────────────────────┘
```

### Cross-linking
- Homepage's `bookmarks.yaml` includes a link to `start2.levonk.com` (TraLa) for the live Traefik catalog.
- TraLa's manual services include a link back to `start.levonk.com` (Homepage).

### Compass — Deferred
Compass is **not** deployed now. Its Tailscale source discovery is a compelling differentiator for the multi-exit-node topology, but at 44 stars (May 2026) it carries early-adopter risk. Revisit in 3–6 months. If Tailscale-only services (not exposed to Traefik) become a real category, Compass earns its place and may replace TraLa.

## Consequences

### Positive
- **TraLa** gives zero-maintenance auto-discovery of all Traefik-routed services — the dashboard stays in sync with the reverse proxy automatically.
- **Homepage** provides rich live widgets (Radarr/Sonarr/Plex/Traefik stats/qBittorrent) and OIDC login for services where live stats matter.
- Both sit behind the existing Authelia SSO + CrowdSec + GeoBlock middleware chain — no new auth infrastructure.
- The split avoids forcing one tool to do a job it can't (Traefik discovery + rich widgets).

### Negative
- **Two containers** to maintain instead of one. Two Traefik routes, two DNS records, two config volumes.
- **Homepage** still requires per-container `homepage.*` Docker labels for services you want surfaced with widgets — not zero-config.
- **TraLa** is a young project (v0.15.x, 2026) — small community, limited widget depth. If it goes unmaintained, the Traefik catalog breaks.
- **Domain sprawl**: `start.levonk.com` + `start2.levonk.com` — not the cleanest naming, but functional.

### Neutral
- Glances (system monitor) is deferred to a future phase. It will be a per-host deployment, not a cloud-server service.
- Compass is deferred. Revisit when it matures or when Tailscale-only services become a category.

## Implementation

### Infrastructure Variables
- `infra_port_dashboard_homepage_host: "8084"` / `infra_port_dashboard_homepage_container: "3000"`
- `infra_port_dashboard_trala_host: "8085"` / `infra_port_dashboard_trala_container: "8080"`
- `infra_domain_dashboard_homepage: "start.levonk.com"`
- `infra_domain_dashboard_trala: "start2.levonk.com"`

### Traefik API Access (for TraLa)
TraLa reads the Traefik API at `http://traefik:8080` on the `traefik-network`. The API is secured with **HTTP basic auth** (bcrypt-hashed password) on a dedicated `traefik-api` entrypoint:

- `api.insecure: false` — no unauthenticated listener
- Dedicated `traefik-api` entrypoint on container port 8080 (static config)
- Dynamic config router `traefik-api@file` routes `PathPrefix(/api)||PathPrefix(/dashboard)` → `api@internal` with `traefik-api-auth` basicAuth middleware
- Credentials (`vault_traefik_api_auth_user`, `vault_traefik_api_auth_password`) stored in `infrahub-levonk-all.vault.yml`
- TraLa receives credentials via `TRAEFIK_BASIC_AUTH_USERNAME`/`TRAEFIK_BASIC_AUTH_PASSWORD` env vars; `enable_basic_auth: true` set in `/config/configuration.yml`
- Host port 8882 bound to `127.0.0.1` only (not `0.0.0.0`) — reachable on the host for debugging, not from Tailscale or public internet

**Defense in depth**: (1) localhost binding, (2) OCI security group blocks 8882, (3) basic auth required on the API itself.

### Ansible Roles
- `shared/active/02-config/ansible/roles/dashboard-homepage/` — deploys Homepage via `community.docker.docker_container`
- `shared/active/02-config/ansible/roles/dashboard-trala/` — deploys TraLa via `community.docker.docker_container`

### Playbook
- `shared/active/02-config/ansible/playbooks/deploy-start-pages.yml` — DNS records + both roles
- Both roles also added to `cloud-server-infra.yml` for full-stack deploys

### Deployment
```bash
cd ~/p/gh/levonk/infrahub && devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-start-pages.yml \
  --vault-password-file ~/.ansible/vault_password
```

## References

- [Homer](https://github.com/bastienwirtz/homer) — static startpage
- [Glance](https://github.com/glanceapp/glance) — widget dashboard
- [Glances](https://github.com/nicolargo/glances) — system monitor
- [Homepage](https://github.com/gethomepage/homepage) — application dashboard ([docs](https://gethomepage.dev/))
- [TraLa](https://github.com/dannybouwers/trala) — Traefik dashboard ([docs](https://www.trala.fyi))
- [Compass](https://github.com/adinhodovic/compass) — multi-source discovery ([docs](https://adinhodovic.github.io/compass/))
- [Homepage Docker discovery docs](https://github.com/gethomepage/homepage/blob/dev/docs/configs/docker.md)
- [Homepage Traefik label duplication discussion](https://github.com/gethomepage/homepage/discussions/2823)
- [ADR-20260624001](adr-20260624001-hybrid-sensitive-information-storage.md) — hybrid secret storage
- [ADR-20260625001](adr-20260625001-infrastructure-consolidation.md) — infrastructure consolidation
