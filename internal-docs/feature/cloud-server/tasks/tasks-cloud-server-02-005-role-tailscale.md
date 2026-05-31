---
story_id: "02-005"
story_title: "Role: tailscale-vpn"
story_name: "role-tailscale"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 5
branch: "feature/current/cloud-server/story-02-005-role-tailscale"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "vpn"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "role", "vpn", "tailscale"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `tailscale-vpn` Ansible role that installs and configures the Tailscale daemon as a host-level overlay mesh VPN. This role follows the functional-group prefix convention (`vpn-tailscale` if needed per naming rules).

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/vpn-tailscale/`
- [x] Create `defaults/main.yml` with Tailscale version, auth key variable, and port settings
- [x] Create `tasks/main.yml` with tasks for:
  - Install Tailscale daemon (via Nix or official repository)
  - Configure Tailscale with `--advertise-routes` if needed
  - Start and enable Tailscale service
  - Verify `tailscale status` shows connected
- [x] Create `handlers/main.yml` for Tailscale service restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables (including auth key handling)
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes — verified via `devbox run ansible-lint`, 0 failures, 0 warnings, production profile

## Relevant Files

- `shared/active/02-config/ansible/roles/vpn-tailscale/` — role directory
- `shared/active/02-config/ansible/roles/vpn-tailscale/defaults/main.yml` — neutral defaults with port variable
- `shared/active/02-config/ansible/roles/vpn-tailscale/tasks/main.yml` — install, configure, verify Tailscale daemon
- `shared/active/02-config/ansible/roles/vpn-tailscale/handlers/main.yml` — tailscaled restart handler
- `shared/active/02-config/ansible/roles/vpn-tailscale/meta/main.yml` — Galaxy metadata (Debian/Ubuntu support)
- `shared/active/02-config/ansible/roles/vpn-tailscale/README.md` — role documentation and variable reference
- `shared/active/02-config/ansible/roles/vpn-tailscale/tests/test.yml` — test playbook for dry-run
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Tailscale port variable (`cloud_server_tailscale_port`)

## Acceptance Criteria

- [x] Tailscale daemon is installed and running — implemented via apt + systemd in `tasks/main.yml`
- [x] `tailscale status` reports connected state — verified via `ansible.builtin.command tailscale status`
- [x] Service is enabled for auto-start — `systemd enabled: true` in tasks and handlers
- [x] Port configuration matches `cloud_server_tailscale_port` variable — defaults pull from `cloud_server_tailscale_port` with fallback to `41641`
- [x] `ansible-lint` passes — verified via `devbox run ansible-lint shared/active/02-config/ansible/roles/vpn-tailscale/`, 0 failures, 0 warnings on 7 files, production profile met

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/vpn-tailscale/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/vpn-tailscale/tests/test.yml`

## Observability

- Log Tailscale status and IP after connection
- Monitor Tailscale daemon health

## Compliance

- Auth key stored in vault/secret manager, never in plain group_vars
- No hardcoded IPs or ports

## Risks & Mitigations

- Risk: Auth key expiration — Mitigation: Document key rotation procedure
- Risk: Tailscale service conflicts with other VPNs — Mitigation: Verify with netbird-client role testing

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-002 (VPN playbook), 05-002 (deploy VPN layer)

## Definition of Done

- Role installs and connects Tailscale correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add vpn-tailscale role`
- `test(ansible): add vpn-tailscale role tests`

## Changelog

- 2026-05-29: initialized story file
