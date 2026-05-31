---
story_id: "02-005"
story_title: "Role: tailscale-vpn"
story_name: "role-tailscale"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 5
branch: "feature/current/cloud-server/story-02-005-role-tailscale"
status: "todo"
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
updated_at: "2026-05-29"
---

## Summary

Create the `tailscale-vpn` Ansible role that installs and configures the Tailscale daemon as a host-level overlay mesh VPN. This role follows the functional-group prefix convention (`vpn-tailscale` if needed per naming rules).

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/vpn-tailscale/`
- [ ] Create `defaults/main.yml` with Tailscale version, auth key variable, and port settings
- [ ] Create `tasks/main.yml` with tasks for:
  - Install Tailscale daemon (via Nix or official repository)
  - Configure Tailscale with `--advertise-routes` if needed
  - Start and enable Tailscale service
  - Verify `tailscale status` shows connected
- [ ] Create `handlers/main.yml` for Tailscale service restart
- [ ] Create `meta/main.yml` with role metadata
- [ ] Create `README.md` documenting role variables (including auth key handling)
- [ ] Add `tests/` with test playbook
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/vpn-tailscale/` — role directory
- `shared/active/02-config/ansible/roles/vpn-tailscale/defaults/main.yml`
- `shared/active/02-config/ansible/roles/vpn-tailscale/tasks/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Tailscale port and auth variables

## Acceptance Criteria

- [ ] Tailscale daemon is installed and running
- [ ] `tailscale status` reports connected state
- [ ] Service is enabled for auto-start
- [ ] Port configuration matches `cloud_server_tailscale_port` variable
- [ ] `ansible-lint` passes

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
