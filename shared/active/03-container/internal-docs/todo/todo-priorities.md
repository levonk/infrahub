---
Time-created: 17:31
Date-updated: 2025-03-16T17:26
Time-updated: 17:31
Title: Home Network Architecture
Template: 00 Fleeting Thought Template
tags: [homelab, architecture, todo]
Date-Created: 2024-07-06T22:09
Date-Updated: 2025-03-08T14:49
---

# Home Network Architecture & Implementation Plan

A prioritized roadmap for building a secure, resilient, and privacy-focused homelab.

## 📚 References & Inspiration

- [ ] **TechHutTV Homelab Apps**: https://github.com/TechHutTV/homelab/tree/main/apps
- [ ] **Awesome Selfhosted**: https://github.com/Awesome-selfhosted/awesome-selfhosted
- Arr Stack
	- [ ] **Automation Ave Arr**: https://github.com/automation-avenue/arr-new/blob/main/docker-compose.yml
	- [ ] **Automation Ave Gluetun Arr**: https://github.com/automation-avenue/arr-gluetun
	- [ ] **Awesome-arr**: https://github.com/automation-avenue/arr-new/blob/main/docker-compose.yml
	- [ ] **Awesome-arr**: https://github.com/Ravencentric/awesome-arr
- [ ] Talos Proxmox GitOps: https://github.com/jamilshaikh07/talos-proxmox-gitops
- [ ] https://github.com/runtipi/runtipi

---
## Bootable USB
Ventoy USB Booter

- Persistant
	- https://github.com/Ganso/refugiOS
- LiveCD
	- Ubuntu Full
	- Debian Full
	- Debian Minimal
	- Kali
- Install
	- QubesOS
	- Windows
	- Nix
- Server
	- Alpine
	- Talos
	- Proxmox
	- Proxmox Backup
- Diagnostic
	- Memtest
	- Backup/Recovery

---

## 🖥️ Hardware & Virtualization Strategy

### Mobile
- [ ] https://github.com/ExTV/Podroid

### Firewall

- 3 Ports (WAN, DMZ, LocalNet)
- **Firewall**: (choose OPNSense)
  - [ ] **OPNsense** https://github.com/opnsense/core (preferred)
  - [ ] pfSense
  - [ ] Sophos
- Virus scan
- IDS
- IDP

### ProxMox1 Compute & Storage (Convergence Goal: 1 Server?)

- [ ] **Productivity**: QubeOS VM
- [ ] **Gaming**: Windows VM + GPU Passthrough
- **Virtualization Server**: Proxmox VE (Containers/VMs)
  - [ ] **docker** (pick portainer)
    - [ ] **PhotonOS**: Pick this for container workloads
    - [ ] **Flatpack**: Use PhotonOS over Flatpack
    - [ ] **Portainer**: https://github.com/portainer/portainer
    - [ ] **Rancher**: https://github.com/rancher/rancher
    - [ ] **Dockge**: https://github.com/louislam/dockge
    - [ ] **Semaphore**: https://github.com/semaphoreui/semaphore
  - [ ] **Talos**
    - [ ] **K8s** https://github.com/kubernetes/kubernetes
- **Storage Server**: TrueNAS Scale (ZFS + Ceph)
  - [ ] **SATA Passthrough**: For direct disk access
  - [ ] **k8s Storage Mgr**: https://github.com/longhorn/longhorn
- **Graphics / Acceleration**:
  - [ ] Transcoding (Plex/Jellyfin)
  - [ ] AI Inference (Local LLMs/Stable Diffusion)
  - [ ] Diffusion
  - [ ] **Remote Gaming**: https://github.com/ClassicOldSong/Apollo

### ProxMox2 Compute & Storage (Convergence Goal: 1 Server?)

### Network Hardware

- **Wi-Fi**: Ubiquiti Unifi
- VLAN supported Switch

### Operating Systems & Config

- **Hypervisors**: Proxmox, TrueNAS Scale
- **Configuration Management**: Ansible
- **Orchestration**: Docker Compose, Kubernetes (k3s/k0s/Talos)

### Cloud Server

- Netbird Gateway Agent Wireguard (Host instance)
- ssh-server
- tailscale
- mosh
- Dunno: TmuxAI, Zellij, both?
- Security: fail2ban, snort, IDS
- assure UTC timezone
- assure no password login
- assure authorized keys
- Neovim
- zsh
- Docker
  - Netbird Control Plane: Management Server
  - Netbird Control Plane: Signal NAT traversal helper Server
  - Netbird Control Plane: TURN fallback relay Server
  - DDNS
  - Time
  - DNS (fourth backup after proxmox1, proxmox2, local Rasberry Pi, cloud based)
  - Redundant Single Sign On
  - Caching Proxy, Reverse Proxy, Tor
  - Cert Authority
- KVM/libvirt
  - Netbird Gateway Agent Wireguard (VM instance)
  - Docker
    - Paperclip
		- Own github account
		- Own Google Account
    - OpenFang
    - Outside -> VPN + Tor -> Outside
    - Inside -> VPN -> Outside
    - RustDeskDocker - Remote Help

### Local Rasberry Pi

- DNS Third Fallback (Third backup after proxmox1, proxmox2, local Raspberry Pi, cloud based)
- KVM
- **OOB Management**: PiKVM
- Cert Authority

### Android

- GrapheneOS
- Quickscan
- (Remote access stream based Apollo) https://github.com/MobinYengejehi/Artemis
- (Remote access SPICE/VNC/RDP based)

### Secure Desktop
- Dual Boot
	- [ ] QubesOS
	- [ ] Proxmox

### Local Desktop
- Triple Boot
	- [ ] QubesOS
	- [ ] Proxmox
	- [ ] Win 11

---

## 🛡️ Platform Security & Core Infrastructure

### Network Segmentation (VLANs)

1. **Main**: Trusted devices
2. **Guest**: Isolated internet access
3. **Camera**: NVR/CCTV (No internet)
4. **IoT**: Untrusted smart devices (No internet/Limited)
5. **Test LAN**: Lab/Sandbox
6. **DMZ**: Public-facing services
7. **Storage**: Ceph/Longhorn traffic

### Identity & Access Management (IAM)

- [ ] **SSO & IdP**:
  - [ ] **Authentik** (General IdP): https://docs.goauthentik.io/
  - [ ] **Authelia** (Proxy Companion): https://www.authelia.com/
  - [ ] **Ory Kratos** (Auth Backend): https://github.com/ory/kratos
  - [ ] PocketID
  - [ ] Tinyauth
  - [ ] VoidAuth
- [ ] **Secrets Management**:
  - [ ] **Vaultwarden**: https://github.com/dani-garcia/vaultwarden
  - [ ] **BackVault**: Backup for passwords from vaultwarden
  - [ ] **Vault**: centralized service passwords management https://github.com/hashicorp/vault
  - [ ] **Hashicorp Vault**: https://github.com/hashicorp/vault
