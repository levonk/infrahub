---
story_id: "02-007"
story_title: "Role: host-firewall"
story_name: "role-firewall"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 7
branch: "feature/current/cloud-server/story-02-007-role-firewall"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "security"]
priority: "MUST"
risk_level: "high"
tags: ["ansible", "role", "security", "firewall"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `host-firewall` Ansible role that configures a default-deny host-level firewall using nftables or ufw. Allows SSH, mosh, and VPN connections. This is a high-risk role because misconfiguration can lock out remote access.

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/proxy-firewall/`
- [ ] Create `defaults/main.yml` with firewall type (nftables/ufw), allowed ports, and VPN subnet variables
- [ ] Create `tasks/main.yml` with tasks for:
  - Install and enable nftables or ufw
  - Set default-deny policy
  - Allow loopback and established connections
  - Allow SSH on variable-driven port
  - Allow mosh on variable-driven port (after 05-002 confirmation)
  - Allow VPN subnets (Tailscale, Netbird)
  - Allow forwarding for VPN subnet routing with masquerade rules
  - Rate limiting on SSH port
  - Save and persist rules
- [ ] Create `handlers/main.yml` for firewall reload
- [ ] Create `meta/main.yml` with role metadata
- [ ] Create `README.md` documenting role variables
- [ ] Add `tests/` with test playbook
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-firewall/` — role directory
- `shared/active/02-config/ansible/roles/proxy-firewall/defaults/main.yml`
- `shared/active/02-config/ansible/roles/proxy-firewall/tasks/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — firewall port and subnet variables

## Acceptance Criteria

- [ ] Firewall is installed and running
- [ ] Default policy is deny
- [ ] SSH port is accessible
- [ ] VPN subnets can route through the host
- [ ] Forwarding and masquerade rules are configured
- [ ] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/proxy-firewall/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/proxy-firewall/tests/test.yml`
- Manual: Verify SSH connectivity after deployment; have console access as fallback

## Observability

- Log firewall rules after application
- Monitor dropped packets metric

## Compliance

- All ports and subnets must be variables
- Include rule to prevent lockout (temporary allow current session IP)

## Risks & Mitigations

- Risk: Lockout from remote host — Mitigation: Apply rules with `ansible.builtin.command` and a revert timer; test via console access
- Risk: VPN subnet rules too restrictive — Mitigation: Allow all VPN CIDRs from variable list

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-002 (VPN playbook), 05-002 (deploy VPN layer)

## Definition of Done

- Role configures firewall without locking out access
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add proxy-firewall role`
- `test(ansible): add proxy-firewall role tests`

## Changelog

- 2026-05-29: initialized story file
