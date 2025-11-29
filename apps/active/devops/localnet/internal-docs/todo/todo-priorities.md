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
- [ ] Talos Proxmox GitOps: https://github.com/jamilshaikh07/talos-proxmox-gitops

---

## 🖥️ Hardware & Virtualization Strategy

### Firewall
- 3 Ports (WAN, DMZ, LocalNet)
- **Firewall**: (choose OPNSense)
	- [ ] **OPNsense** https://github.com/opnsense/core  (preferred)
	- [ ] pfSense
	- [ ] Sophos
- Virus scan
- IDS
- IDP

### ProxMox1 Compute & Storage (Convergence Goal: 1 Server?)
- **Virtualization Server**: Proxmox VE (Containers/VMs)
  - [ ] **Productivity**: QubeOS VM
  - [ ] **Gaming**: Windows VM + GPU Passthrough
  - [ ] **docker** (pick portainer)
	  - [ ] **Portainer**: https://github.com/portainer/portainer
	  - [ ] **Dockge**: https://github.com/louislam/dockge
	  - [ ] **Semaphore**: https://github.com/semaphoreui/semaphore
  - [ ] **Talos**
	  - [ ] **K8s** https://github.com/kubernetes/kubernetes
- **Storage Server**: TrueNAS Scale (ZFS + Ceph)
  - [ ] **SATA Passthrough**: For direct disk access
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
- DDNS, Caching Proxy, VPN, Reverse Proxy, Tor
- Redundant Single Sign On
- DNS (fourth backup after proxmox1, proxmox2, local Rasberry Pi, cloud based)
- Time
- Outside -> Reverse Proxy -> In (self hosted)
- Outside -> VPN -> In
- Outside -> VPN + Tor -> Outside
- Inside -> VPN -> Outside
- Cert Authority

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
- [ ] **Secrets Management**:
	- [ ] **Vaultwarden**: https://github.com/dani-garcia/vaultwarden
	- [ ] **Hashicorp Vault**: https://github.com/hashicorp/vault
- [ ] **PKI / Certificates**:
  - [ ] Internal Certificate Authority (CA)
  - [ ] **Cert-Manager**: Automated cert lifecycle
  - [ ] **mTLS**: High-security internal app communication

### Networking & Edge Access
- [ ] **High Availability** https://github.com/acassen/keepalived
- [ ] **Reverse Proxy**:
	- [ ] FRP  https://github.com/fatedier/frp (from internet to cloud to local Traefik)
	- [ ] Traefik https://github.com/traefik/traefik
		  - [ ] Crowdsec https://github.com/crowdsecurity/crowdsec
		  - [ ] Geoblock https://github.com/PascalMinder/geoblock
- [ ] **VPN Inbound / Mesh**:
  - [ ] **Netbird**: https://github.com/netbirdio/netbird
  - [ ] **Tailscale**: https://tailscale.com/
  - [ ] **Twingate**: https://www.twingate.com/pricing
- [ ] **VPN inter-container**
	- [ ] **GlueTun**: https://github.com/qdm12/gluetun
- [ ] **VPN Outbound**:
  - [ ] **VLESS+XTLS**: 3x-ui (Proxy/VPN) https://github.com/MHSanaei/3x-ui (example config https://github.com/56idc/3x-ui-alpine )
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

### Remote Access
- [ ] **Guacamole**: https://github.com/apache/guacamole-server https://github.com/apache/guacamole-client
- [ ] **RustDesk**: https://github.com/rustdesk/rustdesk

### Hardening & Security Monitoring
- [ ] **Intrusion Detection**:
  - [ ] **Lynis**: Security Audit https://github.com/CISOfy/lynis
  - [ ] **Fail2ban**: Log parsing & banning https://github.com/fail2ban/fail2ban
  - [ ] **Crowdsec**: Collaborative IPS https://github.com/crowdsecurity/crowdsec
- [ ] **Honeypot**: OpenCanary https://github.com/thinkst/opencanary
- [ ] **Drift Detection**: Etckeeper (Git for /etc) https://github.com/expansible/etckeeper
- [ ] **AI Security Evaluation**: OpenPCC https://github.com/openpcc/openpcc
- [ ] **Docker Slim**: https://github.com/slimtoolkit/slim (Container Minify)
- [ ] **Secrets Management**:
	- [ ] vaultwarden
	- [ ] pass
	- [ ] Hashicorp Vault https://github.com/hashicorp/vault

