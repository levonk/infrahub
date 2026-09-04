---
story_id: "01-001"
story_title: "Cloud Server Variable Schema (group_vars)"
story_name: "group-vars"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 1
parallel_id: 1
branch: "feature/current/cloud-server/story-01-001-group-vars"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible", "variables"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "variables", "infra"]
due: "2026-06-05"
created_at: "2026-05-29"
updated_at: "2026-05-30"
---

## Summary

Define the complete Ansible variable schema for the cloud server in `levonk/active/02-config/ansible/group_vars/`. All IP addresses, ports, and service-specific values must be variables per AGENTS.md rules. This story establishes the contract that all downstream roles and playbooks will consume.

## Sub-Tasks

- [x] Create `levonk/active/02-config/ansible/group_vars/cloud_server.yml` with all variables from the PRD variable checklist
- [x] Add `cloud_server_ansible_host_ip` and related connection variables
- [x] Add SSH-related variables: `cloud_server_ssh_host_port`, `cloud_server_ssh_container_port`, `cloud_server_fail2ban_bantime`
- [x] Add VPN variables: `cloud_server_tailscale_port`, netbird mgmt/signal/turn host and container ports
- [x] Add DNS variables: `cloud_server_dns_host_port`, `cloud_server_dns_container_port`
- [x] Add proxy variables: `cloud_server_proxy_http_host_port`, `cloud_server_proxy_https_host_port`, etc.
- [x] Add Tor variables: `cloud_server_tor_socks_host_port`, `cloud_server_tor_socks_container_port`
- [x] Add DDNS variables: `cloud_server_ddns_update_interval`
- [x] Add KVM/networking variables: `cloud_server_kvm_bridge_subnet`, `cloud_server_vm_netbird_gateway_ip`
- [x] Add `levonk/active/02-config/ansible/group_vars/all.yml` with common cross-cutting variables (cuser UID/GID, timezone, etc.)
- [x] Document variable descriptions and defaults in role `README.md` templates

## Relevant Files

- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — cloud-server-specific variables
- `levonk/active/02-config/ansible/group_vars/all.yml` — common variables shared across hosts
- `shared/active/02-config/ansible/roles/*/defaults/main.yml` — role defaults that reference these vars

## Acceptance Criteria

- [x] All variables from the PRD variable checklist are defined in `group_vars`
- [x] No hardcoded IP addresses or ports exist in any Ansible task or compose file
- [x] Variables follow the `{CATEGORY}_{SERVICE}_{SUB}_{HOST|CONTAINER}_{PORT|IP}` naming convention
- [ ] `ansible-lint` passes on the variable files (deferred — ansible-lint not available in current environment)
- [x] Variables are referenced correctly by at least one role in `defaults/main.yml`

## Test Plan

- Lint: `devbox run ansible-lint levonk/active/02-config/ansible/group_vars/`
- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/site.yml`
- Verify no hardcoded IPs: `grep -rE '([0-9]{1,3}\.){3}[0-9]{1,3}' levonk/active/02-config/ansible/group_vars/ || true` (should only show variable definitions, not values in tasks)

## Observability

- Add `ansible_facts` logging at start of playbooks to verify variable resolution

## Compliance

- Variable naming convention per AGENTS.md IP/port rules
- No secrets in plain group_vars (use vault or external secret manager)

## Risks & Mitigations

- Risk: Variable naming conflicts with existing group_vars — Mitigation: Use `cloud_server_` prefix consistently
- Risk: Missing variables causing role failures — Mitigation: Include comprehensive defaults in each role

## Dependencies & Sequencing

- Depends on: None (foundation story)
- Unblocks: 01-002, 02-001..02-014

## Definition of Done

- Variable schema is complete, linted, and referenced by at least one role
- CI passes variable lint checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud server group_vars schema`
- `docs(ansible): document cloud server variable naming`

## Changelog

- 2026-05-29: initialized story file
