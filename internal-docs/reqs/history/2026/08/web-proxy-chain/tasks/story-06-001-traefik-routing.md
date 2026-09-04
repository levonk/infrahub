---
story: "06-001"
title: "Traefik dynamic config for proxy-web dashboards + CA cert download"
status: "[ ] Todo"
phase: 6
depends_on: ["05-001"]
branch: "feature/current/web-proxy-chain/story-06-001-traefik-routing"
---

# Story 06-001: Traefik Routing

## Goal

Add Traefik dynamic config templates for the web proxy chain dashboards and
the MITM CA certificate download endpoint.

## Files to modify

1. `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/` — add new dynamic config templates
2. `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/` — add Windows equivalents

## Routes to add

| Domain | Service | Port | Auth |
|--------|---------|------|------|
| `mitm.{{ infra_domain_base }}` | MITM proxy web UI | 8081 | Authelia |
| `varnish.{{ infra_domain_base }}` | Varnish admin | 6082 | Authelia |
| `ca.{{ infra_domain_base }}` | MITM CA cert download | 8081 | Authelia |

## Template pattern (from existing Traefik dynamic configs)

```yaml
# templates/dynamic/mitm.yml.j2
http:
  routers:
    mitm-web:
      rule: "Host(`{{ infra_domain_proxy_mitm }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia@docker
      service: mitm-web
      tls:
        certResolver: letsencrypt
  services:
    mitm-web:
      loadBalancer:
        servers:
          - url: "http://{{ infra_network_ip_proxy_mitm }}:{{ infra_port_proxy_mitm_webui_container }}"
```

## Acceptance criteria

- [ ] mitm.yml.j2 created for Traefik dynamic config
- [ ] varnish.yml.j2 created for Traefik dynamic config
- [ ] ca-cert-download.yml.j2 created for CA cert download
- [ ] Windows equivalents created in proxy_traefik_windows templates
- [ ] All routes use Authelia middleware
- [ ] All domains use {{ infra_domain_* }} variables
- [ ] All IPs use {{ infra_network_ip_* }} variables
- [ ] `just ansible-syntax` passes
