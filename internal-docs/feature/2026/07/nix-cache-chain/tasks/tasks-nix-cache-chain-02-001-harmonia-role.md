---
story_id: "02-001"
story_title: "Create nix-harmonia Ansible role"
story_name: "harmonia-role"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 1
branch: "feature/current/nix-cache-chain/story-02-001-harmonia-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-003"]
parallel_safe: true
modules: ["shared/02-config/ansible/roles/nix-harmonia"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "role", "nix"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-harmonia` Ansible role that deploys the Harmonia container on all 5 Nix-running machines. Harmonia binds to 127.0.0.1 only, reads `/nix/store:ro`, and requires a signing key (from vault). This role follows the exact pattern of the existing `agentmemory` role — using `community.docker.docker_container`, infrastructure variables for ports, `no-new-privileges:true`, healthchecks, and standard role structure.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/roles/agentmemory/` — reference role pattern. Has defaults/main.yml, tasks/main.yml, handlers/main.yml, meta/main.yml, vars/main.yml, README.md.
  - `shared/active/02-config/ansible/roles/agentmemory/defaults/main.yml` — shows port pattern: `agentmemory_host_port: "{{ infra_port_ai_agentmemory_host | default('3111') }}"`, image pattern: `agentmemory_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-agentmemory"`
  - `shared/active/02-config/ansible/roles/agentmemory/tasks/main.yml` — shows: validate vars → create volume → pull image → deploy container (with security_opts, healthcheck, log_driver) → wait for health → report status
  - `shared/active/02-config/ansible/roles/agentmemory/handlers/main.yml` — restart handler pattern
  - `shared/active/02-config/ansible/roles/agentmemory/meta/main.yml` — galaxy_info + dependencies: [common]

- **Existing code excerpts (agentmemory defaults/main.yml — pattern to follow):**
  ```yaml
  agentmemory_container_name: "localnet-agentmemory"
  agentmemory_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-agentmemory"
  agentmemory_image_tag: "latest"
  agentmemory_host_port: "{{ infra_port_ai_agentmemory_host | default('3111') }}"
  agentmemory_container_port: "{{ infra_port_ai_agentmemory_container | default('3111') }}"
  agentmemory_volume_name: "localnet-agentmemory-data-volume"
  agentmemory_data_dir: "/data"
  agentmemory_healthcheck_interval: "30s"
  agentmemory_healthcheck_timeout: "5s"
  agentmemory_healthcheck_retries: 3
  agentmemory_healthcheck_start_period: "30s"
  agentmemory_log_max_size: "10m"
  agentmemory_log_max_file: "5"
  ```

- **Existing code excerpts (agentmemory tasks/main.yml — container deployment pattern):**
  ```yaml
  - name: Deploy agentmemory container
    community.docker.docker_container:
      name: "{{ agentmemory_container_name }}"
      image: "{{ agentmemory_image_name }}:{{ agentmemory_image_tag }}"
      state: started
      restart_policy: unless-stopped
      ports:
        - "{{ agentmemory_host_port }}:{{ agentmemory_container_port }}/tcp"
      volumes:
        - "{{ agentmemory_volume_name }}:{{ agentmemory_data_dir }}:rw"
      env:
        TZ: "{{ localnet_tz | default('UTC') }}"
      log_driver: json-file
      log_options:
        max-size: "{{ agentmemory_log_max_size }}"
        max-file: "{{ agentmemory_log_max_file }}"
      security_opts:
        - no-new-privileges:true
      healthcheck:
        test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:{{ agentmemory_container_port }}/agentmemory/livez || exit 1"]
        interval: "{{ agentmemory_healthcheck_interval }}"
        timeout: "{{ agentmemory_healthcheck_timeout }}"
        retries: "{{ agentmemory_healthcheck_retries }}"
        start_period: "{{ agentmemory_healthcheck_start_period }}"
  ```

- **Harmonia specifics (from PRD FR-1 and flake.nix):**
  - Container reads `/nix/store:ro` from host
  - Binds to 127.0.0.1 ONLY (not exposed to network)
  - Port: `infra_port_nix_harmonia_container` (default 5000)
  - Requires `HARMONIA_SIGN_KEY_PATH=/data/secret-key.sec` env
  - Signing key from vault: `vault_nix_harmonia_sign_key`
  - Health endpoint: `http://127.0.0.1:5000/nix-cache-info`
  - Image: `100.90.22.85:5000/localnet-nix-harmonia:latest` (built in Story 01-004)
  - 5 target machines: lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm
  - macOS uses OrbStack, Linux uses Docker, Windows uses Docker Desktop

- **Repository conventions:**
  - All containers use `community.docker.docker_container` (NEVER docker compose, NEVER systemd)
  - All ports reference infrastructure variables
  - `no-new-privileges:true` on all containers
  - Healthchecks with string values (e.g., "30s")
  - Role naming: functional-group prefix (`nix-harmonia`, not just `harmonia`)
  - Standard role structure: defaults/, handlers/, meta/, tasks/, vars/, README.md

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-harmonia/` | exit 0, no warnings |
  | YAML syntax | `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-harmonia/defaults/main.yml'))"` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/roles/nix-harmonia/` with full role structure:
  - `defaults/main.yml` — default variables (container name, image, ports from infra vars, volume, healthcheck, logging)
  - `tasks/main.yml` — validate vars, create data volume, deploy signing key from vault, pull image, deploy container, wait for health, report status
  - `handlers/main.yml` — restart handler
  - `meta/main.yml` — galaxy info, dependencies: [common]
  - `vars/main.yml` — empty (convention)
  - `README.md` — documentation

**Out of scope:**
- Building the Harmonia image (Story 01-004)
- Creating the playbook (Story 03-001)
- Deploying to machines (Story 04-001)
- nix.conf configuration (Story 02-005)

## Sub-Tasks

- [ ] Task 1 — Create `defaults/main.yml`
  Define: `nix_harmonia_enabled: true`, `nix_harmonia_container_name: "localnet-nix-harmonia"`, `nix_harmonia_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-nix-harmonia"`, `nix_harmonia_image_tag: "latest"`, `nix_harmonia_host_port: "{{ infra_port_nix_harmonia_host | default('5000') }}"`, `nix_harmonia_container_port: "{{ infra_port_nix_harmonia_container | default('5000') }}"`, `nix_harmonia_volume_name: "localnet-nix-harmonia-data"`, `nix_harmonia_data_dir: "/data"`, `nix_harmonia_sign_key: "{{ vault_nix_harmonia_sign_key | default('') }}"`, healthcheck vars (interval "30s", timeout "5s", retries 3, start_period "10s"), logging vars (max_size "10m", max_file "5").
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-harmonia/defaults/main.yml'))"` → exit 0

- [ ] Task 2 — Create `tasks/main.yml`
  Structure: (1) Validate required vars (assert infra_port_nix_harmonia_host, nix_harmonia_sign_key defined, localnet_services_dir defined). (2) Create data volume. (3) Deploy signing key file from vault variable to a host path (use `ansible.builtin.copy` with `content: "{{ nix_harmonia_sign_key }}"`, `dest: "{{ localnet_services_dir }}/nix-harmonia/secret-key.sec"`, `mode: "0600"`, `no_log: true`). (4) Pull image. (5) Deploy container with: `ports: "127.0.0.1:{{ nix_harmonia_host_port }}:{{ nix_harmonia_container_port }}/tcp"` (127.0.0.1 bind), `volumes`: data volume + `/nix/store:/nix/store:ro` + signing key file mount, `env`: HARMONIA_SIGN_KEY_PATH=/data/secret-key.sec, TZ, `security_opts: [no-new-privileges:true]`, healthcheck `curl -fsS http://127.0.0.1:{{ nix_harmonia_container_port }}/nix-cache-info || exit 1`. (6) Wait for health. (7) Report status.
  **Verify**: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-harmonia/tasks/main.yml` → exit 0

- [ ] Task 3 — Create `handlers/main.yml`
  Restart handler: `restart nix-harmonia` using `community.docker.docker_container` with `restart: true`.
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-harmonia/handlers/main.yml'))"` → exit 0

- [ ] Task 4 — Create `meta/main.yml`
  Galaxy info: role_name: nix-harmonia, author: localnet, description, license: MIT, min_ansible_version: "2.9", platforms (Ubuntu, Debian), galaxy_tags [nix, cache, docker]. Dependencies: [common].
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-harmonia/meta/main.yml'))"` → exit 0

- [ ] Task 5 — Create `vars/main.yml` and `README.md`
  vars/main.yml: empty (just a comment). README.md: document purpose, variables, vault requirements, deployment.
  **Verify**: Files exist and are non-empty

- [ ] Task 6 — Run ansible-lint on the full role
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-harmonia/` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-harmonia/defaults/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-harmonia/tasks/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-harmonia/handlers/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-harmonia/meta/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-harmonia/vars/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-harmonia/README.md` — CREATE

## Acceptance Criteria

- [ ] Role directory structure complete (defaults, handlers, meta, tasks, vars, README)
- [ ] All ports reference infrastructure variables (no hardcoded ports)
- [ ] Container binds to 127.0.0.1 only (not 0.0.0.0)
- [ ] `/nix/store` mounted read-only
- [ ] Signing key deployed from vault with `no_log: true`
- [ ] `no-new-privileges:true` set
- [ ] Healthcheck configured for `/nix-cache-info`
- [ ] ansible-lint passes with 0 warnings

## Test Plan

- ansible-lint: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-harmonia/`
- YAML syntax: `python3 -c "import yaml; ..."` for each YAML file
- Dry run (after Story 03-001): `devbox run -- rtk ansible-playbook --check --diff`

## Observability

- Healthcheck: `curl http://127.0.0.1:5000/nix-cache-info` on each machine
- Harmonia exposes Prometheus metrics — document in README

## Compliance

- Signing key must never be logged (`no_log: true` on the copy task)
- Signing key stored in vault, never in shared/

## Risks & Mitigations

- Risk: macOS OrbStack `/nix/store` bind mount may differ from Linux Docker — Mitigation: Test on one Mac first; OrbStack supports bind mounts to host paths
- Risk: Windows Docker Desktop may not have `/nix/store` on the host filesystem — Mitigation: Harmonia on Windows may need a different volume strategy or may only work if Nix is installed via WSL2; document this as a potential STOP condition
- Risk: Port 5000 conflicts with local registry on oci-cloud-server — Mitigation: Story 01-001 handles port override in levonk/ports.yml

## Dependencies & Sequencing

- Depends on: 01-001 (infrastructure variables), 01-003 (vault secrets for signing key)
- Unblocks: 03-001 (playbook includes this role), 04-001 (deployment)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded ports or IPs
- [ ] No files outside `shared/active/02-config/ansible/roles/nix-harmonia/` are modified

## STOP Conditions

Stop and report if:
- The agentmemory role pattern doesn't apply to Harmonia (different container requirements)
- Windows Docker Desktop cannot bind-mount `/nix/store` (document as known limitation)
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- When a new Nix machine is added, add it to the `nix_harmonia_hosts` inventory group (Story 03-001)
- Signing key rotation: update vault + restart all Harmonia containers + update nix.conf trusted-public-keys
- Harmonia reads /nix/store directly — no cache invalidation needed

## Commit Conventions

- `feat(nix-harmonia): add Ansible role for Harmonia container deployment`

## Changelog

- 2026-07-08: initialized story file
