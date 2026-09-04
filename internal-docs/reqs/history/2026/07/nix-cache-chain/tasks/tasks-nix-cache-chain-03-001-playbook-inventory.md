---
story_id: "03-001"
story_title: "Create nix-cache.yml playbook and inventory groups"
story_name: "playbook-inventory"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 3
parallel_id: 1
branch: "feature/current/nix-cache-chain/story-03-001-playbook-inventory"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003", "02-004", "02-005"]
parallel_safe: false
modules: ["shared/02-config/ansible/playbooks", "levonk/02-config/ansible/inventories"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "playbook", "inventory"]
due: "2026-07-29"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-cache.yml` playbook that orchestrates deployment of all 4 Nix cache services (Harmonia, ncps, ncro, Attic) plus the client config role. Add inventory groups to the existing inventory files to define which machines run which services. This is the integration story that ties all Phase 2 roles together.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/playbooks/deploy-langfuse.yml` — reference playbook pattern. Structure: DNS play (localhost) → deployment play (target hosts) with pre_tasks (load infra vars, validate), tasks (deploy via roles), post_tasks (verify).
  - `shared/active/02-config/ansible/playbooks/deploy-local-registry.yml` — simpler playbook pattern (single play, pre_tasks load infra vars, tasks deploy container)
  - `levonk/active/02-config/ansible/inventories/oci.yml` — OCI inventory (cloud_servers, isolation_vms, vpn_proxy_servers groups). Parent: `infrahub-levonk-all.vault` for vault auto-loading.
  - `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — Mac inventory (macos_hosts group: lzkmbp2016, lzkmbp2018)
  - `levonk/active/02-config/ansible/inventories/windows-docker.yml` — Windows inventory (windows_docker_hosts group: dtop202311)
  - `levonk/active/02-config/ansible/inventories/localnet.yml` — Localnet inventory (localnet_hosts group: kckinai — NOT a Nix machine)

- **Existing code excerpts (deploy-langfuse.yml pre_tasks pattern — infra var loading):**
  ```yaml
  pre_tasks:
    - name: "Load shared infrastructure defaults (ports, networks, domains, storage)"
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../infrastructure/{{ item }}"
      loop:
        - ports.yml
        - networks.yml
        - domains.yml
        - storage.yml
      tags: ["always"]

    - name: "Load client infrastructure overrides (levonk)"
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../../../../../levonk/active/02-config/ansible/infrastructure/{{ item }}"
      loop:
        - ports.yml
        - networks.yml
        - domains.yml
        - storage.yml
      tags: ["always"]
  ```

- **Inventory group requirements (from PRD architecture):**
  - `nix_harmonia_hosts`: lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm (all 5 Nix machines)
  - `nix_ncps_hosts`: dtop202311, oci-cloud-server (2 regional hubs)
  - `nix_ncro_hosts`: dtop202311, oci-cloud-server (2 regional hubs, co-located with ncps)
  - `nix_attic_hosts`: oci-cloud-server (cloud cache only)
  - `lan_nix_clients`: lzkmbp2016, lzkmbp2018, dtop202311 (use dtop202311 ncps)
  - `cloud_nix_clients`: oci-cloud-server, isolation-vm (use oci-cloud-server ncps)

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/playbooks/nix-cache.yml` | exit 0 |
  | Syntax check | `devbox run -- rtk ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/nix-cache.yml` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/playbooks/nix-cache.yml` — multi-play playbook:
  - Play 1: Deploy Harmonia on `nix_harmonia_hosts` (role: nix-harmonia)
  - Play 2: Deploy ncps on `nix_ncps_hosts` (role: nix-ncps)
  - Play 3: Deploy ncro on `nix_ncro_hosts` (role: nix-ncro)
  - Play 4: Deploy Attic on `nix_attic_hosts` (role: nix-attic)
  - Play 5: Deploy client config on `nix_harmonia_hosts` (role: nix-client-config)
  - Each play loads shared + client infra vars in pre_tasks
- Add inventory groups to existing inventory files:
  - `levonk/active/02-config/ansible/inventories/oci.yml` — add `nix_harmonia_hosts`, `nix_ncps_hosts`, `nix_ncro_hosts`, `nix_attic_hosts`, `cloud_nix_clients` groups
  - `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — add `nix_harmonia_hosts`, `lan_nix_clients` groups
  - `levonk/active/02-config/ansible/inventories/windows-docker.yml` — add `nix_harmonia_hosts`, `nix_ncps_hosts`, `nix_ncro_hosts`, `lan_nix_clients` groups

**Out of scope:**
- Role implementations (Phase 2 stories)
- Actual deployment execution (Phase 4 stories)
- DNS configuration (Nix cache services are Tailscale-only, no public DNS needed)

## Sub-Tasks

- [ ] Task 1 — Add inventory groups to `levonk/active/02-config/ansible/inventories/oci.yml`
  Add groups under `infrahub-levonk-all.vault` children: `nix_harmonia_hosts` (children: cloud_servers, isolation_vms), `nix_ncps_hosts` (hosts: oci-cloud-server), `nix_ncro_hosts` (hosts: oci-cloud-server), `nix_attic_hosts` (hosts: oci-cloud-server), `cloud_nix_clients` (children: cloud_servers, isolation_vms).
  **Verify**: `devbox run -- rtk ansible-inventory -i levonk/active/02-config/ansible/inventories/oci.yml --list | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'nix_harmonia_hosts' in d; print('OK')"` → `OK`

