---
story_id: "01-001"
story_title: "Infrastructure variables for Nix cache chain (ports, storage, Tailscale IPs)"
story_name: "infra-variables"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 1
parallel_id: 1
branch: "feature/current/nix-cache-chain/story-01-001-infra-variables"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared/02-config/ansible/infrastructure", "levonk/02-config/ansible/infrastructure"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "infrastructure", "ansible"]
due: "2026-07-15"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Add infrastructure variables for the Nix cache chain services (Harmonia, ncps, ncro, Attic) to the shared schema files and levonk client value overrides. This is the foundation story — all other stories depend on these variables being defined. Covers ports, storage paths, and Tailscale IPs/network entries needed by the 4 service roles and the client config role.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/infrastructure/ports.yml` — shared port allocation schema. Pattern: `infra_port_{SERVICE}_{CONTEXT}_{HOST|CONTAINER}`. All ports are strings. Existing examples: `infra_port_ai_agentmemory_host: "3111"`, `infra_port_registry_host: "5000"`.
  - `shared/active/02-config/ansible/infrastructure/storage.yml` — shared storage path schema. Pattern: `infra_storage_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`. Base dirs: `infra_storage_base_dir: "/opt/localnet"`, `infra_storage_services_dir: "/opt/localnet/services"`, `infra_storage_data_dir: "/opt/localnet/data"`. userns-remap UID: `infra_storage_userns_remap_uid: 100000`.
  - `shared/active/02-config/ansible/infrastructure/networks.yml` — shared network topology. Pattern: `infra_network_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`. Contains VPN subnets, Docker network names, service IP allocations.
  - `shared/active/02-config/ansible/infrastructure/domains.yml` — shared domain schema. Contains `infra_tailscale_tailnet: "example.ts.net"` (overridden in levonk to `"tale-grouper.ts.net"`).
  - `levonk/active/02-config/ansible/infrastructure/ports.yml` — client port overrides.
  - `levonk/active/02-config/ansible/infrastructure/storage.yml` — client storage overrides.
  - `levonk/active/02-config/ansible/infrastructure/networks.yml` — client network overrides. Contains `infra_network_isolation_vm_ip: "192.168.100.147"`.

- **Existing code excerpts (port pattern from shared/ports.yml):**
  ```yaml
  # Local Docker Registry Port
  infra_port_registry_host: "5000"
  infra_port_registry_container: "5000"
  ```

- **Existing code excerpts (storage pattern from shared/storage.yml):**
  ```yaml
  infra_storage_agentmemory_config: "{{ infra_storage_services_dir }}/agentmemory/config"
  infra_storage_agentmemory_data: "{{ infra_storage_data_dir }}/agentmemory"
  ```

- **Repository conventions:**
  - All ports/IPs/domains MUST be infrastructure variables — NEVER hardcoded (AGENTS.md IP and Port Configuration Rules)
  - `shared/` is client-agnostic — no client-specific values (AGENTS.md Invariant #1)
  - Variable naming: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}`
  - All ports are strings (quoted) for YAML compatibility
  - Client-specific values go in `levonk/active/02-config/ansible/infrastructure/`

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | YAML lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/infrastructure/ports.yml` | exit 0 |
  | YAML syntax | `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/infrastructure/ports.yml'))"` | exit 0 |

## Scope

**In scope:**
- Add port variables to `shared/active/02-config/ansible/infrastructure/ports.yml`:
  - `infra_port_nix_harmonia_host: "5000"` / `infra_port_nix_harmonia_container: "5000"`
  - `infra_port_nix_ncps_host: "8080"` / `infra_port_nix_ncps_container: "8080"`
  - `infra_port_nix_ncro_host: "8081"` / `infra_port_nix_ncro_container: "8081"`
  - `infra_port_nix_attic_host: "8082"` / `infra_port_nix_attic_container: "8082"`