- [ ] **PKI / Certificates**:
  - [ ] Internal Certificate Authority (CA)
  - [ ] **Cert-Manager**: Automated cert lifecycle
  - [ ] **mTLS**: High-security internal app communication

### Networking & Edge Access

- [ ] **High Availability** https://github.com/acassen/keepalived
- [ ] **Reverse Proxy**:
  - [ ] FRP https://github.com/fatedier/frp (from internet to cloud to local Traefik)
  - [ ] Self-hosters https://github.com/yusing/godoxy
  - [ ] Traefik https://github.com/traefik/traefik
    - [ ] Crowdsec https://github.com/crowdsecurity/crowdsec
		- [ ] SafeLine https://github.com/chaitin/SafeLine instead?
    - [ ] Geoblock https://github.com/PascalMinder/geoblock
- [ ] **VPN Inbound / Mesh**:
  - [ ] **Netbird**: https://github.com/netbirdio/netbird
  - [ ] **Nebula**: https://github.com/
  - [ ] **Netmaker**: https://github.com/
  - [ ] **Headscale**: https://github.com/
  - [ ] **Tailscale**: https://tailscale.com/
  - [ ] **Zerotier**: https://github.com/
  - [ ] **Twingate**: https://www.twingate.com/pricing
- [ ] **VPN inter-container**
  - [ ] **GlueTun**: https://github.com/qdm12/gluetun
- [ ] **VPN Outbound**:
  - [ ] **VLESS+XTLS**: 3x-ui (Proxy/VPN) https://github.com/MHSanaei/3x-ui (example config https://github.com/56idc/3x-ui-alpine )
  - [ ] **Yggdrasil Network**: https://yggdrasil-network.github.io/
  - [ ] **Tor** https://www.torproject.org/download/tor/
  - [ ] **Cloudflare WARP**
    - [ ] https://github.com/deepwn/warpod
    - [ ] https://github.com/threatpatrols/docker-cfwarp-gost
    - [ ] https://github.com/ppmzhang2/warp-proxy
  - [ ] **WireGuard** https://github.com/angristan/wireguard-install
- [ ] **VPN Gateway**:
  - [ ] https://github.com/ginuerzh/gost
- [ ] **Tunnels & DDNS**:
  - [ ] **Cloudflare Tunnel**: `cloudflared` (Zero Trust)
  - [ ] **FRP**: Fast Reverse Proxy https://github.com/fatedier/frp
  - [ ] **DDNS**: Cloudflare DDNS (oznu/docker-cloudflare-ddns)
    - [ ] https://github.com/timothymiller/cloudflare-ddns
    - [ ] https://github.com/oznu/docker-cloudflare-ddns
- [ ] **VM**
  - [ ] **Kasm**: https://github.com/kasmtech/terraform/blob/develop/digitalocean/single_server/README.md
- [ ] Monitoring
  - [ ] internal networking layout scan https://github.com/netvisor-io/netvisor
  - [ ] internal uptime monitoring https://github.com/louislam/uptime-kuma
  - [ ] external uptime monitoring https://github.com/upptime/upptime
  - [ ] status monitoring
    - [ ] https://github.com/operacle/checkcle
    - [ ] https://github.com/cachethq/cachet

### Remote Access

- [ ] **Guacamole**: https://github.com/apache/guacamole-server https://github.com/apache/guacamole-client
- [ ] **Loopsy**: https://github.com/leox255/loopsy (mobile terminal)
- [ ] **RustDesk**: https://github.com/rustdesk/rustdesk
- [ ] **ClipCascade**: Cross Device Clipboard sharing tool
- [ ] **Termix**: https://github.com/Termix-SSH/Termix

### Hardening & Security Monitoring

- [ ] **Intrusion Detection**:
  - [ ] **Lynis**: Security Audit https://github.com/CISOfy/lynis
  - [ ] **Fail2ban**: Log parsing & banning https://github.com/fail2ban/fail2ban
  - [ ] **Crowdsec**: Collaborative IPS https://github.com/crowdsecurity/crowdsec
  - [ ] **Container Census**:
- [ ] **Honeypot**: OpenCanary https://github.com/thinkst/opencanary
- [ ] **Drift Detection**: Etckeeper (Git for /etc) https://github.com/expansible/etckeeper
- [ ] **AI Security Evaluation**: OpenPCC https://github.com/openpcc/openpcc
- [ ] **Docker Slim**: https://github.com/slimtoolkit/slim (Container Minify)
- [ ] **PruneMate**: Docker pruning for old containers
- [ ] **Secrets Management**:
  - [ ] vaultwarden
  - [ ] pass
  - [ ] Hashicorp Vault https://github.com/hashicorp/vault
- [ ] Security Monitoring
  - [ ] How others see your device activity https://github.com/gommzystudio/device-activity-tracker
  - [ ] Project Time Tracking https://github.com/solidtime-io/solidtime
  - [ ] Geo Tracking https://github.com/Freika/dawarich
  - [ ] Time Tracking (automated) https://github.com/ActivityWatch
  - [ ] Activity Tracking (excersize) https://github.com/myfear/open-pace

### DNS Architecture (Tiered Fallback)

_Goal: Privacy, Resilience, Ad-blocking_

- [ ] Security for Untrusted Workloads: https://github.com/ironsh/iron-proxy?tab=readme-ov-file
- [ ] **High Availability**: `keepalived` for critical DNS endpoints
- [ ] **Layer 1 (Filtering)**: AdGuard Home + keepalived https://github.com/AdguardTeam/AdGuardHome
- [ ] **Layer 2 (Routing)**: DNSDist + keepalived https://github.com/PowerDNS/pdns
- [ ] **Layer 3 (Internal)**: CoreDNS https://github.com/coredns/coredns + keepalived
- [ ] **Layer 4 (Resolution & Anonymity Chain)**:
  1. [ ] DNSCrypt: ODoH (Oblivious DoH) https://github.com/DNSCrypt/dnscrypt-proxy
	- [ ] ODoH Relay maybe via cloudflare workers https://github.com/serverless-dns/odoh-proxy/blob/main/index.js
  2. [ ] DNSCrypt: Non-logging servers
  3. [ ] Tor Service (Future)
  4. [ ] Unbound over Tor https://github.com/NLnetLabs/unbound
  5. [ ] **Ultra Resilient Chain**:
     - DNSCrypt over Tor -> DoH over Tor -> TLS over Tor -> Plaintext
- Other
  - [ ] Go based fast blocker https://github.com/0xERR0R/blocky

### Web Proxy

- [ ] Security for Untrusted workloads: https://github.com/ironsh/iron-proxy?tab=readme-ov-file
- [ ] **Search** (self-hosted meta-search to route through Tor) https://docs.searxng.org/
- [ ] **AI Chat** (self-hosted AI chat) https://github.com/xprivo/ai-chat
- [ ] **Marreta** (Special purpose de-annoyer) https://github.com/manualdousuario/marreta/blob/main/README.en.md
- Tiered Fallback
  - [ ] Privoxy https://www.privoxy.org/
  - [ ] Envoy https://github.com/envoyproxy/envoy
  - [ ] Varnish https://github.com/varnishcache/varnish-cache