- [ ] Task 2 — Add inventory groups to `levonk/active/02-config/ansible/inventories/macos-hosts.yml`
  Add groups: `nix_harmonia_hosts` (children: macos_hosts), `lan_nix_clients` (children: macos_hosts).
  **Verify**: `devbox run -- rtk ansible-inventory -i levonk/active/02-config/ansible/inventories/macos-hosts.yml --list | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'lan_nix_clients' in d; print('OK')"` → `OK`

- [ ] Task 3 — Add inventory groups to `levonk/active/02-config/ansible/inventories/windows-docker.yml`
  Add groups: `nix_harmonia_hosts` (children: windows_docker_hosts), `nix_ncps_hosts` (children: windows_docker_hosts), `nix_ncro_hosts` (children: windows_docker_hosts), `lan_nix_clients` (children: windows_docker_hosts).
  **Verify**: `devbox run -- rtk ansible-inventory -i levonk/active/02-config/ansible/inventories/windows-docker.yml --list | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'nix_ncps_hosts' in d; print('OK')"` → `OK`

- [ ] Task 4 — Create `shared/active/02-config/ansible/playbooks/nix-cache.yml`
  Multi-play playbook following the deploy-langfuse.yml pattern. Each play: `hosts: <group>`, `become: true` (Linux) / `become: false` (macOS/Windows), pre_tasks (load shared + client infra vars, validate), roles (the appropriate nix-cache role). Use tags for selective deployment: `[harmonia]`, `[ncps]`, `[ncro]`, `[attic]`, `[client-config]`.
  **Verify**: `devbox run -- rtk ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/nix-cache.yml` → exit 0

- [ ] Task 5 — Run ansible-lint on the playbook
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/playbooks/nix-cache.yml` → exit 0, no warnings

- [ ] Task 6 — Verify all inventory groups resolve correctly
  Create a combined inventory (or use ansible-inventory with multiple -i flags) and verify that `nix_harmonia_hosts` contains all 5 machines, `nix_ncps_hosts` contains 2, etc.
  **Verify**: `devbox run -- rtk ansible-inventory -i levonk/active/02-config/ansible/inventories/oci.yml -i levonk/active/02-config/ansible/inventories/macos-hosts.yml -i levonk/active/02-config/ansible/inventories/windows-docker.yml --graph` → shows all groups with correct host membership

## Relevant Files

- `shared/active/02-config/ansible/playbooks/nix-cache.yml` — CREATE
- `levonk/active/02-config/ansible/inventories/oci.yml` — MODIFY (add groups)
- `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — MODIFY (add groups)
- `levonk/active/02-config/ansible/inventories/windows-docker.yml` — MODIFY (add groups)

## Acceptance Criteria

- [ ] `nix-cache.yml` playbook passes syntax check
- [ ] All 5 inventory groups exist across the 3 inventory files
- [ ] `nix_harmonia_hosts` contains all 5 Nix machines (lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm)
- [ ] `nix_ncps_hosts` and `nix_ncro_hosts` contain dtop202311 + oci-cloud-server
- [ ] `nix_attic_hosts` contains oci-cloud-server only
- [ ] `lan_nix_clients` contains lzkmbp2016, lzkmbp2018, dtop202311
- [ ] `cloud_nix_clients` contains oci-cloud-server, isolation-vm
- [ ] ansible-lint passes on the playbook
- [ ] Playbook uses tags for selective deployment

## Test Plan

- ansible-playbook --syntax-check on the playbook
- ansible-inventory --graph to verify group membership
- ansible-lint on the playbook
- Dry run: `devbox run -- rtk ansible-playbook --check --diff -i <inventory> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags harmonia`

## Observability

- No metrics changes — playbook orchestration only

## Compliance

- No secrets in playbook (all from vault via roles)
- Inventory groups follow existing naming conventions

## Risks & Mitigations

- Risk: Inventory group conflicts with existing groups — Mitigation: Use `nix_` prefix for all new groups to avoid collisions
- Risk: macOS `become: false` may cause role tasks that need root to fail — Mitigation: Roles should use `become: true` on individual tasks that need it (following the macos-hosts.yml pattern)
- Risk: Windows Docker Desktop may not support all role tasks — Mitigation: Test with `--check --diff` first; document any Windows-specific limitations

## Dependencies & Sequencing

- Depends on: 02-001 (harmonia role), 02-002 (ncps role), 02-003 (ncro role), 02-004 (attic role), 02-005 (client-config role)
- Unblocks: 04-001 (deploy cache services), 04-002 (deploy client config)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No files outside in-scope list are modified
- [ ] Playbook can be run with `--tags` for selective deployment

## STOP Conditions

Stop and report if:
- Inventory group structure conflicts with existing groups
- ansible-playbook --syntax-check fails after reasonable fix attempts
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- When a new Nix machine is added, add it to the appropriate inventory groups
- When a regional hub changes, update `nix_ncps_hosts` and `nix_ncro_hosts`
- Playbook tags allow selective deployment: `--tags harmonia`, `--tags ncps`, etc.

## Commit Conventions

- `feat(nix-cache): add nix-cache.yml playbook and inventory groups`

## Changelog

- 2026-07-08: initialized story file
