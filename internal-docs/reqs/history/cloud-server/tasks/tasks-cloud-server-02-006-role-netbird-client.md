---
story_id: "02-006"
story_title: "Role: netbird-client"
story_name: "role-netbird-client"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 6
branch: "feature/current/cloud-server/story-02-006-role-netbird-client"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "vpn"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "role", "vpn", "netbird"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-30"
---

## Summary

Create the `netbird-client` Ansible role that installs the Netbird gateway agent with WireGuard support. This is the host-level Netbird client that connects to the control plane (self-hosted in 02-010 or managed initially).

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/vpn-netbird/`
- [x] Create `defaults/main.yml` with Netbird version, management URL, and setup key variables
- [x] Create `tasks/main.yml` with tasks for:
  - Install WireGuard kernel module / `wireguard-tools`
  - Install Netbird client (official package or Nix)
  - Configure Netbird client with management server URL
  - Register client using setup key (variable-driven)
  - Start and enable Netbird service
  - Verify `netbird status` shows connected
- [x] Create `handlers/main.yml` for Netbird service restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/vpn-netbird/` — role directory
- `shared/active/02-config/ansible/roles/vpn-netbird/defaults/main.yml`
- `shared/active/02-config/ansible/roles/vpn-netbird/tasks/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Netbird mgmt/signal/turn port variables

## Acceptance Criteria

- [x] WireGuard tools are installed
- [x] Netbird client is installed and running
- [x] `netbird status` reports connected to management server
- [x] Service is enabled for auto-start
- [x] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/vpn-netbird/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/vpn-netbird/tests/test.yml`

## Observability

- Log Netbird peer IP and status after connection
- Monitor Netbird daemon health

## Compliance

- Setup key stored in vault/secret manager
- No hardcoded management server URLs (use variables)

## Risks & Mitigations

- Risk: Self-hosted control plane not ready — Mitigation: Support managed Netbird initially, migrate later
- Risk: WireGuard module missing on cloud kernel — Mitigation: Install wireguard-tools which provides userspace fallback

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-002 (VPN playbook), 05-002 (deploy VPN layer)

## Definition of Done

- Role installs and connects Netbird client correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add vpn-netbird client role`
- `test(ansible): add vpn-netbird client role tests`

## Changelog

- 2026-05-29: initialized story file
