---
story_id: "03-002"
story_title: "Playbook: cloud-server-vpn.yml"
story_name: "pb-vpn"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 3
parallel_id: 2
branch: "feature/current/cloud-server/story-03-002-pb-vpn"
status: "blocked"
assignee: ""
reviewer: ""
dependencies: ["02-005", "02-006", "02-007", "02-008", "02-009"]
parallel_safe: true
modules: ["ansible", "playbook"]
priority: "MUST"
risk_level: "high"
tags: ["ansible", "playbook", "vpn"]
due: "2026-06-19"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `cloud-server-vpn.yml` playbook that orchestrates the VPN mesh layer and security hardening: Tailscale, Netbird client, host firewall, SSH hardening, and fail2ban. This playbook should be deployed AFTER confirming bootstrap succeeded.

## Sub-Tasks

- [ ] Create `shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- [ ] Define `hosts: cloud_servers` target group
- [ ] Import roles in safe order:
  - `vpn-tailscale`
  - `vpn-netbird` (client)
  - `proxy-firewall`
  - `common-ssh-hardening`
  - `common-fail2ban`
- [ ] Add `pre_tasks` to verify bootstrap completed (check for Docker/Nix availability)
- [ ] Add `post_tasks` for VPN connectivity verification (`tailscale status`, `netbird status`)
- [ ] Add explicit SSH hardening pre-check: verify passwordless login works
- [ ] Document playbook usage and deployment order in README
- [ ] Verify `ansible-playbook --syntax-check` passes
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml` — VPN playbook
- `shared/active/02-config/ansible/roles/vpn-tailscale/` — role 02-005
- `shared/active/02-config/ansible/roles/vpn-netbird/` — role 02-006
- `shared/active/02-config/ansible/roles/proxy-firewall/` — role 02-007
- `shared/active/02-config/ansible/roles/common-ssh-hardening/` — role 02-008
- `shared/active/02-config/ansible/roles/common-fail2ban/` — role 02-009
- `levonk/active/02-config/ansible/inventories/oci.yml` — inventory

## Acceptance Criteria

- [ ] Playbook syntax is valid
- [ ] All five VPN/security roles are imported
- [ ] Pre-tasks verify bootstrap state
- [ ] Post-tasks verify VPN connectivity
- [ ] SSH hardening has explicit pre-condition check
- [ ] `ansible-lint` passes
- [ ] Can be executed via `devbox run ansible-playbook ...`

## Test Plan

- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- Lint: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`

## Observability

- Log each role execution status
- Capture Tailscale and Netbird status in post-tasks
- Monitor firewall rule application

## Compliance

- SSH hardening must NOT run without pre-condition verification
- No hardcoded values in playbook

## Risks & Mitigations

- Risk: SSH hardening locks out agent — Mitigation: Pre-condition check + console access backup
- Risk: Firewall rules block VPN traffic — Mitigation: Allow VPN subnets before applying default-deny

## Dependencies & Sequencing

- Depends on: 02-005, 02-006, 02-007, 02-008, 02-009
- Unblocks: 05-002 (deploy VPN layer to OCI)

## Definition of Done

- Playbook is complete, linted, and validated
- CI passes playbook checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud-server-vpn playbook`
- `docs(ansible): document vpn playbook usage and safety checks`

## Changelog

- 2026-05-29: initialized story file
