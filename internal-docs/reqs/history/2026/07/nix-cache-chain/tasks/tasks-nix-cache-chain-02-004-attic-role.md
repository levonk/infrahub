---
story_id: "02-004"
story_title: "Create nix-attic Ansible role"
story_name: "attic-role"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 4
branch: "feature/current/nix-cache-chain/story-02-004-attic-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-003"]
parallel_safe: true
modules: ["shared/02-config/ansible/roles/nix-attic"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "role", "nix"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-attic` Ansible role that deploys the Attic (multi-tenant Nix binary cache) container on oci-cloud-server only. Attic binds to 0.0.0.0 (accessible via Tailscale), uses local storage, and requires `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` from vault. Includes a Jinja2 template for `attic.toml`.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/roles/agentmemory/` — reference role pattern
  - `shared/active/03-container/services/artifact/nix-attic/flake.nix` — existing flake. Shows: `Entrypoint = atticd`, port 8080, `ATTIC_SERVER_DATABASE_URL=sqlite:///data/server.db`, needs `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64`

- **Attic specifics (from PRD FR-4):**
  - Deploys on oci-cloud-server ONLY
  - Binds to 0.0.0.0 (accessible via Tailscale)
  - Port: `infra_port_nix_attic_container` (default 8082)
  - Uses local storage (bind mount)
  - Requires `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` (from vault: `vault_nix_attic_token_secret`)
  - Requires `attic.toml` configuration (deployed via Ansible template)
  - Image: `100.90.22.85:5000/localnet-nix-attic:latest` (built in Story 01-005)
  - Health: `curl http://<oci-cloud>:8082/api/v1/`
  - Database: SQLite at `/data/server.db` (from flake env)

- **Existing code excerpts (Attic README attic.toml example):**
  ```toml
  listen = "[::]:8080"
  [database]
  url = "sqlite:///data/server.db"
  [storage]
  type = "local"
  path = "/data/storage"
  [chunking]
  nar-size-threshold = 65536
  min-size = 16384
  avg-size = 65536
  max-size = 262144
  ```

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-attic/` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/roles/nix-attic/` with:
  - `defaults/main.yml` — container config, ports, volume, token secret from vault, healthcheck, logging
  - `tasks/main.yml` — validate, create config dir, deploy attic.toml template, pull image, deploy container (0.0.0.0 bind), wait for health, report
  - `templates/attic.toml.j2` — Jinja2 template for Attic config (listen, database, storage, chunking)
  - `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`

**Out of scope:**
- Building the Attic image (Story 01-005)
- Playbook (Story 03-001)
- Deployment (Story 04-001)

## Sub-Tasks

- [ ] Task 1 — Create `defaults/main.yml`
  Define: `nix_attic_enabled: true`, `nix_attic_container_name: "localnet-nix-attic"`, `nix_attic_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-nix-attic"`, `nix_attic_image_tag: "latest"`, `nix_attic_host_port: "{{ infra_port_nix_attic_host | default('8082') }}"`, `nix_attic_container_port: "{{ infra_port_nix_attic_container | default('8082') }}"`, `nix_attic_data_dir: "/data"`, `nix_attic_config_dir: "{{ infra_storage_nix_attic_config | default('/opt/localnet/services/nix-attic/config') }}"`, `nix_attic_token_secret: "{{ vault_nix_attic_token_secret | default('') }}"`, healthcheck vars, logging vars.
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-attic/defaults/main.yml'))"` → exit 0

- [ ] Task 2 — Create `templates/attic.toml.j2`
  Template: `listen = "[::]:{{ nix_attic_container_port }}"`, `[database]` url = sqlite, `[storage]` type local path /data/storage, `[chunking]` defaults from README example.
  **Verify**: Template file exists and contains `{{ nix_attic_container_port }}`

- [ ] Task 3 — Create `tasks/main.yml`
  Structure: (1) Validate vars (assert nix_attic_token_secret length > 0, infra vars defined). (2) Create config dir (userns-remap UID). (3) Deploy attic.toml from template. (4) Create data volume. (5) Pull image. (6) Deploy container with: ports `{{ nix_attic_host_port }}:{{ nix_attic_container_port }}/tcp` (0.0.0.0), volumes (data volume + config mount), env (ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64, TZ), security_opts, healthcheck `curl -fsS http://127.0.0.1:{{ nix_attic_container_port }}/api/v1/ || exit 1`. (7) Wait for health. (8) Report.
  **Verify**: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-attic/tasks/main.yml` → exit 0

- [ ] Task 4 — Create `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`
  Standard patterns. README: document token secret requirement, attic.toml config, 0.0.0.0 bind.
  **Verify**: All files exist

- [ ] Task 5 — Run ansible-lint on the full role
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-attic/` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-attic/defaults/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/tasks/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/templates/attic.toml.j2` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/handlers/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/meta/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/vars/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-attic/README.md` — CREATE

## Acceptance Criteria

- [ ] Role structure complete
- [ ] attic.toml.j2 templates listen port from infra variable
- [ ] Container binds to 0.0.0.0
- [ ] ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64 from vault (never hardcoded)
- [ ] `no-new-privileges:true` set
- [ ] Healthcheck for `/api/v1/`
- [ ] ansible-lint passes with 0 warnings

## Test Plan

- ansible-lint on the role directory
- YAML syntax validation

## Observability

- Attic has basic health via API endpoint — document in README

## Compliance

- Token secret from vault, `no_log: true` on env injection
- Attic is GPL-3.0 — note in README

## Risks & Mitigations

- Risk: Attic "early prototype" status (171 open issues) — Mitigation: Use for cloud cache only, not critical path; ncro provides fallback via other upstreams
- Risk: SQLite may not scale for large caches — Mitigation: Acceptable for single-server deployment; can migrate to PostgreSQL later

## Dependencies & Sequencing

- Depends on: 01-001 (infrastructure variables), 01-003 (vault for token secret)
- Unblocks: 03-001 (playbook), 04-001 (deployment — also needs 01-005 for the image)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded ports or IPs
- [ ] No files outside role directory modified

## STOP Conditions

Stop and report if:
- Attic config format is incompatible with expected TOML schema
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- Attic storage may need periodic cleanup (GC) — document in README
- Token rotation: update vault + restart Attic container

## Commit Conventions

- `feat(nix-attic): add Ansible role for Attic binary cache server`

## Changelog

- 2026-07-08: initialized story file
