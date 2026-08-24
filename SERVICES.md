# Infrahub Service Catalog (Shared Defaults)

> **Auto-generated** from `infrastructure/*.yml` (shared defaults only) — last updated: 2026-08-23 13:30
> Regenerate with: `just generate-service-catalog-shared`
> Source: `shared/active/02-config/ansible/infrastructure/services.yml`
> Note: This catalog shows **default ports and suggested hostnames** only. Client-specific deployment details (custom domains, deployed machines, client port overrides) are not included. See `levonk/SERVICES.md` for the deployed client catalog.

**70 services** (shared defaults — no deployment info)

## Table of Contents

- [Service Chains](#service-chains)
  - [AI Pipeline](#ai-pipeline)
  - [Nix Cache Chain (nl)](#nix-cache-chain-nl)
  - [Nix Cache Chain (cno)](#nix-cache-chain-cno)
- [All Services (Alphabetical)](#all-services-alphabetical)
- [Services by Category](#services-by-category)
  - [🌐 UI (Web Apps)](#ui-web-apps)
  - [🔌 API (HTTP Services)](#api-http-services)
  - [🖥️ Console / Dashboard](#console-dashboard)
  - [🗄️ Passive (Databases / Caches / Queues)](#passive-databases-caches-queues)
  - [🔗 Proxy Chain (Internal)](#proxy-chain-internal)
  - [🔒 VPN / Mesh Networking](#vpn-mesh-networking)
  - [📡 DNS](#dns)
  - [🛡️ Security / SSO](#security-sso)
  - [⚙️ Infrastructure](#infrastructure)

## Service Chains

### AI Pipeline

*Request flow for AI inference — gateway → proxy chain → upstream providers*

```mermaid
---
title: AI Pipeline
---
flowchart TD
    LiteLLM["LiteLLM"]
    Privacy_Orchestrator["Privacy Orchestrator"]
    LiteLLM -->|PII guardrail| Privacy_Orchestrator
    Forge["Forge"]
    Privacy_Orchestrator -->|load balancer| Forge
    Headroom["Headroom"]
    Forge -->|context compression| Headroom
    iron_proxy["iron-proxy"]
    Headroom -->|egress proxy| iron_proxy
    OmniRoute["OmniRoute"]
    iron_proxy -->|upstream router| OmniRoute

    %% Machine color coding
    classDef machine_oci_AI_Pipeline fill:#4A90D9,color:#fff,stroke:#333,stroke-width:1px
    class Privacy_Orchestrator,iron_proxy,Forge,LiteLLM,Headroom,OmniRoute machine_oci_AI_Pipeline
```

### Nix Cache Chain (nl)

*Nix binary cache proxy chain (nl region) — client → cache → racer → upstreams*

```mermaid
---
title: Nix Cache Chain (nl)
---
flowchart TD
    Nix_ncps__nl_["Nix ncps (nl)"]
    Nix_ncro__nl_["Nix ncro (nl)"]
    Nix_ncps__nl_ -->|racing proxy| Nix_ncro__nl_
    Nix_Harmonia__nl_["Nix Harmonia (nl)"]
    Nix_ncro__nl_ -->|local /nix/store| Nix_Harmonia__nl_
    https___cache_nixos_org_Nix_Cache_Chain__nl_[("cache.nixos.org")]
    Nix_ncro__nl_ -.-> https___cache_nixos_org_Nix_Cache_Chain__nl_
    https___cache_garnix_io_Nix_Cache_Chain__nl_[("cache.garnix.io")]
    Nix_ncro__nl_ -.-> https___cache_garnix_io_Nix_Cache_Chain__nl_
    https___nix_community_cachix_org_Nix_Cache_Chain__nl_[("nix-community.cachix.org")]
    Nix_ncro__nl_ -.-> https___nix_community_cachix_org_Nix_Cache_Chain__nl_

    %% Machine color coding
    classDef machine_dtop_Nix_Cache_Chain__nl_ fill:#50C878,color:#fff,stroke:#333,stroke-width:1px
    class Nix_Harmonia__nl_,Nix_ncro__nl_,Nix_ncps__nl_ machine_dtop_Nix_Cache_Chain__nl_
```

### Nix Cache Chain (cno)

*Nix binary cache proxy chain (cno region) — client → cache → racer → upstreams*

```mermaid
---
title: Nix Cache Chain (cno)
---
flowchart TD
    Nix_ncps__cno_["Nix ncps (cno)"]
    Nix_ncro__cno_["Nix ncro (cno)"]
    Nix_ncps__cno_ -->|racing proxy| Nix_ncro__cno_
    Nix_Harmonia__cno_["Nix Harmonia (cno)"]
    Nix_ncro__cno_ -->|local /nix/store| Nix_Harmonia__cno_
    https___cache_nixos_org_Nix_Cache_Chain__cno_[("cache.nixos.org")]
    Nix_ncro__cno_ -.-> https___cache_nixos_org_Nix_Cache_Chain__cno_
    https___cache_garnix_io_Nix_Cache_Chain__cno_[("cache.garnix.io")]
    Nix_ncro__cno_ -.-> https___cache_garnix_io_Nix_Cache_Chain__cno_
    https___nix_community_cachix_org_Nix_Cache_Chain__cno_[("nix-community.cachix.org")]
    Nix_ncro__cno_ -.-> https___nix_community_cachix_org_Nix_Cache_Chain__cno_

    %% Machine color coding
    classDef machine_oci_Nix_Cache_Chain__cno_ fill:#4A90D9,color:#fff,stroke:#333,stroke-width:1px
    class Nix_Harmonia__cno_,Nix_ncro__cno_,Nix_ncps__cno_ machine_oci_Nix_Cache_Chain__cno_
```

## All Services (Alphabetical)

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Category | Source |
|---------|-----------|--------------------|-------------------|---------|---------|----------|--------|
| agentmemory | `agentmemory` | `infra_domain_ai_agentmemory` (suggested) | `3111`→`3111` (REST/MCP) | — | `/opt/localnet/data/agentmemory`<br>`/opt/localnet/services/agentmemory/config` | UI (Web Apps) | [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) |
| AI Dashboard | `ai-dashboard` | `infra_domain_ai_dashboard_web` (suggested) | `3000`→`3000` (Web) | — | — | UI (Web Apps) | [levonk/ai-dashboard](https://github.com/levonk/ai-dashboard) |
| Authelia | `authelia` | `infra_domain_sso_authelia` (suggested) | `9091`→`9091` (Web) | — | — | Security / SSO | [authelia/authelia](https://github.com/authelia/authelia) |
| Authelia Postgres | `authelia-postgres` | — | `5432`→`5432` (PostgreSQL) | authelia-network | — | Passive (Databases / Caches / Queues) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| Buzz Agent Runtime | `buzz-agent-*` | — | — | buzz-network | — | ai | [block/buzz](https://github.com/block/buzz) |
| CoreDNS | `coredns` | — | `15354`→`15353` (DNS)<br>`9153`→`9153` (Metrics) | localnet-network | — | DNS | [coredns/coredns](https://github.com/coredns/coredns) |
| CrowdSec | `crowdsec` | — | `8080`→`8080` (LAPI) | crowdsec-network | — | Security / SSO | [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec) |
| Directory Empire | `localnet-dashboard-directory-empire` | `infra_domain_dashboard_directory_empire_nl` (suggested) | `4530`→`3000` (Web) | traefik-windows-network | `localnet-directory-empire-config-volume` (volume) | UI (Web Apps) | [lrepo52/directory-empire](https://github.com/lrepo52/directory-empire) |
| dnsdist | `dnsdist` | — | `5501`→`5501` (DNS)<br>`8083`→`8083` (Metrics) | localnet-network | — | DNS | [PowerDNS/dnsdist](https://github.com/PowerDNS/dnsdist) |
| Forge | `forge` | — | `8083`→`8081` (API) | forge-network | — | Proxy Chain (Internal) | [antoinezambelli/forge](https://github.com/antoinezambelli/forge) |
| fwknop SPA | `N/A (host-level apt service)` | — | `62271`→`62271` (SPA (UDP)) | — | — | Security / SSO | [mrash/fwknop](https://github.com/mrash/fwknop) |
| Gost Egress | `localnet-proxy-gost` | — | `11080`→`1080` (SOCKS5) | localnet-network | — | Proxy Chain (Internal) | [go-gost/gost](https://github.com/go-gost/gost) |
| Headroom | `headroom` | `infra_domain_ai_aishrink` (suggested) | `8787`→`8787` (API) | — | — | Proxy Chain (Internal) | [chopratejas/headroom](https://github.com/chopratejas/headroom) |
| Hister | `localnet-hister` | `infra_domain_search_hister` (suggested) | `4433`→`4433` (Web) | traefik-windows-network | `localnet-hister-data-volume` (volume) | search | [asciimoo/hister](https://github.com/asciimoo/hister) |
| Homepage | `homepage` | `infra_domain_dashboard_homepage` (suggested) | `8084`→`3000` (Web) | — | — | Infrastructure | [gethomepage/homepage](https://github.com/gethomepage/homepage) |
| Host Exit Node (cno) | `—` | — | — | — | — | VPN / Mesh Networking | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| Host Exit Node (nl) | `—` | — | — | — | — | VPN / Mesh Networking | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| iron-proxy | `iron-proxy` | — | `8080` (HTTP)<br>`8443` (HTTPS) | proxy-chain-network | — | Proxy Chain (Internal) | [ironsh/iron-proxy](https://github.com/ironsh/iron-proxy) |
| Isolation VM | `isolation-vm` | — | — | — | — | Infrastructure | [www.qemu.org](https://www.qemu.org/) |
| JobOps | `localnet-jobops` | `infra_domain_career_jobops` (suggested) | `3005`→`3001` (Web) | — | `localnet-jobops-data-volume` (volume) | UI (Web Apps) | [DaKheera47/job-ops](https://github.com/DaKheera47/job-ops) |
| kckinai Host | `kckinai` | `infra_domain_inference_host` (suggested) | — | — | — | Infrastructure | [tailscale.com](https://tailscale.com/) |
| Langfuse ClickHouse | `langfuse-clickhouse` | — | `8123` (HTTP)<br>`9000` (TCP) | langfuse-network | — | Passive (Databases / Caches / Queues) | [ClickHouse/ClickHouse](https://github.com/ClickHouse/ClickHouse) |
| Langfuse MinIO | `langfuse-minio` | — | `9190`→`9000` (S3 API)<br>`9001` (Console) | langfuse-network | — | Passive (Databases / Caches / Queues) | [minio/minio](https://github.com/minio/minio) |
| Langfuse Postgres | `langfuse-postgres` | — | `5434`→`5432` (PostgreSQL) | langfuse-network | — | Passive (Databases / Caches / Queues) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| Langfuse Redis | `langfuse-redis` | — | `6379` (Redis) | langfuse-network | — | Passive (Databases / Caches / Queues) | [redis/redis](https://github.com/redis/redis) |
| Langfuse Web | `langfuse-web` | `infra_domain_ai_langfuse` (suggested) | `3001`→`3000` (Web) | — | — | UI (Web Apps) | [langfuse/langfuse](https://github.com/langfuse/langfuse) |
| Langfuse Worker | `langfuse-worker` | — | `3030` (Worker) | langfuse-network | — | Passive (Databases / Caches / Queues) | [langfuse/langfuse](https://github.com/langfuse/langfuse) |
| LiteLLM | `litellm` | `infra_domain_ai_litellm` (suggested)<br>`infra_domain_ai_litellm_api` (suggested) | `4000`→`4000` (Web/API) | — | `/opt/localnet/data/litellm`<br>`/opt/localnet/services/litellm/config` | UI (Web Apps) | [BerriAI/litellm](https://github.com/BerriAI/litellm) |
| LiteLLM Postgres | `litellm-postgres` | — | `5435`→`5432` (PostgreSQL) | proxy-chain-network | — | Passive (Databases / Caches / Queues) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| LiteLLM Redis | `litellm-redis` | — | `6379` (Redis) | proxy-chain-network | — | Passive (Databases / Caches / Queues) | [redis/redis](https://github.com/redis/redis) |
| Local Registry | `registry` | — | `5000`→`5000` (Registry) | traefik-network | — | Infrastructure | [distribution/distribution](https://github.com/distribution/distribution) |
| MITM Proxy | `mitmproxy` | — | `3128`→`3128` (HTTP Proxy) | localnet-network | — | Proxy Chain (Internal) | [mitmproxy/mitmproxy](https://github.com/mitmproxy/mitmproxy) |
| n8n | `localnet-n8n` | `infra_domain_ai_n8n` (suggested) | `3106`→`5678` (Web UI) | n8n-network | `localnet-n8n-data-volume` (volume) | UI (Web Apps) | [n8n-io/n8n](https://github.com/n8n-io/n8n) |
| n8n Grafana | `localnet-n8n-grafana` | `infra_domain_ai_n8n_grafana` (suggested) | `3108`→`3000` (Web UI) | n8n-network | `localnet-n8n-grafana-data-volume` (volume) | Console / Dashboard | [n8n-io/n8n-observability](https://github.com/n8n-io/n8n-observability) |
| n8n Postgres | `localnet-n8n-postgres` | — | `5438`→`5432` (PostgreSQL) | n8n-network | `localnet-n8n-postgres-data-volume` (volume) | Passive (Databases / Caches / Queues) | [postgres/postgres](https://github.com/postgres/postgres) |
| n8n Prometheus | `localnet-n8n-prometheus` | — | `3107`→`9090` (Web UI) | n8n-network | `localnet-n8n-prometheus-data-volume` (volume) | Passive (Databases / Caches / Queues) | [prometheus/prometheus](https://github.com/prometheus/prometheus) |
| Nix Harmonia (cno) | `localnet-nix-harmonia-cno` | — | `4523`→`5000` (HTTP (local only)) | traefik-network | — | Infrastructure | [nix-community/harmonia](https://github.com/nix-community/harmonia) |
| Nix Harmonia (nl) | `localnet-nix-harmonia` | — | `4523`→`5000` (HTTP (local only)) | traefik-windows-network | — | Infrastructure | [nix-community/harmonia](https://github.com/nix-community/harmonia) |
| Nix ncps (cno) | `localnet-nix-ncps-cno` | `infra_domain_nix_cache_cno` (suggested) | `4524`→`8080` (HTTP (via Traefik)) | traefik-network | — | Infrastructure | [kalbasit/ncps](https://github.com/kalbasit/ncps) |
| Nix ncps (nl) | `localnet-nix-ncps` | `infra_domain_nix_cache_nl` (suggested) | `4524`→`8080` (HTTP (via Traefik)) | traefik-windows-network | — | Infrastructure | [kalbasit/ncps](https://github.com/kalbasit/ncps) |
| Nix ncro (cno) | `localnet-nix-ncro-cno` | — | `4525`→`8081` (HTTP (internal, behind ncps)) | traefik-network | — | Proxy Chain (Internal) | [manic-systems/ncro](https://github.com/manic-systems/ncro) |
| Nix ncro (nl) | `localnet-nix-ncro` | — | `4525`→`8081` (HTTP (internal, behind ncps)) | traefik-windows-network | — | Proxy Chain (Internal) | [manic-systems/ncro](https://github.com/manic-systems/ncro) |
| no-mistakes Gate | `localnet-no-mistakes` | `infra_domain_devops_no_mistakes` (suggested) | `2222`→`2222` (SSH Git) | traefik-windows-network | — | Infrastructure | [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) |
| NordVPN | `nordvpn` | — | `51820`→`51820` (WireGuard)<br>`1080`→`1080` (SOCKS)<br>`8888`→`8888` (HTTP Proxy) | vpn-network | — | VPN / Mesh Networking | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
| NordVPN Exit Node (nl) | `nordvpn` | — | `1081`→`1080` (SOCKS)<br>`8889`→`8888` (HTTP Proxy)<br>`8444`→`8443` (HTTPS Proxy) | vpn-network | — | VPN / Mesh Networking | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
| Omnigent | `omnigent` | `infra_domain_ai_omnigent` (suggested) | `8000`→`8000` (Web/API) | — | — | UI (Web Apps), API (HTTP Services) | [omnigent-ai/omnigent](https://github.com/omnigent-ai/omnigent) |
| Omnigent Postgres | `omnigent-postgres` | — | `5433`→`5432` (PostgreSQL) | proxy-chain-network | — | Passive (Databases / Caches / Queues) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| OmniRoute | `omniroute` | `infra_domain_ai_omniroute` (suggested) | `20128`→`20128` (API) | — | — | API (HTTP Services) | [diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute) |
| Pi | `pi` | — | `8090`→`8090` (RPC) | proxy-chain-network | — | API (HTTP Services) | [earendil-works/pi](https://github.com/earendil-works/pi) |
| Privacy Orchestrator | `privacy-orchestrator` | — | `8082`→`8082` (API) | proxy-chain-network | — | Proxy Chain (Internal) | [levonk/ai-dashboard](https://github.com/levonk/ai-dashboard) |
| Privoxy | `privoxy` | — | `8118`→`8118` (HTTP Proxy) | localnet-network | — | Proxy Chain (Internal) | [www.privoxy.org](https://www.privoxy.org/) |
| QM Core | `qm-levonk-core` | — | `3104`→`8080` (Core API) | — | — | API (HTTP Services) | [yc-software/qm](https://github.com/yc-software/qm) |
| QM Postgres | `qm-levonk-pg` | — | `5437`→`5432` (PostgreSQL) | qm-levonk | `localnet-qm-postgres-data-volume` (volume) | Passive (Databases / Caches / Queues) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| QM Web UI | `qm-levonk-web-ui` | `infra_domain_ai_qm` (suggested) | `3105`→`8082` (Web UI) | — | — | UI (Web Apps) | [yc-software/qm](https://github.com/yc-software/qm) |
| RustFS | `localnet-rustfs` | `infra_domain_storage_rustfs` (suggested)<br>`infra_domain_storage_rustfs_console` (suggested) | `9000`→`9000` (S3 API)<br>`9001`→`9001` (Console) | — | `localnet-rustfs-data-volume` (volume) | Passive (Databases / Caches / Queues) | [rustfs/rustfs](https://github.com/rustfs/rustfs) |
| SearXNG | `searxng` | `infra_domain_proxy_search` (suggested) | `8080`→`8080` (Web) | — | — | UI (Web Apps) | [searxng/searxng](https://github.com/searxng/searxng) |
| Tailscale | `tailscale` | — | `41641`→`41641` (WireGuard) | — | — | VPN / Mesh Networking | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| Tor Exit Node (cno) | `tor` | — | `9001`→`9001` (ORPort)<br>`9030`→`9030` (DirPort)<br>`9050`→`9050` (SOCKS) | tor-network | — | VPN / Mesh Networking | [torproject/tor](https://github.com/torproject/tor) |
| Tor Exit Node (nl) | `tor-exit` | — | `9011`→`9001` (ORPort)<br>`9031`→`9030` (DirPort)<br>`9051`→`9050` (SOCKS) | tor-network | — | VPN / Mesh Networking | [torproject/tor](https://github.com/torproject/tor) |
| Tor Tailscale Exit (cno) | `{{ infra_hostname_vpn_tailscale_tor }}` | — | — | tor-network | — | VPN / Mesh Networking | [torproject/tor](https://github.com/torproject/tor) |
| Tor Tailscale Exit (nl) | `{{ infra_hostname_vpn_tailscale_tor }}` | — | — | tor-network | — | VPN / Mesh Networking | [torproject/tor](https://github.com/torproject/tor) |
| Traefik | `traefik` | `infra_domain_traefik_dashboard` (suggested) | `80`→`80` (HTTP)<br>`443`→`443` (HTTPS) | traefik-network | — | Console / Dashboard | [traefik/traefik](https://github.com/traefik/traefik) |
| TraLa | `trala` | `infra_domain_dashboard_trala` (suggested) | `8085`→`8080` (Web) | — | — | Infrastructure | [dannybouwers/trala](https://github.com/dannybouwers/trala) |
| Varnish Cache | `varnish` | — | `6081`→`6081` (HTTP) | localnet-network | — | Proxy Chain (Internal) | [varnishcache/varnish-cache](https://github.com/varnishcache/varnish-cache) |
| Verdaccio NPM Registry (cno) | `localnet-artifact-verdaccio` | `infra_domain_artifact_verdaccio_cno` (suggested) | `4873`→`4873` (Web/API) | traefik-network | — | Infrastructure | [verdaccio/verdaccio](https://github.com/verdaccio/verdaccio) |
| Verdaccio NPM Registry (nl) | `localnet-artifact-verdaccio-nl` | `infra_domain_artifact_verdaccio_nl` (suggested) | `4873`→`4873` (Web/API) | — | — | Infrastructure | [verdaccio/verdaccio](https://github.com/verdaccio/verdaccio) |
| VPN Tailscale Exit (cno) | `{{ infra_hostname_vpn_tailscale_nordvpn }}` | — | — | vpn-network | — | VPN / Mesh Networking | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| VPN Tailscale Exit (nl) | `{{ infra_hostname_vpn_tailscale_nordvpn }}` | — | — | vpn-network | — | VPN / Mesh Networking | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| WorldMonitor | `worldmonitor-app` | — | `3000`→`8080` (Web) | worldmonitor-net | — | UI (Web Apps) | [koala73/worldmonitor](https://github.com/koala73/worldmonitor) |
| WorldMonitor Redis | `worldmonitor-redis` | — | `8079`→`80` (Redis REST) | worldmonitor-net | `worldmonitor-redis-data` (volume) | Passive (Databases / Caches / Queues) | [redis/redis](https://github.com/redis/redis) |

## Services by Category

### 🌐 UI (Web Apps)

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| agentmemory | `agentmemory` | `infra_domain_ai_agentmemory` (suggested) | `3111`→`3111` (REST/MCP) | — | `/opt/localnet/data/agentmemory`<br>`/opt/localnet/services/agentmemory/config` | [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) |
| AI Dashboard | `ai-dashboard` | `infra_domain_ai_dashboard_web` (suggested) | `3000`→`3000` (Web) | — | — | [levonk/ai-dashboard](https://github.com/levonk/ai-dashboard) |
| Directory Empire | `localnet-dashboard-directory-empire` | `infra_domain_dashboard_directory_empire_nl` (suggested) | `4530`→`3000` (Web) | traefik-windows-network | `localnet-directory-empire-config-volume` (volume) | [lrepo52/directory-empire](https://github.com/lrepo52/directory-empire) |
| JobOps | `localnet-jobops` | `infra_domain_career_jobops` (suggested) | `3005`→`3001` (Web) | — | `localnet-jobops-data-volume` (volume) | [DaKheera47/job-ops](https://github.com/DaKheera47/job-ops) |
| Langfuse Web | `langfuse-web` | `infra_domain_ai_langfuse` (suggested) | `3001`→`3000` (Web) | — | — | [langfuse/langfuse](https://github.com/langfuse/langfuse) |
| LiteLLM | `litellm` | `infra_domain_ai_litellm` (suggested)<br>`infra_domain_ai_litellm_api` (suggested) | `4000`→`4000` (Web/API) | — | `/opt/localnet/data/litellm`<br>`/opt/localnet/services/litellm/config` | [BerriAI/litellm](https://github.com/BerriAI/litellm) |
| n8n | `localnet-n8n` | `infra_domain_ai_n8n` (suggested) | `3106`→`5678` (Web UI) | n8n-network | `localnet-n8n-data-volume` (volume) | [n8n-io/n8n](https://github.com/n8n-io/n8n) |
| Omnigent | `omnigent` | `infra_domain_ai_omnigent` (suggested) | `8000`→`8000` (Web/API) | — | — | [omnigent-ai/omnigent](https://github.com/omnigent-ai/omnigent) |
| QM Web UI | `qm-levonk-web-ui` | `infra_domain_ai_qm` (suggested) | `3105`→`8082` (Web UI) | — | — | [yc-software/qm](https://github.com/yc-software/qm) |
| SearXNG | `searxng` | `infra_domain_proxy_search` (suggested) | `8080`→`8080` (Web) | — | — | [searxng/searxng](https://github.com/searxng/searxng) |
| WorldMonitor | `worldmonitor-app` | — | `3000`→`8080` (Web) | worldmonitor-net | — | [koala73/worldmonitor](https://github.com/koala73/worldmonitor) |

### 🔌 API (HTTP Services)

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Omnigent | `omnigent` | `infra_domain_ai_omnigent` (suggested) | `8000`→`8000` (Web/API) | — | — | [omnigent-ai/omnigent](https://github.com/omnigent-ai/omnigent) |
| OmniRoute | `omniroute` | `infra_domain_ai_omniroute` (suggested) | `20128`→`20128` (API) | — | — | [diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute) |
| Pi | `pi` | — | `8090`→`8090` (RPC) | proxy-chain-network | — | [earendil-works/pi](https://github.com/earendil-works/pi) |
| QM Core | `qm-levonk-core` | — | `3104`→`8080` (Core API) | — | — | [yc-software/qm](https://github.com/yc-software/qm) |

### 🖥️ Console / Dashboard

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| n8n Grafana | `localnet-n8n-grafana` | `infra_domain_ai_n8n_grafana` (suggested) | `3108`→`3000` (Web UI) | n8n-network | `localnet-n8n-grafana-data-volume` (volume) | [n8n-io/n8n-observability](https://github.com/n8n-io/n8n-observability) |
| Traefik | `traefik` | `infra_domain_traefik_dashboard` (suggested) | `80`→`80` (HTTP)<br>`443`→`443` (HTTPS) | traefik-network | — | [traefik/traefik](https://github.com/traefik/traefik) |

### 🗄️ Passive (Databases / Caches / Queues)

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Authelia Postgres | `authelia-postgres` | — | `5432`→`5432` (PostgreSQL) | authelia-network | — | [docker-library/postgres](https://github.com/docker-library/postgres) |
| Langfuse ClickHouse | `langfuse-clickhouse` | — | `8123` (HTTP)<br>`9000` (TCP) | langfuse-network | — | [ClickHouse/ClickHouse](https://github.com/ClickHouse/ClickHouse) |
| Langfuse MinIO | `langfuse-minio` | — | `9190`→`9000` (S3 API)<br>`9001` (Console) | langfuse-network | — | [minio/minio](https://github.com/minio/minio) |
| Langfuse Postgres | `langfuse-postgres` | — | `5434`→`5432` (PostgreSQL) | langfuse-network | — | [docker-library/postgres](https://github.com/docker-library/postgres) |
| Langfuse Redis | `langfuse-redis` | — | `6379` (Redis) | langfuse-network | — | [redis/redis](https://github.com/redis/redis) |
| Langfuse Worker | `langfuse-worker` | — | `3030` (Worker) | langfuse-network | — | [langfuse/langfuse](https://github.com/langfuse/langfuse) |
| LiteLLM Postgres | `litellm-postgres` | — | `5435`→`5432` (PostgreSQL) | proxy-chain-network | — | [docker-library/postgres](https://github.com/docker-library/postgres) |
| LiteLLM Redis | `litellm-redis` | — | `6379` (Redis) | proxy-chain-network | — | [redis/redis](https://github.com/redis/redis) |
| n8n Postgres | `localnet-n8n-postgres` | — | `5438`→`5432` (PostgreSQL) | n8n-network | `localnet-n8n-postgres-data-volume` (volume) | [postgres/postgres](https://github.com/postgres/postgres) |
| n8n Prometheus | `localnet-n8n-prometheus` | — | `3107`→`9090` (Web UI) | n8n-network | `localnet-n8n-prometheus-data-volume` (volume) | [prometheus/prometheus](https://github.com/prometheus/prometheus) |
| Omnigent Postgres | `omnigent-postgres` | — | `5433`→`5432` (PostgreSQL) | proxy-chain-network | — | [docker-library/postgres](https://github.com/docker-library/postgres) |
| QM Postgres | `qm-levonk-pg` | — | `5437`→`5432` (PostgreSQL) | qm-levonk | `localnet-qm-postgres-data-volume` (volume) | [docker-library/postgres](https://github.com/docker-library/postgres) |
| RustFS | `localnet-rustfs` | `infra_domain_storage_rustfs` (suggested)<br>`infra_domain_storage_rustfs_console` (suggested) | `9000`→`9000` (S3 API)<br>`9001`→`9001` (Console) | — | `localnet-rustfs-data-volume` (volume) | [rustfs/rustfs](https://github.com/rustfs/rustfs) |
| WorldMonitor Redis | `worldmonitor-redis` | — | `8079`→`80` (Redis REST) | worldmonitor-net | `worldmonitor-redis-data` (volume) | [redis/redis](https://github.com/redis/redis) |

### 🔗 Proxy Chain (Internal)

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Forge | `forge` | — | `8083`→`8081` (API) | forge-network | — | [antoinezambelli/forge](https://github.com/antoinezambelli/forge) |
| Gost Egress | `localnet-proxy-gost` | — | `11080`→`1080` (SOCKS5) | localnet-network | — | [go-gost/gost](https://github.com/go-gost/gost) |
| Headroom | `headroom` | `infra_domain_ai_aishrink` (suggested) | `8787`→`8787` (API) | — | — | [chopratejas/headroom](https://github.com/chopratejas/headroom) |
| iron-proxy | `iron-proxy` | — | `8080` (HTTP)<br>`8443` (HTTPS) | proxy-chain-network | — | [ironsh/iron-proxy](https://github.com/ironsh/iron-proxy) |
| MITM Proxy | `mitmproxy` | — | `3128`→`3128` (HTTP Proxy) | localnet-network | — | [mitmproxy/mitmproxy](https://github.com/mitmproxy/mitmproxy) |
| Nix ncro (cno) | `localnet-nix-ncro-cno` | — | `4525`→`8081` (HTTP (internal, behind ncps)) | traefik-network | — | [manic-systems/ncro](https://github.com/manic-systems/ncro) |
| Nix ncro (nl) | `localnet-nix-ncro` | — | `4525`→`8081` (HTTP (internal, behind ncps)) | traefik-windows-network | — | [manic-systems/ncro](https://github.com/manic-systems/ncro) |
| Privacy Orchestrator | `privacy-orchestrator` | — | `8082`→`8082` (API) | proxy-chain-network | — | [levonk/ai-dashboard](https://github.com/levonk/ai-dashboard) |
| Privoxy | `privoxy` | — | `8118`→`8118` (HTTP Proxy) | localnet-network | — | [www.privoxy.org](https://www.privoxy.org/) |
| Varnish Cache | `varnish` | — | `6081`→`6081` (HTTP) | localnet-network | — | [varnishcache/varnish-cache](https://github.com/varnishcache/varnish-cache) |

### 🔒 VPN / Mesh Networking

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Host Exit Node (cno) | `—` | — | — | — | — | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| Host Exit Node (nl) | `—` | — | — | — | — | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| NordVPN | `nordvpn` | — | `51820`→`51820` (WireGuard)<br>`1080`→`1080` (SOCKS)<br>`8888`→`8888` (HTTP Proxy) | vpn-network | — | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
| NordVPN Exit Node (nl) | `nordvpn` | — | `1081`→`1080` (SOCKS)<br>`8889`→`8888` (HTTP Proxy)<br>`8444`→`8443` (HTTPS Proxy) | vpn-network | — | [qdm12/gluetun](https://github.com/qdm12/gluetun) |
| Tailscale | `tailscale` | — | `41641`→`41641` (WireGuard) | — | — | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| Tor Exit Node (cno) | `tor` | — | `9001`→`9001` (ORPort)<br>`9030`→`9030` (DirPort)<br>`9050`→`9050` (SOCKS) | tor-network | — | [torproject/tor](https://github.com/torproject/tor) |
| Tor Exit Node (nl) | `tor-exit` | — | `9011`→`9001` (ORPort)<br>`9031`→`9030` (DirPort)<br>`9051`→`9050` (SOCKS) | tor-network | — | [torproject/tor](https://github.com/torproject/tor) |
| Tor Tailscale Exit (cno) | `{{ infra_hostname_vpn_tailscale_tor }}` | — | — | tor-network | — | [torproject/tor](https://github.com/torproject/tor) |
| Tor Tailscale Exit (nl) | `{{ infra_hostname_vpn_tailscale_tor }}` | — | — | tor-network | — | [torproject/tor](https://github.com/torproject/tor) |
| VPN Tailscale Exit (cno) | `{{ infra_hostname_vpn_tailscale_nordvpn }}` | — | — | vpn-network | — | [tailscale/tailscale](https://github.com/tailscale/tailscale) |
| VPN Tailscale Exit (nl) | `{{ infra_hostname_vpn_tailscale_nordvpn }}` | — | — | vpn-network | — | [tailscale/tailscale](https://github.com/tailscale/tailscale) |

### 📡 DNS

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| CoreDNS | `coredns` | — | `15354`→`15353` (DNS)<br>`9153`→`9153` (Metrics) | localnet-network | — | [coredns/coredns](https://github.com/coredns/coredns) |
| dnsdist | `dnsdist` | — | `5501`→`5501` (DNS)<br>`8083`→`8083` (Metrics) | localnet-network | — | [PowerDNS/dnsdist](https://github.com/PowerDNS/dnsdist) |

### 🛡️ Security / SSO

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Authelia | `authelia` | `infra_domain_sso_authelia` (suggested) | `9091`→`9091` (Web) | — | — | [authelia/authelia](https://github.com/authelia/authelia) |
| CrowdSec | `crowdsec` | — | `8080`→`8080` (LAPI) | crowdsec-network | — | [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec) |
| fwknop SPA | `N/A (host-level apt service)` | — | `62271`→`62271` (SPA (UDP)) | — | — | [mrash/fwknop](https://github.com/mrash/fwknop) |

### ⚙️ Infrastructure

| Service | Container | Suggested Hostname | Port(s) (default) | Network | Storage | Source |
|---------|-----------|--------------------|-------------------|---------|---------|--------|
| Homepage | `homepage` | `infra_domain_dashboard_homepage` (suggested) | `8084`→`3000` (Web) | — | — | [gethomepage/homepage](https://github.com/gethomepage/homepage) |
| Isolation VM | `isolation-vm` | — | — | — | — | [www.qemu.org](https://www.qemu.org/) |
| kckinai Host | `kckinai` | `infra_domain_inference_host` (suggested) | — | — | — | [tailscale.com](https://tailscale.com/) |
| Local Registry | `registry` | — | `5000`→`5000` (Registry) | traefik-network | — | [distribution/distribution](https://github.com/distribution/distribution) |
| Nix Harmonia (cno) | `localnet-nix-harmonia-cno` | — | `4523`→`5000` (HTTP (local only)) | traefik-network | — | [nix-community/harmonia](https://github.com/nix-community/harmonia) |
| Nix Harmonia (nl) | `localnet-nix-harmonia` | — | `4523`→`5000` (HTTP (local only)) | traefik-windows-network | — | [nix-community/harmonia](https://github.com/nix-community/harmonia) |
| Nix ncps (cno) | `localnet-nix-ncps-cno` | `infra_domain_nix_cache_cno` (suggested) | `4524`→`8080` (HTTP (via Traefik)) | traefik-network | — | [kalbasit/ncps](https://github.com/kalbasit/ncps) |
| Nix ncps (nl) | `localnet-nix-ncps` | `infra_domain_nix_cache_nl` (suggested) | `4524`→`8080` (HTTP (via Traefik)) | traefik-windows-network | — | [kalbasit/ncps](https://github.com/kalbasit/ncps) |
| no-mistakes Gate | `localnet-no-mistakes` | `infra_domain_devops_no_mistakes` (suggested) | `2222`→`2222` (SSH Git) | traefik-windows-network | — | [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) |
| TraLa | `trala` | `infra_domain_dashboard_trala` (suggested) | `8085`→`8080` (Web) | — | — | [dannybouwers/trala](https://github.com/dannybouwers/trala) |
| Verdaccio NPM Registry (cno) | `localnet-artifact-verdaccio` | `infra_domain_artifact_verdaccio_cno` (suggested) | `4873`→`4873` (Web/API) | traefik-network | — | [verdaccio/verdaccio](https://github.com/verdaccio/verdaccio) |
| Verdaccio NPM Registry (nl) | `localnet-artifact-verdaccio-nl` | `infra_domain_artifact_verdaccio_nl` (suggested) | `4873`→`4873` (Web/API) | — | — | [verdaccio/verdaccio](https://github.com/verdaccio/verdaccio) |

---

*This file is generated by `generate_service_catalog.py`. Do not edit manually.*
*To add a service: add its ports/domains/storage to the shared infrastructure YAML files, add an entry to `services.yml` (including `source_repo`), then run `just generate-service-catalog-shared` (repo root) and `just generate-service-catalog` (client).*
