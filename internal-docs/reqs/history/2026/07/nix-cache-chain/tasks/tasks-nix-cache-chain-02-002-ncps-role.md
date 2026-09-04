---
story_id: "02-002"
story_title: "Create nix-ncps Ansible role"
story_name: "ncps-role"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 2
branch: "feature/current/nix-cache-chain/story-02-002-ncps-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["shared/02-config/ansible/roles/nix-ncps"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "role", "nix"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-ncps` Ansible role that deploys the ncps (Nix Cache Proxy Server) container on 2 regional hubs (dtop202311, oci-cloud-server). ncps caches NARs locally for LAN bandwidth savings and uses ncro as its upstream. ncps binds to 0.0.0.0 (accessible via Tailscale). This role follows the agentmemory role pattern and includes a Jinja2 template for `config.toml`.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/roles/agentmemory/` — reference role pattern
  - `shared/active/02-config/ansible/roles/cloudflare-ddns/templates/ddns-update.sh.j2` — reference for Jinja2 template pattern (uses `{{ variable }}` interpolation)
  - `shared/active/03-container/services/artifact/nix-ncps/config.toml` — existing reference config (upstream substituters, server host/port, cache data_dir, logging, performance)

- **Existing code excerpts (nix-ncps config.toml — reference for template):**
  ```toml
  [upstream]
  substituters = ["https://cache.garnix.io", "https://cache.nixos.org"]
  [server]
  host = "0.0.0.0"
  port = 8080
  [cache]
  data_dir = "/data"
  [logging]
  level = "info"
  format = "json"
  [performance]
  max_concurrent_downloads = 10
  connect_timeout = 30
  request_timeout = 300
  ```

- **ncps specifics (from PRD FR-2):**
  - Deploys on dtop202311 (LAN region) and oci-cloud-server (cloud region)
  - Stores NARs locally (bind mount to host storage)
  - Upstream is the regional ncro instance (127.0.0.1:8081)
  - Binds to 0.0.0.0 (accessible via Tailscale)
  - Port: `infra_port_nix_ncps_container` (default 8080)
  - Image: `ghcr.io/kalbasit/ncps:latest` (Docker Hub/GHCR — can use `source: pull` directly, no build needed per PRD)
  - Health endpoint: `/healthz`

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncps/` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/roles/nix-ncps/` with:
  - `defaults/main.yml` — container config, ports from infra vars, volume, healthcheck, logging
  - `tasks/main.yml` — validate, create storage dir, deploy config.toml template, pull image, deploy container, wait for health, report
  - `templates/config.toml.j2` — Jinja2 template for ncps config (upstream = ncro 127.0.0.1:8081, server 0.0.0.0:8080, cache data_dir, logging)
  - `handlers/main.yml` — restart handler
  - `meta/main.yml` — galaxy info, dependencies: [common]
  - `vars/main.yml` — empty
  - `README.md`

**Out of scope:**
- ncro role (Story 02-003)
- Playbook creation (Story 03-001)
- Deployment (Story 04-001)

## Sub-Tasks

- [ ] Task 1 — Create `defaults/main.yml`
  Define: `nix_ncps_enabled: true`, `nix_ncps_container_name: "localnet-nix-ncps"`, `nix_ncps_image: "ghcr.io/kalbasit/ncps"`, `nix_ncps_image_tag: "latest"`, `nix_ncps_host_port: "{{ infra_port_nix_ncps_host | default('8080') }}"`, `nix_ncps_container_port: "{{ infra_port_nix_ncps_container | default('8080') }}"`, `nix_ncps_data_dir: "/data"`, `nix_ncps_config_dir: "{{ infra_storage_nix_ncps_config | default('/opt/localnet/services/nix-ncps/config') }}"`, `nix_ncps_upstream_url: "http://127.0.0.1:{{ infra_port_nix_ncro_container | default('8081') }}"`, healthcheck vars, logging vars.
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-ncps/defaults/main.yml'))"` → exit 0

- [ ] Task 2 — Create `templates/config.toml.j2`
  Jinja2 template for ncps config.toml: `[upstream]` with `substituters = ["{{ nix_ncps_upstream_url }}"]`, `[server]` with `host = "0.0.0.0"` and `port = {{ nix_ncps_container_port }}`, `[cache]` with `data_dir = "{{ nix_ncps_data_dir }}"`, `[logging]` level info format json, `[performance]` defaults.
  **Verify**: Template file exists and contains `{{ nix_ncps_upstream_url }}`

- [ ] Task 3 — Create `tasks/main.yml`
  Structure: (1) Validate vars. (2) Create config directory on host with `ansible.builtin.file` (owner: userns-remap UID 100000, mode 0755). (3) Deploy config.toml from template (`ansible.builtin.template`, notify restart). (4) Create data volume. (5) Pull image (`community.docker.docker_image`, source: pull). (6) Deploy container with: ports `{{ nix_ncps_host_port }}:{{ nix_ncps_container_port }}/tcp` (binds 0.0.0.0), volumes (data volume + config.toml mount), env (TZ), security_opts, healthcheck `curl -fsS http://127.0.0.1:{{ nix_ncps_container_port }}/healthz || exit 1`. (7) Wait for health. (8) Report.
  **Verify**: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncps/tasks/main.yml` → exit 0

- [ ] Task 4 — Create `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`
  Handler: restart nix-ncps. Meta: role_name: nix-ncps, dependencies: [common]. README: document purpose, variables, config template.
  **Verify**: All files exist, YAML files parse

- [ ] Task 5 — Run ansible-lint on the full role
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncps/` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-ncps/defaults/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/tasks/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/templates/config.toml.j2` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/handlers/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/meta/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/vars/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncps/README.md` — CREATE

## Acceptance Criteria

- [ ] Role structure complete
- [ ] config.toml.j2 templates upstream as ncro (127.0.0.1:8081)
- [ ] Container binds to 0.0.0.0 (accessible via Tailscale)
- [ ] All ports from infrastructure variables
- [ ] `no-new-privileges:true` set
- [ ] Healthcheck for `/healthz`
- [ ] ansible-lint passes with 0 warnings

## Test Plan

- ansible-lint on the role directory
- YAML syntax validation for all YAML files
- Template rendering test (after Story 03-001): `--check --diff` shows correct config

## Observability

- ncps exposes OpenTelemetry + Prometheus metrics — document in README
- Health endpoint: `/healthz`

## Compliance

- No secrets needed for ncps (it proxies to ncro, no auth)
- Config file deployed with userns-remap UID ownership

## Risks & Mitigations

- Risk: ncps image on GHCR may not be available or may be outdated — Mitigation: Pin to a specific version tag instead of `latest` (check ncps releases)
- Risk: ncps production warnings (early development) — Mitigation: Use released versions only, never main branch

## Dependencies & Sequencing

- Depends on: 01-001 (infrastructure variables for ports/storage)
- Unblocks: 03-001 (playbook), 04-001 (deployment)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded ports or IPs
- [ ] No files outside role directory modified

## STOP Conditions

Stop and report if:
- ncps GHCR image doesn't exist or is broken
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- ncps NAR cache may need periodic cleanup (LRU eviction is configurable in config.toml)
- Update upstream URL if ncro port changes (handled via infra variables)

## Commit Conventions

- `feat(nix-ncps): add Ansible role for ncps NAR caching proxy`

## Changelog

- 2026-07-08: initialized story file
