---
story_id: "04-001"
story_title: "Traefik (Windows) dynamic config + Cloudflare DNS records"
story_name: "traefik-dns"
prd_name: "acrm-deployment"
prd_file: "internal-docs/feature/todo/acrm-deployment/feat-202609191733-acrm-deployment.md"
phase: 4
parallel_id: 1
branch: "feature/current/acrm-deployment/story-04-001-traefik-dns"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "03-001"]
parallel_safe: false
modules: ["traefik", "dns", "windows"]
priority: "MUST"
risk_level: "low"
tags: ["traefik", "cloudflare", "dns", "authelia", "acrm"]
due: "2026-09-19"
create-date: "2026-09-19"
update-date: "2026-09-19"
---

## Summary

Wire ACRM into the **Windows** Traefik (`proxy_traefik_windows`) with the
stirling-style two-domain split — `acrm.nl.levonk.com` behind Authelia,
`acrm-api.nl.levonk.com` unauthenticated-at-the-edge (app enforces
`x-acrm-api-key`) — and add both Cloudflare records to the canonical list.

## Sub-Tasks

- [ ] New template
  `roles/proxy_traefik_windows/templates/dynamic/acrm-nl.yml.j2`:
  - `acrm-nl-http` router (Host `{{ proxy_traefik_windows_acrm_domain }}`,
    web entrypoint, `redirect-to-https`)
  - `acrm-nl-https` router (websecure, `middlewares: [authelia]` gated on
    `proxy_traefik_windows_authelia_enabled`, `certResolver: letsencrypt`)
  - `acrm-api-nl-http` + `acrm-api-nl-https` routers (Host
    `{{ proxy_traefik_windows_acrm_api_domain }}`, **no** authelia
    middleware, `certResolver: letsencrypt`)
  - one service `acrm-nl` → `http://{{
    proxy_traefik_windows_acrm_container_name }}:{{
    proxy_traefik_windows_acrm_container_port }}` (container-name upstream —
    NOT the host port)
  - Model on `stirling-nl.yml.j2` / `hister-nl.yml.j2`; skip the SAN/alias
    block (two separate host rules each get their own cert)
- [ ] `roles/proxy_traefik_windows/defaults/main.yml` — add:
  - `proxy_traefik_windows_acrm_enabled: true` (nl service; flip to false if
    acrm is ever undeployed)
  - `proxy_traefik_windows_acrm_domain: "{{ infra_domain_ai_acrm | … }}"`,
    `proxy_traefik_windows_acrm_api_domain: "{{ infra_domain_ai_acrm_api | … }}"`
  - `proxy_traefik_windows_acrm_container_name: "{{ infra_hostname_acrm_web | … }}"`,
    `proxy_traefik_windows_acrm_container_port: "{{ infra_port_ai_acrm_container | … }}"`
  - extend the `proxy_traefik_windows_acme_domains` (cert coverage) chain
    with both acrm domains, matching the existing `ternary` pattern
- [ ] `roles/proxy_traefik_windows/tasks/main.yml` — add render task +
  `docker cp` copy task for `acrm-nl.yml` (both `when:
  proxy_traefik_windows_acrm_enabled | bool`), and a
  `docker network connect traefik-windows-network {{
  proxy_traefik_windows_acrm_container_name }} || true` task alongside the
  other per-service connect tasks
- [ ] `playbooks/configure-cloudflare-dns.yml` — append to
  `cloudflare_dns_records` near the other nl entries:
  - `acrm.nl` → `type: CNAME`, `content: "{{ ts_fqdn_windows_docker }}"`
  - `acrm-api.nl` → `type: CNAME`, `content: "{{ ts_fqdn_windows_docker }}"`
    (NOT an A record — `infra_tailscale_ip_windows_docker` is currently
    `100.90.22.85` = OCI, a known bug; CNAME→FQDN works via MagicDNS)
- [ ] Decide + document: fix `infra_tailscale_ip_windows_docker` to
  `100.81.103.34` in levonk domains.yml? Recommended (repairs the broken
  stirling-api record too) — confirm with owner; separate commit
- [ ] Verify template renders: `just ansible-syntax` on
  `deploy-acrm.yml`/`deploy-stirling-pdf.yml` path; eyeball rendered YAML

## Relevant Files

- `roles/proxy_traefik_windows/templates/dynamic/acrm-nl.yml.j2` (new)
- `roles/proxy_traefik_windows/defaults/main.yml`
- `roles/proxy_traefik_windows/tasks/main.yml`
- `playbooks/configure-cloudflare-dns.yml`
- `levonk/active/02-config/ansible/infrastructure/domains.yml` (optional IP fix)

## Acceptance Criteria

- Given `proxy_traefik_windows_acrm_enabled`, when the role runs, then
  `acrm-nl.yml` renders and lands in the traefik-windows config volume and
  the web container joins `traefik-windows-network`
- Given the rendered config, then `acrm.nl` traffic goes through the
  authelia middleware and `acrm-api.nl` traffic does not
- Given `configure-cloudflare-dns.yml` runs, then both records exist as
  CNAMEs to `dtop202311.tale-grouper.ts.net`
- Given `curl -sI https://acrm-api.nl.levonk.com/` post-deploy, then no
  Authelia redirect (200/401 from the app, not a 302 to auth.levonk.com)

## Implementation Notes

- Traefik file provider hot-reloads the dynamic dir — no Traefik restart
  needed for new configs, but the playbook's phase-2 role re-run is the
  delivery mechanism (hister/stirling pattern).
- `configure-cloudflare-dns.yml` aborts on first failed record — append
  acrm entries after existing nl records; run only the new records via
  `--extra-vars` if re-running surgically.
- `cloudflare_dns_ttl` must be an integer — use `{{ infra_dns_ttl | int }}`
  if defining it (copyparty lesson).

## Definition of Done

- Template + registration + DNS records committed; routing verified during
  the 05-001 live deploy
