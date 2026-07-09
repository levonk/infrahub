---
story_id: "04-001"
story_title: "Deploy cache services and verify health endpoints"
story_name: "deploy-cache-services"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 4
parallel_id: 1
branch: "feature/current/nix-cache-chain/story-04-001-deploy-cache-services"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "01-003", "01-004", "01-005", "02-006"]
parallel_safe: false
modules: ["operational"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "operational", "deploy", "nix"]
due: "2026-08-05"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Execute the `nix-cache.yml` playbook to deploy all 4 Nix cache services (Harmonia, ncps, ncro, Attic) to their target machines. Verify all health endpoints respond correctly. This is an operational task — running ansible-playbook against real machines. Deploy in order: Attic first (cloud cache), then ncro (racing proxy), then ncps (front proxy), then Harmonia (local stores).

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/playbooks/nix-cache.yml` — playbook created in Story 03-001
  - All 5 roles from Phase 2 must be complete and ansible-lint clean
  - All 3 images must be in the local registry (Harmonia from 01-004, Attic from 01-005, ncro from 02-006)
  - Vault secrets must be populated (Story 01-003)

- **Deployment order (dependency chain):**
  1. Attic on oci-cloud-server (cloud cache — ncro upstream)
  2. Harmonia on all 5 machines (local stores — ncro upstream)
  3. ncro on dtop202311 + oci-cloud-server (racing proxy — needs all upstreams running)
  4. ncps on dtop202311 + oci-cloud-server (front proxy — needs ncro running)

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Deploy Attic | `devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/nix-cache.yml --tags attic --vault-password-file ~/.ansible/vault_password` | exit 0, all tasks OK |
  | Deploy Harmonia | `devbox run -- rtk ansible-playbook -i <all-inventories> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags harmonia --vault-password-file ~/.ansible/vault_password` | exit 0 |
  | Deploy ncro | `devbox run -- rtk ansible-playbook -i <all-inventories> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags ncro --vault-password-file ~/.ansible/vault_password` | exit 0 |
  | Deploy ncps | `devbox run -- rtk ansible-playbook -i <all-inventories> shared/active/02-config/ansible/playbooks/nix-cache.yml --tags ncps --vault-password-file ~/.ansible/vault_password` | exit 0 |

## Scope

**In scope:**
- Deploy Attic on oci-cloud-server
- Deploy Harmonia on all 5 Nix machines
- Deploy ncro on dtop202311 + oci-cloud-server
- Deploy ncps on dtop202311 + oci-cloud-server
- Verify all health endpoints
- Verify ncro can reach all upstreams

**Out of scope:**
- Client nix.conf configuration (Story 04-002)
- Code changes to roles or playbook

## Sub-Tasks

- [ ] Task 1 — Deploy Attic on oci-cloud-server
  `devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/nix-cache.yml --tags attic --vault-password-file ~/.ansible/vault_password`
  **Verify**: `curl -s http://100.90.22.85:8082/api/v1/` → returns valid JSON response (not connection refused)

- [ ] Task 2 — Deploy Harmonia on all 5 machines
  Run against all 3 inventories (oci, macos, windows). On each machine verify:
  **Verify**: `curl -s http://127.0.0.1:5000/nix-cache-info` on each machine → returns Nix cache info XML

- [ ] Task 3 — Deploy ncro on dtop202311 + oci-cloud-server
  **Verify**: `curl -s http://127.0.0.1:8081/health` on each regional hub → returns JSON with upstream status (all upstreams should show as reachable)

- [ ] Task 4 — Deploy ncps on dtop202311 + oci-cloud-server
  **Verify**: `curl -s http://127.0.0.1:8080/healthz` on each regional hub → returns healthy status

- [ ] Task 5 — Verify ncro upstream connectivity
  Check ncro `/health` endpoint shows all 5 Harmonia instances + Attic + cache.nixos.org as reachable.
  **Verify**: `curl -s http://127.0.0.1:8081/health | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d['upstreams']) >= 7; print('OK')"` → `OK`

- [ ] Task 6 — Verify ncps → ncro chain
  From a client machine, request a NAR through ncps and verify it proxies to ncro correctly.
  **Verify**: `curl -s http://<regional-ncps-ip>:8080/healthz` from a client machine → healthy

## Relevant Files

- `shared/active/02-config/ansible/playbooks/nix-cache.yml` — playbook (READ ONLY)
- All role directories (READ ONLY)

## Acceptance Criteria

- [ ] Attic container running on oci-cloud-server, health endpoint responds
- [ ] Harmonia containers running on all 5 machines, health endpoints respond
- [ ] ncro containers running on dtop202311 + oci-cloud-server, health endpoints respond
- [ ] ncps containers running on dtop202311 + oci-cloud-server, health endpoints respond
- [ ] ncro reports all upstreams as reachable
- [ ] ncps → ncro proxy chain works end-to-end

## Test Plan

- Health endpoint checks on each service on each machine
- ncro upstream connectivity check (all 7+ upstreams reachable)
- End-to-end NAR request through ncps → ncro → upstream

## Observability

- ncro Prometheus metrics: `curl http://127.0.0.1:8081/metrics` on regional hubs
- ncps OpenTelemetry: check ncps logs for trace exports
- Harmonia: check container logs for any errors

## Compliance

- No secrets exposed during deployment (vault handles all secrets)
- All containers run with `no-new-privileges:true`

## Risks & Mitigations

- Risk: macOS OrbStack `/nix/store` bind mount fails — Mitigation: Test on lzkmbp2016 first; if it fails, document as known limitation and skip macOS Harmonia
- Risk: Windows Docker Desktop cannot run Harmonia (no /nix/store) — Mitigation: Skip Windows if /nix/store not available; document as known limitation
- Risk: ncro crashes or can't reach upstreams — Mitigation: Check ncro logs (`docker logs localnet-nix-ncro`); verify Tailscale connectivity between machines
- Risk: ncps can't reach ncro (127.0.0.1:8081) — Mitigation: Verify both containers are on the same Docker network or that ncro binds to 127.0.0.1 correctly

## Dependencies & Sequencing

- Depends on: 03-001 (playbook), 01-003 (vault secrets), 01-004 (Harmonia image), 01-005 (Attic image), 02-006 (ncro image)
- Unblocks: 04-002 (client config deployment — needs cache services running)

## Definition of Done

- [ ] All health endpoints respond correctly
- [ ] ncro reports all upstreams as reachable
- [ ] No code changes (operational task only)

## STOP Conditions

Stop and report if:
- Any container fails to start (check docker logs)
- ncro cannot reach any upstream (check Tailscale connectivity)
- macOS or Windows cannot bind-mount /nix/store (document as known limitation, proceed with Linux-only deployment)
- Vault secrets are missing or incorrect (go back to Story 01-003)

## Maintenance Notes

- Re-run the playbook with `--tags <service>` to redeploy individual services
- Check ncro `/health` regularly to monitor upstream availability
- ncps NAR cache may need periodic cleanup

## Commit Conventions

- No code changes — no commit needed

## Changelog

- 2026-07-08: initialized story file
