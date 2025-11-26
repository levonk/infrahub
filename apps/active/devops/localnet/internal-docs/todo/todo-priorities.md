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
- [ ] **Awesome-arr**: https://github.com/Ravencentric/awesome-arr

---

## 🖥️ Hardware & Virtualization Strategy

### Compute & Storage (Convergence Goal: 1 Server?)
- **Virtualization Server**: Proxmox VE (Containers/VMs)
  - [ ] **Productivity**: QubeOS VM
  - [ ] **Gaming**: Windows VM + GPU Passthrough
- **Storage Server**: TrueNAS Scale (ZFS)
  - [ ] **SATA Passthrough**: For direct disk access
- **Graphics / Acceleration**:
  - [ ] Transcoding (Plex/Jellyfin)
  - [ ] AI Inference (Local LLMs/Stable Diffusion)
  - [ ] Cloud Gaming

### Network Hardware
- **Firewall**: OPNsense (preferred) > pfSense > Sophos
- **Wi-Fi**: Ubiquiti Unifi
- **OOB Management**: PiKVM
- **Redundancy**: Raspberry Pi (Pi-hole/Unbound backup)

### Operating Systems & Config
- **Hypervisors**: Proxmox, TrueNAS Scale
- **Configuration Management**: Ansible
- **Orchestration**: Docker Compose, Kubernetes (k3s/k0s/Talos)

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
- [ ] **Secrets Management**: Vaultwarden: https://github.com/dani-garcia/vaultwarden
- [ ] **PKI / Certificates**:
  - [ ] Internal Certificate Authority (CA)
  - [ ] **Cert-Manager**: Automated cert lifecycle
  - [ ] **mTLS**: High-security internal app communication

### Networking & Edge Access
- [ ] **Reverse Proxy**: Traefik https://github.com/traefik/traefik
  - [ ] Plugins: Crowdsec, Geoblock
- [ ] **VPN / Mesh**:
  - [ ] **Netbird**: https://github.com/netbirdio/netbird
  - [ ] **Tailscale**: https://tailscale.com/
  - [ ] **VLESS+XTLS**: 3x-ui (Proxy/VPN)
- [ ] **Tunnels & DDNS**:
  - [ ] **Cloudflare Tunnel**: `cloudflared` (Zero Trust)
  - [ ] **FRP**: Fast Reverse Proxy https://github.com/fatedier/frp
  - [ ] **DDNS**: Cloudflare DDNS (oznu/docker-cloudflare-ddns)

### Hardening & Security Monitoring
- [ ] **Intrusion Detection**:
  - [ ] **Fail2ban**: Log parsing & banning
  - [ ] **Crowdsec**: Collaborative IPS https://github.com/crowdsecurity/crowdsec
- [ ] **Honeypot**: OpenCanary https://github.com/thinkst/opencanary
- [ ] **Drift Detection**: Etckeeper (Git for /etc)
- [ ] **AI Security Evaluation**: OpenPCC https://github.com/openpcc/openpcc

### DNS Architecture (Tiered Fallback)
*Goal: Privacy, Resilience, Ad-blocking*
- [ ] **High Availability**: `keepalived` for critical DNS endpoints
- [ ] **Layer 1 (Filtering)**: AdGuard Home + keepalived
- [ ] **Layer 2 (Routing)**: DNSDist + keepalived
- [ ] **Layer 3 (Internal)**: CoreDNS https://github.com/coredns/coredns + keepalived
- [ ] **Layer 4 (Resolution & Anonymity Chain)**:
  1. [ ] DNSCrypt: ODoH (Oblivious DoH)
  2. [ ] DNSCrypt: Non-logging servers
  3. [ ] Tor Service (Future)
  4. [ ] Unbound over Tor
  5. [ ] **Ultra Resilient Chain**:
     - DNSCrypt over Tor -> DoH over Tor -> TLS over Tor -> Plaintext

---

## 🛠️ DevOps, Observability & Automation

