---
story_id: "05-001"
story_title: "deploy-postiz.yml playbook + just/devbox recipes"
story_name: "playbook-justfile"
prd_name: "postiz-deployment"
prd_file: "internal-docs/feature/todo/postiz-deployment/feat-202611131708-postiz-deployment.md"
phase: 5
parallel_id: 1
branch: "levonk/20261113-postiz"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "04-001"]
parallel_safe: false
modules: ["ansible-playbook", "justfile", "devbox"]
priority: "MUST"
risk_level: "low"
tags: ["playbook", "just", "devbox", "postiz"]
due: "2026-11-13"
create-date: "2026-11-13"
update-date: "2026-11-13"
---

## Summary

Create `shared/active/02-config/ansible/playbooks/deploy-postiz.yml`
(copy `deploy-acrm.yml` structure — three phases: DNS → service role →
`proxy_traefik_windows`) plus the `just` recipe and devbox.json script
entry so `just ansible-deploy-postiz` works.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/playbooks/deploy-postiz.yml` —
  three plays copying deploy-acrm.yml exactly:
  - **Phase 0** `hosts: localhost` — `cloudflare-dns` role with a
    one-record `cloudflare_dns_records` list: `postiz.nl.{{
    infra_domain_base }}` CNAME → `{{ ts_fqdn_windows_docker }}`,
    non-proxied. Tags: `["dns"]`. Same vars_files (shared domains +
    timing + client domains + vault).
  - **Phase 1** `hosts: windows_docker_hosts` — `tools-postiz` role with
    `tools_postiz_enabled: true`; the full include_vars preamble
    (ports/storage/domains/timing/modes/networks/apps/values shared +
    client ports/storage/domains + assert required vars +
    `tools-postiz` role defaults load if the playbook references them +
    vault file load `no_log: true`).
  - **Phase 2** `hosts: windows_docker_hosts` —
    `proxy_traefik_windows` role with
    `proxy_traefik_windows_postiz_enabled: true` (+ same preamble +
    vault for ACME).
  - Header comment block: purpose, layout, first-deploy prerequisites
    (vault keys, SSH to dtop202311), usage lines incl. `--check`.
- [ ] `just` recipes — add `ansible-deploy-postiz` +
  `ansible-deploy-postiz-internal` following the `ansible-deploy-acrm`
  entries in the Justfile(s).
- [ ] `devbox.json` — add the matching script entry (mirrors acrm).
- [ ] Add the playbook to the Ansible AGENTS.md
  "Playbook-to-Inventory Mapping" table
  (`shared/active/02-config/ansible/AGENTS.md`).

## Acceptance Criteria

- `devbox run -- rtk ansible-playbook -i
  levonk/active/02-config/ansible/inventories/windows-docker.yml
  shared/active/02-config/ansible/playbooks/deploy-postiz.yml
  --syntax-check` passes; `just ansible-deploy-postiz` resolves to the
  playbook; mapping table updated.
