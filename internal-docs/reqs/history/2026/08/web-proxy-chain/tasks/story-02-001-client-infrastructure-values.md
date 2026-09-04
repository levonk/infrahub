---
story: "02-001"
title: "Client infrastructure values (levonk overrides, DNS CNAMEs, services.yml, SERVICES.md)"
status: "[ ] Todo"
phase: 2
depends_on: ["01-001"]
branch: "feature/current/web-proxy-chain/story-02-001-client-infrastructure-values"
---

# Story 02-001: Client Infrastructure Values

## Goal

Add client-specific overrides for the web proxy chain in the levonk submodule,
add service catalog entries, and regenerate SERVICES.md.

## Files to modify

1. `levonk/active/02-config/ansible/infrastructure/domains.yml` — add client-specific domain overrides (if any deviate from defaults)
2. `shared/active/02-config/ansible/infrastructure/services.yml` — add proxy-web service entries
3. Regenerate `shared/active/03-container/SERVICES.md` via the generation script

## Service catalog entries

Add to `services.yml` under category: proxy:

```yaml
# Web Proxy Chain Services
- name: "MITM Proxy"
  description: "HTTPS interception and decryption proxy (mitmproxy)"
  category: "proxy"
  port: "{{ infra_port_proxy_mitm_adblock_host }}"
  network: "{{ infra_network_dns_localnet_network_name }}"
  ip: "{{ infra_network_ip_proxy_mitm }}"
  source_repo: "upstream"
  image: "mitmproxy/mitmproxy"
  enabled_by_default: true

- name: "Privoxy"
  description: "Content filtering and header sanitization proxy"
  category: "proxy"
  port: "{{ infra_port_proxy_privoxy_host }}"
  network: "{{ infra_network_dns_localnet_network_name }}"
  ip: "{{ infra_network_ip_proxy_privoxy }}"
  source_repo: "upstream"
  image: "vimagick/privoxy"
  enabled_by_default: true

- name: "Varnish Cache"
  description: "HTTP cache with stale-while-revalidate and stale-if-error"
  category: "proxy"
  port: "{{ infra_port_proxy_varnish_http_host }}"
  network: "{{ infra_network_dns_localnet_network_name }}"
  ip: "{{ infra_network_ip_proxy_varnish }}"
  source_repo: "upstream"
  image: "varnish"
  enabled_by_default: true

- name: "Gost Egress"
  description: "Egress multiplexer routing to Direct/Tor/WARP backends"
  category: "proxy"
  port: "{{ infra_port_proxy_gost_socks5_host }}"
  network: "{{ infra_network_dns_localnet_network_name }}"
  ip: "{{ infra_network_ip_proxy_gost }}"
  source_repo: "shared"
  image: "localnet-proxy-gost"
  enabled_by_default: true
```

## Acceptance criteria

- [ ] Service entries added to services.yml
- [ ] SERVICES.md regenerated (find and run the generation script)
- [ ] `just ansible-syntax` passes
