---
story_id: "02-005"
story_title: "Create nix-client-config Ansible role (nix.conf substituters)"
story_name: "client-config-role"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 5
branch: "feature/current/nix-cache-chain/story-02-005-client-config-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["shared/02-config/ansible/roles/nix-client-config"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "role", "nix", "config"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create the `nix-client-config` Ansible role that configures `/etc/nix/nix.conf` (or equivalent) on all Nix-running machines with the correct substituter chain: local Harmonia (priority 10) + regional ncps (priority 20). Includes `trusted-public-keys` for all caches. This role handles the per-machine regional ncps IP selection (LAN machines → dtop202311, cloud machines → oci-cloud-server).

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/roles/agentmemory/` — reference role pattern (for structure)
  - `shared/active/02-config/ansible/roles/cloudflare-ddns/templates/ddns-update.sh.j2` — Jinja2 template reference

- **nix.conf requirements (from PRD FR-5):**
  ```
  substituters = [
    "http://127.0.0.1:<harmonia_port>?priority=10"
    "http://<regional_ncps_tailscale_ip>:<ncps_port>?priority=20"
  ]
  ```
  - Regional ncps IP:
    - LAN machines (lzkmbp2016, lzkmbp2018, dtop202311) → dtop202311 Tailscale IP
    - Cloud machines (oci-cloud-server, isolation-vm) → oci-cloud-server Tailscale IP
  - Include `trusted-public-keys` for Harmonia signing key + cache.nixos.org key

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-client-config/` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/02-config/ansible/roles/nix-client-config/` with:
  - `defaults/main.yml` — harmonia port, ncps port, Harmonia public key, regional ncps IP selection logic
  - `tasks/main.yml` — validate, determine regional ncps IP based on host group, deploy nix.conf template, restart nix daemon (if applicable)
  - `templates/nix.conf.j2` — Jinja2 template for nix.conf with substituters and trusted-public-keys
  - `handlers/main.yml` — restart nix daemon handler
  - `meta/main.yml`, `vars/main.yml`, `README.md`

**Out of scope:**
- Service deployment roles (Stories 02-001 through 02-004)
- Playbook (Story 03-001)
- Actual deployment (Story 04-002)

## Sub-Tasks

- [ ] Task 1 — Create `defaults/main.yml`
  Define: `nix_client_config_enabled: true`, `nix_harmonia_port: "{{ infra_port_nix_harmonia_container | default('5000') }}"`, `nix_ncps_port: "{{ infra_port_nix_ncps_container | default('8080') }}"`, `nix_harmonia_public_key: "levonk-harmonia-cache-1:<FROM_STORY_01-003>"` (the public key generated alongside the signing key), `nix_client_config_file: "/etc/nix/nix.conf"` (override for macOS: `/etc/nix/nix.conf` or nix-darwin managed), regional ncps IP variables from infra vars.
  **Verify**: `python3 -c "import yaml; yaml.safe_load(open('shared/active/02-config/ansible/roles/nix-client-config/defaults/main.yml'))"` → exit 0

- [ ] Task 2 — Create `templates/nix.conf.j2`
  Template nix.conf with:
  ```
  substituters = [
    "http://127.0.0.1:{{ nix_harmonia_port }}?priority=10"
    "http://{{ nix_client_regional_ncps_ip }}:{{ nix_ncps_port }}?priority=20"
  ]
  trusted-public-keys = [
    "{{ nix_harmonia_public_key }}"
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="
  ]
  ```
  Also include standard nix.conf settings (connect-timeout, stalled-timeout, etc. — check existing nix.conf on machines for current settings to preserve).
  **Verify**: Template file exists and contains `priority=10` and `priority=20`

- [ ] Task 3 — Create `tasks/main.yml`
  Structure: (1) Validate vars. (2) Determine regional ncps IP: set `nix_client_regional_ncps_ip` based on inventory group membership — if host in `lan_nix_clients` group → dtop202311 Tailscale IP (`infra_network_nix_ncps_lan_ts_ip`), if in `cloud_nix_clients` group → oci-cloud-server Tailscale IP (`infra_network_nix_ncps_cloud_ts_ip`). Use `ansible.builtin.set_fact` with group check. (3) Deploy nix.conf from template (backup existing first). (4) Notify restart nix handler. (5) Report.
  **Verify**: `devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-client-config/tasks/main.yml` → exit 0

- [ ] Task 4 — Create `handlers/main.yml`, `meta/main.yml`, `vars/main.yml`, `README.md`
  Handler: restart nix daemon (platform-specific: `systemctl restart nix-daemon` on Linux, `launchctl kickstart -k org.nixos.nix-daemon` on macOS, none on Windows/Docker). Meta: role_name: nix-client-config, dependencies: [common]. README: document regional IP selection, nix.conf format, platform-specific restart.
  **Verify**: All files exist

- [ ] Task 5 — Run ansible-lint on the full role
  **Verify**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint shared/active/02-config/ansible/roles/nix-client-config/` → exit 0, no warnings

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-client-config/defaults/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/tasks/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/templates/nix.conf.j2` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/handlers/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/meta/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/vars/main.yml` — CREATE
- `shared/active/02-config/ansible/roles/nix-client-config/README.md` — CREATE

## Acceptance Criteria

- [ ] Role structure complete
- [ ] nix.conf.j2 has correct substituter chain (Harmonia priority 10, ncps priority 20)
- [ ] Regional ncps IP selection works based on inventory group membership
- [ ] trusted-public-keys includes Harmonia public key + cache.nixos.org key
- [ ] Platform-specific nix daemon restart handler (Linux/macOS)
- [ ] ansible-lint passes with 0 warnings

## Test Plan

- ansible-lint on the role directory
- YAML syntax validation
- Template rendering: verify substituter chain and regional IP selection

## Observability

- No metrics — this is a config file deployment

## Compliance

- No secrets in nix.conf (only public keys, which are non-secret)
- Existing nix.conf must be backed up before overwriting

## Risks & Mitigations

- Risk: Overwriting existing nix.conf loses custom settings — Mitigation: Backup existing file before deploying; preserve existing settings by merging rather than replacing
- Risk: macOS nix.conf may be managed by nix-darwin — Mitigation: Check if nix-darwin is in use; if so, deploy via nix-darwin configuration instead of direct file replacement
- Risk: Windows Docker Desktop Nix may not use /etc/nix/nix.conf — Mitigation: Skip Windows or use WSL2 Nix config path

## Dependencies & Sequencing

- Depends on: 01-001 (infrastructure variables for ports and Tailscale IPs)
- Unblocks: 03-001 (playbook), 04-002 (deployment)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] No hardcoded IPs or ports
- [ ] No files outside role directory modified

## STOP Conditions

Stop and report if:
- nix-darwin is managing nix.conf on macOS (need different approach)
- Existing nix.conf has critical settings that would be lost
- ansible-lint fails after reasonable fix attempts

## Maintenance Notes

- When a new Nix machine is added, add it to the appropriate inventory group (lan_nix_clients or cloud_nix_clients)
- Harmonia public key must be updated if signing key is rotated (Story 01-003)
- Regional ncps IPs must be updated if regional hubs change

## Commit Conventions

- `feat(nix-client-config): add Ansible role for nix.conf substituter chain configuration`

## Changelog

- 2026-07-08: initialized story file
