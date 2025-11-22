---
Time-created: 17:31
Date-updated: 2025-03-16T17:26
Time-updated: 17:31
Title: Home Network Architecture
Template: 00 Fleeting Thought Template
tags:
Date-Created: 2024-07-06T22:09
Date-Updated: 2024-07-06T22:09
Date-created: 2025-03-08T14:49
title: Home Network Architecture
---

# Home Network Architecture

- [ ] Reference stacks / inspiration
  - [ ] TechHutTV homelab apps: https://github.com/TechHutTV/homelab/tree/main/apps
  - [ ] https://Github.com/Awesome-selfhosted/awesome-selfhosted

## Hardware

- Productivity PC
  - QubeOS
- Can These be combined into 1 Server?
  - Gaming PC
    - Windows
    - Graphics Card
  - Virtualization Server
    - Proxmox
  - Storage Server
    - TrueNAS Scale
- Firewall
  - Options
  - OpenSense > Pfsense
  - Sophos
- PiHole/Unbound Raspberry Pi (backup to server)
- PiKVM
- Ubiquity WIFI
- SATA card passthrough
- Graphics card
  - Transcode
  - Card gaming
  - AI

## Platform & Security Baseline (Global TODOs)

- [ ] Container lifecycle & updates
  - [ ] watchtower https://github.com/containrrr/watchtower
  - [ ] wud https://github.com/getwud/wud
- [ ] Config history & drift protection
  - [ ] etckeeper
- [ ] Host/network hardening
  - [ ] fail2ban
  - [ ] crowdsec https://github.com/crowdsecurity/crowdsec
  - [ ] Honeypot: https://github.com/thinkst/opencanary
- [ ] Authentication / SSO / identity
  - [ ] SSO (see detailed services below)
  - [ ] High‑security mTLS (mutual TLS) for internal apps
  - [ ] Authentication backend: https://github.com/ory/kratos
  - [ ] Internal SSO IdP / proxies (Authentik / Authelia)
- [ ] Edge access, tunnels, and DDNS
  - [ ] FRP cloud server can proxy to home based client https://github.com/fatedier/frp
  - [ ] Cloudflare DDNS
- [ ] Certificates / PKI
  - [ ] cert authority (internal CA for services)

## VLAN

1. Main
2. Guest
3. Camera
4. IOT
5. Test LAN
6. DMZ
7. Ceph.io longhorn?

## DNS Architecture (Tiered Fallback)

- [ ] keepalived for DNS Critical services
- [ ] DNS services (behind keepalived)
  - [ ] Layer 1 AdGuard + keepalived
  - [ ] Layer 2 DNSDist + keepalived
  - [ ] Layer 3 CoreDNS https://github.com/coredns/coredns + keepalived
- [ ] Layer 4 DNS Tiered Fallback (from most private/resilient to least):
  1. [ ] DNSCrypt: ODoH
  2. [ ] DNSCrypt: DNSCrypt protocol exclusively non-logging servers + keepalived
  3. [ ] Tor Service to be used later + keepalived
  4. [ ] Unbound over Tor + keepalived
  5. [ ] Ultra Resilient chain
     6. [ ] DNSCrypt: DNSCrypt protocol (not limited to anon servers) over Tor
     7. [ ] DNSCrypt: DNSCrypt protocol (not limited to anon servers)
     8. [ ] DNSCrypt: DoH protocol over Tor
     9. [ ] DNSCrypt: TLS protocol over Tor
     10. [ ] DNSCrypt: DoH protocol
     11. [ ] DNSCrypt: TLS protocol
     12. [ ] Unbound
     13. [ ] DNSCrypt: Plaintext over Tor
     13. [ ] DNSCrypt: Plaintext

### Services

