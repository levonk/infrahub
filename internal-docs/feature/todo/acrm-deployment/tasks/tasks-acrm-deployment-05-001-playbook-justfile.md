---
story_id: "05-001"
story_title: "deploy-acrm.yml playbook + just/devbox recipes"
story_name: "playbook-justfile"
prd_name: "acrm-deployment"
prd_file: "internal-docs/feature/todo/acrm-deployment/feat-202609191733-acrm-deployment.md"
phase: 5
parallel_id: 1
branch: "feature/current/acrm-deployment/story-05-001-playbook-justfile"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "04-001"]
parallel_safe: false
modules: ["playbook", "justfile", "devbox"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "playbook", "just", "devbox", "acrm"]
due: "2026-09-19"
create-date: "2026-09-19"
update-date: "2026-09-19"
---

## Summary

Create `shared/active/02-config/ansible/playbooks/deploy-acrm.yml` and wire
`just`/`devbox.json` recipes, following the two-phase nl playbook pattern
(`deploy-hister.yml`, `deploy-stirling-pdf.yml`) plus the Phase-0 DNS play
from `deploy-n8n.yml`/`deploy-paperclip.yml`.

## Sub-Tasks

- [ ] `playbooks/deploy-acrm.yml` — three plays:
  - **Phase 0 — DNS** (`hosts: localhost`): `vars_files` shared+levonk
    `domains.yml` + vault; `cloudflare_dns_records` =
    `{acrm.nl, acrm-api.nl}` CNAMEs → `{{ ts_fqdn_windows_docker }}`
    (`infra_tailscale_fqdn_windows_docker`); `cloudflare_dns_ttl: "{{
    infra_dns_ttl | int }}"`; `roles: [cloudflare-dns]`; `tags: ["dns"]`
  - **Phase 1 — deploy** (`hosts: windows_docker_hosts`, `become: false`):
    pre_tasks `include_vars` for shared `ports.yml`, `storage.yml`,
    `domains.yml`, `timing.yml`, `modes.yml`, `networks.yml`, `apps.yml`,
    `values.yml` + levonk `domains.yml`, `storage.yml`, `ports.yml`
    (copyparty lesson: load ALL shared files incl. `modes.yml`/`timing.yml`;
    levonk has no modes/timing files); assert
    `infra_port_ai_acrm_host`/`infra_domain_ai_acrm` defined; role `ai-acrm`
    with `tags: ["deploy", "acrm"]`; `vars: { ai_acrm_enabled: true }`
  - **Phase 2 — traefik** (`hosts: windows_docker_hosts`): same include_vars
    block + `include_vars` of `roles/ai-acrm/defaults/main.yml` (needed for
    container name/port vars the traefik role consumes) + vault vars_file
    (Cloudflare token for ACME); role `proxy_traefik_windows` with
    `tags: ["deploy", "traefik-windows", "acrm"]`
  - Vault vars auto-load on this inventory via the
    `infrahub-levonk-all.vault` parent group; the Phase-0 localhost play and
    Phase-2 ACME token still need the explicit `vars_files`/`include_vars`
    (stirling/hister pattern)
- [ ] Root `justfile`:
  - `PB_ACRM := ANSIBLE_ROOT + "/playbooks/deploy-acrm.yml"` alongside the
    other `PB_*` vars
  - `ansible-deploy-acrm:` → `@just _devbox ansible_deploy_acrm_impl` and
    `[private] ansible_deploy_acrm_impl:` running
    `ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_ACRM}}
    --vault-password-file ~/.ansible/vault_password` (copy
    `ansible-deploy-stirling-pdf` shape)
  - optional `ansible-deploy-acrm-check` (--check --diff; expect limited
    fidelity — all tasks are shell/command)
- [ ] `devbox.json` scripts: `"ansible-deploy-acrm": "just
  ansible-deploy-acrm-internal"` — follow the existing naming: check whether
  nl deploys register `-internal` variants or direct recipes (stirling/media
  entries are absent from devbox.json — decide: add
  `"ansible-deploy-acrm": "just ansible-deploy-acrm"` or match whatever the
  newest nl recipe does)
- [ ] `just ansible-syntax` + `just ansible-lint` clean

## Relevant Files

- `shared/active/02-config/ansible/playbooks/deploy-acrm.yml` (new)
- `justfile`
- `devbox.json`
- Reference: `deploy-hister.yml`, `deploy-stirling-pdf.yml`,
  `deploy-n8n.yml` (Phase-0 DNS), `deploy-paperclip.yml`

## Acceptance Criteria

- Given the playbook, when `ansible-playbook --syntax-check` runs, then it
  passes
- Given a live run (`just ansible-deploy-acrm`), then DNS records apply,
  postgres+web deploy healthy, migrations run, traefik config lands, and
  `https://acrm-api.nl.levonk.com/` responds without SSO
- Given `just --list`, then `ansible-deploy-acrm` appears

## Implementation Notes

- First live deploy prerequisites (document in playbook header):
  1. vault keys present (`vault_acrm_api_key`, `vault_acrm_postgres_password`)
  2. image pushed: `localnet-ai-acrm-web:latest` in `100.90.22.85:5000`
     (story 01-001 recipe, run in the acrm repo)
  3. SSH to `ansible@dtop202311.tale-grouper.ts.net` works from controller
- Usage line: `ansible-playbook -i
  levonk/active/02-config/ansible/inventories/windows-docker.yml
  shared/active/02-config/ansible/playbooks/deploy-acrm.yml
  --vault-password-file ~/.ansible/vault_password`
- A `validate-acrm.yml` playbook is a follow-up (validation-layer
  convention), not part of this story.

## Definition of Done

- Playbook + recipes committed; syntax/lint clean; live deploy verified
  end-to-end (or checklist handed to the user if image/vault not yet ready)
