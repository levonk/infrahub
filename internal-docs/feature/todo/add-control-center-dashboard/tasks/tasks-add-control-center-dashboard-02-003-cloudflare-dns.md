---
story_id: "02-003"
story_title: "Add Cloudflare DNS entries for both domains"
story_name: "cloudflare-dns"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 2
parallel_id: 3
branch: "feature/current/add-control-center-dashboard/story-02-003-cloudflare-dns"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["shared/playbooks/configure-cloudflare-dns.yml"]
priority: "MUST"
risk_level: "low"
tags: ["dns", "cloudflare", "ansible", "playbook"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Add CNAME records for dashboard.levonk.com and dashboard.nl.levonk.com to the configure-cloudflare-dns.yml playbook, pointing to the Windows Docker host Tailscale FQDN.

## Current State

- `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` — existing Cloudflare DNS configuration playbook with CNAME entries for nl domains
- No control-center DNS entries exist yet
- Windows Docker host has a Tailscale FQDN (`ts_fqdn_windows_docker`)

## Scope

- Add CNAME entry for dashboard.nl.levonk.com → ts_fqdn_windows_docker
- Add CNAME entry for dashboard.levonk.com → dashboard.nl.levonk.com (alias to nl)

## Sub-Tasks

- [ ] Read `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` to find the pattern for nl domains
- [ ] Add CNAME entry for dashboard.nl.levonk.com → ts_fqdn_windows_docker
- [ ] Add CNAME entry for dashboard.levonk.com → dashboard.nl.levonk.com (alias to nl)

## Relevant Files

- `shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` — add CNAME entries

## Acceptance Criteria

- Given the playbook, When inspecting, Then a CNAME entry for dashboard.nl.levonk.com → ts_fqdn_windows_docker exists
- Given the playbook, When inspecting, Then a CNAME entry for dashboard.levonk.com → dashboard.nl.levonk.com exists
- Given the playbook, When `ansible-syntax` runs, Then it passes
- Verify: `grep dashboard.levonk.com shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` shows both entries

## Test Plan

- `grep dashboard.levonk.com shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` shows both entries
- `grep dashboard.nl.levonk.com shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml` shows the nl entry
- `just ansible-syntax` passes

## Observability

- DNS propagation can be verified with `dig dashboard.levonk.com CNAME` and `dig dashboard.nl.levonk.com CNAME`
- Cloudflare dashboard shows the new records after playbook execution

## Compliance

- DNS entries follow existing CNAME pattern in the playbook
- No hardcoded IPs — CNAME points to Tailscale FQDN variable
- dashboard.levonk.com is an alias to dashboard.nl.levonk.com (single source of truth for the actual target)

## Risks & Mitigations

- **DNS record already exists**: Check Cloudflare before running the playbook; the playbook should be idempotent
- **Tailscale FQDN variable not defined**: Verify `ts_fqdn_windows_docker` is set in inventory

## Dependencies & Sequencing

- **Dependencies**: 01-001 (domain variables must exist for consistency)
- **Dependants**: 03-001 (playbook catalog), 05-001 (deploy-verify needs DNS to resolve)
- **Parallel-safe**: true (can run alongside 02-001, 02-002)

## Definition of Done

- Both DNS entries present in playbook
- `just ansible-syntax` passes
- CNAME entries follow existing pattern

## STOP Conditions

- Cloudflare API token not available in vault
- Tailscale FQDN variable not defined in inventory

## Maintenance Notes

- DNS records are managed via the playbook (not manually in Cloudflare dashboard)
- To change the target, update `ts_fqdn_windows_docker` in inventory

## Commit Conventions

- Commit subject: `feat(dns): add cloudflare CNAME entries for control-center domains`
- Body: list both CNAME records added

## Changelog

- 2026-08-30: Story created
