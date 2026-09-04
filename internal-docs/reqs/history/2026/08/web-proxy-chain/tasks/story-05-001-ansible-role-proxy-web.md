---
story: "05-001"
title: "Ansible role proxy-web (defaults, tasks, templates)"
status: "[ ] Todo"
phase: 5
depends_on: ["01-001", "03-001"]
branch: "feature/current/web-proxy-chain/story-05-001-ansible-role-proxy-web"
---

# Story 05-001: Ansible Role proxy-web

## Goal

Create the `proxy-web` Ansible role with multiple task files (matching the `dns`
role pattern), supporting dual-platform deployment (Linux/OCI + Windows).

## Directory structure

```
shared/active/02-config/ansible/roles/proxy-web/
├── defaults/
│   └── main.yml          # Map proxy_web_* vars to infra_* vars
├── tasks/
│   ├── main.yml          # Dispatch: Linux vs Windows
│   ├── deploy-linux.yml  # OCI deployment (community.docker)
│   ├── deploy-windows.yml # Windows deployment (SSH-tunneled Docker CLI)
│   ├── mitm.yml          # MITM proxy deployment
│   ├── privoxy.yml       # Privoxy deployment
│   ├── varnish.yml       # Varnish cache deployment
│   └── gost.yml          # Gost egress multiplexer deployment
├── templates/
│   ├── gost.yaml.j2          # Gost egress config
│   ├── varnish-default.vcl.j2 # Varnish VCL config
│   ├── privoxy-config.j2     # Privoxy config
│   └── mitm-web-conf.j2      # mitmweb config (if needed)
├── meta/
│   └── main.yml          # Role metadata
└── README.md             # Role documentation
```

## defaults/main.yml pattern (from DNS role)

```yaml
---
# proxy-web role defaults
# Maps proxy_web_* variables to infra_* infrastructure variables

# Network
proxy_web_network_name: "{{ infra_network_dns_localnet_network_name }}"
proxy_web_network_subnet: "{{ infra_network_dns_localnet_subnet }}"
proxy_web_network_gateway: "{{ infra_network_dns_localnet_gateway }}"

# Service IPs
proxy_web_mitm_ip: "{{ infra_network_ip_proxy_mitm }}"
proxy_web_privoxy_ip: "{{ infra_network_ip_proxy_privoxy }}"
proxy_web_varnish_ip: "{{ infra_network_ip_proxy_varnish }}"
proxy_web_gost_ip: "{{ infra_network_ip_proxy_gost }}"

# Ports
proxy_web_mitm_transparent_host_port: "{{ infra_port_proxy_mitm_transparent_host }}"
proxy_web_mitm_transparent_container_port: "{{ infra_port_proxy_mitm_transparent_container }}"
proxy_web_mitm_adblock_host_port: "{{ infra_port_proxy_mitm_adblock_host }}"
proxy_web_mitm_adblock_container_port: "{{ infra_port_proxy_mitm_adblock_container }}"
proxy_web_mitm_webui_host_port: "{{ infra_port_proxy_mitm_webui_host }}"
proxy_web_mitm_webui_container_port: "{{ infra_port_proxy_mitm_webui_container }}"
proxy_web_privoxy_host_port: "{{ infra_port_proxy_privoxy_host }}"
proxy_web_privoxy_container_port: "{{ infra_port_proxy_privoxy_container }}"
proxy_web_varnish_http_host_port: "{{ infra_port_proxy_varnish_http_host }}"
proxy_web_varnish_http_container_port: "{{ infra_port_proxy_varnish_http_container }}"
proxy_web_varnish_admin_host_port: "{{ infra_port_proxy_varnish_admin_host }}"
proxy_web_varnish_admin_container_port: "{{ infra_port_proxy_varnish_admin_container }}"
proxy_web_gost_socks5_host_port: "{{ infra_port_proxy_gost_socks5_host }}"
proxy_web_gost_socks5_container_port: "{{ infra_port_proxy_gost_socks5_container }}"
proxy_web_gost_http_host_port: "{{ infra_port_proxy_gost_http_host }}"
proxy_web_gost_http_container_port: "{{ infra_port_proxy_gost_http_container }}"

# Volumes
proxy_web_mitm_ca_volume: "{{ infra_storage_proxy_mitm_ca_volume }}"
proxy_web_varnish_cache_volume: "{{ infra_storage_proxy_varnish_cache_volume }}"
proxy_web_gost_config_volume: "{{ infra_storage_proxy_gost_config_volume }}"
proxy_web_privoxy_config_volume: "{{ infra_storage_proxy_privoxy_config_volume }}"

# Tor proxy (shared with DNS chain)
proxy_web_tor_socks5_ip: "{{ infra_network_ip_dns_tor_proxy }}"
proxy_web_tor_socks5_port: "{{ infra_port_proxy_tor_socks5_container }}"

# Images
proxy_web_mitm_image: "mitmproxy/mitmproxy"
proxy_web_privoxy_image: "vimagick/privoxy"
proxy_web_varnish_image: "varnish"
proxy_web_gost_image: "localnet-proxy-gost"

# Enablement flags
proxy_web_mitm_enabled: true
proxy_web_privoxy_enabled: true
proxy_web_varnish_enabled: true
proxy_web_gost_enabled: true

# Docker host for Windows
proxy_web_docker_host_windows: "ssh://{{ ansible_user }}@{{ ansible_host }}:{{ ansible_port }}"
proxy_web_windows_temp_dir: "/tmp/proxy-web-windows"
```

