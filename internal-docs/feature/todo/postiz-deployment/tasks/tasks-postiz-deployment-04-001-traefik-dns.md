---
story_id: "04-001"
story_title: "Traefik (Windows) dynamic config + DNS records for Postiz"
story_name: "traefik-dns"
prd_name: "postiz-deployment"
prd_file: "internal-docs/feature/todo/postiz-deployment/feat-202611131708-postiz-deployment.md"
phase: 4
parallel_id: 1
branch: "levonk/20261113-postiz"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "03-001"]
parallel_safe: false
modules: ["traefik", "cloudflare-dns", "ansible"]
priority: "MUST"
risk_level: "medium"
tags: ["traefik", "dns", "cloudflare", "postiz"]
due: "2026-11-13"
create-date: "2026-11-13"
update-date: "2026-11-13"
---

## Summary

Wire `postiz.nl.levonk.com` into traefik-windows (dynamic config template,
registration tasks, defaults, cert SAN list) and add the Cloudflare CNAME
record — the acrm story 04-001 pattern, minus the API subdomain and minus
Authelia.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/postiz-nl.yml.j2`
  — copy `acrm-nl.yml.j2` shape: `postiz-nl-http` router (web →
  redirect-to-https) + `postiz-nl-https` router (websecure, letsencrypt)
  both `Host({{ proxy_traefik_windows_postiz_domain }})` → service
  `postiz-nl` → `http://{{ proxy_traefik_windows_postiz_container_name
  }}:{{ proxy_traefik_windows_postiz_container_port }}`,
  `passHostHeader: true`. NO authelia middleware (app has own auth +
  provider OAuth callbacks). Postiz serves UI/API/uploads on one port —
  no path splitting.
- [ ] `proxy_traefik_windows/defaults/main.yml` —
  `proxy_traefik_windows_postiz_enabled: true`,
  `proxy_traefik_windows_postiz_domain: "{{ infra_domain_tools_postiz | default('postiz.nl.' ~ (infra_domain_base | default('example.com'))) }}"`,
  `proxy_traefik_windows_postiz_container_name: "{{ infra_hostname_postiz }}"`,
  `proxy_traefik_windows_postiz_container_port: "{{ infra_port_tools_postiz_container }}"`;
  add the domain to the cert SAN list (the ternary chain near
  `proxy_traefik_windows_acrm_domain` ~line 97)
- [ ] `proxy_traefik_windows/tasks/main.yml` — three additions matching
  the acrm blocks: (a) render `postiz-nl.yml.j2` → temp dir task, (b)
  `docker network connect traefik-windows-network
  localnet-postiz || true` task, (c) `docker cp` postiz-nl.yml into the
  config-seed container task — all `when:
  proxy_traefik_windows_postiz_enabled | bool`
- [ ] DNS — add to the canonical `cloudflare_dns_records` list in
  `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml`:
  `postiz.nl.{{ infra_domain_base }}` CNAME →
  `{{ infra_tailscale_fqdn_windows_docker }}` (matches acrm entries —
  non-proxied, `infra_dns_ttl`)
- [ ] Phase-0 `dns`-tagged play lands in `deploy-postiz.yml` (story
  05-001) — not here.

## Acceptance Criteria

- Re-running `proxy_traefik_windows` with
  `proxy_traefik_windows_postiz_enabled` renders postiz-nl.yml and copies
  it into the config seed; cert SAN list includes
  `postiz.nl.levonk.com`; `configure-cloudflare-dns.yml` contains the
  record; `--syntax-check` clean.
