---
story_id: "06-002"
story_title: "Validate VPN mesh connectivity"
story_name: "validate-vpn"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 6
parallel_id: 2
branch: "feature/current/cloud-server/story-06-002-validate-vpn"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["05-002"]
parallel_safe: true
modules: ["test", "validation"]
priority: "MUST"
risk_level: "low"
tags: ["test", "validation", "vpn"]
due: "2026-07-10"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Validate that the VPN mesh layer and security hardening are functioning correctly on the OCI host. Verify Tailscale connectivity, Netbird client status, firewall rules, SSH hardening, and fail2ban operation.

## Sub-Tasks

- [ ] Create `shared/active/02-config/ansible/playbooks/validate-vpn.yml`
- [ ] Add tasks to verify:
  - `tailscale status` shows connected with IP
  - `tailscale ping <known-peer>` works (if test peer available)
  - `netbird status` shows connected to management server
  - `netbird peers list` shows expected peers
  - Firewall default-deny policy is active
  - SSH port is accessible from management IP
  - SSH config rejects password and root login
  - `fail2ban-client status sshd` shows active jail with bantime matching variable
  - VPN subnet routing works (ping across VPN)
- [ ] Run validation playbook: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vpn.yml`
- [ ] Document any failures and create follow-up tickets

## Relevant Files

- `shared/active/02-config/ansible/playbooks/validate-vpn.yml` — validation playbook
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — expected values

## Acceptance Criteria

- [ ] Validation playbook exists and runs without errors
- [ ] Tailscale is connected and functional
- [ ] Netbird client is connected and peer discovery works
- [ ] Firewall enforces default-deny with VPN exceptions
- [ ] SSH hardening is active and doesn't lock out legitimate access
- [ ] fail2ban jail is active

## Test Plan

- Run: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vpn.yml`
- Manual: Verify `tailscale status` and `netbird status` from host

## Observability

- Log VPN peer status and latency
- Capture firewall rule summary
- Record fail2ban ban stats

## Compliance

- Validation must confirm no lockout risk remains
- Firewall rules must be documented

## Risks & Mitigations

- Risk: Test peers not available for connectivity tests — Mitigation: Skip peer-specific tests; focus on daemon status
- Risk: Firewall rules differ between check and reality — Mitigation: Use `iptables -L` or `nft list ruleset` directly

## Dependencies & Sequencing

- Depends on: 05-002 (VPN deployed)
- Unblocks: 06-005 (final audit)

## Definition of Done

- VPN validation passes cleanly
- All components confirmed healthy
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add VPN validation playbook`
- `test(ansible): validate VPN deployment on OCI`

## Changelog

- 2026-05-29: initialized story file
