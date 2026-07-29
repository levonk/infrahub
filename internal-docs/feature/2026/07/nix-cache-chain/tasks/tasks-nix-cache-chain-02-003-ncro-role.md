---
story_id: "02-003"
story_title: "Create nix-ncro Ansible role"
story_name: "ncro-role"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 3
branch: "feature/current/nix-cache-chain/story-02-003-ncro-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-003"]
parallel_safe: true
modules: ["shared/02-config/ansible/roles/nix-ncro"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "ansible", "role", "nix"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-ncro` Ansible role that deploys the ncro (parallel racing Nix cache proxy) container on 2 regional hubs (dtop202311, oci-cloud-server). ncro races all upstreams in parallel (all Harmonia instances, Attic, Cachix, cache.nixos.org) and binds to 127.0.0.1 (only ncps talks to it). This is the highest-risk role because ncro is a new project with no Docker image (built in Stories 01-002/02-006). Includes a Jinja2 template for ncro's TOML config with the full upstream list.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/roles/agentmemory/` — reference role pattern
  - `shared/active/02-config/ansible/roles/cloudflare-ddns/templates/ddns-update.sh.j2` — Jinja2 template reference
  - `shared/active/03-container/services/artifact/nix-ncro/config.toml` — reference config (created in Story 01-002)

- **ncro specifics (from PRD FR-3 and ADR):**
  - Deploys on dtop202311 and oci-cloud-server (co-located with ncps)
  - Races all upstreams in parallel: all 5 Harmonia instances (via Tailscale IPs), Attic on OCI, Cachix (if credentials available), cache.nixos.org
  - Binds to 127.0.0.1 ONLY (only ncps talks to it)
  - Port: `infra_port_nix_ncro_container` (default 8081)
  - Config: TOML format, deployed via Ansible template
  - Image: `100.90.22.85:5000/localnet-nix-ncro:latest` (built in Story 02-006)
  - Health endpoint: `/health` (returns JSON with upstream status)
  - Needs small SQLite DB for EMA latency tracking (stored in /data)
  - Optional Cachix auth token from vault: `vault_cachix_auth_token`

- **Upstream list for ncro config (from PRD architecture diagram):**
  - `http://<lzkmbp2016-ts-ip>:5000` (Harmonia)
  - `http://<lzkmbp2018-ts-ip>:5000` (Harmonia)
  - `http://<dtop202311-ts-ip>:5000` (Harmonia, local)
  - `http://<oci-cloud-ts-ip>:5000` (Harmonia)
  - `http://<isolation-vm-ts-ip>:5000` (Harmonia)
  - `http://<oci-cloud-ts-ip>:8082` (Attic)
  - `https://cache.nixos.org`
  - `https://<cachix>.cachix.org` (if vault_cachix_auth_token is set)

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncro/` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/roles/nix-ncro/` with:
  - `defaults/main.yml` — container config, ports, volume, upstream list from infra vars, Cachix token from vault, healthcheck, logging
  - `tasks/main.yml` — validate, create config dir, deploy config.toml template, pull image, deploy container (127.0.0.1 bind), wait for health, report
  - `templates/config.toml.j2` — Jinja2 template with all upstreams (Harmonia instances via Tailscale IPs, Attic, cache.nixos.org, optional Cachix)
  - `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`

**Out of scope:**
- Building the ncro image (Stories 01-002, 02-006)
- ncps role (Story 02-002)
- Playbook (Story 03-001)

## Sub-Tasks

- [ ] Task 1 — Create `defaults/main.yml`
  Define: `nix_ncro_enabled: true`, `nix_ncro_container_name: "localnet-nix-ncro"`, `nix_ncro_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-nix-ncro"`, `nix_ncro_image_tag: "latest"`, `nix_ncro_host_port: "{{ infra_port_nix_ncro_host | default('8081') }}"`, `nix_ncro_container_port: "{{ infra_port_nix_ncro_container | default('8081') }}"`, `nix_ncro_data_dir: "/data"`, `nix_ncro_config_dir: "{{ infra_storage_nix_ncro_config | default('/opt/localnet/services/nix-ncro/config') }}"`, `nix_ncro_cachix_token: "{{ vault_cachix_auth_token | default('') }}"`, `nix_ncro_upstreams` list (built from infra Tailscale IP variables + Attic + nixos.org), healthcheck vars, logging vars.
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-ncro/defaults/main.yml'))"` → exit 0

- [ ] Task 2 — Create `templates/config.toml.j2`
  Template ncro TOML config: listen `127.0.0.1`, port `{{ nix_ncro_container_port }}`, upstream list (loop over `nix_ncro_upstreams`), optional Cachix section (conditional on `nix_ncro_cachix_token | length > 0`), logging level info, SQLite DB path `/data/ncro.db`.
  **Verify**: Template file exists and contains `{% for %}` or `{{ nix_ncro_upstreams }}`

- [ ] Task 3 — Create `tasks/main.yml`
  Structure: (1) Validate vars (assert infra_port_nix_ncro_host, nix_ncro_upstreams defined). (2) Create config dir (userns-remap UID). (3) Deploy config.toml from template (notify restart). (4) Create data volume. (5) Pull image. (6) Deploy container with: ports `127.0.0.1:{{ nix_ncro_host_port }}:{{ nix_ncro_container_port }}/tcp` (127.0.0.1 bind), volumes (data volume + config mount), env (CACHIX_AUTH_TOKEN if set, TZ), security_opts, healthcheck `curl -fsS http://127.0.0.1:{{ nix_ncro_container_port }}/health || exit 1`. (7) Wait for health. (8) Report.
  **Verify**: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncro/tasks/main.yml` → exit 0

- [ ] Task 4 — Create `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`
  Standard patterns. README: document upstream list, Cachix optional, 127.0.0.1 bind, health endpoint.
  **Verify**: All files exist

- [ ] Task 5 — Run ansible-lint on the full role
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-ncro/` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-ncro/defaults/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/tasks/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/templates/config.toml.j2` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/handlers/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/meta/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/vars/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-ncro/README.md` — CREATE

## Acceptance Criteria

- [ ] Role structure complete
- [ ] config.toml.j2 includes all 5 Harmonia upstreams + Attic + cache.nixos.org
- [ ] Cachix upstream is conditional (only if vault token is set)
- [ ] Container binds to 127.0.0.1 only
- [ ] All IPs from infrastructure variables (no hardcoded Tailscale IPs)
- [ ] `no-new-privileges:true` set
- [ ] Healthcheck for `/health`
- [ ] ansible-lint passes with 0 warnings

## Test Plan

- ansible-lint on the role directory
- YAML syntax validation
- Template rendering: verify upstream list resolves correctly with infra vars

## Observability

- ncro exposes Prometheus metrics (7 metrics) — document in README
- Health endpoint: `/health` returns JSON with upstream status

## Compliance

- Cachix auth token from vault, never in shared/ — use `no_log: true` if token appears in task output
- ncro is EUPL 1.2 licensed — note in README

## Risks & Mitigations

- Risk: ncro is a new project (May 2026) — Mitigation: Simple architecture, stateless data path, test thoroughly on one regional hub first
- Risk: ncro image may not be in registry yet (depends on Stories 01-002 + 02-006) — Mitigation: Role can be created before image is pushed; deployment (Story 04-001) requires the image
- Risk: Tailscale IPs may not be reachable from all regional hubs — Mitigation: ncro handles upstream failures gracefully (parallel race, picks fastest available)

## Dependencies & Sequencing

- Depends on: 01-001 (infrastructure variables for Tailscale IPs), 01-003 (vault for Cachix token)
- Unblocks: 03-001 (playbook), 04-001 (deployment — also needs 02-006 for the image)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded IPs or ports
- [ ] No files outside role directory modified

## STOP Conditions

Stop and report if:
- ncro config format is incompatible with the TOML template (check ncro docs for exact config schema)
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- ncro upstream list must be updated when machines are added/removed from infrastructure
- ncro EMA latency tracking is automatic — no manual tuning needed
- SQLite DB at /data/ncro.db persists across container restarts (volume mount)

## Commit Conventions

- `feat(nix-ncro): add Ansible role for ncro parallel racing proxy`

## Changelog

- 2026-07-08: initialized story file
