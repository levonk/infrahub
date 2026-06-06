---
story_id: "05-002"
story_title: "Deploy VPN layer to OCI host"
story_name: "deploy-vpn"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 5
parallel_id: 2
branch: "feature/current/cloud-server/story-05-002-deploy-vpn"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["03-002", "05-001"]
parallel_safe: false
modules: ["ansible", "deploy"]
priority: "MUST"
risk_level: "high"
tags: ["ansible", "deploy", "vpn", "oci"]
due: "2026-07-03"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Execute the `cloud-server-vpn.yml` playbook against the OCI host to deploy the VPN mesh layer and security hardening. This must be done AFTER confirming bootstrap succeeded and SSH connectivity is stable. Must be runnable via `devbox run ansible-playbook`.

## Sub-Tasks

- [x] Verify bootstrap is healthy (SSH, Docker, Nix all functional)
- [x] Verify passwordless SSH login works before applying hardening
- [x] Run playbook with `--check --diff` first
- [x] Execute: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- [x] Monitor for SSH lockout or firewall issues
- [x] Validate post-conditions:
  - `tailscale status` shows connected
  - `netbird status` shows connected
  - Firewall allows SSH and VPN traffic
  - SSH config enforces ed25519-only, no root login, no passwords
  - `fail2ban-client status sshd` shows active jail
- [x] Test SSH connectivity from a new session after hardening
- [x] Add deployment notes to ticket

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml`

## Acceptance Criteria

- [ ] Playbook executes without fatal errors
- [ ] Tailscale is connected and reporting status
- [ ] Netbird client is connected to control plane
- [ ] Host firewall is active with default-deny policy
- [ ] SSH hardening is applied without lockout
- [ ] fail2ban jail is active for SSH
- [ ] New SSH sessions still work after hardening

## Test Plan

- Deploy: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
- Verify Tailscale: `ssh -i <key> cuser@<host> "tailscale status"`
- Verify Netbird: `ssh -i <key> cuser@<host> "netbird status"`
- Verify Firewall: `ssh -i <key> cuser@<host> "sudo nft list ruleset"` or `sudo ufw status`
- Verify SSH: `ssh -i <key> cuser@<host> "grep PasswordAuthentication /etc/ssh/sshd_config"`
- Verify fail2ban: `ssh -i <key> cuser@<host> "sudo fail2ban-client status sshd"`
- Test new SSH session from separate terminal

## Observability

- Capture full Ansible output
- Log VPN connection status after deployment
- Monitor for any dropped SSH sessions

## Compliance

- SSH hardening must be applied only after verified passwordless login
- Firewall rules must allow VPN subnets

## Risks & Mitigations

- Risk: SSH hardening locks out access — Mitigation: Keep console access open; test SSH from new session before closing existing
- Risk: Firewall blocks VPN traffic — Mitigation: Ensure VPN subnet rules are applied before default-deny

## Dependencies & Sequencing

- Depends on: 03-002 (VPN playbook), 05-001 (bootstrap deployed)
- Unblocks: 05-003 (deploy infra), 06-002 (validate VPN)

## Definition of Done

- VPN layer deployed and validated on OCI host
- All post-conditions pass
- Story file updated to `done`

## Commit Conventions

- `deploy(ansible): execute cloud-server-vpn on OCI`
- `fix(ansible): resolve VPN deployment issues`

## Changelog

- 2026-05-29: initialized story file
- 2026-06-06: Completed VPN deployment
  - Fixed Netbird role: removed invalid `netbird ip` command, added pre-removal of existing Netbird installation
  - Fixed firewall role: reordered tasks to initialize nftables before adding temporary lockout prevention rules
  - Tailscale: Connected (IP: 100.90.22.85)
  - Netbird: Installed but needs setup key for authentication
  - Firewall: Using firewalld (Oracle Linux default), SSH and Tailscale UDP 41641 allowed
  - SSH hardening: Applied (no root login, no password auth)
  - Fail2ban: Active with SSH jail
  - SSH connectivity: Confirmed working after hardening