- [ ] Proxy https://github.com/MorDavid/FlareTunnel

---

## 🛠️ DevOps, Observability & Automation

### CI/CD & Lifecycle

- [ ] Self Hosted GitHub Actions Runner https://github.com/actions/runner
- [ ] **Updates**:
  - [ ] **Watchtower**: https://github.com/containrrr/watchtower
  - [ ] **WUD** (What's Up Docker): https://github.com/getwud/wud
- [ ] **Feature Flags & Remote Configuration**:
  - [ ] **Flags SDK**: Ultra-lightweight feature flags (~5KB, file-based) https://github.com/flags-sdk/flags-sdk
  - [ ] **Unleash**: Enterprise feature management platform https://github.com/Unleash/unleash
  - [ ] **PostHog**: Analytics + feature flags combined https://github.com/PostHog/posthog
  - [ ] **Flagsmith**: Remote configuration focus https://github.com/Flagsmith/flagsmith
  - [ ] **Featurevisor**: Datafile-based architecture https://github.com/featurevisor/featurevisor
- [ ] **Automation Platforms**:
  - [ ] **n8n**: Workflow automation https://n8n.io
  - Job Scheduler
    - [ ] **Rundeck**: Job scheduler https://github.com/rundeck/rundeck
    - [ ] **Ofelia**: Job scheduler https://github.com/mcuadros/ofelia
    - [ ] **Airflow**: Job scheduler
      - alternative: https://github.com/openworkflowdev/openworkflow
  - [ ] **Kestra.io**: Automation platform https://github.com/kestra-io/kestra
  - [ ] **ChangeDetection.io**: Web change monitor https://github.com/dgtlmoon/changedetection.io

### Observability & Monitoring

- [ ] **Stack**: Prometheus (Metrics) + Grafana (Viz) + Loki (Logs) + Elasticsearch + OpenTelemetry
- [ ] **Status**: Uptime Kuma https://github.com/louislam/uptime-kuma
- [ ] **GPU Hot**: Gpu Monitoring
- [ ] **Portracker**: Monitor all the ports being used on a system
- [ ] **Server Metrics**: Beszel https://github.com/henrygd/beszel
- [ ] **Speedtest**: Speedtest Tracker https://github.com/linuxserver/docker-speedtest-tracker
- [ ] **Transparency**: Certificate Transparency Monitor https://github.com/google/certificate-transparency-go
- [ ] **Notifications**:
  - [ ] **Ntfy**: Push notifications https://github.com/binwiederhier/ntfy
  - [ ] **Logtfy**: Log notifier https://github.com/ImranR98/Logtfy
  - [ ] **Mailrise**: SMTP to Apprise Notifications https://github.com/YoRyan/mailrise
- [ ] **Logging & Metrics (logging/monitoring)**:
  - [ ] **Prometheus**: https://github.com/prometheus/prometheus
  - [ ] **Grafana**: https://github.com/grafana/grafana
  - [ ] **Loki**: https://github.com/grafana/loki
  - [ ] **Elasticsearch**: https://github.com/elastic/elasticsearch
  - [ ] **Vector**: https://github.com/vectordotdev/vector
  - [ ] **Promtail**: https://github.com/grafana/loki
  - [ ] **Jaeger**: https://github.com/jaegertracing/jaeger

### Development Tools
  - [ ] https://github.com/safishamsi/graphify
  - [ ] https://github.com/basecamp/fizzy?tab=readme-ov-file
- [ ] **CI/CD Services**:
  - [ ] https://github.com/mend/renovate-ce-ee/tree/main/docs
  - [ ] https://github.com/SonarSource/sonarqube
- [ ] **Context Manager**:
  - [ ] https://github.com/tobi/qmd
  - [ ] https://github.com/zilliztech/memsearch
- [ ] **Code / Git**:
  - [ ] **Gitea**: https://github.com/search?q=gitea&type=repositories
  - [ ] **Forgejo**: https://forgejo.org/download/#container-image
  - [ ] **GitVex**: https://github.com/mdhruvil/gitvex
- [ ] **IDE**: VS Code Server / Coder
  - [ ] https://github.com/asheshgoplani/agent-deck
- [ ] **AI Code Assist (ai-codeassist)**:
  - [ ] https://github.com/forrestchang/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md
  - [ ] https://github.com/paperclipai/paperclip https://github.com/gsxdsm/awesome-paperclip https://github.com/gsxdsm/oh-my-paperclip
  - [ ] https://github.com/AnthonyDavidAdams/zero-employee-company-book
  - [ ] Human Interaction Controller https://github.com/easychen/ask4me
  - [ ] **Code Understanding** https://github.com/HKUDS/FastCode
  - [ ] **Claude Code core service (cc-tools)**: https://github.com/Veraticus/cc-tools
  - [ ] **Everything Claude Code**: https://github.com/affaan-m/everything-claude-code
  - [ ] **Claude Code UI (claudecodeui)**: https://github.com/siteboon/claudecodeui
    - [ ] https://github.com/jarrodwatts/claude-hud
    - [ ] https://github.com/VoltAgent/awesome-agent-skills
    - [ ] skills.sh
  - [ ] **Claude Code MCP server**: https://github.com/steipete/claude-code-mcp
  - [ ] **Agent Trace**: https://agent-trace.dev/#8-reference-implementation
  - [ ] https://github.com/Th0rgal/open-ralph-wiggum
  - [ ] **LLM Proxy**: https://github.com/Fast-Editor/Lynkr
  - [ ] **PluggedIn MCP proxy**: https://github.com/VeriTeknik/pluggedin-mcp-proxy
  - [ ] **PluggedIn app**: https://github.com/VeriTeknik/pluggedin-app
  - [ ] **OpenClaw**: AI-powered automation and task management https://github.com/openclaw/openclaw (ClawdBot, MoltBot, OpenClaw)
    - [ ] **ClawRouter**: https://github.com/BlockRunAI/ClawRouter
    - [ ] **ClawHub**: https://github.com/openclaw/clawhub
- [ ] **AI Auto Agent**:
  - [ ] https://github.com/agent0ai/space-agent
  - [ ] **Hermes**: AI-powered https://github.com/NousResearch/hermes-agent
  - [ ] **IronClaw**: AI-powered automation and task management https://github.com/nearai/ironclaw
	- Alternatives
    - [ ] **OpenClaw**: AI-powered automation and task management https://github.com/openclaw/openclaw (ClawdBot, MoltBot, OpenClaw)
      - [ ] **ClawRouter**: https://github.com/BlockRunAI/ClawRouter
      - [ ] **ClawHub**: https://github.com/openclaw/clawhub
	  - https://github.com/gavrielc/nanoclaw
    - https://github.com/zeroclaw-labs/zeroclaw
    - https://github.com/bytebot-ai/bytebot
  - Desktop Control
	- [ ] **OpenClaudeCowork**: https://github.com/ComposioHQ/open-claude-cowork/
  - [ ] **Pi CodeAssist Agent**: https://pi.dev/
  - [ ] **LLM Memory**
    - [ ] https://github.com/plastic-labs/honcho
    - [ ] **LLM Memory Search**
      - [ ] https://github.com/tobi/qmd
  - [ ] **OpenCode**:
    - [ ] https://github.com/pedramamini/Maestro/issues/284 agent orchestrator
    - [ ] https://github.com/nrslib/takt Task Agent Koordination Tool – A multi-agent orchestration system supporting Claude Code and Codex.
  - [ ] **Compound Engineering**: https://github.com/EveryInc/compound-engineering-plugin
  - [ ] ClaudCode
    - [ ] Caludit plugin to audit how much garbage is in claude.md
  - [ ] **SuperMemory**: https://supermemory.ai/docs/deployment/self-hosting#self-hosting https://github.com/supermemoryai/supermemory
  - [ ] **Vibe Kanban / Auto-Claude rollout checklist**
    - [x] Hostname: `kanban.levonk.com`, Traefik router with Authelia + geoblock (LAN-only) — confirmed 2025-12-19.
    - [x] Runtime shape: Vibe Kanban container (Node + pnpm) per `services/ai-codeassist/vibe-kanban/`, Linux uses Sysbox+DIND, WSL uses dockerproxy; `/p` repo mount required.
      - [ ] Alternative https://github.com/BradGroux/veritas-kanban
    - [x] Opencode agent: runs as a separate container (`services/ai-codeassist/opencode-runner/`) to allow multiple instances per project; expose control API to Kanban.
    - [x] Auto-Claude runner: track upstream latest release (pin tag/digest once pulled) in `autoclaude-runner` image; integrate FastAPI shim + FalkorDB bolt URL.
    - [ ] Secrets & env required (provide before deploy):
      - `CLAUDE_CODE_OAUTH_TOKEN` (Anthropic/Claude Code OAuth for Auto-Claude CLI).
      - `AUTOCLAUDE_OPENAI_API_KEY` (or equivalent provider key if using OpenCode/GPT-based automations).
      - `KANBAN_SESSION_SECRET`, `KANBAN_AUTH_PASSWORD` (bootstrap admin for Vibe Kanban UI).
      - `OPENCODE_GITHUB_TOKEN` (repo automation), optional `GIT_SSH_PRIVATE_KEY` for multi-repo mounts.
      - `AUTHELIA_POLICY` update granting `kanban.levonk.com`.
    - [ ] Tasks:
      - Add compose fragments (base/linux/wsl) for Vibe Kanban + Opencode with Traefik labels and healthchecks.
      - Update Traefik `dynamic.yml` with `kanban.levonk.com` router/service and Authelia middleware link.
      - Extend `.env.localnet` / `env.template` with new env vars above (flag sensitive).
      - Write smoke test doc covering agent launch via Vibe Kanban -> Opencode -> Auto-Claude pipeline.
- [ ] **Database Tools**:
  - [ ] Django SQL Explorer https://github.com/explorerhq/django-sql-explorer
  - [ ] AI Agent into Databases https://github.com/agno-agi/dash
- [ ] **Data Tooling**: Goose https://github.com/block/goose
- [ ] **Notebooks**: JupyterLab https://github.com/jupyterlab/jupyterlab
- [ ] **Project Mgmt**: Focalboard (Trello alt) https://github.com/mattermost-community/focalboard
- [ ] **API / App Building**: NocoDB (Airtable alt) https://github.com/nocodb/nocodb
- [ ] Understanding
  - [ ] **repo-swarm**: https://github.com/royosherove/repo-swarm
- [ ] Local Cloud
  - [ ] K3s - Kubernetes dev environment
    - [ ] k8s monitoring - https://github.com/skyhook-io/radar
  - [ ] Dokploy.com - self hosted VPS
  - [ ] https://github.com/localstack/localstack - Self hosted Dev AWS
  - [ ] openstack - Self hosted full scale AWS
  - [ ] Blob Storage
    - [ ] https://github.com/deuxfleurs-org/garage (geo-distributed)
    - [ ] https://github.com/rustfs/rustfs (fast local)
    - [ ] https://github.com/minio/minio (legacy de-opensourced)
    - [ ] https://github.com/seaweedfs/seaweedfs

---

## 🚀 Application Services

### Media & Entertainment

- [ ] **Dashboard**:
  - [ ] Homer (Startpage) https://github.com/bastienwirtz/homer
  - [ ] **Glance**: https://github.com/glanceapp/glance
  - [ ] **Glances**: System monitoring dashboard https://github.com/nicolargo/glances
    - [ ] **Example config**: https://gist.github.com/PiiiRKO/8d879b2bcf9366ab3843326b3655a40b?raw=true
  - [ ] **Homepage**: Homepage (Startpage)
- Info: https://github.com/search?q=arr-stack&type=repositories
- [ ] **Streaming**:
  - [ ] **Jellyfin**: Primary media server https://github.com/jellyfin/jellyfin
    - [ ] **Skip Intro**: https://github.com/ClassicOldSong/SkipIntro plugin a must
    - [ ] https://github.com/mmcdole/kino
  - [ ] **Jellyfin Swarm**: link friends servers in
  - [ ] **JellyfinTV**: TV channels for Jellyfin https://github.com/DrewThomasson/JellyfinTV
  - [ ] **Plex**: Backup / External sharing https://www.plex.tv/media-server-downloads/?cat=computer&plat=windows#plex-media-servertwingate
    - [ ] https://github.com/trentferguson/homescreen-hero
  - [ ] **Emby**: alternative for Plex
  - [ ] **Notifiarr**: notifications https://github.com/Notifiarr/notifiarr
  - [ ] **Tracearr**: https://github.com/connorgallopo/Tracearr
  - [ ] **Owncast**: Self-hosted streaming https://owncast.online/
  - [ ] **Apollo**: Gaming Remote Play Streaming https://github.com/ClassicOldSong/Apollo
  - [ ] **Audiobookshelf**: audiobook and podcast player https://github.com/audiobookshelf/audiobookshelf
  - [ ] https://github.com/calibrain/shelfmark
  - [ ] **Miniflux**: Opinionated minimal feed reader https://github.com/miniflux/miniflux
  - [ ] Add context to subtitles https://github.com/ponzischeme89/Sublogue
- [ ] **Acquisition (\*arr Stack)**:
  - [ ] **MediaManager** (Unified Movies & TV alpha software) https://github.com/maxdorninger/MediaManager
  - [ ] **Radarr** (Movies) https://github.com/Radarr/Radarr
  - [ ] **Sonarr** (TV) https://github.com/Sonarr/Sonarr
  - [ ] **Tdarr** (video processing) https://docs.tdarr.io/docs/installation/docker/run-compose https://github.com/HaveAGitGat/Tdarr
  - [ ] **Unpackarr** (download archive unpacker) https://github.com/Unpackerr/unpackerr
  - [ ] **Recyclarr** (CLI tool to sync TRaSH Guides for quality profiles, formats, naming into Sonarr/Radarr)
  - [ ] **FlareSolverr** (proxy to bypass Cloudflare/DDoS-GUARD protections for scrapers and indexers)
  - [ ] **Scraper**
    - [ ] https://github.com/saifyxpro/HeadlessX
    - [ ] https://github.com/mnemosynestack/doppelganger
  - [ ] **Bazarr** (Subtitles) https://github.com/morpheus65535/bazarr
  - [ ] **Medusa** (TV Downloader) https://pymedusa.com/
  - [ ] **Lidarr** (Music) https://lidarr.audio/
    - [ ] https://github.com/Nezreka/SoulSync
  - [ ] Lidarr Request Manager https://github.com/lklynet/aurral
  - [ ] **Lidify** (Music Favs) https://github.com/Chevron7Locked/lidify
  - [ ] **Your Spotify** (Music) https://github.com/Yooooomi/your_spotify
  - [ ] **Your LastFM** (Music) https://github.com/Gomaink/your_lastfm
  - [ ] **Agregarr** Movie & TV Aggregator for collections
  - [ ] **Boxarr** Movie charts
  - [ ] **Releasarr** (Music)
  - [ ] **Suggesterr** Make Movie and TV recomendations of what to watch based on history
  - [ ] **IPTV** https://github.com/Dispatcharr/Dispatcharr
  - [ ] **Whisparr** (Video) https://whisparr.com/
  - [ ] **Flexget**: Misc https://github.com/Flexget/Flexget
  - [ ] **Kapowarr**: (Comics) https://github.com/Casvt/Kapowarr
  - [ ] **Deduparr** https://github.com/deduparr-dev/deduparr (Dedupe with video duplicates considering quality)
  - [ ] **Notifiarr** https://github.com/Notifiarr/notifiarr
  - [ ] **Huntarr** https://github.com/plexguide/Huntarr.io
  - [ ] **Swaparr** https://github.com/ThijmenGThN/swaparr
  - [ ] **Romm** Games and Roms https://romm.app/ https://github.com/rommapp/romm
    - [ ] https://github.com/sam1am/backlogia
  - [ ] **Posterizarr** Arr-stack artwork manager https://github.com/Posterizarr/Posterizarr
  - [ ] Indexers
    - [ ] https://github.com/Prowlarr/Prowlarr
    - [ ] https://github.com/Jackett/Jackett
  - [ ] **SABnzbd** (Usenet) https://github.com/sabnzbd/sabnzbd
- [ ] **Management**:
  - [ ] **XPipte**: Connection Manager https://github.com/xpipe-io/xpipe
  - [ ] **Mydia**: Video Manager https://github.com/getmydia/mydia
  - [ ] **Rclone Gui**: https://rclone.org/gui/ https://github.com/rclone/rclone
  - [ ] **Enclosed**: Private Note exchange https://github.com/CorentinTh/enclosed
  - [ ] **MicroBin**: Private PasteBin https://github.com/microbin/microbin
  - [ ] **OpenBooks**: eBook downloader https://github.com/evan-buss/openbooks
    - [ ] https://github.com/crocodilestick/Calibre-Web-Automated
  - [ ] **Stash**: https://github.com/stashapp/stash
- [ ] Conversion
  - [ ] https://github.com/VERT-sh/VERT
  - [ ] ffmpeg

### File & Content Sharing

- [ ] **Storage/Sync**:
  - [ ] **Nextcloud**: Cloud suite https://github.com/nextcloud/server
  - [ ] **Syncthing**: P2P Sync https://github.com/syncthing/syncthing
  - [ ] **FileBrowser**: Web file manager https://github.com/filebrowser/filebrowser
  - [ ] **FileCloud**: Enterprise file share https://github.com/filecloud/filecloud
    - [ ] https://github.com/safebucket/safebucket
  - [ ] **Paperless-ngx**: Document Management System https://github.com/paperless-ngx/paperless-ngx
  - [ ] **PageIndex**: Document Analysis System https://github.com/VectifyAI/PageIndex
- [ ] **File Transfer**
  - [ ] **Alt-SendMe**: Private file exchange https://github.com/tonyantony300/alt-sendme
  - [ ] **Locker**: Private file exchange https://github.com/zmeyer44/Locker
  - [ ] https://github.com/fatedier/fft
  - [ ] Torrents
    - [ ] **Qbittorrent**: Torrent Client https://github.com/c0re100/qBittorrent-Enhanced-Edition https://github.com/qbittorrent/qBittorrent
    - [ ] **QUI**: qbittorrent wrapper that allows multiple torrents (different networks)
    - [ ] **AutoBrr**: Torrent seeding boost manager https://github.com/autobrr/autobrr
    - [ ] **Deluge**: Torrent Client https://github.com/deluge-torrent/deluge
- [ ] **Calendar**
  - [ ] **Radicale**: FOSS CalDAV and CardDAV server https://github.com/radicale/radicale
- [ ] **Music**
  - [ ] https://github.com/HeartMuLa/heartlib
  - [ ] https://github.com/supunlakmal/hash-calendar
- [ ] **Photos**
  - [ ] Immich https://github.com/immich-app/immich
  - [ ] Immichframe
  - [ ] PhotoPrism https://github.com/photoprism/photoprism
- [ ] **Document Specifics**:
  - [ ] PDF:
    - [ ] https://github.com/PDFCraftTool/pdfcraft
    - [ ] https://github.com/alam00000/bentopdf
    - [ ] https://github.com/libpdf-js/core
- [ ] **Documents Management**:
  - [ ] **Papermark AI**:
  - [ ] **Papermark-ngx**:
  - [ ] **Papermark**: https://github.com/mfts/papermark
- [ ] **Knowledge Base**:
  - [ ] Outline / BookStack / CMS
  - [ ] AirTable alternative https://github.com/baserow/baserow https://baserow.io/

### Communication & Social

- [ ] **Multi Publish**:
  - [ ] https://github.com/yikart/AiToEarn/blob/main/README_EN.md#use-source
- [ ] **Chat**:
  - [ ] **Revolt**: Discord Alternative https://github.com/revoltchat/
  - [ ] Slack Alternative
    - [ ] **Mattermost without limits**: https://framagit.org/framasoft/framateam/mostlymatter https://github.com/mattermost/mattermost
    - [ ] **Rocket.Chat**: https://github.com/RocketChat/Rocket.Chat
  - [ ] **Matrix**: Federated chat https://github.com/matrix-org
    - [ ] Catalog of Matrix Servers: https://matrix.org/ecosystem/servers/
    - [ ] **Synapse**: https://github.com/element-hq/synapse
    - [ ] https://github.com/matrix-construct/tuwunel
    - [ ] https://gitlab.com/famedly/conduit
    - [ ] https://forgejo.ellis.link/continuwuation/continuwuity
    - [ ] https://github.com/element-hq/dendrite
    - [ ] https://git.telodendria.io/Telodendria/Telodendria
- [ ] **Social**: Mastodon https://github.com/mastodon/mastodon
- [ ] **Video/Voice**:
  - [ ] Video Meet: https://jitsi.org/jitsi-meet/
  - [ ] Video Meetings: https://github.com/miroslavpejic85/mirotalk https://p2p.mirotalk.com/
  - [ ] Text to Voice:
    - [ ] Text to Voice: https://github.com/resemble-ai/chatterbox
  - [ ] Voice to Text:
  	- https://github.com/huggingface/distil-whisper
  	- https://github.com/remsky/Kokoro-FastAPI
  - Interactive Voice Chat Telephony capable
	- [ ] Asterisk Voice (Realtime A) https://github.com/hkjarral/Asterisk-AI-Voice-Agent
	- [ ] LiveKit (Realtime A/V) https://github.com/livekit
- [ ] **News**: Meridian (Personal Podcast) https://github.com/iliane5/meridian
- [ ] **Linkstack.org**: (Linktree alternative) https://linkstack.org/
- [ ] **Family Tree**: https://github.com/smestern/treepilot
- [ ] **Postiz-app**: (multi-social poster) https://github.com/gitroomhq/postiz-app
- [ ] **Fider**: (Feedback collector) https://github.com/getfider/fider
- [ ] **CRM**: Self-hosted customer relationship management
  - [ ] **https://twenty.com/**: https://github.com/twentyhq/twenty https://docs.twenty.com/developers/self-hosting/docker-compose
  - [ ] **SuiteCRM**: https://suitecrm.com/
  - [ ] **Vtiger**: https://www.vtiger.com/

### Artificial Intelligence (Local & Private)

- [ ] **AI API Routers**:
  - [ ] https://github.com/diegosouzapw/OmniRoute
    - [ ] https://github.com/decolua/9router
- [ ] **Inference Engines**:
  - [ ] **Ollama**: LLM Runner https://github.com/ollama/ollama
  - [ ] **LocalAI**: OpenAI compatible API
  - [ ] **Nano-VLLM**: https://github.com/GeeeekExplorer/nano-vllm
- [ ] **UI & Agents**:
  - [ ] **Chat Interface**
    - [ ] **Onyx**: Chat Interface https://github.com/onyx-dot-app/onyx
    - [ ] **Open WebUI**: Chat Interface https://github.com/open-webui/open-webui
  - [ ] **Browser Automation**
    - [ ] **Agent Browser**: https://github.com/vercel-labs/agent-browser
    - [ ] **Stagehand**: https://github.com/browserbase/stagehand
      - [ ] **Browser Base**:
    - [ ] **Browser Use**: Web automation agent https://github.com/browser-use/browser-use
  - [ ] **DeepCode**: Code agent https://github.com/HKUDS/DeepCode
  - [ ] **Skyvern**: Browser agent https://github.com/Skyvern-AI/skyvern
  - [ ] **AgentSea**: Compute agent https://github.com/agentsea/surfkit https://www.agentsea.ai/
  - [ ] **Manus Replacement**: https://github.com/OthmanAdi/planning-with-files
  - [ ] **OpenScouts**: Web AI Notifier https://github.com/firecrawl/open-scouts
- [ ] **Stable Diffusion**
  - [ ] **ComfyUI**: https://github.com/comfyanonymous/ComfyUI https://www.comfy.org/
- [ ] **Text to Speech**
  - [ ] **Qwesn3-TTS**: https://huggingface.co/spaces/Qwen/Qwen3-TTS
  - [ ] **Kokorotts**: https://kokorotts.net/
- [ ] **Integration**:
  - [ ] **LiteLLM**: LLM Proxy/Router https://github.com/BerriAI/litellm
  - [ ] **ArchGW**: AI Gateway https://github.com/katanemo/archgw
  - [ ] **n8n AI**: AI workflows

### Proxies & Registries (Caching/Mirroring)

- [ ] **Container Registry**: Harbor https://github.com/goharbor/harbor
- [ ] **Package Proxies**:
  - [ ] **Supply Chain Monitor**: PyPI and NPM Security Monitor https://github.com/elastic/supply-chain-monitor
  - [ ] **Verdaccio**: NPM Proxy https://github.com/verdaccio/verdaccio
  - [ ] **turbo-cache**: https://github.com/brunojppb/turbo-cache-server
  - [ ] **Nexus**: Maven Proxy https://github.com/sonatype/nexus-public
  - [ ] **OpenRepo**: Deb/RPM Repo https://github.com/openkilt/openrepo
  - [ ] **Garnix-Yensid**: Nix Repo https://github.com/garnix-io/yensid
- [ ] **Generic Proxies**:
  - [ ] **Gost**: Tunnel/Proxy https://gost.run/
  - [ ] **Squid / Varnish**: Web caching
  - [ ] **Envoy**: Web Routing

### Code Creation
- [ ] CodeAssist AI Stats https://github.com/git-ai-project/git-ai
- [ ] TUI for Git diff changes https://github.com/remorses/critique
- [ ] OpenCode
- [ ] Claude Code https://github.com/anthropics/claude-code
- [x] **Update Swift Boilerplate Template**: Updated to comply with Rust template standards
  - [ ] **Test Swift Implementation**: Materialize and test Swift template on Mac system
    - **BLOCKED**: Requires macOS system with Swift installed
    - **Notes**: Swift not available on current Linux system, need Mac for testing
      - [ ] https://github.com/akitaonrails/FrankMD
      - [ ] https://github.com/outline/outline

### Content Creation

- [ ] NCA Toolkit API https://github.com/stephengpope/no-code-architects-toolkit
- [ ] Web->Vieo https://github.com/trycua/launchpad
- [ ] Udemy learning: https://github.com/heliomarpm/udemy-downloader-gui/
- [ ] video creation https://github.com/Godzilla675/clip-js-copilot
  - [ ] Video editing https://github.com/kevinbadi/hyperedit

---

## 📝 Backlog

- Learning
  - [ ] https://github.com/HKUDS/DeepTutor
- [ ] **CLI Tools**:
  - [ ] YouTube downloader https://github.com/yt-dlp/yt-dlp
  - [ ] Why is this Running? https://github.com/pranshuparmar/witr
- [ ] **OCR Tools**:
  - [ ] Mistral OCR3: https://mistral.ai/news/mistral-ocr-3
  - Alternatives
    - [ ] https://github.com/ocrbase-hq/ocrbase   Easy to use state of the art VLM(ocr+llm) via SDK & API. (📄 PDF ->.MD/.JSON). Self-hostable.
    - [ ] DeepSeek-OCR2: https://github.com/deepseek-ai/DeepSeek-OCR-2
	- [ ] https://github.com/zai-org/GLM-OCR
  - [ ] Chandra: https://github.com/datalab-to/chandra
- [ ] **Agents**:
  - [ ] Laddr (Agent Runner): https://github.com/AgnetLabs/Laddr
  - [ ] Kimi-Writer https://github.com/Doriandarko/kimi-writer
  - [ ] ChatTutor https://github.com/HugeCatLab/ChatTutor
- [ ] **Misc**:
  - [ ] TAK Server: https://github.com/TAK-Product-Center/Server
  - [ ] Chef (Convex): https://github.com/get-convex/chef
  - [ ] SparkyFitness: https://github.com/CodeWithCJ/SparkyFitness
  - [ ] Web VSCode: https://search.nixos.org/packages?channel=25.11&show=openvscode-server&query=vscode-server

- [ ] **Finance**:
	- [ ] Personal Finance Tracker https://github.com/we-promise/sure/
	- [ ] Actual Budget: https://github.com/actualbudget/actual
	- [ ] AI Investors
	  - [ ] https://github.com/ygwyg/MAHORAGA
- [ ] **Investigate**:
	- [ ] URL Shortener - https://github.com/SinTan1729/chhoto-url
	- [ ] WunderTech - Task management and productivity
	- [ ] Heimdall - Dashboard and link organizer
	- [ ] Genmon - System monitoring and status dashboard
    - [ ] https://github.com/mostafa-wahied/portracker
    - [ ] https://github.com/techfort/cronpulse-community
    - [ ] https://github.com/bluewave-labs/checkmate
	- [ ] Hubitat - Home automation platform
  - [ ] https://github.com/surajverma/homehub
  - [ ] https://github.com/iib0011/omni-tools
	- [ ] Grocy - Grocery management and recipe organizer
	- [ ] Logger - Log aggregation and analysis
	- [ ] CodeProject.AI - AI platform with local inference capabilities
	- [ ] NPM - Node Package Manager for JavaScript applications
	- [ ] NUT Server - Network UPS Tools for power management
	- [ ] DSM - Disk Station Manager for Synology devices
	- [ ] Blue Iris - Security camera management and recording
	- [ ] Code Security Analyzer - https://github.com/SecurityCrux/secrux
- [ ] **From OLD Architecture Doc (additional tools & references)**:
  - [ ] **Media, Downloading & Dashboards**
    - [ ] http://github.com/bastienwirtz/homer --- Homelab / service dashboard
    - [ ] https://github.com/theMK2k/Media-Hoarder --- Media library management / hoarding helper
      - https://github.com/Kyonew/DVinyl
    - [ ] https://github.com/alexta69/metube --- Self-hosted YouTube/media downloader
    - [ ] https://github.com/jdepoix/youtube-transcript-api - Youtube transcripts MCP
    - [ ] https://github.com/JMS1717/8mb.local --- Video size reduction / 8MB-style sharing helper
    - [ ] https://github.com/askreeves/ffmpeg-interface --- Web UI / interface around ffmpeg
    - [ ] https://github.com/librespeed/speedtest-rust --- Self‑hosted internet speed test (Rust)
    - [ ] https://sabnzbd.org/ --- Official SABnzbd site (Usenet downloader)
  - [ ] **Backups & Sync**
    - [ ] https://github.com/duplicati/duplicati --- Encrypted, versioned backup system with deduplication
    - [ ] ZeroByte Backup --- Encrypted, versioned backup system
    - [ ] Velld Database backups
    - [ ] Bichon Email backups
	- [ ] Map / Trip / POI Planner https://github.com/itskovacs/trip
	- [ ] Email https://github.com/wesm/msgvault
	- [ ] Email Organization https://github.com/Lakshay1509/NeatMail
  - [ ] **Bookmarks, Reading & Knowledge**
    - [ ] https://github.com/FreshRSS/FreshRSS --- Self‑hosted RSS/news aggregator
    - [ ] https://github.com/karakeep-app/karakeep --- Personal knowledge / bookmark manager previously Hoarder
    - [ ] https://github.com/asciimoo/omnom --- Simple bookmark manager with screenshots
    - [ ] https://github.com/linkwarden/linkwarden --- Bookmark archiver and organizer
    - [ ] https://github.com/linkwarden/browser-extension --- Browser extension companion for Linkwarden
	- [ ] https://github.com/lyqht/mini-qr --- Mini Privacy First QR Code Generator
    - [ ] https://github.com/rtuszik/starwarden --- Star/bookmark sync utility for Linkwarden
    - [ ] https://github.com/omnivore-app/omnivore --- Read‑it‑later service (Instapaper/Pocket alternative)
	- [ ] https://anytype.io/ --- Open Source Notion for collaboration
    - [ ] https://brainsteam.co.uk/2025/2/15/personal-archive-hoarder/ --- Article on building a personal bookmark/archive server
    - [ ] https://github.com/grishy/any-sync-bundle - sync everything locally
  - [ ] **Automation, Agents & AI Utilities**
    - [ ] https://github.com/coze-dev/coze-loop --- Prompt playground for iterating on prompts
    - [ ] https://github.com/trymeka/agent --- Browser automation / web agent framework
    - [ ] https://github.com/aaronvstory/13ft-enhanced --- Googlebot-style page grabber (bypass paywall-like blocks)
    - [ ] https://github.com/n8n-io/self-hosted-ai-starter-kit --- n8n AI integration starter kit (AI workflows as a service)
    - [ ] https://github.com/zai-org/GLM-4.5 --- Strong LLM model reference (GLM‑4.5)
    - [ ] https://ollama.com/download --- Ollama download page
    - [ ] https://ollama.com/library/dolphin-mixtral --- Unfiltered Dolphin-Mixtral model in Ollama library
  - [ ] **Dev & Ops Tools**
    - [ ] https://github.com/explorerhq/django-sql-explorer?tab=readme-ov-file --- Django SQL Explorer docs (DB query tool)
    - [ ] https://github.com/go-gitea/gitea --- Lightweight self‑hosted Git service
    - [ ] https://github.com/iib0011/omni-tools --- Developer utilities / multi‑tool collection
    - [ ] https://github.com/moghtech/komodo --- Kubernetes management / dashboard platform
    - [ ] https://github.com/opslane/opslane --- Ops/infra orchestration platform
    - [ ] https://github.com/phpipam/phpipam --- IP address management (IPAM)
    - [ ] https://github.com/rcourtman/Pulse --- Network/server monitoring dashboard
    - [ ] https://github.com/amir20/dozzle --- Real‑time container log viewer (Docker)
    - [ ] https://github.com/dockpeek/dockpeek --- Container management and monitoring
    - [ ] https://github.com/pendulum-project/ntpd-rs --- NTP daemon in Rust
    - [ ] https://github.com/pendulum-project/statime --- PTP (Precision Time Protocol) daemon
    - [ ] https://github.com/YunoHost-Apps --- YunoHost app catalog (packaged self‑hosted apps)
    - [ ] https://github.com/YunoHost-Apps/invoiceninja5_ynh --- InvoiceNinja YunoHost package (invoicing)
	- [ ] https://github.com/pixlcore/xyops IT workflow management
      - [ ] https://github.com/piratuks/invoice-builder
  - [ ] **Networking, Edge & Tunnels**
    - [ ] https://docs.pangolin.net/ --- Pangolin docs (reverse proxy / tunnel)
    - [ ] https://github.com/octelium/octelium --- Zero‑trust / tunnel‑related tool (Octelium)
    - [ ] https://github.com/fosrl/pangolin --- Pangolin reverse proxy/tunneling service
    - [ ] https://github.com/cloudflare/cloudflared/blob/master/Dockerfile#L29C6-L29C13 --- Cloudflared Docker reference (Zero‑Trust tunnel)
    - [ ] Cloud Init https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/
    - [ ] https://netboot.xyz/docs/docker/ --- Netboot.xyz PXE boot via Docker
      - [ ] Desktop
        - [ ] Win11 (Gaming)
        - [ ] Linux
          - [ ] Ubuntu desktop
          - [ ] Debian DVD-1
          - [ ] Debian live
          - [ ] Parrot
          - [ ] QubesOS (Daily Driver)
      - [ ] Service
        - [ ] Proxmox
        - [ ] netboot
        - [ ] Linux
          - [ ] Ubuntu server
          - [ ] Ubuntu live-server
          - [ ] Debian netinst
          - [ ] Talos
          - [ ] alpine-virt
          - [ ] alpine-standard
          - [ ] alpine-extended
      - [ ] Both
        - [ ] Mt86plus
        - [ ] Tails

    - [ ] https://github.com/octelium/octelium --- Zero‑trust / tunnel‑related tool (Octelium)
    - [ ] https://www.libhunt.com/compare-pangolin-vs-frp --- Comparison article: Pangolin vs FRP
    - [ ] https://www.xda-developers.com/cloudflare-tunnels-easier-to-manage-free-open-source-self-hosted-tool/ --- Article: Cloudflare Tunnels overview
    - [ ] https://www.xda-developers.com/enabled-https-secure-self-hosted-apps-tailscale/ --- Article: HTTPS with Tailscale
    - [ ] https://www.xda-developers.com/how-are-cloudflare-tunnels-different-from-a-vpn/ --- Cloudflare Tunnels vs VPN
    - [ ] https://www.xda-developers.com/tailscale-guide/ --- Tailscale setup/usage guide

  - [ ] **Home Automation & 3D Printing**
    - [ ] http://octoprint.org/ --- OctoPrint main site (3D printer management)
    - [ ] https://github.com/OctoPrint/OctoPrint --- OctoPrint GitHub repo
    - [ ] https://github.com/home-assistant/ --- Home Assistant (home automation platform)
  - [ ] **Other Services & Utilities**
    - [ ] LanguageTool grammer checker https://dev.languagetool.org/http-server
    - [ ] freenet.org
    - [ ] Price tracking https://github.com/clucraft/PriceGhost
    - [ ] SmartSDR for Linux from Simon Ritchie (NVOE) @ Tech Connect Radio Club (NA0TC)
    - [ ] NetClaw from John Capobianco
    - [ ] https://github.com/DaKheera47/job-ops
	- [ ]  resume optimizer https://github.com/btseytlin/hr-breaker
    - [ ] https://github.com/gchq/CyberChef --- CyberChef (web-based data transform toolkit)
    - [ ] https://github.com/kasmtech/KasmVNC --- Web-based VNC viewer (browser VNC)
    - [ ] https://github.com/Elbullazul/LinkGuardian --- Bookmark/link guardian / archiving helper
    - [ ] https://github.com/pkulium/DeepOCR --- OCR library/tool
	- [ ] https://github.com/majcheradam/ocrbase --- OCR library/tool
    - [ ] https://github.com/666ghj/BettaFish/blob/main/README-EN.md --- Social sentiment monitoring tool (BettaFish)
    - [ ] https://github.com/rtuszik/starwarden --- Extra tooling around Linkwarden/Star management
    - [ ] https://github.com/trymeka/agent --- Browser automation agent (duplicate reference, kept for visibility)
	- [ ] https://github.com/ellite/Wallos --- OSS Personal Finance Subscription Tracker Tool
	- [ ] https://github.com/madalinpopa/gocost-web --- OSS Personal Finance Subscription Tracker Tool
    - [ ] WebMin server maangement web interface
	- [ ] Postiz Social media management https://github.com/gitroomhq/postiz-app
	- [ ] Software Defined Radio https://github.com/smittix/intercept
  - [ ] **References & Articles**
    - [ ] https://brainsteam.co.uk/2025/2/15/personal-archive-hoarder/ --- Personal archive/hoarder architecture write‑up
    - [ ] https://www.xda-developers.com/how-build-google-drive-alternative-nextcloud/ --- Guide: Nextcloud as Google Drive alternative
    - [ ] https://www.xda-developers.com/how-built-google-photos-alternative-nas-photoprism/ --- Guide: PhotoPrism as Google Photos alternative
    - [ ] https://www.xda-developers.com/how-i-replaced-all-these-streaming-services-with-one-self-hosted-app/ --- Jellyfin streaming replacement story
    - [ ] https://www.youtube.com/watch?v=Wjrdr0NU4Sk --- Video walkthrough of Open-WebUI + LiteLLM setup
	- [ ] https://www.reddit.com/r/selfhosted/comments/1p4g508/theres_no_place_like_127001_my_complete_setup/ Nice writeup

## Standards
- Philosophy:
	- Community First
	- License Clarity
	- Reproducibility
	- Simplicity
- Instead of
	- Services
		- Redis: use Valkey unless you NEED enterprise support
		- MySQL: use Postgres unless you NEED MySQL-specific features
		- Linux: prefer NixOS
			- CentOS/RHEL clones use Rocky Linux or AlmaLinux
		- Elasticsearch: use OpenSearch
		- Kafka: use Redpanda
		- Kubernetes with Docker runtime, use containerd or CRI-I
		- Jenkins use GitHub Actions or GitLab CI
		- Terraform use OpenTofu
		- Prometheus + Grafana Cloud use self-hosted Prometheus + Frafana OSS
		- MongoDB use Postgres with JSONB
		- RabbitMQ use NATS
- Tools
	- zsh with oh-my-zsh
	- https://github.com/lucasgelfond/zerobrew instead of homebrew / brew.sh
	- Instead of
		- Docker: use podman


## References

- [[Cross Platform To Install]]
- https://github.com/BansheeTech/HomeDockOS