### DNS Architecture (Tiered Fallback)
*Goal: Privacy, Resilience, Ad-blocking*
- [ ] **High Availability**: `keepalived` for critical DNS endpoints
- [ ] **Layer 1 (Filtering)**: AdGuard Home + keepalived https://github.com/AdguardTeam/AdGuardHome
- [ ] **Layer 2 (Routing)**: DNSDist + keepalived  https://github.com/PowerDNS/pdns
- [ ] **Layer 3 (Internal)**: CoreDNS https://github.com/coredns/coredns + keepalived
- [ ] **Layer 4 (Resolution & Anonymity Chain)**:
  1. [ ] DNSCrypt: ODoH (Oblivious DoH) https://github.com/DNSCrypt/dnscrypt-proxy
  2. [ ] DNSCrypt: Non-logging servers
  3. [ ] Tor Service (Future)
  4. [ ] Unbound over Tor https://github.com/NLnetLabs/unbound
  5. [ ] **Ultra Resilient Chain**:
     - DNSCrypt over Tor -> DoH over Tor -> TLS over Tor -> Plaintext

### Web Proxy
- [ ] **Marreta** (Special purpose de-annoyer) https://github.com/manualdousuario/marreta/blob/main/README.en.md
- Tiered Fallback
	- [ ] Privoxy https://www.privoxy.org/
	- [ ] Envoy https://github.com/envoyproxy/envoy
	- [ ] Varnish https://github.com/varnishcache/varnish-cache

---

## 🛠️ DevOps, Observability & Automation