### CI/CD & Lifecycle
- [ ] **Updates**:
  - [ ] **Watchtower**: https://github.com/containrrr/watchtower
  - [ ] **WUD** (What's Up Docker): https://github.com/getwud/wud
- [ ] **Automation Platforms**:
  - [ ] **n8n**: Workflow automation https://n8n.io
  - [ ] **Rundeck**: Job scheduler https://github.com/rundeck/rundeck
  - [ ] **Kestrel**: Automation platform
  - [ ] **ChangeDetection.io**: Web change monitor https://github.com/dgtlmoon/changedetection.io

### Observability & Monitoring
- [ ] **Stack**: Prometheus (Metrics) + Grafana (Viz) + Loki (Logs) + OpenTelemetry
- [ ] **Status**: Uptime Kuma https://github.com/louislam/uptime-kuma
- [ ] **Server Metrics**: Beszel https://github.com/henrygd/beszel
- [ ] **Speedtest**: Speedtest Tracker https://github.com/linuxserver/docker-speedtest-tracker
- [ ] **Transparency**: Certificate Transparency Monitor https://github.com/google/certificate-transparency-go
- [ ] **Notifications**:
  - [ ] **Ntfy**: Push notifications https://github.com/binwiederhier/ntfy
  - [ ] **Logtfy**: Log notifier https://github.com/ImranR98/Logtfy

### Development Tools
- [ ] **Code / Git**: Gitea or Forgejo
- [ ] **IDE**: VS Code Server / Coder
- [ ] **Database Tools**: Django SQL Explorer https://github.com/explorerhq/django-sql-explorer
- [ ] **Data Tooling**: Goose https://github.com/block/goose
- [ ] **Notebooks**: JupyterLab
- [ ] **Project Mgmt**: Focalboard (Trello alt) https://github.com/mattermost-community/focalboard
- [ ] **API / App Building**: NocoDB (Airtable alt) https://github.com/nocodb/nocodb

---

## 🚀 Application Services

### Media & Entertainment
- [ ] **Dashboard**: Homer (Startpage) https://github.com/bastienwirtz/homer
- [ ] **Streaming**:
  - [ ] **Jellyfin**: Primary media server https://github.com/jellyfin/jellyfin
  - [ ] **Plex**: Backup / External sharing
  - [ ] **Owncast**: Self-hosted streaming https://owncast.online/
- [ ] **Acquisition (*arr Stack)**:
  - [ ] **Radarr** (Movies)
  - [ ] **Sonarr** (TV)
  - [ ] **Jackett/Prowlarr** (Indexers)
  - [ ] **SABnzbd** (Usenet) https://github.com/sabnzbd/sabnzbd
  - [ ] **DelugeVPN** (Torrents)
- [ ] **Management**:
  - [ ] **Mydia**: Video Manager https://github.com/getmydia/mydia
  - [ ] **Alt-SendMe**: Private file exchange https://github.com/tonyantony300/alt-sendme
  - [ ] **OpenBooks**: eBook downloader https://github.com/evan-buss/openbooks

### File & Content Sharing
- [ ] **Storage/Sync**:
  - [ ] **Nextcloud**: Cloud suite https://github.com/nextcloud/server
  - [ ] **Syncthing**: P2P Sync https://github.com/syncthing/syncthing
  - [ ] **FileBrowser**: Web file manager https://github.com/filebrowser/filebrowser
  - [ ] **FileCloud**: Enterprise file share
- [ ] **Photos**
  - [ ] Immich
  - [ ] PhotoPrism https://github.com/photoprism/photoprism
- [ ] **Documents**: Papermark https://github.com/mfts/papermark
- [ ] **Knowledge Base**: Outline / BookStack / CMS

### Communication & Social
- [ ] **Chat**:
  - [ ] **Revolt**: Discord Alternative https://github.com/revoltchat/
  - [ ] **Mattermost / Rocket.Chat**: Slack Alternatives
  - [ ] **Matrix / Synapse**: Federated chat
- [ ] **Social**: Mastodon https://github.com/mastodon/mastodon
- [ ] **Video/Voice**: LiveKit (Realtime A/V)
- [ ] **News**: Meridian (Personal Podcast) https://github.com/iliane5/meridian

### Artificial Intelligence (Local & Private)
- [ ] **Inference Engines**:
  - [ ] **Ollama**: LLM Runner https://github.com/ollama/ollama
  - [ ] **LocalAI**: OpenAI compatible API
  - [ ] **Nano-VLLM**: https://github.com/GeeeekExplorer/nano-vllm
- [ ] **UI & Agents**:
  - [ ] **Open WebUI**: Chat Interface https://github.com/open-webui/open-webui
  - [ ] **Browser Use**: Web automation agent https://github.com/browser-use/browser-use
  - [ ] **DeepCode**: Code agent https://github.com/HKUDS/DeepCode
  - [ ] **Skyvern**: Browser agent
  - [ ] **AgentSea**: Compute agent
- [ ] **Integration**:
  - [ ] **LiteLLM**: LLM Proxy/Router https://github.com/BerriAI/litellm
  - [ ] **ArchGW**: AI Gateway https://github.com/katanemo/archgw
  - [ ] **n8n AI**: AI workflows

### Proxies & Registries (Caching/Mirroring)
- [ ] **Container Registry**: Harbor https://github.com/goharbor/harbor
- [ ] **Package Proxies**:
  - [ ] **Verdaccio**: NPM Proxy
  - [ ] **Nexus**: Maven Proxy
  - [ ] **OpenRepo**: Deb/RPM Repo https://github.com/openkilt/openrepo
- [ ] **Generic Proxies**:
  - [ ] **Gost**: Tunnel/Proxy https://gost.run/
  - [ ] **Squid / Varnish**: Web caching
  - [ ] **Envoy**: Web Routing

---

## 📝 Backlog / To Evaluate
- [ ] **Hosting**:
  - [ ] Talos Proxmox GitOps: https://github.com/jamilshaikh07/talos-proxmox-gitops
  - [ ] Dockerage
- [ ] **OCR Tools**:
  - [ ] DeepSeek-OCR
  - [ ] Chandra: https://github.com/datalab-to/chandra
- [ ] **Agents**:
  - [ ] Laddr (Agent Runner): https://github.com/AgnetLabs/Laddr
  - [ ] Kimi-Writer
  - [ ] ChatTutor
- [ ] **Misc**:
  - [ ] TAK Server: https://github.com/TAK-Product-Center/Server
  - [ ] Chef (Convex): https://github.com/get-convex/chef