- Add storage paths to `shared/active/02-config/ansible/infrastructure/storage.yml`:
  - `infra_storage_nix_harmonia_config: "{{ infra_storage_services_dir }}/nix-harmonia/config"`
  - `infra_storage_nix_harmonia_data: "{{ infra_storage_data_dir }}/nix-harmonia"`
  - `infra_storage_nix_ncps_config: "{{ infra_storage_services_dir }}/nix-ncps/config"`
  - `infra_storage_nix_ncps_data: "{{ infra_storage_data_dir }}/nix-ncps"`
  - `infra_storage_nix_ncro_config: "{{ infra_storage_services_dir }}/nix-ncro/config"`
  - `infra_storage_nix_ncro_data: "{{ infra_storage_data_dir }}/nix-ncro"`
  - `infra_storage_nix_attic_config: "{{ infra_storage_services_dir }}/nix-attic/config"`
  - `infra_storage_nix_attic_data: "{{ infra_storage_data_dir }}/nix-attic"`
- Add Tailscale IP variables to `levonk/active/02-config/ansible/infrastructure/networks.yml`:
  - `infra_network_nix_harmonia_lzkmbp2016_ts_ip: "100.x.y.z"` (look up actual Tailscale IP from existing inventory — `lzkmbp2016.tale-grouper.ts.net`)
  - `infra_network_nix_harmonia_lzkmbp2018_ts_ip` (same pattern)
  - `infra_network_nix_harmonia_dtop202311_ts_ip`
  - `infra_network_nix_harmonia_oci_cloud_ts_ip: "100.90.22.85"` (known from registry URL)
  - `infra_network_nix_harmonia_isolation_vm_ts_ip`
  - `infra_network_nix_ncps_lan_ts_ip` (dtop202311 Tailscale IP — for LAN clients)
  - `infra_network_nix_ncps_cloud_ts_ip: "100.90.22.85"` (oci-cloud-server — for cloud clients)
- Add `infra_tailscale_tailnet: "tale-grouper.ts.net"` override to `levonk/active/02-config/ansible/infrastructure/domains.yml` if not already present (it may already be there — check first)

**Out of scope:**
- Ansible roles (Phase 2)
- Playbook creation (Phase 3)
- Vault secrets (Story 01-003)
- Container image builds (Stories 01-004, 01-005, 02-006)

## Sub-Tasks

- [ ] Task 1 — Add Nix cache port variables to `shared/active/02-config/ansible/infrastructure/ports.yml`
  Add a new section `# Nix Cache Chain Ports` with the 4 service port pairs (harmonia, ncps, ncro, attic). Follow the existing pattern (string values, `infra_port_nix_{SERVICE}_{host|container}`).
  **Verify**: `python3 -c "import yaml; d=yaml.safe_load(open('shared/active/02-config/ansible/infrastructure/ports.yml')); assert d['infra_port_nix_harmonia_host']=='5000'; assert d['infra_port_nix_attic_container']=='8082'; print('OK')"` → `OK`

- [ ] Task 2 — Add Nix cache storage paths to `shared/active/02-config/ansible/infrastructure/storage.yml`
  Add a new section `# Nix Cache Chain Storage` with config and data paths for all 4 services, following the `infra_storage_{service}_{config|data}` pattern using `infra_storage_services_dir` and `infra_storage_data_dir` base variables.
  **Verify**: `python3 -c "import yaml; d=yaml.safe_load(open('shared/active/02-config/ansible/infrastructure/storage.yml')); assert 'nix-harmonia' in d['infra_storage_nix_harmonia_data']; print('OK')"` → `OK`

- [ ] Task 3 — Add Tailscale IP variables to `levonk/active/02-config/ansible/infrastructure/networks.yml`
  Look up actual Tailscale IPs for all 5 Nix-running machines from the inventory files (lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm). The oci-cloud-server IP is `100.90.22.85` (from the registry URL). For others, check `levonk/active/02-config/ansible/inventories/` host definitions or use `tailscale status` on the control machine. Add variables: `infra_network_nix_ts_ip_{hostname}` for each machine, plus `infra_network_nix_ncps_lan_ts_ip` and `infra_network_nix_ncps_cloud_ts_ip` for the regional ncps endpoints.
  **Verify**: `python3 -c "import yaml; d=yaml.safe_load(open('levonk/active/02-config/ansible/infrastructure/networks.yml')); assert d['infra_network_nix_ncps_cloud_ts_ip']=='100.90.22.85'; print('OK')"` → `OK`