### CI/CD & Lifecycle
- [ ] **Updates**:
  - [ ] **Watchtower**: https://github.com/containrrr/watchtower
  - [ ] **WUD** (What's Up Docker): https://github.com/getwud/wud
- [ ] **Automation Platforms**:
  - [ ] **n8n**: Workflow automation https://n8n.io
  - [ ] **Rundeck**: Job scheduler https://github.com/rundeck/rundeck
  - [ ] **Kestra.io**: Automation platform https://github.com/kestra-io/kestra
  - [ ] **ChangeDetection.io**: Web change monitor https://github.com/dgtlmoon/changedetection.io

### Observability & Monitoring
- [ ] **Stack**: Prometheus (Metrics) + Grafana (Viz) + Loki (Logs) + Elasticsearch + OpenTelemetry
- [ ] **Status**: Uptime Kuma https://github.com/louislam/uptime-kuma
- [ ] **Server Metrics**: Beszel https://github.com/henrygd/beszel
- [ ] **Speedtest**: Speedtest Tracker https://github.com/linuxserver/docker-speedtest-tracker
- [ ] **Transparency**: Certificate Transparency Monitor https://github.com/google/certificate-transparency-go
- [ ] **Notifications**:
  - [ ] **Ntfy**: Push notifications https://github.com/binwiederhier/ntfy
  - [ ] **Logtfy**: Log notifier https://github.com/ImranR98/Logtfy
 - [ ] **Logging & Metrics (logging/monitoring)**:
	- [ ] **Prometheus**: https://github.com/prometheus/prometheus
	- [ ] **Grafana**: https://github.com/grafana/grafana
	- [ ] **Loki**: https://github.com/grafana/loki
	- [ ] **Elasticsearch**: https://github.com/elastic/elasticsearch
	- [ ] **Vector**: https://github.com/vectordotdev/vector
	- [ ] **Promtail**: https://github.com/grafana/loki
	- [ ] **Jaeger**: https://github.com/jaegertracing/jaeger

### Development Tools
- [ ] **Code / Git**:
	- [ ] **Gitea**: https://github.com/search?q=gitea&type=repositories
	- [ ] **Forgejo**:  https://forgejo.org/download/#container-image
	- [ ] **GitVex**: https://github.com/mdhruvil/gitvex
- [ ] **IDE**: VS Code Server / Coder
- [ ] **AI Code Assist (ai-codeassist)**:
	- [ ] **Claude Code core service (cc-tools)**: https://github.com/Veraticus/cc-tools
	- [ ] **Claude Code UI (claudecodeui)**: https://github.com/siteboon/claudecodeui
	- [ ] **Claude Code MCP server**: https://github.com/steipete/claude-code-mcp
	- [ ] **PluggedIn MCP proxy**: https://github.com/VeriTeknik/pluggedin-mcp-proxy
	- [ ] **PluggedIn app**: https://github.com/VeriTeknik/pluggedin-app
- [ ] **Database Tools**: Django SQL Explorer https://github.com/explorerhq/django-sql-explorer
- [ ] **Data Tooling**: Goose https://github.com/block/goose
- [ ] **Notebooks**: JupyterLab https://github.com/jupyterlab/jupyterlab
- [ ] **Project Mgmt**: Focalboard (Trello alt) https://github.com/mattermost-community/focalboard
- [ ] **API / App Building**: NocoDB (Airtable alt) https://github.com/nocodb/nocodb
- [ ] Local Cloud
	- [ ] https://github.com/localstack/localstack
	- [ ] Blob Storage
		- [ ] https://github.com/rustfs/rustfs
		- [ ] https://github.com/minio/minio
		- [ ] https://github.com/seaweedfs/seaweedfs

---

## 🚀 Application Services

### Media & Entertainment
- [ ] **Dashboard**:
	- [ ] Homer (Startpage) https://github.com/bastienwirtz/homer
	- [ ] **Homepage**: Homepage (Startpage)
- Info: https://github.com/search?q=arr-stack&type=repositories
- [ ] **Streaming**:
  - [ ] **Jellyfin**: Primary media server https://github.com/jellyfin/jellyfin
	- [ ] **Skip Intro**: https://github.com/ClassicOldSong/SkipIntro plugin a must
  - [ ] **Plex**: Backup / External sharing https://www.plex.tv/media-server-downloads/?cat=computer&plat=windows#plex-media-servertwingate
  - [ ] **Owncast**: Self-hosted streaming https://owncast.online/
  - [ ] **Apollo**: Gaming Remote Play Streaming https://github.com/ClassicOldSong/Apollo
  - [ ] **Audiobookshelf**: audiobook and podcast player https://github.com/audiobookshelf/audiobookshelf
  - [ ] **Miniflux**: Opinionated minimal feed reader https://github.com/miniflux/miniflux
- [ ] **Acquisition (*arr Stack)**:
  - [ ] **Radarr** (Movies) https://github.com/Radarr/Radarr
  - [ ] **Sonarr** (TV) https://github.com/Sonarr/Sonarr
  - [ ] **Bazarr** (Subtitles) https://github.com/morpheus65535/bazarr
  - [ ] **Medusa** (TV Downloader) https://pymedusa.com/
  - [ ] **Lidarr** (Music) https://lidarr.audio/
  - [ ] **Whisparr** (Video) https://whisparr.com/
  - [ ] **Flexget**: Misc https://github.com/Flexget/Flexget
  - [ ] **Kapowarr**: (Comics) https://github.com/Casvt/Kapowarr
  - [ ] **Deduparr** https://github.com/deduparr-dev/deduparr (Dedupe with video duplicates considering quality)
  - [ ] Indexers
	  - [ ] https://github.com/Prowlarr/Prowlarr
	  - [ ] https://github.com/Jackett/Jackett
  - [ ] **SABnzbd** (Usenet) https://github.com/sabnzbd/sabnzbd
- [ ] **Management**:
  - [ ] **Mydia**: Video Manager https://github.com/getmydia/mydia
  - [ ] **Alt-SendMe**: Private file exchange https://github.com/tonyantony300/alt-sendme
  - [ ] **Enclosed**: Private Note exchange https://github.com/CorentinTh/enclosed
  - [ ] **MicroBin**: Private PasteBin https://github.com/microbin/microbin
  - [ ] **OpenBooks**: eBook downloader https://github.com/evan-buss/openbooks
- [ ] Conversion
	- [ ] https://github.com/VERT-sh/VERT
	- [ ] ffmpeg

### File & Content Sharing
- [ ] **Storage/Sync**:
  - [ ] **Nextcloud**: Cloud suite https://github.com/nextcloud/server
  - [ ] **Syncthing**: P2P Sync https://github.com/syncthing/syncthing
  - [ ] **FileBrowser**: Web file manager https://github.com/filebrowser/filebrowser
  - [ ] **FileCloud**: Enterprise file share https://github.com/filecloud/filecloud
  - [ ] **Paperless-ngx**: Document Management System https://github.com/paperless-ngx/paperless-ngx
- [ ] **File Transfer**
	- [ ] https://github.com/fatedier/fft
	- [ ] Torrents
		- [ ] **Qbittorrent**: Torrent Client https://github.com/qbittorrent/qBittorrent
		- [ ] **Deluge**: Torrent Client https://github.com/deluge-torrent/deluge
- [ ] **Calendar**
	- [ ] **Radicale**: FOSS CalDAV and CardDAV server https://github.com/radicale/radicale
- [ ] **Photos**
  - [ ] Immich https://github.com/immich-app/immich
  - [ ] PhotoPrism https://github.com/photoprism/photoprism
- [ ] **Documents**: Papermark https://github.com/mfts/papermark
- [ ] **Knowledge Base**:
	- [ ] Outline / BookStack / CMS
	- [ ] AirTable alternative https://github.com/baserow/baserow https://baserow.io/

### Communication & Social
- [ ] **Chat**:
  - [ ] **Revolt**: Discord Alternative https://github.com/revoltchat/
  - [ ] Slack Alternative
	  - [ ] **Mattermost**: https://github.com/mattermost/mattermost
	  - [ ] **Rocket.Chat**:  https://github.com/RocketChat/Rocket.Chat
  - [ ] **Matrix**: Federated chat https://github.com/matrix-org
	  - [ ] Catalog of Matrix Servers: https://matrix.org/ecosystem/servers/
	  - [ ] **Synapse**: https://github.com/element-hq/synapse
	  - [ ] https://github.com/matrix-construct/tuwunel
	  - [ ] https://gitlab.com/famedly/conduit
	  - [ ] https://forgejo.ellis.link/continuwuation/continuwuity
	  - [ ] https://github.com/element-hq/dendrite
	  - [ ] https://git.telodendria.io/Telodendria/Telodendria
- [ ] **Social**: Mastodon https://github.com/mastodon/mastodon
- [ ] **Video/Voice**: LiveKit (Realtime A/V) https://github.com/livekit
- [ ] **News**: Meridian (Personal Podcast) https://github.com/iliane5/meridian
- [ ] **Linkstack.org**: (Linktree alternative) https://linkstack.org/
- [ ] **Postiz-app**: (multi-social poster) https://github.com/gitroomhq/postiz-app
- [ ] **Fider**: (Feedback collector) https://github.com/getfider/fider

### Artificial Intelligence (Local & Private)
- [ ] **Inference Engines**:
  - [ ] **Ollama**: LLM Runner https://github.com/ollama/ollama
  - [ ] **LocalAI**: OpenAI compatible API
  - [ ] **Nano-VLLM**: https://github.com/GeeeekExplorer/nano-vllm
- [ ] **UI & Agents**:
  - [ ] **Chat Interface**
    - [ ] **Onyx**: Chat Interface https://github.com/onyx-dot-app/onyx
    - [ ] **Open WebUI**: Chat Interface https://github.com/open-webui/open-webui
  - [ ] **Browser Use**: Web automation agent https://github.com/browser-use/browser-use
  - [ ] **DeepCode**: Code agent https://github.com/HKUDS/DeepCode
  - [ ] **Skyvern**: Browser agent https://github.com/Skyvern-AI/skyvern
  - [ ] **AgentSea**: Compute agent https://github.com/agentsea/surfkit https://www.agentsea.ai/
- [ ] **Stable Diffusion**
	- [ ] **ComfyUI**: https://github.com/comfyanonymous/ComfyUI https://www.comfy.org/
- [ ] **Text to Speech**
	- [ ] **Kokorotts**: https://kokorotts.net/
- [ ] **Integration**:
  - [ ] **LiteLLM**: LLM Proxy/Router https://github.com/BerriAI/litellm
  - [ ] **ArchGW**: AI Gateway https://github.com/katanemo/archgw
  - [ ] **n8n AI**: AI workflows

### Proxies & Registries (Caching/Mirroring)
- [ ] **Container Registry**: Harbor https://github.com/goharbor/harbor
- [ ] **Package Proxies**:
  - [ ] **Verdaccio**: NPM Proxy https://github.com/verdaccio/verdaccio
  - [ ] **Nexus**: Maven Proxy https://github.com/sonatype/nexus-public
  - [ ] **OpenRepo**: Deb/RPM Repo https://github.com/openkilt/openrepo
- [ ] **Generic Proxies**:
  - [ ] **Gost**: Tunnel/Proxy https://gost.run/
  - [ ] **Squid / Varnish**: Web caching
  - [ ] **Envoy**: Web Routing

### Content Creation
- [ ] NCA Toolkit API https://github.com/stephengpope/no-code-architects-toolkit

---

## 📝 Backlog
- [ ] **OCR Tools**:
  - [ ] DeepSeek-OCR: https://github.com/deepseek-ai/DeepSeek-OCR
  - [ ] Chandra: https://github.com/datalab-to/chandra
- [ ] **Agents**:
  - [ ] Laddr (Agent Runner): https://github.com/AgnetLabs/Laddr
  - [ ] Kimi-Writer https://github.com/Doriandarko/kimi-writer
  - [ ] ChatTutor https://github.com/HugeCatLab/ChatTutor
- [ ] **Misc**:
  - [ ] TAK Server: https://github.com/TAK-Product-Center/Server
  - [ ] Chef (Convex): https://github.com/get-convex/chef

- [ ] **From OLD Architecture Doc (additional tools & references)**:
	- [ ] **Media, Downloading & Dashboards**
		- [ ] http://github.com/bastienwirtz/homer --- Homelab / service dashboard
		- [ ] https://github.com/theMK2k/Media-Hoarder --- Media library management / hoarding helper
		- [ ] https://github.com/alexta69/metube --- Self-hosted YouTube/media downloader
		- [ ] https://github.com/JMS1717/8mb.local --- Video size reduction / 8MB-style sharing helper
		- [ ] https://github.com/askreeves/ffmpeg-interface --- Web UI / interface around ffmpeg
		- [ ] https://github.com/librespeed/speedtest-rust --- Self‑hosted internet speed test (Rust)
		- [ ] https://sabnzbd.org/ --- Official SABnzbd site (Usenet downloader)
	- [ ] **Backups & Sync**
		- [ ] https://github.com/duplicati/duplicati --- Encrypted, versioned backup system
	- [ ] **Bookmarks, Reading & Knowledge**
		- [ ] https://github.com/FreshRSS/FreshRSS --- Self‑hosted RSS/news aggregator
		- [ ] https://github.com/karakeep-app/karakeep --- Personal knowledge / bookmark manager
		- [ ] https://github.com/linkwarden/linkwarden --- Bookmark archiver and organizer
		- [ ] https://github.com/linkwarden/browser-extension --- Browser extension companion for Linkwarden
		- [ ] https://github.com/rtuszik/starwarden --- Star/bookmark sync utility for Linkwarden
		- [ ] https://github.com/omnivore-app/omnivore --- Read‑it‑later service (Instapaper/Pocket alternative)
		- [ ] https://brainsteam.co.uk/2025/2/15/personal-archive-hoarder/ --- Article on building a personal bookmark/archive server
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
		- [ ] https://github.com/pendulum-project/ntpd-rs --- NTP daemon in Rust
		- [ ] https://github.com/pendulum-project/statime --- PTP (Precision Time Protocol) daemon
		- [ ] https://github.com/YunoHost-Apps --- YunoHost app catalog (packaged self‑hosted apps)
		- [ ] https://github.com/YunoHost-Apps/invoiceninja5_ynh --- InvoiceNinja YunoHost package (invoicing)
	- [ ] **Networking, Edge & Tunnels**
		- [ ] https://docs.pangolin.net/ --- Pangolin docs (reverse proxy / tunnel)
		- [ ] https://github.com/fosrl/pangolin --- Pangolin reverse proxy/tunneling service
		- [ ] https://github.com/cloudflare/cloudflared/blob/master/Dockerfile#L29C6-L29C13 --- Cloudflared Docker reference (Zero‑Trust tunnel)
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
		- [ ] https://github.com/gchq/CyberChef --- CyberChef (web-based data transform toolkit)
		- [ ] https://github.com/kasmtech/KasmVNC --- Web-based VNC viewer (browser VNC)
		- [ ] https://github.com/Elbullazul/LinkGuardian --- Bookmark/link guardian / archiving helper
		- [ ] https://github.com/pkulium/DeepOCR --- OCR library/tool
		- [ ] https://github.com/666ghj/BettaFish/blob/main/README-EN.md --- Social sentiment monitoring tool (BettaFish)
		- [ ] https://github.com/rtuszik/starwarden --- Extra tooling around Linkwarden/Star management
		- [ ] https://github.com/trymeka/agent --- Browser automation agent (duplicate reference, kept for visibility)
	- [ ] **References & Articles**
		- [ ] https://brainsteam.co.uk/2025/2/15/personal-archive-hoarder/ --- Personal archive/hoarder architecture write‑up
		- [ ] https://www.xda-developers.com/how-build-google-drive-alternative-nextcloud/ --- Guide: Nextcloud as Google Drive alternative
		- [ ] https://www.xda-developers.com/how-built-google-photos-alternative-nas-photoprism/ --- Guide: PhotoPrism as Google Photos alternative
		- [ ] https://www.xda-developers.com/how-i-replaced-all-these-streaming-services-with-one-self-hosted-app/ --- Jellyfin streaming replacement story
		- [ ] https://www.youtube.com/watch?v=Wjrdr0NU4Sk --- Video walkthrough of Open-WebUI + LiteLLM setup


## References
- [[Cross Platform To Install]]