## Task file patterns

### mitm.yml (Linux/OCI)

```yaml
- name: Deploy MITM proxy container
  community.docker.docker_container:
    name: localnet-proxy-mitm
    image: "{{ proxy_web_mitm_image }}"
    state: started
    restart_policy: unless-stopped
    command: "mitmweb --web-host 0.0.0.0 --mode regular:{{ proxy_web_mitm_adblock_container_port }}"
    networks:
      - name: "{{ proxy_web_network_name }}"
        ipv4_address: "{{ proxy_web_mitm_ip }}"
    published_ports:
      - "{{ proxy_web_mitm_adblock_host_port }}:{{ proxy_web_mitm_adblock_container_port }}/tcp"
      - "{{ proxy_web_mitm_webui_host_port }}:{{ proxy_web_mitm_webui_container_port }}/tcp"
    volumes:
      - "{{ proxy_web_mitm_ca_volume }}:/home/mitmproxy/.mitmproxy:rw"
    log_driver: json-file
    log_options:
      max-size: 10m
      max-file: 5
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://127.0.0.1:{{ proxy_web_mitm_webui_container_port }}/"]
      interval: "30s"
      timeout: "10s"
      retries: 3
      start_period: "30s"
```

### deploy-windows.yml

Follow the DNS chain's deploy-windows.yml pattern:
- Prepare local temp directory
- Copy config templates to local temp
- Ensure Docker network exists (shell command)
- Ensure Docker volumes exist (shell command)
- Seed template volumes via temp alpine containers (docker cp)
- Deploy containers via docker run (SSH-tunneled)
- Wait for containers to be ready

## Acceptance criteria

- [ ] Role directory structure created
- [ ] defaults/main.yml maps all proxy_web_* to infra_* variables
- [ ] tasks/main.yml dispatches to deploy-linux.yml or deploy-windows.yml
- [ ] mitm.yml deploys MITM proxy with healthcheck (string format)
- [ ] privoxy.yml deploys Privoxy with healthcheck
- [ ] varnish.yml deploys Varnish with healthcheck + tmpfs
- [ ] gost.yml deploys Gost with healthcheck + config template
- [ ] deploy-windows.yml follows DNS chain pattern (SSH-tunneled Docker CLI)
- [ ] All ports/IPs are variables (no hardcoded values)
- [ ] Healthcheck intervals/timeouts are strings with unit suffixes
- [ ] `just ansible-syntax` passes
- [ ] `just ansible-lint` passes (or only pre-existing violations)