- http://github.com/bastienwirtz/homer

  - Media
    - github.com/jellyfin/jellyfin  - media server to watch all your content, better than plex
    - Plex, may need it to access others repository or if Jellyfin falls short
    - GitHub.com/binhex/arch-delugevpn - Linux ISO
    - GitHub.com/Radarr/Radarr
    - https://github.com/Sonarr/Sonarr
    - https://github.com/evan-buss/openbooks
    - [ ] Video Manager: https://github.com/getmydia/mydia
    - [ ] easy private file exchange: https://github.com/tonyantony300/alt-sendme
    - [ ] video file workflow:
      - [ ] https://github.com/askreeves/ffmpeg-interface
      - [ ] https://github.com/JMS1717/8mb.local

  - Dev
    - https://github.com/explorerhq/django-sql-explorer?tab=readme-ov-file
    - Development environments (Proxmox / containers / Kubernetes)

  - Services

    - Share
      - File Share Services
        - https://github.com/nextcloud/server
        - https://github.com/syncthing/syncthing
        - [ ] file-browser: https://github.com/filebrowser/filebrowser
        - [ ] content management (self‑hosted CMS / knowledge base TBD)
		- https://github.com/opencloud-eu/
      - Document Share Services
        - https://github.com/mfts/papermark
      - Media Share Services
        - https://github.com/photoprism/photoprism
        - https://github.com/sabnzbd/sabnzbd Usenet download tool https://sabnzbd.org/
        - Owncast - streamyboi
        - NextJS or Hugo or Jekyll static site generator
        - Plex Media Server
      - Comms
        - OSS Discord Alternative: https://github.com/revoltchat/
        - Personal News Podcast: https://github.com/iliane5/meridian
        - [ ] livekit self-hosted (realtime audio/video)
        - [ ] TAK server: https://github.com/TAK-Product-Center/Server
        - Mastadon https://github.com/mastodon/mastodon
        - IRC
		- Slack Alternative
		- Asterisk?

    - Security
      - https://gitHub.com/dani-garcia/vaultwarden
      - Single sign on https://docs.goauthentik.io/
      - [ ] SSO - for internal network access
        - [ ] Authentik general IdP
        - [ ] Authelia proxy companion
      - [ ] Authentication to build our applications against
        - [ ] https://github.com/ory/kratos
      - [ ] mTLS everywhere for high‑security internal apps
      - [ ] AI security evaluation:
        - [ ] https://github.com/openpcc/openpcc?tab=readme-ov-file
      - [ ] cert authority (internal CA)

    - Development
      - [Mosh Bastian Host](https://superuser.com/questions/816382/mosh-into-bastion-server-ssh-into-internal-hosts)
      - https://github.com/iib0011/omni-tools
      - Trello Local: https://github.com/mattermost-community/focalboard
      - [ ] Code agent: https://github.com/HKUDS/DeepCode

    - Bookmarking
      - LinksPage
      - LinkShortner - Schlink
      - ReadItLater Alternative https://github.com/omnivore-app/omnivore
      - Bookmarking Server: https://brainsteam.co.uk/2025/2/15/personal-archive-hoarder/

    - AI
      - LocalAI
      - Ollama
        - `https://ollama.com/download` or  https://github.com/ollama/ollama
          - - Unfiltered Model: https://ollama.com/library/dolphin-mixtral
          - `ollama pull llama2`
          - Strong model: https://github.com/zai-org/GLM-4.5
      - AI Agent Browser Service https://github.com/browser-use/browser-use
      - Image generation [[Stable Diffusion Web UI]]
      - [[N8N]] AI Integration as a Service (IaaS) https://github.com/n8n-io/self-hosted-ai-starter-kit
      - AI Proxy https://github.com/katanemo/archgw
      - AI Webhooks https://github.com/stephengpope/no-code-architects-toolkit
      - [[Open WebUI]] + LiteLLM
        - https://www.youtube.com/watch?v=Wjrdr0NU4Sk
        - https://github.com/BerriAI/litellm
        - https://github.com/open-webui/open-webui
      - Prompt Playground: https://github.com/coze-dev/coze-loop
      - Browser Web Automation https://github.com/trymeka/agent
      - [ ] browser agent: skyvern
      - [ ] compute agent: agentsea
      - [ ] Agent Runner:
        - [ ] https://github.com/AgnetLabs/Laddr
      - [ ] Writing Agent: https://github.com/Doriandarko/kimi-writer
      - [ ] Tutoring: https://github.com/sheepbox8646/ChatTutor
      - [ ] evaluate OCR
        - [ ] https://github.com/deepseek/DeepSeek-OCR
        - [ ] https://github.com/datalab-to/chandra
        - [ ] https://github.com/pkulium/DeepOCR

    - Network Admin

      - Monitoring
        - Loki
        - Grafana
        - Promethus
        - OpenTelemetry
        - Uptime Kuma https://github.com/louislam/uptime-kuma
        - [ ] Notifications / push:
          - [ ] https://github.com/binwiederhier/ntfy
        - [ ] log notifier:
          - [ ] https://github.com/ImranR98/Logtfy
        - [ ] Server monitoring:
          - [ ] https://github.com/henrygd/beszel
        - [ ] Social Sentiment Monitor:
          - [ ] https://github.com/666ghj/BettaFish/blob/main/README-EN.md

      - Management
        - Rancher
        - Kubernetes

      - Proxys
        - Docker/k8s repo: https://github.com/goharbor/harbor
        - Deb/RPM repo: https://github.com/openkilt/openrepo
        - Node.JS NPM proxy: https://github.com/verdaccio/verdaccio
        - Maven Proxy: https://github.com/sonatype/nexus-public

      - Backups?
        - Offsite + local snapshot strategy
        - Object storage / versioned backups

    - Automation
      - https://github.com/dgtlmoon/changedetection.io https://ghcr.io/dgtlmoon/changedetection.io:latest

    - 3D Printing
      - https://github.com/OctoPrint/OctoPrint http://octoprint.org/

    - Development
      - Jupytr Lab

    - Tools
      - AirTable Alternative https://github.com/nocodb/nocodb
      - [ ] github.com/block/goose (data tooling / experimentation)
      - [ ] investigate only:
        - [ ] github.com/get-convex/chef
        - [ ] github.com/GeeeekExplorer/nano-vllm

  - System
    - https://github.com/traefik/traefik
      - [ ] crowdsec plugin https://github.com/crowdsecurity/crowdsec
      - [ ] geoblock plugin https://github.com/PascalMinder/geoblock
    - https://github.com/linuxserver/docker-unifi-controller
    - https://github.com/jacket/jackett torrent tracker used by radar and sonar
    - fritzbox for home router?
    - https://github.com/pikemen/pikvm remote keyboard
    - https://github.com/chriscrowe/docker/docker-pihole-unbound - recursive DNS adblocker DNS over TLS
    - Automation Software
      - Kestrel Automation Platform (logged commands, cron)
      - https://github.com/rundeck/rundeck
    - https://github.com/netbirdio/netbird VPN
      - https://tailscale.com/
    - Certmanager
    - FileCloud
    - NTPd https://github.com/pendulum-project/ntpd-rs
    - PTPd https://github.com/pendulum-project/statime
    - Mastodon?
    - https://netboot.xyz/docs/docker/
    - https://github.com/linuxserver/docker-speedtest-tracker
    - Zero Trust Tunnel
      - https://github.com/cloudflare/cloudflared/blob/master/Dockerfile#L29C6-L29C13
      - https://github.com/octelium/octelium
    - DDNS
      - https://github.com/oznu/docker-cloudflare-ddns
      - https://github.com/timothymiller/cloudflare-ddns
    - https://github.com/opslane/opslane
    - [ ] VLESS+XTLS proxy: 3x-ui

  - Monitoring
    - Certificate Transparency
      - https://github.com/google/certificate-transparency-go

  - Home Automation
    - https://github.com/home-assistant/docker
    - https://github.com/deacons-community/deconz-docker
    - [ ] Home Automation https://github.com/home-assistant/
    - -

### Bare Metal Operating System

- Bare Metal Virtualization
  - Proxmox.com
    - Containers
    - VMs
  - TrueNAS.com
    - Storage
    - Containers
    - NAS
    - VMs
    - Kubernetes

- Config
  - Ansible
  - docker-compose or k8s

## Related

[[Cross Platform To Install]]
