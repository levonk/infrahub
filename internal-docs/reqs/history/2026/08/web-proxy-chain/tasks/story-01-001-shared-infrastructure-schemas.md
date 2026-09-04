---
story: "01-001"
title: "Shared infrastructure schemas (ports, networks, IPs, domains, storage)"
status: "[ ] Todo"
phase: 1
depends_on: []
branch: "feature/current/web-proxy-chain/story-01-001-shared-infrastructure-schemas"
---

# Story 01-001: Shared Infrastructure Schemas

## Goal

Add all web proxy chain infrastructure variables to the shared schema files so
the Ansible role can reference them without hardcoding.

## Files to modify

1. `shared/active/02-config/ansible/infrastructure/ports.yml` — add proxy-web ports
2. `shared/active/02-config/ansible/infrastructure/networks.yml` — add proxy-web IPs
3. `shared/active/02-config/ansible/infrastructure/domains.yml` — add proxy-web domains
4. `shared/active/02-config/ansible/infrastructure/storage.yml` — add proxy-web volumes

## Port allocations (from design notes)

| Variable | Value | Purpose |
|----------|-------|---------|
| `infra_port_proxy_mitm_transparent_host` | "3127" | Transparent policy entrypoint (host) |
| `infra_port_proxy_mitm_transparent_container` | "3127" | Transparent policy entrypoint (container) |
| `infra_port_proxy_mitm_adblock_host` | "3128" | Ad-blocking policy entrypoint (host) |
| `infra_port_proxy_mitm_adblock_container` | "3128" | Ad-blocking policy entrypoint (container) |
| `infra_port_proxy_mitm_webui_host` | "8081" | mitmweb web UI (host) |
| `infra_port_proxy_mitm_webui_container` | "8081" | mitmweb web UI (container) |
| `infra_port_proxy_privoxy_host` | "8118" | Privoxy HTTP proxy (internal) |
| `infra_port_proxy_privoxy_container` | "8118" | Privoxy HTTP proxy (container) |
| `infra_port_proxy_varnish_http_host` | "6081" | Varnish HTTP cache (host) |
| `infra_port_proxy_varnish_http_container` | "6081" | Varnish HTTP cache (container) |
| `infra_port_proxy_varnish_admin_host` | "6082" | Varnish admin (host) |
| `infra_port_proxy_varnish_admin_container` | "6082" | Varnish admin (container) |
| `infra_port_proxy_gost_socks5_host` | "1080" | Gost SOCKS5 (host, bypass) |
| `infra_port_proxy_gost_socks5_container` | "1080" | Gost SOCKS5 (container) |
| `infra_port_proxy_gost_http_host` | "8080" | Gost HTTP egress (internal) |
| `infra_port_proxy_gost_http_container` | "8080" | Gost HTTP egress (container) |

**IMPORTANT**: Before adding, check ports.yml for conflicts on ports 3127, 3128, 6081, 6082, 8080, 8081, 8118, 1080. Port 3128 is currently `infra_port_proxy_direct` — this needs to be reconciled (the MITM adblock entrypoint reuses 3128, which was the old Squid direct proxy port).

## IP allocations (from design notes)

| Variable | Value |
|----------|-------|
| `infra_network_ip_proxy_mitm` | "172.26.255.80" |
| `infra_network_ip_proxy_privoxy` | "172.26.255.81" |
| `infra_network_ip_proxy_varnish` | "172.26.255.82" |
| `infra_network_ip_proxy_gost` | "172.26.255.83" |

These are in the `localnet-network` (172.26.0.0/16) range, same as DNS chain.

## Domain allocations

| Variable | Default |
|----------|---------|
| `infra_domain_proxy_mitm` | "mitm.{{ infra_domain_base }}" |
| `infra_domain_proxy_mitm_ca` | "ca.{{ infra_domain_base }}" |
| `infra_domain_proxy_varnish` | "varnish.{{ infra_domain_base }}" |

## Storage allocations

| Variable | Volume name |
|----------|------------|
| `infra_storage_proxy_mitm_ca_volume` | "localnet-proxy-mitm-ca-volume" |
| `infra_storage_proxy_varnish_cache_volume` | "localnet-proxy-varnish-cache-volume" |
| `infra_storage_proxy_gost_config_volume` | "localnet-proxy-gost-config-volume" |
| `infra_storage_proxy_privoxy_config_volume` | "localnet-proxy-privoxy-config-volume" |

## Acceptance criteria

- [ ] All port variables added to ports.yml with comments
- [ ] All IP variables added to networks.yml with comments
- [ ] All domain variables added to domains.yml with comments
- [ ] All storage variables added to storage.yml with comments
- [ ] No port conflicts with existing allocations
- [ ] Port 3128 conflict with `infra_port_proxy_direct` reconciled (rename old or reuse)
- [ ] `just ansible-syntax` passes