- [ ] Task 4 — Verify no port conflicts
  Grep all existing port variables to ensure 5000, 8080, 8081, 8082 don't conflict with existing allocations. Note: `infra_port_registry_host: "5000"` already uses 5000 — Harmonia uses 5000 inside the container but binds to 127.0.0.1, and the host port may need to differ if the registry is on the same host. If conflict on oci-cloud-server, set `infra_port_nix_harmonia_host` to a different value in `levonk/active/02-config/ansible/infrastructure/ports.yml` (e.g., `"5001"`).
  **Verify**: `grep -E '"5000"|"8080"|"8081"|"8082"' shared/active/02-config/ansible/infrastructure/ports.yml | grep -v nix` → no nix-cache variables appear in non-nix lines (or if 5000 conflicts with registry, the levonk override resolves it)

- [ ] Task 5 — Run ansible-lint on infrastructure files
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/infrastructure/ports.yml shared/active/02-config/ansible/infrastructure/storage.yml` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/ports.yml` — add Nix cache port variables
- `shared/active/02-config/ansible/infrastructure/storage.yml` — add Nix cache storage paths
- `levonk/active/02-config/ansible/infrastructure/networks.yml` — add Tailscale IPs for ncro upstream config
- `levonk/active/02-config/ansible/infrastructure/ports.yml` — add client-specific port overrides if needed (e.g., harmonia host port if 5000 conflicts with registry)

## Acceptance Criteria

- [ ] All 4 services have host/container port pairs defined in shared/ports.yml
- [ ] All 4 services have config and data storage paths defined in shared/storage.yml
- [ ] Tailscale IPs for all 5 Nix-running machines are defined in levonk/networks.yml
- [ ] Regional ncps endpoint IPs (LAN + cloud) are defined in levonk/networks.yml
- [ ] No port conflicts with existing infrastructure variables
- [ ] ansible-lint passes on modified infrastructure files

## Test Plan

- YAML syntax validation: `python3 -c "import yaml; yaml.safe_load(open('<file>'))"` for each modified file
- ansible-lint: `devbox run -- rtk ansible-lint <file>` for each modified file
- Port conflict check: grep for duplicate port values across all infrastructure files

## Observability

- No metrics/logging changes — this story only adds variables

## Compliance

- No regulatory concerns — infrastructure variable definitions only

## Risks & Mitigations

- Risk: Port 5000 conflicts with local Docker registry on oci-cloud-server — Mitigation: Override `infra_port_nix_harmonia_host` in levonk/ports.yml to a non-conflicting port (e.g., 5001) if needed
- Risk: Tailscale IPs may change — Mitigation: Use Tailscale FQDNs (`hostname.tale-grouper.ts.net`) where possible instead of raw IPs; document that IPs must be updated when machines change

## Dependencies & Sequencing

- Depends on: None (foundation story)
- Unblocks: All Phase 2 stories (02-001 through 02-005), Story 03-001

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded IPs or ports in any role/playbook that references these variables
- [ ] No files outside in-scope list are modified (`git status`)

## STOP Conditions

Stop and report if:
- A Tailscale IP cannot be determined for a machine (machine not in inventory or not reachable)
- A port conflict cannot be resolved (all alternative ports also conflict)
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- When a new Nix-running machine is added, add its Tailscale IP to levonk/networks.yml
- When a machine is removed, update the ncro upstream list (handled in Story 02-003)
- Port allocations are permanent — do not change without coordinated update of all referencing roles

## Commit Conventions

- `feat(infra): add nix-cache-chain port, storage, and network variables`

## Changelog

- 2026-07-08: initialized story file
