---
story_id: "06-005"
story_title: "Security hardening & final audit"
story_name: "final-audit"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 6
parallel_id: 5
branch: "feature/current/cloud-server/story-06-005-final-audit"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["06-001", "06-002", "06-003", "06-004"]
parallel_safe: true
modules: ["security", "audit"]
priority: "MUST"
risk_level: "high"
tags: ["security", "audit", "compliance"]
due: "2026-07-10"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Perform a comprehensive security audit of the deployed cloud server. Verify all hardening measures, check for misconfigurations, document gaps, and create improvement tickets. This is the final quality gate before declaring the cloud server deployment complete.

## Sub-Tasks

- [ ] Run automated security scan (Lynis, OpenSCAP, or custom Ansible checks)
- [ ] Verify no hardcoded IPs or ports in any deployed config:
  - `grep -rE '([0-9]{1,3}\.){3}[0-9]{1,3}' /etc/ssh/ /etc/docker/ /etc/systemd/ || true`
- [ ] Verify SSH hardening:
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - Only ed25519 keys accepted
- [ ] Verify firewall default-deny policy
- [ ] Verify fail2ban is active and configured
- [ ] Verify Docker daemon hardening (userns-remap, no-new-privileges)
- [ ] Verify no unnecessary services are running
- [ ] Verify automatic security updates are configured
- [ ] Review all deployed container images for latest/security patches
- [ ] Document any security gaps or TODOs
- [ ] Create follow-up tickets for any unresolved items
- [ ] Update `AGENTS.md` with any new conventions discovered
- [ ] Write deployment runbook for future OCI hosts

## Relevant Files

- `shared/active/02-config/ansible/playbooks/final-audit.yml` — audit playbook (create if needed)
- All deployed configuration files on OCI host
- `shared/active/03-container/AGENTS.md` — update if needed

## Acceptance Criteria

- [ ] Security scan completes with acceptable risk rating
- [ ] No hardcoded IPs/ports found in deployed configs
- [ ] SSH hardening is confirmed active
- [ ] Firewall is enforcing default-deny
- [ ] fail2ban is operational
- [ ] Docker daemon is hardened
- [ ] All unnecessary services are disabled
- [ ] Automatic updates are active
- [ ] Audit findings are documented
- [ ] Improvement tickets are created for gaps

## Test Plan

- Run: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/final-audit.yml`
- Manual: Review scan output and configuration files

## Observability

- Log security scan results
- Track audit findings and remediation status

## Compliance

- Follow AGENTS.md security standards
- Document all deviations with justification

## Risks & Mitigations

- Risk: Security scan finds critical issues — Mitigation: Create high-priority tickets; fix before declaring complete
- Risk: Audit scope is too broad — Mitigation: Focus on PRD requirements and AGENTS.md standards

## Dependencies & Sequencing

- Depends on: 06-001, 06-002, 06-003, 06-004 (all validation stories)
- Unblocks: None (final story)

## Definition of Done

- Final audit passes with no critical findings
- All gaps documented with improvement tickets
- Deployment runbook is written
- Story file updated to `done`
- PRD requirements are fully satisfied

## Commit Conventions

- `audit(ansible): perform final security audit of cloud server`
- `docs(ansible): add cloud server deployment runbook`
- `fix(ansible): resolve audit findings`

## Changelog

- 2026-05-29: initialized story file
